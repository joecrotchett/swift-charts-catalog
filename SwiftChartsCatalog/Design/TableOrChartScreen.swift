import Accessibility
import Charts
import SwiftUI

/// "Table or chart": the same four weeks as a list to scan and sort, and as a chart with a point.
struct TableOrChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: TableOrChartViewModel
    /// Read here and passed in, so the headline, the rows and the Audio Graph write numbers one way.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.harbourSales) {
        self.screen = screen
        _viewModel = State(initialValue: TableOrChartViewModel(days: days))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption(locale: locale),
            message: viewModel.headline(locale: locale),
            explanation: """
            When people need the values, give them a list they can scan and sort: every day's cups are exact, \
            and sorting by cups puts the busiest day at the top. When they need the point, give them a chart \
            with a headline that says it; in the chart, the dashed line is the daily average its headline quotes. \
            Swift Charts draws only the chart: the list is plain SwiftUI.
            """,
            snippets: viewModel.snippets
        ) {
            switch viewModel.form {
            case .list:
                TableOrChartList(viewModel: viewModel, locale: locale) { sort in
                    Self.announce(viewModel.sortRows(sort, locale: locale))
                }
            case .chart:
                TableOrChartChart(days: viewModel.days, locale: locale)
            }
        } controls: {
            ControlsSection {
                LabeledSegmentedPicker(
                    title: "Show the days as",
                    selection: Binding(
                        get: { viewModel.form },
                        set: { Self.announce(viewModel.show($0, locale: locale)) }
                    )
                ) {
                    ForEach(TableOrChartForm.allCases) { form in
                        Text(form.title).tag(form)
                    }
                }
                .disabled(!viewModel.hasDays)
            }
        }
    }

    /// Says aloud that what is drawn changed, for people who cannot see it happen.
    static func announce(_ message: String?) {
        guard let message else { return }
        // The app's target is iOS 18, so the iOS 17 announcement needs no fallback.
        AccessibilityNotification.Announcement(message).post()
    }
}

// MARK: The list

/// Every day and its cups, with column headings that sort the rows.
struct TableOrChartList: View {
    let viewModel: TableOrChartViewModel
    let locale: Locale
    let onSort: (TableOrChartSort) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if viewModel.hasDays {
            // snippet:table-or-chart-list
            VStack(spacing: 0) {
                // Tapping a heading sorts by that column: the values people came for, in the order they need.
                TableOrChartListHeader(sort: viewModel.sort, onSort: onSort)
                // At the accessibility sizes the panel holds only a few rows: say that the rest scroll.
                if dynamicTypeSize.isAccessibilitySize {
                    Text(viewModel.scrollNote(locale: locale))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, Layout.itemSpacing)
                }
                Divider()
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.rows(locale: locale)) { row in
                            TableOrChartListRow(row: row)
                            Divider()
                        }
                    }
                }
            }
            // end
        } else {
            ContentUnavailableView(
                "No days recorded",
                systemImage: "list.bullet",
                description: Text("Each day's cups appear here, one row per day.")
            )
        }
    }
}

/// The two column headings, each a button that sorts by its column.
struct TableOrChartListHeader: View {
    let sort: TableOrChartSort
    let onSort: (TableOrChartSort) -> Void

    var body: some View {
        HStack {
            TableOrChartSortButton(title: CafeWording.day, sort: .byDay, isActive: sort == .byDay, onSort: onSort)
            Spacer()
            // The chevron leads, so "Cups" ends at the trailing edge, over the column of values.
            TableOrChartSortButton(
                title: CafeWording.cups, sort: .byCups, isActive: sort == .byCups, chevronLeads: true, onSort: onSort
            )
        }
        .font(.subheadline.weight(.semibold))
        .padding(.bottom, Layout.itemSpacing)
    }
}

/// One column heading. The chevron shows which column the rows are sorted by.
struct TableOrChartSortButton: View {
    let title: String
    let sort: TableOrChartSort
    let isActive: Bool
    /// The chevron before the title, for a heading over a trailing column.
    var chevronLeads = false
    let onSort: (TableOrChartSort) -> Void

    var body: some View {
        Button {
            onSort(sort)
        } label: {
            HStack(spacing: Layout.tightSpacing) {
                if chevronLeads { TableOrChartSortChevron(sort: sort, isActive: isActive) }
                Text(title)
                if !chevronLeads { TableOrChartSortChevron(sort: sort, isActive: isActive) }
            }
        }
        .accessibilityLabel("Sort by \(title.lowercased())")
        // The order this heading sorts in; the selected trait says whether it is the order now.
        .accessibilityValue(sort.direction)
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }
}

/// The chevron beside a heading: drawn for the order in use, kept as space for the other.
struct TableOrChartSortChevron: View {
    let sort: TableOrChartSort
    let isActive: Bool

    var body: some View {
        Image(systemName: sort.symbolName)
            .opacity(isActive ? 1 : 0)
            .accessibilityHidden(true)
    }
}

