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

enum UpdateManagerConstants {
    static let timeoutInterval:DispatchTime = .now() + 15
}

class ViewController: UIViewController {
    //let contentClient:BOXContentClient = BOXContentClient.default()
    //var onlineFiles = [BoxFileBasics]()
    var onlineFiles = SynchronizedArray<BoxFileBasics>()
    
    @IBOutlet weak var connectionStatus: UILabel!
    @IBOutlet weak var numberOfFiles: UILabel!
    @IBOutlet weak var fileNames: UILabel!
    
    @IBAction func saveToAppSupp(_ sender: UIButton) {
        let contentClient:BOXContentClient = BOXContentClient.default()
        
        if self.connectedToNetwork() == false {
            print("no internet")
            return
        }
        
        self.onlineFiles.removeAll()
        
        if contentClient.session.isAuthorized() == false { contentClient.authenticate{(user, error) in
            if error == nil && user != nil { self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { _ in })}
            } }
        
        else { self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { _ in }) }
        
        
        /*    let image = UIImage(named: "apple.png")
         do {
         try Disk.save(image!, to: .applicationSupport, as: "apple.png")
         }
         catch { print("error saving") }
         */
    }
    
    func getItemsFromBaseFolder(contentClient: BOXContentClient, completionHandler: @escaping(DispatchTimeoutResult)-> Void) {
        let dispatchGroup = DispatchGroup()
        DispatchQueue.global(qos: .userInitiated).async {
            print("started: \(Date())")
            dispatchGroup.enter()
            let workItem = DispatchWorkItem {
                self.getFolderItems(contentClient: contentClient, folderID: "0") { fileList in
                    if fileList != nil { self.onlineFiles.append(fileList!) }
                    print("main", self.onlineFiles.count)
                    dispatchGroup.leave()
                }
            }
            DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
            
            let groupWait = dispatchGroup.wait(timeout: UpdateManagerConstants.timeoutInterval)
            if groupWait == .timedOut {
                print("timedOUt")
                workItem.cancel()
            }
            else { print("done") }
            
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
                           // print(item.name, item.modelID, item.etag, fileList.count)
                        }
                        else if item.isFolder == true {
                            dispatchGroup.enter()
                            self.getFolderItems(contentClient: contentClient, folderID: item.modelID) { filesInSubFolder in
                                if filesInSubFolder != nil { fileList.append(contentsOf: filesInSubFolder!) }
                                dispatchGroup.leave()
                            }
                        }
                    }
                }
                else { print("error getting folder") }
                dispatchGroup.wait()
                DispatchQueue.main.async {
                   // print("func: ", folderID, fileList.count)
                    completionHanlder(fileList)
                }
            }
        }
        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: UpdateManagerConstants.timeoutInterval, execute: { folderItemsRequest.cancel() })
    }
    
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
    @IBAction func logOut(_ sender: UIButton) {
        BOXContentClient.logOutAll()
        numberOfFiles.text = nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //print("prev",UserDefaultsManager.storedFiles?.count)
        //UserDefaultsManager.storedFiles = nil
        //print("after",UserDefaultsManager.storedFiles?.count)
        
        //UserDefaultsManager.lastSyncedDate = Date()
        //print(UserDefaultsManager.lastSyncedDate)
    }
    
    
    
    func boxFileDownload(contentClient:BOXContentClient, boxItem: BOXItem){
        let localFilePath: String = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(boxItem.name).path
        let downloadRequest = contentClient.fileDownloadRequest(withID: boxItem.modelID, toLocalFilePath: localFilePath)
        
        downloadRequest?.perform(progress: { (totalTransferred, totalExpected) in
            //update progress bar
            //print(totalTransferred, totalExpected)
        }, completion: { (error:Error!) in
            if error == nil {
                
                do {
                    let image = UIImage(contentsOfFile: localFilePath)
                    try Disk.save(image!, to: .applicationSupport, as: boxItem.name)
                }
                catch { print("error saving file") }
                
            }
            else { print("DOWNLOADING FILE ERROR: \(error)") }
        } )
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

