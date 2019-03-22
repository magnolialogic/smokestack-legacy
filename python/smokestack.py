#!/usr/bin/python





# IMPORTS





import os
import sys
import time
import datetime
import traceback
import json
import numpy as np
import RPi.GPIO as GPIO
import SmokeLog
import Traeger
import PID
import MAX31855
import MAX31865
from firebase import firebase





# METHODS





# Firebase

def reset_firebase(settings): # Nuke existing Firebase data and push default values to database
	try:
		r = firebase.put('/','settings', settings, params=fb_params)
#		r = firebase.delete('/','temp-history', params=fb_params)
		r = firebase.delete('/','PID', params=fb_params)
		r = firebase.delete('/','cook', params=fb_params)
		r = firebase.delete('/','timers', params=fb_params)
		r = firebase.delete('/','programs', params=fb_params)
	except Exception:
		SmokeLog.common.error('Failed to initialize database!')
		SmokeLog.common.error(traceback.format_exc())
		sys.exit(1)
	else:
		SmokeLog.common.notice('Successfully initialized database.')

	pid_defaults = {'Time': time.time()*1000, 'u': 0, 'P':0, 'I': 0, 'D': 0, 'PID': 0, 'Error': 0, 'Derv': 0, 'Inter': 0}

	try:
		r = firebase.post_async('/PID', pid_defaults, params=fb_params)
	except Exception:
		SmokeLog.common.error('Failed to push default values for /PID!')
		SmokeLog.common.error(traceback.format_exc())
		sys.exit(1)
	else:
		timers['LastSettingsPush'] = time.time()
		SmokeLog.common.info('Successfully pushed default values for /PID.')

def fetch_settings(settings, recent_temps, programs): # Fetches latest settings from Firebase
	if time.time() - timers['LastSettingsFetch'] > fetch_settings_timeout:
		try:
			fresh_settings = firebase.get('/settings', None)
		except Exception:
			SmokeLog.common.error('Failed to fetch latest settings from Firebase!')
			SmokeLog.common.error(traceback.format_exc())
			sys.exit(1)
		else:
			(settings, programs) = update_settings(fresh_settings, settings, recent_temps, programs)
			timers['LastSettingsFetch'] = time.time()
			SmokeLog.common.debug('Success.')

	return (settings, programs)

def push_settings(settings): # Pushes current settings to Firebase (async)
	for r in Smoker.relays:
		settings[r] = Smoker.get_state(r)
	try:
		r = firebase.patch_async('/settings', settings, params=fb_params)
	except Exception:
		SmokeLog.common.error('Failed to push new settings to Firebase!')
		SmokeLog.common.error(traceback.format_exc())
		sys.exit(1)
	else:
		timers['LastSettingsPush'] = time.time()
		SmokeLog.common.notice('Success.')

	return settings

def push_settings_sync(settings): # Pushes current settings to Firebase (sync)
	for r in Smoker.relays:
		settings[r] = Smoker.get_state(r)
	try:
		r = firebase.patch('/settings', settings, params=fb_params)
	except Exception:
		SmokeLog.common.error('Failed to push new settings to Firebase!')
		SmokeLog.common.error(traceback.format_exc())
		sys.exit(1)
	else:
		timers['LastSettingsPush'] = time.time()
		SmokeLog.common.notice('Success.')

	return settings

def fetch_programs(settings, programs): # Fetches program data from Firebase
	if time.time() - timers['LastProgramFetch'] > fetch_programs_timeout and settings['Program']:
		try:
			fetched_programs = firebase.get('/programs', None)
		except Exception:
			SmokeLog.common.error('Failed to fetch program data from Firebase!')
			SmokeLog.common.error(traceback.format_exc())
			sys.exit(1)
		else:
			timers['LastProgramFetch'] = time.time()
			SmokeLog.common.info('Success: {}'.format(fetched_programs))
			if fetched_programs is not None: # If program exists, check if it's new
				fresh_programs = []
				for item in sorted(fetched_programs.items()):
					fresh_programs.append(item)
				if programs != fresh_programs:
					SmokeLog.common.notice('Detected new program!')
					programs = fresh_programs
		
	return programs

