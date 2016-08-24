#! /usr/bin/python

import serial
import pexpect
import pexpect.fdpexpect
import select
import time
import re
import StringIO
import sys

"""
The LICOR can print the serial number and coefficients with the right command, and the response is something like this:

(Current (SerialNo "75H-1167")(CO2 (XS 1.0000001e-3)(Z -3.3000001e-3)(A 1.6172599e2)(B 1.2099599e4)(C 5.3524599e7)(D -1.8142200e10)(E 2.5890598e12))(H2O (XS -1.2999999e-3)(Z 1.6100001e-2)(A 5.5414705e3)(B 4.5327701e6)(C -2.8575501e8))(Band (A 1.1499999))(Pressure (A0 1.0353000e1)(A1 2.6036000e1)))
"""

import logging

logger = logging.getLogger(__name__)


perdigao_config = """\
(Outputs (BW 20)(Delay 0) (RS232 (EOL "0A") (Labels FALSE) (DiagRec FALSE) (Ndx FALSE) (Aux FALSE) (Cooler FALSE) (CO2Raw TRUE) (CO2D TRUE) (H2ORaw TRUE) (H2OD TRUE) (Temp  TRUE) (Pres TRUE) (DiagVal TRUE) (Freq 20.0) (Baud 19200)))"""

class LicorException(Exception):
    pass


class LValue:
    """The base class is for plain strings.  Subclasses implement types
    with special handling, like boolean and floats.
    """

    def __init__(self, value):
        self.value = None
        self.set(value)

    def set(self, value):
        self.value = value

    def parse(self, text):
        "Set this value by parsing the text."
        self.value = text

    def build(self):
        "Return the string form built from this value."
        return self.value

class LBoolean(LValue):

    def parse(self, text):
        self.value = bool(text == "TRUE")

    def build(self):
        return ["FALSE", "TRUE"][int(bool(self.value))]


class LInteger(LValue):

    def parse(self, text):
        self.value = int(text)

    def build(self):
        return "%d" % (self.value)


class LQuoted(LValue):

    def parse(self, text):
        self.value = text.strip('"')

    def build(self):
        return '"%s"' % (self.value)


class LFloat(LValue):

    def parse(self, text):
        self.value = float(text)

    def build(self):
        return "%g" % (self.value)


class LData(object):

    rxp = re.compile(r"(?P<diagval>%(number)s)\t(?P<co2raw>%(number)s)\t(?P<co2>%(number)s)\t"
                     r"(?P<h2oraw>%(number)s)\t"
                     r"(?P<h2o>%(number)s)\t(?P<tcell>%(number)s)\t(?P<pcell>%(number)s)\t\n" %
                     {'number':'[+-]?[0-9.]+'})

    def __init__(self, message=None):
        self.h2o = None
        self.h2oraw = None
        self.co2raw = None
        self.co2 = None
        self.pcell = None
        self.tcell = None
        if message:
            self.match(self.rxp.search(message))
        
    def match(self, rxm):
        if not rxm:
            return
        self.h2o = float(rxm.group('h2o'))
        self.h2oraw = float(rxm.group('h2oraw'))
        self.co2 = float(rxm.group('co2'))
        self.co2raw = float(rxm.group('co2raw'))
        # Convert pressure to hPa
        self.pcell = float(rxm.group('pcell')) * 10.0
        self.tcell = float(rxm.group('tcell'))
        self.diag = int(rxm.group('diagval'))
            
    def _check(self, name, value, limits):
        if not bool(limits[0] <= value <= limits[1]):
            raise LicorException("%s %g not in range [%g,%g]" %
                                 (name, value, limits[0], limits[1]))
        logger.info("%s checks out: %g <= %g <= %g" %
                    (name, limits[0], value, limits[1]))

    def validate(self):
        # From the Licor7500 wiki page and manual, ambient CO2
        # concentrations are around 400 ppm, which roughly corresponds
        # to an absorptance of 0.1.  So assuming the Licor is being
        # configured indoors, just make rough checks on co2raw, pcell
        # and tcell.  If nothing else it might catch the wrong fields
        # being enabled and parsed in the wrong place.
        self._check('co2raw', self.co2raw, [0.07, 0.13])
        self._check('pcell', self.pcell, [820, 1050])
        # The LICOR temperature appears to take some time to warm up.
        # It is often below 23 right after starting up but will
        # increase to above 23 in a few minutes.  Accept a low of 22
        # just to speed up vetting.
        self._check('tcell', self.tcell, [22, 28])
        # The diag value is one byte, where the 4 high bits should all be
        # 1, to indicate chopper, detector, PLL, and Sync are all
        # ok, in that order.  The low 4 bits are AGC(%)/6.25.
        # The manual says "clean window" values are 55-65%.
        self._check('diag', self.diag, [240,255])
        agc = float(self.diag & (0xf)) * 6.25
        self._check('agc%', agc, [25, 75])


