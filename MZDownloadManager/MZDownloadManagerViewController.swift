//
//  MZDownloadManagerViewController.swift
//  MZDownloadManager
//
//  Created by Muhammad Zeeshan on 22/10/2014.
//  Copyright (c) 2014 ideamakerz. All rights reserved.
//

import UIKit

let kMZDownloadKeyURL        : NSString = "URL"
let kMZDownloadKeyStartTime  : NSString = "startTime"
let kMZDownloadKeyFileName   : NSString = "fileName"
let kMZDownloadKeyProgress   : NSString = "progress"
let kMZDownloadKeyTask       : NSString = "downloadTask"
let kMZDownloadKeyStatus     : NSString = "requestStatus"
let kMZDownloadKeyDetails    : NSString = "downloadDetails"
let kMZDownloadKeyResumeData : NSString = "resumedata"

let RequestStatusDownloading : NSString = "RequestStatusDownloading"
let RequestStatusPaused      : NSString = "RequestStatusPaused"
let RequestStatusFailed      : NSString = "RequestStatusFailed"

@objc protocol MZDownloadDelegate {
    /**A delegate method called each time whenever new download task is start downloading
    */
    optional func downloadRequestStarted(downloadTask: NSURLSessionDownloadTask);
    /**A delegate method called each time whenever any download task is cancelled by the user
    */
    optional func downloadRequestCanceled(downloadTask: NSURLSessionDownloadTask);
    /**A delegate method called each time whenever any download task is finished successfully
    */
    optional func downloadRequestFinished(fileName: NSString);
}

class MZDownloadManagerViewController: UIViewController, UIActionSheetDelegate, NSURLSessionDelegate {
    
    @IBOutlet var bgDownloadTableView : UITableView?
    
    var sessionManager    : NSURLSession!
    var downloadingArray  : NSMutableArray!
    
    var selectedIndexPath : NSIndexPath!
    
    var delegate          : MZDownloadDelegate?
    
    var actionSheetRetry  : UIActionSheet!
    var actionSheetPause  : UIActionSheet!
    var actionSheetStart  : UIActionSheet!
    
    var isViewLoaded      : Bool!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        actionSheetRetry = UIActionSheet()
        actionSheetRetry.title = "options"
        actionSheetRetry.addButtonWithTitle("Retry")
        actionSheetRetry.addButtonWithTitle("Delete")
        actionSheetRetry.addButtonWithTitle("Cancel")
        actionSheetRetry.cancelButtonIndex = 2
        actionSheetRetry.delegate = self
        
        actionSheetPause = UIActionSheet()
        actionSheetPause.title = "options"
        actionSheetPause.addButtonWithTitle("Pause")
        actionSheetPause.addButtonWithTitle("Delete")
        actionSheetPause.addButtonWithTitle("Cancel")
        actionSheetPause.cancelButtonIndex = 2
        actionSheetPause.delegate = self
        
        actionSheetStart = UIActionSheet()
        actionSheetStart.title = "options"
        actionSheetStart.addButtonWithTitle("Start")
        actionSheetStart.addButtonWithTitle("Delete")
        actionSheetStart.addButtonWithTitle("Cancel")
        actionSheetStart.cancelButtonIndex = 2
        actionSheetStart.delegate = self
        
        self.isViewLoaded = true
        
        /* I don't know why this is not working.Problem = UIActionSheet is always nil
        actionSheetRetry? = UIActionSheet(title: "Options", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Retry", "Delete")
        actionSheetPause? = UIActionSheet(title: "Options", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Pause", "Delete")
        actionSheetStart? = UIActionSheet(title: "Options", delegate: self, cancelButtonTitle: "Cancel", destructiveButtonTitle: nil, otherButtonTitles: "Start", "Delete")
        */
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - My Methods -
    
