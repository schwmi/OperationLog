import Foundation
import VectorClock


/// Transformable to Data
public protocol Serializable {
    func serialize() throws -> Data
    static func deserialize(fromData data: Data) throws -> Self
}

/// Operation which can be stored in the log
public protocol LogOperation: Serializable {
    associatedtype SnapshotType: Snapshot

    var description: String? { get }
    func apply(to snapshot: SnapshotType) -> SnapshotType
    func reverted() -> Self
    func serialize() throws -> Data
    static func deserialize(fromData data: Data) throws -> Self
}

/// Reduced form of n operations at a given point in time
public protocol Snapshot: Serializable {
}


/// Holds a vector clock sorted array of operations
public struct OperationLog<ActorID: Comparable & Hashable & Codable, Operation: LogOperation> {

    public struct OperationContainer {
        let id: UUID = UUID()
        let actor: ActorID
        let clock: VectorClock<ActorID>
        let operation: Operation
    }

    private var operations: [OperationContainer] = []
    private var clockProvider: ClockProvider<ActorID>

    // MARK: - Properties

    let actorID: ActorID

    // MARK: - Lifecycle

    init(actorID: ActorID) {
        self.actorID = actorID
        self.clockProvider = .init(actorID: actorID, vectorClock: .init(actorID: actorID))
    }

    // MARK: - OperationLog

    func logDescriptions(limit: Int) -> [String] {
        return self.operations.suffix(limit).map { $0.operation.description ?? " - no description - " }
    }

    public mutating func append(_ operation: Operation) {
        self.operations.append(.init(actor: self.actorID,
                                     clock: self.clockProvider.next(),
                                     operation: operation))
    }

    public mutating func merge(_ operationLog: OperationLog) {
        self.insert(operationLog.operations)
    }

    public func reduce(into snapshot: Operation.SnapshotType) -> Operation.SnapshotType {
        return self.operations.reduce(snapshot, { $1.operation.apply(to: $0) } )
    }

    public mutating func insert(_ operations: [OperationContainer]) {
        guard let maxClock = operations.max(by: { $0.clock < $1.clock })?.clock else { return }

        self.clockProvider.merge(maxClock)
        let allOperations = Set(operations + self.operations)
        self.operations = allOperations.sorted(by: { $0.clock < $1.clock })
    }
}

// MARK: OperationContainer: Hashable, Equatable

extension OperationLog.OperationContainer: Equatable, Hashable {

    public static func == (lhs: OperationLog<ActorID, Operation>.OperationContainer, rhs: OperationLog<ActorID, Operation>.OperationContainer) -> Bool {
        return lhs.clock == rhs.clock
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(self.clock)
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
