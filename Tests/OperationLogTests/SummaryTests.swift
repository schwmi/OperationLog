import XCTest
@testable import OperationLog


final class SummaryTests: XCTestCase {

    func testSummaryConstruction() throws {
        var logA = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: "Result: "))
        var logB = OperationLog<String, StringSnapshot>(actorID: "B", initialSnapshot: .init(string: "Result: "))
        logB.append(.init(kind: .append, character: "X"))
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "B"))
        logA.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(logA.summary.actors, ["A"])
        XCTAssertEqual(logA.summary.operationCount, 3)

        logA.merge(logB)
        XCTAssertEqual(logA.summary.actors, ["A", "B"])
        XCTAssertEqual(logA.summary.operationCount, 4)
        XCTAssertEqual(logA.summary.operationsInfos.count, 4)
    }
}
