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

    func applying(_ operation: Operation) throws -> (snapshot: Self, undoOperation: Operation)
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

    // MARK: - Properties

    public let actorID: ActorID
    public private(set) var snapshot: LogSnapshot

    // MARK: - Lifecycle

    public init(actorID: ActorID, initialSnapshot: LogSnapshot) {
        precondition(initialSnapshot is AnyClass == false, "Snapshot must be a value type")
        self.actorID = actorID
        self.clockProvider = .init(actorID: actorID, vectorClock: .init(actorID: actorID))
        self.initialSnapshot = initialSnapshot
        self.snapshot = initialSnapshot
    }

    public init(actorID: ActorID, data: Data) throws {
        let container = try JSONDecoder().decode(Container.self, from: data)
        self.actorID = actorID
        let clock = container.operations.last?.clock ?? .init(actorID: actorID)
        self.clockProvider = .init(actorID: actorID, vectorClock: clock)
        self.operations = container.operations
        self.initialSnapshot = container.initialSnapshot
        self.snapshot = container.initialSnapshot

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
        let reverseOperation = try self.appendOperationToSnapshot(operation)
        self.undoStack.append(reverseOperation)
    }

    public mutating func insert(_ operations: [OperationContainer]) throws {
        guard let maxClock = operations.max(by: { $0.clock < $1.clock })?.clock else { return }

        self.clockProvider.merge(maxClock)
        // Improve for better performance
        let allOperations = Set(operations + self.operations)
        self.operations = allOperations.sorted(by: { $0.clock < $1.clock })
        try self.recalculateMostRecentSnapshot()
    }

    public mutating func undo() throws {
        guard self.undoStack.isEmpty == false else { return }

        let reverseOperation = try self.appendOperationToSnapshot(self.undoStack.removeLast())
        self.redoStack.append(reverseOperation)
    }

    public mutating func redo() throws {
        guard self.redoStack.isEmpty == false else { return }

        let reverseOperation = try self.appendOperationToSnapshot(self.redoStack.removeLast())
        self.undoStack.append(reverseOperation)
    }

    public func serialize() throws -> Data {
        let container = Container(initialSnapshot: self.initialSnapshot, operations: self.operations)
        return try JSONEncoder().encode(container)
    }
}

// MARK: - OperationLog: Serialization

extension OperationLog {

    private struct Container: Codable {

        let initialSnapshot: LogSnapshot
        let operations: [OperationContainer]

        enum CodingKeys: String, CodingKey {
            case operations
            case initialSnapshot
        }

        init(initialSnapshot: LogSnapshot, operations: [OperationContainer]) {
            self.initialSnapshot = initialSnapshot
            self.operations = operations
        }

        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let snapshotData = try container.decode(Data.self, forKey: .initialSnapshot)
            self.initialSnapshot = try LogSnapshot.deserialize(fromData: snapshotData)
            self.operations = try container.decode([OperationContainer].self, forKey: .operations)
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(self.operations, forKey: .operations)
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
        var undoStack: [Operation] = []
        for operation in self.operations {
            let (snapshot, undoOperation) = try currentSnapshot.applying(operation.operation)
            currentSnapshot = snapshot
            undoStack.append(undoOperation)
        }
        self.snapshot = currentSnapshot
        self.undoStack = undoStack
    }

    mutating func appendOperationToSnapshot(_ operation: Operation) throws -> Operation {
        self.operations.append(.init(actor: self.actorID,
                                     clock: self.clockProvider.next(),
                                     operation: operation))
        let (newSnapshot, reverseOperation) = try self.snapshot.applying(operation)
        self.snapshot = newSnapshot
        return reverseOperation
    }
}

// MARK: - ClockProvider

private struct ClockProvider<ActorID: Comparable & Hashable & Codable> {

    private var actorID: ActorID
    private var currentClock: VectorClock<ActorID>

    // MARK: - Lifecycle

    init(actorID: ActorID, vectorClock: VectorClock<ActorID>) {
        self.currentClock = vectorClock
        self.actorID = actorID
    }

    // MARK: - ClockProvider

    mutating func next() -> VectorClock<ActorID> {
        self.currentClock = self.currentClock.incrementing(self.actorID)
        return self.currentClock
    }

    mutating func merge(_ clockProvider: ClockProvider<ActorID>) {
        self.currentClock = self.currentClock.merging(clockProvider.currentClock)
    }

    mutating func merge(_ clock: VectorClock<ActorID>) {
        self.currentClock = self.currentClock.merging(clock)
    }
}
