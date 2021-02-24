# linux-server-install
Fast use - log in to server and run

```
wget https://github.com/janforman/linux-server-install/archive/main.zip -O /tmp/t.zip && unzip /tmp/t.zip -d /opt && rm /tmp/t.zip && cd /opt/linux-server-install-main/ && ./install.sh
```

* nginx + php
* mariadb
* scylladb
* mongodb
* wso2 microintegrator (mariadb, scylladb, oracle connectors)
* mean stack (MongoDB, NodeJS)
* java openjdk
* docker
* phpmyadmin

This script is intended to use in VPS (virtual server for single purpose in this case)

It's tested in UBUNTU Server 20.04.2 LTS
