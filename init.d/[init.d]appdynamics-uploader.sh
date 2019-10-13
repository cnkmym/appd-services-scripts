#!/bin/bash
#chkconfig: 2345 20 80
#description: service script for AppDynamics File Uploader

APPD_RUNTIME_USER="centos"
APPD_UPLOADER_HOME="/home/centos/Upload/spring-boot-file-upload-download-rest-api-example"

DEBUG_LOGS=false

################################################################################
# Do not edit below this line
################################################################################

init() {
	APPD_PROCESS="java"
	APPD_NAME="AppDynamics Uploader"

	#START_COMMAND="nohup sudo -H -u $APPD_RUNTIME_USER $JAVA $AGENT_OPTIONS -jar $AGENT_HOME/$APPD_PROCESS > /dev/null 2>&1 &"
	#STOP_COMMAND="nohup sudo -H -u $APPD_RUNTIME_USER kill $(get-pid) > /dev/null 2>&1 &"

	MSG_APP_RUNNING="AppDynamics - $APPD_NAME Uploader: Running"
	MSG_APP_STOPPED="AppDynamics - $APPD_NAME Uploader: STOPPED"

	UPLOADER_URL="http://localhost:8080/"
	UPLOADER_RUNNING="AppDynamics - $APPD_NAME home page: Up"
	UPLOADER_STOPPED="AppDynamics - $APPD_NAME home page: Down"
	UPLOADER_VALIDATION="File Upload / Download"

	if [[ -z "$APPD_UPLOADER_HOME" ]] || [[ ! -d "$APPD_UPLOADER_HOME" ]]; then
		echo "ERROR: could not find $APPD_UPLOADER_HOME"
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
	sudo -H -u "$APPD_RUNTIME_USER" "$APPD_UPLOADER_HOME"/bin/start.sh
	echo -e "Started the $APPD_NAME..."
}

stop() {
	echo -e "Stopping the $APPD_NAME..."
	sudo -H -u "$APPD_RUNTIME_USER" "$APPD_UPLOADER_HOME"/bin/stop.sh
	echo -e "Stopped the $APPD_NAME..."
}

status () {
	STATUS=$(ps -ef | grep "$APPD_UPLOADER_HOME" | grep -i "$APPD_PROCESS" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_APP_STOPPED"
	else
		echo "$MSG_APP_RUNNING"
	fi

	check-home-page
}

check-home-page() {
	local url="$UPLOADER_URL"
    local expectedContent="HTTP/1.1 200"

	local actualContent=$(curl -s --head "$url" | head -n 1 | grep "$expectedContent")

	log-debug "actualContent: $actualContent"

	if [[ $actualContent != *"$expectedContent"* ]]; then
		echo "$UPLOADER_STOPPED"
	else
		echo "$UPLOADER_RUNNING"
    fi
}

get-pid() {
	echo $(ps -ef | grep "$APPD_UPLOADER_HOME" | grep "$APPD_PROCESS" | grep -v grep | awk '{print $2}')
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
