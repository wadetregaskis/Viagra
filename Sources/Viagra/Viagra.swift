//  Created by Wade Tregaskis on 2024-05-18.

public import SwiftUI


public nonisolated(unsafe) var ViagraDebugLoggingEnabled = false // Rudimentary control over whether logging is emitted.  This is not technically thread-safe, but since it's a boolean and it doesn't really matter if it races between writes and reads, it actually *is* effectively thread-safe.  Ideally there'd be a way to express this to the compiler without using the misleading word "unsafe", but alas, there apparently is not.

let startTime = ContinuousClock.now

func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    guard ViagraDebugLoggingEnabled else { return }

    var message = ""

    for item in items {
        if !message.isEmpty {
            message.append(separator)
        }

        message.append(String(describing: item))
    }

    print("[", (.now - startTime).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 0, fractionalSecondsLength: 3))), "] ", message, separator: "", terminator: terminator)
}


struct NeverShrink: Layout {
    typealias Cache = CGSize

    func makeCache(subviews: Self.Subviews) -> Self.Cache {
        log("Making cache.")
        return .zero
    }

    func updateCache(_ cache: inout Self.Cache,
                     subviews: Self.Subviews) {
        // Do nothing; the default implementation destroys the cache, so we have to override it merely to stop that.
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Cache) -> CGSize {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("NeverShrink only works with one subview; found:", dump(subviews))
            return CGSize(width: 0, height: 0)
        }

        let subviewResponse = subview.sizeThatFits(proposal)

        if proposal.isReal {
            let response = subviewResponse.unioned(with: cache)

            log("sizeThatFits(\(proposal), …) -> \(response) [\(subviewResponse) ∪ \(cache)]")

            return response
        } else {
            log("sizeThatFits(\(proposal), …) -> \(subviewResponse) [unmodified]")
            return subviewResponse
        }
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Cache) {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("NeverShrink only works with one subview; found:", dump(subviews))
            return
        }

        log("Placing subview in bounds \(bounds) with proposal \(proposal.description)\(proposal.isReal ? "" : " [not considered real]").")

        if proposal.isReal {
            cache.union(with: bounds.size)
        }

        subview.place(at: bounds.origin, proposal: proposal)
    }
}

struct ShrinkSlowlyLayout: Layout {
    @MainActor @Binding var currentMinimumSize: CGSize

    let delay: ContinuousClock.Duration
    let speed: Double

    struct FuckingCGSize: Hashable {
        var width: CGFloat
        var height: CGFloat

        init(_ size: CGSize) {
            self.width = size.width
            self.height = size.height
        }

        var asCGSize: CGSize {
            CGSize(width: width, height: height)
        }
    }

    final class Cache: @unchecked Sendable { // TODO: Not remotely Sendable, but this hack is required in order to work around design flaws in SwiftUI's Layout.  Remove this horrible lie once Layout is fixed.
        var lastRenderedSize: CGSize? = nil
        var desiredSize: CGSize? = nil
        var renderTimesPerDesiredSize = [FuckingCGSize: ContinuousClock.Instant]()
        var shrinker: Task<Void, Never>? = nil

        init() {}

        func currentMinimumSize(delay: ContinuousClock.Duration) -> (size: CGSize, timeRemaining: ContinuousClock.Duration)? {
            let times = renderTimesPerDesiredSize.sorted { $0.key.width > $1.key.width }

            for (wrappedSize, time) in times {
                let size = wrappedSize.asCGSize

                log("\(size) last desired at \(time).")

                let timeout = time + delay
                let timeRemaining = timeout - .now

                if .zero < timeRemaining {
                    return (size, timeRemaining)
                } else {
                    renderTimesPerDesiredSize.removeValue(forKey: wrappedSize)
                }
            }

            return nil
        }
    }

    func makeCache(subviews: Self.Subviews) -> Self.Cache {
        log("Making cache.")
        return Cache()
    }

