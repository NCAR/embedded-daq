#!/bin/bash

# Read /etc/rs4xx.conf and configure serial ports for 485, 422

# Currently supports the on-board serial ports on a WinSystem PCM-C418, Vortex
# https://www.winsystems.com/product/pcm-c418/

# See sections 6.8.5 and 6.8.7 discussing the COM ports:
# https://resources.winsystems.com/product-manuals/PCM-C418_v1_1-pm.pdf

cfdef=/etc/rs4xx.conf
usage() {
    echo "$0 [-d] [config]
  -d: debug, echo outb commands, but don't execute them
  config: name of configuraton file. Defaults to $cfdef"
    exit 1
}

cf=$cfdef
debug=false

while [ $# -gt 0 ]; do
    case $1 in
        -d)
            debug=true
            ;;
        -h)
            usage
            ;;
        *)
            cf=$1
            ;;
    esac
    shift
done

if [ ! -r $cf ]; then
    echo "$cf does not exist"
    exit 1
fi

vortex=false
fgrep -q Vortex86DX3 /proc/cpuinfo && vortex=true

! $debug && ! $vortex && { echo "$0 is currently only supported on a Vortex"; exit 1; }

rs4xx_options_vortex() {
    local dev=$1
    local opts="$2"
    local r1e9  # value to write to 0x1e9
    local r1eab # which of 0x1ea or 0x1eb to use
    local val=0x5 # value to write to 0x1ea or 0x1eb
    case $dev in
    /dev/ttyS0)
        r1e9=0x0
        r1eab=0x1ea
        ;;
    /dev/ttyS1)
        r1e9=0x0
        r1eab=0x1eb
        ;;
    /dev/ttyS2)
        r1e9=0x1
        r1eab=0x1ea
        ;;
    /dev/ttyS3)
        r1e9=0x1
        r1eab=0x1eb
        ;;
    *)
        echo "unknown device: $opt"
        ;;
    esac

    for opt in $opts; do
        case $opt in
            485)
                val=$(( ($val & 0xfc) + 0x2 ))
                ;;
            422)
                val=$(( ($val & 0xfc) + 0x3 ))
                ;;
            232)
                val=$(( ($val & 0xfc) + 0x1 ))
                ;;
            term)
                val=$(( ($val & 0xf7) + 0x8 ))
                ;;
            noterm)
                val=$(( ($val & 0xf7) ))
                ;;
            slew=norm)
                val=$(( ($val & 0xef) ))
                ;;
            slew=slow)
                val=$(( ($val & 0xef) + 0x10 ))
                ;;
            tx=auto)
                val=$(( ($val & 0xdf) + 0x20 ))
                ;;
            tx=rts)
                val=$(( ($val & 0xdf) ))
                ;;
            *)
                echo "unknown option: $opt"
                exit 1
                ;;
        esac
        $debug && printf "%s %#02x\n" $opt $val
        val=$(printf "%#02x" $val)
    done
    if $debug; then
        echo "outb 0x1e9 $r1e9"
        echo "outb $r1eab $val"
    else
        outb 0x1e9 $r1e9
        outb $r1eab $val
        echo "$dev $opts"
    fi
}

# read config file, discard comments
read_conf() {
    grep -v -E "^[[:space:]]*#" $1
}

while read dev options; do
    ( $debug || $vortex ) && rs4xx_options_vortex $dev "$options"
done < <(read_conf $cf)

