//
//  DebugViewController.swift
//  PiSmokerControl
//
//  Created by Chris Coffin on 9/20/18.
//  Copyright © 2018 Chris Coffin. All rights reserved.
//

import UIKit
import Firebase

class DebugViewController: UIViewController {
    
    
    
    
    @IBOutlet var debugButtonOutlet: UIButton!
    @IBOutlet var augerSwitch: UISwitch!
    @IBOutlet var fanSwitch: UISwitch!
    @IBOutlet var igniterSwitch: UISwitch!
    
    var debugEnabled: Bool = false
    
    @IBAction func debugButtonPressed(_ sender: UIButton) {
        //
    }
    
    @IBAction func switchToggled(_ sender: UISwitch) {
        switch sender.tag {
        case 0:
            FirebaseManager.sharedManager.settingsReference.child("Auger").setValue(augerSwitch.isOn)
        case 1:
            FirebaseManager.sharedManager.settingsReference.child("Fan").setValue(fanSwitch.isOn)
        case 2:
            FirebaseManager.sharedManager.settingsReference.child("Igniter").setValue(igniterSwitch.isOn)
        default:
            break
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        FirebaseManager.sharedManager.checkLoginStatus()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: nil)
        
        if FirebaseManager.sharedManager.settingsObserver == nil {
            print("claiming settings observer")
            FirebaseManager.sharedManager.claimSettingsObserver()
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        updateUI()
    }
    
    override func viewDidLayoutSubviews() {
        if FirebaseManager.sharedManager.augerStatus == nil || FirebaseManager.sharedManager.fanStatus == nil || FirebaseManager.sharedManager.igniterStatus == nil {
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = UIActivityIndicatorView.Style.gray
            loadingIndicator.startAnimating()
            let alert = UIAlertController(title: nil, message: "Loading...", preferredStyle: .alert)
            alert.view.addSubview(loadingIndicator)
            present(alert, animated: true, completion: nil)
        }
    }
    
    @objc func updateUI() {
        if FirebaseManager.sharedManager.augerStatus != nil && FirebaseManager.sharedManager.fanStatus != nil && FirebaseManager.sharedManager.igniterStatus != nil {
            print(" auger ", FirebaseManager.sharedManager.augerStatus!)
            augerSwitch.isOn = FirebaseManager.sharedManager.augerStatus!
            print(" fan ", FirebaseManager.sharedManager.fanStatus!)
            fanSwitch.isOn = FirebaseManager.sharedManager.fanStatus!
            print(" igniter ", FirebaseManager.sharedManager.igniterStatus!)
            igniterSwitch.isOn = FirebaseManager.sharedManager.igniterStatus!
            dismiss(animated: false, completion: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: self)
    }

}
