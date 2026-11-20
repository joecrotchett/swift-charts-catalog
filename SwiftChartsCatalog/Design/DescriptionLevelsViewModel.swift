import Accessibility
import Foundation
import Observation
import SwiftUI

/// The four levels of description, in rising order of usefulness (`design.md`, *Descriptions*).
nonisolated enum DescriptionLevelsLevel: Int, CaseIterable, Hashable {
    case title = 1
    case keyValue
    case sentence
    case interpretation

    /// The word on the picker's segment: short enough for four segments at phone width.
    var shortName: String {
        switch self {
        case .title: "Title"
        case .keyValue: "Value"
        case .sentence: "Sentence"
        case .interpretation: "Meaning"
        }
    }

    /// What the level is, as the table in `design.md` names it.
    var longName: String {
        switch self {
        case .title: "a title that only names the chart"
        case .keyValue: "a title that carries the key value"
        case .sentence: "a sentence"
        case .interpretation: "an interpretation"
        }
    }

    /// "Level 2 of 4: a title that carries the key value".
    var caption: String {
        "Level \(rawValue) of \(Self.allCases.count): \(longName)"
    }
}

/// One week of the chart: its days and their daily average, rounded to whole cups as it is drawn and written.
nonisolated struct DescriptionLevelsWeek: Hashable {
    let days: [DailySales]

    var first: Date? {
        days.first?.day
    }

    var last: Date? {
        days.last?.day
    }

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// The daily average to the nearest cup. 0 for a week with no days.
    var average: Int {
        days.isEmpty ? 0 : Int((Double(total) / Double(days.count)).rounded())
    }
}

