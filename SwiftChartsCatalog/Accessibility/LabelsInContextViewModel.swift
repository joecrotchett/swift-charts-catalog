import Accessibility
import Foundation
import Observation
import SwiftUI

/// Which words the bars give VoiceOver: none of the app's own, or a label and value written for them.
nonisolated enum LabelsInContextStyle: String, CaseIterable, Identifiable {
    /// No accessibility code: the framework's own description of each bar.
    case framework
    /// A label and value on a `Plot` around each bar.
    case written

    var id: String {
        rawValue
    }
}

/// One line of what VoiceOver reads for one bar.
nonisolated struct LabelsInContextSpokenLine: Identifiable, Equatable {
    let id: Date
    let label: String
    let value: String

    /// Label, then value, as VoiceOver reads them in turn.
    var spoken: String {
        "\(label), \(value)"
    }
}

/// Every text the screen says VoiceOver reads, in one place, so a line that turns out wrong on a device is
/// replaced here and nowhere else.
///
/// Both styles' lines match what was read on the iPhone 17 simulator, iOS 27, with the device six hours
/// behind UTC (`Docs/field-notes/epic-10/wave-2-dumps/lic-default.txt` and `lic-written.txt`). One mark at a
/// position is read as its x value then its y value; on a date axis binned with `unit: .day, calendar:` the
/// x value is the day as a range of date-times, written in the time zone of that calendar, not the device's.
nonisolated enum LabelsInContextSpokenText {
    /// What the framework reads for a bar of one day, cut in `dataCalendar`: the day as a range of
    /// date-times, from its start to the next day's, written in `dataCalendar`'s time zone. Read on iOS 27.
    static func frameworkLabel(for day: Date, dataCalendar: Calendar, locale: Locale) -> String {
        let end = dataCalendar.date(byAdding: .day, value: 1, to: day) ?? day
        return "\(frameworkDate(day, locale: locale, timeZone: dataCalendar.timeZone)) to "
            + frameworkDate(end, locale: locale, timeZone: dataCalendar.timeZone)
    }

    /// What the framework reads as the bar's value: the bare number, with no unit. Read on iOS 27.
    static func frameworkValue(cups: Int, locale: Locale) -> String {
        cups.formatted(.number.locale(locale))
    }

    /// "Mar 1, 2026 at 12 AM": the full date and the hour, in the given time zone. A day's bounds fall on
    /// the hour in the zone they were cut in, so the hour alone is what is read.
    private static func frameworkDate(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day().year().hour())
    }

    // snippet:labels-in-context-wording
    /// Context first: the day written out, in the time zone it was counted in, so the day spoken is the
    /// day drawn. "Sunday, March 1": no year, no time, no abbreviation.
    static func writtenLabel(for day: Date, dataCalendar: Calendar, locale: Locale) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, timeZone: dataCalendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// Then the value, with its unit, agreeing in number: "190 cups", "1 cup".
    static func writtenValue(cups: Int, locale: Locale) -> String {
        CafeWording.cups(cups, locale: locale)
    }

    // end

    /// The line for one bar in the given style.
    static func line(
        for day: DailySales,
        style: LabelsInContextStyle,
        dataCalendar: Calendar,
        locale: Locale
    ) -> LabelsInContextSpokenLine {
        switch style {
        case .framework:
            LabelsInContextSpokenLine(
                id: day.day,
                label: frameworkLabel(for: day.day, dataCalendar: dataCalendar, locale: locale),
                value: frameworkValue(cups: day.cups, locale: locale)
            )
        case .written:
            LabelsInContextSpokenLine(
                id: day.day,
                label: writtenLabel(for: day.day, dataCalendar: dataCalendar, locale: locale),
                value: writtenValue(cups: day.cups, locale: locale)
            )
        }
    }

    /// Where the spoken lines come from, shown above them.
    static func source(for style: LabelsInContextStyle) -> String {
        switch style {
        case .framework: "Read on the iPhone 17 simulator, iOS 27: the framework's defaults"
        case .written: "Read on the iPhone 17 simulator, iOS 27: the labels written on each Plot"
        }
    }

    /// How to hear the result on a device.
    static let howToHear = """
    To hear it on a device, turn VoiceOver on and swipe through the bars. Then open the rotor's Audio Graph: \
    Describe chart, and Play Audio Graph.
    """

    /// Said in place of the lines when no chart is drawn.
    static let nothingDrawn = "Nothing: no bars are drawn, so the placeholder is read instead."

    /// The Audio Graph is the same in both states, and the screen says so.
    static let audioGraphNote = """
    The switch changes the bars' elements only. The chart has the same chart descriptor in both states, \
    so the Audio Graph says the same.
    """
}

