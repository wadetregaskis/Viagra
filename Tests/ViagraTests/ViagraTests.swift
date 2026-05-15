import XCTest
import SwiftUI
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

    func testEqualSizesEncompassButAreNotBiggerOrSmaller() {
        let a = CGSize(width: 10, height: 10)
        let b = CGSize(width: 10, height: 10)

        XCTAssertTrue(a.encompasses(b))
        XCTAssertTrue(b.encompasses(a))
        XCTAssertFalse(a.isBiggerThan(b))
        XCTAssertFalse(a.isSmallerThan(b))
    }

    // `isBiggerThan` and `isSmallerThan` use logical-or semantics: they ask whether *any* dimension changed in that direction.  As a result, with mixed dimensions, both can be true at once.
    func testMixedDimensionsCanBeBothBiggerAndSmaller() {
        let a = CGSize(width: 10, height: 50)
        let b = CGSize(width: 50, height: 10)

        XCTAssertTrue(a.isBiggerThan(b),  "a.height > b.height")
        XCTAssertTrue(a.isSmallerThan(b), "a.width < b.width")
        XCTAssertFalse(a.encompasses(b))
        XCTAssertFalse(b.encompasses(a))
    }

    func testUnionedIsIdempotentAndCommutative() {
        let a = CGSize(width: 7, height: 3)
        let b = CGSize(width: 2, height: 9)

        XCTAssertEqual(a.unioned(with: b), b.unioned(with: a))
        XCTAssertEqual(a.unioned(with: a), a)
    }

    func testUnionWithSmallerLeavesSelfUnchanged() {
        var a = CGSize(width: 20, height: 20)

        a.union(with: CGSize(width: 5, height: 5))

        XCTAssertEqual(a, CGSize(width: 20, height: 20))
    }
}

final class ProposedViewSizeExtensionsTests: XCTestCase {
    func testIsConcreteForFiniteValues() {
        XCTAssertTrue(ProposedViewSize(width: 0, height: 0).isConcrete)
        XCTAssertTrue(ProposedViewSize(width: 100, height: 50).isConcrete)
    }

    func testIsConcreteFalseForUnspecified() {
        XCTAssertFalse(ProposedViewSize.unspecified.isConcrete)
        XCTAssertFalse(ProposedViewSize(width: nil, height: 10).isConcrete)
        XCTAssertFalse(ProposedViewSize(width: 10, height: nil).isConcrete)
    }

    func testIsConcreteFalseForInfinity() {
        XCTAssertFalse(ProposedViewSize.infinity.isConcrete)
        XCTAssertFalse(ProposedViewSize(width: .infinity, height: 10).isConcrete)
        XCTAssertFalse(ProposedViewSize(width: 10, height: .infinity).isConcrete)
    }

    func testIsRealRequiresPositiveFiniteDimensions() {
        XCTAssertTrue(ProposedViewSize(width: 1, height: 1).isReal)
        XCTAssertFalse(ProposedViewSize.zero.isReal)
        XCTAssertFalse(ProposedViewSize(width: 0, height: 10).isReal)
        XCTAssertFalse(ProposedViewSize(width: 10, height: 0).isReal)
        XCTAssertFalse(ProposedViewSize.unspecified.isReal)
        XCTAssertFalse(ProposedViewSize.infinity.isReal)
        XCTAssertFalse(ProposedViewSize(width: -5, height: 10).isReal)
    }

    func testDescriptionFormat() {
        XCTAssertEqual(ProposedViewSize(width: 10, height: 20).description,
                       "(10.0, 20.0)")
        XCTAssertEqual(ProposedViewSize(width: nil, height: 20).description,
                       "(nil, 20.0)")
        XCTAssertEqual(ProposedViewSize.unspecified.description,
                       "(nil, nil)")
    }
}

final class OptionalOrNilStringTests: XCTestCase {
    func testNilReturnsNilLiteral() {
        let value: Int? = nil
        XCTAssertEqual(value.orNilString, "nil")
    }

