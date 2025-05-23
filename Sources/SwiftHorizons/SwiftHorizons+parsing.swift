//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import simd

extension String {
    func capitalizingFirstLetter() -> String {
        guard let first = self.first else { return self }
        return String(first).uppercased() + self.dropFirst()
    }

    mutating func capitalizeFirstLetter() {
        self = self.capitalizingFirstLetter()
    }
}


extension SwiftHorizons {

    internal func extractNewDate(text: String) -> (start: String, stop: String) {
        let asteriskDelimitor = "***********************************************************************\n"
        let format = text.components(separatedBy: asteriskDelimitor).last!
        let upToDate = format.components(separatedBy: "A.D.").last!
        let components = upToDate.components(separatedBy: " ")
        // index 2 is the day in yyyy-MMM-dd
        // index 3 hh:mm:ss.zzzz
        let ymd = components[1].split(separator: "-")
        // Some have JAN instead of Jan
        let month = ymd[1].lowercased().capitalizingFirstLetter()
        let YMD = "\(ymd[0])-\(month)-\(ymd[2])"
        let dateString = "\(YMD) \(components[2])"
        
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        dateFormat.dateFormat = "yyyy-MMM-dd HH:mm:ss.SSSS"
        let date = dateFormat.date(from: dateString)!
        
        let calendar = Calendar(identifier: .gregorian)
        let prevDate = calendar.date(byAdding: .day, value: -2, to: date)!
        let endDate = calendar.date(byAdding: .day, value: -1, to: date)!
        return (start: dateFormat.string(from: prevDate), stop: dateFormat.string(from: endDate))
    }
    
    internal func getElementBlock(text: String) -> [String] {
        let start = text.components(separatedBy: "$$SOE\n").last!
        let soe = start.components(separatedBy: "$$EOE").first!
        var elementBlock = soe.components(separatedBy: "\n")
        elementBlock.removeLast()
        return elementBlock.map{$0.trimmingCharacters(in: .whitespacesAndNewlines)}
    }
    
