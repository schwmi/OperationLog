import XCTest
@testable import OperationLog

typealias CharacterOperationLog = OperationLog<String, String, StringSnapshot>

final class OperationLogTests: XCTestCase {

    func testAddingOperation() {
        var log = CharacterOperationLog(logID: "1", actorID: "A")
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "ABC")
    }

    func testLogMerging() {
        var logA = CharacterOperationLog(logID: "1", actorID: "A")
        var logB = CharacterOperationLog(logID: "1", actorID: "B")
        logA.append(.init(kind: .append, character: "A"))
        logA.append(.init(kind: .append, character: "B"))
        logA.append(.init(kind: .append, character: "C"))
        logB.append(.init(kind: .append, character: "D"))
        logB.merge(logA)
        logB.merge(logB)
        XCTAssertEqual(logB.snapshot.string, "ABCD")
        logA.append(.init(kind: .append, character: "E"))
        logA.append(.init(kind: .append, character: "F"))
        logB.merge(logA)
        logA.append(.init(kind: .append, character: "G"))
        logB.append(.init(kind: .append, character: "H"))
        logA.merge(logB)
        logB.append(.init(kind: .append, character: "I"))
        logB.append(.init(kind: .append, character: "J"))
        logA.merge(logB)
        logB.merge(logA)
        XCTAssertEqual(logA.snapshot.string, logB.snapshot.string)
        XCTAssertEqual(logA.snapshot.string, "ABCDEFGHIJ")
    }

    func testMergeNoOp() {
        var log = CharacterOperationLog(logID: "1", actorID: "A")
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.undo()
        XCTAssertTrue(log.canUndo)
        XCTAssertTrue(log.canRedo)
        log.merge(log)
        XCTAssertTrue(log.canUndo)
        XCTAssertTrue(log.canRedo)
    }

    func testUndoRedo() {
        var log = CharacterOperationLog(logID: "1", actorID: "A")
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
        XCTAssertEqual(log.operations.count, 8)
    }

    func testSerialization() throws {
        var log = CharacterOperationLog(logID: "1", actorID: "A")
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "ABC")

        // Encode, decode
        let data = try log.serialize()
        var decodedLog = try CharacterOperationLog(actorID: "A", data: data)
        XCTAssertEqual(decodedLog.snapshot.string, log.snapshot.string)
        XCTAssertEqual(decodedLog.logID, log.logID)

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

// MARK: - Reducing Tests

extension OperationLogTests {

    func testReducingLog() throws {
        // Preparation
        var log = CharacterOperationLog(logID: "1", actorID: "A")
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "ABC")
        XCTAssertEqual(log.operations.count, 3)

        // Cutoff in the middle
        do {
            var copiedLog = log
            let secondOperation = copiedLog.operations[1]
            try copiedLog.reduce(until: secondOperation.id)
            XCTAssertEqual(copiedLog.snapshot.string, log.snapshot.string)
            XCTAssertEqual(copiedLog.operations.count, 1)
        }

        // Cutoff at the end
        do {
            var copiedLog = log
            let lastOperation = copiedLog.operations[2]
            try copiedLog.reduce(until: lastOperation.id)
            XCTAssertEqual(copiedLog.snapshot.string, log.snapshot.string)
            XCTAssertEqual(copiedLog.operations.count, 0)
        }

        // Try to cutoff non-existent operation
        do {
            var copiedLog = log
            XCTAssertThrowsError(try copiedLog.reduce(until: UUID()))
        }
    }
}

// MARK: - Performance Tests

extension OperationLogTests {

    func testAddOperationPerformance() {
        var log = CharacterOperationLog(logID: "1", actorID: "A")
        self.measure {
            for _ in 1..<1000 {
                log.append(.init(kind: .append, character: "A"))
            }
        }
    }

    func testAddAndMergePerformance() {
        var logA = CharacterOperationLog(logID: "1", actorID: "A")
        var logB = CharacterOperationLog(logID: "1", actorID: "B")
        // Add operations to logA
        for _ in 1..<100 {
            logA.append(.init(kind: .append, character: "A"))
        }
        // Merge operations one by one into log b
        self.measure {
            for operation in logA.operations {
                logB.insert([operation])
            }
        }
        XCTAssertEqual(logA.snapshot.string, logB.snapshot.string)
    }
}
