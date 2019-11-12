//
//  StatusViewController.swift
//  PiSmokerControl
//
//  Created by Chris Coffin on 2/18/19.
//  Copyright © 2019 Chris Coffin. All rights reserved.
//

import UIKit
import Charts

class StatusViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UINavigationControllerDelegate {
    
    // MARK: IB Outlets + Actions
    
    @IBOutlet var graphTimescaleControl: UISegmentedControl!
    @IBAction func graphTimescaleValueChanged(_ sender: Any) {
        // Set timescale for X-Axis and redraw graph
        switch graphTimescaleControl.selectedSegmentIndex {
        case 0:
            graphTimescale = 9600
        case 1:
            graphTimescale = 4800
        case 2:
            graphTimescale = 800
        case 3:
            graphTimescale = 400
        case 4:
            graphTimescale = 67
        default:
            graphTimescale = 400
        }
        graphView.zoomToCenter(scaleX: 0, scaleY: 0)
        drawGraph()
    }
    
    @IBOutlet var graphView: LineChartView!
    @IBAction func viewGestureCaught(_ sender: UITapGestureRecognizer) {
        // Reset graph to default
        graphTimescaleControl.selectedSegmentIndex = 3
        graphTimescaleValueChanged(sender)
    }
    @IBAction func detailGestureCaught(_ sender: UITapGestureRecognizer) {
        
    }
    @IBAction func resetGestureCaught(_ sender: UITapGestureRecognizer) {
        let warningMessage = UIAlertController(title: "Confirm", message: "Delete temperature history?", preferredStyle: .alert)
        let confirmResponse = UIAlertAction(title: "OK", style: .destructive, handler: { (action) in
            FirebaseManager.sharedManager.dbReference.child("temp-history").removeValue()
            FirebaseManager.sharedManager.clearEntries()
            self.graphView.clearValues()
        })
        let cancelResponse = UIAlertAction(title: "Cancel", style: .cancel)
        warningMessage.addAction(confirmResponse)
        warningMessage.addAction(cancelResponse)
        self.present(warningMessage, animated: true, completion: nil)
    }
    
    @IBOutlet var grillCurrentLegend: UIView!
    @IBOutlet var grillCurrentLabel: UILabel!
    @IBOutlet var grillTargetLegend: UIView!
    @IBOutlet var grillTargetLabel: UILabel!
    @IBOutlet var foodCurrentLegend: UIView!
    @IBOutlet var foodCurrentLabel: UILabel!
    @IBOutlet var foodTargetLegend: UIView!
    @IBOutlet var foodTargetLabel: UILabel!
    
    @IBOutlet var addNewProgramButton: UIButton!
    @IBOutlet var runProgramSwitch: UISwitch!
    @IBAction func runProgramSwitchToggled(_ sender: Any) {
        runProgramSwitch.isEnabled = false // Disable switch for animation
        runProgramLabel.animateForControlState(control: runProgramSwitch)
        runProgramSwitch.isEnabled = !FirebaseManager.sharedManager.programs.isEmpty // Optionally re-enable, if needed
        runProgramLabel.isEnabled = !FirebaseManager.sharedManager.programs.isEmpty
        currentProgramModeLabel.isEnabled = runProgramSwitch.isOn
        currentProgramTriggerValueLabel.isEnabled = runProgramSwitch.isOn
        addNewProgramButton.isEnabled = !runProgramSwitch.isOn
        clearAllButton.isEnabled = !runProgramSwitch.isOn
        if runProgramSwitch.isOn {
            startTimer()
        } else {
            stopTimer()
            FirebaseManager.sharedManager.settingsReference.child("Mode").setValue("Off")
        }
        FirebaseManager.sharedManager.settingsReference.child("Program").setValue(runProgramSwitch.isOn)
    }
    @IBOutlet var runProgramLabel: UILabel!
    
    @IBOutlet var currentProgramModeLabel: UILabel!
    @IBOutlet var currentProgramTriggerTypeLabel: UILabel!
    @IBOutlet var currentProgramTriggerValueLabel: UILabel!
    
