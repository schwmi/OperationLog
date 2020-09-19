import XCTest
import VectorClock
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

    func testLogDescription() {
        var log = OperationLog<String, CharacterOperation>(actorID: "A")
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .removeLast, character: "C"))
        XCTAssertEqual(log.logDescriptions(limit: 2), ["Append character: B", "removeLast character: C"])
    }

    func testLogMerging() {
        var logA = OperationLog<String, CharacterOperation>(actorID: "A")
        var logB = OperationLog<String, CharacterOperation>(actorID: "B")
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "A"))
        logB.append(.init(kind: .append, character: "B"))
        logB.merge(logA)
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "A"))
        logB.merge(logA)
        logA.append(.init(kind: .append, character: "A"))
        logB.append(.init(kind: .append, character: "B"))
        logA.merge(logB)
        logB.append(.init(kind: .append, character: "B"))
        logB.append(.init(kind: .append, character: "B"))
        logA.merge(logB)
        logB.merge(logA)
        let resultA = logA.reduce(into: .init(string: ""))
        let resultB = logB.reduce(into: .init(string: ""))
        print(logA.currentClock)
        XCTAssertEqual(resultA.string, resultB.string)
        XCTAssertEqual(resultA.string, "AAABAAABBB")
    }
}
