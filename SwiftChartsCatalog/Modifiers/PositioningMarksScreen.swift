import Accessibility
import Charts
import SwiftUI

/// "Positioning marks": `offset` moves a mark by points on screen without changing its value. Two
/// cafés' lollipops share each day, so they are nudged apart with `offset(x:y:)` (or `offset(_:)`),
/// and each stem is moved with its head and stopped short of it with the start-and-end form.
struct PositioningMarksScreen: View {
    let screen: CatalogScreen
    var stores = PositioningMarksData.week
    @State private var viewModel = PositioningMarksViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and
    /// dates the way the chart's own axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = PositioningMarksSummary(stores: stores, locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: summary.caption,
            message: summary.headline,
            explanation: """
            offset moves a mark by a distance in points after the scale has placed it, so the value it shows \
            does not change: each lollipop still stands at its day and its cups. offset(x:y:), or offset(_:) \
            with a CGSize, which is the same move, moves each café's heads by the distance set below, Harbour's one way and Station's the other, \
            so they sit twice that far apart. \
            The start-and-end form, offset(xStart:xEnd:yStart:yEnd:), moves each edge of the thin stem bar on its own: \
            both x edges follow the head, and yStart, the top edge on screen, moves down by the inset set below, \
            so the stem can stop at the ring instead of crossing it.
            """,
            snippets: viewModel.snippets
        ) {
            PositioningMarksChart(stores: stores, viewModel: viewModel, locale: locale)
        } controls: {
            PositioningMarksControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The two offset sliders and the choice of how the nudge is written.
struct PositioningMarksControls: View {
    @Bindable var viewModel: PositioningMarksViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSlider(
                title: "Nudge apart", value: $viewModel.nudge, range: PositioningMarksViewModel.nudgeRange,
                valueText: viewModel.nudgeText(locale: locale)
            )
            LabeledSlider(
                title: "Stem stops short of the value", value: $viewModel.stemInset,
                range: PositioningMarksViewModel.stemInsetRange, valueText: viewModel.stemInsetText(locale: locale)
            )
            LabeledSegmentedPicker(title: "Head nudged with offset", selection: $viewModel.nudgeForm) {
                ForEach(PositioningMarksNudgeForm.allCases) { form in
                    Text(form.rawValue).tag(form)
                }
            }
        }
    }
}

/// Constants that belong to this chart's marks.
private enum PositioningMarksStyle {
    /// The head's area in square points: about a 10-point ring.
    static let headSize: CGFloat = 100
    static let ringWidth: CGFloat = 2
    static let stemWidth: CGFloat = 2
}

/// A lollipop per café per day, or a placeholder when nothing was sold.
struct PositioningMarksChart: View {
    let stores: [StoreSales]
    let viewModel: PositioningMarksViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Every second day labelled at the accessibility sizes, so the weekday names do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility1 ? 2 : 1
    }

    var body: some View {
        let summary = PositioningMarksSummary(stores: stores, locale: locale)
        if summary.isEmpty {
            ContentUnavailableView(
                "No sales this week",
                systemImage: "cup.and.saucer",
                description: Text("Each café's cups appear here, one lollipop per day.")
            )
        } else {
            Chart(summary.entries) { entry in
                // The stem and head are one thing, so one Plot makes them one element. Its words come
                // from the data: the offset moves the marks on screen, not the value they show.
                Plot {
                    PositioningMarksLollipop(
                        entry: entry, shift: viewModel.shift(for: entry.store),
                        stemInset: viewModel.stemInset(for: entry), nudgeForm: viewModel.nudgeForm
                    )
                }
                .accessibilityLabel("\(summary.dayName(entry.day)), \(entry.store)")
                .accessibilityValue(CafeWording.cups(entry.cups, locale: locale))
                .foregroundStyle(by: .value(CafeWording.store, entry.store))
                .symbol(by: .value(CafeWording.store, entry.store))
            }
            // Each café in its colour on every screen that draws the two; the rings are its shapes, outlined.
            .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale([
                CafeWording.harbour: AnyChartSymbolShape(.circle.strokeBorder(lineWidth: PositioningMarksStyle.ringWidth)),
                CafeWording.station: AnyChartSymbolShape(.square.strokeBorder(lineWidth: PositioningMarksStyle.ringWidth)),
            ])
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    // Centred only when every day is labelled; with a longer stride it would sit mid-stride.
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                            .weekday(.abbreviated),
                        centered: daysPerLabel == 1
                    )
                }
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(
                PositioningMarksChartDescriptor(stores: stores, nudge: viewModel.nudge, locale: locale)
            )
        }
    }
}

