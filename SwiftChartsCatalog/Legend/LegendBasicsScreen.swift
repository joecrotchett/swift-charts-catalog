import Accessibility
import Charts
import SwiftUI

/// "Legend": where the legend comes from, which side of the chart it sits on and how it is aligned
/// there, and hiding it with the lines named at their ends instead.
struct LegendBasicsScreen: View {
    let screen: CatalogScreen
    var stores = CafeData.storeSales
    @State private var viewModel = LegendBasicsViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and
    /// dates the way the chart's own axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day, March",
            message: LegendBasicsSummary(stores: stores, locale: locale).headline,
            explanation: """
            The legend comes from the scales: each by: encoding, here the café as colour and as dash pattern, \
            adds the café's entry, while a fixed style or position(by:) adds none. \
            chartLegend(position:alignment:) puts it on another side of the chart and aligns it along that side. \
            chartLegend(.hidden) removes it, and then something else has to name the series: here, a label at the end of each line.
            """,
            snippets: viewModel.snippets
        ) {
            LegendBasicsChart(stores: stores, viewModel: viewModel, locale: locale)
        } controls: {
            LegendBasicsControls(viewModel: viewModel)
        }
    }
}

/// The three pickers. None changes the data, so none posts an announcement: each speaks its own value.
struct LegendBasicsControls: View {
    @Bindable var viewModel: LegendBasicsViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Legend", selection: $viewModel.visibility) {
                ForEach(LegendBasicsVisibility.allCases) { Text($0.rawValue).tag($0) }
            }
            LabeledMenuPicker(title: "Position", selection: $viewModel.position) {
                ForEach(LegendBasicsPosition.allCases) { Text($0.rawValue).tag($0) }
            }
            .disabled(!viewModel.placesLegend)
            LabeledSegmentedPicker(title: "Alignment along its side", selection: $viewModel.alignment) {
                ForEach(LegendBasicsAlignment.allCases) { Text($0.rawValue).tag($0) }
            }
            .disabled(!viewModel.placesLegend)
        }
    }
}

/// Constants that belong to this chart's marks.
private enum LegendBasicsMetrics {
    /// Days between the date axis's labels, and fewer labels at the accessibility text sizes.
    static let daysPerAxisLabel = 7
    static let daysPerLargeAxisLabel = 14
}

/// Two cafés' daily cups as two lines, with the legend shown and placed, or hidden and replaced by names.
struct LegendBasicsChart: View {
    let stores: [StoreSales]
    let viewModel: LegendBasicsViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var summary: LegendBasicsSummary {
        LegendBasicsSummary(stores: stores, locale: locale)
    }

    private var largeText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    private var dayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
    }

    var body: some View {
        if summary.hasData {
            chart
                // Each café in its colour on every screen that draws the two.
                .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
                .legendBasicsLegend(viewModel)
                .chartXAxis {
                    // Only days that have data are labelled, so the room the line-end names take past the
                    // last day gets no label of its own. At the accessibility sizes, half as many labels,
                    // as the day alone (the caption names the month). Labels in the data's own time zone,
                    // so each names the day its grid line is drawn at.
                    AxisMarks(values: summary.axisDays(every: largeText
                            ? LegendBasicsMetrics.daysPerLargeAxisLabel
                            : LegendBasicsMetrics.daysPerAxisLabel))
                    {
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: largeText ? dayStyle.day() : dayStyle.month().day())
                    }
                }
                // One value axis for the chart and the descriptor.
                .chartYScale(domain: summary.valueDomain)
                .accessibilityChartDescriptor(LegendBasicsChartDescriptor(stores: stores, locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each café's daily cups appear here, one line per café.")
            )
        }
    }

    private var chart: some View {
        Chart {
            // snippet:the-legend-source
            // One labelled Plot per week of each café: one accessibility element per stretch.
            ForEach(summary.portions) { portion in
                Plot {
                    ForEach(portion.days) { day in
                        LineMark(x: .value(CafeWording.day, day.day), y: .value(CafeWording.cups, day.cups))
                    }
                }
                .accessibilityLabel(summary.label(for: portion))
                .accessibilityValue(summary.value(for: portion))
                // These two encodings are what make the legend: one entry per café, coloured and dashed
                // as its line is. A fixed foregroundStyle(.blue) or position(by:) would add nothing to it.
                .foregroundStyle(by: .value(CafeWording.store, portion.store))
                .lineStyle(by: .value(CafeWording.store, portion.store))
            }
            // end
            if viewModel.labelsLineEnds {
                // snippet:the-legend-end-labels
                // With the legend hidden, a point of no size at each line's end carries the café's name.
                ForEach(summary.drawnStores) { store in
                    if let last = store.days.last {
                        PointMark(x: .value(CafeWording.day, last.day), y: .value(CafeWording.cups, last.cups))
                            .symbolSize(0)
                            .accessibilityHidden(true)
                            .annotation(position: .trailing, overflowResolution: .init(x: .padScale, y: .disabled)) {
                                Text(store.store)
                                    .font(.caption)
                            }
                    }
                }
                // end
            }
            if let last = summary.lastDay, let most = last.cups.map(\.cups).max() {
                // The day the headline names, written over the leading line's end: the axis labels a day a week
                // and does not reach it. A point of no size to hang the label on; the elements read the value.
                PointMark(x: .value(CafeWording.day, last.day), y: .value(CafeWording.cups, most))
                    .symbolSize(0)
                    .accessibilityHidden(true)
                    .headlineCallout(summary.calloutText(day: last.day, cups: most))
            }
        }
    }
}

extension View {
    /// Shows the legend at the chosen side and alignment, or hides it: one chain of modifiers for every
    /// setting, so the chart stays the same chart when the legend is switched off and on.
    func legendBasicsLegend(_ viewModel: LegendBasicsViewModel) -> some View {
        // snippet:the-legend-placement
        // Visibility: .automatic or .hidden. position: which side of the chart; alignment: where along that side.
        chartLegend(viewModel.legendVisibility)
            .chartLegend(position: viewModel.annotationPosition, alignment: viewModel.legendAlignment)
        // end
    }
}

/// The chart for the Audio Graph: both cafés as named, continuous series over written-out days.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct LegendBasicsChartDescriptor: AXChartDescriptorRepresentable {
    let stores: [StoreSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = LegendBasicsSummary(stores: stores, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: summary.dayOrder.map(summary.dayText)
        )
        // The drawn value scale includes zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = summary.drawnStores.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: true,
                dataPoints: store.days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold each day at \(CafeWording.list(summary.drawnStores.map(\.store)))",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Legend") {
    NavigationStack {
        LegendBasicsScreen(screen: Catalog.screen(id: "legend/the-legend") ?? CatalogScreen(
            id: "legend/the-legend", title: "Legend", summary: "Where it comes from, position, alignment, hidden",
            apiSince: "16.0", skillReferences: ["legend.md"], snippets: LegendBasicsViewModel.snippets(for: .shown)
        ))
    }
}

#Preview("No sales") {
    LegendBasicsChart(stores: [], viewModel: LegendBasicsViewModel(), locale: .current)
}
