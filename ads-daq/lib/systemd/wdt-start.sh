#!/bin/sh

module="wdt"
device="wdt"
mode="666"

# Group: since distributions do it differently, look for wheel or use staff
if grep '^staff:' /etc/group > /dev/null; then
    group="staff"
else
    group="wheel"
fi

# invoke modprobe with all arguments
/sbin/modprobe $module

chgrp $group /dev/${device}
chmod $mode  /dev/${device}

exit 0
