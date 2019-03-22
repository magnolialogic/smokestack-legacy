#!/bin/python

# MAX31865.py

import time
import math
import spidev
import SmokeLog

class MAX31865:

	def __init__(self,cs):
		self.cs = cs
		self.R_0 = 1000
		self.R_ref = 4300
		self.A = 3.90830e-3
		self.B = -5.775e-7
		self.spi = spidev.SpiDev()
		self.spi.open(0,cs)
		self.spi.max_speed_hz = 7629
		self.spi.mode = 0b01
		self.config()
		self.temperature = self.read()

	def config(self):
		# Config register map:
		#  V_Bias (1 = On)
		#  Conversion Mode (1 = Auto)
		#  1-Shot (0 = Off)
		#  3-Wire (0 = Off)
		#  Fault Detection (0 = Off)
		#  Fault Detection (0 = Off)
		#  Clear Faults (1 = On)
		#  50/60Hz (0 = 60 Hz)
		config = 0b11000010 # 0xC2
		self.spi.xfer2([0x80,config])
		time.sleep(0.25)

	def read(self):
		MSB = self.spi.xfer2([0x01,0x00])[1]
		LSB = self.spi.xfer2([0x02,0x00])[1]
		
		#Check fault
		if LSB & 0b00000001:
			SmokeLog.common.error('Fault detected on SPI {}'.format(self.cs))
			self.GetFault()
		
		ADC = ((MSB<<8) + LSB) >> 1 #Shift MSB up 8 bits, add to LSB, remove fault bit (last bit)
		R_T = float(ADC * self.R_ref)/(2**15)
		
		#print R_T
		try:
			T = self.Resistance2Temp(R_T)
		except:
			T = 0
		SmokeLog.common.info('MAX31865: {}F'.format(T))
		return T
		
	def Resistance2Temp(self, R_T):
		R_0 = self.R_0
		A = self.A
		B = self.B
		
		Tc = (-A + math.sqrt(A*A - 4*B*(1-R_T/R_0)))/(2*B)
		Tf = Tc*9/5 + 32

		result = float(format(Tf, '.2f'))
		return result
			
	def GetFault(self):
		Fault = self.spi.xfer2([0x07,0x00])[1]

		if Fault & 0b10000000:
			SmokeLog.common.error('SPI {} Fault: RTD High Threshold'.format(self.cs))
		if Fault & 0b01000000:
			SmokeLog.common.error('SPI {} Fault: RTD Low Threshold'.format(self.cs))
		if Fault & 0b00100000:
			SmokeLog.common.error('SPI {} Fault: REFIN- > 0.85 x V_BIAS'.format(self.cs))
		if Fault & 0b0001000:
			SmokeLog.common.error('SPI {} Fault: REFIN- < 0.85 x V_BIAS (FORCE- Open)'.format(self.cs))
		if Fault & 0b00001000:
			SmokeLog.common.error('SPI {} Fault: RTDIN- < 0.85 x V_BIAS (FORCE- Open)'.format(self.cs))
		if Fault & 0b00000100:
			SmokeLog.common.error('SPI {} Fault: Overvoltage/undervoltage fault'.format(self.cs))
			
	def close(self):
		self.spi.close()