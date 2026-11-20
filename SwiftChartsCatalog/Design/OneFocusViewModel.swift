import Foundation
import Observation

/// How strongly one month's marks are drawn.
nonisolated enum OneFocusEmphasis: Equatable {
    /// The month that leads: blue, its range bar at the recipe's strength and its tick solid.
    case focused
    /// A month that steps back: blue, faded to 30% of the focused month's strength.
    case faded
    /// A month under the average line: grey, so the line is the only colour.
    case muted
    /// Every month at full strength: the mistake, where nothing leads.
    case full

    /// The fade applied to the faded months, the skill's "opacity around 0.3".
    static let fadedStrength = 0.3
    /// The fade in Dark Mode. Weight depends on the background (`design.md`): at 0.3 the faded navy months nearly
    /// vanished on the dark panel, so each appearance gets its own strength.
    static let fadedStrengthDark = 0.45

    /// The faded months' strength in one appearance.
    static func fadedStrength(isDark: Bool) -> Double {
        isDark ? fadedStrengthDark : fadedStrength
    }

    /// The range bar's own opacity at full strength, as in the range-bar recipe, so the tick shows on it.
    static let barStrength = 0.35

    /// The opacity of the month's range bar, in light or Dark Mode.
    func barOpacity(isDark: Bool = false) -> Double {
        switch self {
        case .focused, .full: Self.barStrength
        case .faded: Self.barStrength * Self.fadedStrength(isDark: isDark)
        case .muted: Self.barStrength
        }
    }

    /// The opacity of the month's average tick, in light or Dark Mode.
    func tickOpacity(isDark: Bool = false) -> Double {
        switch self {
        case .focused, .full: 1
        case .faded: Self.fadedStrength(isDark: isDark)
        case .muted: 0.6
        }
    }

    /// Whether the marks are grey rather than blue.
    var isGrey: Bool {
        self == .muted
    }
}

/// The words this screen needs that `CafeWording` does not have, and the month formatting every text shares.
/// Not tied to the main actor: the chart descriptor calls it.
nonisolated enum OneFocusWording {
    static let lowestDay = "Lowest day"
    static let highestDay = "Highest day"
    static let averageDay = "Average day"
    static let average = "Average"

    /// A month's name in the data's UTC calendar, so the device's time zone cannot move it: "July".
    static func monthName(_ month: Date, locale: Locale) -> String {
        month.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.wide))
    }

    /// "March to August 2026", in the data's calendar. "" when there are no months.
    static func period(_ months: [MonthlySummary], locale: Locale) -> String {
        guard let first = months.first?.month, let last = months.last?.month else { return "" }
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return "\(first.formatted(style.month(.wide))) to \(last.formatted(style.month(.wide).year()))"
    }

    /// "1 bar", "6 bars": the count agrees in number.
    static func bars(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) bar](inflect: true)", locale: locale).characters)
    }

    /// A plain number in the locale: "137", "1,234".
    static func number(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    /// The average day across the months, weighted by the days in each, rounded. `nil` with no months.
    static func overallAverage(_ months: [MonthlySummary]) -> Int? {
        let weighted = months.map { month in
            let days = CafeData.calendar.range(of: .day, in: .month, for: month.month)?.count ?? 30
            return (cups: month.averageDay * days, days: days)
        }
        let days = weighted.map(\.days).reduce(0, +)
        guard days > 0 else { return nil }
        return Int((Double(weighted.map(\.cups).reduce(0, +)) / Double(days)).rounded())
    }

    /// The value axis, from zero to the highest day rounded up to the next 50 cups (at least 50).
    /// The chart and the descriptor share it.
    static func cupsAxis(_ months: [MonthlySummary]) -> ClosedRange<Double> {
        0 ... max(50, (Double(months.map(\.highestDay).max() ?? 0) / 50).rounded(.up) * 50)
    }
}

