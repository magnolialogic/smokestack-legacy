//
//  LogViewController.swift
//  PiSmokerControl
//
//  Created by Chris Coffin on 9/20/18.
//  Copyright © 2018 Chris Coffin. All rights reserved.
//

import UIKit

class LogViewController: UITableViewController {
    
    @IBOutlet var logTableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        FirebaseManager.sharedManager.dbReference.child("cook/name").setValue("Test2")
		
		let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
		loadingIndicator.hidesWhenStopped = true
		loadingIndicator.style = UIActivityIndicatorView.Style.gray
		loadingIndicator.startAnimating()
		let alert = UIAlertController(title: nil, message: "Loading...", preferredStyle: .alert)
		alert.view.addSubview(loadingIndicator)
		present(alert, animated: true, completion: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
		NotificationCenter.default.addObserver(self, selector: #selector(updateUI), name: NSNotification.Name(rawValue: historyDataDidUpdateNotification), object: nil)
		if FirebaseManager.sharedManager.historyObserver == nil {
			print("claiming history observer")
			FirebaseManager.sharedManager.claimHistoryObserver()
		}
    }
    
    override func viewWillDisappear(_ animated: Bool) {
		NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: historyDataDidUpdateNotification), object: self)
        FirebaseManager.sharedManager.releaseHistoryObserver()
    }
	
	@objc func updateUI() {
		print(#function)
		if FirebaseManager.sharedManager.logEntries != nil {
			dismiss(animated: false, completion: nil)
			print(FirebaseManager.sharedManager.logEntries!.count)
			DispatchQueue.main.async {
				self.logTableView.reloadData()
			}
		}
	}
	
	deinit {
		//
	}
    
    
    
    // MARK: UITableView shit
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return FirebaseManager.sharedManager.logEntries?.count ?? 0
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "historyCell", for: indexPath)
        
        //cell.textLabel?.text = lists[indexPath.row].item
        
        return cell
    }


}
