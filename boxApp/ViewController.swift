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


class ViewController: UIViewController {
    //let contentClient:BOXContentClient = BOXContentClient.default()
    var onlineFiles = [BoxFileBasics]()
    //var onlineFiles = SynchronizedArray<BoxFileBasics>()
    
    var newFiles = [BoxFileBasics]()
    var changedFiles = [BoxFileBasics]()
    var filesToDownload = [BoxFileBasics]()
    var filesToDelete = [BoxFileBasics]()
    
    //@IBOutlet weak var imageView: UIImageView!
    
    let progressView = ProgressView()
    
    
    @IBAction func checkFiles(_ sender: UIButton) {
        self.progressView.startIndicator()
        let contentClient:BOXContentClient = BOXContentClient.default()
        
        if self.connectedToNetwork() == false {
            print("no internet")
            return
        }
        else { // self.statusText.text.append(contentsOf: "Internet connection... OK\n")
        }
        
        self.onlineFiles.removeAll()
        
        if contentClient.session.isAuthorized() == false {
            //self.statusText.text.append(contentsOf: "Not logged in to Box account. Logging in...\n")
            contentClient.authenticate{(user, error) in
                if error == nil && user != nil { self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { _ in self.getDownloadFileList() })}
            } }
            
        else { self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { _ in self.getDownloadFileList() })}
    }
    
    func getItemsFromBaseFolder(contentClient: BOXContentClient, completionHandler: @escaping(DispatchTimeoutResult)-> Void) {
        let dispatchGroup = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async {
            dispatchGroup.enter()
            let workItem = DispatchWorkItem {
                self.getFolderItems(contentClient: contentClient, folderID: "0") { fileList in
                    if fileList != nil { self.onlineFiles.append(contentsOf: fileList!) }
                    print("main", self.onlineFiles.count)
                    dispatchGroup.leave()
                }
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
            
            let groupWait = dispatchGroup.wait(timeout: .now() + UpdateManagerConstants.timeoutInterval)
            if groupWait == .timedOut {
                print("timedout")
                workItem.cancel()
            }
            else { print("done") }
            DispatchQueue.main.async(execute: {
                self.progressView.stopIndicator()
                
            })
            completionHandler(groupWait)
        }
    }
    
    func getFolderItems(contentClient:BOXContentClient ,folderID:String, completionHanlder: @escaping ([BoxFileBasics]?) -> Void) {
        let folderItemsRequest:BOXFolderItemsRequest = contentClient.folderItemsRequest(withID: folderID)
        var fileList = [BoxFileBasics]()
        let dispatchGroup = DispatchGroup()
        
        DispatchQueue.global(qos: .userInitiated).async {
            folderItemsRequest.perform { (items:[BOXItem]?, error:Error!) in
                if error == nil && items != nil {
                    for item in items! {
                        if item.isFile == true {
                            fileList.append(BoxFileBasics(name: item.name, modelID: item.modelID, version: item.etag))
                            //print(item.name, item.modelID, item.etag, fileList.count)
                        }
                        /*
                         else if item.isFolder == true {
                         dispatchGroup.enter()
                         self.getFolderItems(contentClient: contentClient, folderID: item.modelID) { filesInSubFolder in
                         if filesInSubFolder != nil { fileList.append(contentsOf: filesInSubFolder!) }
                         dispatchGroup.leave()
                         }
                         }
                         */
                    }
                }
                else { print("error getting folder") }
                dispatchGroup.wait()
                //DispatchQueue.main.async {
                //   print("func: ", folderID, fileList.count)
                completionHanlder(fileList)
                //}
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + UpdateManagerConstants.timeoutInterval, execute: { folderItemsRequest.cancel() })
    }
    
    func getDownloadFileList() {
        newFiles.removeAll()
        changedFiles.removeAll()
        filesToDownload.removeAll()
        
        if let offlineFiles = UserDefaultsManager.storedFiles{
            self.filesToDownload = self.onlineFiles
            
            for file in offlineFiles{ filesToDownload = filesToDownload.filter { $0 != file } }
            
            for file in filesToDownload {
                switch (offlineFiles.filter{ $0.modelID == file.modelID }.count) {
                case 0: newFiles.append(file)
                case 1: changedFiles.append(file)
                default: break
                }
            }
        }
        else { newFiles.append(contentsOf: onlineFiles) }
        //DispatchQueue.main.async { self.statusText.text.append(contentsOf: "No. of files to be downloaded: \(self.filesToDownload.count)\n") }
        print("to download:\(filesToDownload.count)", "changed: \(changedFiles.count)", "new: \(newFiles.count)")
    }
    
    @IBAction func downloadFiles(_ sender: UIButton) {
        let contentClient: BOXContentClient = BOXContentClient.default()
        
        let totalSizeGroup = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async {
            
            var  progressFileList = [ProgressFile]()
            for file in self.filesToDownload {
                totalSizeGroup.enter()
                
                let fileRequest:BOXFileRequest = contentClient.fileInfoRequest(withID: file.modelID)
                fileRequest.perform(completion: { (boxFile, error) in
                    if error == nil && boxFile != nil {
                        //print(file.modelID, totalSize, boxFile!.size)
                        progressFileList.append(ProgressFile(fileID: file.modelID, bytesTransferred: 0, totalBytes: Int64(truncating: boxFile!.size)))
                        totalSizeGroup.leave()
                    }
                })
                DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + UpdateManagerConstants.timeoutInterval, execute: { fileRequest.cancel() })
            }
            
            totalSizeGroup.wait()
            DispatchQueue.main.async { self.progressView.startTracking(withFiles: progressFileList) }
            
            self.boxFilesDownload(contentClient: contentClient, filesToDownload: self.filesToDownload, completion: {
                self.fileHousekeeping()
            })
            
        }
    }
    
    @IBAction func logOut(_ sender: UIButton) { BOXContentClient.logOutAll() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.progressView.isHidden = true
        
        //self.progressView.frame = CGRect(x: 0, y: 0, width: 200, height: 40)
        self.view.addSubview(self.progressView)
        
        self.view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: progressView, attribute: .centerX, relatedBy: .equal, toItem: self.view , attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .centerY, relatedBy: .equal, toItem: self.view, attribute: .centerY, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .leading, relatedBy: .equal, toItem: self.view, attribute: .leading, multiplier: 1, constant: 2).isActive = true
        NSLayoutConstraint(item: progressView, attribute: .trailing, relatedBy: .equal, toItem: self.view, attribute: .trailing, multiplier: 1, constant: -2).isActive = true
        UserDefaultsManager.storedFiles?.removeAll()
        //print("prev",UserDefaultsManager.storedFiles?.count)
        //UserDefaultsManager.storedFiles = [BoxFileBasics]()
        //print("after",UserDefaultsManager.storedFiles?.count)
        
        //UserDefaultsManager.lastSyncedDate = Date()
        //print(UserDefaultsManager.lastSyncedDate)
    }
    
    func boxFilesDownload(contentClient:BOXContentClient, filesToDownload: [BoxFileBasics], completion:@escaping ()->Void){
        let dispatchGroup = DispatchGroup()
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            for file in filesToDownload {
                let localFilePath: String = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(file.modelID).path
                let downloadRequest = contentClient.fileDownloadRequest(withID: file.modelID, toLocalFilePath: localFilePath)
                
                
                dispatchGroup.enter()
                downloadRequest?.perform(progress: { (totalTransferred, totalExpected) in
                    DispatchQueue.main.async { self.progressView.updateFileProgress(fileID: file.modelID, bytesTransferred: totalTransferred) }
                    //update progress bar
                    //print(boxFileBasics.name, totalTransferred, totalExpected)
                }, completion: { (error:Error!) in
                    dispatchGroup.leave()
                    if error == nil {
                        if file.name.hasSuffix(".jpg") {
                            if let image = UIImage(contentsOfFile: localFilePath) {
                                do {
                                    try Disk.save(image, to: .applicationSupport, as: file.name)
                                    print("File saved:\(file.name)")
                                }
                                catch { print("boxFilesDownload: Error saving IMAGE: \(file.name)") }
                            }
                            else { print("boxFilesDownload: Error saving IMAGE to temp folder: \(file.name)") }
                        }
                        else {
                            do {
                                let data = try Data(contentsOf: URL(fileURLWithPath: localFilePath))
                                do {
                                    try Disk.save(data, to: .applicationSupport, as: file.name)
                                    print("File saved:\(file.name)")
                                }
                                catch { print("boxFilesDownload: Error saving FILE: \(file.name)") }
                            }
                            catch { print("boxFilesDownload: Error saving FILE to temp folder: \(file.name)") }
                        }
                        if self.newFiles.contains(file) { UserDefaultsManager.addFileToList(fileDetails: file) }
                        else if self.changedFiles.contains(file) { UserDefaultsManager.updateFileInList(fileDetails: file) }
                        else { print("boxFilesDownload: Error updating offline file list") }
                    }
                    else { print("boxFilesDownload: Error downloading file: \(file.name)") }
                } )
            }
            
            dispatchGroup.wait()
            DispatchQueue.main.async {
                self.progressView.stopIndicator()
                //self.statusText.text.append(contentsOf: "Finished downloading files\n")
            }
            completion()
        }
    }
    
    private func fileHousekeeping() {
        if UserDefaultsManager.storedFiles != nil {
            var filesToDelete = UserDefaultsManager.storedFiles!
            for file in onlineFiles { filesToDelete = filesToDelete.filter { $0 != file } }
            if filesToDelete.count == 0 {
                print("No files to delete")
                return
            }
            for file in filesToDelete {
                do {
                    try Disk.remove(file.name, from: .applicationSupport)
                    UserDefaultsManager.deleteFileFromList(fileModelID: file.modelID)
                    print("Deleted file: \(file.name)")
                }
                catch { print("fileHouseKeeping: Error removing file: \(file.name)") }
            }
        }
        else { print("No offline files") }
    }
    
    private func showApple() {
        do {
            //let image = try Disk.retrieve("apple.jpg", from: .applicationSupport, as: UIImage.self)
            //DispatchQueue.main.sync { self.imageView.image = image }
        }
        catch { }
    }
    
    private func connectedToNetwork() -> Bool {
        
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return false
        }
        
        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }
        
        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)
        
        return (isReachable && !needsConnection)
    }
    
    
}

