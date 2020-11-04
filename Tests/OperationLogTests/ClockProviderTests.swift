import XCTest
import VectorClock
@testable import OperationLog


final class ClockProviderTests: XCTestCase {

    func testIncrementing() {
        let initialClock = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)
        XCTAssertEqual(initialClock.description, "<A=0 | t: A(1.00)>")

        var clockProvider = ClockProvider(actorID: "A", vectorClock: initialClock)
        XCTAssertEqual(clockProvider.next().description, "<A=1 | t: A(2.00)>")
        XCTAssertEqual(clockProvider.next().description, "<A=2 | t: A(3.00)>")
    }

    func testMerge() {
        let initialClockA = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)
        var clockProviderA = ClockProvider(actorID: "A", vectorClock: initialClockA)
        XCTAssertEqual(clockProviderA.next().description, "<A=1 | t: A(2.00)>")

        let initialClockB = VectorClock(actorID: "B", timestampProviderStrategy: .monotonicIncrease)
        var clockProviderB = ClockProvider(actorID: "B", vectorClock: initialClockB)
        XCTAssertEqual(clockProviderB.next().description, "<B=1 | t: B(2.00)>")

        clockProviderA.merge(clockProviderB)
        XCTAssertEqual(clockProviderA.next().description, "<A=2, B=1 | t: A(3.00)>")
    }
}
