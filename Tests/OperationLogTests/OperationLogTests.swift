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
        log.append(.init(kind: .removeLast, character: "B"))
        XCTAssertEqual(log.logDescriptions(limit: 2), ["Append character: B", "removeLast character: B"])
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

    func testUndoRedo() {
        var log = OperationLog(actorID: "A", initialSnapshot: StringSnapshot(string: ""))
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        XCTAssertEqual(log.snapshot.string, "AB")
        log.undo()
        XCTAssertEqual(log.snapshot.string, "A")
        log.redo()
        XCTAssertEqual(log.snapshot.string, "AB")
        log.undo()
        log.undo()
        log.undo() // no-op (undo queue should be empty)
        XCTAssertEqual(log.snapshot.string, "")
        log.redo()
        log.redo()
        log.redo() // no-op (redo queue should be empty)
        XCTAssertEqual(log.snapshot.string, "AB")
        XCTAssertEqual(log.logDescriptions(limit: .max).count, 8)
    }

    func testSerialization() throws {
        var log = OperationLog(actorID: "A", initialSnapshot: StringSnapshot(string: ""))
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "ABC")

        // Encode, decode
        let data = try JSONEncoder().encode(log)
        var decodedLog = try JSONDecoder().decode(OperationLog<String, StringSnapshot>.self, from: data)
        XCTAssertEqual(decodedLog.snapshot.string, log.snapshot.string)

        // Try decoded undo
        decodedLog.undo()
        log.undo()
        XCTAssertEqual(decodedLog.snapshot.string, log.snapshot.string)

        // Try decoded redo
        decodedLog.redo()
        log.redo()
        XCTAssertEqual(decodedLog.snapshot.string, log.snapshot.string)

        // Add elements to both
        decodedLog.append(.init(kind: .append, character: "X"))
        log.append(.init(kind: .append, character: "X"))
        XCTAssertEqual(decodedLog.snapshot.string, log.snapshot.string)
    }
}
