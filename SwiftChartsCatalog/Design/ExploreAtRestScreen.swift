import Accessibility
import Charts
import SwiftUI

/// "Interaction: explore, do not require": a chart whose message stands at rest, with selection anywhere in the
/// plot revealing each day's exact figures on top of it.
struct ExploreAtRestScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ExploreAtRestViewModel()
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let words = viewModel.words(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold a day, \(CafeWording.harbour) and \(CafeWording.station)",
            message: viewModel.headline(locale: locale),
            explanation: words.explanation(
                isAccessibilitySize: dynamicTypeSize.isAccessibilitySize,
                isShowingMistake: viewModel.isShowingMistake
            ),
            snippets: ExploreAtRestSnippets.references(isShowingMistake: viewModel.isShowingMistake)
        ) {
            if viewModel.hasData {
                ExploreAtRestChart(
                    days: viewModel.days,
                    series: viewModel.series,
                    words: words,
                    shadedDays: viewModel.isShowingMistake ? [] : words.shadedDays,
                    showsShading: !viewModel.isShowingMistake,
                    selection: viewModel.selection(locale: locale),
                    cupsDomain: viewModel.cupsDomain,
                    cupsAxisValues: viewModel.cupsAxisValues,
                    calendar: viewModel.calendar,
                    isShowingMistake: viewModel.isShowingMistake,
                    rawSelection: $viewModel.rawSelection
                )
            } else {
                ContentUnavailableView(
                    "No sales recorded",
                    systemImage: "cup.and.saucer",
                    description: Text("Both cafés' daily cups appear here, one line each.")
                )
            }
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Leave the message to the gesture", isShowingMistake: $viewModel.isShowingMistake)
                    .disabled(!viewModel.hasData)
                if viewModel.isShowingMistake {
                    Text("""
                    Nothing at rest says which café is ahead or since when: a reader has to hold a finger on the \
                    plot and scrub day by day to find out. A tap or a scroll shows nothing, and a reader who \
                    only glances leaves without the point.
                    """)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: viewModel.isShowingMistake) { _, isShowingMistake in
            announceExploreAtRestChange(words.announcement(isShowingMistake: isShowingMistake))
        }
    }
}

/// Says aloud that the screen changed, for people who cannot see it happen.
@MainActor
private func announceExploreAtRestChange(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// Sizes that belong to this chart's marks.
private enum ExploreAtRestMetrics {
    /// Room above the plot for the selection label, which is allowed past the plot's top edge.
    static let selectionRoom: CGFloat = 52
    /// How far the selection rule reaches above the plot to meet its label.
    static let ruleReach: CGFloat = -10
    static let shadeOpacity = 0.12
    static let ruleOpacity = 0.3
    static let gridOpacity = 0.2
    static let labelPadding: CGFloat = 2
    static let popoverPadding: CGFloat = 6
    static let popoverCornerRadius: CGFloat = 4
    static let popoverBackgroundOpacity = 0.12
    static let popoverValueSpacing: CGFloat = 16
    /// How much more room the selection label needs when its figures stack: three lines in place of two.
    static let stackedRoomFactor: CGFloat = 1.6
}

/// The chart, with the shading's key under it at the sizes where its label cannot be written in the shading.
struct ExploreAtRestChart: View {
    let days: [ExploreAtRestDay]
    let series: [ExploreAtRestSeries]
    let words: ExploreAtRestWords
    let shadedDays: [Date]
    let showsShading: Bool
    let selection: ExploreAtRestSelection?
    let cupsDomain: ClosedRange<Int>
    let cupsAxisValues: [Int]
    let calendar: Calendar
    let isShowingMistake: Bool
    @Binding var rawSelection: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .callout) private var selectionRoom = ExploreAtRestMetrics.selectionRoom

    var body: some View {
        let labelsInShading = words.labelsShadingInPlot(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize)
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            ExploreAtRestPlot(
                days: days, series: series, words: words, shadedDays: shadedDays,
                labelsShading: showsShading && labelsInShading, selection: selection,
                cupsDomain: cupsDomain, cupsAxisValues: cupsAxisValues, calendar: calendar,
                isShowingMistake: isShowingMistake, rawSelection: $rawSelection
            )
            if showsShading, !labelsInShading, let shadedLabel = words.shadedLabel {
                Text("Shaded: \(shadedLabel)")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    // The headline and the Audio Graph's summary say it already.
                    .accessibilityHidden(true)
            }
        }
        // Room for the selection label, which goes past the plot's top edge; it has a line more at the
        // accessibility sizes, where the two cafés' figures stack.
        .padding(.top, selectionRoom * (dynamicTypeSize.isAccessibilitySize ? ExploreAtRestMetrics.stackedRoomFactor : 1))
    }
}

