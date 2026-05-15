import XCTest
@testable import Viagra

final class CacheCurrentMinimumSizeTests: XCTestCase {
    func testExpiredEntriesAreRemovedAndDoNotCrashWithManyEntries() {
        let cache = ShrinkSlowlyLayout.Cache()
        let delay: ContinuousClock.Duration = .seconds(1)
        let now: ContinuousClock.Instant = .now

        // Populate with a large mix of expired and still-alive entries.  This is the shape of input that would previously have been vulnerable to dictionary-mutation-during-iteration corruption.
        for i in 0..<200 {
            let size = ShrinkSlowlyLayout.FuckingCGSize(
                CGSize(width: Double(i), height: Double(i)))
            let timestamp: ContinuousClock.Instant = (0 == i % 2)
                ? now - .seconds(10) // expired
                : now                 // alive

            cache.renderTimesPerDesiredSize[size] = timestamp
        }

        let expectedAliveCount = 100
        let expectedExpiredCount = 100

        XCTAssertEqual(cache.renderTimesPerDesiredSize.count,
                       expectedAliveCount + expectedExpiredCount)

        let result = cache.currentMinimumSize(delay: delay)

        // All expired entries should now be gone; alive ones must remain.
        XCTAssertEqual(cache.renderTimesPerDesiredSize.count, expectedAliveCount,
                       "Expired entries should be removed; alive entries kept.")

        for (key, _) in cache.renderTimesPerDesiredSize {
            XCTAssertEqual(Int(key.width) % 2, 1,
                           "Only odd-indexed (alive) entries should remain.")
        }

        // Returned union must encompass the largest alive size (199, 199).
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.size.width, 199)
        XCTAssertEqual(result?.size.height, 199)
        XCTAssertGreaterThan(result?.timeRemaining ?? .zero, .zero)
    }

    func testAllExpiredReturnsNilAndEmptiesDictionary() {
        let cache = ShrinkSlowlyLayout.Cache()
        let delay: ContinuousClock.Duration = .seconds(1)
        let past: ContinuousClock.Instant = .now - .seconds(60)

        for i in 0..<10 {
            cache.renderTimesPerDesiredSize[
                ShrinkSlowlyLayout.FuckingCGSize(
                    CGSize(width: Double(i), height: Double(i)))] = past
        }

        let result = cache.currentMinimumSize(delay: delay)

        XCTAssertNil(result)
        XCTAssertTrue(cache.renderTimesPerDesiredSize.isEmpty)
    }

    func testEmptyCacheReturnsNil() {
        let cache = ShrinkSlowlyLayout.Cache()
        XCTAssertNil(cache.currentMinimumSize(delay: .seconds(1)))
    }

    func testAllAliveLeavesDictionaryIntact() {
        let cache = ShrinkSlowlyLayout.Cache()
        let now: ContinuousClock.Instant = .now

        for i in 1...5 {
            cache.renderTimesPerDesiredSize[
                ShrinkSlowlyLayout.FuckingCGSize(
                    CGSize(width: Double(i * 10), height: Double(i * 5)))] = now
        }

        let result = cache.currentMinimumSize(delay: .seconds(10))

        XCTAssertEqual(cache.renderTimesPerDesiredSize.count, 5)
        XCTAssertEqual(result?.size.width, 50)
        XCTAssertEqual(result?.size.height, 25)
    }
}

final class LogAutoclosureTests: XCTestCase {
    override func tearDown() {
        ViagraDebugLoggingEnabled = false
        super.tearDown()
    }

    func testMessageNotEvaluatedWhenLoggingDisabled() {
        ViagraDebugLoggingEnabled = false

        var evaluations = 0
        log({
            evaluations += 1
            return "should not be called"
        }())

        XCTAssertEqual(evaluations, 0,
                       "log() message must not be evaluated when ViagraDebugLoggingEnabled is false.")
    }

    func testMessageEvaluatedWhenLoggingEnabled() {
        ViagraDebugLoggingEnabled = true

        var evaluations = 0
        log({
            evaluations += 1
            return "ok"
        }())

        XCTAssertEqual(evaluations, 1,
                       "log() message must be evaluated exactly once when logging is enabled.")
    }
}

final class CGSizeHelpersTests: XCTestCase {
    func testUnionedWithTakesMaxOfEachDimension() {
        let a = CGSize(width: 10, height: 20)
        let b = CGSize(width: 15, height: 5)
        XCTAssertEqual(a.unioned(with: b), CGSize(width: 15, height: 20))
    }

    func testUnionMutatingMatchesUnioned() {
        var a = CGSize(width: 10, height: 20)
        a.union(with: CGSize(width: 15, height: 5))
        XCTAssertEqual(a, CGSize(width: 15, height: 20))
    }

    func testEncompassesAndIsSmallerThan() {
        let small = CGSize(width: 10, height: 10)
        let big = CGSize(width: 20, height: 20)
        XCTAssertTrue(big.encompasses(small))
        XCTAssertFalse(small.encompasses(big))
        XCTAssertTrue(small.isSmallerThan(big))
        XCTAssertTrue(big.isBiggerThan(small))
    }
}
