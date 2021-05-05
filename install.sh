#!/bin/bash
# make sure locales are set
sudo sed -i '/^#.* en_US.UTF-8* /s/^#//' /etc/locale.gen
sudo locale-gen
sudo apt update -y
sudo apt install ssl-cert curl gnupg software-properties-common rsync -y

clear
echo "Designed for Ubuntu 20.04.2 LTS"
echo "What you need to install [nginx/mariadb/wso2mi/scylladb/galeradb/mean/mongodb/jdk/docker/vncserver/phpmyadmin/coturn/nextcloud] ?"

read input
IP="$(hostname -I|awk '{print $1;}'|xargs)"
HOSTNAME="$(hostname -s)"
NIC=$(ip link | awk -F: '$0 !~ "lo|vir|wl|docker|^[^0-9]"{sub(/@.*/,"");print $2;getline}')
VIRT="$(systemd-detect-virt -c)"

if [ $input == "nginx" ]; then
	echo "Installing nginx + PHP.."
	sudo apt install nginx -y
	sudo nginx -t

	echo "Adjust the Firewall to Allow Web Traffic"
	sudo ufw app list
	sudo ufw app info "Nginx Full"

	echo "Allow incoming traffic for this profile"
	sudo ufw allow in "Nginx Full"

	echo "Installing php.."
	sudo apt install php-fpm php-mysql php-sqlite3 -y

        sudo cp ./nginx-default.conf /etc/nginx/sites-available/default
	sudo systemctl reload nginx
	sudo rm -rf /var/www/html/index*
	# opcache more agressive
	sudo sed -i '/opcache.revalidate_freq=2/s/^;//g' /etc/php/7.4/fpm/php.ini
	sudo sed -i 's/^\(opcache.revalidate_freq\s*=\s*\).*$/\1240/' /etc/php/7.4/fpm/php.ini

	read -r -p "Cache PHP code permanently in RAM? [Y/n]" response
        response="${response,,}"
        if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
		echo "Timestamps disabled"
		sudo sed -i '/opcache.validate_timestamps=1/s/^;//g' /etc/php/7.4/fpm/php.ini
		sudo sed -i 's/^\(opcache.validate_timestamps\s*=\s*\).*$/\10/' /etc/php/7.4/fpm/php.ini
	fi
	# opcache more agressive
	echo "<?php phpinfo();" | sudo tee -a /var/www/html/index.php >/dev/null
	echo "nginx + php installed"

elif [ $input == "mariadb" ]; then
	echo "Installing mariadb.."
	sudo apt install mariadb-server -y
	sudo service mariadb stop
	sudo mysql_install_db
	sudo service mariadb start
	sudo mysql_secure_installation
	echo "MariaDB installed"

