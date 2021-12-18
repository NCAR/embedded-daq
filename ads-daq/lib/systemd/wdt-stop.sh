#!/bin/sh
  
module="wdt"

/sbin/lsmod | fgrep -q $module || exit 1
/sbin/modprobe -r $module
RETVAL="$?"

exit "$RETVAL"
