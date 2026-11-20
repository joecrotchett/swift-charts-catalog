import Accessibility
import Charts
import SwiftUI

/// "Start from the goal": one data set, the insights it could show, and how choosing one at each
/// distance (the whole, a subset, a single value) decides what the chart draws.
struct StartFromTheGoalScreen: View {
    let screen: CatalogScreen
    @State private var model: StartFromTheGoalViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and dates
    /// the way the chart's own axes do.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.thirtyDays) {
        self.screen = screen
        _model = State(initialValue: StartFromTheGoalViewModel(days: days))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            // The shared invented month says it is invented, so it is not taken for the café's recorded March.
            caption: CafeWording.inventedDaysCaption(locale: locale),
            message: model.headline(locale: locale),
            explanation: """
            The question is how the last 30 days went. These days could show their average, their range, the \
            weekends, the last week, the best day and the quietest; a chart that shows all of them makes no point. \
            Choose one insight at each distance and each adds one thing to the same bars: a labelled line or band \
            for the whole, those days at full strength with the rest faded for a subset, a marked day for a single value.
            """,
            snippets: model.snippets
        ) {
            StartFromTheGoalChart(model: model, locale: locale)
        } controls: {
            StartFromTheGoalControls(model: model, locale: locale)
        }
    }
}

/// Mark constants that belong to this chart alone.
private enum StartFromTheGoalStyle {
    /// The days outside a chosen subset, faded so the subset carries the eye (`design.md`, *Emphasise one thing*).
    static let fadedOpacity = 0.3
    static let bandOpacity = 0.15
    static let ruleWidth: CGFloat = 2
    static let markerSize: CGFloat = 70
    /// Room above the value axis's top label, which is centred on the top of the domain. Scaled with the text.
    static let axisTopPadding: CGFloat = 8
    static let labelVerticalPadding: CGFloat = 2
    static let labelHorizontalPadding: CGFloat = 4
}

/// The thirty days as bars, with what the chosen insights add on top, or a placeholder when nothing sold.
struct StartFromTheGoalChart: View {
    let model: StartFromTheGoalViewModel
    let locale: Locale
    @ScaledMetric(relativeTo: .caption) private var axisTopPadding = StartFromTheGoalStyle.axisTopPadding
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let summary = model.summary(locale: locale)
        let configuration = model.configuration
        if !summary.hasSales {
            // Nothing sold: bars of zero would draw an empty plot under a headline that is not true.
            ContentUnavailableView(
                "No sales in these days",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        } else {
            // At the accessibility sizes the labels' plates covered the tops of the bars: the labels move to a
            // key under the chart instead, and the chart keeps its rule, band and dots.
            let labelsOnChart = !dynamicTypeSize.isAccessibilitySize
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                Chart {
                    // snippet:start-from-the-goal-subset
                    ForEach(summary.days) { day in
                        Plot {
                            BarMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                        }
                        // A chosen subset at full strength and every other day faded; no subset, every day in full.
                        .opacity(summary.isEmphasised(day, in: configuration) ? 1 : StartFromTheGoalStyle.fadedOpacity)
                        .accessibilityLabel(summary.elementLabel(day))
                        .accessibilityValue(summary.elementValue(day, configuration))
                    }
                    // end

                    // snippet:start-from-the-goal-range
                    // The whole, as a range: a faint band from the lowest day to the highest, put behind the bars.
                    if configuration.whole.contains(.range), let range = summary.range, let last = summary.days.last {
                        Plot {
                            RectangleMark(
                                yStart: .value(CafeWording.cups, range.lowerBound),
                                yEnd: .value(CafeWording.cups, range.upperBound)
                            )
                            .foregroundStyle(Color.gray.opacity(StartFromTheGoalStyle.bandOpacity))
                            .zIndex(-1)
                        }
                        .accessibilityLabel(StartFromTheGoalSummary.rangeLabel)
                        .accessibilityValue(summary.rangeValue)
                        // The band's label hangs on a point of no size at its lower edge, written after the bars so
                        // they do not cover it: under the band at the trailing end, clear of the other labels.
                        PointMark(
                            x: .value(CafeWording.day, last.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, range.lowerBound)
                        )
                        .symbolSize(0)
                        .accessibilityHidden(true)
                        .annotation(position: .bottom, alignment: .trailing, overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                            if labelsOnChart { StartFromTheGoalChartLabel(text: summary.rangeAnnotation) }
                        }
                    }
                    // end

                    // snippet:start-from-the-goal-average
                    // The whole, as an average: a rule across the plot, labelled on the chart and for VoiceOver.
                    if configuration.whole.contains(.average), let average = summary.average {
                        RuleMark(y: .value(StartFromTheGoalSummary.averageLabel, average))
                            .foregroundStyle(Color.primary)
                            .lineStyle(StrokeStyle(lineWidth: StartFromTheGoalStyle.ruleWidth))
                            .accessibilityLabel(StartFromTheGoalSummary.averageLabel)
                            .accessibilityValue(summary.averageValue)
                            .annotation(position: .top, alignment: .leading) {
                                if labelsOnChart { StartFromTheGoalChartLabel(text: summary.averageAnnotation) }
                            }
                    }
                    // end

                    // snippet:start-from-the-goal-single
                    // A single value: a point on top of its bar with its figure above. The bar's own element
                    // already says it, so the point is hidden from VoiceOver.
                    ForEach(summary.markedDays(configuration)) { marked in
                        PointMark(
                            x: .value(CafeWording.day, marked.day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, marked.day.cups)
                        )
                        .foregroundStyle(Color.primary)
                        .symbolSize(StartFromTheGoalStyle.markerSize)
                        .accessibilityHidden(true)
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                            // The day's date on the label too: the weekly axis does not label most days.
                            if labelsOnChart {
                                StartFromTheGoalChartLabel(text: summary.markerAnnotation(marked), detail: summary.markerDate(marked))
                            }
                        }
                    }
                    // end
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7, calendar: CafeData.calendar)) { _ in
                        AxisGridLine()
                        AxisTick()
                        // At the accessibility sizes "Mar 1" is cut to an ellipsis: the day alone fits.
                        if dynamicTypeSize >= .accessibility1 {
                            AxisValueLabel(format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).day())
                        } else {
                            AxisValueLabel(format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month().day())
                        }
                    }
                }
                .chartYScale(domain: summary.cupsAxis, range: .plotDimension(endPadding: axisTopPadding))
                .accessibilityChartDescriptor(
                    StartFromTheGoalChartDescriptor(summary: summary, configuration: configuration)
                )
                // The bars keep their ids while their spoken values change with the insights: a new identity
                // makes VoiceOver read the new words.
                .id(configuration)
                if !labelsOnChart {
                    StartFromTheGoalChartKey(entries: summary.keyEntries(configuration))
                }
            }
        }
    }
}

