import Accessibility
import Charts
import SwiftUI

/// "Colour ramps": a number encoded as colour, the gradient legend it gets, and choosing the ramp.
struct ColourRampsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ColourRampsViewModel()
    /// Read here and passed in, so the headline, elements and Audio Graph write numbers alike.
    @Environment(\.locale) private var locale
    /// The appearance the chart is drawn in: the default ramp's low end is pale in light and near black in dark,
    /// so the headline and the explanation say what is drawn.
    @Environment(\.colorScheme) private var colorScheme

    private var isDark: Bool {
        colorScheme == .dark
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Change in cups against last month",
            message: viewModel.summary(locale: locale, isDark: isDark).headline,
            explanation: """
            foregroundStyle(by:) given a number shades each mark along one gradient and adds a gradient legend, \
            with values under it. chartForegroundStyleScale(range:) takes a Gradient to choose the ramp; for data \
            that crosses zero, a diverging ramp with a domain centred on zero makes zero its middle colour. The \
            default ramp’s low end is \(isDark ? "dark enough to vanish on a dark" : "pale enough to vanish on a light") \
            background, which is one reason to choose a ramp.
            """,
            snippets: viewModel.snippets
        ) {
            ColourRampsChart(summary: viewModel.summary(locale: locale, isDark: isDark), locale: locale)
        } controls: {
            ColourRampsControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.ramp) {
            colourRampsAnnounce(viewModel.announcement(locale: locale, isDark: isDark))
        }
    }
}

/// The gradient picker.
struct ColourRampsControls: View {
    @Bindable var viewModel: ColourRampsViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Gradient", selection: $viewModel.ramp) {
                ForEach(ColourRampsRamp.allCases) { ramp in
                    Text(ramp.title).tag(ramp)
                }
            }
        }
    }
}

/// The colours of the two ramps the app chooses. System colours, so they adapt to Dark Mode and
/// Increase Contrast.
enum ColourRampsPalette {
    static let custom = Gradient(colors: [.yellow, .red])
    static let diverging = Gradient(colors: [.orange, Color(.systemGray3), .blue])
}

/// One bar per drink, coloured by the same change its height shows; a placeholder when nothing changed.
struct ColourRampsChart: View {
    let summary: ColourRampsSummary
    let locale: Locale
    /// Room at each end of the change axis for the value written past a bar's end, growing with the text.
    @ScaledMetric(relativeTo: .caption) private var labelRoom = ColourRampsMetrics.labelRoom

    var body: some View {
        if summary.isEmpty {
            ContentUnavailableView(
                "No change to show",
                systemImage: "paintpalette",
                description: Text(summary.headline)
            )
        } else {
            // snippet:colour-ramps-encode
            Chart(summary.changes) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.changeAxisTitle, item.change),
                        y: .value(CafeWording.drink, item.drink)
                    )
                    // A number, not a category: one gradient across the marks, and a gradient legend.
                    .foregroundStyle(by: .value(CafeWording.changeAxisTitle, item.change))
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(ColourRampsSummary.movement(item.change, locale: locale))
                .annotation(position: item.change < 0 ? .leading : .trailing) {
                    Text(item.change, format: .number.sign(strategy: .always(includingZero: false)).locale(locale))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            // end
            .colourRampsScale(summary.ramp, limit: summary.divergingLimit)
            // One change axis for the chart and the descriptor, with room at each end for the bars' labels.
            .chartXScale(domain: summary.valueRange, range: .plotDimension(padding: min(labelRoom, ColourRampsMetrics.largestLabelRoom)))
            .accessibilityChartDescriptor(ColourRampsChartDescriptor(summary: summary))
        }
    }
}

extension View {
    /// Sets the colour scale for a ramp. The default ramp sets nothing.
    @ViewBuilder
    func colourRampsScale(_ ramp: ColourRampsRamp, limit: Int) -> some View {
        switch ramp {
        case .automatic:
            self
        case .custom:
            // snippet:colour-ramps-custom-gradient
            // A Gradient as the range replaces the colours; the domain stays automatic, rounded
            // outward past the data, so no bar reaches either end colour.
            chartForegroundStyleScale(range: ColourRampsPalette.custom)
        // end
        case .diverging:
            // snippet:colour-ramps-diverging
            // The domain runs as far below zero as above it, so zero lands on the middle colour.
            chartForegroundStyleScale(domain: -limit ... limit, range: ColourRampsPalette.diverging)
            // end
        }
    }
}

/// Constants for the chart's axis.
private enum ColourRampsMetrics {
    /// Points kept free at each end of the change axis at the default text size: about a label's width.
    static let labelRoom: CGFloat = 28
    /// The most room kept, whatever the text size.
    static let largestLabelRoom: CGFloat = 56
}

/// Posts an announcement that the chart changed, for people who cannot see it happen.
@MainActor
func colourRampsAnnounce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// The chart for the Audio Graph: one series of changes, said with their unit, and the ramp in the summary.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ColourRampsChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ColourRampsSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: summary.changes.map(\.drink)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.changeAxisTitle,
            range: summary.valueRange,
            gridlinePositions: []
        ) { value in
            CafeWording.count(value, locale: locale, as: ColourRampsSummary.movement(_:locale:))
        }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.changeAxisTitle,
            isContinuous: false,
            dataPoints: summary.changes.map { AXDataPoint(x: $0.drink, y: Double($0.change)) }
        )
        return AXChartDescriptor(
            title: "Change in cups against last month, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Colour ramps") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/colour-ramps") {
            ColourRampsScreen(screen: screen)
        }
    }
}

#Preview("Each ramp") {
    ScrollView {
        ForEach(ColourRampsRamp.allCases) { ramp in
            ColourRampsChart(
                summary: ColourRampsSummary(changes: CafeData.drinkChanges, ramp: ramp, locale: .current),
                locale: .current
            )
            .frame(height: Layout.chartHeightCompact)
            .padding(Layout.panelPadding)
        }
    }
}

#Preview("No change") {
    ColourRampsChart(
        summary: ColourRampsSummary(changes: [DrinkChange(drink: "Tea", change: 0)], ramp: .automatic, locale: .current),
        locale: .current
    )
}
