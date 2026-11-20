import Accessibility
import Charts
import SwiftUI

/// "Mark dimensions": the four `MarkDimension` cases as the width of a bar, and what each does
/// as the number of bars changes.
struct MarkDimensionsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = MarkDimensionsViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold a day at the Harbour café",
            message: MarkDimensionsSummary(days: viewModel.days, locale: locale).headline,
            explanation: """
            A bar's width: takes a MarkDimension. A ratio is a share of the scale's step, here one day, so bars and gaps \
            scale together. An inset takes a set number of points off each side of the step, so the gaps hold. A fixed \
            width is a number of points that ignores the step. Change the number of bars to see which gaps hold and \
            which bars crowd.
            """,
            snippets: viewModel.snippets
        ) {
            MarkDimensionsChart(days: viewModel.days, width: viewModel.width)
        } controls: {
            MarkDimensionsControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.announcement(locale: locale)) { _, announcement in
            // The chart changed: say so for people who cannot see it happen.
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// One bar per day at the given width, or a placeholder when nothing was sold.
struct MarkDimensionsChart: View {
    let days: [DailySales]
    let width: MarkDimension
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let summary = MarkDimensionsSummary(days: days, locale: locale)
        // Nothing sold is no data: zeros would draw axes with no bars.
        if summary.total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        } else {
            Chart {
                // snippet:mark-dimensions-chart
                ForEach(days) { day in
                    Plot {
                        BarMark(
                            // The unit gives each day a step on the date axis, which ratio and inset measure against.
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups),
                            width: width
                        )
                    }
                    .accessibilityLabel(summary.dayLabel(day.day))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }
                // end
                ForEach(summary.busiestDays) { busiest in
                    // Each day the headline names, written on its bar: the axis may not label that day. A point of
                    // no size to hang the label on; the day's own element already reads the value.
                    PointMark(
                        x: .value(CafeWording.day, busiest.day, unit: .day, calendar: CafeData.calendar),
                        y: .value(CafeWording.cups, busiest.cups)
                    )
                    .symbolSize(0)
                    .accessibilityHidden(true)
                    .headlineCallout(summary.calloutText(for: busiest))
                }
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .chartXAxis {
                // The days were counted in UTC, so the axis is told the same calendar as the bars.
                AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) { value in
                    AxisGridLine()
                    AxisTick()
                    // The first label names the month ("Mar 1"), the rest the day alone, so the month is on the
                    // chart and the labels still fit side by side.
                    AxisValueLabel(
                        format: value.index == 0
                            ? Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day()
                            : Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).day(),
                        // Centred, a label sits in the middle of the stride, not of its day:
                        // under its bar only when every day is labelled.
                        centered: daysPerLabel == 1
                    )
                }
            }
            // Marks are not clipped to the plot area: a fixed width wider than its step would run over the axis labels.
            .chartPlotStyle { plotArea in
                plotArea.clipped()
            }
            .accessibilityChartDescriptor(MarkDimensionsChartDescriptor(days: days, locale: locale))
        }
    }

    /// Fewer labels as the bars multiply or the text grows, so they do not collide.
    private var daysPerLabel: Int {
        MarkDimensionsSummary.daysPerLabel(
            dayCount: days.count, isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }
}

/// The case picker, the slider for its amount, and the slider for the number of bars.
struct MarkDimensionsControls: View {
    @Bindable var viewModel: MarkDimensionsViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Bar width", selection: $viewModel.kind.animation(.easeInOut)) {
                ForEach(MarkDimensionsViewModel.Kind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            if let range = viewModel.kind.amountRange, let amountText = viewModel.amountText(locale: locale) {
                LabeledContent(viewModel.kind.amountTitle, value: amountText)
                    .accessibilityHidden(true)
                Slider(value: $viewModel.amount, in: range, step: viewModel.kind.amountStep) {
                    Text(viewModel.kind.amountTitle)
                }
                .accessibilityValue(amountText)
            }
            Text(viewModel.kind.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledContent("Number of bars", value: viewModel.dayCountText(locale: locale))
                .accessibilityHidden(true)
            Slider(
                value: $viewModel.dayCountValue,
                in: Double(MarkDimensionsViewModel.dayCountRange.lowerBound) ... Double(MarkDimensionsViewModel.dayCountRange.upperBound),
                step: 1
            ) {
                Text("Number of bars")
            }
            .accessibilityValue(viewModel.dayCountText(locale: locale))
        }
    }
}

/// What the chart says in words: its headline, its day labels, and the summary the Audio Graph speaks.
nonisolated struct MarkDimensionsSummary {
    let days: [DailySales]
    var locale = Locale.current

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (240 → 300): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    /// The label written over the busiest day's bar, naming the day the headline names: "Mar 14: 240".
    func calloutText(for day: DailySales) -> String {
        let date = day.day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day()
        )
        return "\(date): \(day.cups.formatted(.number.locale(locale)))"
    }

    /// Every day that sold the most, in date order. More than one on a tie; none when nothing sold.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// A day written out in the time zone it was counted in: "Sunday, March 1".
    func dayLabel(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// The chart's message, carrying the tallest bar's value. True on a tie, for one day, and when nothing sold.
    var headline: String {
        guard let most = busiestDays.first?.cups else { return "No cups sold yet." }
        // The dates are written in the view's locale; the list that joins them is English, like the sentence.
        let names = CafeWording.list(busiestDays.map { dayLabel($0.day) })
        if days.count == 1 { return "\(CafeWording.cups(most, locale: locale)) on \(names)." }
        return "Most cups in \(CafeWording.days(days.count, locale: locale)): \(most.formatted(.number.locale(locale))), on \(names)."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = busiestDays.first?.cups, let first = days.first, let last = days.last else {
            return "No cups sold yet."
        }
        // The dates are written in the view's locale; the list that joins them is English, like the sentence.
        let names = CafeWording.list(busiestDays.map { dayLabel($0.day) })
        return "\(CafeWording.days(days.count, locale: locale)), \(dayLabel(first.day)) to \(dayLabel(last.day)). "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), last day \(CafeWording.cups(last.cups, locale: locale)). "
            + "Highest \(CafeWording.cups(most, locale: locale)), on \(names)."
    }

    /// How many days apart the x axis labels are: every day for a week, every other day for two, then weekly.
    /// At the accessibility text sizes each step comes sooner, and four weeks get a label a fortnight.
    static func daysPerLabel(dayCount: Int, isAccessibilitySize: Bool) -> Int {
        let daysInWeek = 7
        if isAccessibilitySize {
            if dayCount <= 3 { return 1 }
            if dayCount <= daysInWeek { return 2 }
            return dayCount <= 2 * daysInWeek ? daysInWeek : 2 * daysInWeek
        }
        if dayCount <= daysInWeek { return 1 }
        return dayCount <= 2 * daysInWeek ? 2 : daysInWeek
    }
}

/// The chart for the Audio Graph: a title, a summary, written-out days, and values said in cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct MarkDimensionsChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    var locale = Locale.current

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = MarkDimensionsSummary(days: days, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.dayLabel($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: days.map { AXDataPoint(x: summary.dayLabel($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold a day at the Harbour café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Mark dimensions") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/mark-dimensions") {
            MarkDimensionsScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    MarkDimensionsChart(days: [], width: .automatic)
}