class LICOR(object):

    def __init__(self, path=None):
        self.path = path
        # Use two dictionaries for the configuration, one for the
        # (Outputs) and one for (RS232), and only parse and set the
        # values that we care about it and might ever change.
        self.serialno = None
        self.coeffs = None
        self.outputs = {'BW':LInteger(20), 'Delay':LFloat(0)}
        self.rs232 = {'Baud':LValue('19200'),
                      'Freq':LFloat(20.0),
                      'Pres':LBoolean(True),
                      'Temp':LBoolean(True),
                      'Aux':LBoolean(False),
                      'Cooler':LBoolean(False),
                      'CO2Raw':LBoolean(True),
                      'H2ORaw':LBoolean(True),
                      'H2OD':LBoolean(True),
                      'Ndx':LBoolean(False),
                      'DiagVal':LBoolean(True),
                      'DiagRec':LBoolean(False),
                      'Labels':LBoolean(False),
                      'EOL':LQuoted('0A')}
        self.port = None
        self.xp = None
        if path:
            self.open(path)

    def open(self, path, cmode=True):
        "Open LICOR serial device, forcing 9600 baud if in command mode."
        if self.port:
            self.close()
        self.path = path
        logger.info("Opening LICOR on port %s" % (self.path))
        baudrate = 9600
        if not cmode:
            baudrate = int(self.rs232['Baud'].value)
        self.port = serial.Serial(self.path, baudrate, timeout=0, rtscts=True,
                                  bytesize=serial.EIGHTBITS,
                                  parity=serial.PARITY_NONE,
                                  stopbits=serial.STOPBITS_ONE)
        self.port.nonblocking()
        self.xp = pexpect.fdpexpect.fdspawn(self.port, timeout=10)

    def getSerialNumber(self):
        return self.serialno

    def dataBaudRate(self):
        return int(self.rs232['Baud'].value)

    def _parse_outputs(self, outputs):
        logger.info("Loading Outputs: %s" % (outputs))
        for config in [self.outputs, self.rs232]:
            for k in config.keys():
                match = re.search(r'\(%s ([^)]+)\)' % (k), outputs)
                if not match:
                    logger.error("Outputs parameter not found: %s" % (k))
                else:
                    config[k].parse(match.group(1))
                    logger.debug("Set outputs parameter %s=%s" % (k, str(config[k].value)))

    def _build_outputs(self):
        outputs = StringIO.StringIO()
        outputs.write('(Outputs ')
        for k,v in self.outputs.items():
            outputs.write('(%s %s)' % (k, v.build()))
        outputs.write('(RS232 ')
        for k,v in self.rs232.items():
            outputs.write('(%s %s)' % (k, v.build()))
        outputs.write("))")
        return outputs.getvalue()

    def send(self, text):
        logger.debug("Write: " + repr(text))
        self.port.write(text)
        self.port.flush()

    def read(self, timeout, log=True):
        "Read as much as possible until timeout expires."
        rdata = None
        bdata = ''
        start = time.time()
        end = start + timeout
        while start < end:
            rfds, wfds, xfds = select.select([self.port], [], [], end - start)
            if self.port in rfds:
                rdata = self.port.read(512)
                logger.debug("Read: " + repr(rdata))
                bdata += rdata
            else:
                logger.debug("No data.")
            start = time.time()
        if log:
            logger.info("Read returning: " + repr(bdata))
        return bdata

    def watch(self):
        while True:
            self.send("\r\n")
            self.read(1)

    def responsive(self):
        logger.info("Testing for response from LICOR.")
        self.send_break()
        # If the licor is now responding, we should get back the
        # expected message.
        self.send("\r\n")
        self.send("\r\n")
        xresult = self.xp.expect([r".*\(Error \(Received TRUE\)\)",
                                  pexpect.TIMEOUT, pexpect.EOF])
        if xresult != 0:
            raise LicorException("LICOR error response expected, not found.")
        logger.info("LICOR responsive.")
        return True

    def send_break(self):
        logger.debug("sending BREAK...")
        # Sending the break puts the LICOR in 9600 baud.
        self.port.baudrate = 9600
        # in pyserial 3.0 this becomes self.port.send_break()
        self.port.sendBreak(0.5)
        # Give LICOR several seconds to recover from BREAK.  5 seconds
        # is too short, 10 seems to work.
        self.read(10)
        # Attempt for 10 seconds to get something back
        for i in xrange(5):
            self.send("\r\n")
            cdata = self.read(2)
            if cdata:
                break

    def get_coeffs(self):
        logger.info("Querying coefficients and serial number...")
        self.send("(Coeffs (Current ?))\n")
        cpattern = r"\(Current \(SerialNo \"(?P<serialno>.*)\"\).*\)\)\)"
        xresult = self.xp.expect([cpattern, pexpect.TIMEOUT, pexpect.EOF])
        if xresult != 0:
            raise LicorException("Response to Coeffs command not found.")
        # Just cache the whole response and the serial number
        self.coeffs = self.xp.after
        self.serialno = self.xp.match.group('serialno')
        # Log the coefficients as well as serial number.
        logger.info("Coefficients: %s" % (self.coeffs))
        logger.info("Serial Number: %s" % (self.serialno))

    def configure_outputs(self):
        "Send the current configuration to the LICOR and verify it."
        logger.info("Configuring and verifying Outputs...")
        xouts = self._build_outputs()
        # Write directly so we can log what's being written.
        self.send(xouts + '\r\n')
        logger.debug("waiting for Ack...")
        # Technically the complete ack message includes (Val 0), but
        # that does not necessarily appear before the data messages
        # start.
        xresult = self.xp.expect([".*\(Ack \(Received TRUE\)",
                                  pexpect.TIMEOUT, pexpect.EOF])
        if xresult != 0:
            raise LicorException("Did not receive Ack from Outputs command.") 
        # The LICOR will start output, so send another break.
        self.send_break()
        # Pull the current outputs for comparison.
        self.xp.sendline("(Outputs ?)")
        xresult = self.xp.expect([r".*(\(Outputs .*\)\)\))",
                                  pexpect.TIMEOUT, pexpect.EOF])
        if xresult != 0:
            raise LicorException("Query for current Outputs failed.")
        licor = LICOR()
        licor._parse_outputs(self.xp.match.group(1))
        gotouts = licor._build_outputs()
        if xouts != gotouts:
            raise LicorException("Expected Outputs: '%s'; got Outputs '%s'" %
                                 (xouts, gotouts))
        logger.info("Outputs verified.")

    def start_data(self):
        "Switch to reading data messages."
        # Assuming the LICOR was in command mode, we need to send it a
        # simple Outputs command to start it back up, and then switch
        # to the data baud rate.
        baudrate = self.dataBaudRate()
        logger.info("Starting data messages and switching "
                    "to baudrate %s..." % (baudrate))
        # If we were opened in the data baud rate but now want to send
        # a command, then we have to switch back.
        if self.port.baudrate != 9600:
            self.send_break()
        self.send("(Outputs (BW %s))\n" % (self.outputs['BW'].build()))
        # Just writing to baudrate does not appear to be reliable.
        logger.info("Resetting baud rate...")
        self.port.baudrate = baudrate
        time.sleep(3)

    def validate_data(self):
        logger.info("Validating data message...\n" +
                    "\n".join(self.read(0.2, False).splitlines()[-5:]))
        ldata = LData()
        xresult = self.xp.expect([ldata.rxp, pexpect.TIMEOUT, pexpect.EOF])
        i = 0
        while xresult != 0 and i < 2:
            i += 1
            logger.info("...trying to start data messages...")
            self.start_data()
            xresult = self.xp.expect([ldata.rxp, pexpect.TIMEOUT, pexpect.EOF])
        if xresult != 0:
            raise LicorException("No data messages received.")
        print(self.xp.after)
        print(self.xp.match.groupdict())
        ldata.match(self.xp.match)
        ldata.validate()
        logger.info("Data validation passed.")

    def close(self):
        self.port.close()
        self.port = None
        self.xp = None


