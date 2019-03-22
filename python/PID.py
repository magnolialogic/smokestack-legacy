import time
import SmokeLog

#PID controller based on proportional band in standard PID form https://en.wikipedia.org/wiki/PID_controller#Ideal_versus_standard_PID_form
# u = Kp (e(t)+ 1/Ti INT + Td de/dt)
# PB = Proportional Band
# Ti = Goal of eliminating in Ti seconds
# Td = Predicts error value at Td in seconds

class PID:
	def __init__(self,  PB, Ti, Td):
		self.calculate_gains(PB,Ti,Td)

		self.P = 0.0
		self.I = 0.0
		self.D = 0.0
		self.u = 0

		self.derv = 0.0
		self.inter = 0.0
		self.inter_max = abs(0.5/self.Ki)

		self.last = 150

		self.set_target(0.0)

	def calculate_gains(self,PB,Ti,Td):
		self.Kp = -1/PB
		self.Ki = self.Kp/Ti
		self.Kd = self.Kp*Td
		SmokeLog.common.debug('PB: {}, Ti: {}, Td: {} --> Kp: {}, Ki: {}, Kd: {}'.format(PB, Ti, Td, self.Kp, self.Ki, self.Kd))


	def update(self, current):
		#P
		error = current - self.set_point
		self.P = self.Kp*error + 0.5 #P = 1 for PB/2 under set_point, P = 0 for PB/2 over set_point

		#I
		dT = time.time() - self.last_update
		#if self.P > 0 and self.P < 1: #Ensure we are in the PB, otherwise do not calculate I to avoid windup
		self.inter += error*dT
		self.inter = max(self.inter, -self.inter_max)
		self.inter = min(self.inter, self.inter_max)

		self.I = self.Ki * self.inter

		#D
		self.derv = (current - self.last)/dT
		self.D = self.Kd * self.derv

		#PID
		self.u = self.P + self.I + self.D

		#Update for next cycle
		self.error = error
		self.last = current
		self.last_update = time.time()

		SmokeLog.common.debug('PID: Target: {}, Current: {}, Gains: ({}, {}, {}), Errors: ({}, {}, {}), Adjustments: ({}, {}, {}), PID: {}'.format(self.set_point, current, self.Kp, self.Ki, self.Kd, error, self.inter, self.derv, self.P, self.I, self.D, self.u))

		return self.u

	def	set_target(self, set_point):
		self.set_point = set_point
		self.error = 0.0
		self.inter = 0.0
		self.derv = 0.0
		self.last_update = time.time()
		SmokeLog.common.notice('New Target: {}'.format(set_point))

	def set_gains(self, PB, Ti, Td):
		self.calculate_gains(PB,Ti,Td)
		self.inter_max = abs(0.5/self.Ki)
		SmokeLog.common.debug('New Gains: ({}, {}, {})'.format(self.Kp, self.Ki, self.Kd))

	def get_k(self):
		return self.Kp, self.Ki, self.Kd
