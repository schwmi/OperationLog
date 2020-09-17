import Foundation
import VectorClock


struct OperationLog<ActorID: Comparable & Hashable & Codable> {

    struct OperationContainer: Equatable, Hashable {

        static func == (lhs: OperationLog<ActorID>.OperationContainer, rhs: OperationLog<ActorID>.OperationContainer) -> Bool {
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

protocol Operation {
    var description: String? { get }
    func apply(to snapshot: Snapshot) -> Snapshot
    func serialize() -> Data
    func reverted() -> Operation
}

protocol Snapshot {
    func serialize() -> Data
}
