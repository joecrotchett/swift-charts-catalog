import Accessibility
import Charts
import SwiftUI

/// "A chart design system": two charts that differ by period, then by kind of data, then by measure,
/// with the design changing as much as the content does and no more.
struct ChartSystemScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ChartSystemViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, trends: [MonthlyDrinkCups] = CafeData.monthlyDrinkTrends) {
        self.screen = screen
        _viewModel = State(initialValue: ChartSystemViewModel(trends: trends))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Two charts, one design",
            message: viewModel.headline(locale: locale),
            explanation: """
            Charts with a similar purpose share one design, so what people learn from one carries to the next, \
            and they differ only as much as their content does. The top chart stays the same; at each step the \
            bottom one changes one more thing. Every chart takes its colour from one mapping of drink to colour, \
            the app's own (Small multiples uses it too), so the same drink is the same colour wherever it appears; \
            and every cups chart of these drinks shares one scale, both here and Small multiples' charts on their \
            shared scale, so the same cups are the same height wherever they appear. The three colours weigh \
            the same in greyscale, so changing the drink changes the colour and not how loud the chart is.
            """,
            snippets: viewModel.snippets
        ) {
            ChartSystemPanel(viewModel: viewModel, locale: locale)
        } controls: {
            ChartSystemControls(viewModel: viewModel, locale: locale)
        }
        .onChange(of: viewModel.step) {
            // A step changes what the second chart draws: say so, then the headline.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The two charts, one above the other.
struct ChartSystemPanel: View {
    let viewModel: ChartSystemViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
            ChartSystemChart(spec: viewModel.reference, data: viewModel.data, locale: locale)
            ChartSystemChart(spec: viewModel.compared, data: viewModel.data, locale: locale)
        }
    }
}

/// One chart of the system: its heading, then its marks or a placeholder.
struct ChartSystemChart: View {
    let spec: ChartSystemChartSpec
    let data: ChartSystemData
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(ChartSystemWording.heading(spec, locale: locale))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                // Wraps at large text rather than cutting the months off; the chart below gives up the height.
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if data.hasMarks(for: spec) {
                ChartSystemMarks(spec: spec, data: data, locale: locale)
            } else {
                ContentUnavailableView(
                    "No cups sold",
                    systemImage: "cup.and.saucer",
                    description: Text("Cups of \(spec.drink) sold each month appear here.")
                )
            }
        }
    }
}

/// The marks of one chart. Everything about how it looks follows from its spec: the measure picks the mark
/// and the scale, the drink picks the colour, and the axes are the same for every chart.
struct ChartSystemMarks: View {
    let spec: ChartSystemChartSpec
    let data: ChartSystemData
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var points: [ChartSystemPoint] {
        data.points(for: spec)
    }

    /// The value axis's labels: the ends of the scale and its middle, a sequence read at a glance.
    private var valueAxisValues: [Double] {
        let domain = data.valueDomain(for: spec.measure)
        return [domain.lowerBound, (domain.lowerBound + domain.upperBound) / 2, domain.upperBound]
    }