    func updateCache(_ cache: inout Self.Cache,
                     subviews: Self.Subviews) {
        // Do nothing; the default implementation destroys the cache, so we have to override it merely to stop that.
    }

    //@MainActor // Should be, but Layout is broken as it's missing @MainActor for all its key methods.
    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Cache) -> CGSize {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return CGSize(width: 0, height: 0)
        }

        let subviewResponse = subview.sizeThatFits(proposal)

        if proposal.isReal {
            let lastDesiredSize = cache.desiredSize

            if let lastDesiredSize {
                log("Last desired size was \(lastDesiredSize) - recording that for \(ContinuousClock.now).")
                cache.renderTimesPerDesiredSize[FuckingCGSize(lastDesiredSize)] = .now
            }

            if cache.desiredSize != subviewResponse {
                log("Desired size:", subviewResponse)
                cache.desiredSize = subviewResponse
            }

            let delayLimit = cache.currentMinimumSize(delay: delay)


            return MainActor.assumeIsolated { // TODO: remove this hack once Layout is fixed (to be @MainActor).
                let response = subviewResponse
                    .unioned(with: currentMinimumSize)
                    .unioned(with: delayLimit?.size ?? .zero)

                log("sizeThatFits(\(proposal), …) -> \(response) [\(subviewResponse) ∪ \(currentMinimumSize) ∪ \(delayLimit.orNilString)]")

                return response
            }
        } else {
            log("sizeThatFits(\(proposal), …) -> \(subviewResponse) [unmodified]")
            return subviewResponse
        }
    }

    @MainActor
    func startShrinker(cache: inout Cache) {
        log("Starting shrinker…")

        if let existingShrinker = cache.shrinker {
            log("WARNING: already had a shrinker.")
            existingShrinker.cancel()
        }

        cache.shrinker = Task { @MainActor [weak cache] in
            do {
                loop: while !Task.isCancelled {
                    guard let cache else {
                        log("Cache gone, cancelling.")
                        throw CancellationError()
                    }

                    guard let desiredSize = cache.desiredSize else {
                        log("🐞 Don't know my own desired size, so can't shrink to anything.  Cancelling.")
                        throw CancellationError()
                    }

                    var minimumSize = desiredSize

                    if let (size, timeRemaining) = cache.currentMinimumSize(delay: delay) {
                        minimumSize.union(with: size)

                        if minimumSize.encompasses(cache.lastRenderedSize ?? .zero) {
                            log("Can't shrink below \(size) yet because there's still \(timeRemaining) before the delay ends.")

                            if currentMinimumSize != minimumSize {
                                // If we don't "lock" the minimum size here, there's a race condition whereby the view is redrawn after the delay has passed but before the shrinker returns from the sleep call (below).  In that case, `currentMinimumSize` will still be set to whatever it was earlier, which may be smaller than the currently rendered size, resulting in sizeThatFits not properly restricting its results to the current size, and thus abrupt and too-rapid shrinkage.  This is easy to reproduce if you add an non-trivial additional delay to the sleep call below (e.g. five seconds), and cause the content view to reduce its desired size [by more than one point] after the real delay has expired but before the artificially extended sleep call below returns.  It may help to force spurious redraws as well (e.g. resize the containing window continuously).
                                log("Locking minimum size at \(minimumSize) until the delay ends.")
                                currentMinimumSize = minimumSize
                            }

                            try await Task.sleep(for: timeRemaining)
                            continue loop
                        }
                    }

                    let newMinimumSize = CGSize(width: max((cache.lastRenderedSize?.width ?? 1) - 1, minimumSize.width),
                                                height: max((cache.lastRenderedSize?.height ?? 1) - 1, minimumSize.height))

                    if currentMinimumSize != newMinimumSize {
                        log("Shrinking below \(cache.lastRenderedSize.orNilString) towards \(desiredSize) (current minimum size \(minimumSize)).  Current target: \(currentMinimumSize)")
                        currentMinimumSize = newMinimumSize
                    }

                    try await Task.sleep(for: .seconds(1) / speed)
                }
            } catch {
                log("Shrinker cancelled.")
            }
        }
    }

    //@MainActor // Should be, but Layout is broken as it's missing @MainActor for all its key methods.
    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Cache) {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return
        }

        log("Placing subview in bounds \(bounds) with proposal \(proposal.description)\(proposal.isReal ? "" : " [not considered real]").")

        if proposal.isReal {
            if let desiredSize = cache.desiredSize {
                log("Desired size is \(desiredSize), recording that for \(ContinuousClock.now).")
                cache.renderTimesPerDesiredSize[FuckingCGSize(desiredSize)] = .now

                if nil != cache.shrinker && desiredSize == bounds.size {
                    cache.shrinker?.cancel()
                    cache.shrinker = nil
                }

                if nil == cache.shrinker && desiredSize.isSmallerThan(bounds.size) {
                    log("Desired size \(desiredSize) is smaller than current rendered size \(bounds.size), so starting shrinker…")

                    MainActor.assumeIsolated {
                        startShrinker(cache: &cache)
                    }
                }
            }

            if cache.lastRenderedSize != bounds.size {
                log("Previously rendered in bounds \(cache.lastRenderedSize.orNilString), now rendering in \(bounds.size).")

                if let lastRenderedSize = cache.lastRenderedSize {
                    // This assertion is to catch unexpected (or unexpectedly rapid) shrinkage.  This has caught at least one sneaky bug (a race condition, of sorts, between the shrinker sleeping off a delay and the view re-rendering for other reasons, before the shrinker took steps to lock the view's size while it's sleeping off the delay).  All going well there are no more such bugs, so it's no longer necessary.  It is possible, however, that it'll be tripped in situations which aren't technically just bugs in this code but perhaps just bad interactions with other SwiftUI views or layouts.  If you think you've found such a case, please report it.  You can disable the assertion in the meantime, but better to have the problem fixed properly.
                    assert(lastRenderedSize.width - 1.1 <= bounds.size.width
                           && lastRenderedSize.height - 1.1 <= bounds.size.height, "View shrank by more than one point between renders - shouldn't be possible.  Last rendered size was \(lastRenderedSize), new size is \(bounds.size).")

                    if lastRenderedSize.isSmallerThan(bounds.size) {
                        log("Bounds grew; previously rendered in bounds \(cache.lastRenderedSize.orNilString), now rendering in \(bounds.size).")
                    }
                }

                cache.lastRenderedSize = bounds.size
            }
        }

        subview.place(at: bounds.origin, proposal: proposal)
    }
}

