import Foundation


/// Encapsulates logic for creating vector clock timestamps for total operation ordering
struct ClockProvider<ActorID: Identifier> {

    private var actorID: ActorID
    private var currentClock: VectorClock<ActorID>

    // MARK: - Lifecycle

    init(actorID: ActorID, vectorClock: VectorClock<ActorID>) {
        self.currentClock = vectorClock
        self.actorID = actorID
    }

    // MARK: - ClockProvider

    mutating func next() -> VectorClock<ActorID> {
        self.currentClock = self.currentClock.incrementingClock(of: self.actorID)
        return self.currentClock
    }

    mutating func merge(_ clockProvider: Self) {
        self.currentClock = self.currentClock.merging(clockProvider.currentClock)
    }

    mutating func merge(_ clock: VectorClock<ActorID>) {
        self.currentClock = self.currentClock.merging(clock)
    }
}
