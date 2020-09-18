import Foundation
import VectorClock


/// Operation which can be stored in the log
public protocol LogOperation {

    associatedtype SnapshotType: Snapshot

    var description: String? { get }
    func apply(to snapshot: SnapshotType) -> SnapshotType
    func serialize() throws -> Data
    func reverted() -> Self
}

/// Reduced form of n operations at a given point in time
public protocol Snapshot {
    func serialize() throws -> Data
}


/// Holds a vector clock sorted array of operations
public struct OperationLog<ActorID: Comparable & Hashable & Codable, Operation: LogOperation> {

    struct OperationContainer {
        let clock: VectorClock<ActorID>
        let operation: Operation
    }

    private let actorID: ActorID
    private var operations: [OperationContainer] = []
    private var currentClock: VectorClock<ActorID> {
        return operations.last?.clock ?? VectorClock(actorID: self.actorID)
    }

    // MARK: - Lifecycle

    init(actorID: ActorID) {
        self.actorID = actorID
    }

    // MARK: - OperationLog

    public mutating func append(_ operation: Operation) {
        self.operations.append(.init(clock: self.currentClock.incrementing(self.actorID), operation: operation))
    }

    public mutating func merge(_ operationLog: OperationLog) {
        let allOperations = Set(operationLog.operations + self.operations)
        self.operations = allOperations.sorted(by: { $0.clock < $1.clock })
    }

    public func reduce(into snapshot: Operation.SnapshotType) -> Operation.SnapshotType {
        return self.operations.reduce(snapshot, { $1.operation.apply(to: $0) } )
    }
}

// MARK: OperationContainer: Hashable, Equatable

extension OperationLog.OperationContainer: Equatable, Hashable {

    static func == (lhs: OperationLog<ActorID, Operation>.OperationContainer, rhs: OperationLog<ActorID, Operation>.OperationContainer) -> Bool {
        return lhs.clock == rhs.clock
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(self.clock)
    }
}