def push_programs(programs): # Pushes program data to Firebase
	try:
		r = firebase.delete('/','programs', params=fb_params)
		for entry in programs:
			r = firebase.post('/programs', entry[1], params=fb_params)
	except Exception:
		SmokeLog.common.error('Failed to push program data to Firebase!')
		SmokeLog.common.error(traceback.format_exc())
		sys.exit(1)
	else:
		timers['LastProgramPush'] = time.time()
		SmokeLog.common.notice('Success.')

def push_recent_temps(settings, entry): # Pushes temperature history to Firebase
	try:
		r = firebase.post_async('/temp-history', {'Timestamp': entry[0]*1000, 'TargetGrill': settings['TargetGrill'], 'TargetFood': settings['TargetFood'], 'Grill': entry[1], 'Food':entry[2]}, params=fb_params)
	except Exception:
		SmokeLog.common.error('Failed to push new log entry to Firebase!')
		SmokeLog.common.error(traceback.format_exc())
		sys.exit(1)
	else:
		SmokeLog.common.debug('Success.')

# Smoker logic

def record_temps(settings, recent_temps): # Read temperature probes and update recent_temps
	if len(recent_temps) == 0 or time.time() - recent_temps[-1][0] > log_timeout:
		entry = [time.time()]
		for probe in probe_controller:
			entry.append(probe.read())
		recent_temps.append(entry)
		push_recent_temps(settings, entry)
		fresh_recent_temps = [] # Clean up oldest temperatures
		for entry in recent_temps:
			if time.time() - entry[0] < recent_temps_lifespan:
				fresh_recent_temps.append(entry)

		return fresh_recent_temps

	return recent_temps

def update_settings(fresh_settings, settings, recent_temps, programs): # Check whether remote settings contain any updates
	for k in fresh_settings.keys():
		if k == 'TargetGrill':
			if int(settings[k]) != int(fresh_settings[k]):
				if fresh_settings[k] == 0 and fresh_settings['Mode'] not in ['Off', 'Shutdown']:
					continue
				elif fresh_settings[k] != 0 and fresh_settings['Mode'] in ['Start', 'Hold', 'Smoke']:
					SmokeLog.common.notice('New setting! {} -- {} ({})'.format(k, float(fresh_settings[k]), settings[k]))
					PID.set_target(float(fresh_settings[k]))
					settings[k] = float(fresh_settings[k])
					settings = push_settings(settings)
		elif k == 'PB' or k == 'Ti' or k == 'Td':
			if float(settings[k]) != float(fresh_settings[k]):
				SmokeLog.common.notice('New setting! {} -- {} ({})'.format(k, float(fresh_settings[k]), settings[k]))
				settings[k] = float(fresh_settings[k])
				PID.set_gains(settings['PB'], settings['Ti'], settings['Td'])
				settings = push_settings(settings)
		elif k == 'PMode':
			if float(settings[k]) != float(fresh_settings[k]):
				SmokeLog.common.notice('New setting! {} -- {} ({})'.format(k, float(fresh_settings[k]), settings[k]))
				settings[k] = float(fresh_settings[k])
				settings = set_mode(settings, recent_temps)
				settings = push_settings(settings)
		elif k == 'Mode':
			if settings[k] != fresh_settings[k]:
				SmokeLog.common.notice('New setting! {} -- {} ({})'.format(k, fresh_settings[k], settings[k]))
				settings[k] = fresh_settings[k]
				settings = set_mode(settings, recent_temps)
				settings = push_settings(settings)
		elif k == 'Program':
			if settings[k] != fresh_settings[k]:
				SmokeLog.common.notice('New setting! {} -- {} ({})'.format(k, fresh_settings[k], settings[k]))
				if fresh_settings[k] == False and fresh_settings['Mode'] == 'Off':
					SmokeLog.common.notice('Program stopped and mode == Off, shutting down.')
					sys.exit(0)
				settings[k] = fresh_settings[k]
				timers['LastProgramFetch'] = time.time() - 10000
				programs = fetch_programs(settings, programs)
				settings = set_programs(settings, programs)
				break # Stop processing new settings

	return (settings, programs)

