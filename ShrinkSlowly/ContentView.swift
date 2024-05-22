//
//  ContentView.swift
//  ShrinkSlowly
//
//  Created by Wade Tregaskis on 18/5/2024.
//

import SwiftUI

let startTime = ContinuousClock.now

func log(_ items: Any..., separator: String = " ", terminator: String = "\n") {
    var message = ""

    for item in items {
        if !message.isEmpty {
            message.append(separator)
        }

        message.append(String(describing: item))
    }

    print("[", (.now - startTime).formatted(.time(pattern: .hourMinuteSecond(padHourToLength: 0, fractionalSecondsLength: 3))), "] ", message, separator: "", terminator: terminator)
}

struct Custom: CustomAnimation {
//    func animate<V>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V : VectorArithmetic {
//        print("Dud animate")
//        return nil
//    }

    let duration = 1.0

    typealias CGSizeAP = AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>

    func animate<V>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V : VectorArithmetic {

//    func animate(value: CGSizeAP,
//                 time: TimeInterval,
//                 context: inout AnimationContext<CGSizeAP>) -> CGSizeAP? {

        guard let realValue = value as? CGSizeAP else {
            guard let _ = value as? Double else {
                var fuckYouSwift = ""
                dump(context, to: &fuckYouSwift)
                log("💩 value:", value, "context:", fuckYouSwift)
                return nil
            }

            return value.scaled(by: time / duration)
        }

        guard time < duration else { return nil } // The animation has finished.

        guard 0 > realValue.second.first else { return nil } // View is growing.

        return value.scaled(by: time / duration)
    }
}

struct NeverShrink: Layout {
    struct FuckingProposedViewSize: Hashable {
        var width: CGFloat?
        var height: CGFloat?

        init(_ proposal: ProposedViewSize) {
            self.width = proposal.width
            self.height = proposal.height
        }
    }

    typealias Cache = [FuckingProposedViewSize: CGSize]

    func makeCache(subviews: Self.Subviews) -> Self.Cache {
        log("Making cache.")
        return Cache()
    }

    func updateCache(_ cache: inout Self.Cache,
                     subviews: Self.Subviews) {
        log("No update cache for you!")
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Cache) -> CGSize {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return CGSize(width: 0, height: 0)
        }

        let subviewResponse = subview.sizeThatFits(proposal)

        let key = FuckingProposedViewSize(proposal)
        let result: CGSize

        if let cachedValue = cache[key] {
            if cachedValue.width >= subviewResponse.width && cachedValue.height >= subviewResponse.height {
                log("Cached value \(cachedValue) is >= subviewResponse \(subviewResponse).")
                return cachedValue
            }

            result = CGSize(width: max(subviewResponse.width,
                                       cachedValue.width),
                            height: max(subviewResponse.height,
                                        cachedValue.height))

            log("Cached value \(cachedValue) is not >= subviewResponse \(subviewResponse), so merging them to \(result).")
        } else {
            log("No cached value for \(key); using subviewResponse:", subviewResponse)
            result = subviewResponse
        }

        cache[key] = result

        return result
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Cache) {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return
        }

        log("Placing subview in bounds \(bounds) with proposal \(proposal).")

        subview.place(at: bounds.origin, proposal: proposal) // ❌
//        subview.place(at: bounds.origin, proposal: .unspecified) // ❌
//        subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size)) // ❌
    }
}

struct ShrinkSlowlyLayout: Layout {
    @MainActor @Binding var tick: Bool

    let delay: ContinuousClock.Duration
    let speed: Double

    struct FuckingProposedViewSize: Hashable {
        var width: CGFloat?
        var height: CGFloat?

        init(_ proposal: ProposedViewSize) {
            self.width = proposal.width
            self.height = proposal.height
        }
    }

    class Cache {
        var current = [FuckingProposedViewSize: CGSize]()
        var target = [FuckingProposedViewSize: CGSize]()
        var lastIncreaseTime: ContinuousClock.Instant? = nil
        var lastRenderedSize: CGSize? = nil
        var desiredSize: CGSize? = nil
        var shrinker: Task<Void, Never>? = nil

        init() {}
    }

    func makeCache(subviews: Self.Subviews) -> Self.Cache {
        log("Making cache.")
        return Cache()
    }

    func updateCache(_ cache: inout Self.Cache,
                     subviews: Self.Subviews) {
        log("No update cache for you!")
    }

