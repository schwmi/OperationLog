import XCTest
import VectorClock
@testable import OperationLog


final class OperationLogTests: XCTestCase {

    func testAddingOperation() throws {
        var log = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: "Result: "))
        try log.append(.init(kind: .append, character: "A"))
        try log.append(.init(kind: .append, character: "B"))
        try log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "Result: ABC")
    }

    func testLogDescription() throws {
        var log = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: ""))
        try log.append(.init(kind: .append, character: "A"))
        try log.append(.init(kind: .append, character: "B"))
        try log.append(.init(kind: .removeLast, character: "B"))
        XCTAssertEqual(log.logDescriptions(limit: 2), ["Append character: B", "removeLast character: B"])
    }

    func testLogMerging() throws {
        var logA = OperationLog<String, StringSnapshot>(actorID: "A", initialSnapshot: .init(string: ""))
        var logB = OperationLog<String, StringSnapshot>(actorID: "B", initialSnapshot: .init(string: ""))
        try logA.append(.init(kind: .append, character: "A"))
        try logA.append(.init(kind: .append, character: "A"))
        try logA.append(.init(kind: .append, character: "A"))
        try logB.append(.init(kind: .append, character: "B"))
        try logB.merge(logA)
        try logA.append(.init(kind: .append, character: "A"))
        try logA.append(.init(kind: .append, character: "A"))
        try logB.merge(logA)
        try logA.append(.init(kind: .append, character: "A"))
        try logB.append(.init(kind: .append, character: "B"))
        try logA.merge(logB)
        try logB.append(.init(kind: .append, character: "B"))
        try logB.append(.init(kind: .append, character: "B"))
        try logA.merge(logB)
        try logB.merge(logA)
        XCTAssertEqual(logA.snapshot.string, logB.snapshot.string)
        XCTAssertEqual(logA.snapshot.string, "AAABAAABBB")
    }

    func testUndoRedo() throws {
        var log = OperationLog(actorID: "A", initialSnapshot: StringSnapshot(string: ""))
        try log.append(.init(kind: .append, character: "A"))
        try log.append(.init(kind: .append, character: "B"))
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
        try log.append(.init(kind: .append, character: "A"))
        try log.append(.init(kind: .append, character: "B"))
        try log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "ABC")

        // Encode, decode
        let data = try log.serialize()
        var decodedLog = try OperationLog<String, StringSnapshot>(actorID: "A", data: data)
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
        try decodedLog.append(.init(kind: .append, character: "X"))
        try log.append(.init(kind: .append, character: "X"))
        XCTAssertEqual(decodedLog.snapshot.string, log.snapshot.string)
    }
}