/// Both cafés' lines, the message shaded at rest, and the selection drawn as marks.
struct ExploreAtRestPlot: View {
    let days: [ExploreAtRestDay]
    let series: [ExploreAtRestSeries]
    let words: ExploreAtRestWords
    let shadedDays: [Date]
    /// Whether the shading's first day is written inside it; otherwise the key under the chart says it.
    let labelsShading: Bool
    let selection: ExploreAtRestSelection?
    let cupsDomain: ClosedRange<Int>
    let cupsAxisValues: [Int]
    let calendar: Calendar
    let isShowingMistake: Bool
    @Binding var rawSelection: Date?
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Chart {
            // snippet:interaction-explore-do-not-require-at-rest
            // The message, drawn at rest: one band over the days the headline names, with the day they start
            // written inside it, since the axis labels only every seventh day.
            if let first = shadedDays.first, let last = shadedDays.last,
               let end = calendar.date(byAdding: .day, value: 1, to: last)
            {
                RectangleMark(xStart: .value(CafeWording.day, first), xEnd: .value(CafeWording.day, end))
                    .foregroundStyle(Color.gray.opacity(ExploreAtRestMetrics.shadeOpacity))
                    // The summary and the headline say it; the band itself reads as nothing.
                    .accessibilityHidden(true)
                    // An overlay is offered the band's width: the longest wording that fits it is written.
                    .annotation(position: .overlay, alignment: .bottom) {
                        if labelsShading {
                            ExploreAtRestBandLabel(words: words)
                        }
                    }
            }
            // end

            // snippet:interaction-explore-do-not-require-selection
            // The selection, snapped to a day, is a rule behind the lines with the day's figures above it.
            if let selection {
                RuleMark(x: .value(CafeWording.day, selection.day, unit: .day, calendar: calendar))
                    .foregroundStyle(Color.gray.opacity(ExploreAtRestMetrics.ruleOpacity))
                    // The indicator repeats what the day's element already says.
                    .accessibilityHidden(true)
                    .offset(yStart: ExploreAtRestMetrics.ruleReach)
                    .zIndex(-1)
                    .annotation(
                        position: .top, spacing: 0,
                        overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                    ) {
                        ExploreAtRestPopover(selection: selection, locale: locale)
                    }
            }
            // end

            ForEach(series) { line in
                ForEach(line.points) { point in
                    LineMark(
                        x: .value(CafeWording.day, point.day, unit: .day, calendar: calendar),
                        y: .value(CafeWording.cups, point.cups)
                    )
                    // Each day's element below carries both cafés; the lines would repeat it.
                    .accessibilityHidden(true)
                }
                .foregroundStyle(by: .value(CafeWording.store, line.name))
            }

            // snippet:interaction-explore-do-not-require-elements
            // One element per day holding both cafés, so VoiceOver reaches by swiping what the finger reaches by
            // dragging. The clear full-height band gives every day the same top, so they are read in date order.
            ForEach(days) { day in
                Plot {
                    RectangleMark(x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar), width: .ratio(1))
                        .foregroundStyle(.clear)
                    PointMark(
                        x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar),
                        y: .value(CafeWording.cups, day.firstCups)
                    )
                    .foregroundStyle(by: .value(CafeWording.store, words.firstName))
                    .symbol(by: .value(CafeWording.store, words.firstName))
                    PointMark(
                        x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar),
                        y: .value(CafeWording.cups, day.secondCups)
                    )
                    .foregroundStyle(by: .value(CafeWording.store, words.secondName))
                    .symbol(by: .value(CafeWording.store, words.secondName))
                }
                .accessibilityLabel(words.elementLabel(day))
                .accessibilityValue(words.elementValue(day))
            }
            // end
        }
        // snippet:interaction-explore-do-not-require-binding
        // The whole plot is the target: a held press anywhere selects the day under the finger.
        .chartXSelection(value: $rawSelection)
        // end
        // The same colour and symbol for each café as on every screen that draws these two series.
        .chartForegroundStyleScale(domain: [words.firstName, words.secondName], mapping: CafeSeriesStyle.colour(for:))
        .chartSymbolScale(domain: [words.firstName, words.secondName], mapping: CafeSeriesStyle.symbol(for:))
        .chartYScale(domain: cupsDomain)
        .chartYAxis {
            // Few, light grid lines: people read exact values by touching, so the data stays prominent.
            AxisMarks(values: cupsAxisValues) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(ExploreAtRestMetrics.gridOpacity))
                AxisValueLabel().foregroundStyle(Color.secondary)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 7, calendar: calendar)) {
                AxisGridLine().foregroundStyle(Color.secondary.opacity(ExploreAtRestMetrics.gridOpacity))
                AxisTick()
                // At the accessibility sizes "Mar 22" no longer fits a week's width: the day alone does.
                AxisValueLabel(format: dynamicTypeSize.isAccessibilitySize
                    ? Date.FormatStyle(locale: locale, timeZone: calendar.timeZone).day()
                    : Date.FormatStyle(locale: locale, timeZone: calendar.timeZone).month(.abbreviated).day())
            }
        }
        .accessibilityChartDescriptor(ExploreAtRestDescriptor(
            words: words, cupsDomain: cupsDomain, isShowingMistake: isShowingMistake
        ))
        // The descriptor's summary changes with the mistake while the data's ids do not.
        .id(isShowingMistake)
    }
}

