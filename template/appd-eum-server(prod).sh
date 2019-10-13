#!/bin/bash
#chkconfig: 2345 30 70
#description: service script for AppDynamics EUM Server
set -e

APPD_RUNTIME_USER="ravello"
APPD_EUM_HOME="/home/ravello/AppDynamics/EUM"
export JAVA_HOME="$APPD_EUM_HOME/jre"

DEBUG_LOGS=false

################################################################################
# Do not edit below this line
################################################################################

init() {
	APPD_PROCESS="com.appdynamics.eumcloud.EUMProcessorServer"
	APPD_NAME="EUM Server"
	APPD_EUM_PROCESSOR="$APPD_EUM_HOME/eum-processor"

	MSG_RUNNING="AppDynamics - $APPD_NAME: Running"
	MSG_STOPPED="AppDynamics - $APPD_NAME: STOPPED"

	EUM_DATABASE_START_CMD="./orcha-master -d mysql.groovy -p ../../playbooks/mysql-orcha/start-mysql.orcha -o ../conf/orcha.properties -c local"
	EUM_DATABASE_STOP_CMD="./orcha-master -d mysql.groovy -p ../../playbooks/mysql-orcha/stop-mysql.orcha -o ../conf/orcha.properties -c local"

	MSG_DB_RUNNING="AppDynamics - Database for $APPD_NAME: Running"
	MSG_DB_STOPPED="AppDynamics - Database for $APPD_NAME: STOPPED"

	EUM_COLLECTOR_URL="http://localhost:7001/eumcollector/ping"
	EUM_COLLECTOR_RUNNING="AppDynamics - $APPD_NAME eumcollector/: Up"
	EUM_COLLECTOR_STOPPED="AppDynamics - $APPD_NAME eumcollector/: Down"
	EUM_COLLECTOR_VALIDATION="ping"

	EUM_AGGREGATOR_URL="http://localhost:7001/eumaggregator/ping"
	EUM_AGGREGATOR_RUNNING="AppDynamics - $APPD_NAME eumaggregator/: Up"
	EUM_AGGREGATOR_STOPPED="AppDynamics - $APPD_NAME eumaggregator/: Down"
	EUM_AGGREGATOR_VALIDATION="ping"

	if [[ -z "$APPD_EUM_HOME" ]] || [[ ! -d "$APPD_EUM_HOME" ]]; then
		echo "ERROR: could not find $APPD_EUM_HOME"
		exit 1
	fi
}

startDB() {
	local STATUS=$(ps -ef | grep "$APPD_EUM_HOME" | grep -i "bin/mysqld" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo -e "Starting the Database for $APPD_NAME..."
		DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
		cd $APPD_EUM_HOME/orcha/orcha-master/bin
		sudo -H -E -u $APPD_RUNTIME_USER "$EUM_DATABASE_START_CMD"
		cd $DIR
		echo -e "Started the Database for $APPD_NAME..."
	else
		echo "Database for $APPD_NAME is already Started"
	fi
}

start() {
	startDB

	echo -e "Starting the $APPD_NAME..."
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	cd $APPD_EUM_HOME/eum-processor
	sudo -H -u $APPD_RUNTIME_USER bin/eum.sh start
	cd $DIR
	echo -e "Started the $APPD_NAME..."
}


stopDB() {

	local STATUS=$(ps -ef | grep "$APPD_EUM_HOME" | grep -i "bin/mysqld" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "Database for $APPD_NAME is already stopped"
	else
		echo -e "Stopping the Database for $APPD_NAME..."
		DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
		cd $APPD_EUM_HOME/orcha/orcha-master/bin
		sudo -H -E -u $APPD_RUNTIME_USER $EUM_DATABASE_STOP_CMD
		cd $DIR
		echo -e "Stopped the Database for $APPD_NAME..."
	fi
}

stop() {

	echo -e "Stopping the $APPD_NAME..."
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	cd $APPD_EUM_HOME/eum-processor
	sudo -H -u $APPD_RUNTIME_USER bin/eum.sh stop
	cd $DIR
	echo -e "Stopped the $APPD_NAME..."

	stopDB
}


status() {
	local processPIDs=$(get-pid)

	log-debug "processPIDs=$processPIDs"

	if [[ -z "$processPIDs" ]]; then
		echo "$MSG_STOPPED"
  else
		echo "$MSG_RUNNING"
  fi

	local STATUS=$(ps -ef | grep "$APPD_EUM_HOME" | grep -i "bin/mysqld" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_DB_STOPPED"
	else
		echo "$MSG_DB_RUNNING"
	fi

	check-eumcollector
	check-eumaggregator
}

check-eumcollector() {
	local url="$EUM_COLLECTOR_URL"
  local expectedContent="HTTP/1.1 200 OK"

	local actualContent=$(curl -s --head "$url" | head -n 1 | grep "$expectedContent")

	log-debug "actualContent: $actualContent"

	if [[ $actualContent != *"$expectedContent"* ]]; then
		echo "$EUM_COLLECTOR_STOPPED"
	else
		echo "$EUM_COLLECTOR_RUNNING"
    fi
}

check-eumaggregator() {
	local url="$EUM_AGGREGATOR_URL"
    local expectedContent="HTTP/1.1 200 OK"

	local actualContent=$(curl -s --head "$url" | head -n 1 | grep "$expectedContent")

	log-debug "actualContent: $actualContent"

	if [[ $actualContent != *"$expectedContent"* ]]; then
		echo "$EUM_AGGREGATOR_STOPPED"
	else
		echo "$EUM_AGGREGATOR_RUNNING"
    fi
}

get-pid() {
	echo $(ps -ef | grep "$APPD_EUM_HOME" | grep "$APPD_PROCESS" | grep -v grep | awk '{print $2}')
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
		echo "Usage: $0 {start|stop|restart|status}"
		exit 1
esac
