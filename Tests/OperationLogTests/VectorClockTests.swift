import XCTest
@testable import OperationLog


final class VectorClockTests: XCTestCase {

    func testNewEmptyClock() {
        let clock = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)
        XCTAssertEqual(clock.description, "<A=0 | t: A(1.00)>")
    }

    func testIncrement() {
        let clock = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)

        // Increment actor A
        let incrementedA = clock.incrementingClock(of: "A")
        XCTAssertEqual(incrementedA.description, "<A=1 | t: A(2.00)>")

        // Increment actor B
        let incrementedAB = incrementedA.incrementingClock(of: "B")
        XCTAssertEqual(incrementedAB.description, "<A=1, B=1 | t: B(3.00)>")

        // Increment actor B again
        let incrementedABB = incrementedAB.incrementingClock(of: "B")
        XCTAssertEqual(incrementedABB.description, "<A=1, B=2 | t: B(4.00)>")

        // Increment actor A again
        let incrementedABBA = incrementedABB.incrementingClock(of: "A")
        XCTAssertEqual(incrementedABBA.description, "<A=2, B=2 | t: A(5.00)>")
    }

    func testMerge() {
        let clock = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)

        // Increment actor A
        let incrementedA = clock.incrementingClock(of: "A")
        XCTAssertEqual(incrementedA.description, "<A=1 | t: A(2.00)>")

        // Increment actor B
        let incrementedB = clock.incrementingClock(of: "B")
        XCTAssertEqual(incrementedB.description, "<A=0, B=1 | t: B(3.00)>")

        // Merge A with B
        let mergedAB = incrementedB.merging(incrementedA)
        XCTAssertEqual(mergedAB.description, "<A=1, B=1 | t: B(3.00)>")
    }

    func testComparisonWithConstantTime() {
        // Test empty clock comparison
        let clock1 = VectorClock(actorID: "A", timestampProviderStrategy: .constant)
        let clock2 = VectorClock(actorID: "A", timestampProviderStrategy: .constant)
        XCTAssertEqual(clock1.partialOrder(other: clock2), .equal)

        // Increment actor A
        let clock1A = clock1.incrementingClock(of: "A")
        XCTAssertEqual(clock1.totalOrder(other: clock1A), .ascending)
        XCTAssertEqual(clock1A.totalOrder(other: clock1A), .equal)

        // Increment actor B
        let clock2B = clock2.incrementingClock(of: "B")
        XCTAssertEqual(clock1A.partialOrder(other: clock2B), .concurrent)
        XCTAssertEqual(clock1A.totalOrder(other: clock2B), .ascending)
        XCTAssertNotEqual(clock1A.totalOrder(other: clock2B), .descending)
    }

    func testComparisonWithIncreasingTime() {
        // Test empty clock comparison
        let clock1 = VectorClock(actorID: "A", timestampProviderStrategy: .unixTime)
        Thread.sleep(forTimeInterval: 0.01)
        let clock2 = VectorClock(actorID: "A",  timestampProviderStrategy: .unixTime)
        XCTAssertEqual(clock1.partialOrder(other: clock2), .equal)
        XCTAssertEqual(clock1.totalOrder(other: clock2), .ascending)

        // Increment actor A
        let clock1A = clock1.incrementingClock(of: "A")
        XCTAssertEqual(clock1.totalOrder(other: clock1A), .ascending)
        XCTAssertEqual(clock1A.totalOrder(other: clock1A), .equal)

        // Increment actor B
        let clock2B = clock2.incrementingClock(of: "B")
        XCTAssertEqual(clock1A.totalOrder(other: clock2B), .ascending)
    }

    func testCodable() throws {
        let clock = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)
        let encoded = try JSONEncoder().encode(clock)
        let decoded = try JSONDecoder().decode(VectorClock<String>.self, from: encoded)
        XCTAssertEqual(clock.totalOrder(other: decoded), .equal)
        let increasedClock = decoded.incrementingClock(of: "B")
        print(increasedClock.description)
        XCTAssertEqual(increasedClock.description, "<A=0, B=1 | t: B(2.00)>")
    }

    static var allTests = [
        ("testIncrement", testIncrement),
        ("testComparisonWithConstantTime", testComparisonWithConstantTime),
        ("testComparisonWithIncreasingTime", testComparisonWithIncreasingTime),
        ("testMerge", testMerge),
        ("testNewEmptyClock", testNewEmptyClock),
        ("testCodable", testCodable),
        ("testSortingPerformance", testSortingPerformance)
    ]
}

// MARK: - Performance Tests

extension VectorClockTests {

    func testSortingPerformance() {
        var clocks = Set<VectorClock<String>>()
        let actors = ["A", "B", "C", "D"]
        let clock = VectorClock(actorID: "A", timestampProviderStrategy: .monotonicIncrease)
        clocks.insert(clock)
        for _ in 0..<5000 {
            clocks.insert(clock.incrementingClock(of: actors.randomElement()!))
        }
        self.measure {
            _ = clocks.sorted(by: { $0.totalOrder(other: $1) == .ascending })
        }
    }
}
