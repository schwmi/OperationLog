import CryptoKit
import Foundation


// MARK: - Protocols

/// Transformable to Data
public protocol Serializable {
    func serialize() throws -> Data
    static func deserialize(fromData data: Data) throws -> Self
}

/// Operation which can be stored in the log
public protocol LogOperationProtocol: Serializable {
    var description: String? { get }
}

/// Reduced form of n operations at a given point in time
public protocol SnapshotProtocol: Serializable {
    associatedtype Operation: LogOperationProtocol

    func applying(_ operation: Operation) -> (snapshot: Self, outcome: Outcome<Operation>)

    static func makeEmptySnapshot() -> Self
}

public typealias Identifier = Comparable & Hashable & Codable

/// Holds a vector clock sorted array of operations, and a provides a snapshot as representation of all applied operations
///
/// Terminology:
///    - Operation … Used to modify a snapshot
///    - LoggedOperation … Wraps an operation which is already applied (has additional meta data, like timestamp)
///    - Snapshot … State at a given point in time, where all operations are reduced into
public struct OperationLog<LogID: Identifier, ActorID: Identifier, LogSnapshot: SnapshotProtocol> {

    public typealias Sha256Data = Data
    public typealias Operation = LogSnapshot.Operation

    public struct BaseSnapshot {
        public let snapshot: LogSnapshot
        public let sha256: Sha256Data
        public let clock: VectorClock<ActorID>?

        public init(snapshot: LogSnapshot, sha256: Sha256Data, clock: VectorClock<ActorID>?) {
            self.snapshot = snapshot
            // We keep track of a sha256 hash which is calculated in the sorted operation list via SHA256(formerHASH, Operation_i.uuid).
            // Initial starting point is taken from the BaseSnapshot struct. For an empty log this starts with (0,0,0,0,…0).
            self.sha256 = sha256
            self.clock = clock
        }
    }

    /// Wraps operations with timestamp and actor information when applied to the log
    public struct LoggedOperation {
        public let id: UUID
        public let actor: ActorID
        public let clock: VectorClock<ActorID>
        public let operation: Operation

        public init(id: UUID = UUID(), actor: ActorID, clock: VectorClock<ActorID>, operation: Operation) {
            self.id = id
            self.actor = actor
            self.clock = clock
            self.operation = operation
        }
    }

    /// Wraps on operation on the undo/redo stack
    public struct UndoOperationContainer {
        /// The ID of the operation which is reverted with this undo operation
        public let revertingOperationID: UUID
        /// The operation which is applied when triggering undo/redo
        public let operation: Operation
    }

    private var clockProvider: ClockProvider<ActorID>
    private var baseSnapshot: BaseSnapshot
    private var initialSummary: Summary

    // MARK: - Properties

    /// ID of the operation log
    public let logID: LogID
    /// ID of the actor which operates on the log instance - used for generating timestamps
    public let actorID: ActorID
    /// Current result when reducing all operations within the log
    public private(set) var snapshot: LogSnapshot
    /// Summary information about all applied operations
    public private(set) var summary: Summary
    /// Applied Operations, clock sorted
    public private(set) var operations: [LoggedOperation] = []
    public var canUndo: Bool { self.undoStack.isEmpty == false }
    public var canRedo: Bool { self.redoStack.isEmpty == false }
    private(set) public var redoStack: [UndoOperationContainer] = []
    private(set) public var undoStack: [UndoOperationContainer] = []

    // MARK: - Lifecycle

    /// Initializes a new OperationLog
    /// - Parameters:
    ///   - logID: Unambiguously identifies a log, can be used to check if two OperationLogs can be merged
    ///   - actorID: The actorID which is used for new timestamps when applying new operations
    public init(logID: LogID, actorID: ActorID) {
        let emptySnapshot = LogSnapshot.makeEmptySnapshot()
        precondition(emptySnapshot is AnyClass == false, "Snapshot must be a value type")
        self.actorID = actorID
        self.clockProvider = .init(actorID: actorID, vectorClock: .init(actorID: actorID))

        self.baseSnapshot = .init(snapshot: emptySnapshot,
                                  sha256: .emptySizedLikeSHA256Hash,
                                  clock: nil)
        self.snapshot = baseSnapshot.snapshot
        let summary: Summary = .init(actors: [actorID],
                                     latestClock: .init(actorID: actorID),
                                     operationCount: 0,
                                     operationInfos: [])
        self.initialSummary = summary
        self.summary = summary
        self.logID = logID
    }

