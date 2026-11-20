import Accessibility
import Charts
import SwiftUI

/// Sizes and strengths that belong to this screen's two charts.
private enum OverviewDetailMetrics {
    /// The compact chart's height: about 100 points, as a compact overview is.
    static let compactHeight: CGFloat = 100
    /// The detail chart's height at the default text size: around 240 points on iPhone.
    static let detailHeight: CGFloat = 240
    /// Room above the top value label, which is centred on the top of the domain, growing with the text.
    static let topLabelRoom: CGFloat = 8
    static let topLabelRoomMaximum: CGFloat = 24
    /// A bar's opacity while another day is selected.
    static let fadedOpacity = 0.3
    static let gridOpacity = 0.2
}

/// "Overview and detail": a compact chart with a headline that opens the same chart in full.
struct OverviewDetailScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: OverviewDetailViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.harbourSales) {
        self.screen = screen
        _viewModel = State(initialValue: OverviewDetailViewModel(days: days))
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        // The panel fits the compact card: the standard chart height left about 250 points blank under a card
        // of about 180.
        CatalogScreenScaffold(
            screen: screen,
            caption: "Daily cups at \(CafeWording.harbour)",
            message: summary.message,
            explanation: """
            The compact chart answers at a glance: a caption, the figure its hidden axes would have carried, and the \
            shape of the days. Tapping it opens the same bars, in the same colour and on the same scale, at 240 points \
            with axes and selection, under a headline that starts from the same total and period.
            """,
            panelHeight: .fitsContent
        ) {
            OverviewDetailCompactCard(viewModel: viewModel, locale: locale)
        } controls: {
            OverviewDetailTryIt(spoken: summary.spoken, hasChart: summary.hasChart)
        }
        .navigationDestination(isPresented: $viewModel.isShowingDetail) {
            OverviewDetailFullChartView(viewModel: viewModel)
        }
    }
}

/// The bars both charts draw: one definition, so the overview and the detail plot the same data the same way.
// snippet:overview-and-detail-bars
struct OverviewDetailBars: ChartContent {
    let days: [DailySales]
    let summary: OverviewDetailSummary
    /// The day selected in the detail; `nil` draws every bar at full strength.
    var selectedDay: Date?

    var body: some ChartContent {
        ForEach(days) { day in
            Plot {
                BarMark(
                    x: .value(CafeWording.day, day.day, unit: .day, calendar: summary.calendar),
                    y: .value(CafeWording.cups, day.cups)
                )
                // Set inside the type, so neither chart can draw the café in another colour.
                .foregroundStyle(CafeSeriesStyle.colour(for: CafeWording.harbour))
                .opacity(OverviewDetailSummary.isEmphasised(day.day, selectedDay: selectedDay) ? 1 : OverviewDetailMetrics.fadedOpacity)
            }
            .accessibilityLabel(summary.elementLabel(day.day))
            .accessibilityValue(CafeWording.cups(day.cups, locale: summary.locale))
        }
    }
}

// end

/// The overview: caption, figure, period and a small bare chart, all one button that opens the detail.
struct OverviewDetailCompactCard: View {
    let viewModel: OverviewDetailViewModel
    let locale: Locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        let spoken = summary.spoken
        // snippet:overview-and-detail-compact
        Button {
            viewModel.openDetail()
        } label: {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                OverviewDetailHeadlineView(headline: viewModel.compactHeadline(locale: locale), showsChevron: true)
                if summary.hasChart {
                    Chart {
                        OverviewDetailBars(days: viewModel.days, summary: summary)
                    }
                    // The same domain as the detail, so the bars keep their heights when it opens.
                    .chartYScale(domain: 0 ... summary.axisTop)
                    .chartXAxis(.hidden)
                    .chartYAxis(.hidden)
                    .frame(height: OverviewDetailMetrics.compactHeight)
                } else {
                    ContentUnavailableView(
                        "No sales in these days", systemImage: "cup.and.saucer",
                        description: Text("Days with cups sold appear here.")
                    )
                }
            }
            .contentShape(.rect)
            // The card's words and bars are said by the button's own label and value: hidden, so neither a
            // second button nor the days are left under it in the tree.
            .accessibilityHidden(true)
        }
        .buttonStyle(.plain)
        .disabled(!summary.hasChart)
        // A preview is one element with a succinct description; the detail has the full chart.
        // Collapsing the button drops its trait, so it is added back.
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(spoken.compactLabel)
        .accessibilityValue(spoken.compactValue)
        // end
    }
}

