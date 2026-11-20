import Accessibility
import Charts
import SwiftUI

/// "Layers counted twice": a chart drawn in two layers of the same data, first with both layers
/// visible to assistive technologies, then fixed.
struct LayersCountedTwiceScreen: View {
    let screen: CatalogScreen
    @State private var model = LayersCountedTwiceViewModel()
    /// Read here and passed in, so the headline, elements and descriptor write numbers and months alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Average cups a day, \(LayersCountedTwiceWording.cafe)",
            message: model.headline(locale: locale),
            explanation: """
            A second layer of the same data looks like decoration but is heard as data: an area under a line, \
            or points drawn over it, gives VoiceOver every month twice and the Audio Graph a doubled or extra series. \
            Hide the layer that repeats the data with accessibilityHidden, or draw the points with symbol on the line, \
            which adds no marks.
            """,
            snippets: model.snippets
        ) {
            LayersCountedTwiceChart(model: model, locale: locale)
        } controls: {
            LayersCountedTwiceControls(model: model, locale: locale)
            LayersCountedTwiceSpokenPanel(
                spoken: model.spokenText(locale: locale), isEmpty: model.hasNoData, hasDescriptor: model.hasDescriptor
            )
        }
    }
}

/// The case picker and the mistake toggle. Each redraws the chart, so each announces the change.
struct LayersCountedTwiceControls: View {
    @Bindable var model: LayersCountedTwiceViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Second layer", selection: $model.layerCase) {
                ForEach(LayersCountedTwiceCase.allCases) { layerCase in
                    Text(layerCase.title).tag(layerCase)
                }
            }
            MistakeToggle(title: "Leave both layers visible to VoiceOver", isShowingMistake: $model.isShowingMistake)
        }
        // With months of zeros the points case still draws, so only no months at all disables the controls.
        .disabled(model.hasNoMonths)
        .onChange(of: model.layerCase) { announceChange() }
        .onChange(of: model.isShowingMistake) { announceChange() }
    }

    private func announceChange() {
        // The skill's announcement; the app's iOS 18 target needs no check for the iOS 17 form.
        AccessibilityNotification.Announcement(model.announcement(locale: locale)).post()
    }
}

/// The chart for the current state, with the descriptor in the fixed state only.
struct LayersCountedTwiceChart: View {
    let model: LayersCountedTwiceViewModel
    let locale: Locale

    var body: some View {
        if model.hasNoData {
            ContentUnavailableView(
                "No months yet",
                systemImage: "chart.line.uptrend.xyaxis",
                description: Text("Average cups a day appear here, one point per month.")
            )
        } else {
            let months = model.months(locale: locale)
            let yDomain = model.yDomain(locale: locale)
            let marks = LayersCountedTwiceMarks(model: model, months: months, yDomain: yDomain, locale: locale)
                // A new identity for each state, so VoiceOver does not keep the elements of the last one.
                .id("\(model.layerCase.rawValue)-\(model.isShowingMistake)")
            if model.hasDescriptor {
                marks.accessibilityChartDescriptor(
                    LayersCountedTwiceDescriptor(months: months, yDomain: yDomain, locale: locale)
                )
            } else {
                // The mistake keeps the framework's own Audio Graph: it is built from both layers, which is
                // the mistake being shown. A descriptor would replace it and hide what the layers do.
                marks
            }
        }
    }
}

/// The four charts: each case with both layers heard, and fixed.
struct LayersCountedTwiceMarks: View {
    let model: LayersCountedTwiceViewModel
    let months: [LayersCountedTwiceMonth]
    /// The one value scale, which the descriptor's y axis also gives.
    let yDomain: ClosedRange<Double>
    let locale: Locale

