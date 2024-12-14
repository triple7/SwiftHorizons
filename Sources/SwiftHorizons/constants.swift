//
//  constants.swift
//  SwiftHorizons
//
//  Created by Yuma decaux on 7/12/2024.
//


import Foundation

/* Astronomical constants used for
 time and date conversion
 */

//Julian date for Jan2000
let JULIAN2000 = 2451545.0
//get local UT time since J2000 12h UT+1
let J2000 = Date(timeIntervalSinceReferenceDate: -(31536000 + 43200)) //Taken into account 1 year and 12 hours in seconds
//J2000 to unix timestamp epoch
let j2000Unix = 946684800



var VEC_BATCH_PARAMS = [
    hp.OBJ_DATA.id: "NO",
    hp.MAKE_EPHEM.id: "YES",
    hp.TABLE_TYPE.id: "V",
    hp.CENTER.id: "c@399",
    hp.REF_PLANE.id: "F",
    hp.COORD_TYPE.id: "GEODETIC",
    hp.SITE_COORD.id: "",
    hp.START_TIME.id: "2018-mar-30 00:00",
    hp.STOP_TIME.id: "2019-mar-30 00:00",
    hp.STEP_SIZE.id: "5m",
    hp.REF_SYSTEM.id: "J2000",
    hp.OUT_UNITS.id: "KM-S",
    hp.VEC_TABLE.id: "1",
//    hp.VEC_CORR.id: "3",
    hp.CSV_FORMAT.id: "YES",
]
