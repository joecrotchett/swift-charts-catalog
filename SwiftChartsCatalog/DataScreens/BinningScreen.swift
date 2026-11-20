import Accessibility
import Charts
import SwiftUI

/// "Binning": `NumberBins` for a histogram of order waits, and `DateBins` for weekly totals of daily cups.
struct BinningScreen: View {
    let screen: CatalogScreen
    @State private var model = BinningViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers
    /// the way the chart's own axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.kind == .waits ? "Orders by wait, in seconds" : "Cups sold per week",
            message: model.summary(locale: locale).headline,
            explanation: """
            A chart draws what it is given; it does not count or sum. NumberBins divides the waits into bins with \
            round boundaries and DateBins cuts the days into calendar weeks; ordinary Swift then counts or totals \
            each bin, and each bin goes to a BarMark as its x value, so the bar stands over its bin and rises to its \
            count. At .ratio(1) the bar fills its bin and neighbours touch; at the default width it is narrower than \
            its bin.
            """,
            snippets: model.snippets
        ) {
            BinningChart(model: model, locale: locale)
        } controls: {
            BinningControls(model: model, locale: locale)
        }
    }
}

/// The chart for the current binning, or a placeholder when there is nothing to draw.
struct BinningChart: View {
    let model: BinningViewModel
    let locale: Locale

    var body: some View {
        let summary = model.summary(locale: locale)
        if !summary.hasData {
            ContentUnavailableView(
                model.kind == .waits ? "No orders yet" : "No cups sold yet",
                systemImage: "chart.bar",
                description: Text(summary.headline)
            )
        } else {
            Group {
                switch model.kind {
                case .waits:
                    BinningWaitsChart(
                        bins: summary.waitBins, barWidth: model.barWidth,
                        isShowingMistake: model.isShowingMistake, summary: summary
                    )
                case .weeks:
                    BinningWeeksChart(
                        bins: summary.weekBins, barWidth: model.barWidth,
                        isShowingMistake: model.isShowingMistake, summary: summary
                    )
                }
            }
            // The labels change with the mistake while the bins' ids do not: a new identity makes
            // VoiceOver read the new words.
            .id(model.chartIdentity)
            .accessibilityChartDescriptor(BinningChartDescriptor(summary: summary))
        }
    }
}

/// A histogram of order waits: one bar over each bin, rising to its count.
struct BinningWaitsChart: View {
    let bins: [BinningWaitBin]
    let barWidth: BinningBarWidth
    let isShowingMistake: Bool
    let summary: BinningSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The span the bins cover: every wait falls inside it.
    private var waitDomain: ClosedRange<Int> {
        (bins.first?.range.lowerBound ?? 0) ... (bins.last?.range.upperBound ?? 0)
    }

    var body: some View {
        Chart(bins) { bin in
            Plot {
                if isShowingMistake {
                    // snippet:binning-histogram-mistake
                    // Wrong: with start and end on x, y is a position, not a length.
                    // Each bin draws as a dash at its count instead of a bar up to it.
                    BarMark(
                        xStart: .value(CafeWording.waitAxisTitle, bin.range.lowerBound),
                        xEnd: .value(CafeWording.waitAxisTitle, bin.range.upperBound),
                        y: .value(CafeWording.orders, bin.orders)
                    )
                    // end
                } else {
                    // snippet:binning-histogram
                    // The bin itself is the x value: the bar stands over it and rises from zero to the count.
                    // It fills the bin only at `.ratio(1)`; the default width leaves a gap beside it.
                    BarMark(
                        x: .value(CafeWording.waitAxisTitle, bin.range),
                        y: .value(CafeWording.orders, bin.orders),
                        width: barWidth.dimension
                    )
                    // end
                }
            }
            .accessibilityLabel(summary.waitRangeText(bin))
            .accessibilityValue(summary.waitValue(bin))
            // The bin the headline names, labelled with its edges: the axis labels round numbers, which may
            // not be this bin's edges. Not read aloud; the bin's element says the same.
            .headlineCallout(summary.tallestWaitBins.contains(where: { $0.id == bin.id }) ? summary.waitCallout(bin) : nil)
        }
        // From the first bin's start to the last bin's end, so the bars fill the plot.
        // `.automatic(includesZero: false)` still rounded this axis out to 0 ... 400.
        .chartXScale(domain: waitDomain)
        // One count axis for the chart and the descriptor.
        .chartYScale(domain: summary.waitCountDomain)
        .chartXAxis {
            // Two labels at the accessibility sizes, clear of the trailing value axis. (Asking
            // `.automatic(desiredCount: 2)` still gave three, and `.stride(by: 200)` gave only one.)
            if dynamicTypeSize >= .accessibility1 {
                AxisMarks(values: BinningAxis.sparseLabels(from: waitDomain.lowerBound, to: waitDomain.upperBound))
            } else {
                AxisMarks()
            }
        }
    }
}

/// Weekly totals of daily cups: one bar per calendar week.
struct BinningWeeksChart: View {
    let bins: [BinningWeekBin]
    let barWidth: BinningBarWidth
    let isShowingMistake: Bool
    let summary: BinningSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer labels as the text grows, so they do not collide.
    private var weeksPerLabel: Int {
        dynamicTypeSize >= .accessibility1 ? 5 : 2
    }

    /// The start of every `weeksPerLabel`-th week. The last boundary is left out: its label would
    /// sit past the plot's trailing edge.
    private var labelledBoundaries: [Date] {
        stride(from: 0, to: bins.count, by: weeksPerLabel).map { bins[$0].range.lowerBound }
    }

