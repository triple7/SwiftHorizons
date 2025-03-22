import XCTest
@testable import SwiftHorizons

final class SwiftHorizonsTests: XCTestCase {
    private let horizonSystem = SwiftHorizons()
    
    func testSingleTargetObserverMb() throws {
        
        let objectID = "599"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(name: "Jupiter", id: objectID, type: .Mb, objectType: "Planet", parent: "Sol")
        horizonSystem.getTarget(object: object, type: .OBSERVER) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetVectorMb() throws {
        
        let objectID = "599"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(name: "Jupiter", id: objectID, type: .Mb, objectType: "planet", parent: "Sol")
        horizonSystem.getTarget(object: object, type: .VECTORS) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetObserverSb() throws {
        
        let objectID = "647/2000647"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(name: "Some moon", id: objectID, type: .Sb, objectType: "NaturalSat", parent: "Saturn")
        horizonSystem.getTarget(object: object, type: .OBSERVER) { result in
            XCTAssert(result, "Result is unexpected")
        }
    }

    func testSingleTargetVectorSb() throws {
        
        let objectID = "647/2000647"
        print("Object ID is \(objectID)")
        let object = HorizonsBatchObject(name: "Some moon", id: objectID, type: .Sb, objectType: "NaturalSat", parent: "Saturn")
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

}
