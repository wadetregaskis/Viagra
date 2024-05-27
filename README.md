#  Viagra

[![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/wadetregaskis/Viagra.svg)]()
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fwadetregaskis%2FViagra%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/wadetregaskis/Viagra)
[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fwadetregaskis%2FViagra%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/wadetregaskis/Viagra)

Take control over SwiftUI view shrinkage.

SwiftUI views will by default change size instantly whenever their contents dictate.  This can lead to very visually noisy behaviour with visual content jittering and shifting about unpleasantly.  This package provides two simple view modifiers to address that.

### NeverShrink

Views to which this is applied never shrink while visible.  They may enlarge at any time and in any dimensions.  e.g.:

```swift
Text(value.formatted())
    .neverShrink()
```

This is great for views where you don't want any unnecessary layout changes (resulting from the contents shrinking) and don't mind potentially wasting some space (at times when the modified view is smaller than its maximum).

### ShrinkSlowly

This view modifier does allow the view to eventually shrink, but only after a delay, and only at a certain rate (effectively animating the reduction in size).  e.g.:

```swift
Text(value.formatted())
    .shrinkSlowly()
```

You can customise the delay and speed from their defaults of three seconds and 30 pixels per second, e.g.:

```swift
Text(value.formatted())
    .shrinkSlowly(delay: .seconds(5),
                  speed: 10)
```

This is good for views which may need to expand temporarily, but which generally are smaller than their peak.  Allowing them to _eventually_ shrink ensures you don't waste space for long, while still preventing ugly sensitivity to size changes.

## Demo app

A demo application is included (in the "Demo" subfolder) showing some basic use-cases.

<video width="626" height="1035" autoplay controls loop="true" playsinline="true" src="https://github.com/wadetregaskis/Viagra/assets/863283/f885cbce-944b-4e73-aa2d-3c91cce34dcd"></video>

Notice in particular the subtle but lovely difference in even a simple text view showing a numeric value - by default jittery and unsure of itself, applying Viagra makes the text view confident and consistent.
