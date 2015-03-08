//
//  MZAvailableDownloadsViewController.swift
//  MZDownloadManager
//
//  Created by Muhammad Zeeshan on 23/10/2014.
//  Copyright (c) 2014 ideamakerz. All rights reserved.
//

import UIKit

class MZAvailableDownloadsViewController: UIViewController, MZDownloadDelegate, UITableViewDataSource {
    @IBOutlet var availableDownloadTableView : UITableView?
    
    var mzDownloadingViewObj    : MZDownloadManagerViewController?
    var availableDownloadsArray : NSMutableArray!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        availableDownloadsArray = NSMutableArray(objects:
            "http://dl.dropbox.com/u/97700329/file1.mp4",
            "http://dl.dropbox.com/u/97700329/file2.mp4",
            "http://dl.dropbox.com/u/97700329/file3.mp4",
            "http://dl.dropbox.com/u/97700329/FileZilla_3.6.0.2_i686-apple-darwin9.app.tar.bz2",
            "http://dl.dropbox.com/u/97700329/GCDExample-master.zip")
        
        self.setUpDownloadingViewController()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func setUpDownloadingViewController() {
        var tabBarTabs : NSArray? = self.tabBarController?.viewControllers
        var mzDownloadingNav : UINavigationController = tabBarTabs?.objectAtIndex(1) as UINavigationController
        
        mzDownloadingViewObj = mzDownloadingNav.viewControllers[0] as? MZDownloadManagerViewController
        mzDownloadingViewObj?.delegate = self

        mzDownloadingViewObj?.sessionManager = mzDownloadingViewObj?.backgroundSession()
        mzDownloadingViewObj?.downloadingArray = NSMutableArray()
        mzDownloadingViewObj?.populateOtherDownloadTasks()
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
   // MARK: - MZDownloadManager Delegates -
    
    func downloadRequestStarted(downloadTask: NSURLSessionDownloadTask) {
        
    }
    
    func downloadRequestCanceled(downloadTask: NSURLSessionDownloadTask) {
        
    }
    
    func downloadRequestFinished(fileName: NSString) {
        var docDirectoryPath : NSString = fileDest.stringByAppendingPathComponent(fileName)
        NSNotificationCenter.defaultCenter().postNotificationName(DownloadCompletedNotif, object: docDirectoryPath)
    }
    
    // MARK: - Tableview Delegate and Datasource -

    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return availableDownloadsArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cellIdentifier : NSString = "AvailableDownloadsCell"
        var cell : UITableViewCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as UITableViewCell
        
        var fileURL  : NSString = availableDownloadsArray.objectAtIndex(indexPath.row) as NSString
        var fileName : NSString = fileURL.lastPathComponent
        
        cell.textLabel?.text = fileName
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        var fileURL : NSString = availableDownloadsArray.objectAtIndex(indexPath.row) as NSString
        var fileName : NSString = fileURL.lastPathComponent
        fileName = MZUtility.getUniqueFileNameWithPath(fileDest.stringByAppendingPathComponent(fileName))
        
        mzDownloadingViewObj?.addDownloadTask(fileName, fileURL: fileURL.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)
        
        availableDownloadsArray.removeObjectAtIndex(indexPath.row)
        tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Right)
    }
}