    /// Initializes a OperationLog from a serialized form
    /// - Parameters:
    ///   - actorID: The actorID which is used for new timestamps when applying new operations
    ///   - data: The serialized data of the log
    /// - Throws: if decoding of data fails
    public init(actorID: ActorID, data: Data) throws {
        let container = try JSONDecoder().decode(Container.self, from: data)
        precondition(container.operations.isSorted(isOrderedBefore: { $0.clock.isOlderInTotalOrder(than: $1.clock) }), "Operations should be persisted in a sorted state")
        self.actorID = actorID
        let clock = container.operations.last?.clock ?? container.baseSnapshot.clock ?? .init(actorID: actorID)
        self.clockProvider = .init(actorID: actorID, vectorClock: clock)
        self.operations = container.operations
        self.baseSnapshot = container.baseSnapshot
        self.snapshot = container.baseSnapshot.snapshot
        self.initialSummary = container.summary
        self.summary = container.summary
        self.logID = container.logID

        self.recalculateMostRecentSnapshot()
    }

    // MARK: - OperationLog

    /// Merge another operation log into the current one
    /// - Parameter operationLog: The log which should be merged
    public mutating func merge(_ operationLog: OperationLog) throws {
        guard self.logID == operationLog.logID else { throw Error.nonMatchingLogIDs }

        var otherLog = operationLog
        if self.baseSnapshot.sha256 != operationLog.baseSnapshot.sha256 {
            if self.initialSummary.latestClock.isNewerInTotalOrder(than: otherLog.initialSummary.latestClock) {
                try otherLog.reduce(until: self.baseSnapshot.sha256)
            } else {
                var copy = self
                // We ensure that we also have the same history (but do not reduce the operations here).
                try copy.reduce(until: otherLog.baseSnapshot.sha256)
            }
        }

        try self.insert(otherLog.operations)
    }

    /// Append a new operation onto the log, the operation is wrapped into a container and a new timestamp is created
    /// - Parameter operation: The operation which should be added
    public mutating func append(_ operation: Operation) {
        if let result = self.applyOperationToSnapshot(operation) {
            self.undoStack.append(.init(revertingOperationID: result.loggedOperation.id, operation: result.undoOperation))
        }
    }

    /// Insert an array of LoggedOperation into a log - normally those are operations which where added into another log and are now
    /// synced to the current log
    /// - Parameter operations: The LoggedOperations which should be added
    public mutating func insert(_ operations: [LoggedOperation]) throws {
        let sortedInsertOperations = operations.sorted(by: { $0.clock.isNewerInTotalOrder(than: $1.clock) })
        guard let latestClockInserted = sortedInsertOperations.first?.clock else { return }
        guard let earliestClockInserted = sortedInsertOperations.last?.clock else { return }
        guard earliestClockInserted.isNewerInTotalOrder(than: self.initialSummary.latestClock) else { throw Error.mergeNotPossible }

        self.clockProvider.merge(latestClockInserted)

        if self.operations.isEmpty {
            self.operations = Array(sortedInsertOperations.reversed())
        } else {
            var resultingArray = self.operations
            // Add operations to existing an array in a sorted manner, search insert positions from end
            // as we assume that operations are more probable to be inserted at the end (later in time).
            var searchStartIndex = self.operations.count - 1
            for operation in sortedInsertOperations {
                for index in stride(from: searchStartIndex, through: 0, by: -1) {
                    let currentOperation = self.operations[index]
                    if currentOperation.id == operation.id {
                        searchStartIndex = index
                        break
                    } else if currentOperation.clock.isOlderInTotalOrder(than: operation.clock) {
                        resultingArray.insert(operation, at: index + 1)
                        searchStartIndex = index
                        break
                    } else if index == 0 {
                        resultingArray.insert(operation, at: 0)
                        searchStartIndex = index
                        break
                    }
                }
            }
            // if the count hasn't changed, the merge was a no-op (same operations)
            guard self.operations.count != resultingArray.count else { return }

            self.operations = resultingArray
        }

        self.recalculateMostRecentSnapshot()
    }

    /// Appends a new operation which undo's the last applied operation
    public mutating func undo() {
        guard self.undoStack.isEmpty == false else { return }

        if let result = self.applyOperationToSnapshot(self.undoStack.removeLast().operation) {
            self.redoStack.append(.init(revertingOperationID: result.loggedOperation.id, operation: result.undoOperation))
        }
    }

