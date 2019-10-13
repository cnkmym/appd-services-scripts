#!/bin/bash
#chkconfig: 2345 60 90
#description: service script for AppDynamics standalone events service
set -e

APPD_RUNTIME_USER="centos"
ES_HOME="/home/centos/appdynamics/platform/product/events-service/processor"
export JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk"

DEBUG_LOGS=false
################################################################################
# To make this file work, please add the following segment to events-service.sh
#
# Line57, method setJavaCmd. Pay attention to JRE version of your installation
#
# setJavaCmd () {
#    [ "$JAVA_HOME" ] || JAVA_CMD=$(which java)
#    [ "$JAVA_HOME" ] && [ -x "$JAVA_HOME/bin/java" ] && JAVA_CMD="$JAVA_HOME/bin/java"
#    #-----------------------------
#    echo "Current JAVA_CMD value is : $JAVA_CMD"
#    if [[ "$JAVA_CMD" ]]; then
#      version=$("$JAVA_CMD" -version 2>&1 | awk -F '"' '/version/ {print $2}')
#      echo version "$version"
#      if [[ ( "$version" == "1.5"* ) || ( "$version" == "1.6"* ) || ( "$version" == "1.7"* ) ]]; then
#        export JAVA_HOME="$APPLICATION_HOME/../../jre/1.8.0_162"
#				 JAVA_CMD="$JAVA_HOME/bin/java"
#        echo "Hardcode JAVA_CMD Value to : $JAVA_CMD"
#      fi
#    fi
#    #-----------------------------
#}
################################################################################

################################################################################
# Do not edit below this line
################################################################################

init() {
	APPD_PROCESS="com.appdynamics.analytics.processor.AnalyticsService"
	APPD_NAME="Events Service"

	START_COMMAND="nohup sudo -H -E -u $APPD_RUNTIME_USER $ES_HOME/bin/events-service.sh start -p $ES_HOME/conf/events-service-api-store.properties"
	STOP_COMMAND="nohup sudo -H -E -u $APPD_RUNTIME_USER kill $(get-pid) > /dev/null 2>&1 &"

	MSG_RUNNING="AppDynamics - $APPD_NAME: Running"
	MSG_STOPPED="AppDynamics - $APPD_NAME: STOPPED"

	ES_URL="http://localhost:9080/_ping"
	ES_RUNNING="AppDynamics - $APPD_NAME ping/: Success"
	ES_STOPPED="AppDynamics - $APPD_NAME ping/: Failure"
	ES_VALIDATION="_pong"

	if [[ -z "$JAVA_HOME" ]] || [[ ! -d "$JAVA_HOME" ]]; then
		echo -e "ERROR: could not find $JAVA_HOME"
		exit 1
	fi

	if [[ ! -d "$ES_HOME" ]]; then
		echo -e "ERROR: could not find $ES_HOME"
		exit 1
	fi
}

start() {
	local processPIDs=$(get-pid)
	log-debug "processPIDs=$processPIDs"
	if [[ ! -z "$processPIDs" ]]; then
   		echo -e "$MSG_RUNNING"
		return
   	fi

	clean-pid-file
	echo -e "Starting the $APPD_NAME..."
	# DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	# cd $ES_HOME

	log-debug "$START_COMMAND"
	eval "$START_COMMAND"

	# cd $DIR

	echo -e "Started the $APPD_NAME..."
}

stop() {
	local processPIDs=$(get-pid)
	log-debug "processPIDs: $processPIDs"

    if [[ -z "$processPIDs" ]]; then
        echo -e "$MSG_STOPPED"
        return
    fi

	echo -e  "Stopping the $APPD_NAME..."
	log-debug "$STOP_COMMAND"
	eval "$STOP_COMMAND"
	echo -e "Stopped the $APPD_NAME..."
	clean-pid-file
}

clean-pid-file() {
	if [[ -e "$ES_HOME/elasticsearch.id" ]]; then
		echo -e "clean $ES_HOME/elasticsearch.id file"
		eval "sudo rm -rf $ES_HOME/elasticsearch.id"
	fi

	if [[ -e "$ES_HOME/events-service-api-store.id" ]]; then
		echo -e "clean $ES_HOME/events-service-api-store.id file"
		eval "sudo rm -rf $ES_HOME/events-service-api-store.id"
	fi
}

status() {
	local processPIDs=$(get-pid)

	log-debug "processPIDs=$processPIDs"

	STATUS=$(ps -ef | grep "$ES_HOME" | grep -i "$APPD_PROCESS" | grep -v grep)
		if [[ -z "$STATUS" ]]; then
			echo "$MSG_STOPPED"
		else
			echo "$MSG_RUNNING"
		fi

	check-ping
}

check-ping() {
	local url="$ES_URL"
    local expectedContent="HTTP/1.1 200 OK"

	local actualContent=$(curl -s --head "$url" | head -n 1 | grep "$expectedContent")

	log-debug "actualContent: $actualContent"

	if [[ $actualContent != *"$expectedContent"* ]]; then
		echo "$ES_STOPPED"
	else
		echo "$ES_RUNNING"
    fi
}

get-pid() {
	echo $(ps -ef | grep "$ES_HOME" | grep "$APPD_PROCESS" | grep -v grep | awk '{print $2}')
}

log-debug() {
    if [[ $DEBUG_LOGS = true ]]; then
        echo -e "DEBUG: $1"
    fi
}

# init() to set the global variables
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
	clean)
		clean-pid-file
		;;
	*)
		echo -e "Usage:\n $0 [start|stop|restart|status|clean]"
		exit 1
		;;
esac
