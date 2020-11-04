import Foundation
import VectorClock


/// Transformable to Data
public protocol Serializable {
    func serialize() throws -> Data
    static func deserialize(fromData data: Data) throws -> Self
}

/// Operation which can be stored in the log
public protocol LogOperation: Serializable {
    var description: String? { get }
    func serialize() throws -> Data
    static func deserialize(fromData data: Data) throws -> Self
}

/// Reduced form of n operations at a given point in time
public protocol Snapshot: Serializable {
    associatedtype Operation: LogOperation

    func applying(_ operation: Operation) -> (snapshot: Self, outcome: Outcome<Operation>)
}

/// Possible outcomes after applying an operaton onto a snapshot
public enum Outcome<Operation: LogOperation> {
    case fullApplied(undoOperation: Operation)
    case partialApplied(undoOperation: Operation, reason: String)
    case skipped(reason: String)
}

/// Holds a vector clock sorted array of operations
public struct OperationLog<ActorID: Comparable & Hashable & Codable, LogSnapshot: Snapshot> {

    public typealias Operation = LogSnapshot.Operation

    public struct OperationContainer {
        let id: UUID
        let actor: ActorID
        let clock: VectorClock<ActorID>
        let operation: Operation

        init(id: UUID = UUID(), actor: ActorID, clock: VectorClock<ActorID>, operation: Operation) {
            self.id = id
            self.actor = actor
            self.clock = clock
            self.operation = operation
        }
    }

    private var redoStack: [Operation] = []
    private var undoStack: [Operation] = []
    private var operations: [OperationContainer] = []
    private var clockProvider: ClockProvider<ActorID>
    private var initialSnapshot: LogSnapshot
    private var initialSummary: Summary

    // MARK: - Properties

    public let actorID: ActorID
    public private(set) var snapshot: LogSnapshot
    public private(set) var summary: Summary

    // MARK: - Lifecycle

    public init(actorID: ActorID, initialSnapshot: LogSnapshot) {
        precondition(initialSnapshot is AnyClass == false, "Snapshot must be a value type")
        self.actorID = actorID
        self.clockProvider = .init(actorID: actorID, vectorClock: .init(actorID: actorID))
        self.initialSnapshot = initialSnapshot
        self.snapshot = initialSnapshot
        let summary: Summary = .init(actors: [actorID],
                                     latestClock: .init(actorID: actorID),
                                     operationCount: 0,
                                     operationIDs: [])
        self.initialSummary = summary
        self.summary = summary
    }

    public init(actorID: ActorID, data: Data) throws {
        let container = try JSONDecoder().decode(Container.self, from: data)
        self.actorID = actorID
        let clock = container.operations.last?.clock ?? .init(actorID: actorID)
        self.clockProvider = .init(actorID: actorID, vectorClock: clock)
        self.operations = container.operations
        self.initialSnapshot = container.initialSnapshot
        self.snapshot = container.initialSnapshot
        self.initialSummary = container.summary
        self.summary = container.summary

        try self.recalculateMostRecentSnapshot()
    }

    // MARK: - OperationLog

    func logDescriptions(limit: Int) -> [String] {
        return self.operations.suffix(limit).map { $0.operation.description ?? " - no description - " }
    }

    public mutating func merge(_ operationLog: OperationLog) throws {
        try self.insert(operationLog.operations)
    }

    public mutating func append(_ operation: Operation) throws {
        if let reverseOperation = self.appendOperationToSnapshot(operation) {
            self.undoStack.append(reverseOperation)
        }
    }

    public mutating func insert(_ operations: [OperationContainer]) throws {
        guard let maxClock = operations.max(by: { $0.clock < $1.clock })?.clock else { return }

        self.clockProvider.merge(maxClock)
        // Improve for better performance
        let allOperations = Set(operations + self.operations)
        self.operations = allOperations.sorted(by: { $0.clock < $1.clock })
        try self.recalculateMostRecentSnapshot()
    }

    public mutating func undo() {
        guard self.undoStack.isEmpty == false else { return }

        if let reverseOperation = self.appendOperationToSnapshot(self.undoStack.removeLast()) {
            self.redoStack.append(reverseOperation)
        }
    }

    public mutating func redo() {
        guard self.redoStack.isEmpty == false else { return }

        if let reverseOperation = self.appendOperationToSnapshot(self.redoStack.removeLast()) {
            self.undoStack.append(reverseOperation)
        }
    }

    public func serialize() throws -> Data {
        let container = Container(initialSnapshot: self.initialSnapshot,
                                  operations: self.operations,
                                  summary: self.summary)
        return try JSONEncoder().encode(container)
    }
}

// MARK: - OperationLog: Serialization

extension OperationLog {

    private struct Container: Codable {

        let initialSnapshot: LogSnapshot
        let summary: Summary
        let operations: [OperationContainer]

        enum CodingKeys: String, CodingKey {
            case operations
            case initialSnapshot
            case summary
        }

        init(initialSnapshot: LogSnapshot, operations: [OperationContainer], summary: Summary) {
            self.initialSnapshot = initialSnapshot
            self.operations = operations
            self.summary = summary
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let snapshotData = try container.decode(Data.self, forKey: .initialSnapshot)
            self.summary = try container.decode(Summary.self, forKey: .summary)
            self.initialSnapshot = try LogSnapshot.deserialize(fromData: snapshotData)
            self.operations = try container.decode([OperationContainer].self, forKey: .operations)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.operations, forKey: .operations)
            try container.encode(self.summary, forKey: .summary)
            let snapshotData = try self.initialSnapshot.serialize()
            try container.encode(snapshotData, forKey: .initialSnapshot)
        }
    }
}

// MARK: OperationContainer: Codable

extension OperationLog.OperationContainer: Codable {

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

// MARK: OperationContainer: Hashable, Equatable

extension OperationLog.OperationContainer: Equatable, Hashable {

    public static func == (lhs: OperationLog<ActorID, LogSnapshot>.OperationContainer, rhs: OperationLog<ActorID, LogSnapshot>.OperationContainer) -> Bool {
        return lhs.clock == rhs.clock
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.clock)
    }
}

// MARK: - Private

private extension OperationLog {

    mutating func recalculateMostRecentSnapshot() throws {
        var currentSnapshot = self.initialSnapshot
        var currentSummary = self.initialSummary
        var currentUndoStack: [Operation] = []
        for operation in self.operations {
            let (snapshot, outcome) = currentSnapshot.applying(operation.operation)
            currentSnapshot = snapshot
            currentSummary.apply(operation, outcome: outcome)
            switch outcome {
            case .fullApplied(let undoOperation), .partialApplied(let undoOperation, _):
                currentUndoStack.append(undoOperation)
            case .skipped:
                break
            }
        }
        self.summary = currentSummary
        self.snapshot = currentSnapshot
        self.undoStack = currentUndoStack
    }

    mutating func appendOperationToSnapshot(_ operation: Operation) -> Operation? {
        let operationContainer: OperationContainer = .init(actor: self.actorID,
                                                           clock: self.clockProvider.next(),
                                                           operation: operation)
        self.operations.append(operationContainer)
        let (newSnapshot, outcome) = self.snapshot.applying(operation)
        self.snapshot = newSnapshot
        self.summary.apply(operationContainer, outcome: outcome)
        switch outcome {
        case .fullApplied(let undoOperation), .partialApplied(let undoOperation, _):
            return undoOperation
        case .skipped:
            return nil
        }
    }
}
