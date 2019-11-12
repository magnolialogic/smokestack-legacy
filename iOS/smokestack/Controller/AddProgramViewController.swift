//
//  AddProgramViewController.swift
//  smokestack
//
//  Created by Chris Coffin on 9/20/18.
//  Copyright © 2018 Chris Coffin. All rights reserved.
//

import UIKit
import Firebase

class AddProgramViewController: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource {
    
    // MARK: IB OUTLETS + ACTIONS
    
    @IBOutlet var triggerPicker: UISegmentedControl!
    @IBAction func newTriggerSelected(_ sender: UISegmentedControl) {
        updateUI()
    }
    
    @IBOutlet var targetTempDescription: UILabel!
    @IBOutlet var targetSlider: UISlider!
    @IBAction func targetTempChanged(_ sender: UISlider) {
        let roundedValue = roundf(sender.value)
        sender.setValue(roundedValue, animated: true)
        if roundedValue == 0 {
            targetTempDescription.text = "Smoke"
        } else {
            targetTempDescription.text = "Cook at " + String(targetTemps[Int(roundedValue)]) + " °F"
        }
    }
    @IBOutlet var triggerDescription: UILabel!
    @IBOutlet var timerPicker: UIDatePicker!
    @IBOutlet var temperaturePicker: UIPickerView!
    @IBOutlet var degreesLabel: UILabel!
    
    @IBOutlet var fdaPresetButton: UIButton!
    @IBAction func fdaPresetButtonPressed(_ sender: Any) {
        let presetMenu = UIAlertController(title: nil, message: "Choose Preset", preferredStyle: .actionSheet)
        presetMenu.addAction(UIAlertAction(title: "Beef, Pork/Ham, Fish", style: .default) { (action) in
            self.temperaturePicker.selectRow(55, inComponent: 0, animated: true) // 145F
        })
        presetMenu.addAction(UIAlertAction(title: "Ground Meat", style: .default) { (action) in
            self.temperaturePicker.selectRow(40, inComponent: 0, animated: true) // 160F
        })
        presetMenu.addAction(UIAlertAction(title: "Poultry", style: .default) { (action) in
            self.temperaturePicker.selectRow(35, inComponent: 0, animated: true) // 165F
        })
        presetMenu.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(presetMenu, animated: true)
    }
    
    // MARK: PROPERTIES
    
    let minTargetFoodTemp = 50
    let maxTargetFoodTemp = 200
    let targetTemps = [150, 180, 225, 250, 275, 300, 325, 350, 375, 400]
    
