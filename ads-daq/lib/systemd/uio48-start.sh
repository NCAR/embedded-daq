#!/bin/sh

module="uio48"
device="uio48"
mode="666"

# Group: since distributions do it differently, look for wheel or use staff
if grep '^staff:' /etc/group > /dev/null; then
    group="staff"
else
    group="wheel"
fi

# invoke modprobe with all arguments
# j.carnes 5/2020 uio48 default io and irq conflicts, changing 
#/sbin/modprobe $module io=0x120 irq=10
/sbin/modprobe $module io=0x140 irq=15

chgrp $group /dev/${device}a
chmod $mode  /dev/${device}a

exit 0
