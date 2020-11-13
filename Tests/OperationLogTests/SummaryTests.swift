import XCTest
@testable import OperationLog


final class SummaryTests: XCTestCase {

    func testSummaryConstruction() throws {
        var logA = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: .init(string: "Result: "))
        var logB = CharacterOperationLog(logID: "1", actorID: "B", initialSnapshot: .init(string: "Result: "))
        logB.append(.init(kind: .append, character: "X"))
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "B"))
        logA.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(logA.summary.actors, ["A"])
        XCTAssertEqual(logA.summary.operationCount, 3)

        logA.merge(logB)
        XCTAssertEqual(logA.summary.actors, ["A", "B"])
        XCTAssertEqual(logA.summary.operationCount, 4)
        XCTAssertEqual(logA.summary.operationInfos.count, 4)
    }

    func testPersistence() throws {
        var logA = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: .init(string: "Result: "))
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "B"))
        logA.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(logA.summary.actors, ["A"])
        XCTAssertEqual(logA.summary.operationCount, 3)

        let data = try logA.serialize()
        let deserializedA = try CharacterOperationLog(actorID: "A", data: data)
        XCTAssertEqual(deserializedA.summary.actors, ["A"])
        XCTAssertEqual(deserializedA.summary.operationCount, 3)
    }
}
