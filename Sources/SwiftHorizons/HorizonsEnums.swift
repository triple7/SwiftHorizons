//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation

public typealias hp = HorizonsParameter

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
                hp.CENTER.id: "\(parentId!)",
                hp.EXTRA_PREC.id: "YES",
                hp.STEP_SIZE.id: "1d",
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

public enum AsteroidClass: String, Codable {
    case ast = "AST"   // General asteroid
    case amo = "AMO"   // Amor asteroids (near-Earth, do not cross Earth's orbit)
    case mca = "MCA"   // Mars-crossing asteroids
    case tjn = "TJN"   // Trojan asteroids (e.g., Jupiter Trojans)
    case com = "COM"   // General comet
    case mba = "MBA"   // Main-belt asteroid
    case imb = "IMB"   // Inner main-belt asteroid
    case apo = "APO"   // Apollo asteroids (Earth-crossing)
    case jfc = "JFC"   // Jupiter-family comet
    case jFc = "JFc"   // (Possible lowercase variant of JFC)
    case omb = "OMB"   // Outer main-belt asteroid
    case ctc = "CTc"   // Centaur/comet transition object
    case cen = "CEN"   // Centaur
    case tno = "TNO"   // Trans-Neptunian object
    case htc = "HTC"   // Halley-type comet
    case etc = "ETc"   // Earth Trojan candidate
    case ate = "ATE"   // Aten asteroids (Earth-crossing with a < 1 AU)

    var description: String {
        switch self {
        case .ast:
            return "General asteroid"
        case .amo:
            return "Amor asteroids (near-Earth, do not cross Earth's orbit)"
        case .mca:
            return "Mars-crossing asteroids"
        case .tjn:
            return "Trojan asteroids (e.g., Jupiter Trojans)"
        case .com:
            return "General comet"
        case .mba:
            return "Main-belt asteroid"
        case .imb:
            return "Inner main-belt asteroid"
        case .apo:
            return "Apollo asteroids (Earth-crossing)"
        case .jfc:
            return "Jupiter-family comet"
        case .jFc:
            return "Jupiter-family comet"
        case .omb:
            return "Outer main-belt asteroid"
        case .ctc:
            return "Centaur/comet transition object"
        case .cen:
            return "Centaur"
        case .tno:
            return "Trans-Neptunian object"
        case .htc:
            return "Halley-type comet"
        case .etc:
            return "Earth Trojan candidate"
        case .ate:
            return "Aten asteroids (Earth-crossing with a < 1 AU)"
        }
    }
}

public enum AsteroidKind: String, Codable {
    case an = "an"  // Numbered asteroid
    case au = "au"  // Unnumbered asteroid
    case cn = "cn"  // Numbered comet
    case cu = "cu"  // Unnumbered comet

    var description: String {
        switch self {
        case .an:
            return "Numbered asteroid"
        case .au:
            return "Unnumbered asteroid"
        case .cn:
            return "Numbered comet"
        case .cu:
            return "Unnumbered comet"
        }
    }
}

