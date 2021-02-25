#!/bin/bash
# make sure locales are set
sudo sed -i '/^#.* en_US.UTF-8* /s/^#//' /etc/locale.gen
sudo locale-gen
sudo apt update -y
sudo apt install ssl-cert curl gnupg software-properties-common -y

clear
echo "Designed for Ubuntu 20.04.2 LTS"
echo "What you need to install [nginx/mariadb/wso2mi/scylladb/mean/mongodb/jdk/docker/vncserver/phpmyadmin/nextcloud] ?"

read input

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
	sudo apt install php-fpm php-mysql -y

        sudo cp ./nginx-default.conf /etc/nginx/sites-available/default
	sudo systemctl reload nginx
	sudo rm -rf /var/www/html/index*
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
	sudo apt-get install -y openjdk-8-jre-headless
	sudo scylla_setup --no-raid-setup --nic eth0 --no-kernel-check \
                 --no-ntp-setup --no-coredump-setup --io-setup 0 \
                 --no-node-exporter --no-cpuscaling-setup \
                 --no-fstrim-setup --no-memory-setup --no-rsyslog-setup
	echo "ScyllaDB 4.4 installed"

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
	sudo apt-get update
	sudo apt-get install phpmyadmin php-mbstring gettext -y
	sudo phpenmod mcrypt
	sudo phpenmod mbstring
	sudo ln -s /usr/share/phpmyadmin /var/www/html
	echo "phpmyadmin in place, you can access it on /phpmyadmin!"

elif [ $input == "nextcloud" ]; then
	echo "Installing nextcloud..."
        sudo cp ./nginx-nextcloud.conf /etc/nginx/sites-available/default
	sudo wget -O /tmp/nc.zip https://download.nextcloud.com/server/releases/nextcloud-21.0.0.zip 
        sudo unzip /tmp/nc.zip -d /var/www
	sudo mv /var/www/html /var/www/html.bak
	sudo mv /var/www/nextcloud /var/www/html
	sudo chown -R www-data:www-data /var/www/html
	sudo rm /tmp/nc.zip
	sudo apt install -y php-intl php-bcmath php-gmp php-imagick
	sudo sed -i 's/^\(memory_limit\s*=\s*\).*$/\1512M/' /etc/php/7.4/fpm/php.ini
	sudo systemctl restart php7.4-fpm
	echo "Nextcloud in place, continue in websetup!"
else 
	echo "Nothing was installed!"
fi
