//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import CoreLocation

public struct HorizonsBatchObject:Codable, Hashable, Equatable {
    public let name:String // Known name
    public let id: String // Known id in horizons
    public let type: HorizonsType // for request forming
    public let objectType:String // category of object as known in english language
    public let parent:String // The object's orbit parent
    public var parentId:Int?
    public var startTime:String?
    public var stopTime:String?

    public init(name: String, id: String, type: HorizonsType, objectType: String, parent: String, parentId: Int? = nil) {
        self.name = name
        self.id = id
        self.type = type
        self.objectType = objectType
        self.parent = parent
        self.parentId = parentId
    }
    
    
    public mutating func setTime(start: String, stop: String) {
        self.startTime = start
        self.stopTime = stop
    }
    
    public static func == (lhs: HorizonsBatchObject, rhs: HorizonsBatchObject) -> Bool {
        return lhs.id == rhs.id && lhs.type == rhs.type
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(type)
    }
}

public struct HorizonsTarget:Codable {
    /** Horizons target result
     Object containing all information pertaining to a Horizons target including:
     * known name
     * target id
     * target orbital parent
     * target object type
     * target request parameters
     * target physical properties
     * target ephemerus carthesian vectors
     * target coordinate timestamp
     */
    
    public let name:String // Known name
    public let id:String /* Horizons client object id */
    public var designation:String?
    public let objectType:String
    public let parent:String
    public let parameters:[String: String] /* object request parameters */
    public let properties:[String] /* physical object properties */
    public let coordinates:[[Double]] /* ephemerus carthesian coordinates */
    public let timestamps:[Double]

}

public struct HorizonsRequest {
    /** Horizons request formatter
     Creates a request Url from the API and configured parameters, with start and end time
     */
    private let APIUrl = "https://ssd.jpl.nasa.gov/api/horizons.api"
    private let fileAPIUrl = "https://ssd.jpl.nasa.gov/api/horizons_file.api"
    private(set) var parameters:[String: String]
    
    public init(target: HorizonsBatchObject, parameters: [String: String], location: CLLocation? = nil) {
        if target.type == .Mb {
            self.parameters = [hp.COMMAND.id: target.id] + parameters
        } else {
            let components = target.id.components(separatedBy: "/")
            let des = components[1]
            self.parameters = [hp.COMMAND.id: "DES=\(des)"] + parameters
        }
        guard let location = location else {
            return
        }
        // convert altitude from iOS in meters to km in Horizons
        let convertedAltitude = location.altitude/1000
        self.parameters[hp.SITE_COORD.id] = "\(location.coordinate.longitude),\(location.coordinate.latitude),\(convertedAltitude)"
        
        // User defined start and stop time
        if let startTime = target.startTime {
            print("has startime and stop times")
            self.parameters[hp.START_TIME.id] = startTime
            self.parameters[hp.STOP_TIME.id] = target.stopTime!
        }
    }

    public init() {
        self.parameters = [String: String]()
    }

    public mutating func setParameter(name: String, value: String) {
        parameters[name] = value
    }

    
    public func getURL(start: Int = -1, stop: Int = 1)->URL {
        /** Returns a formatted request Url
         Params:
         start: how many units before current time local
         end: how many units after current time local
         */
            var url = URLComponents(string: APIUrl)
        var params = getparameters(start, stop)
        for k in params.keys {
            if k != hp.format.id {
            params[k] = "'\(params[k]!)'"
            }
        }
        url!.queryItems = Array(params.keys).map {URLQueryItem(name: $0, value: params[$0]!)}
            return url!.url!
        }

    public func getElementUrl() -> URL {
        /** Returns a formatted request Url
         */
            var url = URLComponents(string: APIUrl)
        var params = getparameters()
        for k in params.keys {
            if k != hp.format.id {
            params[k] = "'\(params[k]!)'"
            }
        }
        url!.queryItems = Array(params.keys).map {URLQueryItem(name: $0, value: params[$0]!)}
            return url!.url!
        }

    public func getparameters(_ start: Int = -1, _ stop: Int = 1)->[String: String] {
        /** Returns parameters used for the Url request
         Params:
         start: time unit before current local time
         end: time unit after current local time
         Returns: [String: String]
         */
        let T = (parameters[hp.START_TIME.id] != nil) ? (parameters[hp.START_TIME.id]!, parameters[hp.STOP_TIME.id]!) : DateAgent.getISODate(t0: start, t1: stop)
        return parameters + [hp.START_TIME.id: T.0, hp.STOP_TIME.id: T.1]
    }

    public func getMbRequestUrl() -> URL {
        var url = URLComponents(string: APIUrl)
    url!.queryItems = [URLQueryItem(name: "COMMAND", value: "MB")]
        return url!.url!
    }
}

public struct HorizonsReturnJson:Codable {
    let result:String
    let signature:HorizonsReturnSignature
}


public struct HorizonsReturnSignature:Codable {
    let version:String
    let source:String
}

struct MBList: Codable {
    let result: String
    let signature: HorizonsReturnSignature
}

public struct MB: Codable {
    public let id: Int
    public let name: String
    public var designation: String?
    public var aliases: String?
    public var parent: String?
    public var parentId:Int?
    
}

public struct TargetProperties:Codable {
    let orbitalElements:[OrbitalElements]
    let physicalProperties:[String: Double]
}

public struct OrbitalElements: Codable {
    let epoch: Double               // Julian Date of the elements
    let eccentricity: Double        // EC
    let periapsisDistance: Double   // QR (km)
    let inclination: Double         // IN (degrees)
    let ascendingNode: Double       // OM (degrees)
    let argumentOfPeriapsis: Double // W (degrees)
    let timeOfPeriapsis: Double     // Tp (Julian Date)
    let meanMotion: Double          // N (degrees/day)
    let meanAnomaly: Double         // MA (degrees)
    let trueAnomaly: Double         // TA (degrees)
    let semiMajorAxis: Double       // A (km)
    let apoapsisDistance: Double    // AD (km)
    let orbitalPeriod: Double       // PR (days)
}
