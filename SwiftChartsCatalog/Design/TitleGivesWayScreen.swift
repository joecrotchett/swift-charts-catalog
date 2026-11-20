import Accessibility
import Charts
import SwiftUI

/// "Title gives way to selection": a selection label takes the place of the chart's title and legend, above the
/// plot, and the plot does not move when it appears.
struct TitleGivesWayScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = TitleGivesWayViewModel()
    /// Read here and passed in, so the headline, labels and Audio Graph write numbers and dates the chart's way.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Two cafés",
            message: viewModel.headline(locale: locale),
            explanation: """
            At rest the chart's title and legend sit above the plot. Touch and hold the chart: the day under your \
            finger and both cafés' cups take their place, and the plot stays where it was, its grid lines not moving, \
            because that space is sized for the tallest label as well as for the title. Lift your finger and the title \
            returns; with VoiceOver, swipe through the chart to hear each day's values.
            """
        ) {
            TitleGivesWayChart(viewModel: viewModel, locale: locale)
        }
    }
}

/// Constants that belong to this chart's marks and header.
private enum TitleGivesWayMetrics {
    static let symbolSize: CGFloat = 24
    static let legendSwatch: CGFloat = 9
    static let legendSpacing: CGFloat = 12
    static let ruleOpacity = 0.5
    static let gridOpacity = 0.2
    /// The least height the plot keeps, whatever the space above it takes at the largest text sizes: the axes
    /// and the header are added around it (`plot-area.md`).
    static let minimumPlotHeight: CGFloat = 160
}

/// Two cafés' daily cups as lines, with the title, legend and selection label in the space above the plot.
struct TitleGivesWayChart: View {
    @Bindable var viewModel: TitleGivesWayViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasData {
            TitleGivesWayLines(viewModel: viewModel, locale: locale)
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each café's cups a day appear here, one line per café.")
            )
        }
    }
}

/// The lines themselves, with the selection bound to the view model.
struct TitleGivesWayLines: View {
    @Bindable var viewModel: TitleGivesWayViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A label every week, every fortnight at the accessibility text sizes so the dates do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 14 : 7
    }

    /// The value labels: every step of the axis, or only its two ends at the accessibility sizes, where four
    /// labels of that size overlapped.
    private func cupsLabels(_ summary: TitleGivesWaySummary) -> [Double] {
        dynamicTypeSize.isAccessibilitySize ? summary.cupsAxisEnds : summary.cupsAxisSteps
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        // Read in the body, not only inside the chart's closures, so a change redraws the marks.
        let selectedDay = viewModel.selectedDay
        let header = viewModel.header(locale: locale)
        let allSelections = viewModel.allSelectionTexts(locale: locale)
        Chart {
            ForEach(summary.days) { day in
                // One element per day, carrying both cafés: what the selection label shows, reachable by swiping.
                Plot {
                    // A clear band the full height of the plot, so VoiceOver reads the days in order along x,
                    // not by the height of their points.
                    RectangleMark(
                        xStart: .value(CafeWording.day, day.date.addingTimeInterval(-TitleGivesWayViewModel.halfDay)),
                        xEnd: .value(CafeWording.day, day.date.addingTimeInterval(TitleGivesWayViewModel.halfDay))
                    )
                    .foregroundStyle(.clear)
                    ForEach(day.cups, id: \.store) { entry in
                        LineMark(x: .value(CafeWording.day, day.date), y: .value(CafeWording.cups, entry.cups))
                            .foregroundStyle(by: .value(CafeWording.store, entry.store))
                            .symbol(by: .value(CafeWording.store, entry.store))
                            .symbolSize(TitleGivesWayMetrics.symbolSize)
                    }
                }
                .accessibilityLabel(summary.dayText(day.date))
                .accessibilityValue(summary.valuesText(day))
            }
            if let selectedDay {
                RuleMark(x: .value(CafeWording.day, selectedDay.date))
                    .foregroundStyle(Color.gray.opacity(TitleGivesWayMetrics.ruleOpacity))
                    // It marks the selection only: the day's element already says its values.
                    .accessibilityHidden(true)
                    .zIndex(-1)
            }
        }
        // The same colour and symbol for each café as on every screen that draws these two series.
        .chartForegroundStyleScale(domain: summary.storeNames, mapping: CafeSeriesStyle.colour(for:))
        .chartSymbolScale(domain: summary.storeNames, mapping: CafeSeriesStyle.symbol(for:))
        .chartYScale(domain: summary.cupsAxis)
        .chartYAxis {
            // An interactive chart: fewer, lighter grid lines, labels kept at secondary.
            AxisMarks(values: summary.cupsAxisSteps) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(TitleGivesWayMetrics.gridOpacity))
            }
            AxisMarks(values: cupsLabels(summary)) { _ in
                AxisValueLabel().foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            // Counted from the first day, so the labels fall on the same days as on the other screens that draw
            // these 28 days; written in the data's UTC calendar, so they name the days that are drawn.
            AxisMarks(values: summary.labelledDays(every: daysPerLabel)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: Date.FormatStyle(locale: locale, timeZone: summary.calendar.timeZone).month().day())
            }
        }
        // snippet:title-gives-way-to-selection-header
        .chartXSelection(value: $viewModel.rawSelection)
        // The title and legend sit in the legend's place above the plot; the selection label replaces them there.
        .chartLegend(position: .top, alignment: .leading) {
            TitleGivesWayHeader(header: header, allSelections: allSelections)
        }
        // end
        // The header can be tall at the largest text sizes; the plot keeps a height it can be read at.
        .chartPlotStyle { $0.frame(minHeight: TitleGivesWayMetrics.minimumPlotHeight) }
        .accessibilityChartDescriptor(TitleGivesWayDescriptor(summary: summary))
    }
}

