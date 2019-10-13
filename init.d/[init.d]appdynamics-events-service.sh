#!/bin/bash
#chkconfig: 2345 60 90
#description: service script for AppDynamics standalone events service

set -e

APPD_RUNTIME_USER="ravello"
ES_HOME="/home/ravello/appdynamics/platform/product/events-service/processor"
export JAVA_HOME="/home/ravello/appdynamics/platform/product/jre/1.8.0_162"

DEBUG_LOGS=false

################################################################################
# Put Runtime User to sudo group (wheels) to run "sudo rm (line 73, 78)" to clean pid files
# or
# Run the service script in root mode (thus no "sudo" needed in line 73,78)
#
# Do not edit below this line
################################################################################

init() {
	APPD_PROCESS="com.appdynamics.analytics.processor.AnalyticsService"
	APPD_NAME="Events Service"

	START_COMMAND="nohup sudo -H -E -u $APPD_RUNTIME_USER $ES_HOME/bin/events-service.sh start -p $ES_HOME/conf/events-service-api-store.properties > $ES_HOME/logs/startAs.log 2>&1 &"
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
	log-debug "Ready to launch $APPD_NAME"
  echo -e "Starting the $APPD_NAME..."
	# DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	# cd $ES_HOME

	log-debug "$START_COMMAND"
	# export JAVA_HOME=$JAVA_HOME
	eval "$START_COMMAND"

	# cd $DIR

	echo -e "Started the $APPD_NAME..."
}

clean-pid-file() {
	if [[ -e "$ES_HOME/elasticsearch.id" ]]; then
		echo -e "clean $ES_HOME/elasticsearch.id file"
		eval "rm $ES_HOME/elasticsearch.id"
	fi

	if [[ -e "$ES_HOME/events-service-api-store.id" ]]; then
		echo -e "clean $ES_HOME/events-service-api-store.id file"
		eval "rm $ES_HOME/events-service-api-store.id"
	fi
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
