//
//  MZUtility.swift
//  MZDownloadManager
//
//  Created by Muhammad Zeeshan on 22/10/2014.
//  Copyright (c) 2014 ideamakerz. All rights reserved.
//

import UIKit

let fileDest               : NSString = NSHomeDirectory().stringByAppendingPathComponent("Documents")
let DownloadCompletedNotif : NSString = "DownloadCompletedNotif"
let kAlertTitle            : NSString = "Message"

class MZUtility: NSObject {
    
    class func showAlertViewWithTitle(titl : NSString, msg : NSString) {
        var alertview : UIAlertView = UIAlertView()
        alertview.title = titl
        alertview.message = msg
        alertview.addButtonWithTitle("Ok")
        alertview.cancelButtonIndex = 0
        alertview.show()
    }
    
    class func getUniqueFileNameWithPath(filePath : NSString) -> NSString {
        var fullFileName        : NSString = filePath.lastPathComponent
        var fileName            : NSString = fullFileName.stringByDeletingPathExtension
        var fileExtension       : NSString = fullFileName.pathExtension
        var suggestedFileName   : NSString = fileName
        
        var isUnique            : Bool = false
        var fileNumber          : Int = 0
        
        var fileManger          : NSFileManager = NSFileManager.defaultManager()
        
        do {
            var fileDocDirectoryPath : NSString?
            
            if fileExtension.length > 0 {
                fileDocDirectoryPath = "\(filePath.stringByDeletingLastPathComponent)/\(suggestedFileName).\(fileExtension)"
            } else {
                fileDocDirectoryPath = "\(filePath.stringByDeletingLastPathComponent)/\(suggestedFileName)"
            }
            
            var isFileAlreadyExists : Bool = fileManger.fileExistsAtPath(fileDocDirectoryPath!)
            
            if isFileAlreadyExists {
                fileNumber++
                suggestedFileName = "\(fileName)(\(fileNumber))"
            } else {
                isUnique = true
                if fileExtension.length > 0 {
                    suggestedFileName = "\(suggestedFileName).\(fileExtension)"
                }
            }
        
        } while isUnique == false
        
        return suggestedFileName
    }
    
    class func calculateFileSizeInUnit(contentLength : Int64) -> Float {
        var dataLength : Float64 = Float64(contentLength)
        if dataLength >= (1024.0*1024.0*1024.0) {
            return Float(dataLength/(1024.0*1024.0*1024.0))
        } else if dataLength >= 1024.0*1024.0 {
            return Float(dataLength/(1024.0*1024.0))
        } else if dataLength >= 1024.0 {
            return Float(dataLength/1024.0)
        } else {
            return Float(dataLength)
        }
    }
    
    class func calculateUnit(contentLength : Int64) -> NSString {
        if(contentLength >= (1024*1024*1024)) {
            return "GB"
        } else if contentLength >= (1024*1024) {
            return "MB"
        } else if contentLength >= 1024 {
            return "KB"
        } else {
            return "Bytes"
        }
    }
    
    class func addSkipBackupAttributeToItemAtURL(docDirectoryPath : NSString) -> Bool {
        var url : NSURL = NSURL(fileURLWithPath: docDirectoryPath)!
        var fileManager = NSFileManager.defaultManager()
        if fileManager.fileExistsAtPath(url.path!) {
            var error : NSError?
            var success : Bool = url.setResourceValue(NSNumber(bool: true), forKey: NSURLIsExcludedFromBackupKey, error: &error)
            if let hasError = error {
                println("Error excluding \(url.lastPathComponent) from backup \(error)")
            }
            return success
        } else {
            return false
        }
    }
    
    class func getFreeDiskspace() -> Int64? {
        var error : NSError?
        let documentDirectoryPath = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        if let systemAttributes = NSFileManager.defaultManager().attributesOfFileSystemForPath(documentDirectoryPath.last as String, error: &error) {
            if let freeSize = systemAttributes[NSFileSystemFreeSize] as? NSNumber {
                return freeSize.longLongValue
            }
        }
        if let hasError = error {
            println("Error Obtaining System Memory Info: Domain = \(error?.domain), Code = \(error?.code)")
        }
        return nil
    }
}
