//
//  Event.swift
//  CoreML in ARKit
//
//  Created by Andrew Scherba on 11/10/17.
//  Copyright © 2017 CompanyName. All rights reserved.
//

import Foundation
import GoogleAPIClientForREST
import Google
class Event {
    var startDate:Date
    var endDate:Date
    var title:String
    var isBusy:Bool {
        return (startDate ... endDate).contains(Date())
    }
    
    init(event:GTLRCalendar_Event) {
        title = event.summary ?? ""
        startDate = event.start?.dateTime?.date ?? event.start!.date!.date
        endDate = event.end?.dateTime?.date ?? event.end!.date!.date
    }
}