    @MainActor
    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Cache) -> CGSize {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return CGSize(width: 0, height: 0)
        }

        let subviewResponse = subview.sizeThatFits(proposal)

        if proposal.isReal {
            if cache.desiredSize != subviewResponse {
                log("Desired size:", subviewResponse)
                cache.desiredSize = subviewResponse
            }
        }

        let key = FuckingProposedViewSize(proposal)

        cache.target[key] = subviewResponse

        let result: CGSize

        if let cachedValue = cache.current[key] {
            if nil == cache.shrinker && subviewResponse != cachedValue {
                log("Target differs from current value for \(proposal.description); needs to shrink.")
            }

            if cachedValue.width >= subviewResponse.width && cachedValue.height >= subviewResponse.height {
                log("Cached value for \(proposal.description) is \(cachedValue) which is >= subviewResponse \(subviewResponse).")

                if subviewResponse == cachedValue {
                    if nil != cache.shrinker && cache.target == cache.current {
                        log("Target met - no longer need to shrink.")

                        cache.shrinker?.cancel()
                        cache.shrinker = nil
                    }

                    return cachedValue
                } else {
                    if let lastIncreaseTime = cache.lastIncreaseTime, .zero >= lastIncreaseTime + delay - .now {
                        log("Shrinking slightly (lastIncreaseTime: \(lastIncreaseTime), delay: \(delay), now: \(ContinuousClock.now))…")
                        let slightlySmallerValue = CGSize(width: max(subviewResponse.width, cachedValue.width - 1),
                                                          height: max(subviewResponse.height, cachedValue.height - 1))

                        cache.current[key] = slightlySmallerValue
                        return slightlySmallerValue
                    } else {
                        log("Non-shrinker update (not currently shrinking or still in delay period; lastIncreaseTime: \(cache.lastIncreaseTime.orNilString)).")
                        return cachedValue
                    }
                }
            }

            result = CGSize(width: max(subviewResponse.width,
                                       cachedValue.width),
                            height: max(subviewResponse.height,
                                        cachedValue.height))

            log("Cached value for \(proposal.description) is \(cachedValue) which is not >= subviewResponse \(subviewResponse), so merging them to \(result).")
        } else {
            result = subviewResponse

            log("No cached value for \(proposal.description); using subviewResponse:", subviewResponse)
        }

        cache.current[key] = result

        return result
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
                while !Task.isCancelled {
                    delayLoop: while true {
                        guard let cache else {
                            log("Cache gone, cancelling.")
                            throw CancellationError()
                        }

                        guard let lastIncreaseTime = cache.lastIncreaseTime else {
                            log("No last increase time!")
                            throw CancellationError()
                        }

                        let startShrinkingAt = lastIncreaseTime + delay
                        let durationUntilShrinkingStarts = startShrinkingAt - .now

                        if .zero < durationUntilShrinkingStarts {
                            log("In delay period before shrink (for another \(durationUntilShrinkingStarts))…")
                            try await Task.sleep(for: durationUntilShrinkingStarts)
                        } else {
                            log("No delay (durationUntilShrinkingStarts: \(durationUntilShrinkingStarts), startShrinkingAt: \(startShrinkingAt), now: \(ContinuousClock.now)).")
                            break delayLoop
                        }
                    }

                    log("TICK")
                    tick.toggle()
                    try await Task.sleep(for: .seconds(1) / speed)
                }
            } catch {
                log("Shrinker cancelled.")
            }
        }
    }

    @MainActor
    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Cache) {
        guard let subview = subviews.first, 1 == subviews.count else {
            log("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return
        }

        log("Placing subview in bounds \(bounds) with proposal \(proposal.description).")

        if proposal.isReal {
            if nil != cache.shrinker && cache.desiredSize == bounds.size {
                cache.shrinker?.cancel()
                cache.shrinker = nil
            }

            if cache.desiredSize?.encompasses(bounds.size) ?? false {
                log("Desired size \(cache.desiredSize.orNilString) encompasses actual rendered size \(bounds.size).  Don't shrink soon.")

                cache.lastIncreaseTime = .now
            } else if nil == cache.shrinker && (cache.desiredSize?.isSmallerThan(bounds.size) ?? false) {
                log("Desired size \(cache.desiredSize.orNilString) is smaller than current rendered size \(bounds.size), so starting shrinker…")

                startShrinker(cache: &cache)
            }

            if cache.lastRenderedSize != bounds.size {
//                log("Previously rendered in bounds \(cache.lastRenderedSize), now rendering in \(bounds.size).")

                if !(cache.lastRenderedSize?.encompasses(bounds.size) ?? false) {
                    log("Bounds grew; previously rendered in bounds \(cache.lastRenderedSize.orNilString), now rendering in \(bounds.size).")
                }

                cache.lastRenderedSize = bounds.size
            }
        }

        subview.place(at: bounds.origin, proposal: proposal) // ❌
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
}

@MainActor
struct ShrinkSlowly<C: View>: View {
    @State var tick = false

    let delay: Duration
    let speed: Double

    let content: () -> C

    public init(delay: Duration = .seconds(3),
                speed: Double = 100,
                @ViewBuilder content: @escaping () -> C) {
        self.delay = delay
        self.speed = speed
        self.content = content
    }

    var body: some View {
        let _ = tick // Have to explicitly reference `tick` in order to be re-run when `tick` changes.

        ShrinkSlowlyLayout(tick: $tick,
                           delay: delay,
                           speed: speed) {
            content()
        }
    }
}

struct ContentView: View {
    @State var width: CGFloat = 400

    var body: some View {
        VStack {
            let text = String(repeating: "•", count: Int(width) / 5)

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.gray)
                    .frame(width: width, height: 100)
                    .border(.black, width: 1)
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(text)
                    .backgroundStyle(.gray)
                    .border(.black, width: 1)
                Text("Right")
            }

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.red)
                    .strokeBorder(.black, style: .init(lineWidth: 2, dash: [3, 3]))
                    .frame(width: width, height: 100)
                //                .animation(/*@START_MENU_TOKEN@*/.easeIn/*@END_MENU_TOKEN@*/.delay(1), value: frameSize)

                //                .keyframeAnimator(initialValue: frameSize, trigger: frameSize) {
                //                    $0.frame(width: $1.width, height: $1.height)
                //                } keyframes: { value in
                //                    KeyframeTrack(\.width) {
                //                        let _ = log("value:", value, "frameSize:", frameSize)
                //
                //                        LinearKeyframe(frameSize.width, duration: frameSize.width < value.width ? 10 : 0.5)
                //                    }
                //                }

                //                .phaseAnimator([1, 2], trigger: frameSize) {
                //                    let _ = log("phaseAnimator:", $0, $1)
                //                    $0.frame(width: frameSize.width, height: frameSize.height)
                //                } animation: {
                //                    log("animation:", $0)
                //                    return Animation.linear(duration: $0)
                //                }

                //                .border(.black, width: 1)
                    .animation(Animation(Custom()).delay(1), value: width)
                    .border(.black, width: 1)
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(text)
                    .backgroundStyle(.red)
//                    .strokeBorder(.black, style: .init(lineWidth: 2, dash: [3, 3]))
                    .animation(Animation(Custom()).delay(1), value: width)
                    .border(.black, width: 1)
                Text("Right")
            }

