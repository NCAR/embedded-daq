#!/bin/bash

# set -x

titan=false
fgrep -q PXA270 /proc/cpuinfo && titan=true

# Try to ping one or more hosts. If no pings are successful
# turn off a DIO port and back on. The port presumably
# controls power to a router.

script=$0
script=${script##*/}

log=/var/tmp/${script%.*}.log
cat /dev/null > $log

if [ $# -lt 2 ]; then
    echo "Usage $script dio_port ping_host1 ping_host2 ... "
    exit 1
fi

if [ -x /usr/bin/logger ]; then                                
    LOGGER=/usr/bin/logger                                     
elif [ -x /bin/logger ]; then                                  
    LOGGER=/bin/logger                                         
else                                                           
    unset LOGGER                                               
fi                                                             

# If stdout is a terminal then cat messages to stdout,
# otherwise use logger
if [ -t 1 -o -z "$LOGGER" ]; then     
    mesgr () {                         
        cat
    }                                 
else                                  
    mesgr () {                         
        $LOGGER -p daemon.warning -t $(basename $0)"[$$]"
    }                                       
fi              


dioport=$1
shift
hosts=($@)

# busybox bash doesn't support pipefail
# set -o pipefail

# check that dns returns an address for the host argument,
# that is not a 169.254.*.* address.  The cradlepoint
# routers, if the cellular link is down, seem to return
# a 169.254.*.* address on DNS lookups and pings to that address succeed.
check_dns() {
    local -a addrs=(`host $1 | awk '{print $4}'`)
    [[ ${#addrs[*]} -eq 0 ]] && return 1
    if [[ ${addrs[0]} == 169.254.*.* ]]; then
        echo "host $1 returns ${addrs[0]}"
        return 1
    fi
    return 0
}

do_ping() {
    local i
    local ntry=3
    for (( i=0; i < $ntry; i++ )); do
        check_dns $1 && ping -c 2 -q  $1 > /dev/null 2>&1 && return 0
        sleep 1
    done
    # do last ping without discarding error output
    ping -c 2 -q  $1
    return 1
}

if $titan; then
    power_cycle_router() {
        echo "cycling state of DIO pin $dioport to cycle power on router"
        tio $dioport 0 || return 1
        sleep 2
        tio $dioport 1 || return 1
        sleep 2 
    }
else
    power_cycle_router() {
        echo "cycling state of DIO pin $dioport to cycle power on router"
        viper_dio /dev/viper_dio0 $dioport 0 || return 1
        sleep 2
        viper_dio /dev/viper_dio0 $dioport 1 || return 1
        sleep 2 
    }
fi

check_ping() {
    local host
    # if a ping of a host works, don't power cycle router
    for host in ${hosts[*]}; do
        do_ping $host && return 0
    done
    return 1
}

logfile=$(mktemp /tmp/${script}_XXXXXX)
if ! check_ping > $logfile 2>&1; then
    cat $logfile | mesgr
    rm $logfile
    power_cycle_router 2>&1 | mesgr
    exit 1
fi
rm $logfile
exit 0
