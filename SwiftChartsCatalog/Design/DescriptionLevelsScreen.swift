import Accessibility
import Charts
import SwiftUI

/// "Descriptions: say the message": Apple's summary card (caption, figure, period, chart) and the four levels of
/// description, from a title that only names the chart to an interpretation.
struct DescriptionLevelsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: DescriptionLevelsViewModel
    /// The locale every word is written in, read here and passed in.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales]? = nil, initialLevel: DescriptionLevelsLevel = .title) {
        self.screen = screen
        let viewModel = days.map { DescriptionLevelsViewModel(days: $0) } ?? DescriptionLevelsViewModel()
        viewModel.level = initialLevel
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.level.caption,
            message: summary.headline(viewModel.level),
            explanation: DescriptionLevelsViewModel.explanation(hasNoSales: summary.hasNoSales),
            snippets: viewModel.snippets
        ) {
            DescriptionLevelsCard(summary: summary)
        } controls: {
            ControlsSection {
                LabeledSegmentedPicker(title: "Level of description", selection: $viewModel.level) {
                    ForEach(DescriptionLevelsLevel.allCases, id: \.self) { level in
                        Text(level.shortName).tag(level)
                    }
                }
            }
        }
        .onChange(of: viewModel.level) {
            viewModel.announce(locale: locale)
        }
    }
}

// snippet:descriptions-say-the-message-summary-card
/// Caption, figure with its unit, period, then the chart: the takeaway is read before the bars.
struct DescriptionLevelsCard: View {
    let summary: DescriptionLevelsSummary

    var body: some View {
        if summary.hasNoSales {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Daily cups appear here, with each week's average.")
            )
        } else {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                VStack(alignment: .leading, spacing: DescriptionLevelsStyle.cardLineSpacing) {
                    Text("Daily average".uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    // Interpolation joins the two styles in one Text; `+` between Texts is deprecated in iOS 26.
                    Text("\(Text(summary.figureNumber).font(.title.bold())) \(Text(summary.figureUnit).font(.headline).foregroundStyle(.secondary))")
                    // A string formatted in the data's time zone: Text(range, format:) would use the device's.
                    Text(summary.period)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                // One stop for VoiceOver, the period written out: "Daily average, 236 cups, March 22 to March 28, 2026".
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Daily average")
                .accessibilityValue("\(summary.figure), \(summary.spokenPeriod)")
                DescriptionLevelsChart(summary: summary)
            }
        }
    }
}

// end

/// Fourteen days of bars, this week at full strength, each week's daily average as a rule across it, labelled in a
/// strip above the tallest bar so no label covers a bar. At the accessibility text sizes the two labels no longer
/// fit above the plot, so they move under it as a key.
struct DescriptionLevelsChart: View {
    let summary: DescriptionLevelsSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room above the top value label, growing with its text up to a cap, so it is not cut in half.
    @ScaledMetric(relativeTo: .caption2) private var topLabelRoom = DescriptionLevelsStyle.topLabelRoom
    /// Room above the top of the domain for the rules' labels, growing with their text up to a cap.
    @ScaledMetric(relativeTo: .caption2) private var ruleLabelRoom = DescriptionLevelsStyle.ruleLabelRoom

    var body: some View {
        let thisWeek = summary.thisWeek
        let weekBefore = summary.weekBefore
        let locale = summary.locale
        let labelsInPlot = !dynamicTypeSize.isAccessibilitySize
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Chart {
                ForEach(summary.days) { day in
                    let isThisWeek = thisWeek.days.contains(day)
                    Plot {
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                        .opacity(isThisWeek ? 1 : DescriptionLevelsStyle.fadedOpacity)
                    }
                    .accessibilityLabel(summary.fullDayName(day.day))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }
                if !weekBefore.days.isEmpty {
                    DescriptionLevelsAverageRule(
                        week: weekBefore, name: summary.weekBeforeName, isEmphasised: false, showsLabel: labelsInPlot, summary: summary
                    )
                }
                DescriptionLevelsAverageRule(
                    week: thisWeek, name: summary.thisWeekName, isEmphasised: true, showsLabel: labelsInPlot, summary: summary
                )
            }
            .chartYScale(domain: summary.cupsAxis, range: .plotDimension(endPadding: labelsInPlot
                    ? min(ruleLabelRoom, DescriptionLevelsStyle.ruleLabelRoomCap)
                    : min(topLabelRoom, DescriptionLevelsStyle.topLabelRoomCap)))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: DescriptionLevelsSummary.daysPerWeek, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    // At the accessibility sizes "Mar 22" is cut short: the day alone, as the period above gives the month.
                    AxisValueLabel(format: summary.axisDayFormat(accessibilitySize: !labelsInPlot))
                }
            }
            .accessibilityChartDescriptor(DescriptionLevelsChartDescriptor(summary: summary))
            if !labelsInPlot {
                DescriptionLevelsRuleKey(summary: summary)
            }
        }
    }
}