def set_mode(settings, recent_temps): # Operations for beginning of new mode
	if settings['Mode'] == 'Off':
		SmokeLog.common.notice('Setting mode to Off.')
		Smoker.initialize()
		Smoker.set_state('Fan',False)
		Smoker.set_state('Auger',False)
		Smoker.set_state('Igniter',False)
		settings['TargetFood'] = 0
		settings['TargetGrill'] = 0
		settings['Program'] = False
	elif settings['Mode'] == 'Shutdown':
		SmokeLog.common.notice('Setting mode to Shutdown.')
		Smoker.set_state('Fan',True)
		Smoker.set_state('Auger',False)
		Smoker.set_state('Igniter',False)
	elif settings['Mode'] == 'Start':
		SmokeLog.common.notice('Setting mode to Start.')
		Smoker.set_state('Fan',True)
		Smoker.set_state('Auger',True)
		Smoker.set_state('Igniter',True)
		timers['StartModeBegan'] = time.time()
		settings['CycleTime'] = 15+45
		settings['u'] = 15.0/(15.0+45.0) #P0
	elif settings['Mode'] == 'Smoke':
		SmokeLog.common.notice('Setting mode to Smoke.')
		Smoker.set_state('Fan',True)
		Smoker.set_state('Auger',True)
		check_igniter(settings, recent_temps)
		On = 15
		Off = 45 + settings['PMode']*10 #http://tipsforbbq.com/Definition/Traeger-P-Setting
		settings['CycleTime'] = On + Off
		settings['u'] = On / (On+Off)
	elif settings['Mode'] == 'Hold':
		SmokeLog.common.notice('Setting mode to Hold.')
		Smoker.set_state('Fan',True)
		Smoker.set_state('Auger',True)
		check_igniter(settings, recent_temps)
		settings['CycleTime'] = pid_cycle_timeout
		settings['u'] = u_min # Set to maintenance level

	push_settings(settings)
	return settings

def do_mode(settings, recent_temps): # Lifecycle operations per mode
	if settings['Mode'] == 'Shutdown':
		#if (time.time() - Smoker.toggle_time['Fan']) > shutdown_timeout:
		if (time.time() - timers['LastProgramToggle']) > shutdown_timeout:
			SmokeLog.common.notice('Shutdown timer fired, turning smoker off.')
			settings['Mode'] = 'Off'
			if len(programs) > 0:
				(settings, programs) = next_program(settings, programs)
			settings = set_mode(settings, recent_temps)
	elif settings['Mode'] == 'Start':
		do_auger_control(settings, recent_temps)
		Smoker.set_state('Igniter', True)
		if recent_temps[-1][1] > 120:
			SmokeLog.common.notice('Reached start mode temp limit, setting mode to Hold.')
			settings['Mode'] = 'Hold'
			settings = set_mode(settings, recent_temps)
		elif time.time() - timers['StartModeBegan'] > start_timeout:
			SmokeLog.common.notice('Start mode timeout fired, setting mode to Hold.')
			settings['Mode'] = 'Hold'
			settings = set_mode(settings, recent_temps)
	elif settings['Mode'] == 'Smoke':
		do_auger_control(settings, recent_temps)
	elif settings['Mode'] == 'Hold':
		settings = do_control(settings, recent_temps)
		do_auger_control(settings, recent_temps)

	return settings

def do_auger_control(settings, recent_temps): # Decisions and operations for auger
	if Smoker.get_state('Auger') and (time.time() - Smoker.toggle_time['Auger']) > settings['CycleTime']*settings['u']: # Auger currently on AND TimeSinceToggle > Auger On Time
		if settings['u'] < 1.0:
			Smoker.set_state('Auger', False)
			push_settings(settings)
		check_igniter(settings, recent_temps)

	if not Smoker.get_state('Auger') and (time.time() - Smoker.toggle_time['Auger']) > settings['CycleTime']*(1-settings['u']): # Auger currently off AND TimeSinceToggle > Auger Off Time
		Smoker.set_state('Auger',True)
		check_igniter(settings, recent_temps)
		push_settings(settings)

