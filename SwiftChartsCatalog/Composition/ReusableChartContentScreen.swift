import Accessibility
import Charts
import SwiftUI

/// "Reusable chart content": a custom `ChartContent` type and a `@ChartContentBuilder` property.
struct ReusableChartContentScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ReusableChartContentViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        @Bindable var viewModel = viewModel
        CatalogScreenScaffold(
            screen: screen,
            caption: CafeWording.harbourDaysCaption(locale: locale),
            message: viewModel.headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            ReusableContentChart(days: viewModel.days, target: viewModel.target, usesFixedStyle: viewModel.isShowingMistake)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Set the colour inside the type", isShowingMistake: $viewModel.isShowingMistake)
            }
        }
        .onChange(of: viewModel.isShowingMistake) {
            // The lines change colour and nothing else: say so for people who cannot see it happen.
            AccessibilityNotification.Announcement(viewModel.changeAnnouncement).post()
        }
    }
}

// snippet:reusable-chart-content-type
/// A labelled line at a number of cups: one definition for every reference line in this chart.
/// It sets no colour inside, so the colour a chart gives it reaches the rule.
struct ReferenceLine: ChartContent {
    let title: String
    let cups: Int
    /// The side of the line its label sits on, so two lines close together keep their labels apart.
    var labelPosition: AnnotationPosition = .top

    var body: some ChartContent {
        RuleMark(y: .value(title, cups))
            .accessibilityLabel(title)
            .accessibilityValue(Text("^[\(cups) cup](inflect: true)"))
            .annotation(
                position: labelPosition, alignment: .leading,
                overflowResolution: .init(x: .fit(to: .plot), y: .padScale)
            ) {
                Text("\(title): \(cups, format: .number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // On a backing of its own, so the label stays readable where it crosses the bars.
                    .padding(.horizontal, Layout.tightSpacing)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.badgeCornerRadius))
            }
    }
}

// end

// snippet:reusable-chart-content-mistake-type
/// The same line with its colour set inside. A style set inside the type wins over the same
/// style applied from outside, so no chart can give this line another colour.
struct FixedStyleReferenceLine: ChartContent {
    let title: String
    let cups: Int
    /// The side of the line its label sits on, so two lines close together keep their labels apart.
    var labelPosition: AnnotationPosition = .top

    var body: some ChartContent {
        RuleMark(y: .value(title, cups))
            .foregroundStyle(.red)
            .accessibilityLabel(title)
            .accessibilityValue(Text("^[\(cups) cup](inflect: true)"))
            .annotation(
                position: labelPosition, alignment: .leading,
                overflowResolution: .init(x: .fit(to: .plot), y: .padScale)
            ) {
                Text("\(title): \(cups, format: .number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    // On a backing of its own, so the label stays readable where it crosses the bars.
                    .padding(.horizontal, Layout.tightSpacing)
                    .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.badgeCornerRadius))
            }
    }
}

// end

/// A bar per day with an average line and a target line, or a placeholder when nothing was sold.
struct ReusableContentChart: View {
    /// The bars are context for the two lines, so they are drawn fainter than the lines.
    private static let barOpacity = 0.4

