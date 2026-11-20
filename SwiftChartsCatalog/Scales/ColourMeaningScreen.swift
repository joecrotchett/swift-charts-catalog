import Accessibility
import Charts
import SwiftUI

/// "Colour that means something": `foregroundStyle(by:)` makes a colour scale, and
/// `chartForegroundStyleScale` sets it. Add cafés until the automatic colours repeat.
struct ColourMeaningScreen: View {
    let screen: CatalogScreen
    @State private var model = ColourMeaningViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups a year, by café",
            message: model.summary(locale: locale).headline,
            explanation: """
            foregroundStyle(by:) turns the cafés into a colour scale: Swift Charts hands out blue, green, \
            orange, purple, red, cyan and yellow in the order the cafés appear, then starts again. Those \
            colours mean nothing, and past seven they stop telling cafés apart. chartForegroundStyleScale \
            sets the scale: here each café gets a colour of its own, which it keeps however many are shown.
            """,
            snippets: model.snippets
        ) {
            ColourMeaningChart(rows: model.rows, colours: model.colours, locale: locale)
        } controls: {
            ColourMeaningControls(model: model, locale: locale)
        }
    }
}

/// The colour picker and the number of cafés. Each change to the chart is announced.
struct ColourMeaningControls: View {
    @Bindable var model: ColourMeaningViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Colours", selection: $model.colours) {
                ForEach(ColourMeaningColours.allCases) { colours in
                    Text(colours.title).tag(colours)
                }
            }
            LabeledStepper(
                title: "Cafés", value: $model.cafeCount, in: model.countRange,
                valueText: model.cafeCount.formatted(.number.locale(locale)),
                spokenValue: CafeWording.cafes(model.cafeCount, locale: locale)
            )
        }
        .onChange(of: model.cafeCount) {
            AccessibilityNotification.Announcement(model.countAnnouncement(locale: locale)).post()
        }
        .onChange(of: model.colours) {
            AccessibilityNotification.Announcement(model.coloursAnnouncement(locale: locale)).post()
        }
    }
}

/// The chart with automatic colours or with a colour set for each café, or a placeholder when there
/// are no cafés.
struct ColourMeaningChart: View {
    let rows: [ColourMeaningRow]
    let colours: ColourMeaningColours
    let locale: Locale

    var body: some View {
        if rows.isEmpty {
            ContentUnavailableView(
                "No cafés",
                systemImage: "cup.and.saucer",
                description: Text("The chain’s cafés appear here, one row each.")
            )
        } else {
            Group {
                switch colours {
                case .automatic:
                    ColourMeaningPlot(rows: rows, locale: locale)
                case .explicit:
                    // snippet:colour-meaning-explicit
                    ColourMeaningPlot(rows: rows, locale: locale)
                        // The domain is the cafés shown, in data order, so the legend reads as the rows
                        // do; the mapping gives each café its own colour.
                        .chartForegroundStyleScale(domain: rows.map(\.cafe)) { cafe in
                            cafe.colour
                        }
                    // end
                }
            }
            .accessibilityChartDescriptor(ColourMeaningChartDescriptor(rows: rows, colours: colours, locale: locale))
        }
    }
}

/// One point per café at its yearly cups, coloured by café.
struct ColourMeaningPlot: View {
    let rows: [ColourMeaningRow]
    let locale: Locale

    private var usesLogScale: Bool {
        ColourMeaningAxis.usesLogScale(rows)
    }

    private var decades: [Int] {
        ColourMeaningAxis.decades(rows)
    }

    private var axisFormat: IntegerFormatStyle<Int> {
        IntegerFormatStyle<Int>.number.notation(.compactName).locale(locale)
    }