/// The state of "One focus at a time": which month leads, whether the average line is shown, and whether
/// the screen is showing the mistake of drawing every month at full strength.
@Observable
final class OneFocusViewModel {
    let months: [MonthlySummary]
    /// The month that leads while the average line is off.
    var focusedMonth: Date
    /// Whether the average line is drawn. While it is, every month is muted under it.
    var showsAverage = false
    /// The mistake: every month stays at full strength, whatever leads.
    var isShowingMistake = false

    init(months: [MonthlySummary] = CafeData.monthlySummaries, focusedMonth: Date? = nil) {
        self.months = months
        // The busiest month by its average day leads to begin with.
        self.focusedMonth = focusedMonth ?? months.max { $0.averageDay < $1.averageDay }?.month ?? CafeData.firstDay
    }

    // MARK: What is drawn

    /// Whether there is anything to draw: months with at least one cup sold.
    var hasData: Bool {
        months.contains { $0.highestDay > 0 }
    }

    /// The month that leads, or `nil` when the focused date is not one of the months.
    var focus: MonthlySummary? {
        months.first { $0.month == focusedMonth }
    }

    var overallAverage: Int? {
        OneFocusWording.overallAverage(months)
    }

    var cupsAxis: ClosedRange<Double> {
        OneFocusWording.cupsAxis(months)
    }

    /// How strongly a month is drawn in the current state.
    func emphasis(of month: MonthlySummary) -> OneFocusEmphasis {
        if isShowingMistake {
            // snippet:one-focus-at-a-time-mistake
            // The mistake: every month at full strength, so nothing leads.
            return .full
            // end
        }
        // snippet:one-focus-at-a-time-emphasis
        // One focus at a time: under the average line every month is grey;
        // without it, the chosen month stays at full strength and the rest fade.
        if showsAverage { return .muted }
        return month.month == focusedMonth ? .focused : .faded
        // end
    }

    /// Whether the month's lowest, highest and average are written on the chart. Only the focused month's
    /// are, and only while the average line is off, so the headline's figures can be found on the chart.
    func isLabelled(_ month: MonthlySummary) -> Bool {
        !showsAverage && month.month == focusedMonth
    }

    /// A new identity whenever element text or the descriptor changes, so VoiceOver and the Audio Graph
    /// do not keep the old ones.
    var chartIdentity: String {
        "\(focusedMonth.timeIntervalSinceReferenceDate)-\(showsAverage)-\(isShowingMistake)"
    }

    /// The snippets for the current setting: the mistake's code beside the chart while it is shown.
    var snippets: [SnippetReference] {
        let chart = SnippetReference(name: "one-focus-at-a-time-chart", title: "Emphasis in the chart")
        if isShowingMistake {
            return [chart, SnippetReference(name: "one-focus-at-a-time-mistake", title: "The mistake: nothing fades")]
        }
        return [chart, SnippetReference(name: "one-focus-at-a-time-emphasis", title: "Choosing each month's emphasis")]
    }

    // MARK: Words

    /// The chart's message, true of what is drawn: the focused month's labelled figures, or the labelled average.
    func headline(locale: Locale) -> String {
        guard !months.isEmpty else { return "No months to show yet." }
        guard hasData else { return "No cups sold in these months." }
        if showsAverage, let average = overallAverage {
            return "Across \(CafeWording.months(months.count, locale: locale)), the average day sold "
                + "\(CafeWording.cups(average, locale: locale))."
        }
        guard let focus else { return "Choose a month to bring into focus." }
        return monthHeadline(focus, locale: locale)
    }

    private func monthHeadline(_ month: MonthlySummary, locale: Locale) -> String {
        "\(OneFocusWording.monthName(month.month, locale: locale))'s days ran from "
            + "\(OneFocusWording.number(month.lowestDay, locale: locale)) to "
            + "\(CafeWording.cups(month.highestDay, locale: locale)), "
            + "\(OneFocusWording.number(month.averageDay, locale: locale)) on average."
    }

