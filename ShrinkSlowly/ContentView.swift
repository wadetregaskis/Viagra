//
//  ContentView.swift
//  ShrinkSlowly
//
//  Created by Wade Tregaskis on 18/5/2024.
//

import SwiftUI

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
                print("💩 value:", value, "context:", fuckYouSwift)
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
        print("Making cache.")
        return Cache()
    }

    func updateCache(_ cache: inout Self.Cache,
                     subviews: Self.Subviews) {
        print("No update cache for you!")
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Cache) -> CGSize {
        guard let subview = subviews.first, 1 == subviews.count else {
            print("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return CGSize(width: 0, height: 0)
        }

        let subviewResponse = subview.sizeThatFits(proposal)

        let key = FuckingProposedViewSize(proposal)
        let result: CGSize

        if let cachedValue = cache[key] {
            if cachedValue.width >= subviewResponse.width && cachedValue.height >= subviewResponse.height {
                print("Cached value \(cachedValue) is >= subviewResponse \(subviewResponse).")
                return cachedValue
            }

            result = CGSize(width: max(subviewResponse.width,
                                       cachedValue.width),
                            height: max(subviewResponse.height,
                                        cachedValue.height))

            print("Cached value \(cachedValue) is not >= subviewResponse \(subviewResponse), so merging them to \(result).")
        } else {
            print("No cached value for \(key); using subviewResponse:", subviewResponse)
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
            print("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return
        }

        print("Placing subview in bounds \(bounds) with proposal \(proposal).")

        subview.place(at: bounds.origin, proposal: proposal) // ❌
//        subview.place(at: bounds.origin, proposal: .unspecified) // ❌
//        subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size)) // ❌
    }
}

struct ShrinkSlowlyLayout: Layout {
    let tick: Int

    let delay: ContinuousClock.Duration
    @Binding var lastIncreaseTime: ContinuousClock.Instant?
    @Binding var lastRenderedSize: CGSize?
    @Binding var needsToShrink: Bool

    struct FuckingProposedViewSize: Hashable {
        var width: CGFloat?
        var height: CGFloat?

        init(_ proposal: ProposedViewSize) {
            self.width = proposal.width
            self.height = proposal.height
        }
    }

    struct Cache {
        var current = [FuckingProposedViewSize: CGSize]()
        var target = [FuckingProposedViewSize: CGSize]()
        var lastRenderedSize: CGSize? = nil

        init() {}
    }

    func makeCache(subviews: Self.Subviews) -> Self.Cache {
        print("Making cache.")
        return Cache()
    }

    func updateCache(_ cache: inout Self.Cache,
                     subviews: Self.Subviews) {
        print("No update cache for you!")
    }

    func sizeThatFits(proposal: ProposedViewSize,
                      subviews: Subviews,
                      cache: inout Cache) -> CGSize {
        guard let subview = subviews.first, 1 == subviews.count else {
            print("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return CGSize(width: 0, height: 0)
        }

        let subviewResponse = subview.sizeThatFits(proposal)

        let key = FuckingProposedViewSize(proposal)

        cache.target[key] = subviewResponse

        let result: CGSize

        if let cachedValue = cache.current[key] {
            if !needsToShrink && subviewResponse != cachedValue {
                print("Target differs from current value for \(proposal); needs to shrink.")

                DispatchQueue.main.async {
                    needsToShrink = true
//                    lastIncreaseTime = .now
                }
            }

            if cachedValue.width >= subviewResponse.width && cachedValue.height >= subviewResponse.height {
                print("Cached value for \(proposal) is \(cachedValue) which is >= subviewResponse \(subviewResponse).")

                if subviewResponse == cachedValue {
                    if needsToShrink && cache.target == cache.current {
                        print("Target met - no longer need to shrink.")

                        DispatchQueue.main.async {
                            needsToShrink = false
//                            lastIncreaseTime = nil
                        }
                    }

                    return cachedValue
                } else {
                    if let lastIncreaseTime, .zero >= lastIncreaseTime + delay - .now {
                        print("Shrinking slightly (lastIncreaseTime: \(lastIncreaseTime), delay: \(delay), now: \(ContinuousClock.now))…")
                        let slightlySmallerValue = CGSize(width: max(subviewResponse.width, cachedValue.width - 1),
                                                          height: max(subviewResponse.height, cachedValue.height - 1))

                        cache.current[key] = slightlySmallerValue
                        return slightlySmallerValue
                    } else {
                        print("Non-shrinker update (not currently shrinking or still in delay period; lastIncreaseTime: \(lastIncreaseTime)).")
                        return cachedValue
                    }
                }
            }

            result = CGSize(width: max(subviewResponse.width,
                                       cachedValue.width),
                            height: max(subviewResponse.height,
                                        cachedValue.height))

            print("Cached value for \(proposal) is \(cachedValue) which is not >= subviewResponse \(subviewResponse), so merging them to \(result).")
        } else {
            result = subviewResponse

            print("No cached value for \(proposal); using subviewResponse:", subviewResponse)
        }

//        DispatchQueue.main.async {
//            lastIncreaseTime = .now
//        }

        cache.current[key] = result

        return result
    }

    func placeSubviews(in bounds: CGRect,
                       proposal: ProposedViewSize,
                       subviews: Subviews,
                       cache: inout Cache) {
        guard let subview = subviews.first, 1 == subviews.count else {
            print("ShrinkSlowly only works with one subview; found:", dump(subviews))
            return
        }

        print("Placing subview in bounds \(bounds) with proposal \(proposal).")

        if (proposal.width?.isFinite ?? false) && (proposal.height?.isFinite ?? false) && cache.lastRenderedSize != bounds.size {
//            print("Previously rendered in bounds \(cache.lastRenderedSize), now rendering in \(bounds.size).")

            if !(cache.lastRenderedSize?.encompasses(bounds.size) ?? false) {
                print("Bounds grew; previously rendered in bounds \(cache.lastRenderedSize), now rendering in \(bounds.size).")

                DispatchQueue.main.async {
                    lastIncreaseTime = .now
                }
            }

            cache.lastRenderedSize = bounds.size
        }

        subview.place(at: bounds.origin, proposal: proposal) // ❌
//        subview.place(at: bounds.origin, proposal: .unspecified) // ❌
//        subview.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size)) // ❌
    }
}

extension CGSize {
    func fitsWithin(_ other: CGSize) -> Bool {
        self.width <= other.width && self.height <= other.height
    }

    func encompasses(_ other: CGSize) -> Bool {
        self.width >= other.width && self.height >= other.height
    }
}

@MainActor
struct ShrinkSlowly<C: View>: View {
    @State var tick = 0
    @State var lastIncreaseTime: ContinuousClock.Instant? = nil
    @State var lastRenderedSize: CGSize? = nil

//    @State var needsToShrink: Bool = false
    @State var shrinker: Task<Void, Never>? = nil

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
        let needsToShrink = Binding<Bool>(get: {
            nil != shrinker
        }, set: {
            if $0 {
                if nil == shrinker {
                    print("Starting shrinker…")

                    shrinker = Task {
                        do {
                            while !Task.isCancelled {
                                delayLoop: while true {
                                    guard let lastIncreaseTime else {
                                        print("No last increase time!")
                                        throw CancellationError()
                                    }

                                    let startShrinkingAt = lastIncreaseTime + delay
                                    let durationUntilShrinkingStarts = startShrinkingAt - .now

                                    if .zero < durationUntilShrinkingStarts {
                                        print("In delay period before shrink (for another \(durationUntilShrinkingStarts))…")
                                        try await Task.sleep(for: durationUntilShrinkingStarts)
                                    } else {
                                        print("No delay (durationUntilShrinkingStarts: \(durationUntilShrinkingStarts), startShrinkingAt: \(startShrinkingAt), now: \(ContinuousClock.now)).")
                                        break delayLoop
                                    }
                                }

                                print("TICK")
                                tick += 1
                                try await Task.sleep(for: .seconds(1) / speed)
                                //                            lastIncreaseTime = nil
                            }
                        } catch {
                            print("Shrinker cancelled.")
                        }
                    }
                } else {
                    print("Shrinker needed and already running.")
                }
            } else {
                print("Shrinker no longer needed; cancelling…")
                shrinker?.cancel()
                shrinker = nil
            }
        })

        ShrinkSlowlyLayout(tick: tick,
                           delay: delay,
                           lastIncreaseTime: $lastIncreaseTime,
                           lastRenderedSize: $lastRenderedSize,
                           needsToShrink: needsToShrink) {
            content()
        }.onDisappear {
            shrinker?.cancel()
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
                //                        let _ = print("value:", value, "frameSize:", frameSize)
                //
                //                        LinearKeyframe(frameSize.width, duration: frameSize.width < value.width ? 10 : 0.5)
                //                    }
                //                }

                //                .phaseAnimator([1, 2], trigger: frameSize) {
                //                    let _ = print("phaseAnimator:", $0, $1)
                //                    $0.frame(width: frameSize.width, height: frameSize.height)
                //                } animation: {
                //                    print("animation:", $0)
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
                    print("New width:", width)
                }

                Button("Grow") {
                    width *= 2
                    print("New width:", width)
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
