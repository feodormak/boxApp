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

struct BoxFileBasics: Codable {
    let name: String
    let modelID: String
    var version: String
}

extension BoxFileBasics: Equatable {
    static func == (lhs: BoxFileBasics, rhs: BoxFileBasics) -> Bool {
        return lhs.modelID == rhs.modelID && lhs.name == rhs.name && lhs.version == rhs.version
    }
}

enum UpdateManagerConstants {
    static let timeoutInterval:DispatchTimeInterval = .seconds(30)
}

class ViewController: UIViewController {
    //let contentClient:BOXContentClient = BOXContentClient.default()
    var onlineFiles = [BoxFileBasics]()
    //var onlineFiles = SynchronizedArray<BoxFileBasics>()
    
    var newFiles = [BoxFileBasics]()
    var changedFiles = [BoxFileBasics]()
    var filesToDownload = [BoxFileBasics]()
    var filesToDelete = [BoxFileBasics]()
    
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var statusText: UITextView!
    @IBOutlet weak var downloadProgress: ProgressBar!
    @IBOutlet weak var currentBytesLabel: UILabel!
    @IBOutlet weak var totalBytesLabel: UILabel!
    @IBOutlet weak var downloadProgressStack: UIStackView!
    
    @IBAction func checkFiles(_ sender: UIButton) {
        self.activityIndicator.isHidden = false
        self.activityIndicator.startAnimating()
        let contentClient:BOXContentClient = BOXContentClient.default()
        
        if self.connectedToNetwork() == false {
            self.statusText.text.append(contentsOf: "No internet\n")
            //print("no internet")
            return
        }
        else { self.statusText.text.append(contentsOf: "Internet connection... OK\n") }
        
        self.onlineFiles.removeAll()
        
        if contentClient.session.isAuthorized() == false {
            self.statusText.text.append(contentsOf: "Not logged in to Box account. Logging in...\n")
            contentClient.authenticate{(user, error) in
            if error == nil && user != nil { self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { _ in self.getDownloadFileList() })}
            } }
        
        else { self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { _ in self.getDownloadFileList() })}
        
        //DispatchQueue.main.async { self.activityIndicator.stopAnimating() }
       
        /*    let image = UIImage(named: "apple.png")
         do {
         try Disk.save(image!, to: .applicationSupport, as: "apple.png")
         }
         catch { print("error saving") }
         */
    }
    
    func getItemsFromBaseFolder(contentClient: BOXContentClient, completionHandler: @escaping(DispatchTimeoutResult)-> Void) {
        let dispatchGroup = DispatchGroup()
        self.statusText.text.append(contentsOf: "Getting list of files...\n")
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
                DispatchQueue.main.async(execute: {self.statusText.text.append(contentsOf: "Connection timed out. Check internet connenction\n") })
                workItem.cancel()
            }
            else {
                DispatchQueue.main.async(execute: { self.statusText.text.append(contentsOf: "Total no. of remote files: \(self.onlineFiles.count)\nDone getting Box files\n") })
                print("done")
            }
            DispatchQueue.main.async(execute: {
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
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
        filesToDownload.append(contentsOf: newFiles + changedFiles)
        DispatchQueue.main.async { self.statusText.text.append(contentsOf: "No. of files to be downloaded: \(self.filesToDownload.count)\n") }
        print("to download:\(filesToDownload.count)", "changed: \(changedFiles.count)", "new: \(newFiles.count)")
    }
    
    @IBAction func downloadFiles(_ sender: UIButton) {
        let contentClient: BOXContentClient = BOXContentClient.default()
        
        
        let totalSizeGroup = DispatchGroup()
        var totalSize = 0
        self.activityIndicator.isHidden = false
        self.activityIndicator.startAnimating()
        DispatchQueue.global(qos: .userInitiated).async {
            
            for file in self.filesToDownload {
                totalSizeGroup.enter()
                
                let fileRequest:BOXFileRequest = contentClient.fileInfoRequest(withID: file.modelID)
                fileRequest.perform(completion: { (boxFile, error) in
                    if error == nil && boxFile != nil {
                        print(totalSize, boxFile!.size)
                        totalSize += Int(truncating: boxFile!.size)
                        totalSizeGroup.leave()
                    }
                })
            }
            
            totalSizeGroup.wait()
            self.boxFilesDownload(contentClient: contentClient, filesToDownload: self.filesToDownload)
            DispatchQueue.main.async {
                self.totalBytesLabel.text = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
                self.currentBytesLabel.text = "0.0"
                self.downloadProgress.progress = 0.0
                self.downloadProgress.totalBytes = Int64(totalSize)
        
                self.downloadProgressStack.isHidden = false
            }
        }
    }
    /*
    @IBAction func getFiles(_ sender: UIButton) {
        let contentClient:BOXContentClient = BOXContentClient.default()
        contentClient.authenticate(completionBlock: {(user:BOXUser?, error:Error?) -> Void in
            if error == nil {
                if user != nil { self.connectionStatus.text = user!.login as String }
                
                let folderItemsRequest:BOXFolderItemsRequest = contentClient.folderItemsRequest(withID: "0")
                folderItemsRequest.perform { (items:[BOXItem]?, error:Error?) in
                    if error == nil && items != nil {
                        self.numberOfFiles.text = String(items!.count)
                        for item in items! {
                            if item.isFile { self.boxFileDownload(contentClient: contentClient, boxItem: item) }
                        }
                    }
                    else { print("error getting folder items: ", error!) }
                }
            }
            else { print("error logging in: ", error!)}
        })
        
    }
     */
    @IBAction func logOut(_ sender: UIButton) { BOXContentClient.logOutAll() }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.activityIndicator.isHidden = true
        self.downloadProgressStack.isHidden = true
        //print("prev",UserDefaultsManager.storedFiles?.count)
        //UserDefaultsManager.storedFiles = nil
        //print("after",UserDefaultsManager.storedFiles?.count)
        
        //UserDefaultsManager.lastSyncedDate = Date()
        //print(UserDefaultsManager.lastSyncedDate)
    }
    
    func boxFilesDownload(contentClient:BOXContentClient, filesToDownload: [BoxFileBasics]){
        let dispatchGroup = DispatchGroup()
        
        DispatchQueue.global(qos: .userInitiated).async {
            
            for file in filesToDownload {
                let localFilePath: String = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(file.modelID).path
                let downloadRequest = contentClient.fileDownloadRequest(withID: file.modelID, toLocalFilePath: localFilePath)
                
                DispatchQueue.main.async { self.downloadProgress.addFile(file: ProgressFile(fileID: file.modelID, bytesTransferred: 0)) }
                
                dispatchGroup.enter()
                downloadRequest?.perform(progress: { (totalTransferred, totalExpected) in
                    DispatchQueue.main.async { self.downloadProgress.updateFileProgress(fileID: file.modelID, bytesTransferred: totalTransferred) }
                    //update progress bar
                    //print(boxFileBasics.name, totalTransferred, totalExpected)
                }, completion: { (error:Error!) in
                    dispatchGroup.leave()
                    /*
                     if error == nil {
                     do {
                     let image = UIImage(contentsOfFile: localFilePath)
                     try Disk.save(image!, to: .applicationSupport, as: boxFileBasics.name)
                     }
                     catch { print("error saving file") }
                     
                     }
                     else { print("DOWNLOADING FILE ERROR: \(error)") }
                     */
                } )
            }
            
            dispatchGroup.wait()
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.activityIndicator.isHidden = true
                self.statusText.text.append(contentsOf: "Finished downloading files\n")
            }
        }
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

