//
//  ViewController.swift
//  boxApp
//
//  Created by feodor on 17/10/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import UIKit
import BoxContentSDK
import Disk

struct BoxFileBasics: Codable {
    let name: String
    let modelID: String
    var version: String
}

class ViewController: UIViewController {
    //let contentClient:BOXContentClient = BOXContentClient.default()
    var onlineFiles = [BoxFileBasics]()
    
    @IBOutlet weak var connectionStatus: UILabel!
    @IBOutlet weak var numberOfFiles: UILabel!
    @IBOutlet weak var fileNames: UILabel!
    
    @IBAction func saveToAppSupp(_ sender: UIButton) {
      let contentClient:BOXContentClient = BOXContentClient.default()
        contentClient.authenticate(completionBlock: {(user: BOXUser?, error:Error!)-> Void in
            if error == nil && user != nil { self.getFolderItems(contentClient: contentClient, folderID: "0")}
        })
        print("that is last")
        /*    let image = UIImage(named: "apple.png")
        do {
            try Disk.save(image!, to: .applicationSupport, as: "apple.png")
        }
        catch { print("error saving") }
     */
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
        print("prev",UserDefaultsManager.storedFiles)
        //UserDefaultsManager.storedFiles = [BoxFileBasics]()
        UserDefaultsManager.storedFiles?.append(BoxFileBasics(name: "a", modelID: "a", version: "1"))
        print("after",UserDefaultsManager.storedFiles)

        UserDefaultsManager.lastSyncedDate = Date()
        print(UserDefaultsManager.lastSyncedDate)
        // Do any additional setup after loading the view, typically from a nib.
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getFolderItems(contentClient:BOXContentClient ,folderID:String) {
        let folderItemsRequest:BOXFolderItemsRequest = contentClient.folderItemsRequest(withID: folderID)
        folderItemsRequest.perform { (items:[BOXItem]?, error:Error!) in
            if error == nil {
                if items != nil {
                    for item in items! {
                        if item.isFile == true {
                            print(item.name, item.modelID, item.etag)
                            self.onlineFiles.append(BoxFileBasics(name: item.name, modelID: item.modelID, version: item.etag))
                        }
                        else if item.isFolder == true { self.getFolderItems(contentClient: contentClient, folderID: item.modelID) }
                    }
                }
                else { print("folder is empty") }
            }
            else { print("error getting folder") }
        }
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
}

