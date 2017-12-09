//
//  ProgressBar.swift
//  boxApp
//
//  Created by feodor on 10/12/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import UIKit

struct ProgressFile {
    let fileID:String
    var bytesTransferred: Int64
}

class ProgressBar: UIProgressView {
    private var files = [ProgressFile]()
    var totalBytes: Int64 = 0
    var transferredBytes: Int64 = 0
    
    func addFile(file: ProgressFile) { self.files.append(file) }
    
    func updateFileProgress(fileID: String, bytesTransferred: Int64) {
        if let index = files.index(where: { $0.fileID == fileID }) {
            files[index].bytesTransferred = bytesTransferred
            self.updateProgressbar()
        }
    }
    
    private func updateProgressbar() {
            self.transferredBytes = 0
            for file in files { self.transferredBytes += file.bytesTransferred }
            self.progress = Float(self.transferredBytes) / Float(self.totalBytes)
            print("progress: \(self.progress)")
        
    }
}