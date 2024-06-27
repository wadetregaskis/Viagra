//
//  ContentView.swift
//  ViagraDemo
//
//  Created by Wade Tregaskis on 18/5/2024.
//

import Darwin
import SwiftUI
import Viagra


struct Custom: CustomAnimation {
    let duration = 1.0

    typealias CGSizeAP = AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>>

    func animate<V>(value: V, time: TimeInterval, context: inout AnimationContext<V>) -> V? where V : VectorArithmetic {
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

extension View {
    var dottedLineBorder: some View {
        self.overlay(
            Rectangle()
                .strokeBorder(.black, style: .init(lineWidth: 1, dash: [1, 1])))
    }
}

struct ContentView: View {
    @State var width: CGFloat = 100
    @State var x = ""
    @State var y = ""

    var body: some View {
        VStack(spacing: 10) {
            let rectangleHeight: CGFloat = 25

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

            Text("No animation nor shrink control")
                .font(.title)

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.gray)
                    .frame(width: width, height: rectangleHeight)
                    .dottedLineBorder
                Text("Right")
            }

            let text = String(repeating: "•", count: Int(width) / 5)

            HStack {
                Text("Left")
                Text(text)
                    .backgroundStyle(.gray)
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(x)
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(y)
                    .dottedLineBorder
                Text("Right")
            }

            Divider()

            Text("SwiftUI animation")
                .font(.title)

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.red)
                    .frame(width: width, height: rectangleHeight)
                    .animation(Animation(Custom()).delay(3), value: width)
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(text)
                    .animation(Animation(Custom()).delay(3), value: width)
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(x)
                    .animation(Animation(Custom()).delay(3), value: width)
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(y)
                    .animation(Animation(Custom()).delay(3), value: width)
                    .dottedLineBorder
                Text("Right")
            }

            Divider()

            Text("Viagra")
                .font(.title)

            Text("Never shrink")
                .font(.title2)

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.cyan)
                    .frame(width: width, height: rectangleHeight)
                    .neverShrink()
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(text)
                    .neverShrink()
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(x)
                    .neverShrink()
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(y)
                    .neverShrink()
                    .dottedLineBorder
                Text("Right")
            }

            Text("Shrink slowly (default delay & speed)")
                .font(.title2)
                .padding(.top, 10)

#if false // How *not* to use Viagra:
            HStack {
                Text("Left")

                Rectangle()
                    .fill(.blue)
                    .shrinkSlowly() // ❌ .frame(…) must be before .shrinkSlowly(…).
                    .frame(width: width, height: rectangleHeight)
                    .dottedLineBorder

                Text("Right")
            }

            HStack {
                Text("Left")

                Text(text)
                    .shrinkSlowly() // ❌ .frame(…) must be before .shrinkSlowly(…).
                    .frame(width: width, height: rectangleHeight)
                    .dottedLineBorder

                Text("Right")
            }
#endif

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.cyan)
                    .frame(width: width, height: rectangleHeight)
                    .shrinkSlowly()
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(text)
                    .shrinkSlowly()
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(x)
                    .shrinkSlowly()
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(y)
                    .shrinkSlowly()
                Text("Right")
            }

            Text("Shrink slowly (no delay, default speed)")
                .font(.title2)
                .padding(.top, 10)

            HStack {
                Text("Left")
                Rectangle()
                    .fill(.cyan)
                    .frame(width: width, height: rectangleHeight)
                    .shrinkSlowly(delay: .milliseconds(10))
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(text)
                    .shrinkSlowly(delay: .milliseconds(10))
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(x)
                    .shrinkSlowly(delay: .milliseconds(10))
                    .dottedLineBorder
                Text("Right")
            }

            HStack {
                Text("Left")
                Text(y)
                    .shrinkSlowly(delay: .milliseconds(10))
                    .dottedLineBorder
                Text("Right")
            }

            Spacer()
        }
        .padding()
        .task {
            var count = 0

            while !Task.isCancelled {
                let now = Date.now.timeIntervalSinceReferenceDate
                
                x = String(repeating: "█", count: Int(fabs(sin(now) + sin(now * 1.5)) * 20))
                
                y = count.formatted()
                count &+= 1

                try? await Task.sleep(for: .milliseconds(1 / 60.0))
            }
        }
    }
}

#Preview {
    ContentView()
}
