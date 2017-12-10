//
//  ProgressView.swift
//  boxApp
//
//  Created by feodor on 10/12/17.
//  Copyright © 2017 feodor. All rights reserved.
//

import UIKit

enum ProgressViewConstants {
    static let textFontSize: CGFloat = 10.0
}

struct ProgressFile {
    let fileID:String
    var bytesTransferred: Int64
    let totalBytes: Int64
}


class ProgressView: UIView {
    private let progressBar:UIProgressView = {
        let bar = UIProgressView()
        bar.progressTintColor = .red
        bar.tintColor = .white
        bar.progress = 0.5
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()
    private let transferredBytesLabel:UILabel = {
        let label = UILabel()
        label.text = "0.0"
        label.font =  UIFont.systemFont(ofSize: ProgressViewConstants.textFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sizeToFit()
        return label
    }()
    private let bytesOfLabel: UILabel = {
        let label = UILabel()
        label.text = "of"
        label.font =  UIFont.systemFont(ofSize: ProgressViewConstants.textFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sizeToFit()
        return label
    }()
    private let totalBytesLabel: UILabel = {
        let label = UILabel()
        label.text = "Total"
        label.font =  UIFont.systemFont(ofSize: ProgressViewConstants.textFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sizeToFit()
        return label
    }()
    
    private let filesOfLabel: UILabel = {
        let label = UILabel()
        label.text = "of"
        label.font =  UIFont.systemFont(ofSize: ProgressViewConstants.textFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sizeToFit()
        return label
    }()
    private let completedFilesLabel: UILabel = {
        let label = UILabel()
        label.text = "0"
        label.font =  UIFont.systemFont(ofSize: ProgressViewConstants.textFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sizeToFit()
        return label
    }()
    private let totalFilesLabel: UILabel = {
        let label = UILabel()
        label.text = "Files"
        label.font =  UIFont.systemFont(ofSize: ProgressViewConstants.textFontSize)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.sizeToFit()
        return label
    }()
    
    private let bytesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .trailing
        stack.distribution = .fill
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    } ()
    private let filesStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .leading
        stack.distribution = .fill
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    } ()
    
    private let activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView()
        indicator.activityIndicatorViewStyle = .gray
        indicator.hidesWhenStopped = true
        indicator.frame.size = CGSize(width: 20, height: 20)
        indicator.translatesAutoresizingMaskIntoConstraints = false
        return indicator
    }()
    
    private var totalNumberOfFiles: Int = 0
    private var numberOfTransferredFiles: Int = 0
    private var totalByteCount: Int64 = 0
    private var transferredByteCount: Int64 = 0
    private var files = [ProgressFile]()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        bytesStack.addArrangedSubview(self.transferredBytesLabel)
        bytesStack.addArrangedSubview(self.bytesOfLabel)
        bytesStack.addArrangedSubview(self.totalBytesLabel)
        
        filesStack.addArrangedSubview(self.completedFilesLabel)
        filesStack.addArrangedSubview(self.filesOfLabel)
        filesStack.addArrangedSubview(self.totalFilesLabel)
        
        self.addSubview(self.activityIndicator)
        self.addSubview(self.progressBar)
        self.addSubview(self.bytesStack)
        self.addSubview(self.filesStack)
        
        self.progressBar.isHidden = true
        self.filesStack.isHidden = true
        self.bytesStack.isHidden = true
        
        NSLayoutConstraint(item: self.activityIndicator, attribute: .top, relatedBy: .equal, toItem: self, attribute: .top, multiplier: 1, constant: 2).isActive = true
        NSLayoutConstraint(item: self.activityIndicator, attribute: .centerX, relatedBy: .equal, toItem: self, attribute: .centerX, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: self.progressBar, attribute: .left, relatedBy: .equal, toItem: self, attribute: .left, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: self.progressBar, attribute: .right, relatedBy: .equal, toItem: self, attribute: .right, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: self.progressBar, attribute: .top, relatedBy: .equal, toItem: activityIndicator, attribute: .bottom, multiplier: 1, constant: 4).isActive = true
        NSLayoutConstraint(item: self.bytesStack, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: self.bytesStack, attribute: .top, relatedBy: .equal, toItem: progressBar, attribute: .bottom, multiplier: 1, constant: 4).isActive = true
        NSLayoutConstraint(item: self.bytesStack, attribute: .trailing, relatedBy: .equal, toItem: self, attribute: .trailing, multiplier: 1, constant: -2).isActive = true
        NSLayoutConstraint(item: self.filesStack, attribute: .leading, relatedBy: .equal, toItem: self, attribute: .leading, multiplier: 1, constant: 2).isActive = true
        NSLayoutConstraint(item: self.filesStack, attribute: .bottom, relatedBy: .equal, toItem: self, attribute: .bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: self.filesStack, attribute: .top, relatedBy: .equal, toItem: progressBar, attribute: .bottom, multiplier: 1, constant: 4).isActive = true
        
        self.translatesAutoresizingMaskIntoConstraints = false
        self.backgroundColor = UIColor.lightGray
        //self.activityIndicator.startAnimating()
    }
    
    func startTracking(withFiles: [ProgressFile]) {
        self.reset()
        self.files = withFiles
        var totalBytes: Int64 = 0
        for file in withFiles { totalBytes += file.totalBytes }
        self.totalNumberOfFiles = withFiles.count
        self.totalByteCount = totalBytes
        self.totalBytesLabel.text = ByteCountFormatter.string(fromByteCount: totalByteCount, countStyle: .file)
        self.totalFilesLabel.text = String(totalNumberOfFiles)
        self.activityIndicator.startAnimating()
        self.progressBar.isHidden = false
        self.filesStack.isHidden = false
        self.bytesStack.isHidden = false
    }
    
    func startIndicator() { self.activityIndicator.startAnimating() }
    func stopIndicator() { self.activityIndicator.stopAnimating() }

    func updateFileProgress(fileID: String, bytesTransferred: Int64) {
        if let index = files.index(where: { $0.fileID == fileID }) {
            files[index].bytesTransferred = bytesTransferred
            self.updateProgress()
        }
    }
    
    private func updateProgress() {
        self.transferredByteCount = 0
        self.numberOfTransferredFiles = 0
        for file in files {
            self.transferredByteCount += file.bytesTransferred
            if file.bytesTransferred == file.totalBytes { self.numberOfTransferredFiles += 1 }
        }
        self.progressBar.progress = Float(self.transferredByteCount) / Float(self.totalByteCount)
        self.transferredBytesLabel.text = ByteCountFormatter.string(fromByteCount: self.transferredByteCount, countStyle: .file)
        self.completedFilesLabel.text = String(self.numberOfTransferredFiles)
        //print("progress: \(self.progressBar.progress)")
    }
    
    private func reset() {
        self.files.removeAll()
        self.totalByteCount = 0
        self.transferredByteCount = 0
        self.totalNumberOfFiles = 0
        self.numberOfTransferredFiles = 0
        self.progressBar.progress = 0
        self.totalFilesLabel.text = "Files"
        self.completedFilesLabel.text = "0"
        self.transferredBytesLabel.text = "0.0"
        self.totalBytesLabel.text = "Total"
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
