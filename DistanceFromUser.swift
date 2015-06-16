//
//  Location.swift
//  HospitalsNepal
//
//  Created by Vijaya Prakash Kandel on 5/10/15.
//  Copyright (c) 2015 Vijaya Prakash Kandel. Use freely.
//

import Foundation
import CoreLocation

protocol CurrentUserLocationObserver: class{
    func currentUserLocationDidChange(newLocation:CLLocation)
}

class Location: NSObject,CLLocationManagerDelegate{
    var locationManager:CLLocationManager!
    private static var instance:Location?
    static var lastKnownUserLocation:CLLocation?{
        willSet{
            if newValue != nil{
                Location.storeCurrentUserLocation(newValue!)
                Location.sharedInstance().delegate?.currentUserLocationDidChange(newValue!)
            }
        }
    }
    
    //be a delegate if you want to listen to the location change
    weak var delegate:CurrentUserLocationObserver?
    
    private override init(){
        super.init()
        //"Creating location".log()
        locationManager = CLLocationManager()
        //wheener we initiate we go do our work
        fetchCurrentUserLocation()
    }
    
    static func sharedInstance() -> Location{
        if Location.instance == nil{
            Location.instance = Location()
        }
        return Location.instance!
    }
    
    //via cellular or whatever via significant changes
    func fetchCurrentUserLocation(){
        if CLLocationManager.locationServicesEnabled(){
            locationManager.delegate = self
            //ios8 must ask authorization
            locationManager.requestWhenInUseAuthorization()
            //we do this for the first time only the we swith to significant changes only
            locationManager.startUpdatingLocation()
        }else{
            //"Location disabled".log()     //Future:alert user to turn back on
        }
    }
    
    //store it on defaults, on db and on online if its useful
    static func storeCurrentUserLocation(userLocation:CLLocation){
        let defaults = NSUserDefaults.standardUserDefaults()
        //break the location to property list compatibles and store
        let lat = userLocation.coordinate.latitude
        let long = userLocation.coordinate.longitude
        defaults.setObject(lat, forKey: "latestUserLocationLatitude")
        defaults.setObject(long, forKey: "latestUserLocationLongitude")
    }
    
    //a way to get the last set user location
    //try to get a new one and if it fails or time outs default to the last stored
    func getCurrentUserLocation()-> CLLocation?{
        //try the cellular one
        self.fetchCurrentUserLocation()
        
        //retrive from defautls
        let defaults = NSUserDefaults.standardUserDefaults()
        let lat = defaults.objectForKey("latestUserLocationLatitude") as? Double
        let long = defaults.objectForKey("latestUserLocationLongitude") as? Double
        
        //check for validity
        if lat != nil && long != nil{
            //godd data
            let alocation = CLLocation(latitude: lat!, longitude: long!)
            //save it too
            Location.lastKnownUserLocation = alocation
            return alocation
        }
        
        return nil
    }
    
    
    //MARK: Location manager delegates
    func locationManager(manager: CLLocationManager, didFailWithError error: NSError) {
        //"Our location retriving failed".log()
        print(error)
    }
    
    func locationManager(manager: CLLocationManager, didUpdateLocations locations: [AnyObject]) {
        //we got some data to work with
        //"User Location update".log()
        let latestLocation = locations.last as? CLLocation
        if latestLocation != nil{
            //we got some good thing
            //we may need to watch how recent it was using time stamp ::future:
            Location.lastKnownUserLocation = latestLocation
            //set the accuracy to significant change
            locationManager.stopUpdatingLocation()
            //now hear only the big changes
            locationManager.startMonitoringSignificantLocationChanges()
        }
    }
    
    
    //MARK: computing distance from the given coordinates
    func computeDistanceFromUsersPosition(destinationGeoCoordinate:CLLocationCoordinate2D?, callBack:(Double?)->()){
        //get users location during the app launch
        //store that in defaults so we avoid to read location every time
        //user can locate themself correctly on map and we get update
        //else we use 1km range data
        
        var userLocation = Location.lastKnownUserLocation
        
        if destinationGeoCoordinate != nil {
            
            //check if the hospital geocordinate are out of bounds
            if abs(destinationGeoCoordinate!.latitude) > 90.0 || abs(destinationGeoCoordinate!.longitude) > 180.0{
                callBack(nil)
                return
            }
            
            if userLocation == nil{
                //try once more
                userLocation = getCurrentUserLocation()
            }
            
            if userLocation == nil {
                callBack(nil)
                return
            }
            
            let hospitalLocation = CLLocation(latitude: destinationGeoCoordinate!.latitude, longitude: destinationGeoCoordinate!.longitude)
            let userLocation = CLLocation(latitude: userLocation!.coordinate.latitude, longitude: userLocation!.coordinate.longitude)
            
            let distanceMeter = hospitalLocation.distanceFromLocation(userLocation)
            let distanceKM = distanceMeter/1000;
            let displayablePrecision = convertDouble(distanceKM, precision:2);
            //"This entity is located \(displayablePrecision)KM from the user".log()
            
            callBack(displayablePrecision)
        }
    }
    
    //rounder for doubles
    private func convertDouble(double:Double, precision:Int) -> Double{
        let falseDouble = Int(double * 10.0 * Double(precision))    //truncates all decimal
        let goodData:Double = Double(falseDouble) / (10.0 * Double(precision))
        return goodData
    }
    
    
    
    static func getGeoCoordinateFromString(data:String?) -> CLLocationCoordinate2D?{
        if let goodData = data{
            //split maplocation by ,
            //and set
            let array = goodData.componentsSeparatedByString(",")
        
        
        
            
            if array.count == 2{
                if array.first != nil && array.last != nil{
                    //we have something but thats omething maynot convert to doubles
                    let lat = (array.first! as NSString).doubleValue
                    let long = (array.last! as NSString).doubleValue    //if error we get 0.0
                    
                    //check we got good pair
                    if abs(lat) <= 90.0 && abs(long) <= 180.0{
                        return CLLocationCoordinate2DMake(lat, long)
                    }
                }
            }
        }
        //println(self.geoCoordinate?.latitude)
        return nil
    }
}