/// One day: its date at the leading edge and its cups at the trailing edge, stacked at the accessibility sizes.
struct TableOrChartListRow: View {
    let row: TableOrChartRow
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.tightSpacing))
            : AnyLayout(HStackLayout())
        layout {
            Text(row.dayText)
            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }
            Text(row.cupsText)
                .monospacedDigit()
                .fontWeight(.semibold)
        }
        .padding(.vertical, Layout.itemSpacing)
        .frame(maxWidth: .infinity, alignment: .leading)
        // One stop per row: the day, then its cups with the unit said.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(row.spokenDay)
        .accessibilityValue(row.spokenCups)
    }
}

// MARK: The chart

/// A bar per day under a dashed rule at the daily average, or a placeholder when nothing sold.
struct TableOrChartChart: View {
    let days: [DailySales]
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var summary: TableOrChartSummary {
        TableOrChartSummary(days: days)
    }

    var body: some View {
        // No days, or only zeros, would draw axes with no bars under a headline that is not true.
        if summary.hasNoCups {
            ContentUnavailableView(
                "No cups sold",
                systemImage: "chart.bar",
                description: Text("Each day's cups appear here, one bar per day.")
            )
        } else {
            let averageText = "Average: \(CafeWording.cups(summary.roundedAverage, locale: locale))"
            // At the accessibility sizes the plot is too narrow for the label on the rule: it moves under the chart.
            let labelsTheRule = !dynamicTypeSize.isAccessibilitySize
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                // snippet:table-or-chart-chart
                Chart {
                    ForEach(days) { day in
                        Plot {
                            // The days were counted in UTC: the calendar keeps each bar on its own day.
                            BarMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                        }
                        .accessibilityLabel(TableOrChartSummary.spokenDay(day.day, locale: locale))
                        .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                    }
                    // The point of the chart, drawn: the average the headline quotes.
                    TableOrChartAverageRule(
                        average: summary.average,
                        spokenValue: CafeWording.cups(summary.roundedAverage, locale: locale),
                        label: labelsTheRule ? averageText : nil
                    )
                }
                .chartYScale(domain: summary.cupsAxis)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7, calendar: CafeData.calendar)) { _ in
                        AxisGridLine()
                        AxisTick()
                        // "Mar 1" is cut to "M…" at the accessibility sizes: the day alone fits.
                        AxisValueLabel(format: labelsTheRule ? dayFormat.month(.abbreviated).day() : dayFormat.day())
                    }
                }
                .accessibilityChartDescriptor(TableOrChartChartDescriptor(days: days, locale: locale))
                // end
                if !labelsTheRule {
                    TableOrChartAverageKey(text: averageText)
                }
            }
        }
    }

    /// Dates written in the data's time zone and the view's locale.
    private var dayFormat: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
    }
}

/// The dashed rule at the daily average, labelled on the rule when there is room.
struct TableOrChartAverageRule: ChartContent {
    let average: Double
    let spokenValue: String
    /// The visible label, or `nil` when it is shown under the chart instead.
    let label: String?

    var body: some ChartContent {
        let rule = RuleMark(y: .value(CafeWording.cups, average))
            .foregroundStyle(Color.primary)
            .lineStyle(StrokeStyle(lineWidth: TableOrChartMarks.ruleWidth, dash: TableOrChartMarks.ruleDash))
            // Annotation views are not read; the rule's label and value carry the words.
            .accessibilityLabel("Daily average")
            .accessibilityValue(spokenValue)
        if let label {
            // No background behind the text: one would hide the tops of the bars it crosses.
            rule.annotation(position: .top, alignment: .leading) {
                Text(label)
                    .font(.caption.weight(.semibold))
            }
        } else {
            rule
        }
    }
}

/// The rule's label under the chart, as a key, at the sizes where it does not fit on the rule.
struct TableOrChartAverageKey: View {
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Layout.itemSpacing) {
            Text(verbatim: "- - -")
                .accessibilityHidden(true)
            Text(text)
        }
        .font(.caption.weight(.semibold))
        // The rule itself is the element VoiceOver reads; the key repeats it.
        .accessibilityHidden(true)
    }
}

/// Constants that belong to this chart's marks.
private enum TableOrChartMarks {
    static let ruleWidth: CGFloat = 1.5
    static let ruleDash: [CGFloat] = [4, 3]
}

/// The chart for the Audio Graph: a bar per day, said with its date and unit, and the average in the summary.
nonisolated struct TableOrChartChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = TableOrChartSummary(days: days)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { TableOrChartSummary.spokenDay($0.day, locale: locale) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: days.map { AXDataPoint(x: TableOrChartSummary.spokenDay($0.day, locale: locale), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups each day at the \(CafeWording.harbour) café",
            summary: summary.audioGraphSummary(locale: locale),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Four weeks") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/table-or-chart") {
            TableOrChartScreen(screen: screen)
        }
    }
}

#Preview("Chart") {
    TableOrChartChart(days: CafeData.harbourSales, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No days") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/table-or-chart") {
            TableOrChartScreen(screen: screen, days: [])
        }
    }
}