import pytest

_outputs = """\
(Outputs (BW 5)(Delay 0.1)(SDM (Address 7))(Dac1 (Source NONE)(Zero 0)(Full 5))(Dac2 (Source NONE)(Zero 0)(Full 5))(RS232 (Baud 9600)(Freq 1)(Pres TRUE)(Temp TRUE)(Aux TRUE)(Cooler TRUE)(CO2Raw TRUE)(CO2D TRUE)(H2ORaw TRUE)(H2OD TRUE)(Ndx TRUE)(DiagVal TRUE)(DiagRec TRUE)(Labels TRUE)(EOL "0B")))"""

_built_outputs = """\
(Outputs (BW 5)(Delay 0.1)(RS232 (Baud 9600)(Freq 1)(Pres TRUE)(Temp TRUE)(Aux TRUE)(Cooler TRUE)(CO2Raw TRUE)(CO2D TRUE)(H2ORaw TRUE)(H2OD TRUE)(Ndx TRUE)(DiagVal TRUE)(DiagRec TRUE)(Labels TRUE)(EOL "0B")))"""

def test_output_parsing():
    licor = LICOR()
    licor._parse_outputs(_outputs)
    assert(licor.outputs['BW'].value == 5)
    assert(licor.outputs['Delay'].value == 0.1)
    assert(licor.rs232['Labels'].value == True)
    assert(licor.rs232['EOL'].value == '0B')
    assert(licor.rs232['DiagRec'].value == True)

