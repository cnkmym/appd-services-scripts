#!/bin/bash
#chkconfig: 2345 20 80
#description: service script for AppDynamics Platform Admin

APPD_RUNTIME_USER="centos"
APPD_PLATFORMADMIN_HOME="/home/centos/appdynamics/platform/platform-admin"
APPD_PLATFORMDB_HOME="/home/centos/appdynamics/platform/mysql"

DEBUG_LOGS=false

################################################################################
# Do not edit below this line
################################################################################

init() {
	APPD_PROCESS="java"
	APPD_NAME="Platform Admin"

	MSG_APP_RUNNING="AppDynamics - $APPD_NAME app server: Running"
	MSG_APP_STOPPED="AppDynamics - $APPD_NAME app server: STOPPED"
	MSG_DB_RUNNING="AppDynamics - $APPD_NAME database: Running"
	MSG_DB_STOPPED="AppDynamics - $APPD_NAME database: STOPPED"
	MSG_ES_RUNNING="AppDynamics - $APPD_NAME events service: Running"
	MSG_ES_STOPPED="AppDynamics - $APPD_NAME events service: STOPPED"

	PLATFORMADMIN_URL="http://localhost:9191/"
	PLATFORMADMIN_RUNNING="AppDynamics - $APPD_NAME home page: Up"
	PLATFORMADMIN_STOPPED="AppDynamics - $APPD_NAME home page: Down"
	PLATFORMADMIN_VALIDATION="AppDyamics"

	if [[ -z "$APPD_PLATFORMADMIN_HOME" ]] || [[ ! -d "$APPD_PLATFORMADMIN_HOME" ]]; then
		echo "ERROR: could not find $APPD_PLATFORMADMIN_HOME"
		exit 1
	fi
}

start() {
	local processPIDs=$(get-pid)
	log-debug "processPIDs=$processPIDs"
	if [[ ! -z "$processPIDs" ]]; then
   		status
		return
   	fi

	echo -e "Starting the $APPD_NAME..."
	sudo -H -u "$APPD_RUNTIME_USER" "$APPD_PLATFORMADMIN_HOME"/bin/platform-admin.sh start-platform-admin
	echo -e "Started the $APPD_NAME..."
}

stop() {
	echo -e "Stopping the $APPD_NAME..."
	sudo -H -u "$APPD_RUNTIME_USER" "$APPD_PLATFORMADMIN_HOME"/bin/platform-admin.sh stop-platform-admin
	echo -e "Stopped the $APPD_NAME..."
}

status () {
	STATUS=$(ps -ef | grep "$APPD_PLATFORMADMIN_HOME" | grep -i "$APPD_PROCESS" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_APP_STOPPED"
	else
		echo "$MSG_APP_RUNNING"
	fi

	STATUS=$(ps -ef | grep "$APPD_PLATFORMDB_HOME" | grep -i "bin/mysqld" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_DB_STOPPED"
	else
		echo "$MSG_DB_RUNNING"
	fi

	check-home-page
}

check-home-page() {
	local url="$PLATFORMADMIN_URL"
  local expectedContent="HTTP/1.1 200 OK"
	local actualContent=$(curl -s --head "$url" | head -n 1 | grep "$expectedContent")
	log-debug "actualContent: $actualContent"

	if [[ $actualContent != *"$expectedContent"* ]]; then
		echo "$PLATFORMADMIN_STOPPED"
	else
		echo "$PLATFORMADMIN_RUNNING"
    fi
}

get-pid() {
	echo $(ps -ef | grep "$APPD_PLATFORMADMIN_HOME" | grep "$APPD_PROCESS" | grep -v grep | awk '{print $2}')
}

log-debug() {
    if [[ $DEBUG_LOGS = true ]]; then
        echo -e "DEBUG: $1"
    fi
}

init
case "$1" in
	start)
		start
		;;
	stop)
		stop
		;;
	restart)
		stop
		sleep 1
		start
		;;
	status)
		status
		;;
	*)
		echo $"Usage: $0 {start|stop|restart|status}"
		exit 1
		;;
esac
