#!/bin/bash

SCRIPTPATH="$( cd "$(dirname "$0")" ; pwd -P )"
INVENTORY=$SCRIPTPATH/../environments/dev/hosts.moe
NAMESPACE=mongo
LOGFILE=$SCRIPTPATH/log

[ "$1" != "" ] && usage

while [ "$1" != "" ]; do
    case $1 in
	-l | --list)
	    list
	    exit 0
	    ;;
        -c | --configure)
	    configure
	    exit 0
            ;;
        * )  usage
    esac
    shift
done

function usage
{
    cat <<EOF Usage: $0 options
    Options:
    -l | --list		       - list inventory
    -h | --host	<hostname>     - output host variables
    -c | --configure 	       - create env file containing inventory configuration 
EOF
    exit 1
}

function list
{
}

function configure
{
    
}

function generate_machine
{
    NAMESPACE=$NAMESPACE envsubst < $SCRIPTPATH/vmi-preset.yaml | kubectl apply -f - 2>&1 >> $LOGFILE
    NAME=$1 NAMESPACE=$NAMESPACE envsubst < $SCRIPTPATH/vm.yaml | kubectl apply -f - 2>&1 >> $LOGFILE
}

function machine_ip
{    
    kubectl get vms -n $NAMESPACE | grep $1 2>&1>$LOGFILE || generate_machine $1
    
    IP=`kubectl get pods -o wide -n $NAMESPACE | grep $1 | awk '{ print  $6 }'`
    while  ! echo $IP | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" 2>&1 >> $LOGFILE; do
	sleep 0.5s
	IP=`kubectl get pods -o wide -n $NAMESPACE | grep $1 | awk '{ print  $6 }'`
    done
    echo $IP
}

echo "START" > $LOGFILE

hostsSection=false
while read line; do
    echo ">> $line" >> $LOGFILE
    if echo $line | grep "\[.*\]" > /dev/null; then
	if echo $line | grep "\[.*\:.*\]" > /dev/null; then
	    hostsSection=false
	else
	    hostsSection=true
	fi
    else	
	if [ "$hostsSection" = true ] && [[ ! -z "${line// }" ]]; then
	    line="$line ansible_ssh_host="`machine_ip $line`
	fi
    fi
    echo "$line" | tee -a $LOGFILE
done < $INVENTORY
