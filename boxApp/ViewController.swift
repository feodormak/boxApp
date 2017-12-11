//
//  ViewController.swift
//  boxApp
//
//  Created by feodor on 17/10/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import UIKit
import BoxContentSDK
import SystemConfiguration
import Disk


enum UpdateManagerState {
    case begin
    case checking
    case noUpdate
    case updateAvailable
    case noInternet
    case downloading
    case error
    case complete
}

class ViewController: UIViewController, UpdateManagerDelegate {
    
    private let updateManager = UpdateManager()
    private var updateManagerState: UpdateManagerState = .begin {
        didSet {
            switch updateManagerState{
            case .checking: self.mainButton.isEnabled = false
            case .noUpdate, .complete:
                self.mainButton.isHidden = true
                self.mainButton.isEnabled = false
            case .updateAvailable:
                self.mainButton.isEnabled = true
                self.mainButton.setTitle("Download updates", for: .normal)
            case .downloading:
                self.mainButton.isEnabled = true
                self.mainButton.setTitle("Cancel", for: .normal)
            case .noInternet, .error:
                self.mainButton.isHidden = false
                self.mainButton.isEnabled = true
                self.mainButton.setTitle("Check for updates", for: .normal)
            case .begin : break
            }
        }
    }
    
    let progressView = ProgressView()
    let statusLabel: UILabel = {
       let label = UILabel()
        label.text = "Ready"
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 12)
        label.backgroundColor = .clear
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    let mainButton: UIButton = {
       let button = UIButton()
        button.setTitle("Check for updates", for: .normal)
        button.backgroundColor = .clear
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        button.setTitleColor(.black, for: .normal)
        button.setTitleColor(.gray, for: .highlighted)
        //button.tintColor = .black
        button.layer.cornerRadius = 10
        button.layer.borderWidth = 1
        button.layer.borderColor = UIColor.black.cgColor
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(mainButtonTapped(_:)), for: .touchUpInside)
        return button
    }()
    
    @objc private func mainButtonTapped(_ sender: UIButton) {
        switch self.updateManagerState {
        case .begin, .noInternet, .error: self.checkFiles()
        case .updateAvailable: self.downloadFiles()
        case .downloading : self.cancelDownload()
        case .checking, .noUpdate, .complete: break
        }
    }
    
    private func checkFiles() {
        self.progressView.resetView()
        let contentClient: BOXContentClient = BOXContentClient.default()
        self.progressView.startIndicator()
        self.updateManagerState = .checking
        self.statusLabel.text = "Checking for updates..."
        updateManager.checkFiles(contentClient: contentClient, completion: ({ (completionStatus, numberOfFiles) in
            DispatchQueue.main.async {
                self.progressView.stopIndicator()
                switch completionStatus {
                case .successful:
                    if numberOfFiles != nil {
                        if numberOfFiles! == 0 {
                            self.statusLabel.text = "All files are up to file"
                            self.updateManagerState = .noUpdate
                        }
                        else {
                            self.statusLabel.text = "Update available"
                            self.updateManagerState = .updateAvailable
                        }
                    }
                case .error:
                    self.statusLabel.text = "Error occur. Please try again."
                    self.updateManagerState = .error
                case .noConnection:
                    self.statusLabel.text =  "No internet connection!"
                    self.updateManagerState = .noInternet
                }
            }
        }))
    }
    
    private func downloadFiles() {
        self.updateManagerState = .downloading
        let contentClient: BOXContentClient = BOXContentClient.default()
        self.progressView.startIndicator()
        self.statusLabel.text = "Downloading files..."
        updateManager.downloadFiles(contentClient: contentClient) { completionStatus in
            DispatchQueue.main.async {
                switch completionStatus {
                case .successful:
                    self.statusLabel.text = "Files successfully updated"
                    self.updateManagerState = .complete
                case .error:
                    self.statusLabel.text = "Error downloading files. Please try again"
                    self.updateManagerState = .error
                case .noConnection:
                    self.statusLabel.text = "No internet connection"
                    self.updateManagerState = .noInternet
                }
                self.progressView.stopIndicator()
            }
        }
    }
    
    private func cancelDownload() {
        let contentClient: BOXContentClient = BOXContentClient.default()
        updateManager.cancelDownloads(contentClient: contentClient)
        self.updateManagerState = .error
    }
    
    @IBAction func logOut(_ sender: UIButton) { BOXContentClient.logOutAll() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.progressView.isHidden = true
        
        //self.progressView.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        self.view.addSubview(self.progressView)
        self.view.addSubview(self.statusLabel)
        self.view.addSubview(self.mainButton)
       
        self.updateManager.delegate = self
        self.view.translatesAutoresizingMaskIntoConstraints = false
        
        //UserDefaultsManager.storedFiles?.removeAll()
        
        
        NSLayoutConstraint(item: progressView, attribute: .centerX, relatedBy: .equal, toItem: self.view , attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 2).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -2).isActive = true
        NSLayoutConstraint(item: statusLabel, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 2).isActive = true
        NSLayoutConstraint(item: statusLabel, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -2).isActive = true
        NSLayoutConstraint(item: statusLabel, attribute: .bottom, relatedBy: .equal, toItem: progressView, attribute: .top, multiplier: 1, constant: 2).isActive = true
        NSLayoutConstraint(item: mainButton, attribute: .top, relatedBy: .equal, toItem: progressView, attribute: .bottom, multiplier: 1, constant: 4).isActive = true
        NSLayoutConstraint(item: mainButton, attribute: .centerX, relatedBy: .equal, toItem: self.view, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: mainButton, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1, constant: 200).isActive = true
        
        //print("prev",UserDefaultsManager.storedFiles?.count)
        //UserDefaultsManager.storedFiles = [BoxFileBasics]()
        //print("after",UserDefaultsManager.storedFiles?.count)
        
        //UserDefaultsManager.lastSyncedDate = Date()
        //print(UserDefaultsManager.lastSyncedDate)
    }
    
    func startTracking(withFiles: [ProgressFile]) {
        DispatchQueue.main.async { self.progressView.startTracking(withFiles: withFiles) }
    }
    
    func updateFileProgress(fileID: String, bytesTransferred: Int64) {
        DispatchQueue.main.async { self.progressView.updateFileProgress(fileID: fileID, bytesTransferred: bytesTransferred) }
    }
    
    private func showApple() {
        /*
        do {
            //let image = try Disk.retrieve("apple.jpg", from: .applicationSupport, as: UIImage.self)
            //DispatchQueue.main.sync { self.imageView.image = image }
        }
        catch { }
         */
    }
    
    
    
    
}