/// The detail: the same bars at around 240 points, with axes, selection and an Audio Graph.
struct OverviewDetailFullChartView: View {
    @Bindable var viewModel: OverviewDetailViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                    ZStack(alignment: .topLeading) {
                        // The longest selected headline and the resting one, unseen, so the chart does not
                        // move when a selection changes the lines above it.
                        if let longest = summary.longestSelectedHeadline {
                            OverviewDetailHeadlineView(headline: longest, showsChevron: false)
                                .hidden()
                                .accessibilityHidden(true)
                        }
                        OverviewDetailHeadlineView(headline: summary.headline, showsChevron: false)
                            .hidden()
                            .accessibilityHidden(true)
                        OverviewDetailHeadlineView(headline: viewModel.detailHeadline(locale: locale), showsChevron: false)
                    }
                    if summary.hasChart {
                        OverviewDetailChart(viewModel: viewModel, summary: summary)
                    } else {
                        ContentUnavailableView(
                            "No sales in these days", systemImage: "cup.and.saucer",
                            description: Text("Days with cups sold appear here.")
                        )
                    }
                }
                .padding(Layout.panelPadding)
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
                Text("""
                The same bars, colour and scale as the overview, with axes added. Touch and hold the chart, then drag, \
                to read one day; with VoiceOver, swipe through the chart a day at a time, or use the rotor's Audio Graph.
                """)
                .foregroundStyle(.secondary)
            }
            .padding(Layout.screenPadding)
            .frame(maxWidth: Layout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Daily cups at \(CafeWording.harbour)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The detail chart itself.
struct OverviewDetailChart: View {
    @Bindable var viewModel: OverviewDetailViewModel
    let summary: OverviewDetailSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var height = OverviewDetailMetrics.detailHeight
    @ScaledMetric(relativeTo: .caption) private var topLabelRoom = OverviewDetailMetrics.topLabelRoom

    /// Fewer labels at the largest text sizes, so they do not collide.
    private var isThinned: Bool {
        dynamicTypeSize >= .accessibility3
    }

    var body: some View {
        let calendar = summary.calendar
        // snippet:overview-and-detail-detail
        Chart {
            OverviewDetailBars(days: viewModel.days, summary: summary, selectedDay: viewModel.selectedDay?.day)
        }
        // The overview's domain, with room above the top label.
        .chartYScale(
            domain: 0 ... summary.axisTop,
            range: .plotDimension(endPadding: min(topLabelRoom, OverviewDetailMetrics.topLabelRoomMaximum))
        )
        .chartXAxis {
            // The data's own days, every week or every fortnight: a stride ran on to a March 29 the data lacks.
            AxisMarks(values: summary.labelledDays(thinned: isThinned)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(
                    format: Date.FormatStyle(locale: summary.locale, calendar: calendar, timeZone: calendar.timeZone)
                        .month(.abbreviated).day()
                )
            }
        }
        .chartYAxis {
            AxisMarks(values: summary.axisValues(thinned: isThinned)) { _ in
                // Light grid lines on a chart people touch; the labels stay at secondary.
                AxisGridLine().foregroundStyle(Color.secondary.opacity(OverviewDetailMetrics.gridOpacity))
                AxisValueLabel().foregroundStyle(Color.secondary)
            }
        }
        .chartXSelection(value: $viewModel.rawSelectedDate)
        .accessibilityChartDescriptor(OverviewDetailDescriptor(summary: summary))
        .frame(height: height)
        // end
    }
}

/// Caption, figure with its unit, and the period: the lines the overview and the detail share.
struct OverviewDetailHeadlineView: View {
    let headline: OverviewDetailHeadline
    let showsChevron: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            HStack {
                Text(headline.caption)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                if showsChevron {
                    Image(systemName: "chevron.forward")
                        .foregroundStyle(.tertiary)
                }
            }
            Text(headline.figure)
                .font(.title2.bold())
            Text(headline.period)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// How to use the pair, and what VoiceOver reads on the overview, as read on iOS.
struct OverviewDetailTryIt: View {
    let spoken: OverviewDetailSpokenText
    let hasChart: Bool

    var body: some View {
        ControlsSection {
            Text(hasChart
                ? "Tap the overview to open the detail. Touch and hold the detail chart, then drag, to read one day."
                : "With no cups sold there is no chart, so the overview does not open.")
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text("What VoiceOver reads on the overview")
                    .font(.headline)
                Text(OverviewDetailSpokenText.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Label", value: spoken.compactLabel)
                LabeledContent("Value", value: spoken.compactValue)
                LabeledContent("Trait", value: "Button")
                Text("""
                One element with the Button trait and no Audio Graph: collapsing the chart into one element removes it. \
                The detail is read a day at a time and has its own. To hear it on a device: turn VoiceOver on, swipe to \
                the overview, open it, swipe through the chart, then use the rotor's Audio Graph (Describe chart, \
                Play Audio Graph).
                """)
                .font(.callout)
                .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// The detail chart's Audio Graph: written-out days, cups with their unit, and the overview's value axis.
nonisolated struct OverviewDetailDescriptor: AXChartDescriptorRepresentable {
    let summary: OverviewDetailSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let spoken = summary.spoken
        let locale = summary.locale
        let categories = summary.days.map { summary.category($0.day) }
        return AXChartDescriptor(
            title: spoken.descriptorTitle,
            summary: spoken.descriptorSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: categories),
            yAxis: AXNumericDataAxisDescriptor(
                title: spoken.descriptorAxisTitle,
                range: 0 ... Double(summary.axisTop),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: summary.days.map { AXDataPoint(x: summary.category($0.day), y: Double($0.cups)) }
            )]
        )
    }
}

#Preview("Overview") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/overview-and-detail") {
            OverviewDetailScreen(screen: screen)
        }
    }
}

#Preview("Detail") {
    NavigationStack {
        OverviewDetailFullChartView(viewModel: OverviewDetailViewModel())
    }
}

#Preview("No sales") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/overview-and-detail") {
            OverviewDetailScreen(screen: screen, days: [])
        }
    }
}