def check_igniter(settings, recent_temps): # Decide whether igniter is needed or has been running too long
	if (time.time() - Smoker.toggle_time['Igniter']) > 1200 and Smoker.get_state('Igniter'):
		SmokeLog.common.error('Disabling igniter due to timeout!')
		Smoker.set_state('Igniter', False)
		settings['Mode'] = 'Shutdown'
		settings = set_mode(settings, recent_temps)
	elif recent_temps[-1][1] < igniter_temperature:
		if not settings['Igniter']:
			SmokeLog.common.notice('Enabling igniter due to low temp: {}'.format(recent_temps[-1][1]))
			Smoker.set_state('Igniter',True)
	else:
		if settings['Igniter']:
			SmokeLog.common.notice('Igniter should not be on, disabling.')
			Smoker.set_state('Igniter',False)

def do_control(settings, recent_temps): # PID control mode (hold)
	if (time.time() - PID.last_update) > settings['CycleTime']:
		avg = get_average_since(recent_temps, PID.last_update)
		settings['u'] = PID.update(avg[1]) # Average grill probe temp
		settings['u'] = max(settings['u'],u_min)
		settings['u'] = min(settings['u'],u_max)
		SmokeLog.common.notice('Updated u: {}'.format(settings['u']))

		# Post control state
		pid_values = {'Time': time.time()*1000, 'u': settings['u'], 'P': PID.P, 'I': PID.I, 'D': PID.D, 'PID': PID.u, 'Error': PID.error, 'Derv': PID.derv, 'Inter': PID.inter}
		try:
			r = firebase.post_async('/PID', pid_values, params=fb_params)
		except Exception:
			SmokeLog.common.error('Failed to push updated PID settings to Firebase!')
			SmokeLog.common.error(traceback.format_exc())
			sys.exit(1)
		else:
			SmokeLog.common.notice('Pushed new PID settings to Firebase: {}'.format(pid_values))

		settings = push_settings(settings)
		
	return settings

def evaluate_triggers(settings, recent_temps, programs): # Check current status vs program instructions
	if settings['Program'] and len(programs) > 0:
		program = programs[0]
		if program[1]['Trigger'] == 'Time':
			if time.time() - timers['LastProgramToggle'] > float(program[1]['Limit']):
				SmokeLog.common.notice('Program timer fired!')
				(settings, programs) = next_program(settings, programs)
		elif program[1]['Trigger'] == 'Temp':
			if recent_temps[-1][2] > float(program[1]['Limit']):
				SmokeLog.common.notice('Reached temperature threshold for food probe!')
				(settings, programs) = next_program(settings, programs)

	return (settings, programs)

def next_program(settings, programs): # End current program and advance to next, if it exists
	programs.pop(0) # Remove current program
	push_programs(programs)
	if len(programs) > 0:
		SmokeLog.common.notice('Found new program.')
		settings = set_programs(settings, programs)
	else:
		SmokeLog.common.notice('No more programs found, disabling program control.')
		settings['Program'] = False
		settings = push_settings(settings)

	return (settings, programs)

def set_programs(settings, programs): # Set new program, if it exists
	if len(programs) > 0:
		timers['LastProgramToggle'] = time.time()
		fresh_program = next(iter(programs))
		if fresh_program[1]['Trigger'] == 'Temp':
			settings['TargetFood'] = fresh_program[1]['Limit']
		else:
			settings['TargetFood'] = 0
		settings['LastProgramToggle'] = timers['LastProgramToggle']
		settings['Mode'] = fresh_program[1]['Mode']
		settings = set_mode(settings, recent_temps)
		settings['TargetGrill'] = float(fresh_program[1]['TargetGrill'])
		PID.set_target(settings['TargetGrill'])
		settings = push_settings_sync(settings)
		SmokeLog.common.notice('Starting new program: Trigger: {}, Limit: {}'.format(fresh_program[1]['Trigger'], fresh_program[1]['Limit']))
	else:
		SmokeLog.common.notice('No program found to start! Disabling program control.')
		settings['Program'] = False
		settings['TargetFood'] = 0
		settings = push_settings(settings)

	return settings	

