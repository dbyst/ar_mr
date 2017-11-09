//
//  GoogleCalendarManager.swift
//  GoogleCalendar
//
//  Created by Andrew Scherba on 11/9/17.
//  Copyright © 2017 Andrew Scherba. All rights reserved.
//

import Foundation
import Google
import GoogleAPIClientForREST
import GoogleSignIn
class GoogleCalendarManager:NSObject,GIDSignInUIDelegate,GIDSignInDelegate {
 
    
    
    enum RoomType:String {
        case big = "remit.se_3838373539393531363133@resource.calendar.google.com"
        case bus = "remit.se_3135383730373737333533@resource.calendar.google.com"
        case small = "remit.se_3231363835353731363839@resource.calendar.google.com"
    }
    var googleCalendar:GTLRCalendarService = GTLRCalendarService()
    var signCallback:(()->())?
    func start(viewController:UIViewController,finishLoginCallback:@escaping (()->())) {
        vc = viewController
        signCallback = finishLoginCallback
        GIDSignIn.sharedInstance().signIn()
    }
    fileprivate var vc:UIViewController?
    
    static let shared = GoogleCalendarManager()
    
   override init() {
        super.init()
        GIDSignIn.sharedInstance().uiDelegate = self
        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().scopes = [kGTLRAuthScopeCalendarReadonly]
        googleCalendar = GTLRCalendarService()
     
    }

    func executeRequest(startDate:Date,endDate:Date, room:RoomType, finishCallback:@escaping (([GTLRCalendar_Event])->())) {
        
        let query = GTLRCalendarQuery_EventsList.query(withCalendarId: room.rawValue)
        query.maxResults = 100
        query.timeMin = GTLRDateTime(date: startDate)
        query.timeMax = GTLRDateTime(date: endDate)
        query.singleEvents = true
        query.orderBy = kGTLRCalendarOrderByStartTime
        
        googleCalendar.executeQuery(query, completionHandler: { (ticke, obj, error) in
        
        guard let gtlobj = obj as? GTLRCalendar_Events, let events = gtlobj.items else {
            finishCallback([])
            return
        }
            finishCallback(events)
        })
    }
        
    func sign(inWillDispatch signIn: GIDSignIn!, error: Error!) {
        
    }
    

    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error!) {
        if user != nil {
            googleCalendar.authorizer = user.authentication.fetcherAuthorizer()
            signCallback?()
        }
    }
    
    func sign(_ signIn: GIDSignIn!, present viewController: UIViewController!) {
        vc?.present(viewController, animated: true, completion: nil)
    }
    
    func sign(_ signIn: GIDSignIn!, dismiss viewController: UIViewController!) {
        vc?.dismiss(animated: true, completion: nil)
    }
}
