//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import simd

extension SwiftHorizons {
    
    
    internal func parseElements(jsonString: String) -> TargetProperties {
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: jsonString.data(using: .utf8)!).result
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
        let extractedProperties = extractPhysicalProperties(from: format[0])
        let start = result.components(separatedBy: "SOE\n").last!
        let soe = "$$SOE\n\(start.components(separatedBy: "EOE").first!)"
        var orbitalBlock = soe.components(separatedBy: "\n")
        orbitalBlock.removeFirst()
        orbitalBlock.removeLast()
        print(orbitalBlock)
        var ephemorbitals = [OrbitalElements]()
        /* csv output is not available
        So JD is first of a sequence at index 0
         every 5 after that will be the next of the blocks
         * ec, qr and in are index 1
         om, w and tp are index 2
         n, ma ta are index 3
         a, ada, pr are index 4
         then cycle through
         */
        let idx = orbitalBlock.count/5
        for i in 0 ..< idx {
            let jdBlock = orbitalBlock[i*5].replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: " =", with: "=").components(separatedBy: "=")
            let epoch = Double(jdBlock[0])!
            let ecqrinBlock = orbitalBlock[i*5+1].replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: " =", with: "=").components(separatedBy: " ")
            let ec = Double(ecqrinBlock[1].components(separatedBy: "=")[1])!
            let qr = Double(ecqrinBlock[2].components(separatedBy: "=")[1])!
            let inc = Double(ecqrinBlock[3].components(separatedBy: "=")[1])!
            let omwtpBlock = orbitalBlock[i*5+2].replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: " =", with: "=").replacingOccurrences(of: "  ", with: "").components(separatedBy: " ")
            let om = Double(omwtpBlock[1].components(separatedBy: "=")[1])!
            let w = Double(omwtpBlock[2].components(separatedBy: "=")[1])!
            let tp = Double(omwtpBlock[4])!
            let amataBlock = orbitalBlock[i*5+3].replacingOccurrences(of: " = ", with: "=").replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: "  ", with: "").components(separatedBy: " ")
            
            let n = Double(amataBlock[1].components(separatedBy: "=")[1])!
            let ma = Double(amataBlock[2].components(separatedBy: "=")[1])!
            let ta = Double(amataBlock[3].components(separatedBy: "=")[1])!
            let Aadapr = orbitalBlock[i*5+4].replacingOccurrences(of: " = ", with: "=").replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: " =", with: "=").replacingOccurrences(of: "  ", with: "").components(separatedBy: " ")
            let A = Double(Aadapr[1].components(separatedBy: "=")[1])!
            let ad = Double(Aadapr[2].components(separatedBy: "=")[1])!
            let apr = Double(Aadapr[3].components(separatedBy: "=")[1])!
            ephemorbitals.append(OrbitalElements(epoch: epoch, eccentricity: ec, periapsisDistance: qr, inclination: inc, ascendingNode: om, argumentOfPeriapsis: w, timeOfPeriapsis: tp, meanMotion: n, meanAnomaly: ma, trueAnomaly: ta, semiMajorAxis: A, apoapsisDistance: ad, orbitalPeriod: apr))
        }
        return TargetProperties(orbitalElements: ephemorbitals, physicalProperties: extractedProperties)
    }
            
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
                3: ("Earth", 399),
                4: ("Mars", 499),
                5: ("Jupiter", 599),
                6: ("Saturn", 699),
                7: ("Uranus", 799),
                8: ("Neptune", 899),
                9: ("Pluto", 999)
            ]
            let extended = [
                55: ("Jupiter", 599),
                65: ("Saturn", 699),
                75: ("Uranus", 799),
                85: ("Neptune", 899),
                95: ("Pluto", 999)
            ]
            
            if id % 100 == 99 || id <= 100 || id > 99999 { // Planet IDs usually end in 99
//                print("Found id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                let parentId = id == 10 ?  0 : 10 // Sun case
                let parent = id == 10 ? "Solar Barycenter" : "Sol"
                output.append(MB(id: id, name: name, designation: designation, aliases: aliases, parent: parent, parentId: parentId))
            } else if id < 1000 && id > 299 && id % 100 != 99 {
//                print("found moon: \(id) \(name)")
                let planet = planets[id/100]!
                output.append(MB(id: id, name: name, designation: designation, aliases: aliases, parent: planet.0, parentId: planet.1))
            } else { // Moon
//                print("Found id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                let bodyId = idString
                    let start = bodyId.index(bodyId.startIndex, offsetBy: 0)
                    let end = bodyId.index(bodyId.startIndex, offsetBy: 2)
                if let planet = extended[Int(bodyId[start..<end])!]{
                    output.append(MB(id: id, name: name, designation: designation, aliases: aliases, parent: planet.0, parentId: planet.1))
                } else {
                    // Other bodies
//                                    print("other id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                    output.append(MB(id: id, name: name, designation: designation, aliases: aliases, parent: "Barycenter", parentId: 0))
                }
        }
                                  }
        
                                         return output
    }

}

