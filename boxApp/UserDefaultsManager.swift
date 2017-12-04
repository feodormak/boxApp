//
//  UserDefaultsManager.swift
//  boxApp
//
//  Created by feodor on 3/12/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import Foundation

class UserDefaultsManager {
    
    static var lastSyncedDate: Date {
        get { return UserDefaults.standard.object(forKey: "lastBoxSyncedDate") as! Date}
        set { UserDefaults.standard.set(newValue, forKey: "lastBoxSyncedDate")}
    }
    
    static var storedFiles:[BoxFileBasics]? {
        get {
            if let data = UserDefaults.standard.value(forKey: "storedFilesList") as? Data {
                let decoder = JSONDecoder()
                return try? decoder.decode(Array.self, from: data) as [BoxFileBasics] }
            else { return nil }
        }
        set {
            let encoder = JSONEncoder()
            if let encoded = try? encoder.encode(newValue) {
            UserDefaults.standard.set(encoded, forKey: "storedFilesList") }
        }
    }
}
