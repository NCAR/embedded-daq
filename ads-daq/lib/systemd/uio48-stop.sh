#!/bin/sh
  
module="uio48"

/sbin/lsmod | fgrep -q $module || exit 1
/sbin/modprobe -r $module
RETVAL="$?"

exit "$RETVAL"
