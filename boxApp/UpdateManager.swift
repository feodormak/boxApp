//
//  UpdateManager.swift
//  boxApp
//
//  Created by feodor on 10/12/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import UIKit
import Disk
import BoxContentSDK
import SystemConfiguration

struct BoxFileBasics: Codable {
    let name: String
    let modelID: String
    var version: String
    var size: Int64
}

extension BoxFileBasics: Equatable {
    static func == (lhs: BoxFileBasics, rhs: BoxFileBasics) -> Bool {
        return lhs.modelID == rhs.modelID && lhs.name == rhs.name && lhs.version == rhs.version && lhs.size == rhs.size
    }
}

enum UpdateManagerConstants {
    static let timeoutInterval:DispatchTimeInterval = .seconds(5)
}

enum UpdateManagerCompletionStatus{
    case successful
    case noConnection
    case error
}

protocol UpdateManagerDelegate {
    func startTracking(withFiles:[ProgressFile])
    func updateFileProgress(fileID: String, bytesTransferred: Int64)
}

class UpdateManager {
    //private let contentClient:BOXContentClient = BOXContentClient.default()
    
    private var onlineFiles = [BoxFileBasics]()
    private var newFiles = [BoxFileBasics]()
    private var changedFiles = [BoxFileBasics]()
    private var filesToDownload = [BoxFileBasics]()
    private var filesToDelete = [BoxFileBasics]()
    
    private var fileDownloadRequestList = [BOXFileDownloadRequest]()
    
    var delegate: UpdateManagerDelegate?
    
