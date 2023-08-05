import XCTest
@testable import SwiftHorizons

final class SwiftHorizonsTests: XCTestCase {
    private let horizonSystem = SwiftHorizons()
    
    func testSingleTargetObserverMb() throws {
        
        let objectID = "599"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(id: objectID, type: .Mb)
        horizonSystem.getTarget(object: object, type: .OBSERVER) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetVectorMb() throws {
        
        let objectID = "599"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(id: objectID, type: .Mb)
        horizonSystem.getTarget(object: object, type: .VECTORS) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetObserverSb() throws {
        
        let objectID = "647/2000647"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(id: objectID, type: .Sb)
        horizonSystem.getTarget(object: object, type: .OBSERVER) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetVectorSb() throws {
        
        let objectID = "647/2000647"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(id: objectID, type: .Sb)
        horizonSystem.getTarget(object: object, type: .VECTORS) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleObserverParse() {
        let path = URL(fileURLWithPath: Bundle.module.path(forResource: "testObserver", ofType: "json")!)
        do {
            let text = try String(contentsOf: path)
            let target = horizonSystem.parseSingleTarget(id: "499", parameters: [String: String](), text: text, type: .OBSERVER)
            XCTAssert(target.id == "499")
        } catch let error {
            print(String(describing: error.localizedDescription))
        }
    }

    func testSingleVectorParse() {
        let path = URL(fileURLWithPath: Bundle.module.path(forResource: "testVector", ofType: "json")!)
        do {
            let text = try String(contentsOf: path)
            let target = horizonSystem.parseSingleTarget(id: "499", parameters: [String: String](), text: text, type: .VECTORS)
            XCTAssert(target.id == "499")
        } catch let error {
            print(String(describing: error.localizedDescription))
        }
    }

    fileprivate func rectifyDate(_ output: String)->String{
        var result = ""
        do{
            let pattern = try NSRegularExpression(pattern: "[0-9]+-[A-Za-z]+-[0-9]+ [0-9]+:[0-9]+", options: [])
            let match = pattern.firstMatch(in: output, options: [], range: NSRange(location: 0, length: output.count))?.range
            result = String(output[Range(match!, in: output)!])
        }catch{
            print("Error getting regular expression")
        }
        let dateFormat = DateFormatter()
        dateFormat.locale = Locale(identifier: "en_US_POSIX")
        dateFormat.timeZone = TimeZone(abbreviation: "UTC")
        dateFormat.dateFormat = "yyyy-MMM-dd HH:mm"
        let TimeNow = dateFormat.date(from: result)!
        let previous = Calendar.current.date(byAdding: .minute, value: -1, to: TimeNow)!
        let prev = dateFormat.string(from: previous)
        
        // check if date is in the future
        guard Date().timeIntervalSince(TimeNow) > 0 else {
            return "FUTURE"
        }
        return prev + ";" + result
    }

}
