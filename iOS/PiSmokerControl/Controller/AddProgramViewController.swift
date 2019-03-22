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
        if triggerPicker.selectedSegmentIndex == 0 {
            timerPicker.isHidden = true
            temperaturePicker.isHidden = false
            triggerDescription.text = "until food reaches"
            temperaturePicker.selectRow(10, inComponent: 0, animated: false)
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
            self.temperaturePicker.selectRow(30, inComponent: 0, animated: true)
        })
        presetMenu.addAction(UIAlertAction(title: "Ground Meat", style: .default) { (action) in
            self.temperaturePicker.selectRow(15, inComponent: 0, animated: true)
        })
        presetMenu.addAction(UIAlertAction(title: "Poultry", style: .default) { (action) in
            self.temperaturePicker.selectRow(10, inComponent: 0, animated: true)
        })
        presetMenu.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(presetMenu, animated: true)
    }
    
    // MARK: PROPERTIES
    
    let minTargetFoodTemp = 50
    let maxTargetFoodTemp = 175
    let targetTemps = [150, 180, 225, 250, 275, 300, 325, 350, 375, 400]
    
    // MARK: VIEWCONTROLLER LIFECYCLE
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelButtonPressed))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(doneButtonPressed))
        temperaturePicker.selectRow(10, inComponent: 0, animated: false)
        targetSlider.minimumValue = 0
        targetSlider.maximumValue = Float(targetTemps.count - 1)
        if let historyData = FirebaseManager.sharedManager.logEntries.last {
            if historyData["Food"] as? Int == 0 {
                triggerPicker.isEnabled = false
                triggerPicker.selectedSegmentIndex = 1
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
    
    // MARK: OBJC #SELECTORS
    
    @objc func cancelButtonPressed() {
        self.navigationController?.popToRootViewController(animated: true)
    }
    
    @objc func doneButtonPressed() {
        var programMode = ""
        var programTarget = Int()
        var programTrigger = ""
        var programLimit = Int()
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
        let shutdownProgram: [String: Any] = ["Mode": "Shutdown", "TargetGrill": 0, "Trigger": "Time", "Limit": 600]
        
        
        if FirebaseManager.sharedManager.programs.isEmpty {
            FirebaseManager.sharedManager.programReference.childByAutoId().setValue(startProgram)
            FirebaseManager.sharedManager.programReference.childByAutoId().setValue(program)
            FirebaseManager.sharedManager.programReference.childByAutoId().setValue(shutdownProgram)
        } else {
            var oldPrograms = FirebaseManager.sharedManager.programs
            FirebaseManager.sharedManager.programReference.removeValue()
            FirebaseManager.sharedManager.programReference.childByAutoId().setValue(startProgram)
            oldPrograms.removeFirst()
            oldPrograms.removeLast()
            for oldProgram in oldPrograms {
                FirebaseManager.sharedManager.programReference.childByAutoId().setValue(oldProgram)
            }
            FirebaseManager.sharedManager.programReference.childByAutoId().setValue(program)
            FirebaseManager.sharedManager.programReference.childByAutoId().setValue(shutdownProgram)
        }
        self.navigationController?.popToRootViewController(animated: true)
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