    @IBOutlet var clearAllButton: UIButton!
    @IBAction func clearAllButton(_ sender: Any) {
        let warningMessage = UIAlertController(title: "Confirm", message: "Delete all programs?", preferredStyle: .alert)
        let confirmResponse = UIAlertAction(title: "OK", style: .destructive, handler: { (action) in
            FirebaseManager.sharedManager.programReference.removeValue()
        })
        let cancelResponse = UIAlertAction(title: "Cancel", style: .cancel)
        warningMessage.addAction(confirmResponse)
        warningMessage.addAction(cancelResponse)
        self.present(warningMessage, animated: true, completion: nil)
    }
    @IBOutlet var upcomingProgramsTableView: UITableView!
    
    // MARK: Properties

    var dataForTableView: [String] = []
    var needLoadingIndicator = true
    var graphTimescale = 400
    var foodTargetColor = UIColor.systemBlue
    var foodCurrentColor = UIColor.systemTeal
    var grillTargetColor = UIColor.systemRed
    var grillCurrentColor = UIColor.systemOrange
    var timer: Timer?
    var timerToggled = Date()
    var timerLimit = Int()
    var programNeedsTimer = false
    
    // MARK: View Controller Lifecycle Functions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set history graph legend colors
        grillCurrentLegend.backgroundColor = grillCurrentColor
        grillTargetLegend.backgroundColor = grillTargetColor
        foodCurrentLegend.backgroundColor = foodCurrentColor
        foodTargetLegend.backgroundColor = foodTargetColor
        clearAllButton.isHidden = true
        
