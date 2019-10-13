#!/bin/bash
#chkconfig: 2345 40 70
#description: service script for AppDynamics Private Synthetic Server
set -e

APPD_RUNTIME_USER="centos"
APPD_SYNTH_HOME="/home/centos/appdynamics/"
APPD_EUM_URL="http://45controllerbase-maoexercisedefault-1gax8lud.srv.ravcloud.com:7001"
# MUST use JDK1.8+
export JAVA_HOME="/usr/lib/jvm/java-1.8.0-openjdk-1.8.0.222.b10-1.el7_7.x86_64/"

DEBUG_LOGS=true

################################################################################
# Do not edit below this line
################################################################################

init() {
	APPD_PROCESS="synthetic-processor"
	APPD_NAME="On Premise Synthetic Server"
	# APPD_SYNTH_PROCESSOR="$APPD_SYNTH_HOME/"
	EUM_STATUS_CHECK="curl -s --head $APPD_EUM_URL/eumcollector/ping | head -n 1"
	EUM_STATUS=0

	MSG_RUNNING="AppDynamics - $APPD_NAME: Running"
	MSG_STOPPED="AppDynamics - $APPD_NAME: STOPPED"

	MSG_SYNTH_SCHEDULER_RUNNING="AppDynamics - $APPD_NAME Scheduler : Up"
	MSG_SYNTH_SCHEDULER_STOPPED="AppDynamics - $APPD_NAME Scheduler : Down"

	MSG_SYNTH_SHEPHERD_RUNNING="AppDynamics - $APPD_NAME Shepherd : Up"
	MSG_SYNTH_SHEPHERD_STOPPED="AppDynamics - $APPD_NAME Shepherd : Down"

	MSG_SYNTH_FEEDER_RUNNING="AppDynamics - $APPD_NAME Feeder : Up"
	MSG_SYNTH_FEEDER_STOPPED="AppDynamics - $APPD_NAME Feeder : Down"

	if [[ -z "$APPD_SYNTH_HOME" ]] || [[ ! -d "$APPD_SYNTH_HOME" ]]; then
		echo "ERROR: could not find $APPD_SYNTH_HOME"
		exit 1
	fi
}

start() {
	# startDB

	processPIDs=$(get-pid)

	log-debug "processPIDs=$processPIDs"

	waitForEUM
	log-debug "EUM_STATUS=$EUM_STATUS"

	if [[ $EUM_STATUS -eq 0 ]]; then
		echo -e "Please Launch EUM Collector Service first"
		echo "AppDynamics - $APPD_NAME Launch Skipped : EUM Server is NOT Running"
	elif [[ -z "$processPIDs" ]]; then
		echo -e "Starting the $APPD_NAME..."
		DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
		cd $APPD_SYNTH_HOME/
		sudo -H -E -u $APPD_RUNTIME_USER unix/deploy.sh start
		cd $DIR
		echo -e "Started the $APPD_NAME..."
  else
		echo "AppDynamics - $APPD_NAME Launch Skipped : Already Running"
  fi

}

waitForEUM() {
	local tried=0
	local maxTries=60
	log-debug "Ready to check EUM status by CMD = $EUM_STATUS_CHECK"
	log-debug "EUM Respnse is $(eval $EUM_STATUS_CHECK)"
	while [[ $tried -lt $maxTries ]] && [[ $(eval $EUM_STATUS_CHECK) != *"HTTP/1.1 200 OK"* ]]; do
    echo 'EUM Collector Service is not running yet. Will try again in 10 seconds ...'
    sleep 10
		tried=$((tried + 1))
		log-debug "EUM Respnse is $(eval $EUM_STATUS_CHECK)"
	done

	log-debug "tried times = $tried"
	if [[ $tried -lt $maxTries ]]; then
		echo "EUM is running"
		EUM_STATUS=1
	fi
}

stop() {

	echo -e "Stopping the $APPD_NAME..."
	DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
	cd $APPD_SYNTH_HOME/
	sudo -H -E -u $APPD_RUNTIME_USER unix/deploy.sh stop
	cd $DIR
	echo -e "Stopped the $APPD_NAME..."

}


status() {
	local processPIDs=$(get-pid)

	log-debug "processPIDs=$processPIDs"

	if [[ -z "$processPIDs" ]]; then
		echo "$MSG_STOPPED"
  else
		echo "$MSG_RUNNING"
  fi

	local STATUS=$(ps -ef | grep "$APPD_SYNTH_HOME" | grep -i "synthetic-scheduler.yml" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_SYNTH_SCHEDULER_STOPPED"
	else
		echo "$MSG_SYNTH_SCHEDULER_RUNNING"
	fi

	STATUS=$(ps -ef | grep "$APPD_SYNTH_HOME" | grep -i "shepherd.yml" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_SYNTH_SHEPHERD_STOPPED"
	else
		echo "$MSG_SYNTH_SHEPHERD_RUNNING"
	fi

	STATUS=$(ps -ef | grep "$APPD_SYNTH_HOME" | grep -i "synthetic-feeder.yml" | grep -v grep)
	if [[ -z "$STATUS" ]]; then
		echo "$MSG_SYNTH_FEEDER_STOPPED"
	else
		echo "$MSG_SYNTH_FEEDER_RUNNING"
	fi
}

get-pid() {
	echo $(ps -ef | grep "$APPD_SYNTH_HOME" | grep "$APPD_PROCESS" | grep -v grep | awk '{print $2}')
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

	eum)
		waitForEUM
	;;

	*)
		echo "Usage: $0 {start|stop|restart|status|eum}"
		exit 1
esac
