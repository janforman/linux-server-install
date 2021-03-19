# linux-server-install
Fast use - log in to server and run

```
wget https://github.com/janforman/linux-server-install/archive/main.zip -O /tmp/t.zip && unzip /tmp/t.zip -d /tmp && rm /tmp/t.zip && cd /tmp/linux-server-install-main/ && ./install.sh
```

* nginx (with php)
* mariadb
* scylladb
* mongodb
* galeradb
* wso2 microintegrator (mariadb, scylladb, mongodb, postgres, oracle connectors)
* mean stack (MongoDB, NodeJS)
* java openjdk
* docker
* phpmyadmin (install nginx first)
* coturn (STUN/TURN on port 443)
* nextcloud (install nginx first)

This script is intended to use in VPS (virtual server for single purpose in this case) and fresh OS install.

It's tested in UBUNTU Server 20.04.2 LTS