    // MARK: VIEWCONTROLLER LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonPressed))
        temperaturePicker.selectRow(55, inComponent: 0, animated: false)
        targetSlider.minimumValue = 0
        targetSlider.maximumValue = Float(targetTemps.count - 1)
        if let historyData = FirebaseManager.sharedManager.logEntries.last {
            // If last log entry doesn't contain food temp data, food probe is not connected == only offer timed mode
            if historyData["Food"] as? Int == 0 {
                triggerPicker.isEnabled = false
                triggerPicker.selectedSegmentIndex = 1
                updateUI()
            } else {
                triggerPicker.isEnabled = true
            }
        } else {
            let errorMessage = UIAlertController(title: "Error", message: "Couldn't retrieve history data from Firebase.", preferredStyle: .alert)
            let okButton = UIAlertAction(title: "OK", style: .cancel, handler: { (action) in
                self.navigationController?.popToRootViewController(animated: true)
            })
            errorMessage.addAction(okButton)
            self.present(errorMessage, animated: true, completion: nil)
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    // MARK: Custom functions
    
    func updateUI() {
        if triggerPicker.selectedSegmentIndex == 0 {
            timerPicker.isHidden = true
            temperaturePicker.isHidden = false
            triggerDescription.text = "until food reaches"
            temperaturePicker.selectRow(55, inComponent: 0, animated: false)
            fdaPresetButton.isHidden = false
            degreesLabel.isHidden = false
        } else {
            timerPicker.isHidden = false
            temperaturePicker.isHidden = true
            fdaPresetButton.isHidden = true
            degreesLabel.isHidden = true
            triggerDescription.text = "for"
        }
    }
    
    // MARK: OBJC #SELECTORS
    
    @objc func cancelButtonPressed() {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @objc func doneButtonPressed() {
        var programMode = ""
        var programTarget = Int()
        var programTrigger = ""
        var programLimit = Int()
        var keepWarmEnabled = false
        let roundedSlider = Int(roundf(targetSlider.value))
        if roundedSlider == 0 { // FIXME
            programMode = "Smoke"
        } else {
            programMode = "Hold"
        }
        programTarget = targetTemps[roundedSlider]
        if triggerPicker.selectedSegmentIndex == 1 {
            programTrigger = "Time"
            programLimit = Int(timerPicker.countDownDuration)
        } else {
            programTrigger = "Temp"
            programLimit = maxTargetFoodTemp - temperaturePicker.selectedRow(inComponent: 0)
        }
        let startProgram: [String: Any] = ["Mode": "Start", "TargetGrill": programTarget, "Trigger": "Time", "Limit": 600]
        let program: [String: Any] = ["Mode": programMode, "TargetGrill": programTarget, "Trigger": programTrigger, "Limit": programLimit]
        let keepWarmProgram: [String: Any] = ["Mode": "Hold", "TargetGrill": 165, "Trigger": "Temp", "Limit": 0]
        let shutdownProgram: [String: Any] = ["Mode": "Shutdown", "TargetGrill": 0, "Trigger": "Time", "Limit": 600]
        func submitPrograms() {
            if FirebaseManager.sharedManager.programs.isEmpty {
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(startProgram)
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(program)
                if keepWarmEnabled {
                    FirebaseManager.sharedManager.programReference.childByAutoId().setValue(keepWarmProgram)
                }
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(shutdownProgram)
            } else {
                var oldPrograms = FirebaseManager.sharedManager.programs
                var keepWarmProgramExists = false
                FirebaseManager.sharedManager.programReference.removeValue()
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(startProgram)
                oldPrograms.removeFirst()
                oldPrograms.removeLast()
                if oldPrograms.last!["Mode"] as? String == "Hold" && oldPrograms.last!["Limit"] as? Int == 0 {
                    keepWarmProgramExists = true
                    oldPrograms.removeLast()
                }
                for oldProgram in oldPrograms {
                    FirebaseManager.sharedManager.programReference.childByAutoId().setValue(oldProgram)
                }
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(program)
                if keepWarmProgramExists {
                    FirebaseManager.sharedManager.programReference.childByAutoId().setValue(keepWarmProgram)
                } else if keepWarmEnabled {
                    FirebaseManager.sharedManager.programReference.childByAutoId().setValue(keepWarmProgram)
                }
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(shutdownProgram)
            }
        }
        
        if triggerPicker.selectedSegmentIndex == 0 {
            let keepWarmPrompt = UIAlertController(title: "Keep warm?", message: "To end Keep Warm program, detach temperature probe from controller", preferredStyle: .alert)
            let keepWarmEnableResponse = UIAlertAction(title: "Yes", style: .default, handler: { (action) in
                keepWarmEnabled = true
                submitPrograms()
                self.navigationController?.popToRootViewController(animated: true)
            })
            let keepWarmDisableResponse = UIAlertAction(title: "No", style: .default, handler: { (action) in
                submitPrograms()
                self.navigationController?.popToRootViewController(animated: true)
            })
            keepWarmPrompt.addAction(keepWarmEnableResponse)
            keepWarmPrompt.addAction(keepWarmDisableResponse)
            self.present(keepWarmPrompt, animated: true, completion: nil)
        } else {
            submitPrograms()
            self.navigationController?.popToRootViewController(animated: true)
        }
    }
    
    // MARK: UIPICKERVIEW DELEGATE METHODS
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return (maxTargetFoodTemp-minTargetFoodTemp+1)
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String(maxTargetFoodTemp-row)
    }

}
