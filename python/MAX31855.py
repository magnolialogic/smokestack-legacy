#!/usr/bin/python

# MAX31855.py

import time
import math
import spidev
import SmokeLog

class MAX31855:

	def __init__(self,cs):
		self.cs = cs
		self.spi = spidev.SpiDev()
		self.spi.open(0,cs)
		self.spi.max_speed_hz = 7629
		self.spi.mode = 0b01
		self.temperature = self.read()

	def _read32(self):
		raw = self.spi.readbytes(4)
		if raw is None or len(raw) !=4:
			SmokeLog.common.error('SPI Error, did not read expected number of bytes!')
		value = raw[0] << 24 | raw [1] << 16 | raw[2] << 8 | raw[3]
		# SmokeLog.common.debug('Raw value: 0x{0:08X}'.format(value & 0xFFFFFFFF))
		return value

	def readInternal(self):
		v = self._read32()
		# Ignore bottom 4 bits of thermocouple data.
		v >>= 4
		# Grab bottom 11 bits as internal temperature data.
		internal = v & 0x7FF
		if v & 0x800:
			# Negative value, take 2's compliment. Compute this with subtraction
			# because python is a little odd about handling signed/unsigned.
			internal -= 4096
		# Scale by 0.0625 degrees C per bit and return value.
		return internal * 0.0625

	def read(self):
		v = self._read32()

		# Check for error reading value.
		if v & 0x7:
			#return float('NaN')
			SmokeLog.common.info('MAX31855: No thermocouple detected.')
			return 0
		# Check if signed bit is set.
		if v & 0x80000000:
			# Negative value, take 2's compliment. Compute this with subtraction
			# because python is a little odd about handling signed/unsigned.
			v >>= 18
			v -= 16384
		else:
			# Positive value, just shift the bits to get the value.
			v >>= 18
		# Scale by 0.25 degrees C per bit and return value.
		temp = float(format((v * 0.25) * 1.8 + 32, '.2f'))
		SmokeLog.common.info('MAX31855: {}F'.format(temp))
		return temp

	def readState(self):
		v = self._read32()
		return {
		'openCircuit': (v & (1 << 0)) > 0,
		'shortGND': (v & (1 << 1)) > 0,
		'shortVCC': (v & (1 << 2)) > 0,
		'fault': (v & (1 << 16)) > 0
		}

	def readLinearizedTempC(self):
		# MAX31855 thermocouple voltage reading in mV
		thermocoupleVoltage = (self.readTempC() - self.readInternalC()) * 0.041276
		# MAX31855 cold junction voltage reading in mV
		coldJunctionTemperature = self.readInternalC()
		coldJunctionVoltage = (-0.176004136860E-01 +
			0.389212049750E-01  * coldJunctionTemperature +
			0.185587700320E-04  * math.pow(coldJunctionTemperature, 2.0) +
			-0.994575928740E-07 * math.pow(coldJunctionTemperature, 3.0) +
			0.318409457190E-09  * math.pow(coldJunctionTemperature, 4.0) +
			-0.560728448890E-12 * math.pow(coldJunctionTemperature, 5.0) +
			0.560750590590E-15  * math.pow(coldJunctionTemperature, 6.0) +
			-0.320207200030E-18 * math.pow(coldJunctionTemperature, 7.0) +
			0.971511471520E-22  * math.pow(coldJunctionTemperature, 8.0) +
			-0.121047212750E-25 * math.pow(coldJunctionTemperature, 9.0) +
			0.118597600000E+00  * math.exp(-0.118343200000E-03 * math.pow((coldJunctionTemperature-0.126968600000E+03), 2.0)))
		# cold junction voltage + thermocouple voltage
		voltageSum = thermocoupleVoltage + coldJunctionVoltage
		# calculate corrected temperature reading based on coefficients for 3 different ranges
		# float b0, b1, b2, b3, b4, b5, b6, b7, b8, b9, b10;
		if thermocoupleVoltage < 0:
			b0 = 0.0000000E+00
			b1 = 2.5173462E+01
			b2 = -1.1662878E+00
			b3 = -1.0833638E+00
			b4 = -8.9773540E-01
			b5 = -3.7342377E-01
			b6 = -8.6632643E-02
			b7 = -1.0450598E-02
			b8 = -5.1920577E-04
			b9 = 0.0000000E+00
		elif thermocoupleVoltage < 20.644:
			b0 = 0.000000E+00
			b1 = 2.508355E+01
			b2 = 7.860106E-02
			b3 = -2.503131E-01
			b4 = 8.315270E-02
			b5 = -1.228034E-02
			b6 = 9.804036E-04
			b7 = -4.413030E-05
			b8 = 1.057734E-06
			b9 = -1.052755E-08
		elif thermocoupleVoltage < 54.886:
			b0 = -1.318058E+02
			b1 = 4.830222E+01
			b2 = -1.646031E+00
			b3 = 5.464731E-02
			b4 = -9.650715E-04
			b5 = 8.802193E-06
			b6 = -3.110810E-08
			b7 = 0.000000E+00
			b8 = 0.000000E+00
			b9 = 0.000000E+00
		else:
			SmokeLog.common.error('Thermocouple voltage out of range!')
			return 0
		return (b0 +
			b1 * voltageSum +
			b2 * pow(voltageSum, 2.0) +
			b3 * pow(voltageSum, 3.0) +
			b4 * pow(voltageSum, 4.0) +
			b5 * pow(voltageSum, 5.0) +
			b6 * pow(voltageSum, 6.0) +
			b7 * pow(voltageSum, 7.0) +
			b8 * pow(voltageSum, 8.0) +
			b9 * pow(voltageSum, 9.0))