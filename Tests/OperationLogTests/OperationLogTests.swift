import XCTest
@testable import OperationLog


final class OperationLogTests: XCTestCase {

    func testAddingOperation() {
        var log = OperationLog<String, CharacterOperation>(actorID: "A")
        log.append(.init(kind: .add, character: "A"))
        log.append(.init(kind: .add, character: "B"))
        log.append(.init(kind: .add, character: "C"))
        let snapshot = StringSnapshot(string: "Result: ")
        let result = log.reduce(into: snapshot)
        XCTAssertEqual(result.string, "Result: ABC")
    }
}