/// Every word around the chart, worked out from the data: the four levels of headline, the summary card's
/// figure and period, the elements' text and the chart descriptor's summary. Not tied to the main actor, so the
/// chart descriptor can use it.
nonisolated struct DescriptionLevelsSummary {
    /// The days the chart draws, in order: the last seven are "this week", the seven before "the week before".
    let days: [DailySales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    static let daysPerWeek = 7

    var thisWeek: DescriptionLevelsWeek {
        DescriptionLevelsWeek(days: Array(days.suffix(Self.daysPerWeek)))
    }

    /// The seven days before this week; empty when the data is a week or less.
    var weekBefore: DescriptionLevelsWeek {
        DescriptionLevelsWeek(days: Array(days.dropLast(Self.daysPerWeek).suffix(Self.daysPerWeek)))
    }

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// No days, or only zeros: bars grow from zero, so the chart would draw nothing. A placeholder shows instead.
    var hasNoSales: Bool {
        total == 0
    }

    // MARK: Dates, in the data's UTC calendar

    /// "March 22", in the data's calendar so the device's time zone cannot move it to the day before.
    func dayName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.wide).day())
    }

    /// "Sunday, March 22": an element's label.
    func fullDayName(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .weekday(.wide).month(.wide).day())
    }

    /// "from March 22 to March 28", or "" for a week with no days.
    func span(_ week: DescriptionLevelsWeek) -> String {
        guard let first = week.first, let last = week.last else { return "" }
        return "from \(dayName(first)) to \(dayName(last))"
    }

    /// The summary card's period: "Mar 22 – 28, 2026", in the locale's own interval form. Formatted to a
    /// string, so `Text` cannot write it in the device's time zone.
    var period: String {
        guard let first = thisWeek.first, let last = thisWeek.last else { return "" }
        let style = Date.IntervalFormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month().day().year()
        return (first ..< max(first, last)).formatted(style)
    }

    /// The summary card's period as VoiceOver says it, written out: "March 22 to March 28, 2026".
    var spokenPeriod: String {
        guard let first = thisWeek.first, let last = thisWeek.last else { return "" }
        let withYear = last.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.wide).day().year())
        return first == last ? withYear : "\(dayName(first)) to \(withYear)"
    }

    // MARK: The summary card's figure

    /// The figure and its unit together, agreeing in number: "236 cups", "1 cup".
    var figure: String {
        CafeWording.cups(thisWeek.average, locale: locale)
    }

    /// The figure's number alone, as the inflected string writes it: "236".
    var figureNumber: String {
        let number = thisWeek.average.formatted(.number.locale(locale))
        return figure.hasPrefix(number) ? number : figure
    }

    /// The unit after the figure's number, already agreeing with it: "cups", "cup". "" when the number and unit
    /// cannot be told apart, and the whole figure is then the number.
    var figureUnit: String {
        let number = figureNumber
        guard number != figure else { return "" }
        return String(figure.dropFirst(number.count)).trimmingCharacters(in: .whitespaces)
    }

    // MARK: The four levels

    func headline(_ level: DescriptionLevelsLevel) -> String {
        switch level {
        case .title: titleOnly
        case .keyValue: titleWithKeyValue
        case .sentence: sentence
        case .interpretation: interpretation
        }
    }

    // snippet:descriptions-say-the-message-title
    /// Level 1: a title that only names the chart. "Daily cups sold at the Harbour café over 14 days".
    var titleOnly: String {
        guard !days.isEmpty else { return "Daily cups sold at the \(CafeWording.harbour) café" }
        return "Daily cups sold at the \(CafeWording.harbour) café over \(CafeWording.days(days.count, locale: locale))"
    }

    // end

    // snippet:descriptions-say-the-message-key-value
    /// Level 2: a title that carries the key value. "Daily average this week: 236 cups".
    var titleWithKeyValue: String {
        guard !hasNoSales else { return "Daily average: no cups sold yet" }
        return "Daily average this week: \(CafeWording.cups(thisWeek.average, locale: locale))"
    }

    // end

    // snippet:descriptions-say-the-message-sentence
    /// Level 3: a sentence. "From March 22 to March 28, the Harbour café sold 236 cups a day on average."
    var sentence: String {
        guard !hasNoSales else { return "The \(CafeWording.harbour) café has no sales to show for these days yet." }
        let span = span(thisWeek)
        return "\(span.prefix(1).uppercased())\(span.dropFirst()), the \(CafeWording.harbour) café sold "
            + "\(CafeWording.cups(thisWeek.average, locale: locale)) a day on average."
    }

    // end

    // snippet:descriptions-say-the-message-interpretation
    /// Level 4: an interpretation, against the week before, which the chart also draws.
    /// "Daily sales are up 10% on the week before, averaging 236 cups from March 22 to March 28."
    var interpretation: String {
        guard !hasNoSales else { return "No cups sold in these days, so there is nothing to compare yet." }
        let now = thisWeek.average
        let averaging = "averaging \(CafeWording.cups(now, locale: locale)) \(span(thisWeek))"
        let before = weekBefore.average
        // No week before, or nothing sold in it: a percentage of zero means nothing, so say what is known.
        guard !weekBefore.days.isEmpty, before > 0 else {
            return "With no sales the week before to compare with, this week is \(averaging)."
        }
        // From the two rounded averages, as both are drawn and labelled, so a reader can check the figure.
        let change = Double(now - before) / Double(before)
        let percent = abs(change).formatted(.percent.precision(.fractionLength(0)).locale(locale))
        if now == before {
            return "Daily sales are level with the week before, \(averaging)."
        }
        if abs(change) < 0.005 {
            return "Daily sales are within 1% of the week before, \(averaging)."
        }
        return "Daily sales are \(change > 0 ? "up" : "down") \(percent) on the week before, \(averaging)."
    }

    // end

    // MARK: The chart's own labels

    /// The rules' visible names.
    let thisWeekName = "This week"
    let weekBeforeName = "Week before"

    /// A line of the key that replaces the rules' labels at the accessibility text sizes:
    /// "Solid line, this week: 236". Says which line, since the key sits apart from the rules.
    func ruleKey(isEmphasised: Bool) -> String {
        let week = isEmphasised ? thisWeek : weekBefore
        let name = isEmphasised ? thisWeekName : weekBeforeName
        return "\(isEmphasised ? "Solid" : "Dashed") line, \(name.lowercased()): \(week.average.formatted(.number.locale(locale)))"
    }

    /// The x axis's labels, in the data's calendar: "Mar 22", or the day alone at the accessibility sizes.
    func axisDayFormat(accessibilitySize: Bool) -> Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return accessibilitySize ? style.day() : style.month(.abbreviated).day()
    }

    // MARK: Accessibility

    /// A rule's label: "Daily average, March 22 to March 28".
    func averageLabel(_ week: DescriptionLevelsWeek) -> String {
        "Daily average, \(span(week).replacingOccurrences(of: "from ", with: ""))"
    }

    /// The Audio Graph's summary, in actual values with no judgement: no "up" or "down".
    var audioGraphSummary: String {
        guard !hasNoSales, let first = days.first?.day, let last = days.last?.day,
              let best = days.max(by: { $0.cups < $1.cups })
        else { return "No cups sold." }
        var words = "\(CafeWording.days(days.count, locale: locale)), \(dayName(first)) to \(dayName(last)). "
        if !weekBefore.days.isEmpty {
            words += "\(averageLabel(weekBefore)): \(CafeWording.cups(weekBefore.average, locale: locale)). "
        }
        words += "\(averageLabel(thisWeek)): \(CafeWording.cups(thisWeek.average, locale: locale)). "
        words += "Highest: \(fullDayName(best.day)), \(CafeWording.cups(best.cups, locale: locale))."
        return words
    }

    /// The value axis, from zero to the next 50 cups above the highest day (at least 50); the chart and the
    /// descriptor share it.
    var cupsAxis: ClosedRange<Double> {
        0 ... max(50, (Double(days.map(\.cups).max() ?? 0) / 50).rounded(.up) * 50)
    }
}

