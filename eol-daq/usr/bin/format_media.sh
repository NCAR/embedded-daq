#!/bin/bash

# partition and make ext4 file systems on a device, generally a
# SD or CF flash card, or a USB flash.

# Note, there are posts on the net about optimizing the partitioning,
# the ext4 file system and the mount options for a given type of SD card.
# https://blogofterje.wordpress.com/2012/01/14/optimizing-fs-on-sd-card/
# The "flashbench" program is apparently a useful tool.
# None of that is done here.

usage() {
    echo "${0##*/} device [sizeMiB]"
    echo "sizeMiB is the size of the first partition."
    echo "    The rest of the disk will be allocated to the second partition"
    echo "    If sizeMiB is not specified, the whole disk will be allocated"
    echo "    to one partition.  In this case, an attempt will be made"
    echo "    to mount the disk as /media/usbdisk, and the permissions set to 777."
    echo "Example: ${0##*/} /dev/sda"
    exit 1
}

[ $# -lt 1 ] && usage
dev=$1

sizemb=0
[ $# -gt 1 ] && sizemb=$2

mmcdev=false
if [[ $dev =~ /dev/mmcblk.* ]]; then
    mmcdev=true
    if [[ $dev =~ .*p[0-9] ]]; then
        echo "Error: device name should not contain a partition number"
        echo "For example:  use /dev/mmcblk0 rather than /dev/mmcblk0p1"
        exit 1
    fi
elif [[ $dev =~ /dev/sd.* ]]; then
    if [[ $dev =~ .*[0-9] ]]; then
        echo "Error: device name should not contain a partition number"
        echo "For example:  use /dev/sdc rather than /dev/sdc1"
        exit 1
    fi
else
    echo "Unknown disk type: $dev"
    exit 1
fi

partition_media.sh $dev $sizemb || exit 1

sudo partprobe -s $dev

sleep 2

# In sfdisk 2.25.2, --verify option doesn't work, use -V
echo "Doing sfdisk -V $dev"
sudo sfdisk -V $dev || exit 1

declare -A pdevs
if $mmcdev; then
    if [ $sizemb -gt 0 ]; then
        pdevs[root]="${dev}p1"
        pdevs[home]="${dev}p2"
    else
        pdevs[data]="${dev}p1"
    fi
else
    if [ $sizemb -gt 0 ]; then
        pdevs[root]="${dev}1"
        pdevs[home]="${dev}2"
    else
        pdevs[data]="${dev}1"
    fi
fi


for label in ${!pdevs[*]}; do
    pdev=${pdevs[$label]}
    if mount | fgrep -q $pdev; then
        echo "Error: $pdev is mounted!"
        echo "Doing: umount $pdev"
        umount $pdev || exit 1
        mount | fgrep $pdev && exit 1
    fi

    echo "doing mkfs.ext4 -L $label $pdev"
    sudo mkfs.ext4 -L $label $pdev
    # For a data disk, try to mount it as /media/usbdisk,
    # and set permissions to 777
    if [ "$label" == data ]; then
        if mount /media/usbdisk; then
            sudo chmod 777 /media/usbdisk
            umount /media/usbdisk
        fi
    fi
done
