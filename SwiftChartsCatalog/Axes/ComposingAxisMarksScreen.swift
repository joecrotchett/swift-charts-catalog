import Accessibility
import Charts
import SwiftUI

/// "Composing axis marks": an axis built from grid line, tick and label as separate parts, in one
/// `AxisMarks` or in two at different values.
struct ComposingAxisMarksScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ComposingAxisMarksViewModel()
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var summary: ComposingAxisMarksSummary {
        viewModel.summary(locale: locale, isLargeText: dynamicTypeSize >= .accessibility3)
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: summary.headline,
            explanation: summary.explanation,
            snippets: viewModel.snippets
        ) {
            ComposingAxisMarksChart(
                summary: summary, composition: viewModel.composition, parts: viewModel.parts
            )
        } controls: {
            ComposingAxisMarksControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.parts.labels) {
            ComposingAxisMarksAnnouncer.announce(summary.labelsAnnouncement)
        }
    }
}

/// The drinks as bars, with a value axis built from the parts switched on.
struct ComposingAxisMarksChart: View {
    let summary: ComposingAxisMarksSummary
    let composition: ComposingAxisMarksComposition
    let parts: ComposingAxisMarksParts
    /// The width the chart was laid out at, to tell whether the drink names fit across.
    @State private var width: CGFloat = 0
    /// The width one drink name needs to be written across without an ellipsis, growing with the text.
    @ScaledMetric(relativeTo: .caption2) private var widthPerName = ComposingAxisMarksMetrics.widthPerName

    /// Turn the names to read top to bottom when they would be truncated: on the narrowest phones,
    /// and at larger text sizes.
    private var rotatesNames: Bool {
        width > 0 && width / CGFloat(max(summary.sales.count, 1)) < widthPerName
    }

    var body: some View {
        if summary.total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            let scale = summary.scale
            Chart(summary.sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, item.drink),
                        y: .value(CafeWording.cups, item.cups)
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: summary.locale))
            }
            // The axis values are added to the scale, so the domain is set from the same numbers.
            .chartYScale(domain: 0 ... scale.top)
            .chartXAxis {
                // Where the drink names no longer fit across, they turn to read top to bottom.
                // Otherwise the default category axis.
                if rotatesNames {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(orientation: .vertical)
                    }
                } else {
                    AxisMarks()
                }
            }
            .chartYAxis {
                switch composition {
                case .oneSet:
                    // snippet:composing-axis-marks-one-set
                    // With a closure, only the parts it lists are drawn at each value.
                    AxisMarks(values: scale.labelValues) {
                        if parts.gridLines {
                            AxisGridLine()
                        }
                        if parts.ticks {
                            AxisTick()
                        }
                        if parts.labels {
                            AxisValueLabel()
                        }
                    }
                // end
                case .twoSets:
                    // snippet:composing-axis-marks-two-sets
                    // Labels and ticks at every label step...
                    AxisMarks(values: scale.labelValues) {
                        if parts.ticks {
                            AxisTick()
                        }
                        if parts.labels {
                            AxisValueLabel()
                        }
                    }
                    // ...and grid lines at every half step, from a second AxisMarks.
                    AxisMarks(values: scale.minorGridValues) {
                        if parts.gridLines {
                            AxisGridLine()
                        }
                    }
                    // end
                }
            }
            .accessibilityChartDescriptor(ComposingAxisMarksChartDescriptor(summary: summary))
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.size.width
            } action: { newWidth in
                width = newWidth
            }
        }
    }
}

/// Constants that belong to this chart's axis.
private enum ComposingAxisMarksMetrics {
    /// Measured at the default text size: "Americano" fits across at 66 points per drink and is cut
    /// short at 62.
    static let widthPerName: CGFloat = 64
}

/// One switch per part, and how many `AxisMarks` the axis is written with.
struct ComposingAxisMarksControls: View {
    @Bindable var viewModel: ComposingAxisMarksViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Value axis", selection: $viewModel.composition) {
                ForEach(ComposingAxisMarksComposition.allCases) { composition in
                    Text(composition.title).tag(composition)
                }
            }
            Toggle("AxisGridLine", isOn: $viewModel.parts.gridLines)
            Toggle("AxisTick", isOn: $viewModel.parts.ticks)
            Toggle("AxisValueLabel", isOn: $viewModel.parts.labels)
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
enum ComposingAxisMarksAnnouncer {
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Composing axis marks") {
    NavigationStack {
        if let screen = Catalog.screen(id: "axes/composing-axis-marks") {
            ComposingAxisMarksScreen(screen: screen)
        }
    }
}

#Preview("Two sets, no labels") {
    let viewModel = ComposingAxisMarksViewModel()
    let parts = ComposingAxisMarksParts(gridLines: true, ticks: true, labels: false)
    ComposingAxisMarksChart(
        summary: ComposingAxisMarksSummary(
            sales: viewModel.sales, scale: viewModel.scale(isLargeText: false), composition: .twoSets,
            parts: parts, locale: .current
        ),
        composition: .twoSets,
        parts: parts
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No sales") {
    ComposingAxisMarksChart(
        summary: ComposingAxisMarksSummary(
            sales: [], scale: ComposingAxisMarksScale(sales: [], isLargeText: false), composition: .oneSet,
            parts: ComposingAxisMarksParts(), locale: .current
        ),
        composition: .oneSet,
        parts: ComposingAxisMarksParts()
    )
}
