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
}

extension BoxFileBasics: Equatable {
    static func == (lhs: BoxFileBasics, rhs: BoxFileBasics) -> Bool {
        return lhs.modelID == rhs.modelID && lhs.name == rhs.name && lhs.version == rhs.version
    }
}

enum UpdateManagerConstants {
    static let timeoutInterval:DispatchTimeInterval = .seconds(30)
}

class UpdateManager {
    
}
