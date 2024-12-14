//
//  File.swift
//  
//
//  Created by Yuma decaux on 17/4/2022.
//

import Foundation
import simd

extension SwiftHorizons {
    
    func parseSingleTarget(id: String, parameters: [String: String], text: String, type: EphemType, _ notify: Bool = false)->HorizonsTarget {
        print("parse target")
        let result = try! JSONDecoder().decode(HorizonsReturnJson.self, from: text.data(using: .utf8)!).result
        let asteriskDelimitor = "\n*******************************************************************************\n"
        let format = result.components(separatedBy: asteriskDelimitor)
        print(format)
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
            print("getting vectors")
            let start = text.components(separatedBy: "SOE\n").last!
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
        print("getting coordinate vectors")
        var coordinateBlock = soe.components(separatedBy: "\n")
        print("coordinate block: \n\(coordinateBlock)")
        coordinateBlock.removeFirst()
        coordinateBlock.removeLast()
        var ephemerus = [String: [Double]]()
        for c in coordinateBlock {
            var coordinates = parseCoordinates(text: c.components(separatedBy: ","), type: type)
             let timeCode = coordinates.removeFirst()
            ephemerus[timeCode] = coordinates.map {Double($0)!}
        }
        return HorizonsTarget(id: id, parameters: parameters, properties: [String]()/* temporary */, ephemerus: ephemerus)
    }

    private final func parseCoordinates(text: [String], type: EphemType)->[String] {
        switch type {
        case .OBSERVER:
            return [text[0], text[3], text[4]].map {$0.replacingOccurrences(of: " ", with: "")}
        case .ELEMENTS:
            return [String]()
        case .VECTORS:
            return [text[1], text[2], text[3], text[4]].map {$0.replacingOccurrences(of: " ", with: "")}
        case .APPROACH:
            return [String]()
        case .SPK:
            return [String]()
        }
    }
    
}