/// The chart's labels as a key under it, at the sizes where they would cover the bars.
struct StartFromTheGoalChartKey: View {
    let entries: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            ForEach(entries, id: \.self) { Text($0) }
        }
        .font(.caption.weight(.semibold))
        // Its full height, taken from the plot: a key squeezed to fit was cut to an ellipsis.
        .fixedSize(horizontal: false, vertical: true)
        // The rule, the band and the bars already say these figures to VoiceOver; the key repeats them.
        .accessibilityHidden(true)
    }
}

/// A label drawn on the chart, on a small plate so it stays readable over the bars.
struct StartFromTheGoalChartLabel: View {
    let text: String
    /// A second line above the text, such as the marked day's date.
    var detail: String?

    var body: some View {
        VStack(spacing: 0) {
            if let detail {
                Text(detail)
            }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .padding(.horizontal, StartFromTheGoalStyle.labelHorizontalPadding)
        .padding(.vertical, StartFromTheGoalStyle.labelVerticalPadding)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.badgeCornerRadius))
    }
}

/// One picker per distance, and the mistake.
struct StartFromTheGoalControls: View {
    @Bindable var model: StartFromTheGoalViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            Group {
                LabeledSegmentedPicker(title: StartFromTheGoalDistance.whole.title, selection: $model.whole) {
                    Text("None").tag(StartFromTheGoalWhole?.none)
                    ForEach(StartFromTheGoalWhole.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                LabeledSegmentedPicker(title: StartFromTheGoalDistance.subset.title, selection: $model.subset) {
                    Text("None").tag(StartFromTheGoalSubset?.none)
                    ForEach(StartFromTheGoalSubset.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
                LabeledSegmentedPicker(title: StartFromTheGoalDistance.single.title, selection: $model.single) {
                    Text("None").tag(StartFromTheGoalSingle?.none)
                    ForEach(StartFromTheGoalSingle.allCases, id: \.self) { Text($0.title).tag(Optional($0)) }
                }
            }
            .disabled(!model.arePickersEnabled)
            MistakeToggle(title: "Show every insight at once", isShowingMistake: $model.isShowingMistake)
                .disabled(!model.hasSales)
            if model.isShowingMistake {
                Text("Six insights in one chart: a line, a band, two subsets and two marked days compete, and no one message stands out.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .onChange(of: model.whole) { announce(.distance(.whole)) }
        .onChange(of: model.subset) { announce(.distance(.subset)) }
        .onChange(of: model.single) { announce(.distance(.single)) }
        .onChange(of: model.isShowingMistake) { announce(.mistake) }
    }

    private func announce(_ change: StartFromTheGoalChange) {
        announceStartFromTheGoalChange(model.announcement(after: change, locale: locale))
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen (`accessibility-beyond-voiceover.md`).
@MainActor
func announceStartFromTheGoalChange(_ message: String) {
    // iOS 17.0+, below the app's iOS 18.0 deployment target, so no fallback is needed.
    AccessibilityNotification.Announcement(message).post()
}

/// The chart for the Audio Graph: a title, a summary in actual values, the days written out, and cups said
/// with their unit. Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct StartFromTheGoalChartDescriptor: AXChartDescriptorRepresentable {
    let summary: StartFromTheGoalSummary
    let configuration: StartFromTheGoalConfiguration

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: summary.categories)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: summary.days.map { AXDataPoint(x: summary.shortDayName($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: StartFromTheGoalSummary.audioGraphTitle,
            summary: summary.audioGraphSummary(configuration),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Three insights") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/start-from-the-goal") {
            StartFromTheGoalScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    StartFromTheGoalChart(model: StartFromTheGoalViewModel(days: []), locale: .current)
}