/// The state of "Descriptions: say the message": the days drawn and the level of description the headline is at.
@Observable
final class DescriptionLevelsViewModel {
    /// The two weeks the chart draws: the Harbour café's last fourteen days.
    let days: [DailySales]
    var level: DescriptionLevelsLevel = .title

    init(days: [DailySales] = Array(CafeData.harbourSales.suffix(2 * DescriptionLevelsSummary.daysPerWeek))) {
        self.days = days
    }

    func summary(locale: Locale) -> DescriptionLevelsSummary {
        DescriptionLevelsSummary(days: days, locale: locale)
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline(level)
    }

    /// Said when the level changes: what changed, then the headline it gives.
    func announcement(locale: Locale) -> String {
        "Level \(level.rawValue): \(level.longName). \(headline(locale: locale))"
    }

    /// The screen's explanation. Its last sentence points at the drawn chart, so it is true only when a chart is drawn.
    static func explanation(hasNoSales: Bool) -> String {
        let pattern = "The panel follows the pattern Apple's own apps use: a caption, a large figure with its unit, "
            + "the period it covers, then the chart as the evidence. The headline above it can say more or less: step "
            + "from a title that only names the chart to the key value, a sentence, and an interpretation. "
        guard !hasNoSales else {
            return pattern + "With no sales there is no figure to give: the levels that would carry one say so, and the chart is a placeholder."
        }
        return pattern + "Even at level 1, where the headline only names the chart, the card under it already carries "
            + "the figure. Every figure is worked out from the data and can be found on the chart: the solid line is "
            + "this week's daily average, the dashed line the week before's, with this week's bars at full strength."
    }

    static let cardSnippet = SnippetReference(name: "descriptions-say-the-message-summary-card", title: "Caption, figure, period, chart")

    /// The level's own snippet, after the summary card.
    static func levelSnippet(_ level: DescriptionLevelsLevel) -> SnippetReference {
        switch level {
        case .title: SnippetReference(name: "descriptions-say-the-message-title", title: "Level 1: a title")
        case .keyValue: SnippetReference(name: "descriptions-say-the-message-key-value", title: "Level 2: the key value")
        case .sentence: SnippetReference(name: "descriptions-say-the-message-sentence", title: "Level 3: a sentence")
        case .interpretation: SnippetReference(
                name: "descriptions-say-the-message-interpretation", title: "Level 4: an interpretation"
            )
        }
    }

    var snippets: [SnippetReference] {
        [Self.cardSnippet, Self.levelSnippet(level)]
    }

    /// Says the change aloud, for people who cannot see the headline change.
    func announce(locale: Locale) {
        AccessibilityNotification.Announcement(announcement(locale: locale)).post()
    }
}
