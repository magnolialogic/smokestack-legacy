import syslog
import sys
import time

class SmokeLog:
	
	def __init__(self):
		syslog.openlog('smokestack', 0, syslog.LOG_DAEMON)
	
	def debug(self, logMessage):
		sender = sys._getframe(1).f_code.co_name
		logString = "{}: {}".format(sender, logMessage)
		syslog.syslog(syslog.LOG_DEBUG, logString)
		print logString
	
	def info(self, logMessage):
		sender = sys._getframe(1).f_code.co_name
		logString = "{}: {}".format(sender, logMessage)
		syslog.syslog(syslog.LOG_INFO, logString)
		print logString
	
	def notice(self, logMessage):
		sender = sys._getframe(1).f_code.co_name
		logString = "{}: {}".format(sender, logMessage)
		syslog.syslog(syslog.LOG_NOTICE, logString)
		print logString
	
	def error(self, logMessage):
		sender = sys._getframe(1).f_code.co_name
		logString = "{}: {}".format(sender, logMessage)
		syslog.syslog(syslog.LOG_ERR, logString)
		print logString

common = SmokeLog()