//            HStack {
//                Text("Left")
//
//                ShrinkSlowly {
//                    Rectangle()
//                        .fill(.blue)
//                }.border(FillShapeStyle(), width: 2)
//                    .frame(width: width, height: 100)
//                    .border(.black, width: 1)
//
//                Text("Right")
//            }

//            HStack {
//                Text("Left")
//
//                ShrinkSlowly {
//                    Text(text)
//                        .backgroundStyle(.blue)
//                }.border(FillShapeStyle(), width: 2)
//                    .frame(width: width, height: 100)
//                    .border(.black, width: 1)
//
//                Text("Right")
//            }

//            HStack {
//                Text("Left")
//
//                ShrinkSlowly {
//                    Rectangle()
//                        .fill(.cyan)
//                        .frame(width: width, height: 100)
//                }.border(FillShapeStyle(), width: 2)
//                    .border(.black, width: 1)
//
//                Text("Right")
//            }

            HStack {
                Text("Left")

                ShrinkSlowly {
                    Text(text)
                        .backgroundStyle(.cyan)
                }.border(FillShapeStyle(), width: 2)
                    .border(.black, width: 1)

                Text("Right")
            }

            HStack {
                Button("Shrink") {
                    width /= 2
                    log("New width:", width)
                }

                Button("Grow") {
                    width *= 2
                    log("New width:", width)
                }
            }
        }
        .frame(width: 1000, height: 500)
        .padding()
    }
}

#Preview {
    ContentView()
}
