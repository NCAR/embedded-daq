#!/bin/sh

# set -x

# Check status of a network interface (typically a ppp interface).
# If it is down, do ifup and a ping of a host. Log errors.

script=$0
script=${script##*/}

if [ $# -lt 3 ]; then
    echo "Usage $script interface subnet ping_host"
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

iface=$1
subnet=$2
host=$3

get_if_state() {
    /sbin/ifconfig $iface 2> /dev/null | awk 'FNR==3{print $1}'
}

get_if_addr() {
    /sbin/ifconfig $iface 2> /dev/null | awk 'FNR==2{print $2}' | \
        sed 's/addr://'
}

do_ping() {
    local i
    local ntry=4
    for (( i=0; i < $ntry; i++ )); do
        ping -c 2 -q  $1 > /dev/null 2>&1 && return 0
        sleep 1
    done
    # do last ping without discarding error output
    ping -c 2 -q $1 2>&1 | mesgr
    return 1
}

check_ping() {
    local i
    local ntry=2
    for (( i=0; i < $ntry; i++ )); do
        do_ping $host && return 0
        echo "doing ifdown $iface" | mesgr
        /sbin/ifdown $iface 2>&1 | mesgr
        # still might be pppd's hanging around,
        # perhaps due to repeated ifups? Kill 'em.
        if [[ $iface == ppp* ]]; then
            sleep 2
            pkill -9 pppd 2>&1 | dmesgr
            sleep 2
        fi
        echo "doing ifup $iface" | mesgr
        /sbin/ifup $iface 2>&1 | mesgr
        sleep 1
    done
    return 1
}

fix_if() {
    # send output from individual commands to mesgr
    # so that they appear in order with other
    # syslog messages from pump (dhcp client).
    /sbin/ifconfig $iface 2>&1 | mesgr
    echo "doing ifdown $iface" | mesgr
    /sbin/ifdown $iface 2>&1 | mesgr
    # still might be pppd's hanging around,
    # perhaps due to repeated ifups? Kill 'em.
    if [[ $iface == ppp* ]]; then
        sleep 2
        pkill -9 pppd 2>&1 | mesgr
        sleep 2
    fi
    echo "doing ifup $iface" 2>&1 | mesgr
    /sbin/ifup $iface 2>&1 | mesgr
    sleep 1 
}

ifstate=`get_if_state`
addr=`get_if_addr`

case $ifstate in
UP)
    case $addr in
    ${subnet}.*)
        ;;
    *)
        echo "$iface has incorrect address: $addr" | mesgr
        fix_if
        ;;
    esac
    ;;
*)
    fix_if
    ;;
esac

logfile=$(mktemp /tmp/${script}_XXXXXX)
if ! check_ping > $logfile 2>&1; then
    cat $logfile | mesgr
    rm $logfile         
    echo "Exiting, failed" | mesgr
    exit 1
fi
rm $logfile         

exit 0

