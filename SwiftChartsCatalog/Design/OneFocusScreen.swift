import Accessibility
import Charts
import SwiftUI

/// "One focus at a time": one month at full strength with the rest faded, and every month greyed under
/// the average line while it shows.
struct OneFocusScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: OneFocusViewModel
    /// Read here and passed in, so the headline, elements and descriptor write numbers as the axis does.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, months: [MonthlySummary] = CafeData.monthlySummaries) {
        self.screen = screen
        _viewModel = State(initialValue: OneFocusViewModel(months: months))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups a day, by month",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation(locale: locale),
            snippets: viewModel.snippets
        ) {
            OneFocusChart(viewModel: viewModel, locale: locale)
        } controls: {
            OneFocusControls(viewModel: viewModel, locale: locale)
        }
        .onChange(of: viewModel.focusedMonth) {
            AccessibilityNotification.Announcement(viewModel.focusAnnouncement(locale: locale)).post()
        }
        .onChange(of: viewModel.showsAverage) {
            AccessibilityNotification.Announcement(viewModel.averageAnnouncement(locale: locale)).post()
        }
    }
}

/// Mark sizes that belong to this chart alone.
private enum OneFocusStyle {
    /// The share of a month's band the range bar and its tick take, so the tick lines up with its bar.
    static let barWidth = 0.6
    /// The tick's height in points, so it stays a thin line whatever the scale.
    static let tickHeight: CGFloat = 2
    static let ruleWidth: CGFloat = 3
    /// Room above the top of the value axis for its top label, at the default text size, and the most it grows to.
    static let topRoom: CGFloat = 10
    static let topRoomMaximum: CGFloat = 24
}

/// The range bars, ticks and average line, or a placeholder when there is nothing to draw.
struct OneFocusChart: View {
    let viewModel: OneFocusViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasData {
            OneFocusRangeChart(viewModel: viewModel, locale: locale)
        } else {
            ContentUnavailableView(
                "No months to show",
                systemImage: "cup.and.saucer",
                description: Text("Each month's lowest, highest and average day appear here.")
            )
        }
    }
}

/// Each month's range bar and average tick, with the focused month leading or the average line over them all.
struct OneFocusRangeChart: View {
    let viewModel: OneFocusViewModel
    let locale: Locale
    @ScaledMetric(relativeTo: .caption2) private var topRoom = OneFocusStyle.topRoom
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.colorScheme) private var colorScheme
    private let calendar = CafeData.calendar

    var body: some View {
        let months = viewModel.months
        // snippet:one-focus-at-a-time-chart
        Chart {
            ForEach(months) { month in
                let emphasis = viewModel.emphasis(of: month)
                let colour = emphasis.isGrey ? Color.gray : Color.blue
                let labelled = viewModel.isLabelled(month)
                // The bar and its tick are one element: the month, with its three values.
                Plot {
                    BarMark(
                        x: .value(CafeWording.month, month.month, unit: .month, calendar: calendar),
                        yStart: .value(OneFocusWording.lowestDay, month.lowestDay),
                        yEnd: .value(OneFocusWording.highestDay, month.highestDay),
                        width: .ratio(OneFocusStyle.barWidth)
                    )
                    .foregroundStyle(colour)
                    // Fading: the focused month at full strength, the rest at 30% of it (45% in Dark Mode).
                    .opacity(emphasis.barOpacity(isDark: colorScheme == .dark))
                    .annotation(position: .top) {
                        if labelled { OneFocusValueLabel(value: month.highestDay, locale: locale) }
                    }
                    .annotation(position: .bottom) {
                        if labelled { OneFocusValueLabel(value: month.lowestDay, locale: locale) }
                    }
                    RectangleMark(
                        x: .value(CafeWording.month, month.month, unit: .month, calendar: calendar),
                        y: .value(OneFocusWording.averageDay, month.averageDay),
                        width: .ratio(OneFocusStyle.barWidth),
                        height: .fixed(OneFocusStyle.tickHeight)
                    )
                    .foregroundStyle(colour)
                    .opacity(emphasis.tickOpacity(isDark: colorScheme == .dark))
                    .annotation(position: .top) {
                        if labelled { OneFocusValueLabel(value: month.averageDay, locale: locale) }
                    }
                }
                .accessibilityLabel(viewModel.elementLabel(for: month, locale: locale))
                .accessibilityValue(viewModel.elementValue(for: month, locale: locale))
            }

            // The overlay: while it shows, every month above is grey, so the line is the one focus.
            if viewModel.showsAverage, let average = viewModel.overallAverage {
                RuleMark(y: .value(OneFocusWording.average, average))
                    .foregroundStyle(Color.blue)
                    .lineStyle(StrokeStyle(lineWidth: OneFocusStyle.ruleWidth))
                    .accessibilityLabel(viewModel.ruleLabel)
                    .accessibilityValue(viewModel.ruleValue(locale: locale))
                    // Fitted to the plot: at the largest text sizes it otherwise ran over the value axis's labels.
                    .annotation(position: .top, alignment: .leading, overflowResolution: .init(x: .fit(to: .plot))) {
                        // On two lines at the accessibility sizes, where one line was wider than the plot.
                        Text("\(OneFocusWording.average):\(dynamicTypeSize.isAccessibilitySize ? "\n" : " ")"
                            + OneFocusWording.number(average, locale: locale))
                            .font(.callout.bold())
                            .foregroundStyle(Color.blue)
                    }
            }
        }
        // end
        .chartYScale(
            domain: viewModel.cupsAxis,
            range: .plotDimension(endPadding: min(topRoom, OneFocusStyle.topRoomMaximum))
        )
        .chartXAxis {
            // "Mar" was cut to "..." at the accessibility sizes; the recipe's initials fit there.
            AxisMarks(values: .stride(by: .month, count: 1, calendar: calendar)) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(
                    format: Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                        .month(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated),
                    centered: true
                )
            }
        }
        .accessibilityChartDescriptor(OneFocusChartDescriptor(
            months: months,
            cupsAxis: viewModel.cupsAxis,
            summary: viewModel.audioGraphSummary(locale: locale),
            locale: locale
        ))
        .id(viewModel.chartIdentity)
    }
}

