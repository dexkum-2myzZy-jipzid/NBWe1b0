//
//  NBWCommentTableViewController.swift
//  NBWe1b0
//
//  Created by ChanLiang on 3/3/16.
//  Copyright © 2016 JackChan. All rights reserved.
//

import UIKit
import CoreData
import SDWebImage
import Alamofire

class NBWCommentTableViewController: UITableViewController {
    
    let commentToMeURLString = "https://api.weibo.com/2/comments/to_me.json"
    let commentCellIdentifier = "CommentCell"
    let replyCommentCellIdentifier = "ReplyCommentCell"
    var commentDelegateAndDataSource:NBWCommentArrayDelegateAndDataSource?
    
    var commentArray = [Comment]()
    var filterByAuthor = 0
    var midButton:UIButton?
    var midButtonTitle:String = "All Comments"
    var comment:Comment?
    
    init(){
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        navigationController?.navigationBar.tintColor = UIColor.lightGrayColor()
        
        setupMidBarButtonItem()
        
//        setupTableView()
        
        fetchCommentDataFromWeibo(commentToMeURLString, filterByAuthor)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        managerContextSave()
    }
    
    func setupTableView(){
        self.tableView.registerNib(UINib.init(nibName: "NBWCommentCell", bundle: nil), forCellReuseIdentifier: "CommentCell")
        self.tableView.registerNib(UINib.init(nibName: "NBWReplyCommentCell", bundle: nil), forCellReuseIdentifier: "ReplyCommentCell")
        commentDelegateAndDataSource = NBWCommentArrayDelegateAndDataSource.init(comments: commentArray)
        self.tableView.delegate = commentDelegateAndDataSource
        self.tableView.dataSource = commentDelegateAndDataSource
    }
    
    //MARK: - UIButton
    
    func setupMidBarButtonItem(){
        
        let view = UIView(frame: CGRect(x: 0, y: 0, width: 120, height: 20))
        midButton = UIButton(frame: CGRect(x: 0, y: 0, width: 120, height: 20))
        midButton?.setTitle(midButtonTitle, forState: .Normal)
        midButton?.setTitleColor(UIColor.blackColor(), forState: .Normal)
        midButton?.titleLabel?.font = UIFont.systemFontOfSize(15, weight: UIFontWeightBold)
        midButton?.addTarget(self, action: Selector("filterComments:"), forControlEvents: .TouchUpInside)
        view.addSubview(midButton!)
        
        navigationItem.titleView = view
    }
    
    func filterComments(sender:AnyObject){
        
        let filterCommentVC = NBWFilterCommentTableViewController.init()
        filterCommentVC.modalPresentationStyle = UIModalPresentationStyle.Popover
        filterCommentVC.preferredContentSize = CGSize(width: 150, height: 120)
        filterCommentVC.view.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.7)
        filterCommentVC.indexDelegate = self
        
