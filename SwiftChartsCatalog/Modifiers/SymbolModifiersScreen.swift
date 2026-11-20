import Accessibility
import Charts
import SwiftUI

/// "Symbols": `symbol(_:)` with a built-in shape, `symbol { }` with a view, and `symbolSize(_:)`.
struct SymbolModifiersScreen: View {
    let screen: CatalogScreen
    var days = SymbolModifiersSummary.sampleDays
    @State private var viewModel = SymbolModifiersViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers
    /// the way the chart's own axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day at the Harbour café",
            message: SymbolModifiersSummary(days: days, locale: locale).headline,
            explanation: """
            symbol(_:) puts one of the built-in shapes at every point of the line, and symbolSize(_:) sets its \
            size as an area in square points, not a width: 400 is only twice as wide as 100. symbol { } draws \
            any SwiftUI view there instead, at the view's own size: symbolSize(_:) does not change it, so with \
            a view the slider sets the view's frame.
            """,
            snippets: viewModel.snippets
        ) {
            SymbolModifiersChart(days: days, symbol: viewModel.symbol, area: viewModel.area, locale: locale)
        } controls: {
            SymbolModifiersControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The shape picker and the size slider. Both restyle the points and speak their own value,
/// so neither posts an announcement.
struct SymbolModifiersControls: View {
    @Bindable var viewModel: SymbolModifiersViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Symbol", selection: $viewModel.symbol) {
                ForEach(SymbolModifiersSymbol.allCases) { symbol in
                    Text(symbol.title).tag(symbol)
                }
            }
            LabeledSlider(
                title: "Symbol size",
                value: $viewModel.area,
                range: SymbolModifiersViewModel.areaRange,
                step: SymbolModifiersViewModel.areaStep,
                valueText: viewModel.areaText(locale: locale),
                spokenValue: viewModel.spokenArea(locale: locale)
            )
        }
    }
}

/// Constants that belong to this chart's marks.
private enum SymbolModifiersMetrics {
    /// Room at each end of both axes, so the largest symbols stay off the plot's edges.
    static let plotPadding: CGFloat = 14
    /// A labelled grid line once a week, a familiar step for two weeks of days.
    static let daysPerAxisLabel = 7
}

/// Two weeks of the Harbour café's cups as a line, with the chosen symbol at every day.
struct SymbolModifiersChart: View {
    let days: [DailySales]
    let symbol: SymbolModifiersSymbol
    let area: Double
    let locale: Locale

    var body: some View {
        let summary = SymbolModifiersSummary(days: days, locale: locale)
        if days.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here as a line, with a symbol at every day.")
            )
        } else {
            Chart {
                ForEach(days) { day in
                    // A labelled Plot per day, so each is read as its date and cups. The marks still join into one line.
                    // Each point is the day's midnight in UTC, an instant, with no `unit:`: a unit would put it at
                    // noon, half a day past the grid line and label that name it.
                    Plot {
                        if let shape = symbol.shape {
                            // snippet:symbol-modifiers-shape
                            LineMark(
                                x: .value(CafeWording.day, day.day),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            // One of the built-in shapes at every point of the line.
                            .symbol(shape)
                            // An area in square points: 100 is a 10 by 10 point square's worth.
                            .symbolSize(area)
                            // end
                        } else {
                            // snippet:symbol-modifiers-view
                            LineMark(
                                x: .value(CafeWording.day, day.day),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            // Any SwiftUI view as the symbol, drawn as written. symbolSize(_:) does not
                            // reach it, so the view is given its own size: the side of a square of that area.
                            .symbol {
                                Image(systemName: "cup.and.saucer.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: area.squareRoot(), height: area.squareRoot())
                                    .foregroundStyle(.blue)
                                    .accessibilityHidden(true)
                            }
                            // end
                        }
                    }
                    .accessibilityLabel(summary.elementLabel(for: day))
                    .accessibilityValue(summary.elementValue(for: day))
                }
                ForEach(summary.busiestDays) { busiest in
                    // The day the headline names, written over its point: the axis labels a day a week and may
                    // not label it. A point of no size to hang the label on; the day's element reads the value.
                    PointMark(x: .value(CafeWording.day, busiest.day), y: .value(CafeWording.cups, busiest.cups))
                        .symbolSize(0)
                        .accessibilityHidden(true)
                        .headlineCallout(summary.calloutText(for: busiest))
                }
            }
            .chartXAxis {
                // The days were made in UTC: the axis is told so, or it marks and labels them in the device's zone.
                AxisMarks(values: .stride(by: .day, count: SymbolModifiersMetrics.daysPerAxisLabel, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month().day())
                }
            }
            .yAxisTitle(CafeWording.cupsAxisTitle)
            .chartXScale(range: .plotDimension(padding: SymbolModifiersMetrics.plotPadding))
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain, range: .plotDimension(padding: SymbolModifiersMetrics.plotPadding))
            .accessibilityChartDescriptor(SymbolModifiersChartDescriptor(days: days, locale: locale))
        }
    }
}

/// The chart for the Audio Graph: written-out dates, cups said with their unit, one connected line.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SymbolModifiersChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = SymbolModifiersSummary(days: days, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.spokenDate($0.day) }
        )
        // The drawn value axis, from zero to its rounded top.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: days.map { AXDataPoint(x: summary.spokenDate($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the Harbour café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Symbols") {
    NavigationStack {
        SymbolModifiersScreen(
            screen: CatalogScreen(
                id: "mark-modifiers/symbols", title: "Symbols", summary: "", apiSince: "16.0",
                skillReferences: ["mark-modifiers.md"],
                snippets: SymbolModifiersViewModel.snippets(for: .circle)
            )
        )
    }
}

#Preview("No sales") {
    SymbolModifiersChart(days: [], symbol: .circle, area: 100, locale: .current)
}