/// A figure written on the focused month, so every number in the headline can be found on the chart.
struct OneFocusValueLabel: View {
    let value: Int
    let locale: Locale

    var body: some View {
        Text(OneFocusWording.number(value, locale: locale))
            .font(.caption.bold())
            .foregroundStyle(Color.primary)
            .lineLimit(1)
    }
}

/// The month picker, the average toggle and the mistake.
struct OneFocusControls: View {
    @Bindable var viewModel: OneFocusViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledMenuPicker(title: "Month in focus", selection: $viewModel.focusedMonth) {
                ForEach(viewModel.months) { month in
                    Text(OneFocusWording.monthName(month.month, locale: locale)).tag(month.month)
                }
            }
            // While the average line shows it is the one focus, so no month can be chosen.
            .disabled(viewModel.showsAverage || !viewModel.hasData)
            if viewModel.showsAverage {
                Text("The average line is the focus while it shows.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Toggle("Show the average line", isOn: $viewModel.showsAverage)
                .disabled(!viewModel.hasData)
            MistakeToggle(title: "Keep every month at full strength", isShowingMistake: $viewModel.isShowingMistake)
                .disabled(!viewModel.hasData)
        }
    }
}

/// The chart for the Audio Graph: the months as categories and one series each for the lowest, average and
/// highest day. The average line is not a series; the summary states it.
nonisolated struct OneFocusChartDescriptor: AXChartDescriptorRepresentable {
    let months: [MonthlySummary]
    /// The value axis as drawn, passed to `chartYScale(domain:)` too.
    let cupsAxis: ClosedRange<Double>
    let summary: String
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let names = months.map { OneFocusWording.monthName($0.month, locale: locale) }
        func series(_ name: String, _ value: (MonthlySummary) -> Int) -> AXDataSeriesDescriptor {
            AXDataSeriesDescriptor(
                name: name,
                isContinuous: false,
                dataPoints: zip(names, months).map { AXDataPoint(x: $0, y: Double(value($1))) }
            )
        }
        return AXChartDescriptor(
            title: "Cups a day by month at the \(CafeWording.harbour) café, \(OneFocusWording.period(months, locale: locale))",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.month, categoryOrder: names),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: cupsAxis, gridlinePositions: []) {
                CafeWording.count($0, locale: locale)
            },
            additionalAxes: [],
            series: [
                series(OneFocusWording.lowestDay, \.lowestDay),
                series(OneFocusWording.averageDay, \.averageDay),
                series(OneFocusWording.highestDay, \.highestDay),
            ]
        )
    }
}

#Preview("One focus") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/one-focus-at-a-time") {
            OneFocusScreen(screen: screen)
        }
    }
}

#Preview("No months") {
    OneFocusChart(viewModel: OneFocusViewModel(months: []), locale: .current)
        .frame(height: 260)
}