    func checkFiles(contentClient:BOXContentClient ,completion: @escaping(UpdateManagerCompletionStatus, Int?) -> Void) {
        self.resetFileArrays()
        if self.connectedToNetwork() == false {
            print("no internet")
            completion(.noConnection, nil)
        }
        else {
            if contentClient.session.isAuthorized() == false {
                contentClient.authenticate{(user, error) in
                    if error == nil && user != nil {
                        self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { dispatchResult in
                            switch dispatchResult {
                            case .success:
                                self.getDownloadFileList()
                                completion(.successful, self.filesToDownload.count)
                            case .timedOut:
                                completion(.error, nil)
                            }
                        })
                    }
                    else { completion(.error, nil) }
                }
            }
                
            else {
                self.getItemsFromBaseFolder(contentClient: contentClient, completionHandler: { dispatchResult in
                    switch dispatchResult {
                    case .success:
                        self.getDownloadFileList()
                        completion(.successful, self.filesToDownload.count)
                    case .timedOut:
                        completion(.error, nil)
                    }
                })
            }
        }
    }
    
    func downloadFiles(contentClient: BOXContentClient, completion: @escaping(UpdateManagerCompletionStatus)-> Void) {
        if self.connectedToNetwork() == false { completion(.noConnection) }
        else {
            /*
            let dispatchGroup = DispatchGroup()
            DispatchQueue.global(qos: .userInitiated).async {
                
                var  progressFileList = [ProgressFile]()
                let workItem = DispatchWorkItem {
                    for file in self.filesToDownload {
                        dispatchGroup.enter()
                        
                        let fileRequest:BOXFileRequest = contentClient.fileInfoRequest(withID: file.modelID)
                        self.fileRequestList.append(fileRequest)
                        fileRequest.perform(completion: { (boxFile, error) in
                            if error == nil && boxFile != nil {
                                print(file.modelID, boxFile!.size)
                                progressFileList.append(ProgressFile(fileID: file.modelID, bytesTransferred: 0, totalBytes: Int64(truncating: boxFile!.size)))
                                dispatchGroup.leave()
                            }
                            self.fileRequestList.remove(at: self.fileRequestList.index(of: fileRequest)!)
                        })
                        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + UpdateManagerConstants.timeoutInterval, execute: { fileRequest.cancel() })
                    }
                }
                DispatchQueue.global(qos: .userInitiated).async(execute: workItem)
                
                let groupWait = dispatchGroup.wait(timeout: .now() + UpdateManagerConstants.timeoutInterval)
                //DispatchQueue.main.async { self.progressView.startTracking(withFiles: progressFileList) }
                
                switch groupWait {
                case .success:*/
            var progressFileList = [ProgressFile]()
            for file in filesToDownload { progressFileList.append(ProgressFile(fileID: file.modelID, bytesTransferred: 0, totalBytes: file.size)) }
            self.delegate?.startTracking(withFiles: progressFileList)
            self.boxFilesDownload(contentClient: contentClient, filesToDownload: self.filesToDownload, completion: { completionStatus in
                switch completionStatus {
                case .successful:
                    self.fileHousekeeping()
                    completion(.successful)
                case .error: completion(.error)
                case .noConnection: return
                }
            })
        }
    }

    func cancelDownloads(contentClient:BOXContentClient) {
        for request in self.fileDownloadRequestList { request.cancel() }
        self.fileDownloadRequestList.removeAll()
    }
    
    private func getItemsFromBaseFolder(contentClient: BOXContentClient, completionHandler: @escaping(DispatchTimeoutResult)-> Void) {
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
            completionHandler(groupWait)
        }
    }
    
    private func getFolderItems(contentClient:BOXContentClient ,folderID:String, completionHanlder: @escaping ([BoxFileBasics]?) -> Void) {
        let folderItemsRequest:BOXFolderItemsRequest = contentClient.folderItemsRequest(withID: folderID)
        folderItemsRequest.requestAllItemFields = true
        var fileList = [BoxFileBasics]()
        let dispatchGroup = DispatchGroup()
        
        DispatchQueue.global(qos: .userInitiated).async {
            folderItemsRequest.perform { (items:[BOXItem]?, error:Error!) in
                if error == nil && items != nil {
                    for item in items! {
                        if item.isFile == true {
                            fileList.append(BoxFileBasics(name: item.name, modelID: item.modelID, version: item.etag, size: Int64(truncating: item.size)))
                            //print(item.name, item.modelID, item.etag, item.size, fileList.count)
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
    
    private func getDownloadFileList() {
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
        
        print("to download:\(filesToDownload.count)", "changed: \(changedFiles.count)", "new: \(newFiles.count)")
    }
    
    private func boxFilesDownload(contentClient:BOXContentClient, filesToDownload: [BoxFileBasics], completion:@escaping (UpdateManagerCompletionStatus)->Void){
        let dispatchGroup = DispatchGroup()
        
        DispatchQueue.global(qos: .userInitiated).async {
            var errorOccured = false
            for file in filesToDownload {
                let localFilePath: String = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(file.modelID).path
                let downloadRequest = contentClient.fileDownloadRequest(withID: file.modelID, toLocalFilePath: localFilePath)
                
                dispatchGroup.enter()
                if let request = downloadRequest { self.fileDownloadRequestList.append(request) }
                
                downloadRequest?.perform(progress: { (totalTransferred, totalExpected) in
                    self.delegate?.updateFileProgress(fileID: file.modelID, bytesTransferred: totalTransferred)
                    //print(boxFileBasics.name, totalTransferred, totalExpected)
                }, completion: { (error:Error!) in
                    if let request = downloadRequest {
                        if let index = self.fileDownloadRequestList.index(of: request) {
                            self.fileDownloadRequestList.remove(at: index)
                            print("removed request: \(request)")
                        }
                    }
                    
                    if error == nil {
                        //saving image
                        if file.name.hasSuffix(".jpg") {
                            if let image = UIImage(contentsOfFile: localFilePath) {
                                do {
                                    try Disk.save(image, to: .applicationSupport, as: file.name)
                                    NSLog("File saved:\(file.name)")
                                }
                                catch {
                                    NSLog("boxFilesDownload: Error saving IMAGE: \(file.name)")
                                    errorOccured = true
                                }
                            }
                            else {
                                NSLog("boxFilesDownload: Error saving IMAGE to temp folder: \(file.name)")
                                errorOccured = true
                            }
                        }
                        //saving all other types of files
                        else {
                            do {
                                let data = try Data(contentsOf: URL(fileURLWithPath: localFilePath))
                                do {
                                    try Disk.save(data, to: .applicationSupport, as: file.name)
                                    NSLog("File saved:\(file.name)")
                                }
                                catch {
                                    NSLog("boxFilesDownload: Error saving FILE: \(file.name)")
                                    errorOccured = true
                                }
                            }
                            catch {
                                NSLog("boxFilesDownload: Error saving FILE to temp folder: \(file.name)")
                                errorOccured = true
                            }
                        }
                        
                        //recording to UserDefaults
                        if self.newFiles.contains(file) { UserDefaultsManager.addFileToList(fileDetails: file) }
                        else if self.changedFiles.contains(file) { UserDefaultsManager.updateFileInList(fileDetails: file) }
                        else {
                            NSLog("boxFilesDownload: Error updating offline file list")
                            errorOccured = true
                        }
                    }
                    else {
                        NSLog("boxFilesDownload: Error downloading file: \(file.name)")
                        errorOccured = true
                    }
                    
                    dispatchGroup.leave()
                } )
            }
            dispatchGroup.wait()
            completion(errorOccured ? .error : .successful)
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
    
    private func resetFileArrays() {
        self.changedFiles.removeAll()
        self.filesToDelete.removeAll()
        self.filesToDownload.removeAll()
        self.newFiles.removeAll()
        self.onlineFiles.removeAll()
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