        if needLoadingIndicator {
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.style = UIActivityIndicatorView.Style.medium
            loadingIndicator.startAnimating()
            let alert = UIAlertController(title: nil, message: "Loading...", preferredStyle: .alert)
            alert.view.addSubview(loadingIndicator)
            UIApplication.shared.keyWindow!.rootViewController?.present(alert, animated: true, completion: nil)
            needLoadingIndicator = false
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(dismissLoadingIndicator), name: NSNotification.Name(rawValue: establishedFirebaseConnectionNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleHistoryUpdate), name: NSNotification.Name(rawValue: historyDataDidUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProgramDataUpdate), name: NSNotification.Name(rawValue: programDataDidUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleProgramStatusUpdate), name: NSNotification.Name(rawValue: programStatusDidUpdateNotification), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSettingsUpdate), name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: nil)
        
        // Set up Firebase
        FirebaseManager.sharedManager.checkLoginStatus()
        if FirebaseManager.sharedManager.historyObserver == nil {
            FirebaseManager.sharedManager.claimHistoryObserver()
        }
        if FirebaseManager.sharedManager.programObserver == nil {
            FirebaseManager.sharedManager.claimProgramObserver()
        }
        if FirebaseManager.sharedManager.settingsObserver == nil {
            FirebaseManager.sharedManager.claimSettingsObserver()
        }
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        customizeGraphAppearance()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: establishedFirebaseConnectionNotification), object: self)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: historyDataDidUpdateNotification), object: self)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: programDataDidUpdateNotification), object: self)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: programStatusDidUpdateNotification), object: self)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: settingsDataDidUpdateNotification), object: self)
    }
    
    // MARK: UITableView Delegate Methods
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataForTableView.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = upcomingProgramsTableView!.dequeueReusableCell(withIdentifier: "upcomingProgram", for: indexPath)
        cell.textLabel?.text = dataForTableView[indexPath.row]
        return cell
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    // MARK: Selectors for NotificationCenter Observers
    
    @objc func dismissLoadingIndicator() {
        dismiss(animated: false, completion: nil)
    }
    
    @objc func handleProgramDataUpdate() {
        // If there is a program:
        if let currentProgram = FirebaseManager.sharedManager.programs.first {
            let currentProgramMode = currentProgram["Mode"] as? String ?? ""
            let currentProgramTarget = currentProgram["TargetGrill"] as? Int ?? 0
            let currentProgramTrigger = currentProgram["Trigger"] as? String ?? ""
            let currentProgramLimit = currentProgram["Limit"] as? Int ?? 0
            let programCount = FirebaseManager.sharedManager.programs.count
            let programStatus = FirebaseManager.sharedManager.programOn
            // 1. Update UI element states
            runProgramSwitch.isEnabled = true
            runProgramLabel.isEnabled = true
            clearAllButton.isHidden = false
            clearAllButton.isEnabled = !programStatus
            addNewProgramButton.isEnabled = !programStatus
            currentProgramModeLabel.isEnabled = programStatus
            currentProgramTriggerValueLabel.isEnabled = programStatus
            // 2. Update label text
            if currentProgramTrigger == "Time" {
                currentProgramTriggerTypeLabel.text = "TIME"
                if currentProgramMode == "Hold" {
                    currentProgramModeLabel.text = "Cook at " +  String(currentProgramTarget) + " °F"
                } else {
                    currentProgramModeLabel.text = currentProgramMode.uppercased()
                }
                if currentProgramMode == "Off" {
                    currentProgramTriggerValueLabel.text = "N/A"
                    programNeedsTimer = false
                    stopTimer()
                } else {
                    programNeedsTimer = true
                    timerLimit = currentProgramLimit
                    currentProgramTriggerValueLabel.text = stringForTimer(currentProgramLimit)
                    if runProgramSwitch.isOn {
                        startTimer()
                    }
                }
            } else if currentProgramTrigger == "Temp" {
                programNeedsTimer = false
                stopTimer()
                if currentProgramLimit == 0 {
                    currentProgramModeLabel.text = "Keep Warm"
                    currentProgramTriggerTypeLabel.text = "TIME"
                    currentProgramTriggerValueLabel.text = "∞"
                } else {
                    currentProgramTriggerTypeLabel.text = "COOK"
                    currentProgramModeLabel.text = currentProgramMode + " " + String(currentProgramTarget) + " °F"
                    currentProgramTriggerValueLabel.text = String(currentProgramLimit) + " °F"
                }
            }
            // 4. Update the data for upcomingProgramsTableView
            dataForTableView.removeAll()
            var stringsForTableView = [String]()
            for program in FirebaseManager.sharedManager.programs[1..<programCount] {
                let programMode = program["Mode"] as? String ?? ""
                let programTarget = program["TargetGrill"] as? Int ?? 0
                let programTrigger = program["Trigger"] as? String ?? ""
                let programLimit = program["Limit"] as? Int ?? 0
                if programTrigger == "Time" {
                    if programMode == "Hold" {
                        stringsForTableView.append("Cook at " + String(programTarget) + " °F for " + stringForTimer(programLimit))
                    } else {
                        stringsForTableView.append(programMode + " for " + stringForTimer(programLimit))
                    }
                } else {
                    if programMode == "Hold" {
                        if programLimit == 0 {
                            stringsForTableView.append("Keep Warm")
                        } else {
                            stringsForTableView.append("Cook at " + String(programTarget) + " °F until food reaches " + String(programLimit) + " °F")
                        }
                    } else {
                        stringsForTableView.append(programMode + " until food reaches " + String(programLimit) + " °F")
                    }
                }
            }
            dataForTableView = stringsForTableView
        } else { // If there are no more programs
            stopTimer()
            currentProgramTriggerTypeLabel.text = "TIME"
            currentProgramModeLabel.text = "OFF"
            currentProgramTriggerValueLabel.text = "N/A"
            runProgramSwitch.isEnabled = false
            runProgramLabel.isEnabled = false
            clearAllButton.isHidden = true
            addNewProgramButton.isEnabled = true
            dataForTableView.removeAll()
        }
        upcomingProgramsTableView.reloadData()
    }
    
    @objc func handleProgramStatusUpdate() {
        let programStatus = FirebaseManager.sharedManager.programOn
        runProgramSwitch.isOn = programStatus
        currentProgramModeLabel.isEnabled = programStatus
        currentProgramTriggerValueLabel.isEnabled = programStatus
        if programStatus == false && FirebaseManager.sharedManager.programs.isEmpty {
            runProgramSwitch.isEnabled = programStatus
        }
        if !programStatus || !programNeedsTimer {
            stopTimer()
        } else {
            startTimer()
        }
    }
    
    @objc func handleHistoryUpdate() {
        if let historyData = FirebaseManager.sharedManager.logEntries.last {
            grillCurrentLabel.text = String(historyData["Grill"] as! Double) + " °F"
            if historyData["Food"] as? Int != 0 {
                foodCurrentLabel.text = String(historyData["Food"] as! Double) + " °F"
            } else {
                foodCurrentLabel.text = "N/A"
            }
            if historyData["TargetGrill"] as? Int != 0 && FirebaseManager.sharedManager.programOn {
                grillTargetLabel.text = String(historyData["TargetGrill"] as! Int) + " °F"
            } else {
                grillTargetLabel.text = "N/A"
            }
            if historyData["TargetFood"] as? Int != 0 {
                foodTargetLabel.text = String(historyData["TargetFood"] as! Int) + " °F"
            } else {
                foodTargetLabel.text = "N/A"
            }
            drawGraph()
        } else {
            graphView.clear()
            grillCurrentLabel.text = "N/A"
            grillTargetLabel.text = "N/A"
            foodCurrentLabel.text = "N/A"
            foodTargetLabel.text = "N/A"
        }
    }
    
    @objc func handleSettingsUpdate() {
        runProgramSwitch.isOn = FirebaseManager.sharedManager.programOn
        if let timestamp = FirebaseManager.sharedManager.settings?["LastProgramToggle"] as? Double {
            timerToggled = Date(timeIntervalSince1970: timestamp)
        }
    }
    
    @objc func updateTimerLabel() {
        if let triggerTime = Calendar.current.date(byAdding: .second, value: timerLimit, to: timerToggled) {
            let remainingTime = Double(triggerTime.timeIntervalSinceNow)
            if remainingTime < 1 {
                runProgramSwitch.isEnabled = false
                currentProgramTriggerValueLabel.text = "..."
            } else {
                runProgramSwitch.isEnabled = true
                currentProgramTriggerValueLabel.text = stringForTimer(Int(remainingTime))
            }
        }
    }
    
    // MARK: Custom functions
    
    func startTimer() {
        if programNeedsTimer && timer == nil {
            updateTimerLabel()
            timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateTimerLabel), userInfo: nil, repeats: true)
        }
    }
    
    func stopTimer() {
        if let timer = self.timer {
            timer.invalidate()
            self.timer = nil
        }
    }
    
    func stringForTimer(_ seconds: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute, .second]
        formatter.unitsStyle = .positional
        return formatter.string(from: TimeInterval(seconds)) ?? ""
    }
    
    // MARK: iOS Charts Customization
    
    func customizeGraphAppearance() {
        // Interactions
        graphView.dragXEnabled = true
        graphView.dragYEnabled = true
        graphView.scaleXEnabled = true
        graphView.scaleYEnabled = true
        graphView.pinchZoomEnabled = false
        graphView.doubleTapToZoomEnabled = false
        
        // Properties
        graphView.legend.enabled = false
        graphView.highlighter = nil
        
        // Defaults
        graphView.noDataText = "No temperature history to display"
        
        // Grill Temperature Axis
        let leftAxis = graphView.getAxis(.left)
        leftAxis.drawBottomYLabelEntryEnabled = true
        leftAxis.drawTopYLabelEntryEnabled = true
        leftAxis.axisMaximum = 400
        leftAxis.axisMinimum = 25
        leftAxis.labelTextColor = grillTargetColor
        leftAxis.axisLineColor = grillTargetColor
        leftAxis.axisLineWidth = 1.5
        leftAxis.axisMinLabels = 6
        leftAxis.axisMaxLabels = 6
        leftAxis.forceLabelsEnabled = true
        leftAxis.granularity = 75
        
        // Food Temperature Axis
        let rightAxis = graphView.getAxis(.right)
        rightAxis.drawBottomYLabelEntryEnabled = true
        rightAxis.drawTopYLabelEntryEnabled = true
        rightAxis.axisMaximum = 200
        rightAxis.axisMinimum = 50
        rightAxis.labelTextColor = foodTargetColor
        rightAxis.axisLineColor = foodTargetColor
        rightAxis.axisLineWidth = 1.5
        rightAxis.axisMinLabels = 6
        rightAxis.axisMaxLabels = 6
        rightAxis.forceLabelsEnabled = true
        rightAxis.granularity = 25
        
        // X Axis
        let xAxis = graphView.xAxis
        xAxis.labelPosition = .bottom
        xAxis.drawGridLinesEnabled = false
        xAxis.drawLabelsEnabled = false
    }
    
    func drawGraph() {
        var grillTargetLineData = [ChartDataEntry]()
        var grillCurrentLineData = [ChartDataEntry]()
        var foodTargetLineData = [ChartDataEntry]()
        var foodCurrentLineData = [ChartDataEntry]()
        
        for entry in FirebaseManager.sharedManager.logEntries.suffix(graphTimescale) {
            let grillTargetValue = ChartDataEntry(x: (entry["Timestamp"] as! Double), y: (entry["TargetGrill"] as! Double))
            let foodTargetValue = ChartDataEntry(x: (entry["Timestamp"] as! Double), y: Double(entry["TargetFood"] as! Int))
            let grillCurrentValue = ChartDataEntry(x: (entry["Timestamp"] as! Double), y: (entry["Grill"] as! Double))
            let foodCurrentValue = ChartDataEntry(x: (entry["Timestamp"] as! Double), y: (entry["Food"] as! Double))
            grillTargetLineData.append(grillTargetValue)
            grillCurrentLineData.append(grillCurrentValue)
            foodTargetLineData.append(foodTargetValue)
            foodCurrentLineData.append(foodCurrentValue)
        }
        
        let grillTargetLine = LineChartDataSet(entries: grillTargetLineData, label: "TargetGrill")
        grillTargetLine.colors = [grillTargetColor]
        grillTargetLine.drawCirclesEnabled = false
        grillTargetLine.drawValuesEnabled = false
        grillTargetLine.axisDependency = .left
        grillTargetLine.lineWidth = 4
        
        let foodTargetLine = LineChartDataSet(entries: foodTargetLineData, label: "TargetFood")
        foodTargetLine.colors = [foodTargetColor]
        foodTargetLine.drawCirclesEnabled = false
        foodTargetLine.drawValuesEnabled = false
        foodTargetLine.axisDependency = .right
        foodTargetLine.lineWidth = 4
        
        
        let grillCurrentLine = LineChartDataSet(entries: grillCurrentLineData, label: "Grill")
        grillCurrentLine.colors = [grillCurrentColor]
        grillCurrentLine.drawCirclesEnabled = false
        grillCurrentLine.drawValuesEnabled = false
        grillCurrentLine.axisDependency = .left
        grillCurrentLine.lineWidth = 2
        
        let foodCurrentLine = LineChartDataSet(entries: foodCurrentLineData, label: "Food")
        foodCurrentLine.colors = [foodCurrentColor]
        foodCurrentLine.drawCirclesEnabled = false
        foodCurrentLine.drawValuesEnabled = false
        foodCurrentLine.axisDependency = .right
        foodCurrentLine.lineWidth = 2
        
        graphView.data = LineChartData(dataSets: [grillTargetLine, foodTargetLine, grillCurrentLine, foodCurrentLine])
        graphView.notifyDataSetChanged()
    }

}

// MARK: Extensions

extension UILabel {
    func animateForControlState(control: UISwitch) {
        var highlightColor: UIColor
        if control.isOn {
            self.text = "RUNNING"
            highlightColor = UIColor.systemGreen
        } else {
            self.text = "STOPPING"
            highlightColor = UIColor.systemRed
        }
        UIView.animate(withDuration: 1, delay: 0.0, options: AnimationOptions.transitionCrossDissolve, animations: {
            self.textColor = highlightColor
            self.alpha = 0.0
        }, completion: { finish in
            self.textColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 1)
            self.text = "RUN"
            self.alpha = 1.0
        })
    }
}
