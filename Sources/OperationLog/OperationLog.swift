import Foundation
import VectorClock


struct OperationLog<ActorID: Comparable & Hashable & Codable, Operation: OperationProtocol> {

    struct OperationContainer: Equatable, Hashable {

        static func == (lhs: OperationLog<ActorID, Operation>.OperationContainer, rhs: OperationLog<ActorID, Operation>.OperationContainer) -> Bool {
            return lhs.clock == rhs.clock
        }

        func hash(into hasher: inout Hasher) {
            hasher.combine(self.clock)
        }

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

    mutating func append(_ operation: Operation) {
        self.operations.append(.init(clock: self.currentClock.incrementing(self.actorID),
                                     operation: operation))
    }

    mutating func merge(_ operationLog: OperationLog) {
        let allOperations = Set(operationLog.operations + self.operations)
        self.operations = allOperations.sorted(by: { $0.clock < $1.clock })
    }
}

public protocol OperationProtocol {

    associatedtype SnapshotType: Snapshot

    var description: String? { get }
    func apply(to snapshot: SnapshotType) -> SnapshotType
    func serialize() -> Data
    func reverted() -> Self
}

public protocol Snapshot {
    func serialize() -> Data
}
