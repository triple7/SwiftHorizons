//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation

typealias hp = HorizonsParameter

/* Reference from the JPL Horizon Systems API page
 https://ssd-api.jpl.nasa.gov/doc/horizons.html#spk_file
 */

public enum HorizonsType:String, Codable, CaseIterable, Identifiable {
    case Mb
    case Sb
    
    public var id:String {
        return self.rawValue
    }

}

public enum HorizonsParameter:String, CaseIterable, Identifiable {
    // Common parameters
    case format // json ,  text
    case COMMAND // see
    case OBJ_DATA // NO ,  YES
    case MAKE_EPHEM // NO ,  YES
    case EPHEM_TYPE // OBSERVER ,  VECTORS ,  ELEMENTS ,
    case EMAIL_ADDR // any valid email address
    
    // Ephemerus parameters
    case CENTER
    case REF_PLANE
    case COORD_TYPE
    case SITE_COORD
    case START_TIME
    case STOP_TIME
    case STEP_SIZE
    case TLIST
    case TLIST_TYPE
    case QUANTITIES
    case REF_SYSTEM
    case OUT_UNITS
    case VEC_TABLE
    case VEC_CORR
    case CAL_FORMAT
    case ANG_FORMAT
    case APPARENT
    case TIME_DIGITS
    case TIME_ZONE
    case RANGE_UNITS
    case SUPPRESS_RANGE_RATE
    case ELEV_CUT
    case SKIP_DAYLT
    case SOLAR_ELONG
    case AIRMASS
    case LHA_CUTOFF
    case ANG_RATE_CUTOFF
    case EXTRA_PREC
    case CSV_FORMAT
    case VEC_LABELS
    case VEC_DELTA_T
    case ELM_LABELS
    case TP_TYPE
    case R_T_S_ONLY
    case TABLE_TYPE
    
    public var id:String {
        return self.rawValue
    }

}

/* The main ephemerus outputs where:
 The most commonly used for sky maps and 3D spatial coordinates.
 observer: ground telescope
 vectors: takes an object in carthesian coordinate using local long lat from GPS
 
 */
public enum EphemType:String, CaseIterable, Identifiable {
    case OBSERVER
    case ELEMENTS
    case VECTORS
case APPROACH
    case SPK
    
    public var id:String {
        return self.rawValue
    }

    public func defaultParameters(_ parentId: Int? = nil) -> [String: String] {
        switch self {
        case .OBSERVER:
            return [
                hp.format.id: "text",
                hp.EPHEM_TYPE.id: self.id,
                hp.STEP_SIZE.id: "3",
                hp.ANG_FORMAT.id: "DEG",
                hp.EXTRA_PREC.id: "NO",
                hp.CSV_FORMAT.id: "YES",
            ]
        case .ELEMENTS:
            return [
                hp.EPHEM_TYPE.id: self.id,
                hp.ANG_FORMAT.id: "DEG",
                hp.CENTER.id: "500@\(parentId!)",
                hp.EXTRA_PREC.id: "YES",
            ]
        case .VECTORS: return VEC_BATCH_PARAMS
            case .APPROACH:
            /* WIP*/
            return [String: String]()
        case .SPK:
            /* WIP */
            return [String: String]()
        }
    }
    
    
}

enum Parameters{
    case Observable, Source, StartDate, EndDate, DurationStep
    
    var index:Int{
        switch self{
        case .Observable: return 0
        case .Source: return 5
        case .StartDate: return 7
        case .EndDate: return 8
        case .DurationStep: return 9
        }
    }

    func format(_ value: String)->String{
        return "\(value)\n"
    }
    
}
