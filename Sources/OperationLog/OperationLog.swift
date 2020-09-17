import VectorClock


struct OperationLog<ActorID: Comparable & Hashable & Codable> {

    private let actorID: ActorID

    // MARK: - Lifecycle

    init(actorID: ActorID) {
        self.actorID = actorID
    }

    func appendOperation() {

    }
}
