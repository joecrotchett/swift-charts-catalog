import Foundation
import Observation

/// The stages the day axis goes through, from the framework's default to the finished axis.
/// Each stage adds one idea to the one before.
enum AxisFormattingStage: Int, CaseIterable, Identifiable {
    case automatic = 1
    case formatStyle
    case byValue
    case twoLines
    case centredDays

    var id: Int {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic: "Default axis"
        case .formatStyle: "A format style"
        case .byValue: "Labels by value"
        case .twoLines: "Two-line labels"
        case .centredDays: "Centred day labels"
        }
    }

    /// What this stage changes, in a sentence shown under the control.
    var note: String {
        switch self {
        case .automatic:
            "AxisMarks() with no arguments: the framework picks the dates and their format, in the device's calendar. "
                + "The days were counted in UTC, so away from UTC a label can sit a day off its bar."
        case .formatStyle:
            "AxisMarks(format:values:) marks every seventh day in the data's calendar and writes each as month and day."
        case .byValue:
            "The closure reads each AxisValue: the month is written only on the first label, and where a month starts."
        case .twoLines:
            "Each label is a view: the day of the month, with the month on a second line under the first label."
        case .centredDays:
            "Every day is marked, with its label centred under its bar. Grid lines and ticks only on each Sunday."
        }
    }

    /// The snippet that shows this stage's axis.
    var snippet: SnippetReference {
        switch self {
        case .automatic: SnippetReference(name: "axis-formatting-default", title: "The default axis")
        case .formatStyle: SnippetReference(name: "axis-formatting-format-style", title: "A format style on the axis")
        case .byValue: SnippetReference(name: "axis-formatting-by-value", title: "Labels that differ by value")
        case .twoLines: SnippetReference(name: "axis-formatting-two-lines", title: "Two-line labels")
        case .centredDays: SnippetReference(name: "axis-formatting-centred-days", title: "Centred day labels")
        }
    }
}

/// The state of the "Formatting and conditional labels" screen: two weeks of daily cups, and the stage
/// the day axis is at. Only the axis changes between stages; the data, the scale and the marks do not.
@Observable
final class AxisFormattingViewModel {
    /// Two weeks of the Harbour café's daily cups, Sunday 1 to Saturday 14 March 2026.
    let days: [DailySales]
    var stage: AxisFormattingStage = .automatic

    init(days: [DailySales] = Array(CafeData.harbourSales.prefix(14))) {
        self.days = days
    }

    /// The stage as a number from 1, for the stepper.
    var stageNumber: Int {
        get { stage.rawValue }
        set { stage = AxisFormattingStage(rawValue: newValue) ?? stage }
    }

    var stageCount: Int {
        AxisFormattingStage.allCases.count
    }

    /// "Stage 2 of 5: A format style", shown and spoken by the stepper.
    var stageDescription: String {
        "Stage \(stage.rawValue) of \(stageCount): \(stage.title)"
    }

    var snippets: [SnippetReference] {
        [stage.snippet]
    }
}

/// How the screen writes the sample dates. They were made in UTC, so every date is written in the
/// data's time zone and the view's locale: on a device west of Greenwich, midnight UTC would
/// otherwise be written as the day before.
nonisolated struct AxisFormattingDateText {
    let locale: Locale
    var calendar: Calendar = CafeData.calendar

    private var style: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: calendar.timeZone)
    }

    /// "Mar 1".
    var monthDay: Date.FormatStyle {
        style.month(.abbreviated).day()
    }

    /// "8".
    var dayNumber: Date.FormatStyle {
        style.day()
    }

    /// "Mar".
    var monthName: Date.FormatStyle {
        style.month(.abbreviated)
    }

    /// "S" for Sunday.
    var weekdayInitial: Date.FormatStyle {
        style.weekday(.narrow)
    }

    /// "Saturday, March 14": unambiguous, for what is read aloud and for the headline.
    var spoken: Date.FormatStyle {
        style.weekday(.wide).month(.wide).day()
    }

    /// "March 14", for the period the chart covers.
    var writtenDay: Date.FormatStyle {
        style.month(.wide).day()
    }

    func callAsFunction(_ date: Date, _ format: Date.FormatStyle) -> String {
        date.formatted(format)
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct AxisFormattingSummary {
    let days: [DailySales]
    /// The locale every date and count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    private var text: AxisFormattingDateText {
        AxisFormattingDateText(locale: locale)
    }

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// Whether there is anything to draw: no days, or only zeros, get a placeholder instead of a chart.
    var hasSales: Bool {
        total > 0
    }

    /// The screen's caption, the same as every chart of the Harbour café's days: "Cups sold each day at the Harbour
    /// café, March 1 – 14, 2026".
    var caption: String {
        CafeWording.harbourDaysCaption(from: days.first?.day, to: days.last?.day, locale: locale)
    }

    /// The label written over a day the headline names: "Mar 14: 240".
    func calloutText(for day: DailySales) -> String {
        let date = day.day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day()
        )
        return "\(date): \(day.cups.formatted(.number.locale(locale)))"
    }

    /// Every day with the most cups, in date order. More than one on a tie; none when nothing sold.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// Every day with the fewest cups, in date order.
    var quietestDays: [DailySales] {
        guard let fewest = days.map(\.cups).min(), hasSales else { return [] }
        return days.filter { $0.cups == fewest }
    }

    func names(_ days: [DailySales]) -> String {
        CafeWording.list(days.map { text($0.day, text.spoken) })
    }

    /// The chart's message in a sentence, with a figure that can be found on the chart.
    var headline: String {
        guard let most = busiestDays.first?.cups else { return "No cups sold in these two weeks." }
        let cups = CafeWording.cups(most, locale: locale)
        if busiestDays.count > 1 {
            return "The busiest days were \(names(busiestDays)), with \(cups) each."
        }
        return "The busiest day was \(names(busiestDays)), with \(cups)."
    }

    /// The first and last dates, written out: "March 1 to March 14".
    var period: String {
        guard let first = days.first?.day, let last = days.last?.day else { return "" }
        return "\(text(first, text.writtenDay)) to \(text(last, text.writtenDay))"
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = busiestDays.first?.cups, let fewest = quietestDays.first?.cups,
              let first = days.first?.cups, let last = days.last?.cups
        else { return "No cups sold in these two weeks." }
        return "\(CafeWording.days(days.count, locale: locale)), \(period). "
            + "First day \(CafeWording.cups(first, locale: locale)), last day \(CafeWording.cups(last, locale: locale)). "
            + "Most: \(names(busiestDays)), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(names(quietestDays)), \(CafeWording.cups(fewest, locale: locale))."
    }
}
