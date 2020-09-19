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
        let actor: ActorID
        let clock: VectorClock<ActorID>
        let operation: Operation
    }

    private var operations: [OperationContainer] = []

    // MARK: - Properties

    let actorID: ActorID
    private(set) var currentClock: VectorClock<ActorID>

    // MARK: - Lifecycle

    init(actorID: ActorID) {
        self.actorID = actorID
        self.currentClock = VectorClock(actorID: self.actorID)
    }

    // MARK: - OperationLog

    func logDescriptions(limit: Int) -> [String] {
        return self.operations.suffix(limit).map { $0.operation.description ?? " - no description - " }
    }

    public mutating func append(_ operation: Operation) {
        self.currentClock = self.currentClock.incrementing(self.actorID)
        self.operations.append(.init(actor: self.actorID, clock: self.currentClock, operation: operation))
    }

    public mutating func merge(_ operationLog: OperationLog) {
        self.currentClock = self.currentClock.merging(operationLog.currentClock)
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