    /// "Mar", or "M" at the accessibility sizes, where six abbreviated months were each cut to an ellipsis.
    private var monthLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return style.month(dynamicTypeSize >= .accessibility1 ? .narrow : .abbreviated)
    }

    /// The value label's colour: secondary beside the mark, primary at the accessibility sizes, where the
    /// label is larger than the room above the bar and is pushed down over it.
    private var labelStyle: Color {
        dynamicTypeSize.isAccessibilitySize ? .primary : .secondary
    }

    var body: some View {
        let marked = data.markedMonths(for: spec)
        Chart {
            ForEach(points) { point in
                Plot {
                    // snippet:a-chart-design-system-mark
                    // One mark per measure, wherever it is drawn: cups are bars, a share is a line with points.
                    switch spec.measure {
                    case .cups:
                        BarMark(
                            x: .value(CafeWording.month, point.month, unit: .month, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, point.value)
                        )
                    case .share:
                        LineMark(
                            x: .value(CafeWording.month, point.month, unit: .month, calendar: CafeData.calendar),
                            y: .value(ChartSystemWording.share, point.value),
                            series: .value(ChartSystemWording.run, point.run)
                        )
                        .symbol(.circle)
                    }
                    // end
                }
                .foregroundStyle(by: .value(CafeWording.drink, spec.drink))
                // The figure the headline names, written on its own bar; the other months carry no label.
                // A line's marks draw an annotation once for the whole line, at its first point, and a label
                // set for any other point draws nothing (read on iOS 27), so a share's label is hung below.
                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))) {
                    if spec.measure == .cups, marked.contains(point.month) {
                        ChartSystemValueLabel(text: writtenValue(point), style: labelStyle)
                    }
                }
                .accessibilityLabel(ChartSystemWording.monthAndYear(point.month, locale: locale))
                .accessibilityValue(spokenValue(point))
            }
            if spec.measure == .share {
                // A line has no single mark to annotate: a point of no size at the marked month carries it.
                ForEach(points.filter { marked.contains($0.month) }) { point in
                    PointMark(
                        x: .value(CafeWording.month, point.month, unit: .month, calendar: CafeData.calendar),
                        y: .value(ChartSystemWording.share, point.value)
                    )
                    .symbolSize(0)
                    .accessibilityHidden(true)
                    .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))) {
                        ChartSystemValueLabel(text: writtenValue(point), style: labelStyle)
                    }
                }
            }
        }
        // snippet:a-chart-design-system-colour
        // One mapping of drink to colour for every chart, with the domain fixed: Tea is green wherever it
        // appears, and Latte keeps brown whichever drinks a chart happens to show.
        .chartForegroundStyleScale(domain: CafeDrinkStyle.drinks, mapping: CafeDrinkStyle.colour(for:))
        // The heading names the drink, so the legend would only repeat it.
        .chartLegend(.hidden)
        // end
        // snippet:a-chart-design-system-one-style
        // Every cups chart shares one scale, so a bar's height means the same cups in each; a share runs 0 to 100.
        .chartYScale(domain: data.valueDomain(for: spec.measure))
        .chartYAxis {
            if spec.measure == .share {
                AxisMarks(values: valueAxisValues) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(ChartSystemMetrics.gridOpacity))
                    AxisValueLabel(format: Decimal.FormatStyle.Percent.percent.scale(1).locale(locale))
                        .foregroundStyle(Color.secondary)
                }
            } else {
                AxisMarks(values: valueAxisValues) { _ in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(ChartSystemMetrics.gridOpacity))
                    AxisValueLabel().foregroundStyle(Color.secondary)
                }
            }
        }
        // The same month axis on every chart, cut in the data's calendar and written in the view's locale.
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1, calendar: CafeData.calendar)) { _ in
                AxisTick()
                AxisValueLabel(format: monthLabelFormat, centered: true)
            }
        }
        // end
        .accessibilityChartDescriptor(ChartSystemChartDescriptor(spec: spec, data: data, locale: locale))
        // Element text and the descriptor change with the spec while some months stay the same: a new identity.
        .id("\(spec)-\(locale.identifier)")
    }

    private func writtenValue(_ point: ChartSystemPoint) -> String {
        switch spec.measure {
        case .cups: point.cups.formatted(.number.locale(locale))
        case .share: ChartSystemWording.percent(point.value, locale: locale)
        }
    }

    private func spokenValue(_ point: ChartSystemPoint) -> String {
        switch spec.measure {
        case .cups:
            CafeWording.cups(point.cups, locale: locale)
        case .share:
            "\(ChartSystemWording.percent(point.value, locale: locale)) of all cups, \(CafeWording.cups(point.cups, locale: locale))"
        }
    }
}

/// The figure the headline names, as written on the chart.
struct ChartSystemValueLabel: View {
    let text: String
    let style: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(style)
    }
}