/// One café's day: a stem from zero to the value and a hollow head at the value, both moved by `shift`
/// points across, the stem's top stopping `stemInset` points short of the value (none on a day with no
/// cups, where the stem has no height to take it).
/// An offset's start and end are the mark's edges on screen (top and bottom, leading and trailing),
/// not its data start and end.
struct PositioningMarksLollipop: ChartContent {
    let entry: PositioningMarksEntry
    let shift: CGFloat
    let stemInset: CGFloat
    let nudgeForm: PositioningMarksNudgeForm

    var body: some ChartContent {
        // snippet:positioning-marks-stem
        // A thin bar, not a rule: on a vertical RuleMark the xStart and xEnd offsets do nothing.
        BarMark(
            x: .value(CafeWording.day, entry.day, unit: .day, calendar: CafeData.calendar),
            yStart: .value(CafeWording.cups, 0),
            yEnd: .value(CafeWording.cups, entry.cups),
            width: .fixed(PositioningMarksStyle.stemWidth)
        )
        // In points on screen: both x edges move with the head, and yStart, the top edge, moves down
        // by the inset so the stem stops at the ring. yEnd, the bottom edge, stays on the baseline.
        .offset(xStart: shift, xEnd: shift, yStart: stemInset, yEnd: 0)
        // end
        switch nudgeForm {
        case .xAndY:
            // snippet:positioning-marks-nudge-xy
            PointMark(
                x: .value(CafeWording.day, entry.day, unit: .day, calendar: CafeData.calendar),
                y: .value(CafeWording.cups, entry.cups)
            )
            .symbolSize(PositioningMarksStyle.headSize)
            // Harbour's head moves one way, Station's the other: the value is unchanged.
            .offset(x: shift)
        // end
        case .size:
            // snippet:positioning-marks-nudge-size
            PointMark(
                x: .value(CafeWording.day, entry.day, unit: .day, calendar: CafeData.calendar),
                y: .value(CafeWording.cups, entry.cups)
            )
            .symbolSize(PositioningMarksStyle.headSize)
            // The same move as offset(x: shift), written as one size.
            .offset(CGSize(width: shift, height: 0))
            // end
        }
    }
}

/// The week the screen draws: both cafés, Monday 16 to Sunday 22 March, when they sold about the
/// same on weekdays, so their marks at one day nearly coincide.
nonisolated enum PositioningMarksData {
    static let week: [StoreSales] = CafeData.storeSales.map { store in
        StoreSales(store: store.store, days: store.days.filter { day in
            day.day >= CafeData.day(15) && day.day <= CafeData.day(21)
        })
    }
}

/// One café's cups on one day: one lollipop.
nonisolated struct PositioningMarksEntry: Identifiable, Hashable {
    let store: String
    let day: Date
    let cups: Int

    var id: String {
        "\(store)-\(day.timeIntervalSinceReferenceDate)"
    }
}