    let days: [DailySales]
    let target: Int
    /// Draws the lines with the type that sets its own colour: the mistake.
    var usesFixedStyle = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A date label a week, or one a fortnight at the accessibility text sizes, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize.isAccessibilitySize ? 14 : 7
    }

    // snippet:reusable-chart-content-builder
    /// Part of this one chart, given a name. It keeps chart syntax, and the chart's body reads as a list.
    @ChartContentBuilder
    private var dailyBars: some ChartContent {
        ForEach(days) { day in
            Plot {
                BarMark(
                    x: .value("Day", day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", day.cups)
                )
            }
            .accessibilityLabel(ReusableContentSummary.spokenDay(day.day))
            .accessibilityValue(Text("^[\(day.cups) cup](inflect: true)"))
        }
        .opacity(Self.barOpacity)
    }

    // end

    var body: some View {
        let summary = ReusableContentSummary(days: days, target: target)
        // No days, or only zeros, is no data: the average line would lie on the axis under a headline about nothing.
        if let average = summary.average {
            Chart {
                if usesFixedStyle {
                    // snippet:reusable-chart-content-mistake-use
                    dailyBars
                    // The chart asks for orange and purple. The type's own red wins: both lines are red.
                    FixedStyleReferenceLine(title: "Average", cups: average, labelPosition: .bottom)
                        .foregroundStyle(.orange)
                    FixedStyleReferenceLine(title: "Target", cups: target)
                        .foregroundStyle(.purple)
                    // end
                } else {
                    // snippet:reusable-chart-content-use
                    dailyBars
                    // One type, used twice. Each use gives the line its own colour from outside.
                    ReferenceLine(title: "Average", cups: average, labelPosition: .bottom)
                        .foregroundStyle(.orange)
                    ReferenceLine(title: "Target", cups: target)
                        .foregroundStyle(.purple)
                    // end
                }
            }
            .chartXAxis {
                // The days were counted in UTC, so the axis is cut and labelled in that calendar too.
                AxisMarks(
                    format: Date.FormatStyle(timeZone: CafeData.calendar.timeZone).month().day(),
                    values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)
                )
            }
            // One value axis for the chart and the descriptor: to the taller of the busiest day and the target.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(ReusableContentChartDescriptor(days: days, target: target))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, with the average and the target.")
            )
        }
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct ReusableContentSummary {
    let days: [DailySales]
    let target: Int

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn: from zero to the taller of the busiest day and the target, rounded up to the axis
    /// step (282 and 250 → 300). The chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups) + [target])
    }

    /// Cups a day, rounded to a whole cup: the figure the average line is drawn and labelled at.
    /// `nil` when there are no days or nothing was sold.
    var average: Int? {
        guard !days.isEmpty, total > 0 else { return nil }
        return Int((Double(total) / Double(days.count)).rounded())
    }

    /// The chart's message. Both figures are written on the chart's two lines.
    var headline: String {
        guard let average else { return "No cups sold yet." }
        let relation = if average < target {
            "under"
        } else if average > target {
            "over"
        } else {
            "exactly on"
        }
        return "\(Self.spokenCups(average)) a day on average, \(relation) the target of \(target.formatted())."
    }

    /// Actual values only. The two lines are not series, so they are stated here.
    var audioGraphSummary: String {
        guard let average, let fewest = days.map(\.cups).min(), let most = days.map(\.cups).max() else {
            return "No cups sold yet."
        }
        return "\(days.count.formatted()) days. Average \(Self.spokenCups(average)) a day. "
            + "Target \(Self.spokenCups(target)) a day. "
            + "Fewest in a day \(Self.spokenCups(fewest)), most \(Self.spokenCups(most))."
    }

    /// A count with its unit as a plain string that agrees in number: "1 cup", "204 cups".
    static func spokenCups(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) cup](inflect: true)").characters)
    }

    /// A day written out, in the time zone the days were counted in: "Sunday, March 1".
    static func spokenDay(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day())
    }
}

/// The chart for the Audio Graph: a title, a summary with both lines' values, written-out days, and cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ReusableContentChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let target: Int

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = ReusableContentSummary(days: days, target: target)
        let spokenDays = days.map { ReusableContentSummary.spokenDay($0.day) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: spokenDays)
        // The drawn scale starts at zero and reaches the taller of the tallest bar and the target line, rounded up.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in ReusableContentSummary.spokenCups(count) } }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: zip(spokenDays, days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the Harbour café, with the average and the target",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Lines coloured by the chart") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/reusable-chart-content") {
            ReusableChartContentScreen(screen: screen)
        }
    }
}

#Preview("The mistake") {
    ReusableContentChart(days: CafeData.harbourSales, target: ReusableChartContentViewModel.dailyTarget, usesFixedStyle: true)
        .padding()
}

#Preview("No sales") {
    ReusableContentChart(days: [], target: ReusableChartContentViewModel.dailyTarget)
}