/// Strengths that belong to this screen's charts alone.
private enum ChartSystemMetrics {
    /// Light grid lines, so the marks lead; the labels stay at secondary.
    static let gridOpacity = 0.2
}

/// The step controls, and the row of the table each step stands for.
struct ChartSystemControls: View {
    let viewModel: ChartSystemViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            Text(viewModel.stepTitle)
                .font(.headline)
            LabeledContent("What changed", value: viewModel.step.whatChanged)
            LabeledContent("Change in the design", value: viewModel.step.designChange)
            Text(viewModel.lookFor(locale: locale))
                .foregroundStyle(.secondary)
            HStack {
                Button("Back", systemImage: "chevron.backward") {
                    viewModel.goBack()
                }
                .disabled(!viewModel.canGoBack)
                Spacer()
                Button("Next", systemImage: "chevron.forward") {
                    viewModel.goForward()
                }
                .disabled(!viewModel.canGoForward)
            }
            .buttonStyle(.bordered)
        }
    }
}

/// The chart for the Audio Graph: its heading as the title, a summary in actual values, months written out,
/// and values said with their unit. Not tied to the main actor: the accessibility system calls it when it chooses.
nonisolated struct ChartSystemChartDescriptor: AXChartDescriptorRepresentable {
    let spec: ChartSystemChartSpec
    let data: ChartSystemData
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let measure = spec.measure
        let points = data.points(for: spec)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.month,
            categoryOrder: spec.monthDates.map { ChartSystemWording.monthAndYear($0, locale: locale) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: measure == .cups ? CafeWording.cupsAxisTitle : ChartSystemWording.share,
            range: data.valueDomain(for: measure),
            gridlinePositions: []
        ) { value in
            switch measure {
            case .cups: CafeWording.count(value, locale: locale)
            case .share: value.isFinite ? ChartSystemWording.percent(value, locale: locale) : ""
            }
        }
        let series = AXDataSeriesDescriptor(
            name: measure == .cups ? spec.drink : "\(spec.drink), \(ChartSystemWording.share.lowercased())",
            isContinuous: measure == .share,
            dataPoints: points.map { AXDataPoint(x: ChartSystemWording.monthAndYear($0.month, locale: locale), y: $0.value) }
        )
        return AXChartDescriptor(
            title: ChartSystemWording.heading(spec, locale: locale),
            summary: summary(points),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }

    /// The months, then the highest and lowest values with their months: actual values, no judgement.
    func summary(_ points: [ChartSystemPoint]) -> String {
        guard data.hasMarks(for: spec),
              let highest = points.map(\.value).max(), let lowest = points.map(\.value).min()
        else { return "No cups sold in \(ChartSystemWording.period(spec, locale: locale))." }
        let say: (Double) -> String = { value in
            switch spec.measure {
            case .cups: CafeWording.count(value, locale: locale)
            case .share: "\(ChartSystemWording.percent(value, locale: locale)) of all cups"
            }
        }
        // Months are compared as they are written: two shares that both read 49% are both the highest.
        let written: (Double) -> String = { value in
            switch spec.measure {
            case .cups: CafeWording.count(value, locale: locale)
            case .share: ChartSystemWording.percent(value, locale: locale)
            }
        }
        let monthsAt: (Double) -> String = { value in
            ChartSystemWording.months(points.filter { written($0.value) == written(value) }.map(\.month), locale: locale)
        }
        return "\(CafeWording.months(points.count, locale: locale)). "
            + "Highest: \(monthsAt(highest)), \(say(highest)). Lowest: \(monthsAt(lowest)), \(say(lowest))."
    }
}

#Preview("Steps") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/a-chart-design-system") {
            ChartSystemScreen(screen: screen)
        }
    }
}

#Preview("No cups") {
    ChartSystemPanel(viewModel: ChartSystemViewModel(trends: []), locale: .current)
        .padding()
}