        let popover = filterCommentVC.popoverPresentationController
        popover?.sourceView = filterCommentVC.view
        popover?.sourceRect = CGRect(x: (view.frame.width/2), y: (navigationController?.navigationBar.frame.height)! - 10, width: 0, height: 0)
        popover?.delegate = self
        presentViewController(filterCommentVC, animated: true, completion: nil)
    }
    
    func replyComment(sender:AnyObject){
        let cell = sender.superview!!.superview as! UITableViewCell
        let indexPath = tableView.indexPathForCell(cell)
        let id = commentArray[(indexPath?.row)!].status!.id
        let commentID = commentArray[(indexPath?.row)!].idstr
        let commentVC = NBWCommentViewController.init(id: id!,replyOrNot:true,commentID:Int(commentID!)!)
        presentViewController(commentVC, animated: true, completion: nil)
    }
    
    //MARK: - FetchDataFromWeibo
    
    func fetchCommentDataFromWeibo(urlString:String,_ filterByAuthor:Int){
        
        Alamofire.request(.GET, urlString, parameters: ["access_token":accessToken,"count":20,"filter_by_author":filterByAuthor], encoding: ParameterEncoding.URL, headers: nil)
            .responseJSON { (Response) -> Void in
                
                do {
                    let dict =  try NSJSONSerialization.JSONObjectWithData(Response.data!, options: NSJSONReadingOptions.AllowFragments) as! NSDictionary
                    let array = dict["comments"] as! NSArray
                    
                    self.commentIntoCoreData(array)
                    
                }catch let error as NSError{
                    print("Fetch error:\(error.localizedDescription)")
                }
        }
    }
    
    //MARK: - CoreData -- StoreData
    func commentIntoCoreData(array:NSArray){
        
        commentArray = []
        
        for commentDict in array {
            
            let idstr = commentDict["idstr"] as? String
            
            if commentAlreadyExisted(idstr!) {
                commentArray.append(comment!)
            }else{
                let comment             = weiboCommentManagedObject()
                importCommentDataFromJSON(comment, commentDict: commentDict as! NSDictionary)
                
                let weiboUser           = weiboUserManagedObject()
                let weiboUserDict       = commentDict["user"] as! NSDictionary
                importUserDataFromJSON(weiboUser, userDict: weiboUserDict)
                comment.user            = weiboUser
                
                let weiboStatus         = weiboStatusManagedObject()
                let weiboStatusDict     = commentDict["status"] as! NSDictionary
                importStatusDataFromJSON(weiboStatus, jsonDict: weiboStatusDict)
                comment.status          = weiboStatus
                
                let weiboStatusUser     = weiboUserManagedObject()
                let weiboStatusUserDict = weiboStatusDict["user"] as! NSDictionary
                importUserDataFromJSON(weiboStatusUser, userDict: weiboStatusUserDict)
                comment.status?.user    = weiboStatusUser
                
                let retweetedStatusDict = weiboStatusDict["retweeted_status"] as? NSDictionary
                
                if retweetedStatusDict == nil {
                    comment.status?.retweeted_status = nil
                }else{
                    let retweetedStatus = weiboStatusManagedObject()
                    importStatusDataFromJSON(retweetedStatus, jsonDict: retweetedStatusDict!)
                    comment.status?.retweeted_status = retweetedStatus
                    
                    let retweetedUser = weiboUserManagedObject()
                    let retweetedUserDict = retweetedStatusDict!["user"] as! NSDictionary
                    importUserDataFromJSON(retweetedUser, userDict: retweetedUserDict)
                    comment.status?.retweeted_status?.user = retweetedUser
                }
                
                let reply_commentDict = commentDict["reply_comment"] as? NSDictionary
                
                if reply_commentDict == nil {
                    comment.reply_comment = nil
                }else{
                    let replyComment            = weiboCommentManagedObject()
                    importCommentDataFromJSON(replyComment, commentDict: reply_commentDict!)
                    comment.reply_comment       = replyComment
                    
                    let replyCommentUser        = weiboUserManagedObject()
                    let replyCommentUserDict    = reply_commentDict!["user"] as! NSDictionary
                    importUserDataFromJSON(replyCommentUser, userDict: replyCommentUserDict)
                    comment.reply_comment?.user = replyCommentUser
                }
                commentArray.append(comment)
            }
        }
        setupTableView()
        tableView.reloadData()
    }
    
    func commentAlreadyExisted(id:String)->Bool{
        
        let request = NSFetchRequest(entityName: "Comment")
        request.predicate = NSPredicate(format: "idstr == \(id)")
        
        do{
            let array = try managerContext?.executeFetchRequest(request) as! [Comment]
            if array.count != 0 {
                comment = array[0]
                return true
            }
        }catch let error as NSError {
            print("Fetch comment error:\(error.localizedDescription)")
        }
        return false
    }

    
}

//MARK: - UIPopoverPresentationControllerDelegate

extension NBWCommentTableViewController:UIPopoverPresentationControllerDelegate{
    func adaptivePresentationStyleForPresentationController(controller: UIPresentationController) -> UIModalPresentationStyle {
        return UIModalPresentationStyle.None
    }
}

extension NBWCommentTableViewController:SendIndexDelegate{
    func sendIndex(index: Int) {
        filterByAuthor = index
//        fetchCommentDataFromWeibo()
    }
}