/// The day the shading starts, written inside it: "Since Mar 21", or "Mar 21" where that is too wide.
struct ExploreAtRestBandLabel: View {
    let words: ExploreAtRestWords

    var body: some View {
        ViewThatFits(in: .horizontal) {
            ForEach(words.bandLabels, id: \.self) { label in
                Text(label)
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
                    .lineLimit(1)
                    .fixedSize()
                    .padding(ExploreAtRestMetrics.labelPadding)
            }
        }
    }
}

/// The label above the selection: the day, then each café's cups.
struct ExploreAtRestPopover: View {
    let selection: ExploreAtRestSelection
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // At the accessibility sizes the figures stack and the day is shortened, so the label fits the chart.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading))
            : AnyLayout(HStackLayout(spacing: ExploreAtRestMetrics.popoverValueSpacing))
        VStack(alignment: .leading) {
            Text(dynamicTypeSize.isAccessibilitySize ? selection.shortDayText : selection.dayText)
                .font(.caption)
                .foregroundStyle(.secondary)
            layout {
                ExploreAtRestPopoverValue(name: selection.firstName, cups: selection.firstCups, locale: locale)
                ExploreAtRestPopoverValue(name: selection.secondName, cups: selection.secondCups, locale: locale)
            }
        }
        .padding(ExploreAtRestMetrics.popoverPadding)
        .background(
            Color.gray.opacity(ExploreAtRestMetrics.popoverBackgroundOpacity),
            in: .rect(cornerRadius: ExploreAtRestMetrics.popoverCornerRadius)
        )
    }
}

struct ExploreAtRestPopoverValue: View {
    let name: String
    let cups: Int
    let locale: Locale

    var body: some View {
        Text("\(Text(cups.formatted(.number.locale(locale))).font(.callout.bold())) \(Text(name).font(.caption).foregroundStyle(.secondary))")
    }
}

/// The Audio Graph: both cafés as lines over written-out days, on the drawn value axis.
nonisolated struct ExploreAtRestDescriptor: AXChartDescriptorRepresentable {
    let words: ExploreAtRestWords
    let cupsDomain: ClosedRange<Int>
    let isShowingMistake: Bool

    func makeChartDescriptor() -> AXChartDescriptor {
        let words = words
        let locale = words.locale
        let dayNames = words.days.map { words.longDay($0.day) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: dayNames)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: Double(cupsDomain.lowerBound) ... Double(cupsDomain.upperBound),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let first = AXDataSeriesDescriptor(
            name: words.firstName,
            isContinuous: true,
            dataPoints: zip(dayNames, words.days).map { AXDataPoint(x: $0, y: Double($1.firstCups)) }
        )
        let second = AXDataSeriesDescriptor(
            name: words.secondName,
            isContinuous: true,
            dataPoints: zip(dayNames, words.days).map { AXDataPoint(x: $0, y: Double($1.secondCups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold a day at \(CafeWording.list([words.firstName, words.secondName]))",
            summary: words.audioGraphSummary(isShowingMistake: isShowingMistake),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [first, second]
        )
    }
}

/// The snippets the Code view shows, following the mistake toggle.
enum ExploreAtRestSnippets {
    static let atRest = SnippetReference(name: "interaction-explore-do-not-require-at-rest", title: "The message, drawn at rest")
    static let binding = SnippetReference(name: "interaction-explore-do-not-require-binding", title: "Selection anywhere in the plot")
    static let selection = SnippetReference(name: "interaction-explore-do-not-require-selection", title: "The selected day, drawn as marks")
    static let elements = SnippetReference(name: "interaction-explore-do-not-require-elements", title: "The same figures for VoiceOver")
    static let mistake = SnippetReference(name: "interaction-explore-do-not-require-mistake", title: "The mistake: an instruction for a headline")

    static func references(isShowingMistake: Bool) -> [SnippetReference] {
        [isShowingMistake ? mistake : atRest, binding, selection, elements]
    }
}

#Preview("At rest") {
    NavigationStack {
        ExploreAtRestScreen(screen: CatalogScreen(
            id: "design/interaction-explore-do-not-require", title: "Interaction: explore, do not require",
            summary: "", apiSince: "17.0", skillReferences: ["design.md"],
            snippets: ExploreAtRestSnippets.references(isShowingMistake: false)
        ))
    }
}