/// What the chart says in words: its headline, its element text and the Audio Graph's summary.
nonisolated struct PositioningMarksSummary {
    let stores: [StoreSales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// Day by day, the cafés in their data order within each day: the order VoiceOver visits them,
    /// which matches the order they are drawn in along the axis.
    var entries: [PositioningMarksEntry] {
        days.flatMap { day in
            stores.compactMap { store in
                store.days.first { $0.day == day }.map { PositioningMarksEntry(store: store.store, day: day, cups: $0.cups) }
            }
        }
    }

    /// Every day any café has, in order.
    var days: [Date] {
        Array(Set(stores.flatMap { $0.days.map(\.day) })).sorted()
    }

    /// No days, or nothing sold on any of them: lollipops of zero would draw a bare baseline.
    var isEmpty: Bool {
        entries.allSatisfy { $0.cups == 0 }
    }

    /// For each day both cafés have, which sold more: Harbour, Station, or neither on a tie.
    private var leads: [String?] {
        days.compactMap { day -> String?? in
            let cups = stores.map { store in store.days.first { $0.day == day }?.cups }
            guard cups.count == 2, let first = cups[0], let second = cups[1] else { return nil }
            if first == second { return .some(nil) }
            return .some(first > second ? stores[0].store : stores[1].store)
        }
    }

    /// The chart's message: which café sold more on how many days. Counted from the marks as drawn,
    /// so it holds at every setting of the controls, which move marks and never change a value.
    var headline: String {
        guard !isEmpty, stores.count == 2 else { return "No cups sold at either café this week." }
        let compared = leads
        guard !compared.isEmpty else { return "The two cafés have no day in common to compare." }
        let first = compared.count(where: { $0 == stores[0].store })
        let second = compared.count(where: { $0 == stores[1].store })
        let ties = compared.count - first - second
        let total = CafeWording.days(compared.count, locale: locale)
        let oneDay = compared.count == 1
        if ties == compared.count {
            return oneDay ? "Both cafés sold the same on the one day shown." : "Both cafés sold the same on all \(total)."
        }
        let level = ties > 0 ? ", level on \(number(ties))" : ""
        if first == second {
            return "Each sold more on \(number(first)) of the \(total)\(level)."
        }
        let (leader, more, other, fewer) = second > first
            ? (stores[1].store, second, stores[0].store, first)
            : (stores[0].store, first, stores[1].store, second)
        if more == compared.count {
            return oneDay ? "\(leader) sold more on the one day shown." : "\(leader) sold more on all \(total)."
        }
        return "\(leader) sold more on \(number(more)) of the \(total), \(other) on \(number(fewer))\(level)."
    }

    /// The days drawn, first to last, written in the environment's locale and the data's calendar and
    /// time zone: "16 – 22 March" in British English, with thin spaces. Empty when there are no days.
    var dateRange: String {
        guard let first = days.first, let last = days.last else { return "" }
        if first == last {
            return first.formatted(
                Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                    .day().month(.wide)
            )
        }
        return (first ..< last).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                .day().month(.wide)
        )
    }

    /// The cups axis as drawn, from zero to the busiest day at either café rounded up to the axis step (261 →
    /// 300): the chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: stores.flatMap { $0.days.map(\.cups) })
    }

    /// The screen's caption, with the days drawn.
    var caption: String {
        dateRange.isEmpty ? "Cups sold each day at both cafés" : "Cups sold each day at both cafés, \(dateRange)"
    }

    /// The Audio Graph's title, with the days drawn.
    var descriptorTitle: String {
        let title = "Cups sold each day at the \(CafeWording.harbour) and \(CafeWording.station) cafés"
        return dateRange.isEmpty ? title : "\(title), \(dateRange)"
    }

    /// The Audio Graph's summary: actual values, and what the offset does to the drawing.
    func audioGraphSummary(nudge: Double) -> String {
        guard !isEmpty else { return headline }
        let perStore = stores.map { store in
            let cups = store.days.map(\.cups)
            return "\(store.store): lowest \(CafeWording.cups(cups.min() ?? 0, locale: locale)), "
                + "highest \(CafeWording.cups(cups.max() ?? 0, locale: locale))."
        }
        let drawing = nudge > 0
            ? "Each day's two marks are drawn \(CafeWording.points(nudge * 2, locale: locale)) apart, "
            + "\(stores.first?.store ?? "") first; the nudge moves them on screen and does not change their values."
            : "Each day's two marks are drawn at the same place, so where the values are close they cover each other."
        return "\(CafeWording.days(days.count, locale: locale)). \(headline) " + perStore.joined(separator: " ") + " " + drawing
    }

    /// "Monday, 16 March", in the data's time zone so it names the day that is drawn.
    func dayName(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                .weekday(.wide).day().month(.wide)
        )
    }

    private func number(_ count: Int) -> String {
        count.formatted(.number.locale(locale))
    }
}

/// The chart for the Audio Graph: two series over the week's days, values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct PositioningMarksChartDescriptor: AXChartDescriptorRepresentable {
    let stores: [StoreSales]
    /// The nudge in points, so the summary describes the marks as drawn.
    let nudge: Double
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = PositioningMarksSummary(stores: stores, locale: locale)
        let locale = locale
        return AXChartDescriptor(
            title: summary.descriptorTitle,
            summary: summary.audioGraphSummary(nudge: nudge),
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: summary.days.map(summary.dayName)),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle, range: summary.valueDomain, gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: stores.map { store in
                AXDataSeriesDescriptor(
                    name: store.store,
                    isContinuous: false,
                    dataPoints: store.days.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
                )
            }
        )
    }
}

#Preview("Week") {
    NavigationStack {
        PositioningMarksScreen(
            screen: CatalogScreen(
                id: "mark-modifiers/positioning-marks", title: "Positioning marks", summary: "", apiSince: "16.0",
                skillReferences: ["mark-modifiers.md"]
            )
        )
    }
}

#Preview("No sales") {
    PositioningMarksChart(stores: [], viewModel: PositioningMarksViewModel(), locale: .current)
}
