import RPi.GPIO as GPIO
import time
import SmokeLog

class Traeger:
	
	def __init__(self, relays={'Auger': 16, 'Fan': 13, 'Igniter': 18}):
		self.relays = relays
		self.toggle_time = {}
		self.initialize()
		
	def initialize(self):
		SmokeLog.common.notice('Initializing Traeger.')
		GPIO.setwarnings(False)
		GPIO.setmode(GPIO.BCM)
		for k in self.relays.keys():
			GPIO.setup(self.relays[k],GPIO.OUT)
			self.set_state(k,False)
			self.toggle_time[k] = time.time()

	def get_state(self,relay):
		state = GPIO.input(self.relays[relay])
		if state == 0:
			return False
		elif state == 1:
			return True
	
	def set_state(self,relay,state):
		if not (self.get_state(relay) == state):
			SmokeLog.common.notice('Toggling {}: {} ({})'.format(relay, state, self.get_state(relay)))
			self.toggle_time[relay] = time.time()
			GPIO.output(self.relays[relay], state)