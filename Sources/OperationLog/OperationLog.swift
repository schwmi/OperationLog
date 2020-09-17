import Foundation
import VectorClock


struct OperationLog<ActorID: Comparable & Hashable & Codable> {

    private let actorID: ActorID

    // MARK: - Lifecycle

    init(actorID: ActorID) {
        self.actorID = actorID
    }

    func append(_ operation: Operation) {
    }
}

protocol Operation {
    var description: String? { get }
    func apply(to snapshot: Snapshot) -> Snapshot
    func serialize() -> Data
}

protocol Snapshot {
    func serialize() -> Data
}
