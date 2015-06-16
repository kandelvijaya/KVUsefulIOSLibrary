//
//  ViewCounterAPI.swift
//  HospitalsNepal
//
//  PURPOSE: a standard API to hold the view count offline and then store it to the online without data conflict
//
//  Created by Vijaya Prakash Kandel on 6/8/15.
//  Copyright (c) 2015 Vijaya Prakash Kandel. Feel free to use it.
//

import UIKit

//struct to hold certain string that are need by the local parse database
struct TCViewCount{
    static let className = "ViewCounter"
    static let modelName = "modelTableName"
    static let modelId = "modelId"
    static let currentOfflineViewCount = "currentOfflineViewCount"
}

class ViewCounterAPI{
    
    private init(){
        //listen for notification on app did launch
        //NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector(tryUploadingStaleViewCount()), name: "UIApplicationDidBecomeActiveNotification", object: nil)
        //call this init on app launch
        tryUploadingStaleViewCount()
    }
    
    deinit{
        //NSNotificationCenter.defaultCenter().removeObserver(self)   //remove to dealloc this object properly
    }
    
    //MARK:-singleton
    static let sharedInstance = ViewCounterAPI()
    //static is lazy and create a copy and get hold of it
    //let makes usre the object is instantiated once and only once
    
    
    
    
    
    //MARK:-public API
    /**
    Increments the view count and sync with the cloud whenever possible
    
    :param: modelName model name the user viewed like Hospital, Doctor, Ambulance
    :param: modelId   id of the entity
    */
    func incrementViewCountFor(modelName modelName:String, modelId:Int){
        self.storeViewCountDataLocally(modelName, modelId: modelId)
    }
    
    
    
    //MARK:-Private Worker
    /**
    Store the tableName, dataID and currentOfflineViewCount in local database
    If the table already exists then just increment by one
    
    :param: tableName               get from the context
    :param: modelId                 unique identifier
    :param: currentOfflineViewCount
    */
    private func storeViewCountDataLocally(tableName:String, modelId:Int){
        //if the table with the tablename and id exists just update that one
        let query = PFQuery(className: TCViewCount.className)
        query.fromLocalDatastore()
        query.whereKey(TCViewCount.modelName, equalTo: tableName)
        query.whereKey(TCViewCount.modelId, equalTo: modelId)
        
        query.findObjectsInBackgroundWithBlock { (objects, error) -> Void in
            if error == nil && objects != nil{
                //we have something
                if objects?.count > 0{
                    if let goodObject:PFObject = (objects?.first) as? PFObject{
                        //we have valid object
                        //just increment the viewCounter by one
                        goodObject[TCViewCount.currentOfflineViewCount] = (goodObject.objectForKey(TCViewCount.currentOfflineViewCount) as! Int) + 1
                        goodObject.pinInBackground()
                    }
                }else{
                    //we dont have create and save
                    let counterObject = PFObject(className: TCViewCount.className)
                    counterObject.setObject(tableName, forKey: TCViewCount.modelName)
                    counterObject.setObject(modelId, forKey: TCViewCount.modelId)
                    counterObject.setObject(1, forKey: TCViewCount.currentOfflineViewCount) //1 because this is the first view
                    counterObject.pinInBackground() //store it localy async
                }
                
                //try to store now too
                self.tryUploadingStaleViewCount()
            }
        }
    }
    
    
    private func tryUploadingStaleViewCount(){
        print("trying to upliad view count")
        //check if the offlineviewcounter table is empty
        //if not then try sycning the data online
        let query = PFQuery(className: TCViewCount.className)
        query.fromLocalDatastore()
        query.findObjectsInBackgroundWithBlock { (objects, error) -> Void in
            if error == nil && objects != nil{
                //have something to work with
                if let goodObjects = objects as? [PFObject]{
                    //iterate and try syncing
                    for goodObject in goodObjects{
                        let tableName = goodObject.objectForKey(TCViewCount.modelName) as! String
                        let modelId = goodObject.objectForKey(TCViewCount.modelId) as! Int
                        let currentOfflineViewCount  = goodObject.objectForKey(TCViewCount.currentOfflineViewCount) as! Int
                        //call the method to sync online
                        self.incrementViewCountFor(tableName, modelId: modelId, currentOfflineViewCount: currentOfflineViewCount, completion: { (status) -> () in
                            if status{
                                "Synced".debug()
                                print(goodObject)
                                //purge the table entity
                                //we might take the currentOfflineViewCount to 0 but not now
                                goodObject.unpin()      //removes
                            }else{
                                "Not synced now".debug()
                                return  //return from this block because we dont have internet now
                                //dont use the resource just trying
                            }
                        })
                    }
                    
                }else{
                    //its empty
                    return
                }
            }
        }//closure ends
    }//fn ends
    
    
    /**
    function to increment the view count of the parse db items view count
    
    :param: tableName               modelName
    :param: modelId                 unique identifier
    :param: currentOfflineViewCount
    :param: completion              Returns a block with the status of success: Bool
    */
    private func incrementViewCountFor(tableName:String, modelId:Int, currentOfflineViewCount:Int, completion:((Bool)->())?){
        //1. get the object from the online parse database for the tablename and id
        let query = PFQuery(className: tableName)
        query.whereKey(TableColumn.BaseDetail.id, equalTo: modelId)
        query.findObjectsInBackgroundWithBlock { (objects, error) -> Void in
            if error == nil && objects != nil{
                print(objects?.first)
                if let goodObject = objects?.first as? PFObject{
                    //update the view count by incremnting from the current value
                    //as Hugo said the below condition possibly makes a race case 
                    //that is what i found after going throught the parse documentation again
                    //FIXME:- change the columnName on the parse db here  
                    //so this code does do the work atomically
                    goodObject.incrementKey("columnNameForViewCount????", byAmount: currentOfflineViewCount)
                    
                    //save it online
                    goodObject.saveInBackgroundWithBlock({ (status, error) -> Void in
                        if status{
                            //after sync:
                            //keep or update the local copy to reflect changes
                            goodObject.pinInBackground()
                            completion?(true)
                            print(goodObject)
                        }else{
                            completion?(false)  //call the callback with false
                        }
                    })
                }
            }else{
                //we dont have internet or error occured
                completion?(false)
            }
        }//query ends
    }//inner function ends
    
}

