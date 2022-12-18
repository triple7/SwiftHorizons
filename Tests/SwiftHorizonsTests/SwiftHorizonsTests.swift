import XCTest
@testable import SwiftHorizons

final class SwiftHorizonsTests: XCTestCase {
    private let horizonSystem = SwiftHorizons()
    
    func testSingleTargetObserver() throws {
        
        let objectID = "599"
        print("Object ID is \(objectID)")
        horizonSystem.getTarget(objectID: objectID, type: .OBSERVER) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetVector() throws {
        
        let objectID = "599"
        print("Object ID is \(objectID)")
         horizonSystem.getTarget(objectID: objectID, type: .VECTORS) { result in
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

}