    /// Appends a new operation which redo's the last undone operation
    public mutating func redo() {
        guard self.redoStack.isEmpty == false else { return }

        if let result = self.applyOperationToSnapshot(self.redoStack.removeLast().operation) {
            self.undoStack.append(.init(revertingOperationID: result.loggedOperation.id, operation: result.undoOperation))
        }
    }

    /// Creates a data representation of the log which can be stored and later
    /// used in init(actorID: ActorID, data: Data) for initializing a log
    public func serialize() throws -> Data {
        let container = Container(logID: self.logID,
                                  baseSnapshot: self.baseSnapshot,
                                  operations: self.operations,
                                  summary: self.initialSummary)
        return try JSONEncoder().encode(container)
    }
}

// MARK: - Log Reducing

public extension OperationLog {

    enum Error: Swift.Error {
        case reduceNotPossible
        case mergeNotPossible
        case nonMatchingLogIDs
    }

    mutating func reduce(until operationID: UUID) throws {
        try self.reduce(until: { operation, _ in operation.id == operationID })
    }

    mutating func reduce(until targetHash: Sha256Data) throws {
        try self.reduce(until: { _, hash in hash == targetHash })
    }

    mutating func reduce(until condition: (LoggedOperation, Sha256Data) -> Bool) throws {
        var baseSnapshot = self.baseSnapshot.snapshot
        var initialSummary = self.initialSummary
        var formerHash = self.baseSnapshot.sha256
        var cutoffIndex: Int?
        print("Initial \(Array(self.baseSnapshot.sha256))")
        var lastClock: VectorClock<ActorID>?
        for (index, loggedOperation) in self.operations.enumerated() {
            print("Reduce operation \(loggedOperation.id) into hash")
            let (snapshot, outcome) = baseSnapshot.applying(loggedOperation.operation)
            baseSnapshot = snapshot
            initialSummary.apply(loggedOperation, outcome: outcome)
            var sha256 = SHA256()
            sha256.update(data: formerHash)
            sha256.update(data: loggedOperation.id.data)
            let currentHash = Data(sha256.finalize())
            formerHash = currentHash
            lastClock = loggedOperation.clock
            if condition(loggedOperation, currentHash) {
                cutoffIndex = index
                break
            }
        }
        guard let cutoffIndex = cutoffIndex else { throw Error.reduceNotPossible }

        let newStartIndex = cutoffIndex + 1
        self.initialSummary = initialSummary
        if newStartIndex >= self.operations.count {
            self.operations = []
        } else {
            self.operations = Array(self.operations.suffix(from: cutoffIndex + 1))
        }
        self.baseSnapshot = .init(snapshot: baseSnapshot, sha256: formerHash, clock: lastClock ?? .init(actorID: self.actorID))
        self.recalculateMostRecentSnapshot()
    }
}

// MARK: - Outcome

/// Possible outcomes after applying an operation
public enum Outcome<Operation: LogOperationProtocol> {
    case fullApplied(undoOperation: Operation)
    case partialApplied(undoOperation: Operation, reason: String)
    case skipped(reason: String)
}

// MARK: - OperationLog: Serialization

extension OperationLog {

    /// Container used for serialization purposes
    private struct Container: Codable {

        let logID: LogID
        let baseSnapshot: BaseSnapshot
        let summary: Summary
        let operations: [LoggedOperation]

        enum CodingKeys: String, CodingKey {
            case operations
            case baseSnapshot
            case initialSha256
            case initialClock
            case summary
            case logID
        }

        init(logID: LogID, baseSnapshot: BaseSnapshot, operations: [LoggedOperation], summary: Summary) {
            self.baseSnapshot = baseSnapshot
            self.operations = operations
            self.summary = summary
            self.logID = logID
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let snapshotData = try container.decode(Data.self, forKey: .baseSnapshot)
            let logID = try container.decode(LogID.self, forKey: .logID)
            let initialSha256 = try container.decodeIfPresent(Data.self, forKey: .initialSha256) ?? .emptySizedLikeSHA256Hash
            let initialClock = try container.decodeIfPresent(VectorClock<ActorID>.self, forKey: .initialClock)
            self.summary = try container.decode(Summary.self, forKey: .summary)
            self.baseSnapshot = .init(snapshot: try LogSnapshot.deserialize(fromData: snapshotData),
                                      sha256: initialSha256,
                                      clock: initialClock)
            self.operations = try container.decode([LoggedOperation].self, forKey: .operations)
            self.logID = logID
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.operations, forKey: .operations)
            try container.encode(self.summary, forKey: .summary)
            let snapshotData = try self.baseSnapshot.snapshot.serialize()
            try container.encode(snapshotData, forKey: .baseSnapshot)
            try container.encode(self.baseSnapshot.sha256, forKey: .initialSha256)
            try container.encode(self.logID, forKey: .logID)
            try container.encode(self.baseSnapshot.clock, forKey: .initialClock)
        }
    }
}

