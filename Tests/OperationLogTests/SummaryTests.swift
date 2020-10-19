import XCTest
import VectorClock
@testable import OperationLog


final class SummaryTests: XCTestCase {

    func testSummaryConstruction() throws {
        var logA = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: "Result: "))
        var logB = OperationLog<String, StringSnapshot>(actorID: "B", initialSnapshot: .init(string: "Result: "))
        try logB.append(.init(kind: .append, character: "X"))
        try logA.append(.init(kind: .append, character: "A"))
        try logA.append(.init(kind: .append, character: "B"))
        try logA.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(logA.summary.actors, ["A"])
        XCTAssertEqual(logA.summary.operationCount, 3)

        try logA.merge(logB)
        XCTAssertEqual(logA.summary.actors, ["A", "B"])
        XCTAssertEqual(logA.summary.operationCount, 4)
        XCTAssertEqual(logA.summary.operationIDs.count, 4)
    }
}
