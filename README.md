# Swift Charts Catalog

A reference app for iPhone and iPad (iOS 18 and later): Swift Charts concepts, one per screen, each with the code that produces it.

- **126 screens:** marks, mark modifiers, composition, data, scales, axes, legends, the plot area, annotations, interaction, vectorized plots, accessibility, design, 3D charts, availability and the framework's limits.
- **A Dashboard tab:** four linked charts over one set of data, with a shared selection.
- **See the code:** every screen shows the Swift that draws its chart, and the code follows the screen's controls.
- **Accessibility built in:** each chart has labelled elements for VoiceOver and a descriptor for the Audio Graph, and is laid out for the largest text sizes, Dark Mode and iPad.

The data is invented: two cafés, their drinks and their orders.

## Run it

Open `SwiftChartsCatalog.xcodeproj` in Xcode and run the `SwiftChartsCatalog` scheme on an iOS 18 or later simulator. The 3D screens need iOS 26.

The project has three targets: the app, its tests (Swift Testing), and a small UI-test tool that prints a screen's accessibility elements. The build runs `scripts/extract_snippets.py`, which collects the code each screen shows from the app's own source.

## How it was made

The app was built screen by screen with the [Swift Charts skill](https://github.com/joecrotchett/swift-charts-skill), an agent skill for Apple's Swift Charts framework, as the test of that skill: whatever a build or a review found wrong was corrected in the skill. Some comments in the source point at development notes (`Docs/…`) that are not part of this repository.

It is plain SwiftUI with an `@Observable` view model per screen, tested with Swift Testing, in Swift 6.
