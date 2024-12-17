//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import simd

extension SwiftHorizons {
    
    func parseSingleTarget(name: String, id: String, objectType: String, parameters: [String: String], text: String, type: EphemType, _ notify: Bool = false)->HorizonsTarget {
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: text.data(using: .utf8)!).result
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
        print("parsing single target")
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
            print("getting type \(type)")
            var coordinates = parseCoordinates(text: c.components(separatedBy: ","), type: type)
            ephemCoordinateTimestamps.append(Double(coordinates.removeFirst())!)
            ephemCoordinates.append(coordinates.map {Double($0)!})
        }
        return HorizonsTarget(name: name, id: id, objectType: objectType, parameters: parameters, properties: [String]()/* temporary */, coordinates: ephemCoordinates, timestamps: ephemCoordinateTimestamps)
    }

    private final func parseCoordinates(text: [String], type: EphemType)->[String] {
        switch type {
        case .OBSERVER:
            return [text[0], text[3], text[4]].map {$0.replacingOccurrences(of: " ", with: "")}
        case .ELEMENTS:
            return [String]()
        case .VECTORS:
            print("getting vectors \(text.count)")
            return [ text[0], text[1], text[2], text[3], text[4]].map {$0.replacingOccurrences(of: " ", with: "")}
        case .APPROACH:
            return [String]()
        case .SPK:
            return [String]()
        }
    }
    
}