// MARK: LoggedOperation: Codable

extension OperationLog.LoggedOperation: Codable {

    enum CodingKeys: String, CodingKey {
        case uuid
        case actor
        case clock
        case operation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let uuid = try container.decode(UUID.self, forKey: .uuid)
        let actor = try container.decode(ActorID.self, forKey: .actor)
        let clock = try container.decode(VectorClock<ActorID>.self, forKey: .clock)
        let operationData = try container.decode(Data.self, forKey: .operation)
        let operation = try OperationLog.Operation.deserialize(fromData: operationData)

        self.init(id: uuid, actor: actor, clock: clock, operation: operation)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.id, forKey: .uuid)
        try container.encode(self.actor, forKey: .actor)
        try container.encode(self.clock, forKey: .clock)
        let operationData = try self.operation.serialize()
        try container.encode(operationData, forKey: .operation)
    }
}

// MARK: LoggedOperation: Hashable, Equatable

extension OperationLog.LoggedOperation: Equatable, Hashable {

    public static func == (lhs: Self, rhs: Self) -> Bool {
        return lhs.clock == rhs.clock
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.clock)
    }
}

// MARK: - Private

private extension OperationLog {

    /// Recalculates the most recent snapshot by applying all operations onto the initial snapshot
    mutating func recalculateMostRecentSnapshot() {
        var currentSnapshot = self.baseSnapshot.snapshot
        var currentSummary = self.initialSummary
        var currentUndoStack: [UndoOperationContainer] = []
        for operation in self.operations {
            let (snapshot, outcome) = currentSnapshot.applying(operation.operation)
            currentSnapshot = snapshot
            currentSummary.apply(operation, outcome: outcome)
            switch outcome {
            case .fullApplied(let undoOperation), .partialApplied(let undoOperation, _):
                currentUndoStack.append(.init(revertingOperationID: operation.id, operation: undoOperation))
            case .skipped:
                break
            }
        }
        self.summary = currentSummary
        self.snapshot = currentSnapshot
        self.undoStack = currentUndoStack
        self.redoStack = []
    }

    /// Appends a new operation to the log and applies it to the most recent snapshot
    /// - Parameter operation: The operation which should be appended
    /// - Returns: The operation to undo the change
    mutating func applyOperationToSnapshot(_ operation: Operation) -> (loggedOperation: LoggedOperation, undoOperation: Operation)? {
        let loggedOperation: LoggedOperation = .init(actor: self.actorID,
                                                     clock: self.clockProvider.next(),
                                                     operation: operation)
        self.operations.append(loggedOperation)
        let (newSnapshot, outcome) = self.snapshot.applying(operation)
        self.snapshot = newSnapshot
        self.summary.apply(loggedOperation, outcome: outcome)
        switch outcome {
        case .fullApplied(let undoOperation), .partialApplied(let undoOperation, _):
            return (loggedOperation, undoOperation)
        case .skipped:
            return nil
        }
    }
}

private extension Array {

    func isSorted(isOrderedBefore: (Element, Element) -> Bool) -> Bool {
        guard self.isEmpty == false else { return true }

        for i in 1..<self.count {
            if isOrderedBefore(self[i-1], self[i]) == false {
                return false
            }
        }
        return true
    }
}

private extension UUID {

    var data: Data {
        let (u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15,u16) = self.uuid
        let uuidBytes = [u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15,u16]
        return .init(uuidBytes)
    }
}

private extension Data {

    static let emptySizedLikeSHA256Hash = Data(count: 32)
}

private extension VectorClock {

    func isNewerInTotalOrder(than other: VectorClock) -> Bool {
        return self.totalOrder(other: other) == .descending
    }

    func isOlderInTotalOrder(than other: VectorClock) -> Bool {
        return self.totalOrder(other: other) == .ascending
    }
}