elif [ $input == "wso2mi" ]; then
 	echo "Installing WSO2 Micro Integrator 1.2.0"
        sudo wget -O /tmp/ei.zip https://github.com/wso2/micro-integrator/releases/download/v1.2.0/wso2mi-1.2.0.zip
        sudo unzip /tmp/ei.zip -d /opt
        sudo rm /tmp/ei.zip
	sudo apt install -y openjdk-8-jdk
	sudo ufw allow 8290,8253/tcp
	sudo cp ./init.d-wso2mi.sh /etc/init.d/wso2mi
	sudo chmod +x /etc/init.d/wso2mi
	sudo update-rc.d wso2mi defaults
	sudo useradd  --home /opt/wso2mi-1.2.0 -M wso2
	sudo cp ./jdbc/* /opt/wso2mi-1.2.0/dropins/
	sudo chown -R wso2:nogroup /opt/wso2mi-1.2.0
	echo "WSO2 Micro Integrator installed"

elif [ $input == "scylladb" ]; then
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 5e08fbd8b5d6ec9c
	sudo curl -L --output /etc/apt/sources.list.d/scylla.list http://downloads.scylladb.com/deb/ubuntu/scylla-4.4-$(lsb_release -s -c).list
	sudo apt-get update
        sudo apt-get install -y scylla
	sudo sed -i 's/^\(listen_address\s*:\s*\).*$/\1'${IP}'/' /etc/scylla/scylla.yaml
	sudo sed -i 's/^\(rpc_address\s*:\s*\).*$/\1'${IP}'/' /etc/scylla/scylla.yaml
	sudo /opt/scylladb/scripts/scylla_dev_mode_setup --developer-mode 1
        sudo scylla_setup --no-raid-setup --nic ${NIC} --no-kernel-check \
                 --no-ntp-setup --no-coredump-setup \
                 --no-node-exporter --no-cpuscaling-setup \
                 --no-fstrim-setup --no-memory-setup --no-rsyslog-setup

	sudo ufw allow 9042,9142,7199,10000,9180,9100,9160,19042,19142,7000,7001/tcp
	echo "ScyllaDB 4.4 installed"

elif [ $input == "citus" ]; then
	curl https://install.citusdata.com/community/deb.sh | sudo bash
	sudo apt-get -y install postgresql-13-citus-10.0
	sudo pg_conftool 13 main set shared_preload_libraries citus
	sudo pg_conftool 13 main set listen_addresses '*'
	echo "host    all             all             10.0.0.0/8              trust" | sudo tee -a /etc/postgresql/13/main/pg_hba.conf
	echo "host    all             all             127.0.0.1/32            trust" | sudo tee -a /etc/postgresql/13/main/pg_hba.conf
	echo "host    all             all             ::1/128                 trust" | sudo tee -a /etc/postgresql/13/main/pg_hba.conf
        sudo systemctl enable postgresql
        sudo systemctl restart postgresql
	sudo -i -u postgres psql -c "CREATE EXTENSION citus;"
	echo "Run this command on coordinator node"
	echo "sudo -i -u postgres psql -c \"SELECT * from citus_add_node('${IP}', 5432);\""
	sudo pg_ctlcluster 13 main start
	sudo ufw allow 5432/tcp
	echo "Citus installed"

elif [ $input == "galeradb" ]; then
	sudo apt install mariadb-server mariadb-backup -y
	sudo service mariadb stop
	sudo cp ./galera.cnf /etc/mysql/conf.d/
	sudo ufw allow 3306,4567,4568,4444/tcp
	sudo ufw allow 4567/udp
	
        echo "Insert all node IP separated by coma for example 10.0.0.1,10.0.0.2,10.0.0.3"
        read IPLIST
        sudo sed -i 's/^\(wsrep_node_name\s*=\s*\).*$/\1"'${HOSTNAME}'"/' /etc/mysql/conf.d/galera.cnf
        sudo sed -i -e "s/ThisNodeIP/${IP}/g" /etc/mysql/conf.d/galera.cnf
        sudo sed -i -e "s/NodeIPs/${IPLIST}/g" /etc/mysql/conf.d/galera.cnf

        read -r -p "Is this first node of cluster? [Y/n]" response
        response="${response,,}"

        if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
            echo "Yes - cluster init in progress"
	    sudo mysql_install_db
            sudo galera_new_cluster
            sudo mariadb -u root -e "CREATE USER 'mariabackup'@'localhost' IDENTIFIED BY 'Nx9sXG7v7vF5w4Ls';"
            sudo mariadb -u root -e "GRANT RELOAD, PROCESS, LOCK TABLES, REPLICATION CLIENT ON *.* TO 'mariabackup'@'localhost';"
	    sudo mysql_secure_installation
	else
            echo "No - starting DB directly"
            sudo service mariadb start
	fi
	echo "GaleraDB installed"

elif [ $input == "mean" ]; then
	echo "Installing mean stack.. [Installs MongoDB, NodeJS version 12]"
	sudo apt install git -y
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 20691eec35216c63caf66ce1656408e390cfb1f5
	echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
	sudo apt update
	sudo apt-get install -y mongodb-org
	sudo systemctl start mongod
	service mongod status

	echo "Installing nodejs.. - To install your own NodeJS version, try nvm option"
	curl -sL https://deb.nodesource.com/setup_12.x | sudo -E bash -
	sudo apt install -y nodejs
	sudo apt install build-essential
	
	echo "MEAN stack installed!"

elif [ $input == "jdk" ] || [ $input == "java" ]; then
	sudo apt install -y openjdk-8-jdk
	echo "OpenJDK installed in"
	sudo update-alternatives --list java

elif [ $input == "docker" ]; then
        echo "Installing Docker...."

        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
        sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
        sudo apt-get update

        echo "Making sure the Docker is installed from Official Docker repo to get the latest version"
        dockerInstallLoc="$(apt-cache policy docker-ce)"
        echo "${dockerInstallLoc}"

        sudo apt-get install -y docker-ce

        dockerSuccess="$(sudo systemctl status docker)"
        echo "${dockerSuccess}"

        echo "Successfully installed Docker!"

        read -r -p "Do you want to add root privileges to run Docker? [Y/n]" response
        response="${response,,}"

        if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
            echo "Adding your username into Docker group"
            sudo usermod -aG docker ${USER}
            su - ${USER}
            echo "Addition of Username to Docker group is successful!"
        else
            echo "Exited without adding root privileges to run Docker"
        fi

        echo "Docker is ready to be used"

elif [ $input == "vncserver" ]; then
        echo "Installing VNCServer...."
		sudo apt install xfce4 xfce4-goodies tightvncserver
        echo "VNCServer is ready to be used"

elif [ $input == "mongodb" ]; then
	echo "Installing MongoDB...."
	sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 20691eec35216c63caf66ce1656408e390cfb1f5
	echo "deb [ arch=amd64,arm64 ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list
	sudo apt-get update
	sudo apt-get install -y mongodb-org
	echo "Starting Mongodb Service..."
	sudo service mongod start
	echo "Service started (Hopefully)..."
	echo "Run 'mongo' to connect to the local server which is running on 27017"

elif [ $input == "phpmyadmin" ]; then
	echo "Installing phpmyadmin..."
	sudo apt-get install phpmyadmin php-mbstring gettext -y
	sudo phpenmod mbstring
	sudo ln -s /usr/share/phpmyadmin /var/www/html
	echo "phpmyadmin in place, you can access it on /phpmyadmin!"

elif [ $input == "coturn" ]; then
	echo "Installing coturn..."
	sudo apt-get install coturn -y
	sudo sed -i '/TURNSERVER_ENABLED=1/s/^#//g' /etc/default/coturn
	sudo ufw allow 443/tcp
	sudo ufw allow 443/udp
	sudo ufw allow 49152:65535/udp
	sudo mkdir -p /etc/systemd/system/coturn.service.d
	sudo cp ./systemd-coturn.conf /etc/systemd/system/coturn.service.d/override.conf
	sudo mkdir -p /var/log/turnserver
	sudo chown turnserver:turnserver /var/log/turnserver
	sudo systemctl daemon-reload
	sudo systemctl restart coturn
	echo "Successfully installed coturn server!"

elif [ $input == "ceph" ]; then
	echo "Installing CEPH.."
	curl -fsSL https://github.com/ceph/ceph/raw/pacific/src/cephadm/cephadm --output /tmp/cephadm
	chmod +x /tmp/cephadm
	sudo /tmp/cephadm add-repo --release pacific

	curl -fsSL https://download.ceph.com/keys/release.asc | gpg --no-default-keyring --keyring /tmp/fix.gpg --import -
	gpg --no-default-keyring --keyring /tmp/fix.gpg --export | sudo tee  /etc/apt/trusted.gpg.d/ceph.release.gpg >/dev/null
	rm /tmp/fix.gpg && rm /tmp/cephadm
	
	sudo apt update -y
	sudo apt install ceph -y

        read -r -p "Is this first node of cluster? [Y/n]" response
        response="${response,,}"

        if [[ $response =~ ^(yes|y| ) ]] || [[ -z $response ]]; then
            echo "Yes - bootstrap in progress"
            FSID="$(uuidgen)"
            echo "[global]" | sudo tee /etc/ceph/ceph.conf
            echo "fsid = $FSID" | sudo tee -a /etc/ceph/ceph.conf
            echo "mon initial members = $HOSTNAME" | sudo tee -a /etc/ceph/ceph.conf
            echo "mon host = $IP" | sudo tee -a /etc/ceph/ceph.conf
            printf "auth cluster required = cephx\nauth service required = cephx\nauth client required = cephx\nosd journal size = 1024\nosd pool default size = 3\nosd pool default min size = 2\nosd pool default pg num = 333\nosd pool default pgp num = 333\nosd crush chooseleaf type = 1\n" | sudo tee -a /etc/ceph/ceph.conf
	    sudo mkdir /var/lib/ceph/bootstrap-osd/
            sudo ceph-authtool --create-keyring /tmp/ceph.mon.keyring --gen-key -n mon. --cap mon 'allow *'
            sudo ceph-authtool --create-keyring /etc/ceph/ceph.client.admin.keyring --gen-key -n client.admin --cap mon 'allow *' --cap osd 'allow *' --cap mds 'allow *' --cap mgr 'allow *'
            sudo ceph-authtool --create-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring --gen-key -n client.bootstrap-osd --cap mon 'profile bootstrap-osd' --cap mgr 'allow r'
            sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /etc/ceph/ceph.client.admin.keyring
            sudo ceph-authtool /tmp/ceph.mon.keyring --import-keyring /var/lib/ceph/bootstrap-osd/ceph.keyring
            sudo chown ceph:ceph /tmp/ceph.mon.keyring
            monmaptool --create --add $HOSTNAME $IP /tmp/monmap
            sudo mkdir -p /var/lib/ceph/mon/ceph-$HOSTNAME
            sudo chown -R ceph:ceph /var/lib/ceph
            sudo -u ceph ceph-mon --cluster ceph --mkfs -i $HOSTNAME --monmap /tmp/monmap --keyring /tmp/ceph.mon.keyring
	    sudo systemctl enable ceph-mon@$HOSTNAME
	    sudo systemctl start ceph-mon@$HOSTNAME
	    sudo ceph config set mon auth_allow_insecure_global_id_reclaim false
	    sudo ceph config set mon mon_warn_on_msgr2_not_enabled false
	    
	    sudo ceph auth get-or-create mgr.$HOSTNAME mon 'allow profile mgr' osd 'allow *' mds 'allow *' >/tmp/ceph.mgr.keyring
	    sudo cp /tmp/ceph.mgr.keyring /var/lib/ceph/mgr/ceph-$HOSTNAME/keyring
	else
            echo "No"
	fi
	sudo ceph -s
	echo "Create OSD by running -> sudo ceph-volume lvm create --data /dev/sd{X}"
	echo "Create POOL by running -> sudo ceph osd pool create {pool} 128"
	echo "CEPH Server installed"

elif [ $input == "nextcloud" ]; then
	echo "Installing nextcloud..."
        sudo cp ./nginx-nextcloud.conf /etc/nginx/sites-available/default
	sudo wget -O /tmp/nc.zip https://download.nextcloud.com/server/releases/nextcloud-21.0.0.zip 
        sudo unzip /tmp/nc.zip -d /var/www
	sudo mv /var/www/html /var/www/html.bak
	sudo mv /var/www/nextcloud /var/www/html
	sudo chown -R www-data:www-data /var/www/html
	sudo rm /tmp/nc.zip
	sudo apt install -y php-intl php-bcmath php-gmp php-imagick php-zip php-xml php-mbstring php-curl php-gd
	sudo sed -i 's/^\(memory_limit\s*=\s*\).*$/\1512M/' /etc/php/7.4/fpm/php.ini
	sudo sed -i '/clear_env = no/s/^;//g' /etc/php/7.4/fpm/pool.d/www.conf
	sudo systemctl restart php7.4-fpm
	sudo systemctl reload nginx
	echo "Nextcloud in place, continue in websetup!"
else 
	echo "Nothing was installed!"
fi
