import SwiftUI

/// How tall a `ChartPanel` is.
enum ChartPanelHeight {
    /// The app's chart height, growing with the text size: every chart the same.
    case standard
    /// As tall as its content, for a chart that sizes itself (a compact card, a plot with a fixed aspect ratio,
    /// rows of a set height).
    case fitsContent
}

/// The container every chart in the app sits in: one background, padding and height for all of them.
struct ChartPanel<Content: View>: View {
    var height: ChartPanelHeight = .standard
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    /// Taller at larger text sizes, so labels inside the plot do not squeeze the marks.
    @ScaledMetric(relativeTo: .body) private var textScale: CGFloat = 1
    @ViewBuilder let content: Content

    var body: some View {
        sized
            .padding(Layout.panelPadding)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }

    @ViewBuilder private var sized: some View {
        switch height {
        case .standard:
            content
                .frame(height: (horizontalSizeClass == .regular ? Layout.chartHeightRegular : Layout.chartHeightCompact) * textScale)
        case .fitsContent:
            content
        }
    }
}

/// Two charts in one panel, each under its own title: side by side only when each chart then gets at least
/// `minimumChartWidth` (the pair measures its own width), otherwise one above the other, and always one above the
/// other at the accessibility text sizes. Each gets the panel's full height side by side, half of it stacked.
///
/// The width rule replaces a size-class rule: at regular width each chart got less width than on a phone (318
/// points on iPad against 338 on iPhone 17), and *Axes: the lower bound* cut its drink names to "Moc…". With the
/// app's readable width (720) a pair in a catalog screen's panel gets at most 318 points a chart, so it stacks there;
/// it goes side by side only in a wider container. A pair of compact charts can pass a smaller minimum:
/// ```swift
/// ChartPair(firstTitle: "Harbour", secondTitle: "Station", minimumChartWidth: 240) { first } second: { second }
/// ```
struct ChartPair<First: View, Second: View>: View {
    let firstTitle: String
    let secondTitle: String
    /// The narrowest each chart may be drawn side by side.
    var minimumChartWidth = Layout.chartPairMinimumWidth
    @ViewBuilder let first: First
    @ViewBuilder let second: Second
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The pair's own width, measured; zero until the first layout, which stacks.
    @State private var width: CGFloat = 0

    var body: some View {
        let sideBySide = Self.isSideBySide(
            width: width, minimumChartWidth: minimumChartWidth, accessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
        let layout = sideBySide
            ? AnyLayout(HStackLayout(alignment: .top, spacing: Layout.sectionSpacing))
            : AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.itemSpacing))
        layout {
            ChartPairItem(title: firstTitle, reservesTwoLines: sideBySide) { first }
            ChartPairItem(title: secondTitle, reservesTwoLines: sideBySide) { second }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { newWidth in
            width = newWidth
        }
    }

    /// Whether the two charts go side by side in `width`: each must get `minimumChartWidth` after the gap between
    /// them, and never at the accessibility text sizes.
    static func isSideBySide(width: CGFloat, minimumChartWidth: CGFloat, accessibilitySize: Bool) -> Bool {
        guard !accessibilitySize else { return false }
        return (width - Layout.sectionSpacing) / 2 >= minimumChartWidth
    }
}

/// One chart of a `ChartPair` under its title, which is a header for VoiceOver's rotor.
private struct ChartPairItem<Content: View>: View {
    let title: String
    /// Side by side, both titles keep two lines' height, so the two plots start level when one title wraps.
    let reservesTwoLines: Bool
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                // Whole at every text size: the chart below gives up the height, not the title.
                .lineLimit(reservesTwoLines ? 2 : Int.max, reservesSpace: reservesTwoLines)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            content
                .frame(maxHeight: .infinity)
        }
    }
}

#Preview("One chart") {
    ChartPanel {
        Color.blue.opacity(0.2)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Two charts") {
    ChartPanel {
        ChartPair(firstTitle: "Harbour", secondTitle: "Station") {
            Color.blue.opacity(0.2)
        } second: {
            Color.orange.opacity(0.2)
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Fits its content") {
    ChartPanel(height: .fitsContent) {
        Color.green.opacity(0.2).frame(height: 120)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
