import Accessibility
import Charts
import SwiftUI

/// "Formatting and conditional labels": one day axis taken in stages from the default to a finished
/// axis with a format style, labels that differ by value, two-line labels and centred day labels.
struct AxisFormattingScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = AxisFormattingViewModel()
    /// Read here and passed in, so the axis labels, headline, elements and Audio Graph write dates
    /// and numbers the same way.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: AxisFormattingSummary(days: viewModel.days, locale: locale).caption,
            message: AxisFormattingSummary(days: viewModel.days, locale: locale).headline,
            explanation: """
            AxisMarks(format:) takes any FormatStyle for the axis's values. Given a closure, AxisMarks hands \
            it each AxisValue, so a label can change with its date or its index, and AxisValueLabel can hold \
            a view of two lines. With centered: true, a label marked at every day sits under its own bar.
            """,
            snippets: viewModel.snippets
        ) {
            AxisFormattingChart(days: viewModel.days, stage: viewModel.stage, locale: locale)
        } controls: {
            ControlsSection {
                AxisFormattingStageStepper(viewModel: viewModel)
            }
        }
    }
}

/// The stepper that walks through the stages, with a sentence on what the current one changes.
private struct AxisFormattingStageStepper: View {
    @Bindable var viewModel: AxisFormattingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            LabeledStepper(
                title: "Axis stage", value: $viewModel.stageNumber, in: 1 ... viewModel.stageCount,
                valueText: viewModel.stageDescription
            )
            Text(viewModel.stage.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// One bar per day, with the day axis drawn as the current stage says, or a placeholder when there
/// is nothing to draw.
struct AxisFormattingChart: View {
    let days: [DailySales]
    let stage: AxisFormattingStage
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let summary = AxisFormattingSummary(days: days, locale: locale)
        if summary.hasSales {
            let text = AxisFormattingDateText(locale: locale)
            let calendar = CafeData.calendar
            Chart(days) { day in
                Plot {
                    // The days were counted in UTC: the bar takes the data's calendar, or it lands on
                    // the previous day anywhere west of Greenwich.
                    BarMark(
                        x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar),
                        y: .value(CafeWording.cups, day.cups)
                    )
                }
                .accessibilityLabel(text(day.day, text.spoken))
                .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                // The day the headline names, labelled on its bar: the axis labels a day a week and may not label
                // it. Not read aloud; the bar's element says the same.
                .headlineCallout(summary.busiestDays.contains(day) ? summary.calloutText(for: day) : nil)
            }
            .chartXAxis {
                // The stage is chosen inside the axis closure, so it stays one chart.
                let axis = AxisFormattingDayAxis(text: text, labelEvery: daysPerLabel)
                switch stage {
                case .automatic: axis.automatic()
                case .formatStyle: axis.formatStyle()
                case .byValue: axis.byValue()
                case .twoLines: axis.twoLines()
                case .centredDays: axis.centredDays()
                }
            }
            // One value axis for the chart and the descriptor: the busiest day, rounded up to the axis step.
            .chartYScale(domain: ChartAxis.valueDomain(for: days.map(\.cups)))
            .accessibilityChartDescriptor(AxisFormattingChartDescriptor(days: days, locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        }
    }

    /// Centred labels at every day need about one letter's width each; at the accessibility sizes
    /// only every other day is labelled, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility1 ? 2 : 1
    }
}

/// The day axis at each stage. The marks and labels are placed in the data's calendar, and dates are
/// written in its time zone and the view's locale.
struct AxisFormattingDayAxis {
    let text: AxisFormattingDateText
    /// In the last stage, label every this many days.
    let labelEvery: Int

    var calendar: Calendar {
        text.calendar
    }

    // snippet:axis-formatting-default
    @AxisContentBuilder
    func automatic() -> some AxisContent {
        // The default axis, recreated: the framework picks the values and the format.
        AxisMarks()
    }

    // end

    // snippet:axis-formatting-format-style
    @AxisContentBuilder
    func formatStyle() -> some AxisContent {
        // A mark every seventh day, written as "Mar 1". An explicit format carries its own locale
        // and time zone, so it is given the view's locale and the data's time zone.
        AxisMarks(
            format: Date.FormatStyle(locale: text.locale, timeZone: calendar.timeZone).month(.abbreviated).day(),
            values: .stride(by: .day, count: 7, calendar: calendar)
        )
    }

    // end

    // snippet:axis-formatting-by-value
    @AxisContentBuilder
    func byValue() -> some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 7, calendar: calendar)) { value in
            AxisGridLine()
            AxisTick()
            if let date = value.as(Date.self) {
                // "Mar 1" on the first label and where a month starts; the day alone elsewhere.
                if value.index == 0 || calendar.component(.day, from: date) == 1 {
                    AxisValueLabel(date.formatted(text.monthDay))
                } else {
                    AxisValueLabel(date.formatted(text.dayNumber))
                }
            }
        }
    }

    // end

    // snippet:axis-formatting-two-lines
    @AxisContentBuilder
    func twoLines() -> some AxisContent {
        AxisMarks(values: .stride(by: .day, count: 7, calendar: calendar)) { value in
            AxisGridLine()
            AxisTick()
            if let date = value.as(Date.self) {
                AxisValueLabel {
                    VStack(alignment: .leading) {
                        Text(date.formatted(text.dayNumber))
                        // The month on a second line, only where the first line needs it.
                        if value.index == 0 || calendar.component(.day, from: date) == 1 {
                            Text(date.formatted(text.monthName))
                        }
                    }
                }
            }
        }
    }

    // end

    // snippet:axis-formatting-centred-days
    @AxisContentBuilder
    func centredDays() -> some AxisContent {
        AxisMarks(values: .stride(by: .day, calendar: calendar)) { value in
            if let date = value.as(Date.self) {
                // A grid line and tick only on each Sunday, weekday 1 in the Gregorian calendar.
                if calendar.component(.weekday, from: date) == 1 {
                    AxisGridLine()
                    AxisTick()
                }
                // Every day is a mark, so a centred label sits under its own bar, even when
                // large text leaves room for only every other label.
                if value.index.isMultiple(of: labelEvery) {
                    AxisValueLabel(centered: true) {
                        VStack {
                            Text(date.formatted(text.weekdayInitial))
                            Text(date.formatted(text.dayNumber))
                        }
                    }
                }
            }
        }
    }
    // end
}

/// The chart for the Audio Graph: a title, a summary, named axes, written-out dates, and values said
/// with their unit. Not tied to the main actor: the accessibility system calls its value description
/// when it chooses.
nonisolated struct AxisFormattingChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = AxisFormattingSummary(days: days, locale: locale)
        let text = AxisFormattingDateText(locale: locale)
        let locale = locale
        let names = days.map { text($0.day, text.spoken) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: ChartAxis.valueDomain(for: days.map(\.cups)),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: zip(names, days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
        )
        return AXChartDescriptor(
            title: "\(CafeWording.cups) sold each day, \(CafeWording.harbour), \(summary.period)",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Stages") {
    NavigationStack {
        if let screen = Catalog.screen(id: "axes/formatting-and-conditional-labels") {
            AxisFormattingScreen(screen: screen)
        }
    }
}

#Preview("Centred days") {
    AxisFormattingChart(days: Array(CafeData.harbourSales.prefix(14)), stage: .centredDays, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No sales") {
    AxisFormattingChart(days: [], stage: .automatic, locale: .current)
}