    var body: some View {
        // snippet:colour-meaning-automatic
        Chart(rows) { row in
            Plot {
                PointMark(
                    x: .value(CafeWording.yearlyCupsAxisTitle, row.yearlyCups),
                    y: .value(CafeWording.store, row.cafe)
                )
                // This one modifier makes the colour scale: a colour per café, and a legend.
                .foregroundStyle(by: .value(CafeWording.store, row.cafe))
                .symbolSize(ColourMeaningMetrics.pointArea)
            }
            .accessibilityLabel(row.cafe.rawValue)
            .accessibilityValue("\(CafeWording.cups(row.yearlyCups, locale: locale)) a year")
        }
        // end
        .chartXScale(type: usesLogScale ? .log : .linear)
        .chartXAxis {
            if usesLogScale {
                AxisMarks(format: axisFormat, preset: .aligned, values: decades)
            } else {
                AxisMarks(format: axisFormat, preset: .aligned)
            }
        }
        // The names beside the rows, not above them, where the smallest café's point covered its name.
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading)
        }
    }
}

/// Constants that belong to this chart's marks and axis.
private enum ColourMeaningMetrics {
    /// Large enough for each point's colour to be seen, in square points.
    static let pointArea: CGFloat = 120
}

/// The value axis, worked out in one place for the chart and the Audio Graph, so both cover the same range.
nonisolated enum ColourMeaningAxis {
    /// Labels at each power of ten on the log axis: a sequence read at a glance.
    static let allDecades = [100, 1000, 10000, 100_000, 1_000_000]

    /// Yearly cups span more than three orders of magnitude, so they go on a log scale, which needs
    /// every value above zero. With a zero the scale stays linear and the zero is still drawn.
    static func usesLogScale(_ rows: [ColourMeaningRow]) -> Bool {
        rows.allSatisfy { $0.yearlyCups > 0 }
    }

    /// The powers of ten from the one at or below the smallest value to the one at or above the
    /// largest. Axis mark values widen the scale, so a decade beyond the data would leave it empty,
    /// and the drawn log axis runs from the first of these to the last.
    static func decades(_ rows: [ColourMeaningRow]) -> [Int] {
        let cups = rows.map(\.yearlyCups)
        guard let lowest = cups.min(), let highest = cups.max() else { return [] }
        return allDecades.filter { $0 * 10 > lowest && $0 / 10 < highest }
    }

    /// The range the value axis draws: from the first decade to the last on the log scale (from the
    /// data's ends if no decade fits), from zero to the largest value on the linear one.
    static func drawnRange(_ rows: [ColourMeaningRow]) -> ClosedRange<Double> {
        let cups = rows.map { Double($0.yearlyCups) }
        let highest = cups.max() ?? 0
        guard usesLogScale(rows) else { return 0 ... highest }
        let decades = decades(rows)
        if let first = decades.first, let last = decades.last {
            return Double(first) ... Double(last)
        }
        return (cups.min() ?? 0) ... highest
    }
}

/// The chart for the Audio Graph: the cafés, their yearly cups, and in the summary what the colours do.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ColourMeaningChartDescriptor: AXChartDescriptorRepresentable {
    let rows: [ColourMeaningRow]
    let colours: ColourMeaningColours
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = ColourMeaningSummary(rows: rows, colours: colours, locale: locale)
        let locale = locale
        // The drawn scale: the log axis runs over its decades, not the data; the linear one from zero.
        let range = ColourMeaningAxis.drawnRange(rows)
        return AXChartDescriptor(
            title: "Cups a year at the chain’s cafés, coloured by café",
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(
                title: CafeWording.store,
                categoryOrder: rows.map(\.cafe.rawValue)
            ),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.yearlyCupsAxisTitle,
                range: range,
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: "Cafés of the chain",
                isContinuous: false,
                dataPoints: rows.map { AXDataPoint(x: $0.cafe.rawValue, y: Double($0.yearlyCups)) }
            )]
        )
    }
}

#Preview("Cafés") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/colour-that-means-something") {
            ColourMeaningScreen(screen: screen)
        }
    }
}

#Preview("Ten cafés, automatic") {
    ColourMeaningChart(rows: ColourMeaningViewModel(cafeCount: 10).rows, colours: .automatic, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No cafés") {
    ColourMeaningChart(rows: [], colours: .automatic, locale: .current)
}
