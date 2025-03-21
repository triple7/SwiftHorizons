//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import simd

extension SwiftHorizons {
    
    
    internal func parseElements(jsonString: String) -> OrbitalElements {
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: jsonString.data(using: .utf8)!).result
                print(result)
        return OrbitalElements(eccentricity: 0, perihelionDistance: 0, timeOfPerihelionPassage: 0, longitudeOfAscendingNode: 0, argumentOfPerihelion: 0, inclination: 0)
    }
            
            func parseSingleTarget(name: String, id: String, objectType: String, parent: String, parameters: [String: String], text: String, type: EphemType, _ notify: Bool = false)->HorizonsTarget {
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: text.data(using: .utf8)!).result
                print(result)
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
        let extractedProperties = extractPhysicalProperties(from: format[0])
        print(extractedProperties)
        _ = format[1].components(separatedBy: "\n")
        var soe = ""
        var wip = false
        switch type {
        case .OBSERVER:
             soe = text.match("\\$\\$SOE[^(EOE)]*\\$\\$EOE")[0].first!
        case .ELEMENTS:
            break
        case .VECTORS:
            let start = result.components(separatedBy: "SOE\n").last!
            soe = "$$SOE\n\(start.components(separatedBy: "EOE").first!)"
        case .APPROACH:
            wip = true
            break
        case .SPK:
            wip = true
            break
        }
        
        if wip {
            fatalError( "Currently unavailable ephemerus type: \(type)" )
        }
        
        /* Parses the returned coordinate text block */
        var coordinateBlock = soe.components(separatedBy: "\n")
        coordinateBlock.removeFirst()
        coordinateBlock.removeLast()
        var ephemCoordinates = [[Double]]()
        var ephemCoordinateTimestamps = [Double]()
        for c in coordinateBlock {
            var coordinates = parseCoordinates(text: c.components(separatedBy: ","), type: type)
            let timestamp = coordinates.removeFirst()
            ephemCoordinateTimestamps.append(Double(timestamp)!)
            ephemCoordinates.append(coordinates.map {Double($0)!})
        }
        return HorizonsTarget(name: name, id: id, objectType: objectType, parent: parent, parameters: parameters, properties: [String]()/* temporary */, coordinates: ephemCoordinates, timestamps: ephemCoordinateTimestamps)
    }

    private final func parseCoordinates(text: [String], type: EphemType)->[String] {
        switch type {
        case .OBSERVER:
            return [text[0], text[3], text[4]].map {$0.replacingOccurrences(of: " ", with: "")}
        case .ELEMENTS:
            return [String]()
        case .VECTORS:
            return [ text[0], text[2], text[3], text[4]].map {$0.trimmingCharacters(in: .whitespaces)}
        case .APPROACH:
            return [String]()
        case .SPK:
            return [String]()
        }
    }

    
    func parseMBList(payload: MBList) -> [MB] {
        print(payload.result)
        var output:[MB] = []
        let lines = payload.result.components(separatedBy: "\n")
        
        // Identify header row (the line containing "ID# Name Designation IAU/aliases/other")
        guard let headerIndex = lines.firstIndex(where: { $0.contains("ID#") }) else {
            print("Error: Header row not found")
            return []
        }
        
        var headerFields = lines[headerIndex]
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        headerFields[0] = "id"
        headerFields[3] = "aliases"
        
        for line in lines[(headerIndex + 2)...] {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count < 1 + 1 { continue } // Skip invalid lines
            
            let idString = String(components[0])
            let name = String(components[1])
            let designation = components.count > 2 ? String(components[2]) : ""
            let aliases = components.count > 3 ? String(components[3]) : ""
            guard let id = Int(idString) else { continue } // Ensure valid ID

                                         // Numericals for extended identifiers

            let planets = [
                3: "Earth",
                4: "Mars",
                5: "Jupiter",
                6: "Saturn",
                7: "Uranus",
                8: "Neptune",
                9: "Pluto"
            ]
            let extended = [
                55: "Jupiter",
                65: "Saturn",
                75: "Uranus",
                85: "Neptune",
                95: "Pluto"
            ]
            
            if id % 100 == 99 || id <= 100 || id > 99999 { // Planet IDs usually end in 99
//                print("Found id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                output.append(MB(id: id, name: name, designation: designation, aliases: aliases))
            } else if id < 1000 && id > 299 && id % 100 != 99 {
//                print("found moon: \(id) \(name)")
                let planet = planets[id/100]!
                output.append(MB(id: id, name: name, designation: designation, aliases: aliases, planet: planet))
            } else { // Moon
//                print("Found id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                let bodyId = idString
                    let start = bodyId.index(bodyId.startIndex, offsetBy: 0)
                    let end = bodyId.index(bodyId.startIndex, offsetBy: 2)
                if let planet = extended[Int(bodyId[start..<end])!]{
                output.append(MB(id: id, name: name, designation: designation, aliases: aliases, planet: planet))
                } else {
                    // Other bodies
                    output.append(MB(id: id, name: name, designation: designation, aliases: aliases))
                }
        }
                                  }
        
                                         return output
    }

}