    func testSomeReturnsDescription() {
        let value: Int? = 42
        XCTAssertEqual(value.orNilString, "42")
    }

    func testCGSizeOptional() {
        let value: CGSize? = CGSize(width: 1, height: 2)

        XCTAssertTrue(value.orNilString.contains("1"))
        XCTAssertTrue(value.orNilString.contains("2"))
    }
}

final class FuckingCGSizeTests: XCTestCase {
    func testRoundTripPreservesValue() {
        let original = CGSize(width: 12.5, height: 3.25)
        let wrapped = ShrinkSlowlyLayout.FuckingCGSize(original)

        XCTAssertEqual(wrapped.asCGSize, original)
    }

    func testEqualSizesHashEqually() {
        let a = ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 10, height: 20))
        let b = ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 10, height: 20))

        XCTAssertEqual(a, b)
        XCTAssertEqual(a.hashValue, b.hashValue)
    }

    func testUsableAsDictionaryKey() {
        var dict = [ShrinkSlowlyLayout.FuckingCGSize: Int]()
        let key = ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 1, height: 2))

        dict[key] = 99

        XCTAssertEqual(dict[ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 1, height: 2))], 99)
    }
}

final class CacheInitialStateTests: XCTestCase {
    func testFreshCacheIsEmpty() {
        let cache = ShrinkSlowlyLayout.Cache()

        XCTAssertNil(cache.lastRenderedSize)
        XCTAssertNil(cache.desiredSize)
        XCTAssertNil(cache.shrinker)

        XCTAssertTrue(cache.renderTimesPerDesiredSize.isEmpty)
    }

    func testCurrentMinimumSizeOnFreshCacheReturnsNil() {
        let cache = ShrinkSlowlyLayout.Cache()

        XCTAssertNil(cache.currentMinimumSize(delay: .seconds(1)))
        XCTAssertNil(cache.currentMinimumSize(delay: .zero))
        XCTAssertNil(cache.currentMinimumSize(delay: .seconds(-1)))
    }
}

final class CacheCurrentMinimumSizeUnionTests: XCTestCase {
    // Verify that the returned size is the union (per-dimension max) of every alive entry, not just any single one.
    func testReturnedSizeUnionsAcrossMultipleAliveEntries() {
        let cache = ShrinkSlowlyLayout.Cache()
        let now: ContinuousClock.Instant = .now

        cache.renderTimesPerDesiredSize[
            ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 100, height: 10))] = now
        cache.renderTimesPerDesiredSize[
            ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 10, height: 200))] = now
        cache.renderTimesPerDesiredSize[
            ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 50, height: 50))] = now

        let result = cache.currentMinimumSize(delay: .seconds(60))

        XCTAssertEqual(result?.size.width, 100)
        XCTAssertEqual(result?.size.height, 200)
    }

    // timeRemaining should be the MIN across alive entries (the soonest one to expire), so the shrinker wakes up at the right moment.
    func testTimeRemainingIsMinimumAcrossAliveEntries() {
        let cache = ShrinkSlowlyLayout.Cache()
        let now: ContinuousClock.Instant = .now

        // Entry A recorded 0.5 s ago → with 2 s delay, ~1.5 s remaining.
        // Entry B recorded 1.5 s ago → with 2 s delay, ~0.5 s remaining.
        cache.renderTimesPerDesiredSize[
            ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 10, height: 10))] = now - .milliseconds(500)
        cache.renderTimesPerDesiredSize[
            ShrinkSlowlyLayout.FuckingCGSize(CGSize(width: 20, height: 20))] = now - .milliseconds(1500)

        let result = cache.currentMinimumSize(delay: .seconds(2))

        XCTAssertNotNil(result)

        let remaining = result!.timeRemaining

        XCTAssertGreaterThan(remaining, .zero)
        XCTAssertLessThan(remaining, .seconds(1),
                          "timeRemaining must be the minimum (~0.5 s), not the maximum.")
    }
}