    var body: some View {
        switch (model.layerCase, model.isShowingMistake) {
        case (.lineOverArea, true):
            // snippet:layers-counted-twice-area-both
            Chart(months) { month in
                // The fill repeats the line's data. Left visible, it is a second element at every month.
                AreaMark(
                    x: .value(CafeWording.month, month.name),
                    y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                )
                .foregroundStyle(LayersCountedTwiceStyle.areaFill)
                Plot {
                    LineMark(
                        x: .value(CafeWording.month, month.name),
                        y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                    )
                }
                .accessibilityLabel(model.elementLabel(for: month))
                .accessibilityValue(model.elementValue(for: month, locale: locale))
            }
            // end
            .modifier(LayersCountedTwiceAxes(months: months, yDomain: yDomain))
        case (.lineOverArea, false):
            // snippet:layers-counted-twice-area-hidden
            Chart(months) { month in
                AreaMark(
                    x: .value(CafeWording.month, month.name),
                    y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                )
                .foregroundStyle(LayersCountedTwiceStyle.areaFill)
                // The fill repeats the line's data: hidden, it leaves the elements and the Audio Graph.
                .accessibilityHidden(true)
                Plot {
                    LineMark(
                        x: .value(CafeWording.month, month.name),
                        y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                    )
                }
                .accessibilityLabel(model.elementLabel(for: month))
                .accessibilityValue(model.elementValue(for: month, locale: locale))
            }
            // end
            .modifier(LayersCountedTwiceAxes(months: months, yDomain: yDomain))
        case (.lineWithPoints, true):
            // snippet:layers-counted-twice-points-layer
            Chart(months) { month in
                Plot {
                    LineMark(
                        x: .value(CafeWording.month, month.name),
                        y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                    )
                }
                .accessibilityLabel(model.elementLabel(for: month))
                .accessibilityValue(model.elementValue(for: month, locale: locale))
                // A separate layer of points: a second element at every month, and a second series.
                PointMark(
                    x: .value(CafeWording.month, month.name),
                    y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                )
            }
            // end
            .modifier(LayersCountedTwiceAxes(months: months, yDomain: yDomain))
        case (.lineWithPoints, false):
            // snippet:layers-counted-twice-points-symbol
            Chart(months) { month in
                Plot {
                    LineMark(
                        x: .value(CafeWording.month, month.name),
                        y: .value(LayersCountedTwiceWording.averageCupsAxisTitle, month.cups)
                    )
                    // The points are drawn by the line itself: no marks of their own, nothing heard twice.
                    .symbol(.circle)
                }
                .accessibilityLabel(model.elementLabel(for: month))
                .accessibilityValue(model.elementValue(for: month, locale: locale))
            }
            // end
            .modifier(LayersCountedTwiceAxes(months: months, yDomain: yDomain))
        }
    }
}

/// The axes: the one value scale shared with the descriptor, and the month axis, every month named in
/// full, or at the accessibility text sizes every other month abbreviated, since six full names are cut
/// to a letter there. Grid lines stay at every month.
struct LayersCountedTwiceAxes: ViewModifier {
    let months: [LayersCountedTwiceMonth]
    let yDomain: ClosedRange<Double>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        let labelled = Set(months.enumerated().filter { !isLarge || $0.offset.isMultiple(of: 2) }.map(\.element.name))
        let shortNames = Dictionary(months.map { ($0.name, $0.shortName) }, uniquingKeysWith: { first, _ in first })
        content
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: months.map(\.name)) { value in
                    AxisGridLine()
                    if let name = value.as(String.self), labelled.contains(name) {
                        AxisValueLabel {
                            Text(isLarge ? shortNames[name] ?? name : name)
                        }
                    }
                }
            }
    }
}

/// What assistive technologies get in the current state, read on iOS, and how to hear it.
struct LayersCountedTwiceSpokenPanel: View {
    let spoken: LayersCountedTwiceSpokenText
    let isEmpty: Bool
    let hasDescriptor: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("What assistive technologies get")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Read on iOS 27 (simulator)")
                .font(.caption)
                .foregroundStyle(.secondary)
            if isEmpty {
                Text("No chart is drawn, so there is nothing to hear.")
            } else {
                Text(spoken.verdict)
                    .fixedSize(horizontal: false, vertical: true)
                LayersCountedTwiceSpokenList(
                    title: "VoiceOver elements (\(spoken.elements.count.formatted()))", lines: spoken.elements
                )
                LayersCountedTwiceSpokenList(title: "Audio Graph", lines: spoken.audioGraph)
                if !hasDescriptor {
                    Text("""
                    No chart descriptor in this state: one would replace the Audio Graph the two layers make, \
                    which is the mistake shown here. The fixed state carries one.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("""
            To hear it on a device: turn VoiceOver on and swipe through the chart, then use the rotor's \
            Audio Graph: Describe chart, Play Audio Graph.
            """)
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// A titled list of spoken lines, each its own line of text.
struct LayersCountedTwiceSpokenList: View {
    let title: String
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Text(line)
                    .font(.callout.monospaced())
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

/// The styling that belongs to this screen's marks.
private enum LayersCountedTwiceStyle {
    /// The area's fill: the line's colour, faint, so the line stays the data.
    static let areaFill = Color.blue.opacity(0.2)
}

#Preview("Both layers heard") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/layers-counted-twice") {
            LayersCountedTwiceScreen(screen: screen)
        }
    }
}

#Preview("No data") {
    LayersCountedTwiceChart(model: LayersCountedTwiceViewModel(summaries: []), locale: .current)
}
