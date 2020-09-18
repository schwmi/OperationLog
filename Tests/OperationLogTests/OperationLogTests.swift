import XCTest
@testable import OperationLog


final class OperationLogTests: XCTestCase {

    func testAddingOperation() {
        var log = OperationLog<String, CharacterOperation>(actorID: "A")
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        let snapshot = StringSnapshot(string: "Result: ")
        let result = log.reduce(into: snapshot)
        XCTAssertEqual(result.string, "Result: ABC")
    }
}