/// The words beside the chart, and the chart descriptor's, worked out from the data.
nonisolated struct LabelsInContextSummary {
    let days: [DailySales]
    let dataCalendar: Calendar
    let locale: Locale

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// Every day that sold the most, in data order. Empty when nothing sold.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// The top of the value axis: the highest day rounded up to the next step, so the bar and its
    /// figure fit. The descriptor's range uses the same.
    var valueAxisTop: Int {
        let most = days.map(\.cups).max() ?? 0
        let step = LabelsInContextScale.roundingStep
        return max(step, (most + step - 1) / step * step)
    }

    /// The caption above the chart, with the dates the data covers written month first, as on every other screen
    /// of these days: "March 1 – 7, 2026" (`CafeWording.dayRange`).
    var caption: String {
        CafeWording.harbourDaysCaption(from: days.first?.day, to: days.last?.day, locale: locale)
    }

    func dayName(_ day: Date) -> String {
        LabelsInContextSpokenText.writtenLabel(for: day, dataCalendar: dataCalendar, locale: locale)
    }

    /// The chart's message, with a figure drawn above the bar it names. True on a tie and with no sales.
    var headline: String {
        guard let cups = busiestDays.first?.cups else { return "No cups sold this week." }
        let names = CafeWording.list(busiestDays.map { dayName($0.day) })
        return "Busiest: \(names), with \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values only.
    var audioGraphSummary: String {
        guard let first = days.first, let last = days.last, let most = busiestDays.first?.cups else {
            return "No cups sold this week."
        }
        return "\(CafeWording.days(days.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), "
            + "last day \(CafeWording.cups(last.cups, locale: locale)). "
            + "Most: \(CafeWording.list(busiestDays.map { dayName($0.day) })), \(CafeWording.cups(most, locale: locale))."
    }
}

/// Constants that belong to this chart's scale.
nonisolated enum LabelsInContextScale {
    /// The value axis ends on the next multiple of this above the highest day.
    static let roundingStep = 50
}

/// The Audio Graph: a title, a summary, the days written out, and cups with their unit.
nonisolated struct LabelsInContextChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let dataCalendar: Calendar
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = LabelsInContextSummary(days: days, dataCalendar: dataCalendar, locale: locale)
        let locale = locale
        let names = days.map { summary.dayName($0.day) }
        return AXChartDescriptor(
            title: "Cups sold each day at the \(CafeWording.harbour) café",
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: names),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle,
                range: 0 ... Double(summary.valueAxisTop),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: zip(names, days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
            )]
        )
    }
}

/// The screen's state: which labels the bars carry, and the texts that follow from it.
@Observable
final class LabelsInContextViewModel {
    /// One week of the Harbour café: seven days stay one element each, so every bar is read on its own.
    let days: [DailySales]
    let dataCalendar: Calendar
    /// On: the framework's defaults, the shortfall the screen shows on purpose.
    var isShowingDefault = false

    init(days: [DailySales] = Array(CafeData.harbourSales.prefix(7)), dataCalendar: Calendar = CafeData.calendar) {
        self.days = days
        self.dataCalendar = dataCalendar
    }

    var style: LabelsInContextStyle {
        isShowingDefault ? .framework : .written
    }

    /// The code for the current state.
    var snippets: [SnippetReference] {
        switch style {
        case .framework:
            [SnippetReference(name: "labels-in-context-default", title: "No labels: the framework's description")]
        case .written:
            [
                SnippetReference(name: "labels-in-context-written", title: "A label and value on a Plot"),
                SnippetReference(name: "labels-in-context-wording", title: "Writing the label and value"),
            ]
        }
    }

    func summary(locale: Locale) -> LabelsInContextSummary {
        LabelsInContextSummary(days: days, dataCalendar: dataCalendar, locale: locale)
    }

    /// `true` when the week sold nothing: the chart shows a placeholder, so there are no bars to read and
    /// nothing for the switch to change.
    var isEmpty: Bool {
        days.allSatisfy { $0.cups == 0 }
    }

    /// What VoiceOver reads for each bar as drawn now; none when the placeholder shows.
    func spokenLines(locale: Locale) -> [LabelsInContextSpokenLine] {
        guard !isEmpty else { return [] }
        return days.map {
            LabelsInContextSpokenText.line(for: $0, style: style, dataCalendar: dataCalendar, locale: locale)
        }
    }

    /// What is wrong with the framework's description. Empty for the written labels and with no chart.
    func shortfalls(locale: Locale) -> [String] {
        guard style == .framework, !isEmpty, let first = days.first else { return [] }
        let value = LabelsInContextSpokenText.frameworkValue(cups: first.cups, locale: locale)
        let dayName = LabelsInContextSpokenText.writtenLabel(for: first.day, dataCalendar: dataCalendar, locale: locale)
        // Without `calendar:` the device's calendar cuts and writes the day: the local day the date falls in.
        var deviceCalendar = dataCalendar
        deviceCalendar.timeZone = TimeZone(secondsFromGMT: Self.contrastOffset) ?? dataCalendar.timeZone
        let withoutCalendar = LabelsInContextSpokenText.frameworkLabel(
            for: deviceCalendar.startOfDay(for: first.day), dataCalendar: deviceCalendar, locale: locale
        )
        return [
            "No unit: the value is the bare number \u{201C}\(value)\u{201D}. Nothing says it counts cups.",
            "Each day is read as a range of date-times, with the year and an hour every time, not as the day it is.",
            "The day read is right only because the bars are given the data's calendar. Leave out calendar: and the "
                + "device's cuts each day: six hours behind UTC, \(dayName) is read as \u{201C}\(withoutCalendar)\u{201D}, "
                + "the day before.",
        ]
    }

    /// Six hours behind UTC, the time zone of the simulator the readings were taken on.
    static let contrastOffset = -6 * 60 * 60
}
