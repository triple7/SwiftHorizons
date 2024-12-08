//
//  Untitled.swift
//  SwiftHorizons
//
//  Created by Yuma decaux on 8/12/2024.
//

import Foundation


extension SwiftHorizons {
    
    func setCelestialSnapshotTime(){
        snapShotToday = Date()
        snapShotJDStart = (snapShotToday!.timeIntervalSince(J2000))/86400.0 + JULIAN2000
    }

    
        func getSnapShotJD() -> Double {
            return snapShotJDStart!
        }
        
        func getTDBtime(date: Date)->Date{
            if firstTimeSamplingJD{
                firstTimeSamplingJD=false
                setCelestialSnapshotTime()
            }
            let UTC1970 = snapShotToday!.timeIntervalSince1970
            
            let JD = snapShotJDStart! //(date.timeIntervalSince(J2000)+deltaTau)/86400.0 + JULIAN2000

            let g = 357.53 + 0.9856003 * ( JD - JULIAN2000 ) // degrees
            
            let TDB1970 = UTC1970  + 32.184 + 0.001658 * sin(g * Double.pi/180.0) + 0.000014 * sin(2 * g * Double.pi/180.0)  // seconds
            
            let TDB = Date(timeIntervalSince1970: TDB1970)
            return TDB
        }
        
    }
    
    