def test_build_outputs():
    licor = LICOR()
    licor._parse_outputs(_outputs)
    licor2 = LICOR()
    licor2._parse_outputs(licor._build_outputs())
    assert(licor2.rs232['EOL'].value == '0B')
    assert(licor._build_outputs() == licor2._build_outputs())


_data_message = "249\t0.08600\t15.4452\t0.04727\t326.019\t25.89\t84.0\t\n"

def test_ldata():
    ldata = LData(_data_message)
    assert(ldata.pcell == 840)
    assert(ldata.tcell == 25.89)
    ldata.validate()
    with pytest.raises(Exception):
        ldata.pcell = 800
        ldata.validate()
    ldata = LData(_data_message)
    with pytest.raises(Exception):
        ldata.co2raw = 0.05
        ldata.validate()
    ldata = LData(_data_message)
    with pytest.raises(Exception):
        ldata.tcell = 29
        ldata.validate()


def main():
    logging.basicConfig(level=logging.INFO)
    if len(sys.argv) < 2:
        print("Usage: licor.py <device> [config|data]")
        sys.exit(1)
    device = sys.argv[1]
    op = 'config'
    if len(sys.argv) > 2:
        op = sys.argv[2]
    try:
        if op == 'config':
            licor = LICOR(device)
            licor.responsive()
            licor.get_coeffs()
            licor.configure_outputs()
            licor.start_data()
            licor.validate_data()
            print("Done with LICOR %s." % (licor.getSerialNumber()))
        elif op == 'data':
            licor = LICOR()
            licor.open(device, False)
            licor.validate_data()
        licor.close()
        sys.exit(0)
    except LicorException, le:
        print("LICOR Error: %s" % (str(le)))
        sys.exit(1)

if __name__ == "__main__":
    main()
    
