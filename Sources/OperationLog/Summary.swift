import Foundation
import VectorClock


public extension OperationLog {

    /// Summarizes information about an operation log
    struct Summary {
        public var actors: Set<ActorID>
        public var latestClock: VectorClock<ActorID>
        public var operationCount: Int
        public var operationIDs: [UUID]

        mutating func apply(_ operation: OperationContainer) {
            self.actors.insert(operation.actor)
            self.latestClock = operation.clock
            self.operationCount += 1
            self.operationIDs.append(operation.id)
        }
    }
}

// MARK: - Codable

extension OperationLog.Summary: Codable { }