    var body: some View {
        Chart(bins) { bin in
            Plot {
                if isShowingMistake {
                    // snippet:binning-weekly-mistake
                    // Wrong: with start and end on x, y is a position, not a length.
                    // Each week draws as a dash at its total instead of a bar up to it.
                    BarMark(
                        xStart: .value(CafeWording.week, bin.range.lowerBound),
                        xEnd: .value(CafeWording.week, bin.range.upperBound),
                        y: .value(CafeWording.cups, bin.cups)
                    )
                    // end
                } else {
                    // snippet:binning-weekly-bars
                    // The week's bin is the x value: the bar stands over the seven days and rises to their total.
                    // It covers all seven only at `.ratio(1)`; the default width leaves a gap beside it.
                    BarMark(
                        x: .value(CafeWording.week, bin.range),
                        y: .value(CafeWording.cups, bin.cups),
                        width: barWidth.dimension
                    )
                    // end
                }
            }
            .accessibilityLabel(summary.weekLabel(bin))
            .accessibilityValue(summary.weekValue(bin))
            // The week the headline names, labelled by its first day: the axis labels every other week.
            .headlineCallout(summary.tallestWeekBins.contains(where: { $0.id == bin.id }) ? summary.weekCallout(bin) : nil)
        }
        // One cups axis for the chart and the descriptor.
        .chartYScale(domain: summary.weekCupsDomain)
        .chartXAxis {
            // The weeks were cut in UTC: label their boundaries in UTC too, in the view's locale,
            // or a device west of Greenwich names each week by the Saturday before it.
            AxisMarks(values: labelledBoundaries) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(
                    format: Date.FormatStyle(locale: summary.locale, timeZone: summary.timeZone).month(.abbreviated).day()
                )
            }
        }
    }
}

/// The screen's controls: which binning, how many bins, bar width, and the mistake.
struct BinningControls: View {
    @Bindable var model: BinningViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Binning", selection: $model.kind) {
                ForEach(BinningKind.allCases) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            switch model.kind {
            case .waits:
                LabeledStepper(
                    title: "Bins", value: $model.desiredBinCount, in: BinningViewModel.binCountRange,
                    valueText: model.binCountText(locale: locale),
                    spokenValue: model.binCountSpokenValue(locale: locale)
                )
            case .weeks:
                LabeledContent("Bins", value: "One per week, \(model.drawnBinCount.formatted(.number.locale(locale))) drawn")
            }
            LabeledSegmentedPicker(title: "Bar width", selection: $model.barWidth) {
                ForEach(BinningBarWidth.allCases) { width in
                    Text(width.rawValue).tag(width)
                }
            }
            .disabled(model.isShowingMistake)
            if let footnote = model.barWidthFootnote {
                Text(footnote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            MistakeToggle(title: "Plot each bin with xStart and xEnd", isShowingMistake: $model.isShowingMistake)
        }
        .onChange(of: model.kind) {
            BinningAnnouncer.announce(model.announcement(after: .kind, locale: locale))
        }
        .onChange(of: model.isShowingMistake) {
            BinningAnnouncer.announce(model.announcement(after: .mistake, locale: locale))
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
enum BinningAnnouncer {
    static func announce(_ message: String) {
        if #available(iOS 17.0, *) {
            AccessibilityNotification.Announcement(message).post()
        } else {
            UIAccessibility.post(notification: .announcement, argument: message)
        }
    }
}

/// The chart for the Audio Graph: a title, a summary in actual values, named axes, and values with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct BinningChartDescriptor: AXChartDescriptorRepresentable {
    let summary: BinningSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let mistake = summary.isShowingMistake ? ", each drawn as a dash" : ""
        switch summary.kind {
        case .waits:
            let bins = summary.waitBins
            return AXChartDescriptor(
                title: "Orders by wait, in bins of seconds\(mistake)",
                summary: summary.audioGraphSummary,
                xAxis: AXCategoricalDataAxisDescriptor(
                    title: CafeWording.waitAxisTitle,
                    categoryOrder: bins.map(summary.waitRangeText)
                ),
                yAxis: AXNumericDataAxisDescriptor(
                    title: CafeWording.orders,
                    range: summary.waitCountDomain,
                    gridlinePositions: []
                ) { value in CafeWording.count(value, locale: locale, as: CafeWording.orders(_:locale:)) },
                additionalAxes: [],
                series: [AXDataSeriesDescriptor(
                    name: CafeWording.orders,
                    isContinuous: false,
                    dataPoints: bins.map { AXDataPoint(x: summary.waitRangeText($0), y: Double($0.orders)) }
                )]
            )
        case .weeks:
            let bins = summary.weekBins
            return AXChartDescriptor(
                title: "Cups sold per week at the Harbour café\(mistake)",
                summary: summary.audioGraphSummary,
                xAxis: AXCategoricalDataAxisDescriptor(
                    title: CafeWording.week,
                    categoryOrder: bins.map(summary.weekLabel)
                ),
                yAxis: AXNumericDataAxisDescriptor(
                    title: CafeWording.cups,
                    range: summary.weekCupsDomain,
                    gridlinePositions: []
                ) { value in CafeWording.count(value, locale: locale) },
                additionalAxes: [],
                series: [AXDataSeriesDescriptor(
                    name: CafeWording.cups,
                    isContinuous: false,
                    dataPoints: bins.map { AXDataPoint(x: summary.weekLabel($0), y: Double($0.cups)) }
                )]
            )
        }
    }
}

#Preview("Binning") {
    NavigationStack {
        if let screen = Catalog.screen(id: "data/binning") {
            BinningScreen(screen: screen)
        }
    }
}

#Preview("No data") {
    BinningChart(model: BinningViewModel(waits: [], days: []), locale: .current)
}
