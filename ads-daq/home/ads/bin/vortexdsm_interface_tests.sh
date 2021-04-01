#!/bin/bash
# Run series of VortexDSM Interface Tests

# Prompt Test Setup
echo "-------------------------------------------------------"
echo "DSM Interfaces must have these Test Fixtures Installed:"
echo "  S1 I/O Loopback Dongle"
echo "  S2 RS-232 Loopback Dongle"
echo "  S3 RS-422 Loopback Dongle"
echo "  S4 RS-232 Loopback Dongle"
echo "  A0 Loopback Dongle"
echo "  A1 to A2 Supply Bridge Cable"
echo "  USB0 Passmark PMUSB02 Loopback Tester"
echo "  USB1 Passmark PMUSB02 Loopback Tester"
echo "-------------------------------------------------------"

# dsm process must not be running on DSM
DSMPID=$(pidof dsm)
DSMRUNNING=!$?
if (($DSMRUNNING))
then
    echo "SCRIPT FAILED: Must close dsm process"
    kill $DSMPID
    echo "  dsm process killed ... try running script again"
    exit 1
fi

# status packets to be sent to acserver
IPADDR='192.168.84.2'
IPPORT='40000'

echo "--> Tests Started <--"
TSTAMP=`date`
echo $TSTAMP
echo $TSTAMP > /dev/udp/$IPADDR/$IPPORT
FAIL=0

# Serial Port Tests, PCM-C418 Native
#   ttyS2 no test, not connected to DSM faceplate
#   ttyS3 no test, Console
#   ttyS4 no test, doesnt exist
for PORT in 0 1
do
    OUTPUT=$(../bin/serial_loopback_test -T 10 -b 115200 -d /dev/ttyS${PORT})
    FAIL=$(($FAIL||$?))
    echo $OUTPUT
    echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT
done

# Test Winsystems PCM-COM-8 serial ports (mapped to ttyS[5:12])
#for PORT in 5 6 7 8 9 10 11 12
#do
#    OUTPUT=$(/opt/nidas/bin/serial_loopback_test -T 10 -b 115200 -d /dev/ttyS${PORT})
#    FAIL=$(($FAIL||$?))
#    echo $OUTPUT
#    echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT
#done

# Test ConnectTech XT007-01 ttyCTI[0:11] Serial Ports
for PORT in 0 1 2 3 4 5 6 7 8 9 10 11
do
    OUTPUT=$(../bin/serial_loopback_test -T 10 -b 115200 -d /dev/ttyCTI${PORT})
    FAIL=$(($FAIL||$?))
    echo $OUTPUT
    echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT
done

# Analog A0 & A1 Port Tests with DAC Loopback
../bin/dmd_mmat_vout_const -w 0,2.5 -d /dev/dmmat_d2a0
OUTPUT=$(../bin/dmd_mmat_vin_limit_test -N 8 -F 100 -H 2.51 -L 2.49 -d /dev/dmmat_a2d0)
FAIL=$(($FAIL||$?))
echo $OUTPUT
echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT
../bin/dmd_mmat_vout_const -w 0,0 -d /dev/dmmat_d2a0 

# A2 Supplies to A1 Analog Ports Test
# Ch.8,9=24V/3=8V, Ch.11,12,13=12V/2=6V, Ch.14,15=5V, 5% tolerance
PORT=(8 9 10 11 12 13 14)
LIM_HIGH=(8.4 8.4 6.3 6.3 6.3 5.25 5.25)
LIM_LOW=(7.6 7.6 5.7 5.7 5.7 4.75 4.75)
for ((i=0;i<${#PORT[@]};i++))
do
    OUTPUT=$(../bin/dmd_mmat_vin_limit_test -w -C ${PORT[$i]} -H ${LIM_HIGH[$i]} -L ${LIM_LOW[$i]} -d /dev/dmmat_a2d0)
    FAIL=$(($FAIL||$?))
    echo $OUTPUT
    echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT
done

# DIO Tests
OUTPUT=$(../bin/pcmc418_dio_loopback_test)
FAIL=$(($FAIL||$?))
echo $OUTPUT
echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT

# USB Tests
#    Test Channel 0
OUTPUT=$(../bin/usb_pmusb02_loopback_test 0)
FAIL=$(($FAIL||$?))
echo $OUTPUT
echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT
#    Test Channel 1
OUTPUT=$(../bin/usb_pmusb02_loopback_test 1)
FAIL=$(($FAIL||$?))
echo $OUTPUT
echo $OUTPUT > /dev/udp/$IPADDR/$IPPORT

echo "--> Tests Finished <--"
if (($FAIL!=0))
then
    echo "ALLTESTS: $TSTAMP FAILED" > /dev/udp/$IPADDR/$IPPORT
else
    echo "ALLTESTS: $TSTAMP SUCCESS" > /dev/udp/$IPADDR/$IPPORT
fi

exit 0
