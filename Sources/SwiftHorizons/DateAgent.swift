//
//  File.swift
//  
//
//  Created by Yuma decaux on 18/4/2022.
//

import Foundation

public final class DateAgent {
/** Agent responsible for converting date formats
 This class will expand as new requirements are identified
 */
    
    public final class func getISODate(t0: Int, t1: Int)->(String, String) {
        /** ISO date formatter (yyyy-MMM-dd hh:mm)
         Params:
         t0: negative time unit in days from current local time
         t1: positive unit time in days from current local time
         */
    let dateFormat = DateFormatter()
        dateFormat.dateFormat = "yyyy-MMM-dd hh:mm"
        let start = Calendar.current.date(byAdding: .day, value: t0, to: Date())!
        let end = Calendar.current.date(byAdding: .day, value: t1, to: Date())!
return (dateFormat.string(from: start), dateFormat.string(from: end))
    }
    
}