/// A week's daily average: a rule across that week's bars, for VoiceOver too, and its label in the strip above the
/// top of the domain, over the week's first day, where no bar reaches.
struct DescriptionLevelsAverageRule: ChartContent {
    let week: DescriptionLevelsWeek
    /// The visible name: "This week", "Week before".
    let name: String
    let isEmphasised: Bool
    /// Whether the name and figure are drawn on the rule; at the accessibility sizes a key under the chart has them.
    let showsLabel: Bool
    let summary: DescriptionLevelsSummary

    var body: some ChartContent {
        if let first = week.first, let last = week.last {
            // Bars with `unit: .day` cover each whole day, so the rule runs from the first day's start to the
            // end of the last day.
            let end = CafeData.calendar.date(byAdding: .day, value: 1, to: last) ?? last
            RuleMark(
                xStart: .value(CafeWording.day, first),
                xEnd: .value(CafeWording.day, end),
                y: .value(CafeWording.cups, week.average)
            )
            .foregroundStyle(isEmphasised ? Color.primary : Color.secondary)
            .lineStyle(StrokeStyle(
                lineWidth: DescriptionLevelsStyle.ruleWidth,
                dash: isEmphasised ? [] : DescriptionLevelsStyle.dash
            ))
            // A rule is an element of its own, so it carries its words directly.
            .accessibilityLabel(summary.averageLabel(week))
            .accessibilityValue(CafeWording.cups(week.average, locale: summary.locale))
            if showsLabel {
                // An invisible anchor at the top of the domain: its label sits above every bar.
                PointMark(x: .value(CafeWording.day, first), y: .value(CafeWording.cups, summary.cupsAxis.upperBound))
                    .symbolSize(0)
                    .accessibilityHidden(true)
                    .annotation(position: .top, alignment: .leading, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        DescriptionLevelsRuleLabel(
                            name: name, value: week.average.formatted(.number.locale(summary.locale)), isEmphasised: isEmphasised
                        )
                    }
            }
        }
    }
}

/// The visible label of an average rule: a short stroke in the rule's own style, then its week and the figure.
struct DescriptionLevelsRuleLabel: View {
    let name: String
    let value: String
    let isEmphasised: Bool

    var body: some View {
        HStack(spacing: DescriptionLevelsStyle.chipPadding) {
            DescriptionLevelsRuleSwatch(isEmphasised: isEmphasised)
            Text("\(name): \(Text(value).bold())")
                .font(.caption2)
        }
    }
}

/// A short stroke drawn as the rule is, solid or dashed, so the label says which line it names.
struct DescriptionLevelsRuleSwatch: View {
    let isEmphasised: Bool

    var body: some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: DescriptionLevelsStyle.ruleWidth / 2))
            path.addLine(to: CGPoint(x: DescriptionLevelsStyle.swatchLength, y: DescriptionLevelsStyle.ruleWidth / 2))
        }
        .stroke(
            isEmphasised ? Color.primary : Color.secondary,
            style: StrokeStyle(lineWidth: DescriptionLevelsStyle.ruleWidth, dash: isEmphasised ? [] : DescriptionLevelsStyle.dash)
        )
        .frame(width: DescriptionLevelsStyle.swatchLength, height: DescriptionLevelsStyle.ruleWidth)
        .accessibilityHidden(true)
    }
}

/// The rules' labels as a key under the chart, at the accessibility text sizes, where they wrap instead of
/// overlapping in the plot. Hidden from VoiceOver: the rules already say the same.
struct DescriptionLevelsRuleKey: View {
    let summary: DescriptionLevelsSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(summary.ruleKey(isEmphasised: true))
            if !summary.weekBefore.days.isEmpty {
                Text(summary.ruleKey(isEmphasised: false))
            }
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
    }
}

/// The chart for the Audio Graph: the fourteen days as written-out dates, cups with their unit, and the two weekly
/// averages in the summary. Not tied to the main actor: the accessibility system calls its value description.
nonisolated struct DescriptionLevelsChartDescriptor: AXChartDescriptorRepresentable {
    let summary: DescriptionLevelsSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let names = summary.days.map { summary.dayName($0.day) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: summary.days.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: summary.titleOnly,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

/// Constants that belong to this chart's marks and labels.
private enum DescriptionLevelsStyle {
    static let fadedOpacity = 0.3
    static let ruleWidth: CGFloat = 2
    static let dash: [CGFloat] = [5, 3]
    static let cardLineSpacing: CGFloat = 2
    static let chipPadding: CGFloat = 4
    static let swatchLength: CGFloat = 14
    static let topLabelRoom: CGFloat = 8
    static let topLabelRoomCap: CGFloat = 20
    /// The strip above the top of the domain that holds the rules' labels, at the default text size.
    static let ruleLabelRoom: CGFloat = 20
    static let ruleLabelRoomCap: CGFloat = 32
}

#Preview("Two weeks") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/descriptions-say-the-message") {
            DescriptionLevelsScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    DescriptionLevelsCard(summary: DescriptionLevelsSummary(days: [], locale: .current))
}