    func backgroundSession() -> NSURLSession {
        struct sessionStruct {
            static var onceToken : dispatch_once_t = 0;
            static var session   : NSURLSession? = nil
        }
        
        dispatch_once(&sessionStruct.onceToken, { () -> Void in
            let sessionIdentifer     : String = "com.iosDevelopment.MZDownloadManager.BackgroundSession"
            let sessionConfiguration : NSURLSessionConfiguration
            
            if #available(iOS 8.0, *) {
                sessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfigurationWithIdentifier(sessionIdentifer)
            } else {
                // Fallback on earlier versions
                sessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfiguration(sessionIdentifer)
            }

            sessionStruct.session = NSURLSession(configuration: sessionConfiguration, delegate: self, delegateQueue: nil)
        })
        return sessionStruct.session!
    }
    
    func tasks() -> NSArray {
        return self.tasksForKeyPath("tasks")
    }
    
    func dataTasks() -> NSArray {
        return self.tasksForKeyPath("dataTasks")
    }
    
    func uploadTasks() -> NSArray {
        return self.tasksForKeyPath("uploadTasks")
    }
    
    func downloadTasks() -> NSArray {
        return self.tasksForKeyPath("downloadTasks")
    }
    
    func tasksForKeyPath(keyPath: NSString) -> NSArray {
        var tasks     : NSArray! = NSArray()
        let semaphore : dispatch_semaphore_t = dispatch_semaphore_create(0)
        sessionManager.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
            if keyPath == "dataTasks" {
                tasks = dataTasks
            } else if keyPath == "uploadTasks" {
                tasks = uploadTasks
                
            } else if keyPath == "downloadTasks" {
                if let pendingTasks: NSArray = downloadTasks {
                    tasks = pendingTasks
                    print("pending tasks \(tasks)")
                }
            } else if keyPath == "tasks" {
                tasks = ([dataTasks, uploadTasks, downloadTasks] as AnyObject).valueForKeyPath("@unionOfArrays.self") as! NSArray
                
                print("pending task\(tasks)")
            }
            
            dispatch_semaphore_signal(semaphore)
        }
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        return tasks
    }
    
    func addDownloadTask(fileName: NSString, fileURL: NSString) {
        
        let url          : NSURL = NSURL(string: fileURL as String)!
        let request      : NSURLRequest = NSURLRequest(URL: url)
        let downloadTask : NSURLSessionDownloadTask = sessionManager.downloadTaskWithRequest(request)
        
        print("session manager:\(sessionManager) url:\(url) request:\(request)")
        
        downloadTask.resume()
        
        let downloadInfo : NSMutableDictionary = NSMutableDictionary()
        downloadInfo.setObject(fileURL, forKey: kMZDownloadKeyURL)
        downloadInfo.setObject(fileName, forKey: kMZDownloadKeyFileName)
        
        let jsonData     : NSData = try! NSJSONSerialization.dataWithJSONObject(downloadInfo, options: NSJSONWritingOptions.PrettyPrinted)
        let jsonString   : NSString = NSString(data: jsonData, encoding: NSUTF8StringEncoding)!
        downloadTask.taskDescription = jsonString as String
        
        downloadInfo.setObject(NSDate(), forKey: kMZDownloadKeyStartTime)
        downloadInfo.setObject(RequestStatusDownloading, forKey: kMZDownloadKeyStatus)
        downloadInfo.setObject(downloadTask, forKey: kMZDownloadKeyTask)
        
        let indexPath    : NSIndexPath = NSIndexPath(forRow: self.downloadingArray.count, inSection: 0)
        
        self.downloadingArray.addObject(downloadInfo)
        bgDownloadTableView?.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        
        self.delegate?.downloadRequestStarted?(downloadTask)
    }
    
    func populateOtherDownloadTasks() {
        
        let downloadTasks : NSArray = self.downloadTasks()
        
        for downloadTask in downloadTasks {

            let taskDescStr: String? = downloadTask.taskDescription
            let taskDescription: NSData = (taskDescStr?.dataUsingEncoding(NSUTF8StringEncoding))!
            
            var downloadInfo: NSMutableDictionary?
            do {
                downloadInfo = try NSJSONSerialization.JSONObjectWithData(taskDescription, options: .AllowFragments).mutableCopy() as? NSMutableDictionary
            } catch let jsonError as NSError {
                print("Error while retreiving json value:\(jsonError)")
                downloadInfo = NSMutableDictionary()
            }
            
            downloadInfo?.setObject(downloadTask, forKey: kMZDownloadKeyTask)
            downloadInfo?.setObject(NSDate(), forKey: kMZDownloadKeyStartTime)
            
            let taskState       : NSURLSessionTaskState = downloadTask.state
            
            if taskState == NSURLSessionTaskState.Running {
                downloadInfo?.setObject(RequestStatusDownloading, forKey: kMZDownloadKeyStatus)
                self.downloadingArray.addObject(downloadInfo!)
            } else if(taskState == NSURLSessionTaskState.Suspended) {
                downloadInfo?.setObject(RequestStatusPaused, forKey: kMZDownloadKeyStatus)
                self.downloadingArray.addObject(downloadInfo!)
            } else {
                downloadInfo?.setObject(RequestStatusFailed, forKey: kMZDownloadKeyStatus)
            }

            if let _ = downloadInfo {
                
            } else {
                downloadTask.cancel()
            }
            
        }
    }
    
    func presentNotificationForDownload(fileName : NSString) {
        let application = UIApplication.sharedApplication()
        let applicationState = application.applicationState
        
        if applicationState == UIApplicationState.Background {
            let localNotification = UILocalNotification()
            localNotification.alertBody = "Downloading complete of \(fileName)"
            localNotification.alertAction = "Background Transfer Download!"
            localNotification.soundName = UILocalNotificationDefaultSoundName
            localNotification.applicationIconBadgeNumber = ++application.applicationIconBadgeNumber
            application.presentLocalNotificationNow(localNotification)
        }
    }
    
    func isValidResumeData(resumeData: NSData?) -> Bool {
        if resumeData == nil {
            return false
        }
        if resumeData?.length < 0 {
            return false
        }
        
        var resumeDictionary : AnyObject!
        do {
            resumeDictionary = try NSPropertyListSerialization.propertyListWithData(resumeData!, options: .Immutable, format: nil)
        } catch let error as NSError {
            print("resume data is nil: \(error)")
            resumeDictionary = nil
        }
        
        let localFilePath : NSString? = resumeDictionary?.objectForKey("NSURLSessionResumeInfoLocalPath") as? NSString
        if localFilePath == nil {
            return false
        }
        
        if localFilePath?.length < 1 {
            return false
        }
        
        let fileManager : NSFileManager! = NSFileManager.defaultManager()
        return fileManager.fileExistsAtPath(localFilePath! as String)
    }

    // MARK: - My IBActions -
    
    @IBAction func cancelButtonTappedOnActionSheet() {
        let indexPath    : NSIndexPath = selectedIndexPath
        let downloadInfo : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as! NSMutableDictionary
        let downloadTask : NSURLSessionDownloadTask = downloadInfo.objectForKey(kMZDownloadKeyTask) as! NSURLSessionDownloadTask

        downloadTask.cancel()
        
        self.downloadingArray.removeObjectAtIndex(indexPath.row)
        self.bgDownloadTableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
        
        self.delegate?.downloadRequestCanceled?(downloadTask)
    }
    
    @IBAction func pauseOrRetryButtonTappedOnActionSheet() {
        let indexPath         : NSIndexPath = selectedIndexPath
        let downloadInfo      : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as! NSMutableDictionary
        let downloadTask      : NSURLSessionDownloadTask = downloadInfo.objectForKey(kMZDownloadKeyTask) as! NSURLSessionDownloadTask
        let cell              : MZDownloadingCell = self.bgDownloadTableView?.cellForRowAtIndexPath(indexPath) as! MZDownloadingCell
        let downloadingStatus : NSString = downloadInfo.objectForKey(kMZDownloadKeyStatus) as! NSString
        
        if downloadingStatus == RequestStatusDownloading {
            downloadTask.suspend()
            downloadInfo.setObject(RequestStatusPaused, forKey: kMZDownloadKeyStatus)
            downloadInfo.setObject(NSDate(), forKey: kMZDownloadKeyStartTime)
            
            self.downloadingArray.replaceObjectAtIndex(indexPath.row, withObject: downloadInfo)
            
        } else if downloadingStatus == RequestStatusPaused {
            downloadTask.resume()
            downloadInfo.setObject(RequestStatusDownloading, forKey: kMZDownloadKeyStatus)
            
            self.downloadingArray.replaceObjectAtIndex(indexPath.row, withObject: downloadInfo)
            
        } else {
            downloadTask.resume()
            downloadInfo.setObject(RequestStatusDownloading, forKey: kMZDownloadKeyStatus)
            downloadInfo.setObject(NSDate(), forKey: kMZDownloadKeyStartTime)
            downloadInfo.setObject(downloadTask, forKey: kMZDownloadKeyTask)
            
            self.downloadingArray.replaceObjectAtIndex(indexPath.row, withObject: downloadInfo)
        }
        self.updateCellForRowAtIndexPath(cell, indexPath: indexPath)
    }
    
    // MARK: - NSURLSession Delegates -
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        for downloadDict in self.downloadingArray {
            if downloadTask.isEqual(downloadDict.objectForKey(kMZDownloadKeyTask)) {
                dispatch_async(dispatch_get_main_queue(), { () -> Void in
                    
                    let receivedBytesCount      : Double = Double(downloadTask.countOfBytesReceived)
                    let totalBytesCount         : Double = Double(downloadTask.countOfBytesExpectedToReceive)
                    let progress                : Float = Float(receivedBytesCount / totalBytesCount)
                    
                    let taskStartedDate         : NSDate = downloadDict.objectForKey(kMZDownloadKeyStartTime) as! NSDate
                    let timeInterval            : NSTimeInterval = taskStartedDate.timeIntervalSinceNow
                    let downloadTime            : NSTimeInterval = NSTimeInterval(-1 * timeInterval)
                    
                    let speed                   : Float = Float(totalBytesWritten) / Float(downloadTime)
                    
                    let indexOfObject           : NSInteger = self.downloadingArray.indexOfObject(downloadDict)
                    let indexPath               : NSIndexPath = NSIndexPath(forRow: indexOfObject, inSection: 0)
                    
                    let remainingContentLength  : Int64 = totalBytesExpectedToWrite - totalBytesWritten
                    let remainingTime           : Int64 = remainingContentLength / Int64(speed)
                    let hours                   : Int = Int(remainingTime) / 3600
                    let minutes                 : Int = (Int(remainingTime) - hours * 3600) / 60
                    let seconds                 : Int = Int(remainingTime) - hours * 3600 - minutes * 60
                    let fileSizeUnit            : Float = MZUtility.calculateFileSizeInUnit(totalBytesExpectedToWrite)
                    let unit                    : NSString = MZUtility.calculateUnit(totalBytesExpectedToWrite)
                    let fileSizeInUnits         : NSString = NSString(format: "%.2f \(unit)", fileSizeUnit)
                    let fileSizeDownloaded      : Float = MZUtility.calculateFileSizeInUnit(totalBytesWritten)
                    let downloadedSizeUnit      : NSString = MZUtility.calculateUnit(totalBytesWritten)
                    let downloadedFileSizeUnits : NSString = NSString(format: "%.2f \(downloadedSizeUnit)", fileSizeDownloaded)
                    let speedSize               : Float = MZUtility.calculateFileSizeInUnit(Int64(speed))
                    let speedUnit               : NSString = MZUtility.calculateUnit(Int64(speed))
                    let speedInUnits            : NSString = NSString(format: "%.2f \(speedUnit)", speedSize)
                    let remainingTimeStr        : NSMutableString = NSMutableString()
                    let detailLabelText         : NSMutableString = NSMutableString()
                    
                    if self.isViewLoaded != nil {
                        if hours > 0 {
                            remainingTimeStr.appendString("\(hours) Hours ")
                        }
                        if minutes > 0 {
                            remainingTimeStr.appendString("\(minutes) Min ")
                        }
                        if seconds > 0 {
                            remainingTimeStr.appendString("\(seconds) sec")
                        }
                        
                        detailLabelText.appendFormat("File Size: \(fileSizeInUnits)\nDownloaded: \(downloadedFileSizeUnits) (%.2f%%)\nSpeed: \(speedInUnits)/sec\n", progress*100.0)
                        
                        if  progress == 1.0 {
                            detailLabelText.appendString("Time Left: Please wait...")
                        } else {
                            detailLabelText.appendString("Time Left: \(remainingTimeStr)")
                        }
                        
                        let cell : MZDownloadingCell = self.bgDownloadTableView?.cellForRowAtIndexPath(indexPath) as! MZDownloadingCell
                        cell.progressDownload?.progress = progress
                        cell.lblDetails?.text = detailLabelText as String
                        
                        downloadDict.setObject("\(progress)", forKey: kMZDownloadKeyProgress)
                        downloadDict.setObject(detailLabelText, forKey: kMZDownloadKeyDetails)
                    }
                })
                break
            }
        }
    }
    
    func URLSession(session: NSURLSession, downloadTask: NSURLSessionDownloadTask, didFinishDownloadingToURL location: NSURL) {
        for downloadDict in self.downloadingArray {
            if downloadTask.isEqual(downloadDict.objectForKey(kMZDownloadKeyTask)) {
                let fileName        : NSString = downloadDict.objectForKey(kMZDownloadKeyFileName) as! NSString
                let destinationPath : NSString = fileDest.stringByAppendingPathComponent(fileName as String)
                let fileURL         : NSURL = NSURL(fileURLWithPath: destinationPath as String)
                print("directory path = \(destinationPath)")
                
                let fileManager : NSFileManager = NSFileManager.defaultManager()
                do {
                    try fileManager.moveItemAtURL(location, toURL: fileURL)
                } catch let error as NSError {
                    print("Error while moving downloaded file to destination path:\(error)")
                    let errorMessage : NSString = error.localizedDescription as NSString
                    MZUtility.showAlertViewWithTitle(kAlertTitle, msg: errorMessage)
                }
                
                break
            }
        }
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let error = error {
            print("Download complete with error: \(error)")
            let errorUserInfo : NSDictionary? = error.userInfo
            if let _: AnyObject = errorUserInfo?.objectForKey("NSURLErrorBackgroundTaskCancelledReasonKey") {
                let errorReasonNum : Int = Int(errorUserInfo?.objectForKey("NSURLErrorBackgroundTaskCancelledReasonKey") as! NSNumber)
                if errorReasonNum == NSURLErrorCancelledReasonUserForceQuitApplication || errorReasonNum == NSURLErrorCancelledReasonBackgroundUpdatesDisabled {
                    
                    
                    let taskDescStr: String? = task.taskDescription
                    let taskDescriptionData: NSData = (taskDescStr?.dataUsingEncoding(NSUTF8StringEncoding))!
                    var taskInfoDict : NSMutableDictionary?
                    
                    do {
                       taskInfoDict = try NSJSONSerialization.JSONObjectWithData(taskDescriptionData, options: .AllowFragments).mutableCopy() as? NSMutableDictionary
                    } catch let jsonError as NSError {
                        print("Error while retreiving json value: didCompleteWithError \(jsonError.localizedDescription)")
                    }
                    
                    let fileName        : NSString = taskInfoDict?.objectForKey(kMZDownloadKeyFileName) as! NSString
                    let fileURL         : NSString = taskInfoDict?.objectForKey(kMZDownloadKeyURL) as! NSString
                    let downloadInfo    : NSMutableDictionary = NSMutableDictionary()
                    downloadInfo.setObject(fileName, forKey: kMZDownloadKeyFileName)
                    downloadInfo.setObject(fileURL, forKey: kMZDownloadKeyURL)
                    downloadInfo.setObject(RequestStatusFailed, forKey: kMZDownloadKeyStatus)
                    
                    var newTask = task
                    let resumeData : NSData? = errorUserInfo?.objectForKey(NSURLSessionDownloadTaskResumeData) as? NSData

                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        if let resumeData = resumeData {
                            let hasValidResumeData : Bool = self.isValidResumeData(resumeData)
                            if hasValidResumeData == true {
                                newTask = self.sessionManager.downloadTaskWithResumeData(resumeData)
                            } else {
                                newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL as String)!)
                            }
                        } else {
                            newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL as String)!)
                        }
                        
                        newTask.taskDescription = task.taskDescription
                        downloadInfo.setObject(newTask as! NSURLSessionDownloadTask, forKey: kMZDownloadKeyTask)
                        
                        self.downloadingArray.addObject(downloadInfo)
                        
                        self.dismissAllActionSeets()
                        self.bgDownloadTableView?.reloadData()
                    })
                    return
                }
            }
        }
        for downloadInfo in self.downloadingArray {
            if task.isEqual(downloadInfo.objectForKey(kMZDownloadKeyTask)) {
                let indexOfObject : Int = self.downloadingArray.indexOfObject(downloadInfo)
                if let error = error {
                    let errorUserInfo : NSDictionary? = error.userInfo
                    if error.code != NSURLErrorCancelled {
                        let taskInfo    : String? = task.taskDescription
                        let fileURL     : NSString = downloadInfo.objectForKey(kMZDownloadKeyURL) as! NSString
                        let resumeData  : NSData? = errorUserInfo?.objectForKey(NSURLSessionDownloadTaskResumeData) as? NSData
                        var newTask = task

                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            
                            if let resumeData = resumeData {
                                let hasValidResumeData : Bool = self.isValidResumeData(resumeData)
                                if hasValidResumeData == true {
                                    newTask = self.sessionManager.downloadTaskWithResumeData(resumeData)
                                } else {
                                    newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL as String)!)
                                }
                            } else {
                                newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL as String)!)
                            }
                            
                            newTask.taskDescription = taskInfo
                            downloadInfo.setObject(RequestStatusFailed, forKey: kMZDownloadKeyStatus)
                            downloadInfo.setObject(newTask as! NSURLSessionDownloadTask, forKey: kMZDownloadKeyTask)
                            
                            self.downloadingArray.replaceObjectAtIndex(indexOfObject, withObject: downloadInfo)
                            
                            self.dismissAllActionSeets()
                            self.bgDownloadTableView?.reloadData()
                            MZUtility.showAlertViewWithTitle(kAlertTitle, msg: error.localizedDescription)
                        })
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.dismissAllActionSeets()
                        let fileName : NSString = downloadInfo.objectForKey(kMZDownloadKeyFileName) as! NSString
                        
                        self.presentNotificationForDownload(fileName)
                        
                        self.downloadingArray.removeObjectAtIndex(indexOfObject)
                        let indexPath : NSIndexPath = NSIndexPath(forRow: indexOfObject, inSection: 0)
                        self.bgDownloadTableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                        
                        self.delegate?.downloadRequestFinished?(fileName)
                    })
                }
                break
            }
        }
    }
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        let appDelegate : AppDelegate = UIApplication.sharedApplication().delegate as! AppDelegate
        
        if let _ = appDelegate.backgroundSessionCompletionHandler {
            let completionHandler = appDelegate.backgroundSessionCompletionHandler
            appDelegate.backgroundSessionCompletionHandler = nil
            completionHandler!()
        }
        
        print("All tasks are finished")
    }
    /*
    // MARK: - Navigation -

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    //MARK: - UIActionSheet Delegates -
    
    func actionSheet(actionSheet: UIActionSheet, didDismissWithButtonIndex buttonIndex: Int) {
        if buttonIndex == 0 {
            self.pauseOrRetryButtonTappedOnActionSheet()
        } else if buttonIndex == 1 {
            self.cancelButtonTappedOnActionSheet()
        }
    }
    
    func dismissAllActionSeets() {
        if isViewLoaded != nil {
            actionSheetPause.dismissWithClickedButtonIndex(2, animated: true)
            actionSheetRetry.dismissWithClickedButtonIndex(2, animated: true)
            actionSheetStart.dismissWithClickedButtonIndex(2, animated: true)
        }
    }
    
    // MARK: - UITableView Delegates and Datasource -
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.downloadingArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        let cellIdentifier : NSString = "MZDownloadingCell"
        let cell : MZDownloadingCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier as String, forIndexPath: indexPath) as! MZDownloadingCell
        
        self.updateCellForRowAtIndexPath(cell, indexPath: indexPath)
        
        return cell
        
    }
    
    func updateCellForRowAtIndexPath(cell : MZDownloadingCell, indexPath : NSIndexPath) {
        let downloadInfoDict : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as! NSMutableDictionary
        let fileName         : NSString = downloadInfoDict.objectForKey(kMZDownloadKeyFileName) as! NSString
        
        cell.lblTitle?.text = "File Title: \(fileName)"
        
        if let _ = downloadInfoDict.objectForKey(kMZDownloadKeyDetails) as? NSString {
            let progress         : NSString = downloadInfoDict.objectForKey(kMZDownloadKeyProgress) as! NSString
            cell.lblDetails?.text = downloadInfoDict.objectForKey(kMZDownloadKeyDetails) as! NSString as String
            cell.progressDownload?.progress = progress.floatValue
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        selectedIndexPath = indexPath
        let downloadInfoDict : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as! NSMutableDictionary
        let downloadStatus : NSString = downloadInfoDict.objectForKey(kMZDownloadKeyStatus) as! NSString
        
        if downloadStatus == RequestStatusPaused {
            actionSheetStart.showFromTabBar((self.tabBarController?.tabBar)!)
        } else if downloadStatus == RequestStatusDownloading {
            actionSheetPause.showFromTabBar((self.tabBarController?.tabBar)!)
        } else {
            print("retry actionsheet\(actionSheetRetry)")
            actionSheetRetry.showFromTabBar((self.tabBarController?.tabBar)!)
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