    /// What the screen says about the chart as it is drawn now, each sentence checkable against it.
    func explanation(locale: Locale) -> String {
        let name = focus.map { OneFocusWording.monthName($0.month, locale: locale) } ?? "The chosen month"
        switch (showsAverage, isShowingMistake) {
        case (false, false):
            return "\(name) is drawn at full strength and the other months are faded to 30% of its strength (45% in Dark "
                + "Mode, where a fainter blue sinks into the panel), so the eye "
                + "starts on \(name) and its labelled figures. Turn on the average line and every month turns grey "
                + "under it: one focus at a time."
        case (true, false):
            return "Every month is grey under the blue average line, so the line is the one thing that leads. "
                + "Turn the line off and one month comes back into focus while the rest stay faded."
        case (false, true):
            return "Every month is at full strength, so nothing leads: only the labels say which month the "
                + "headline is about. Fading the other months to 30% of the chosen month's strength lets it lead."
        case (true, true):
            return "The months keep their full blue under the blue average line, so the line competes with "
                + "\(OneFocusWording.bars(months.count, locale: locale)) of its own colour. Greying the months under it "
                + "makes the line the one focus."
        }
    }

    // MARK: What VoiceOver reads

    /// Context first: the month, and whether it is the one drawn in focus.
    func elementLabel(for month: MonthlySummary, locale: Locale) -> String {
        let name = OneFocusWording.monthName(month.month, locale: locale)
        return emphasis(of: month) == .focused ? "\(name), in focus" : name
    }

    /// The month's three values, each with its unit.
    func elementValue(for month: MonthlySummary, locale: Locale) -> String {
        "\(OneFocusWording.lowestDay) \(CafeWording.cups(month.lowestDay, locale: locale)), "
            + "\(OneFocusWording.highestDay.lowercased()) \(CafeWording.cups(month.highestDay, locale: locale)), "
            + "\(OneFocusWording.averageDay.lowercased()) \(CafeWording.cups(month.averageDay, locale: locale))"
    }

    /// The average rule's label, read as an element of its own.
    var ruleLabel: String {
        "\(OneFocusWording.average) across all months"
    }

    func ruleValue(locale: Locale) -> String {
        "\(CafeWording.cups(overallAverage ?? 0, locale: locale)) a day"
    }

    /// Said when the month in focus changes: what changed, then the headline.
    func focusAnnouncement(locale: Locale) -> String {
        let name = focus.map { OneFocusWording.monthName($0.month, locale: locale) } ?? "No month"
        return "\(name) in focus. \(headline(locale: locale))"
    }

    /// Said when the average line is switched: what changed, then the headline.
    func averageAnnouncement(locale: Locale) -> String {
        let change = showsAverage ? "Average line shown, months greyed under it." : "Average line hidden."
        return "\(change) \(headline(locale: locale))"
    }

    /// The Audio Graph's summary, in actual values, for the current state.
    func audioGraphSummary(locale: Locale) -> String {
        guard hasData else { return headline(locale: locale) }
        var parts = [CafeWording.months(months.count, locale: locale) + "."]
        if let low = months.min(by: { $0.lowestDay < $1.lowestDay }),
           let high = months.max(by: { $0.highestDay < $1.highestDay })
        {
            parts.append("Lowest day \(CafeWording.cups(low.lowestDay, locale: locale)) in "
                + "\(OneFocusWording.monthName(low.month, locale: locale)), highest day "
                + "\(CafeWording.cups(high.highestDay, locale: locale)) in "
                + "\(OneFocusWording.monthName(high.month, locale: locale)).")
        }
        if showsAverage, let average = overallAverage {
            parts.append("Average line at \(CafeWording.cups(average, locale: locale)) a day.")
        } else if let focus {
            // In the mistake nothing is drawn in focus; the month is only labelled.
            parts.append("\(isShowingMistake ? "Labelled" : "In focus"): "
                + "\(OneFocusWording.monthName(focus.month, locale: locale)), "
                + "\(elementValue(for: focus, locale: locale).lowercased()).")
        }
        return parts.joined(separator: " ")
    }
}
