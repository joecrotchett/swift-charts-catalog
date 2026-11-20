import CoreGraphics

/// Every spacing, size and corner constant the app's own views use.
enum Layout {
    static let screenPadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 20
    static let tightSpacing: CGFloat = 4
    static let itemSpacing: CGFloat = 8
    static let panelPadding: CGFloat = 16
    static let panelCornerRadius: CGFloat = 14
    static let badgeCornerRadius: CGFloat = 6
    static let badgeHorizontalPadding: CGFloat = 8
    static let badgeVerticalPadding: CGFloat = 3
    /// The chart's height in a compact width, and in a regular one.
    static let chartHeightCompact: CGFloat = 260
    static let chartHeightRegular: CGFloat = 360
    /// The narrowest a chart of a `ChartPair` is drawn side by side: about what one chart gets on a phone (338 on
    /// iPhone 17), so going side by side never gives a chart less room than stacking would.
    static let chartPairMinimumWidth: CGFloat = 320
    /// The widest a screen's content grows on a large display.
    static let readableWidth: CGFloat = 720
    static let codeGutterSpacing: CGFloat = 12
    static let codeLineSpacing: CGFloat = 3
    static let codePadding: CGFloat = 12
}
