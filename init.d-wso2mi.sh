#! /bin/bash
#
### BEGIN INIT INFO
# Provides:          wso2
# Product:           wso2mi
# Product Version:   1.2.0
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: Start and stop the wso2 product server daemon
# Description:       Controls the main WSO2 product server daemon
### END INIT INFO
#

[ -z "$JAVA_HOME" ] && JAVA_HOME="/usr/lib/jvm/java-8-openjdk-amd64/jre"
WSO2_HOME="/opt/wso2mi-4.0.0"

# define service commands
startcmd="${WSO2_HOME}/bin/micro-integrator.sh start"
restartcmd="${WSO2_HOME}/bin/micro-integrator.sh restart"
stopcmd="${WSO2_HOME}/bin/micro-integrator.sh stop"

case "$1" in
start)
   echo "Starting the WSO2 server ..."
   su -c "env JAVA_HOME=${JAVA_HOME} ${startcmd}" wso2 2>/dev/null
;;
restart)
   echo "Restarting the WSO2 server ..."
   su -c "env JAVA_HOME=${JAVA_HOME} ${restartcmd}" wso2 2>/dev/null
;;
stop)
   echo "Stopping the WSO2 server ..."
   su -c "env JAVA_HOME=${JAVA_HOME} ${stopcmd}" wso2 2>/dev/null
;;
*)
   echo "Usage: sudo service <PRODUCT_NAME> <start|stop|restart>"
exit 1
esac
