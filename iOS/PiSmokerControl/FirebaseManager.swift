//
//  FirebaseManager.swift
//  smokestack
//
//  Created by Chris Coffin on 1/12/19.
//  Copyright © 2019 Chris Coffin. All rights reserved.
//

import Foundation
import Firebase
import FirebaseAuth
import FirebaseDatabase

let establishedFirebaseConnectionNotification = "establishedFirebaseConnectionNotification"
let historyDataDidUpdateNotification = "historyDataDidUpdateNotification"
let programDataDidUpdateNotification = "programDataDidUpdateNotification"
let programStatusDidUpdateNotification = "programStatusDidUpdateNotification"
let settingsDataDidUpdateNotification = "settingsDataDidUpdateNotification"

class FirebaseManager {
	
	// MARK: Setup

	private init() {}  // Prevent clients from creating another instance.

	static let sharedManager = FirebaseManager() // Creates shared instance

	// MARK: References

	internal lazy var dbReference: DatabaseReference = { // Make as many properties and references lazy as possible, to minimize initial footprint
		return Database.database().reference()
	}()

	internal lazy var historyReference: DatabaseReference = {
		return Database.database().reference().child("/temp-history")
	}()
	
	internal lazy var programReference: DatabaseReference = {
		return Database.database().reference().child("/programs")
	}()

	internal lazy var settingsReference: DatabaseReference = {
		return Database.database().reference().child("/settings")
	}()

	// MARK: Properties

	private (set) var logEntries: [[String: Any]] = [] {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: historyDataDidUpdateNotification), object: nil)
		}
	}
	
	private (set) var programs: [[String: Any]] = [] {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: programDataDidUpdateNotification), object: nil)
		}
	}
	
	private (set) var settings: [String: Any]? {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: nil)
		}
	}

	private (set) var historyObserver: AuthStateDidChangeListenerHandle? {
		didSet {
			if self.historyObserver != nil && self.programObserver != nil && self.settingsObserver != nil {
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: establishedFirebaseConnectionNotification), object: nil)
			}
		}
	}
	
	private (set) var programObserver: AuthStateDidChangeListenerHandle? {
		didSet {
			if self.historyObserver != nil && self.programObserver != nil && self.settingsObserver != nil {
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: establishedFirebaseConnectionNotification), object: nil)
			}
		}
	}

	private (set) var settingsObserver: AuthStateDidChangeListenerHandle? {
		didSet {
			if self.historyObserver != nil && self.programObserver != nil && self.settingsObserver != nil {
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: establishedFirebaseConnectionNotification), object: nil)
			}
		}
	}
	
	private (set) var programOn: Bool = false {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: programStatusDidUpdateNotification), object: nil)
		}
	}
	
	private (set) var augerStatus: Bool? {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: nil)
		}
	}
	
	private (set) var fanStatus: Bool? {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: nil)
		}
	}
	
	private (set) var igniterStatus: Bool? {
		didSet {
			NotificationCenter.default.post(name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: nil)
		}
	}
	
	// MARK: Functions

	internal func checkLoginStatus() {
		Auth.auth().addStateDidChangeListener { auth, user in
			if user == nil {
				print("no user logged in, fixing that.")
				self.login()
			}
		}
	}

	internal func login() {
		let email = "tenantless@gmail.com"
		let password = "pismoker"
		Auth.auth().signIn(withEmail: email, password: password) { (authResult, error) in
			print(authResult!.description)
			print(authResult!.debugDescription)
			print(authResult!.additionalUserInfo.debugDescription)
		}
	}
	
	internal func clearEntries() {
		self.logEntries.removeAll()
	}

	internal func claimHistoryObserver() {
		self.historyObserver = Auth.auth().addStateDidChangeListener() { (auth, user) in
			var entries = [[String: Any]]()
			self.historyReference.observe(.childAdded, with: { (snapshot) in
				if snapshot.hasChildren() {
					let data = snapshot.value as! [String: Any]
					entries.append(data)
				}
				self.logEntries = entries
			})
			
			self.historyReference.observe(.childRemoved, with: { (snapshot) in
				NotificationCenter.default.post(name: NSNotification.Name(rawValue: historyDataDidUpdateNotification), object: nil)
			})
		}
	}
	
	internal func claimProgramObserver() {
		self.programObserver = Auth.auth().addStateDidChangeListener() { (auth, user) in
			self.programReference.observe(.value, with: { snapshot in
				var programs = [[String:Any]]()
				let enumerator = snapshot.children
				while let child = enumerator.nextObject() as? DataSnapshot {
					let data = child.value as! [String:Any]
					programs.append(data)
				}
				self.programs = programs
			})
		}
	}

	internal func claimSettingsObserver() {
		self.settingsObserver = Auth.auth().addStateDidChangeListener() { (auth, user) in
			self.settingsReference.observe(.value, with: { (snapshot) in
				if snapshot.hasChildren() {
					self.settings = snapshot.value as? [String: Any]
				}
			})
			self.settingsReference.child("Program").observe(.value, with: { (snapshot) in
				self.programOn = snapshot.value as? Bool ?? false
			})
		}
	}
	
	internal func releaseHistoryObserver() {
		if self.historyObserver != nil {
			Auth.auth().removeStateDidChangeListener(self.historyObserver!)
			self.historyObserver = nil
		}
	}
	
	internal func releaseProgramObserver() {
		if self.programObserver != nil {
			Auth.auth().removeStateDidChangeListener(self.programObserver!)
			self.programObserver = nil
		}
	}

	internal func releaseSettingsObserver() {
		if self.settingsObserver != nil {
			Auth.auth().removeStateDidChangeListener(self.settingsObserver!)
			self.settingsObserver = nil
		}
	}

}