    internal func parseElements(result: String, orbitalBlock: [String]) -> TargetProperties {
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
        let extractedProperties = extractPhysicalProperties(from: format[0])
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
            let ec = Double(ecqrinBlock[0].components(separatedBy: "=")[1])!
            let qr = Double(ecqrinBlock[1].components(separatedBy: "=")[1])!
            let inc = Double(ecqrinBlock[2].components(separatedBy: "=")[1])!
            let omwtpBlock = orbitalBlock[i*5+2].replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: " =", with: "=").replacingOccurrences(of: "  ", with: "").components(separatedBy: " ")
            let om = Double(omwtpBlock[0].components(separatedBy: "=")[1])!
            let w = Double(omwtpBlock[1].components(separatedBy: "=")[1])!
            let tp = Double(omwtpBlock[1].components(separatedBy: "=")[1])!
            let amataBlock = orbitalBlock[i*5+3].replacingOccurrences(of: " = ", with: "=").replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: "  ", with: "").components(separatedBy: " ")
            let n = Double(amataBlock[0].components(separatedBy: "=")[1])!
            let ma = Double(amataBlock[1].components(separatedBy: "=")[1])!
            let ta = Double(amataBlock[2].components(separatedBy: "=")[1])!
            let Aadapr = orbitalBlock[i*5+4].replacingOccurrences(of: " = ", with: "=").replacingOccurrences(of: "= ", with: "=").replacingOccurrences(of: " =", with: "=").replacingOccurrences(of: "  ", with: "").components(separatedBy: " ")
            let A = Double(Aadapr[0].components(separatedBy: "=")[1])!
            let ad = Double(Aadapr[1].components(separatedBy: "=")[1])!
            let apr = Double(Aadapr[2].components(separatedBy: "=")[1])!
            ephemorbitals.append(OrbitalElements(epoch: epoch, eccentricity: ec, periapsisDistance: qr, inclination: inc, ascendingNode: om, argumentOfPeriapsis: w, timeOfPeriapsis: tp, meanMotion: n, meanAnomaly: ma, trueAnomaly: ta, semiMajorAxis: A, apoapsisDistance: ad, orbitalPeriod: apr))
        }
        return try! TargetProperties(orbitalElements: ephemorbitals, physicalProperties: extractedProperties)
    }
            
            func parseSingleTarget(name: String, id: String, objectType: String, parent: String, parameters: [String: String], text: String, type: EphemType, _ notify: Bool = false)->HorizonsTarget {
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: text.data(using: .utf8)!).result
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
//                let extractedProperties = extractPhysicalProperties(from: format[0])
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
                if coordinateBlock.count == 1 {
                    fatalError("Coordinate block does not exist")
                }
                    coordinateBlock.removeFirst()
                    coordinateBlock.removeLast()
                    var ephemCoordinates = [[Double]]()
                    var ephemVelocities = [[Double]]()
                    var ephemCoordinateTimestamps = [Double]()
                    for c in coordinateBlock {
                        var coordinates = parseCoordinates(text: c.components(separatedBy: ","), type: type)
                        let timestamp = coordinates.removeFirst()
                        ephemCoordinateTimestamps.append(Double(timestamp)!)
                        var coordinateSet = [Double]()
                        var velocitySetg = [Double]()
                        for (i, c) in coordinates.enumerated() {
                            i < 3 ? coordinateSet.append(Double(c)!) : velocitySetg.append(Double(c)!)
                        }
                        ephemCoordinates.append(coordinateSet)
                        ephemVelocities.append(velocitySetg)
                    }
                return HorizonsTarget(name: name, id: id, objectType: objectType, parent: parent, parameters: parameters, properties: [], coordinates: ephemCoordinates, velocities: ephemVelocities, timestamps: ephemCoordinateTimestamps)
    }

    private final func parseCoordinates(text: [String], type: EphemType)->[String] {
        switch type {
        case .OBSERVER:
            return [text[0], text[3], text[4]].map {$0.replacingOccurrences(of: " ", with: "")}
        case .ELEMENTS:
            return [String]()
        case .VECTORS:
            return [ text[0], text[2], text[3], text[4], text[5], text[6], text[7]].map {$0.trimmingCharacters(in: .whitespaces)}
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
61: ("Saturn", 699),
62: ("Saturn", 699),
63: ("Saturn", 699),
64: ("Saturn", 699),
65: ("Saturn", 699),
66: ("Saturn", 699),
67: ("Saturn", 699),
68: ("Saturn", 699),
69: ("Saturn", 699),
75: ("Uranus", 799),
85: ("Neptune", 899),
95: ("Pluto", 999)
]
// bin for checking density per planet

        
        for line in lines[(headerIndex + 2)...] {
            let components = line.split(separator: " ", omittingEmptySubsequences: true)
            if components.count < 1 + 1 { continue } // Skip invalid lines
            
            let idString = String(components[0])
            let name = String(components[1])
            let designation = components.count > 2 ? String(components[2]) : ""
            let aliases = components.count > 3 ? String(components[3]) : ""
            guard let id = Int(idString) else { continue } // Ensure valid ID

            if id % 100 == 99 || (id <= 100 && id >= 0) || id > 99999 { // Planet IDs usually end in 99
//                print("Found id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                let parentId = id == 10 ?  0 : 10 // Sun case
                let parent = id == 10 ? "Solar Barycenter" : "Sol"
                let type = id == 10 ? "Star" : "Planet"
                output.append(MB(id: id, name: name, type: type, designation: designation, aliases: aliases, parent: parent, parentId: parentId))
            } else if id < 1000 && id > 299 && id % 100 != 99 {
//                print("found moon: \(id) \(name)")
                let planet = planets[id/100]!
                output.append(MB(id: id, name: name, type: "NaturalSat", designation: designation, aliases: aliases, parent: planet.0, parentId: planet.1))
            } else { // Moon
//                print("Found id \(id) name \(name) designation: \(designation) aliases: \(aliases)")
                let bodyId = idString
                    let start = bodyId.index(bodyId.startIndex, offsetBy: 0)
                    let end = bodyId.index(bodyId.startIndex, offsetBy: 2)
                if let planet = extended[Int(bodyId[start..<end])!]{
//                    print("Planet: \(planet)")

                    output.append(MB(id: id, name: name, type: "NaturalSat", designation: designation, aliases: aliases, parent: planet.0, parentId: planet.1))
                } else {
                    // Other bodies
//                                    print("other id\(id) name \(name) designation: \(designation) aliases: \(aliases)")
                    output.append(MB(id: id, name: name, type: "Satellite", designation: designation, aliases: aliases))
                }
        }
                                  }
        
                                         return output
    }

}

