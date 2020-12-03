import XCTest
@testable import OperationLog

typealias CharacterOperationLog = OperationLog<String, String, StringSnapshot>

final class OperationLogTests: XCTestCase {

    func testAddingOperation() {
        var log = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: .init(string: "Result: "))
        log.append(.init(kind: .append, character: "A"))
        log.append(.init(kind: .append, character: "B"))
        log.append(.init(kind: .append, character: "C"))
        XCTAssertEqual(log.snapshot.string, "Result: ABC")
    }

    func testLogMerging() {
        var logA = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: .init(string: ""))
        var logB = CharacterOperationLog(logID: "1", actorID: "B", initialSnapshot: .init(string: ""))
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

    func testUndoRedo() {
        var log = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: StringSnapshot(string: ""))
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
        var log = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: StringSnapshot(string: ""))
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

// MARK: - Performance Tests

extension OperationLogTests {

    func testAddOperationPerformance() {
        var log = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: StringSnapshot(string: ""))
        self.measure {
            for _ in 1..<1000 {
                log.append(.init(kind: .append, character: "A"))
            }
        }
    }

    func testAddAndMergePerformance() {
        var logA = CharacterOperationLog(logID: "1", actorID: "A", initialSnapshot: StringSnapshot(string: ""))
        var logB = CharacterOperationLog(logID: "1", actorID: "B", initialSnapshot: StringSnapshot(string: ""))
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
