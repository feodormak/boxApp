//
//  UserDefaultsManager.swift
//  boxApp
//
//  Created by feodor on 3/12/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import Foundation

class UserDefaultsManager {
    private static let storedfileKey = "storedFilesList"
    
    static var lastSyncedDate: Date {
        get { return UserDefaults.standard.object(forKey: "lastBoxSyncedDate") as! Date}
        set { UserDefaults.standard.set(newValue, forKey: "lastBoxSyncedDate")}
    }
    
    static var storedFiles:[BoxFileBasics]? {
        get {
            if let data = UserDefaults.standard.value(forKey: storedfileKey) as? Data {
                let decoder = JSONDecoder()
                return try? decoder.decode(Array.self, from: data) as [BoxFileBasics] }
            else { return nil }
        }
        set {
            if newValue == nil { UserDefaults.standard.set(nil, forKey: storedfileKey) }
            else {
                let encoder = JSONEncoder()
                if let encoded = try? encoder.encode(newValue) {
                    UserDefaults.standard.set(encoded, forKey: storedfileKey) }
            }
        }
    }
    static func addFileToList(fileDetails:BoxFileBasics) {
        if UserDefaultsManager.storedFiles == nil { UserDefaultsManager.storedFiles = [BoxFileBasics]() }
        guard UserDefaultsManager.storedFiles != nil else {
            NSLog("UserDefaultsManager.storedFiles ERROR: Unable to initialise")
            fatalError("UserDefaultsManager.storedFiles: Unable to initialise")
        }
        
        guard UserDefaultsManager.fileExistInList(modelID: fileDetails.modelID) == false else {
            NSLog("UserDefaultsManager.storedFiles: Error adding \"\(fileDetails.name)\" to list. File already exist in list")
            return
        }
        
        UserDefaultsManager.storedFiles!.append(fileDetails)
    }
    
    private static func fileExistInList(modelID:String) -> Bool {
        return UserDefaultsManager.storedFiles!.contains(where: { $0.modelID == modelID })
    }
    
    static func updateFileInList(fileDetails:BoxFileBasics) {
        guard UserDefaultsManager.storedFiles != nil else { return }
        guard UserDefaultsManager.fileExistInList(modelID: fileDetails.modelID) == true else {
            NSLog("UserDefaultsManager.storedFiles ERROR updating: \"\(fileDetails.modelID)\" not found")
            return
        }
        
        switch UserDefaultsManager.storedFiles!.filter({$0.modelID == fileDetails.modelID}).count {
        case 0: NSLog("UserDefaultsManager.storedFiles ERROR updating: \"\(fileDetails.modelID)\" not found")
        case 1:
            UserDefaultsManager.storedFiles!.remove(at: UserDefaultsManager.storedFiles!.index(where: {$0.modelID == fileDetails.modelID})!)
            UserDefaultsManager.addFileToList(fileDetails: fileDetails)
        default: NSLog("UserDefaultsManager.storedFiles ERROR deleting: multiple instances of \"\(fileDetails.modelID)\" found")
        }
    }
    
    static func deleteFileFromList(fileModelID: String) {
        guard UserDefaultsManager.storedFiles != nil else { return }
        guard UserDefaultsManager.storedFiles!.isEmpty != true else { return }
        
        switch UserDefaultsManager.storedFiles!.filter({$0.modelID == fileModelID}).count {
        case 0: NSLog("UserDefaultsManager.storedFiles ERROR deleting: \"\(fileModelID)\" not found")
        case 1: UserDefaultsManager.storedFiles!.remove(at: UserDefaultsManager.storedFiles!.index(where: {$0.modelID == fileModelID})!)
        default: NSLog("UserDefaultsManager.storedFiles ERROR deleting: multiple instances of \"\(fileModelID)\" found")
        }
    }
}