/// The space above the plot. It holds the title and legend, or the selection label, and is always as tall as the
/// tallest of them, so nothing below it moves when a selection appears or changes.
struct TitleGivesWayHeader: View {
    let header: TitleGivesWayHeaderText
    let allSelections: [TitleGivesWaySelectionText]

    var body: some View {
        // snippet:title-gives-way-to-selection-reserve
        ZStack(alignment: .topLeading) {
            // Every label a selection can show, laid out unseen: they set the height, whichever day is selected.
            ForEach(allSelections) { text in
                TitleGivesWaySelectionLabel(text: text)
                    .hidden()
                    .accessibilityHidden(true)
            }
            switch header {
            case let .title(title):
                TitleGivesWayTitleAndLegend(title: title)
            case let .selection(text):
                TitleGivesWaySelectionLabel(text: text)
            }
        }
        // end
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The chart's title with its legend, drawn from the same table as the chart's colour and symbol scales.
struct TitleGivesWayTitleAndLegend: View {
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            // The legend's place draws in the tint colour; the title and names are set to the text colours.
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
            HStack(spacing: TitleGivesWayMetrics.legendSpacing) {
                ForEach(CafeSeriesStyle.stores, id: \.self) { store in
                    Label {
                        Text(store)
                    } icon: {
                        CafeSeriesStyle.symbol(for: store)
                            .fill(CafeSeriesStyle.colour(for: store))
                            .frame(width: TitleGivesWayMetrics.legendSwatch, height: TitleGivesWayMetrics.legendSwatch)
                    }
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

/// The selected day written out, then both cafés' cups: what takes the title's place while a finger is down.
struct TitleGivesWaySelectionLabel: View {
    let text: TitleGivesWaySelectionText
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            // "Wed, Mar 4" at the accessibility sizes, where the day written out took two lines from the plot.
            Text(dynamicTypeSize.isAccessibilitySize ? text.shortDayText : text.dayText)
                .font(.subheadline)
                .foregroundStyle(Color.secondary)
            Text(text.valuesText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.primary)
        }
    }
}

/// The chart for the Audio Graph: two continuous series over written-out days, values said with their unit.
nonisolated struct TitleGivesWayDescriptor: AXChartDescriptorRepresentable {
    let summary: TitleGivesWaySummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let days = summary.days
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.shortDayText($0.date) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = summary.stores.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: true,
                dataPoints: store.days.map { AXDataPoint(x: summary.shortDayText($0.day), y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups a day at the \(CafeWording.list(summary.stores.map(\.store))) cafés",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("At rest") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/title-gives-way-to-selection") {
            TitleGivesWayScreen(screen: screen)
        }
    }
}

#Preview("Selected") {
    // In the panel the app uses, which grows with the text size: in a fixed height the header squeezes the plot.
    ChartPanel {
        TitleGivesWayChart(
            viewModel: TitleGivesWayViewModel(rawSelection: CafeData.day(3).addingTimeInterval(7 * 60 * 60)),
            locale: .current
        )
    }
    .padding()
}

#Preview("No sales") {
    TitleGivesWayChart(viewModel: TitleGivesWayViewModel(stores: []), locale: .current)
}
