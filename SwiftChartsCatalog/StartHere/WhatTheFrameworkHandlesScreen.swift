import Accessibility
import Charts
import SwiftUI

/// "What the framework handles": one chart, drawn in another appearance, text size and locale with no code changed.
struct WhatTheFrameworkHandlesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = WhatTheFrameworkHandlesViewModel()
    /// The device's text size: what the chart is drawn at while the Text size control is on Device.
    @Environment(\.dynamicTypeSize) private var deviceTextSize

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold at the Harbour café, running total",
            message: viewModel.headline,
            explanation: viewModel.explanation(deviceTextSize: deviceTextSize),
            snippets: viewModel.snippets,
            chart: {
                FrameworkHandlesChart(totals: viewModel.totals)
                    // Room for the axis labels that reach past the plot, inside the forced background.
                    .padding(Layout.itemSpacing)
                    .chartEnvironment(viewModel.chartEnvironment)
            },
            controls: {
                FrameworkHandlesControls(viewModel: viewModel)
            }
        )
        // The axes are redrawn by each of the three controls, so each change is said, not only seen.
        .onChange(of: viewModel.chartEnvironment) { previous, _ in
            AccessibilityNotification.Announcement(
                viewModel.announcement(after: previous, deviceTextSize: deviceTextSize)
            ).post()
        }
    }
}

/// The three settings forced on the chart alone.
struct FrameworkHandlesControls: View {
    @Bindable var viewModel: WhatTheFrameworkHandlesViewModel

    var body: some View {
        ControlsSection {
            LabeledMenuPicker(title: "Appearance", selection: $viewModel.appearance) {
                ForEach(FrameworkHandlesAppearance.allCases) { Text($0.title).tag($0) }
            }
            LabeledMenuPicker(title: "Text size", selection: $viewModel.textSize) {
                ForEach(FrameworkHandlesTextSize.allCases) { Text($0.title).tag($0) }
            }
            LabeledMenuPicker(title: "Locale", selection: $viewModel.locale) {
                ForEach(FrameworkHandlesLocale.allCases) { Text($0.title).tag($0) }
            }
        }
    }
}

/// A line of the running total, or a placeholder when nothing has been sold.
/// Nothing in here reads the appearance, the text size or the locale, and nothing is configured.
struct FrameworkHandlesChart: View {
    let totals: [FrameworkHandlesRunningTotal]

    var body: some View {
        let summary = FrameworkHandlesSummary(totals: totals)
        // Nothing sold is no data: a flat line on the baseline under a headline that is not true.
        if summary.total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("The running total of cups sold appears here, a day at a time.")
            )
        } else {
            // snippet:what-the-framework-handles-chart
            // No colour, no font, no number or date format, no axis: all of that is left to the framework,
            // which is why this one chart can be drawn in any appearance, text size and locale.
            Chart(totals) { total in
                // A label and a value for VoiceOver, on a Plot around the mark. The line is still one line.
                Plot {
                    LineMark(
                        x: .value("Day", total.day, unit: .day),
                        y: .value("Cups", total.cups)
                    )
                }
                .accessibilityLabel(summary.spokenDay(total.day))
                .accessibilityValue(summary.spokenValue(total.cups))
            }
            // end
            .accessibilityChartDescriptor(FrameworkHandlesChartDescriptor(totals: totals))
        }
    }
}

/// The cups sold up to and including one day.
nonisolated struct FrameworkHandlesRunningTotal: Identifiable, Hashable {
    /// The start of the day in the device's time zone.
    let day: Date
    let cups: Int

    var id: Date {
        day
    }

    /// Each day's sales added to all the days before it, in the order given.
    ///
    /// The sample days are midnights in `dataCalendar` (UTC). Each is moved to the start of the same calendar day
    /// in `timeZone`, the device's, because the chart's default axis cuts and labels days in the device's calendar:
    /// left as they are, every point west of Greenwich would be drawn on the day before.
    static func totals(
        of days: [DailySales], dataCalendar: Calendar = CafeData.calendar, timeZone: TimeZone = .current
    ) -> [FrameworkHandlesRunningTotal] {
        var deviceCalendar = Calendar(identifier: .gregorian)
        deviceCalendar.timeZone = timeZone
        var sum = 0
        return days.map { day in
            sum += day.cups
            let sameDay = dataCalendar.dateComponents([.year, .month, .day], from: day.day)
            return FrameworkHandlesRunningTotal(day: deviceCalendar.date(from: sameDay) ?? day.day, cups: sum)
        }
    }
}

/// What the chart says in words: its headline, what VoiceOver reads for a day, and the Audio Graph's summary.
nonisolated struct FrameworkHandlesSummary {
    let totals: [FrameworkHandlesRunningTotal]

    /// The last running total: everything sold.
    var total: Int {
        totals.last?.cups ?? 0
    }

    /// The chart's message: the height of the line's last point. The total is written nowhere on the chart, so the
    /// figure is in `locale`, the reader's, like the words around it. True for one day, and when nothing sold.
    func headline(locale: Locale) -> String {
        guard total > 0 else { return Self.nothingSold }
        return "The café sold \(CafeWording.cups(total, locale: locale)) in \(Self.daysText(totals.count, locale: locale))."
    }

    static let nothingSold = "No cups sold yet."

    /// A day written out in words, in the time zone the chart draws it in.
    func spokenDay(_ day: Date) -> String {
        day.formatted(.dateTime.weekday(.wide).month(.wide).day())
    }

    func spokenValue(_ cups: Int) -> String {
        "\(Self.cupsText(cups)) so far"
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard total > 0, let first = totals.first else { return Self.nothingSold }
        return "\(Self.daysText(totals.count)). \(Self.cupsText(first.cups)) after the first day, "
            + "\(Self.cupsText(total)) after the last."
    }

    /// A count with its unit, agreeing in number: "1 cup", "5,726 cups".
    static func cupsText(_ cups: Int) -> String {
        CafeWording.cups(cups, locale: .current)
    }

    static func daysText(_ days: Int, locale: Locale = .current) -> String {
        CafeWording.days(days, locale: locale)
    }

    /// The cups axis as drawn, for the descriptor. This chart's subject is that nothing is configured, so its scale
    /// stays automatic; `ChartAxis` gives the same rounded top the automatic axis draws (0 to 6,000 for 5,726), so
    /// the Audio Graph reads the drawn ends.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: [total])
    }
}

/// The chart for the Audio Graph: a title, a summary, written-out dates and values said in cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct FrameworkHandlesChartDescriptor: AXChartDescriptorRepresentable {
    let totals: [FrameworkHandlesRunningTotal]

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = FrameworkHandlesSummary(totals: totals)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: totals.map { summary.spokenDay($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Cups sold so far",
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in FrameworkHandlesSummary.cupsText(count) } }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: totals.map { AXDataPoint(x: summary.spokenDay($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Running total of cups sold at the Harbour café, by day",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Device settings") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/what-the-framework-handles") {
            WhatTheFrameworkHandlesScreen(screen: screen)
        }
    }
}

#Preview("Dark, Accessibility 2, German") {
    FrameworkHandlesChart(totals: FrameworkHandlesRunningTotal.totals(of: CafeData.harbourSales))
        .chartEnvironment(
            ChartEnvironment(colorScheme: .dark, dynamicTypeSize: .accessibility2, locale: Locale(identifier: "de_DE"))
        )
        .padding()
}

#Preview("No sales") {
    FrameworkHandlesChart(totals: [])
}
