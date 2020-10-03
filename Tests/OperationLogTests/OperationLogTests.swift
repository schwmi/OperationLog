import XCTest
import VectorClock
@testable import OperationLog


final class OperationLogTests: XCTestCase {

    func testAddingOperation() {
        var log = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: "Result: "))
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "Result: ABC")
    }

    func testLogDescription() {
        var log = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: ""))
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .removeLast, character: "C"))
        XCTAssertEqual(log.logDescriptions(limit: 2), ["Append character: B", "removeLast character: C"])
    }

    func testLogMerging() {
        var logA = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: ""))
        var logB = OperationLog<String, StringSnapshot>(actorID: "B", initialSnapshot: .init(string: ""))
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
        XCTAssertEqual(logA.snapshot.string, logB.snapshot.string)
        XCTAssertEqual(logA.snapshot.string, "AAABAAABBB")
    }
}
