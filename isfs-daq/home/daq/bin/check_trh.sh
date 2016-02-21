#!/bin/sh

# Pipe real-time output from rserial to awk to check for bad temperature values.
# Cycle power on TRH if temperature is out of range.

script=${0##*/}

if [ $# -lt 1 ]; then
    echo "Usage $script port"
    echo "e.g.: $script 5"
    exit 1
fi

port=$1

mach=titan
uname -r | fgrep -q viper && mach=viper

# mktemp on AEL fails if the template string ends with .awk
# perhaps doesn't like two file extensions: .sh and .awk
awkcom=$(mktemp /tmp/${script}_XXXXXX)
trap "{ rm -f $awkcom; }" EXIT

# errlog=$(mktemp /tmp/${script}_XXXXXX.log)
# trap "{ rm -f $awkcom $errlog; }" EXIT

cat << EOD > $awkcom
BEGIN {
    if ( $port >= 5) {
        iocmd = "eio"
    }
    else if ( "$mach" == "viper" ) {
        iocmd = "vio"
    }
    else {
        iocmd = "tio"
    }
    powcmd = iocmd " $port 0; sleep 2; " iocmd " $port 1"
    skip = 0
}
# format of output from TRH via rserial
# TRH3 13.63 31.68 29 0 1341 64 92\r\n
/^TRH[0-9]+ *[0-9.+-]+ *[0-9.+-]+ *[0-9.+-]+/ && NF > 3 {
    temp=\$2
    ifan=\$4
    if (skip == 0) {
        # print "temp=",temp,", ifan=",ifan
        if (temp > 50 || temp < -50) {
            print "temperature is",temp,". Power cycling port $port" > "/dev/stderr"
            stat = system(powcmd)
            print powcmd,"status=",stat > "/dev/stderr"
            skip = 10
        }
        else if (ifan < 10) {
            print "Ifan is",ifan,". Power cycling port $port" > "/dev/stderr"
            stat = system(powcmd)
            print powcmd,"status=",stat > "/dev/stderr"
            skip = 10
        }
    }
    else skip--
}
EOD

rserial -n /dev/ttyS$port localhost | awk -f $awkcom
