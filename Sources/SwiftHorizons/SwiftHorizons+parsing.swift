//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import simd

extension SwiftHorizons {
    
    func parseSingleTarget(name: String, id: String, objectType: String, parent: String, parameters: [String: String], text: String, type: EphemType, _ notify: Bool = false)->HorizonsTarget {
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: text.data(using: .utf8)!).result
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
        _ = format[1].components(separatedBy: "\n")
        var soe = ""
        var wip = false
        switch type {
        case .OBSERVER:
             soe = text.match("\\$\\$SOE[^(EOE)]*\\$\\$EOE")[0].first!
        case .ELEMENTS:
            wip = true
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

    
    func parseMBList(payload: MBList) -> [String: Any] {
        var planets: [String: [String: Any]] = [:]
        var moons: [[String: Any]] = []
        
        let lines = payload.result.components(separatedBy: "\n")
        
        // Identify header row (the line containing "ID# Name Designation IAU/aliases/other")
        guard let headerIndex = lines.firstIndex(where: { $0.contains("ID#") }) else {
            print("Error: Header row not found")
            return [:]
        }
        
        let headerFields = lines[headerIndex]
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        
        // Define index positions based on header
        let idIndex = headerFields.firstIndex(of: "ID#") ?? 0
        let nameIndex = headerFields.firstIndex(of: "Name") ?? 1
        let designationIndex = headerFields.firstIndex(of: "Designation") ?? 2
        
        // Iterate over data rows
        for line in lines[(headerIndex + 2)...] { // Skip header and separator
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count < nameIndex + 1 { continue } // Skip invalid lines
            
            let idString = String(components[idIndex])
            let name = String(components[nameIndex])
            let designation = components.count > designationIndex ? String(components[designationIndex]) : nil
            
            guard let id = Int(idString) else { continue } // Ensure valid ID
            
            let entry: [String: Any] = [
                "id": id,
                "name": name,
                "designation": designation ?? ""
            ]
            
            if id % 100 == 99 { // Planet IDs usually end in 99
                planets[name] = entry
            } else { // Moon
                var moonEntry = entry
                let planetId = (id / 100) * 100 + 99 // Find associated planet
                let planetName = planets.first(where: { $0.value["id"] as? Int == planetId })?.key ?? "Unknown"
                moonEntry["planet"] = planetName
                moons.append(moonEntry)
            }
        }
        
        return ["planets": planets, "moons": moons]
    }

}

