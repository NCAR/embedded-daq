#!/usr/bin/env python3

''' Configure a Roving Networks bluetooth radio, from a serial port.
'''

# from __future__ import absolute_import
# from __future__ import print_function
# from __future__ import unicode_literals

import os, sys, getopt, subprocess, string
import serial, pexpect
import pexpect.fdpexpect as fdpexpect

CMDMODE = '$$$'
DATAMODE = '---\r\n'
COMMAND_RESP = 'CMD'
DATA_RESP = 'END'
OK_RESP = 'AOK'
ERR_RESP = 'ERR'

# SA,2  (SSP "just works" mode)
# SA,0  (open mode)
# SL,N  (no UART parity)
# SM,0  (slave mode)
# SN,MyDevice   (device name)
# SP, 0123 (pin code)
# ST,N
#       N=0 no remote configuration
#       N=1-252: time in seconds from powerup to allow configuration
#       N=253, continuous config, local only
#       N=254, continuous config, remote only
#       N=255, continuous config, local and remote
#       want
# SU,115K
# SW,0000   # disable low power sniff,
#   N       # wake up every N*625usec, for N in hex
# SY,hex    # transmit power
#           # hex 0010: power dBM =16
#           # hex 000C: power dBM =12
#           # hex 0008: power dBM =8
#           # hex 0004: power dBM =4
#           # hex 0000: power dBM =0
#           # hex FFFC: power dBM =-4
#           # hex FFF8: power dBM =-8
#           # hex FFF4: power dBM =-12
# S~,0      # SPP, no modem
# S-,<string>   # friendly name
# S$,x      # escape character x
# S|,sleep mode

class CmdException(Exception):
    """Derived exception."""
    def __init__(self, value):
        """ """
        super(CmdException, self).__init__(value)
        self.value = value

    def __str__(self):
        """ """
        return repr(self.value)

def stop_getty():
    """."""
    return subprocess.call(
        ['systemctl', 'stop', 'serial-getty@ttyAMA0.service'])


def start_getty():
    """."""
    return subprocess.call(
        ['systemctl', 'start', 'serial-getty@ttyAMA0.service'])

def exit_with_usage():
    """."""
    print("quack")

def main():
    """."""
    # default term ttyAMA0
    # default stop serial-getty@ttyAMA0

    try:
        optlist, args = getopt.getopt(sys.argv[1:], 'h?cgn:t:', ['help', 'h', '?'])
    except Exception as exc:
        print(str(exc))
        exit_with_usage()

    options = dict(optlist)

    if len(args) > 1:
        exit_with_usage()

    if [elem for elem in options if elem in ['-h', '--h', '-?', '--?', '--help']]:
        print("Help:")
        exit_with_usage()

    name = os.uname()[1]
    if '-n' in options:
        name = options['-n']

    tty = '/dev/ttyAMA0'
    if '-t' in options:
        tty = options['-t']

    start_stop_getty = True
    if '-g' in options:
        start_stop_getty = False

    show_config = False
    if '-c' in options:
        show_config = True

    if start_stop_getty:
        stop_getty()

    # open serial port
    sport = serial.Serial(
        tty, 115200, timeout=2, parity=serial.PARITY_NONE, rtscts=0)
    # print(sport.name)         # check which port was really used
    # sport.write(b'hello')     # write a string
    # sport.close()             # close port

    try:
        pexp = fdpexpect.fdspawn(
            sport, args=None, timeout=1,
            maxread=2000, searchwindowsize=None, logfile=None)

        cmd_mode(pexp)
        cfg = get_config(pexp)
        if show_config:
            print(repr(cfg))

        # Only change things that need to be changed.
        if cfg['Mode'] != 'Slav':
            print("setting Slave mode")
            cmd = 'SM,0'
            send_command(pexp, cmd)

        if cfg['BTName'] != name:
            print("setting name")
            cmd = 'SN,' + name
            send_command(pexp, cmd)

    except CmdException as exc:
        print(exc)
    finally:
        data_mode(pexp)
        sport.close()

    if start_stop_getty:
        start_getty()

def send_command(pexp, cmd):
    """Send command to radio, check response."""
    pexp.sendline(cmd)
    i = pexp.expect([pexpect.TIMEOUT, ERR_RESP, OK_RESP])
    if i == 0:  # Timeout
        raise CmdException('ERROR: no response after sending %s' % [cmd])
    if i == 1:  # ERR
        raise CmdException('ERROR: ERR response after sending %s' % [cmd])

def cmd_mode(pexp):
    """Put radio in command mode."""
    pexp.send(CMDMODE)
    i = pexp.expect([pexpect.TIMEOUT, COMMAND_RESP])
    if i == 0:  # Timeout
        raise CmdException('ERROR: timeout in getting %s after sending %s' % (COMMAND_RESP, CMDMODE))

def data_mode(pexp):
    """Put radio back in data mode."""
    pexp.send(DATAMODE)
    i = pexp.expect([pexpect.TIMEOUT, DATA_RESP])
    if i == 0:  # Timeout
        raise CmdException('ERROR: timeout in getting %s after sending %s' % (DATA_RESP, CMDMODE))

def get_config(pexp):
    """Get current configuration as a dictionary."""

    cmd = 'x'
    pexp.sendline(cmd)
    i = pexp.expect([pexpect.TIMEOUT], timeout=1)
    cfg = pexp.before.decode("utf-8")
    # print(repr(cfg))

    cfg = cfg.split('\r\n')
    # print(repr(cfg))

    # remove first two lines
    cfg = [cfg[i][:] for i in range(2, len(cfg))]
    # print("removed 2")
    # print(repr(cfg))

    # remove all that start with '*'
    cfg = [c for c in cfg if len(c) > 0 and c[0] != '*']
    # print("removed *")
    # print(repr(cfg))

    # split at =
    cfg = [ c.split('=') for c in cfg]
    # print("split")
    # print(repr(cfg))

    # make a dictionary
    cfg = {c[0].strip(): c[1].strip() for c in cfg}
    # print(repr(cfg))

    return cfg

if __name__ == '__main__':
    main()