extension Optional {
    var orNilString: String {
        if let self {
            return String(describing: self)
        } else {
            return "nil"
        }
    }
}

extension ProposedViewSize {
    var description: String {
        let w = if let width { width.description } else { "nil" }
        let h = if let height { height.description } else { "nil" }

        return "(\(w), \(h))"
    }

    var isConcrete: Bool {
        (width?.isFinite ?? false) && (height?.isFinite ?? false)
    }

    var isReal: Bool {
        isConcrete && (0 < (width ?? 0)) && (0 < (height ?? 0))
    }
}

extension CGSize {
    func fitsWithin(_ other: CGSize) -> Bool {
        self.width <= other.width && self.height <= other.height
    }

    func encompasses(_ other: CGSize) -> Bool {
        self.width >= other.width && self.height >= other.height
    }

    func isBiggerThan(_ other: CGSize) -> Bool {
        self.width > other.width || self.height > other.height
    }

    func isSmallerThan(_ other: CGSize) -> Bool {
        self.width < other.width || self.height < other.height
    }

    mutating func union(with other: CGSize) {
        if other.width > self.width {
            self.width = other.width
        }

        if other.height > self.height {
            self.height = other.height
        }
    }

    func unioned(with other: CGSize) -> CGSize {
        CGSize(width: max(self.width, other.width),
               height: max(self.height, other.height))
    }
}

