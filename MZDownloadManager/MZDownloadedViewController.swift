//
//  MZDownloadedViewController.swift
//  MZDownloadManager
//
//  Created by Muhammad Zeeshan on 23/10/2014.
//  Copyright (c) 2014 ideamakerz. All rights reserved.
//

import UIKit

class MZDownloadedViewController: UIViewController {
    
    @IBOutlet var tblViewDownloaded : UITableView?
    
    var downloadedFilesArray : NSMutableArray!
    var selectedIndexPath    : NSIndexPath?
    var fileManger           : NSFileManager!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        
        fileManger = NSFileManager.defaultManager()
        var contentOfDir : NSArray = fileManger.contentsOfDirectoryAtPath(fileDest, error: nil) as NSArray!
        downloadedFilesArray = NSMutableArray()
        downloadedFilesArray.addObjectsFromArray(contentOfDir)
        
//        downloadedFilesArray?.removeObject(".DS_Store")
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "downloadFinishedNotification:", name: DownloadCompletedNotif, object: nil)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */
    
    // MARK: - Tableview Delegate and Datasource -
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return downloadedFilesArray.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        
        var cellIdentifier : NSString = "DownloadedFileCell"
        var cell : UITableViewCell = tableView.dequeueReusableCellWithIdentifier(cellIdentifier, forIndexPath: indexPath) as UITableViewCell
        
        var fileName : NSString = downloadedFilesArray.objectAtIndex(indexPath.row) as NSString
        
        cell.textLabel?.text = fileName
        
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)
        
        selectedIndexPath = indexPath
        
    }
    
    func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        var fileName : NSString = downloadedFilesArray.objectAtIndex(indexPath.row) as NSString
        var fileURL  : NSURL = NSURL(fileURLWithPath: fileDest.stringByAppendingPathComponent(fileName))!
        
        var error : NSError?
        
        var isDeletedSucces : Bool = fileManger.removeItemAtURL(fileURL, error: &error)
        if isDeletedSucces {
            downloadedFilesArray.removeObject(indexPath.row)
            tblViewDownloaded?.deleteRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Fade)
        } else {
            MZUtility.showAlertViewWithTitle(kAlertTitle, msg: "File deletion error : \(error?.localizedDescription)")
        }
    }
    
    // MARK: - NSNotification Methods -
    func downloadFinishedNotification(notification : NSNotification) {
        var fileName : NSString = notification.object as NSString
        downloadedFilesArray?.addObject(fileName.lastPathComponent)
        tblViewDownloaded?.reloadSections(NSIndexSet(index: 0), withRowAnimation: UITableViewRowAnimation.Fade)
    }
}
