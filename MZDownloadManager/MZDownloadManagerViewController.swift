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
            let sessionIdentifer     : NSString = "com.iosDevelopment.MZDownloadManager.BackgroundSession"
            var sessionConfiguration : NSURLSessionConfiguration = NSURLSessionConfiguration.backgroundSessionConfiguration(sessionIdentifer)
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
        var semaphore : dispatch_semaphore_t = dispatch_semaphore_create(0)
        sessionManager.getTasksWithCompletionHandler { (dataTasks, uploadTasks, downloadTasks) -> Void in
            if keyPath == "dataTasks" {
                tasks = dataTasks
            } else if keyPath == "uploadTasks" {
                tasks = uploadTasks
                
            } else if keyPath == "downloadTasks" {
                if let pendingTasks = downloadTasks {
                    tasks = downloadTasks
                    println("pending tasks \(tasks)")
                }
            } else if keyPath == "tasks" {
                tasks = ([dataTasks, uploadTasks, downloadTasks] as AnyObject).valueForKeyPath("@unionOfArrays.self") as NSArray
                
                println("pending task\(tasks)")
            }
            
            dispatch_semaphore_signal(semaphore)
        }
        
        dispatch_semaphore_wait(semaphore, DISPATCH_TIME_FOREVER)
        return tasks
    }
    
    func addDownloadTask(fileName: NSString, fileURL: NSString) {
        
        var url          : NSURL = NSURL(string: fileURL)!
        var request      : NSURLRequest = NSURLRequest(URL: url)
        var downloadTask : NSURLSessionDownloadTask = sessionManager.downloadTaskWithRequest(request)
        
        println("session manager:\(sessionManager) url:\(url) request:\(request)")
        
        downloadTask.resume()
        
        var downloadInfo : NSMutableDictionary = NSMutableDictionary()
        downloadInfo.setObject(fileURL, forKey: kMZDownloadKeyURL)
        downloadInfo.setObject(fileName, forKey: kMZDownloadKeyFileName)
        
        var error        : NSError?
        var jsonData     : NSData = NSJSONSerialization.dataWithJSONObject(downloadInfo, options: NSJSONWritingOptions.PrettyPrinted, error: &error)!
        var jsonString   : NSString = NSString(data: jsonData, encoding: NSUTF8StringEncoding)!
        downloadTask.taskDescription = jsonString
        
        downloadInfo.setObject(NSDate(), forKey: kMZDownloadKeyStartTime)
        downloadInfo.setObject(RequestStatusDownloading, forKey: kMZDownloadKeyStatus)
        downloadInfo.setObject(downloadTask, forKey: kMZDownloadKeyTask)
        
        var indexPath    : NSIndexPath = NSIndexPath(forRow: self.downloadingArray.count, inSection: 0)
        
        self.downloadingArray.addObject(downloadInfo)
        bgDownloadTableView?.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        
        self.delegate?.downloadRequestStarted?(downloadTask)
    }
    
    func populateOtherDownloadTasks() {
        
        var downloadTasks : NSArray = self.downloadTasks()
        
        for downloadTask in downloadTasks {
            var error : NSError?
            var taskDescription : NSData = downloadTask.taskDescription.dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)!
            var downloadInfo    : NSMutableDictionary? = NSJSONSerialization.JSONObjectWithData(taskDescription, options: NSJSONReadingOptions.AllowFragments, error: &error)?.mutableCopy() as? NSMutableDictionary
            
            if let serializationError = error {
                println("Error while retreiving json value:\(error)")
            }
            
            downloadInfo?.setObject(downloadTask, forKey: kMZDownloadKeyTask)
            downloadInfo?.setObject(NSDate(), forKey: kMZDownloadKeyStartTime)
            
            var taskState       : NSURLSessionTaskState = downloadTask.state
            
            if taskState == NSURLSessionTaskState.Running {
                downloadInfo?.setObject(RequestStatusDownloading, forKey: kMZDownloadKeyStatus)
                self.downloadingArray.addObject(downloadInfo!)
            } else if(taskState == NSURLSessionTaskState.Suspended) {
                downloadInfo?.setObject(RequestStatusPaused, forKey: kMZDownloadKeyStatus)
                self.downloadingArray.addObject(downloadInfo!)
            } else {
                downloadInfo?.setObject(RequestStatusFailed, forKey: kMZDownloadKeyStatus)
            }
            
            if let taskInfo = downloadInfo {
                
            } else {
                downloadTask.cancel()
            }
            
        }
    }
    
    func presentNotificationForDownload(fileName : NSString) {
        var application = UIApplication.sharedApplication()
        var applicationState = application.applicationState
        
        if applicationState == UIApplicationState.Background {
            var localNotification = UILocalNotification()
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

        var error : NSError?
        var resumeDictionary : AnyObject! = NSPropertyListSerialization.propertyListWithData(resumeData!, options: Int(NSPropertyListMutabilityOptions.Immutable.rawValue), format: nil, error: &error)
        
        var localFilePath : NSString? = resumeDictionary?.objectForKey("NSURLSessionResumeInfoLocalPath") as? NSString
        if localFilePath == nil {
            return false
        }
        
        if localFilePath?.length < 1 {
            return false
        }
        
        var fileManager : NSFileManager! = NSFileManager.defaultManager()
        return fileManager.fileExistsAtPath(localFilePath!)
    }

    // MARK: - My IBActions -
    
    @IBAction func cancelButtonTappedOnActionSheet() {
        var indexPath    : NSIndexPath = selectedIndexPath
        var downloadInfo : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as NSMutableDictionary
        var downloadTask : NSURLSessionDownloadTask = downloadInfo.objectForKey(kMZDownloadKeyTask) as NSURLSessionDownloadTask

        downloadTask.cancel()
        
        self.downloadingArray.removeObjectAtIndex(indexPath.row)
        self.bgDownloadTableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
        
        self.delegate?.downloadRequestCanceled?(downloadTask)
    }
    
    @IBAction func pauseOrRetryButtonTappedOnActionSheet() {
        var indexPath         : NSIndexPath = selectedIndexPath
        var downloadInfo      : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as NSMutableDictionary
        var downloadTask      : NSURLSessionDownloadTask = downloadInfo.objectForKey(kMZDownloadKeyTask) as NSURLSessionDownloadTask
        var cell              : MZDownloadingCell = self.bgDownloadTableView?.cellForRowAtIndexPath(indexPath) as MZDownloadingCell
        var downloadingStatus : NSString = downloadInfo.objectForKey(kMZDownloadKeyStatus) as NSString
        
        if downloadingStatus == RequestStatusDownloading {
            downloadTask.suspend()
            downloadInfo.setObject(RequestStatusPaused, forKey: kMZDownloadKeyStatus)
            NSDate()
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
                    
                    var receivedBytesCount      : Double = Double(downloadTask.countOfBytesReceived)
                    var totalBytesCount         : Double = Double(downloadTask.countOfBytesExpectedToReceive)
                    var progress                : Float = Float(receivedBytesCount / totalBytesCount)
                    
                    var taskStartedDate         : NSDate = downloadDict.objectForKey(kMZDownloadKeyStartTime) as NSDate
                    var timeInterval            : NSTimeInterval = taskStartedDate.timeIntervalSinceNow
                    var downloadTime            : NSTimeInterval = NSTimeInterval(-1 * timeInterval)
                    
                    var speed                   : Float = Float(totalBytesWritten) / Float(downloadTime)
                    
                    var indexOfObject           : NSInteger = self.downloadingArray.indexOfObject(downloadDict)
                    var indexPath               : NSIndexPath = NSIndexPath(forRow: indexOfObject, inSection: 0)
                    
                    var remainingContentLength  : Int64 = totalBytesExpectedToWrite - totalBytesWritten
                    var remainingTime           : Int64 = remainingContentLength / Int64(speed)
                    var hours                   : Int = Int(remainingTime) / 3600
                    var minutes                 : Int = (Int(remainingTime) - hours * 3600) / 60
                    var seconds                 : Int = Int(remainingTime) - hours * 3600 - minutes * 60
                    var fileSizeUnit            : Float = MZUtility.calculateFileSizeInUnit(totalBytesExpectedToWrite)
                    var unit                    : NSString = MZUtility.calculateUnit(totalBytesExpectedToWrite)
                    var fileSizeInUnits         : NSString = NSString(format: "%.2f \(unit)", fileSizeUnit)
                    var fileSizeDownloaded      : Float = MZUtility.calculateFileSizeInUnit(totalBytesWritten)
                    var downloadedSizeUnit      : NSString = MZUtility.calculateUnit(totalBytesWritten)
                    var downloadedFileSizeUnits : NSString = NSString(format: "%.2f \(downloadedSizeUnit)", fileSizeDownloaded)
                    var speedSize               : Float = MZUtility.calculateFileSizeInUnit(Int64(speed))
                    var speedUnit               : NSString = MZUtility.calculateUnit(Int64(speed))
                    var speedInUnits            : NSString = NSString(format: "%.2f \(speedUnit)", speedSize)
                    var remainingTimeStr        : NSMutableString = NSMutableString()
                    var detailLabelText         : NSMutableString = NSMutableString()
                    
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
                        
                        var cell : MZDownloadingCell = self.bgDownloadTableView?.cellForRowAtIndexPath(indexPath) as MZDownloadingCell
                        cell.progressDownload?.progress = progress
                        cell.lblDetails?.text = detailLabelText
                        
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
                var fileName        : NSString = downloadDict.objectForKey(kMZDownloadKeyFileName) as NSString
                var destinationPath : NSString = fileDest.stringByAppendingPathComponent(fileName)
                var fileURL         : NSURL = NSURL(fileURLWithPath: destinationPath)!
                println("directory path = \(destinationPath)")
                
                var error       : NSError?
                var fileManager : NSFileManager = NSFileManager.defaultManager()
                var success     : Bool = fileManager.moveItemAtURL(location, toURL: fileURL, error: &error)
                if let hasError = error {
                    println("Error while moving downloaded file to destination path:\(error)")
                    var errorMessage : NSString = error!.localizedDescription as NSString
                    MZUtility.showAlertViewWithTitle(kAlertTitle, msg: errorMessage)
                }
                break
            }
        }
    }
    
    func URLSession(session: NSURLSession, task: NSURLSessionTask, didCompleteWithError error: NSError?) {
        if let error = error {
            println("Download complete with error: \(error)")
            let errorUserInfo : NSDictionary? = error.userInfo
            if let hasReasonKey: AnyObject = errorUserInfo?.objectForKey("NSURLErrorBackgroundTaskCancelledReasonKey") {
                let errorReasonNum : Int = Int(errorUserInfo?.objectForKey("NSURLErrorBackgroundTaskCancelledReasonKey")? as NSNumber)
                if errorReasonNum == NSURLErrorCancelledReasonUserForceQuitApplication || errorReasonNum == NSURLErrorCancelledReasonBackgroundUpdatesDisabled {
                    
                    var taskInfo        : NSString = task.taskDescription as NSString
                    var jsonError       : NSError?
                    var taskDescription : NSData? = taskInfo.dataUsingEncoding(NSUTF8StringEncoding)
                    var taskInfoDict    : NSMutableDictionary? = NSJSONSerialization.JSONObjectWithData(taskDescription!, options: NSJSONReadingOptions.AllowFragments, error: &jsonError)?.mutableCopy() as? NSMutableDictionary
                    
                    if let jsonError = jsonError {
                        println("Error while retreiving json value: didCompleteWithError \(jsonError.localizedDescription)")
                    }
                    
                    var fileName        : NSString = taskInfoDict?.objectForKey(kMZDownloadKeyFileName) as NSString
                    var fileURL         : NSString = taskInfoDict?.objectForKey(kMZDownloadKeyURL) as NSString
                    var downloadInfo    : NSMutableDictionary = NSMutableDictionary()
                    downloadInfo.setObject(fileName, forKey: kMZDownloadKeyFileName)
                    downloadInfo.setObject(fileURL, forKey: kMZDownloadKeyURL)
                    downloadInfo.setObject(RequestStatusFailed, forKey: kMZDownloadKeyStatus)
                    
                    var newTask = task
                    var resumeData : NSData? = errorUserInfo?.objectForKey(NSURLSessionDownloadTaskResumeData) as? NSData

                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        
                        if let resumeData = resumeData {
                            var hasValidResumeData : Bool = self.isValidResumeData(resumeData)
                            if hasValidResumeData == true {
                                newTask = self.sessionManager.downloadTaskWithResumeData(resumeData)
                            } else {
                                newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL)!)
                            }
                        } else {
                            newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL)!)
                        }
                        
                        newTask.taskDescription = taskInfo
                        downloadInfo.setObject(newTask as NSURLSessionDownloadTask, forKey: kMZDownloadKeyTask)
                        
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
                var indexOfObject : Int = self.downloadingArray.indexOfObject(downloadInfo)
                if let error = error {
                    let errorUserInfo : NSDictionary? = error.userInfo
                    if error.code != NSURLErrorCancelled {
                        var taskInfo    : NSString = task.taskDescription as NSString
                        var fileURL     : NSString = downloadInfo.objectForKey(kMZDownloadKeyURL) as NSString
                        var resumeData  : NSData? = errorUserInfo?.objectForKey(NSURLSessionDownloadTaskResumeData) as? NSData
                        var newTask = task

                        dispatch_async(dispatch_get_main_queue(), { () -> Void in
                            
                            if let resumeData = resumeData {
                                var hasValidResumeData : Bool = self.isValidResumeData(resumeData)
                                if hasValidResumeData == true {
                                    newTask = self.sessionManager.downloadTaskWithResumeData(resumeData)
                                } else {
                                    newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL)!)
                                }
                            } else {
                                newTask = self.sessionManager.downloadTaskWithURL(NSURL(string: fileURL)!)
                            }
                            
                            newTask.taskDescription = taskInfo
                            downloadInfo.setObject(RequestStatusFailed, forKey: kMZDownloadKeyStatus)
                            downloadInfo.setObject(newTask as NSURLSessionDownloadTask, forKey: kMZDownloadKeyTask)
                            
                            self.downloadingArray.replaceObjectAtIndex(indexOfObject, withObject: downloadInfo)
                            
                            self.dismissAllActionSeets()
                            self.bgDownloadTableView?.reloadData()
                            MZUtility.showAlertViewWithTitle(kAlertTitle, msg: error.localizedDescription)
                        })
                    }
                } else {
                    dispatch_async(dispatch_get_main_queue(), { () -> Void in
                        self.dismissAllActionSeets()
                        var fileName : NSString = downloadInfo.objectForKey(kMZDownloadKeyFileName) as NSString
                        
                        self.presentNotificationForDownload(fileName)
                        
                        self.downloadingArray.removeObjectAtIndex(indexOfObject)
                        var indexPath : NSIndexPath = NSIndexPath(forRow: indexOfObject, inSection: 0)
                        self.bgDownloadTableView?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Left)
                        
                        self.delegate?.downloadRequestFinished?(fileName)
                    })
                }
                break
            }
        }
    }
    
    func URLSessionDidFinishEventsForBackgroundURLSession(session: NSURLSession) {
        var appDelegate : AppDelegate = UIApplication.sharedApplication().delegate as AppDelegate
        
        if let isBackgroundCompletionHandler = appDelegate.backgroundSessionCompletionHandler {
            var completionHandler = appDelegate.backgroundSessionCompletionHandler
            appDelegate.backgroundSessionCompletionHandler = nil
            completionHandler!()
        }
        
        println("All tasks are finished")
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
        
        var cellIdentifier : NSString = "MZDownloadingCell"
        var cell : MZDownloadingCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as MZDownloadingCell
        
        self.updateCellForRowAtIndexPath(cell, indexPath: indexPath)
        
        return cell
        
    }
    
    func updateCellForRowAtIndexPath(cell : MZDownloadingCell, indexPath : NSIndexPath) {
        var downloadInfoDict : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as NSMutableDictionary
        var fileName         : NSString = downloadInfoDict.objectForKey(kMZDownloadKeyFileName) as NSString
        
        cell.lblTitle?.text = "File Title: \(fileName)"
        
        if let areDetailsAvailable = downloadInfoDict.objectForKey(kMZDownloadKeyDetails) as? NSString {
            var progress         : NSString = downloadInfoDict.objectForKey(kMZDownloadKeyProgress)? as NSString
            cell.lblDetails?.text = downloadInfoDict.objectForKey(kMZDownloadKeyDetails) as NSString
            cell.progressDownload?.progress = progress.floatValue
        }
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        selectedIndexPath = indexPath
        var downloadInfoDict : NSMutableDictionary = self.downloadingArray.objectAtIndex(indexPath.row) as NSMutableDictionary
        var downloadStatus : NSString = downloadInfoDict.objectForKey(kMZDownloadKeyStatus) as NSString
        
        if downloadStatus == RequestStatusPaused {
            actionSheetStart.showFromTabBar(self.tabBarController?.tabBar)
        } else if downloadStatus == RequestStatusDownloading {
            actionSheetPause.showFromTabBar(self.tabBarController?.tabBar)
        } else {
            println("retry actionsheet\(actionSheetRetry)")
            actionSheetRetry.showFromTabBar(self.tabBarController?.tabBar)
        }
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
    }
}