def get_average_since(recent_temps, start_time):
	n = 0
	sum = [0]*len(recent_temps[0])
	for entry in recent_temps:
		if entry[0] < start_time:
			continue
		for i in range(0,len(entry)):
			sum[i] += entry[i]
		n += 1
	avg = np.array(sum)/n

	return avg.tolist()





# START IT UP





SmokeLog.common.notice('Starting smokestack...')





# Constants

igniter_temperature = 100 # Upper limit of grill temperatures that trigger the igniter
start_timeout = 4*60 # Time to run "Start" mode before switching to "Hold"
shutdown_timeout = 10*60 # Time to run fan after shutdown
log_timeout = 10 # Period between temperature recordings
recent_temps_lifespan = log_timeout * 10 # Lifespan for recent_temps entries in memory
fetch_settings_timeout = 3  # Period between Firebase requests for settings
fetch_programs_timeout = 60 # Period between Firebase requests for new programs
pid_cycle_timeout = 20 # Period between control loop updates
u_min = 0.15 # Maintenance level
u_max = 1.0 #

# Objects

cook = {} # Dict, {'StartTime': time, 'Name': string, 'Food': string, 'FoodWeight': float, 'DesiredTemp': float}
recent_temps = [] # List of lists, [time, T[0], T[1]...]
programs = [] # List of dicts, [{'Trigger': Time|Temp, 'Limit': float}] ??? MODE ???
timers = {} # Dict, {'LastSettingsFetch': time, 'LastSettingsPush': time, 'LastProgramFetch': time, 'LastProgramPush': time, 'LastProgramToggle': time, 'StartModeBegan': time}
startup_time = time.time()
timers['LastProgramToggle'] = startup_time
timers['LastProgramFetch'] = startup_time
timers['LastSettingsFetch'] = startup_time
settings = {'Mode': 'Off', 'TargetGrill': 0, 'TargetFood': 0, 'PB': 60.0, 'Ti': 180.0, 'Td': 45.0, 'CycleTime': 20, 'u': 0.15, 'PMode': 2.0, 'Program': False, 'LastProgramToggle': timers['LastProgramToggle']}  # Default settings: 60, 180, 45 held +- 5F
PID = PID.PID(settings['PB'], settings['Ti'], settings['Td'])
Smoker = Traeger.Traeger()
probe_controller = [] # List, [grill_temp_probe_controller, food_temp_probe_controller]
probe_controller.append(MAX31865.MAX31865(0)) # Grill
probe_controller.append(MAX31855.MAX31855(1)) # Food

# Firebase

fb_projectID_file = open('/home/pi/FirebaseProjectID.txt', 'r')
projectID = fb_projectID_file.read()
fb_projectID_file.close()
fb_secret_file = open('/home/pi/FirebaseSecret.txt', 'r')
secret = fb_secret_file.read()
fb_secret_file.close()
fb_params = {'print':'silent'}
fb_params = {'auth':secret, 'print':'silent'} # ".write": "auth !== null"
firebase = firebase.FirebaseApplication('https://{}.firebaseio.com/'.format(projectID))
reset_firebase(settings)
set_mode(settings, recent_temps)





# DO THE THING





time.sleep(5) # Wait for clocks to sync
SmokeLog.common.notice('Starting main runloop.')
while 1: # GO
	recent_temps = record_temps(settings, recent_temps) # Record temperatures
	(settings, programs) = fetch_settings(settings, recent_temps, programs) # Check for new settings
	programs = fetch_programs(settings, programs) # Check for new program data
	(settings, programs) = evaluate_triggers(settings, recent_temps, programs) # Evaluate triggers
	settings = do_mode(settings, recent_temps) # Do the needful
	time.sleep(0.1)