@MainActor
struct ShrinkSlowly<C: View>: View {
    @State var currentMinimumSize: CGSize = .zero

    let delay: Duration
    let speed: Double

    let content: () -> C

    init(delay: Duration,
         speed: Double,
         @ViewBuilder content: @escaping () -> C) {
        self.delay = delay
        self.speed = speed
        self.content = content
    }

    var body: some View {
        let _ = currentMinimumSize // Have to explicitly reference `shrink` in order to be re-run when `shrink` changes.

        ShrinkSlowlyLayout(currentMinimumSize: $currentMinimumSize,
                           delay: delay,
                           speed: speed) {
            content()
        }
    }
}

public extension View {
    /// Prevents (as best it can) the view from ever shrinking.
    ///
    /// Normally SwiftUI views shrink (and enlarge) immediately whenever the layout changes (whether a result of an internal change, such as their content changing, or an external change, such as a window resizing).
    ///
    /// This modifier allows the view to enlarge, but never shrink.
    ///
    /// It works best when expansion occurs in only one direction, or when the view has fixed maximums in at least one dimension (e.g. a `Text` view with a fixed maximum width, or inside a container which imposes a fixed maximum width).  You may see odd and undesirable behaviour in cases such as windows that try to automatically fit their contents.
    ///
    /// Make sure not to use any of the [`frame`](https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)) modifiers after this one, as they will override.  It's fine to use the `frame` modifiers _before_ this one.
    ///
    /// This is conceptually a specialisation of `shrinkSlowly` with an infinite delay, but its implementation is more efficient because its task is simpler.  Always use this in preference to `neverShrink` when you don't actually want shrinkage.
    ///
    /// - Returns: The modified view.
    @MainActor
    func neverShrink() -> some View {
        NeverShrink() {
            self
        }
    }

    /// Controls the delay and speed at which the view shrinks, if its natural size changes.
    ///
    /// Normally SwiftUI views shrink (and enlarge) immediately whenever the layout changes (whether a result of an internal change, such as their content changing, or an external change, such as a window resizing).
    ///
    /// This modifier lets you control their shrinkage - first by (optionally) delaying it and then as to how quickly the shrinkage occurs.
    ///
    /// It works best when expansion occurs in only one direction, or when the view has fixed maximums in at least one dimension (e.g. a `Text` view with a fixed maximum width, or inside a container which imposes a fixed maximum width).  You may see odd and undesirable behaviour in cases such as windows that try to automatically fit their contents.
    ///
    /// Make sure not to use any of the [`frame`](https://developer.apple.com/documentation/swiftui/view/frame(width:height:alignment:)) modifiers after this one, as they will override.  It's fine to use the `frame` modifiers _before_ this one.
    ///
    /// If you want the view to _never_ shrink, use `neverShrink` instead (it is functionally equivalent to an infinite delay, but more efficient).
    ///
    /// - Parameters:
    ///   - delay: The amount of time to wait before shrinking.  Defaults to three seconds.
    ///   - speed: The speed of the shrinkage once it does occur, in **pixels per second**.  This is not "Retina-aware" - if you want the speed to be visually consistent irrespective of Retina factor, you'll need to divide this by the Retina factor (e.g. [`backingScaleFactor`](https://developer.apple.com/documentation/appkit/nswindow/1419459-backingscalefactor) from `NSWindow`).
    ///
    ///       For best results use a factor of the display frequency (e.g. on a 120 Hz display, the best speeds are 120, 60, 30, and 15).  The default is 30.
    /// - Returns: The modified view.
    @MainActor
    func shrinkSlowly(delay: ContinuousClock.Duration = .seconds(3),
                      speed: Double = 30) -> some View {
        ShrinkSlowly(delay: delay,
                     speed: speed) {
            self
        }
    }
}
