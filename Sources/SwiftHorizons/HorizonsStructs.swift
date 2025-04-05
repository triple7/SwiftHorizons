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
     * target velocity vectors
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
    public let velocities:[[Double]]
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
        // User defined start and stop time
        if let startTime = target.startTime {
            self.parameters[hp.START_TIME.id] = startTime
            self.parameters[hp.STOP_TIME.id] = target.stopTime!
        }

        guard let location = location else {
            return
        }
        // convert altitude from iOS in meters to km in Horizons
        let convertedAltitude = location.altitude/1000
        self.parameters[hp.SITE_COORD.id] = "\(location.coordinate.longitude),\(location.coordinate.latitude),\(convertedAltitude)"
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
    public let type: String // reflects AOSType
    public var designation: String?
    public var aliases: String?
    public var parent: String?
    public var parentId:Int?
    
}

public struct TargetProperties:Codable {
    public let orbitalElements:[OrbitalElements]
    public let physicalProperties:[String: Double]
    
    
    // Mark: explicit initializer
    public init(orbitalElements: [OrbitalElements], physicalProperties: [String: Double]) throws {
        self.orbitalElements = orbitalElements
        self.physicalProperties = physicalProperties
    }
    
    // Mark: empty initializer
    public init() {
        self.orbitalElements = []
        self.physicalProperties = [:]
    }
}

public struct OrbitalElements: Codable {
    public let epoch: Double               // Julian Date of the elements
    public let eccentricity: Double        // EC
    public let periapsisDistance: Double   // QR (km)
    public let inclination: Double         // IN (degrees)
    public let ascendingNode: Double       // OM (degrees)
    public let argumentOfPeriapsis: Double // W (degrees)
    public let timeOfPeriapsis: Double     // Tp (Julian Date)
    public let meanMotion: Double          // N (degrees/day)
    public let meanAnomaly: Double         // MA (degrees)
    public let trueAnomaly: Double         // TA (degrees)
    public let semiMajorAxis: Double       // A (km)
    public let apoapsisDistance: Double    // AD (km)
    public let orbitalPeriod: Double       // PR (days)

    // CodingKeys enum to map short JSON keys to long property names
    enum CodingKeys: String, CodingKey {
        case epoch = "E"                   // Julian Date of the elements
        case eccentricity = "e"               // Eccentricity
        case periapsisDistance = "q"          // Periapsis Distance (km)
        case inclination = "i"                // Inclination (degrees)
        case ascendingNode = "o"              // Longitude of Ascending Node (degrees)
        case argumentOfPeriapsis = "W"         // Argument of Periapsis (degrees)
        case timeOfPeriapsis = "Tp"            // Time of Periapsis (Julian Date)
        case meanMotion = "n"                  // Mean Motion (degrees/day)
        case meanAnomaly = "m"                // Mean Anomaly (degrees)
        case trueAnomaly = "t"                // True Anomaly (degrees)
        case semiMajorAxis = "a"               // Semi-Major Axis (km)
        case apoapsisDistance = "ad"           // Apoapsis Distance (km)
        case orbitalPeriod = "p"              // Orbital Period (days)
    }
}



public struct AsteroidParams: Codable {
    public let spkid: Int                 // Spacecraft and Planet Kernel ID
    public let name: String               // Asteroid name
    public let kind: String               // Type or classification of the object
    public let `class`: String            // Dynamical class of the asteroid
    public var absolutemagnitude: Double? // Absolute magnitude (H)
    public var diameter: Double?          // Diameter (km)
    public var gm: Double?                // Gravitational parameter (km^3/s^2)
    public var albedo: Double?            // Geometric albedo

    // CodingKeys enum to map short JSON keys to long property names
    enum CodingKeys: String, CodingKey {
        case spkid = "s"                   // SPK-ID (shortened to "s")
        case name = "n"                    // Name (shortened to "n")
        case kind = "k"                    // Kind (shortened to "k")
        case `class` = "c"                 // Class (shortened to "c")
        case absolutemagnitude = "H"       // Absolute magnitude (H)
        case diameter = "D"                // Diameter (km)
        case gm = "gm"                     // Gravitational parameter (km^3/s^2)
        case albedo = "A"                  // Albedo (geometric)
    }

    // Custom decoding to handle both strings, numbers, and null values
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        self.spkid = try container.decodeIfPresent(Int.self, forKey: .spkid) ?? 0
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Unknown"
        self.kind = try container.decodeIfPresent(String.self, forKey: .kind) ?? "Unknown"
        self.class = try container.decodeIfPresent(String.self, forKey: .class) ?? "Unknown"

        // Handle cases where the value might be a Double, String, or null
        self.absolutemagnitude = try Self.decodeDoubleIfPresent(container, forKey: .absolutemagnitude)
        self.diameter = try Self.decodeDoubleIfPresent(container, forKey: .diameter)
        self.gm = try Self.decodeDoubleIfPresent(container, forKey: .gm)
        self.albedo = try Self.decodeDoubleIfPresent(container, forKey: .albedo)
    }

    // Helper function to decode Double or String, including handling null
    private static func decodeDoubleIfPresent(_ container: KeyedDecodingContainer<CodingKeys>, forKey key: CodingKeys) throws -> Double? {
        if let doubleValue = try? container.decodeIfPresent(Double.self, forKey: key) {
            return doubleValue
        }
        if let stringValue = try? container.decodeIfPresent(String.self, forKey: key), let doubleValue = Double(stringValue) {
            return doubleValue
        }
        return nil
    }
}

