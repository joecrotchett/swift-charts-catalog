import Foundation
import Observation

// MARK: The insights

/// The three distances to look at data from (`design.md`, *Whether to use a chart*): the whole, a subset,
/// and single values. The screen chooses at most one insight at each distance.
nonisolated enum StartFromTheGoalDistance: CaseIterable, Hashable {
    case whole
    case subset
    case single

    var title: String {
        switch self {
        case .whole: "The whole"
        case .subset: "A subset"
        case .single: "A single value"
        }
    }
}

/// What the whole of the thirty days could say.
nonisolated enum StartFromTheGoalWhole: CaseIterable, Hashable {
    case average
    case range

    var title: String {
        switch self {
        case .average: "Average"
        case .range: "Range"
        }
    }
}

/// A part of the thirty days worth singling out.
nonisolated enum StartFromTheGoalSubset: CaseIterable, Hashable {
    case weekends
    case lastWeek

    var title: String {
        switch self {
        case .weekends: "Weekends"
        case .lastWeek: "Last 7 days"
        }
    }
}

/// One day worth pointing at.
nonisolated enum StartFromTheGoalSingle: CaseIterable, Hashable {
    case bestDay
    case quietestDay

    var title: String {
        switch self {
        case .bestDay: "Best day"
        case .quietestDay: "Quietest day"
        }
    }
}

// MARK: Choice and configuration

/// What the chart draws, as plain values: which rules or bands cross it, which days are at full strength,
/// and which days carry a marker. The bars of the thirty days are always drawn; this is everything on top.
nonisolated struct StartFromTheGoalConfiguration: Hashable {
    var whole: Set<StartFromTheGoalWhole>
    var subsets: Set<StartFromTheGoalSubset>
    var singles: Set<StartFromTheGoalSingle>

    /// The mistake: every insight the data could show, all in one chart.
    static let everything = StartFromTheGoalConfiguration(
        whole: Set(StartFromTheGoalWhole.allCases),
        subsets: Set(StartFromTheGoalSubset.allCases),
        singles: Set(StartFromTheGoalSingle.allCases)
    )

    /// How many insights are drawn.
    var insightCount: Int {
        whole.count + subsets.count + singles.count
    }
}

/// The reader's choice: at most one insight at each distance.
nonisolated struct StartFromTheGoalChoice: Hashable {
    var whole: StartFromTheGoalWhole?
    var subset: StartFromTheGoalSubset?
    var single: StartFromTheGoalSingle?

    /// Every choice there is: none or one of each distance's insights, 3 × 3 × 3.
    static let all: [StartFromTheGoalChoice] = {
        let wholes: [StartFromTheGoalWhole?] = [nil] + StartFromTheGoalWhole.allCases
        let subsets: [StartFromTheGoalSubset?] = [nil] + StartFromTheGoalSubset.allCases
        let singles: [StartFromTheGoalSingle?] = [nil] + StartFromTheGoalSingle.allCases
        return wholes.flatMap { whole in
            subsets.flatMap { subset in
                singles.map { single in StartFromTheGoalChoice(whole: whole, subset: subset, single: single) }
            }
        }
    }()

    // snippet:start-from-the-goal-insights
    /// The chart follows from the chosen insights: each one adds exactly one thing to the same bars.
    /// The whole becomes a labelled rule or band, a subset the days drawn at full strength,
    /// a single value a marked day. Nothing chosen at a distance adds nothing.
    var configuration: StartFromTheGoalConfiguration {
        StartFromTheGoalConfiguration(
            whole: Set([whole].compactMap(\.self)),
            subsets: Set([subset].compactMap(\.self)),
            singles: Set([single].compactMap(\.self))
        )
    }
    // end
}

/// A day the chart marks, and the insight that marks it.
nonisolated struct StartFromTheGoalMarkedDay: Identifiable, Hashable {
    let insight: StartFromTheGoalSingle
    let day: DailySales

    var id: String {
        "\(insight)-\(day.day.timeIntervalSinceReferenceDate)"
    }
}

/// Which control changed, for the announcement that follows it.
nonisolated enum StartFromTheGoalChange: Hashable {
    case distance(StartFromTheGoalDistance)
    case mistake
}

// MARK: Words and figures

/// Everything the screen works out from the days: the figures, and every sentence written or spoken
/// about them. One table, so the words can be checked and replaced in one place.
nonisolated struct StartFromTheGoalSummary {
    let days: [DailySales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// How much room the value axis leaves above the highest bar, for the marker's label.
    static let axisHeadroom = 1.2
    /// The value axis is rounded up to a multiple of this.
    static let axisStep = 50.0

    init(days: [DailySales], locale: Locale) {
        self.days = days.sorted { $0.day < $1.day }
        self.locale = locale
    }

    // MARK: Figures

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// False with no days, and with days of only zeros: then there are no bars to draw.
    var hasSales: Bool {
        total > 0
    }

    var average: Double? {
        days.isEmpty ? nil : Double(total) / Double(days.count)
    }

    /// The average as written: a whole number of cups.
    var roundedAverage: Int {
        Int((average ?? 0).rounded())
    }

    var range: ClosedRange<Int>? {
        guard let lowest = days.map(\.cups).min(), let highest = days.map(\.cups).max() else { return nil }
        return lowest ... highest
    }

    /// The value axis, from zero, set on the chart and given to the chart descriptor alike.
    var cupsAxis: ClosedRange<Double> {
        let highest = Double(range?.upperBound ?? 0)
        let top = (highest * Self.axisHeadroom / Self.axisStep).rounded(.up) * Self.axisStep
        return 0 ... max(Self.axisStep, top)
    }

    func isWeekend(_ day: DailySales) -> Bool {
        CafeData.calendar.isDateInWeekend(day.day)
    }

    /// The last seven days in the data, or all of them when there are fewer.
    var lastWeek: [DailySales] {
        Array(days.suffix(7))
    }

    func isIn(_ subset: StartFromTheGoalSubset, _ day: DailySales) -> Bool {
        switch subset {
        case .weekends: isWeekend(day)
        case .lastWeek: lastWeek.contains(day)
        }
    }

    /// Every day that sold the most, or the fewest. More than one on a tie; none when nothing sold.
    func days(for single: StartFromTheGoalSingle) -> [DailySales] {
        guard hasSales, let range else { return [] }
        let cups = single == .bestDay ? range.upperBound : range.lowerBound
        return days.filter { $0.cups == cups }
    }

    func markedDays(_ configuration: StartFromTheGoalConfiguration) -> [StartFromTheGoalMarkedDay] {
        StartFromTheGoalSingle.allCases.filter(configuration.singles.contains).flatMap { single in
            days(for: single).map { StartFromTheGoalMarkedDay(insight: single, day: $0) }
        }
    }

    /// A day at full strength: every day when no subset is chosen, otherwise only the days in a chosen one.
    func isEmphasised(_ day: DailySales, in configuration: StartFromTheGoalConfiguration) -> Bool {
        configuration.subsets.isEmpty || configuration.subsets.contains { isIn($0, day) }
    }

    private func mean(_ days: [DailySales]) -> Double? {
        days.isEmpty ? nil : Double(days.map(\.cups).reduce(0, +)) / Double(days.count)
    }

    // MARK: Dates and numbers

    /// The dates were made in UTC: written in UTC, so the day named is the day drawn.
    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
    }

    /// "Sunday, March 29".
    func dayName(_ date: Date) -> String {
        date.formatted(dateStyle.weekday(.wide).month(.wide).day())
    }

    /// "March 29", for the spans of the Audio Graph's summary and its categories.
    func shortDayName(_ date: Date) -> String {
        date.formatted(dateStyle.month(.wide).day())
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private func names(_ days: [DailySales]) -> String {
        CafeWording.list(days.map { dayName($0.day) })
    }

    // MARK: The headline

    /// The headline: one sentence for each chosen insight, the whole first, then the subset, then single
    /// values. Each figure in it is written on the chart, beside the rule, band or marker it belongs to.
    func headline(_ configuration: StartFromTheGoalConfiguration) -> String {
        guard hasSales else { return "No cups sold in these days." }
        let sentences = wholeSentences(configuration) + subsetSentences(configuration) + singleSentences(configuration)
        guard !sentences.isEmpty else {
            return "\(CafeWording.days(days.count, locale: locale)) of sales, with nothing singled out."
        }
        return sentences.joined(separator: " ")
    }

    private func wholeSentences(_ configuration: StartFromTheGoalConfiguration) -> [String] {
        StartFromTheGoalWhole.allCases.filter(configuration.whole.contains).compactMap { whole in
            switch whole {
            case .average:
                return "Averaged \(CafeWording.cups(roundedAverage, locale: locale)) a day."
            case .range:
                guard let range else { return nil }
                return "Between \(number(range.lowerBound)) and \(CafeWording.cups(range.upperBound, locale: locale)) a day."
            }
        }
    }

    private func subsetSentences(_ configuration: StartFromTheGoalConfiguration) -> [String] {
        StartFromTheGoalSubset.allCases.filter(configuration.subsets.contains).map { subset in
            let inside = days.filter { isIn(subset, $0) }
            let outside = days.filter { !isIn(subset, $0) }
            switch subset {
            case .weekends:
                guard let weekendMean = mean(inside) else { return "No weekend days are in these days." }
                guard let weekdayMean = mean(outside) else { return "Every one of these days is a weekend day." }
                return "Weekends sold \(comparison(weekendMean, weekdayMean)) weekdays."
            case .lastWeek:
                let last = CafeWording.days(inside.count, locale: locale)
                guard let lastMean = mean(inside), let earlierMean = mean(outside) else {
                    return "Every one of these days is in the last \(last)."
                }
                let earlier = CafeWording.days(outside.count, locale: locale)
                return "The last \(last) sold \(comparison(lastMean, earlierMean)) the \(earlier) before."
            }
        }
    }

    /// "more a day than", "fewer a day than", "as many a day as": a comparison of two averages, no judgement.
    private func comparison(_ first: Double, _ second: Double) -> String {
        if first > second { return "more a day than" }
        if first < second { return "fewer a day than" }
        return "as many a day as"
    }

    private func singleSentences(_ configuration: StartFromTheGoalConfiguration) -> [String] {
        StartFromTheGoalSingle.allCases.filter(configuration.singles.contains).compactMap { single in
            let marked = days(for: single)
            guard let cups = marked.first?.cups else { return nil }
            switch single {
            case .bestDay: return "Most cups in a day: \(number(cups)), on \(names(marked))."
            case .quietestDay: return "Fewest cups in a day: \(number(cups)), on \(names(marked))."
            }
        }
    }

    // MARK: Text drawn on the chart

    /// The label beside the average rule: "Average 187".
    var averageAnnotation: String {
        "Average \(number(roundedAverage))"
    }

    /// The label under the range band: "150 to 230".
    var rangeAnnotation: String {
        guard let range else { return "" }
        return "\(number(range.lowerBound)) to \(number(range.upperBound))"
    }

    /// The first line of a marked day's label, its date as the axis writes it: "Mar 29".
    func markerDate(_ marked: StartFromTheGoalMarkedDay) -> String {
        marked.day.day.formatted(dateStyle.month(.abbreviated).day())
    }

    /// The label above a marked day: "Most: 230".
    func markerAnnotation(_ marked: StartFromTheGoalMarkedDay) -> String {
        switch marked.insight {
        case .bestDay: "Most: \(number(marked.day.cups))"
        case .quietestDay: "Fewest: \(number(marked.day.cups))"
        }
    }

    /// The chart's labels as lines of a key, for the accessibility sizes, in the order the layers are drawn:
    /// "Band: 150 to 230", "Line: Average 187", "Dot: Most: 230, Mar 29".
    func keyEntries(_ configuration: StartFromTheGoalConfiguration) -> [String] {
        var entries: [String] = []
        if configuration.whole.contains(.range), range != nil { entries.append("Band: \(rangeAnnotation)") }
        if configuration.whole.contains(.average), average != nil { entries.append("Line: \(averageAnnotation)") }
        entries += markedDays(configuration).map { "Dot: \(markerAnnotation($0)), \(markerDate($0))" }
        return entries
    }

    // MARK: Accessibility elements

    /// A bar's label: its day, written out.
    func elementLabel(_ day: DailySales) -> String {
        dayName(day.day)
    }

    /// A bar's value: its cups, then what the chosen insights say about that day, in actual words.
    func elementValue(_ day: DailySales, _ configuration: StartFromTheGoalConfiguration) -> String {
        var parts = [CafeWording.cups(day.cups, locale: locale)]
        if configuration.subsets.contains(.weekends), isWeekend(day) { parts.append("weekend") }
        if configuration.subsets.contains(.lastWeek), lastWeek.contains(day) {
            parts.append("in the last \(CafeWording.days(lastWeek.count, locale: locale))")
        }
        for single in StartFromTheGoalSingle.allCases where configuration.singles.contains(single) {
            if days(for: single).contains(day) {
                parts.append(single == .bestDay ? "most cups in a day" : "fewest cups in a day")
            }
        }
        return parts.joined(separator: ", ")
    }

    static let averageLabel = "Average"
    var averageValue: String {
        "\(CafeWording.cups(roundedAverage, locale: locale)) a day"
    }

    static let rangeLabel = "Range"
    var rangeValue: String {
        guard let range else { return "" }
        return "\(number(range.lowerBound)) to \(CafeWording.cups(range.upperBound, locale: locale)) a day"
    }

    // MARK: The Audio Graph

    static let audioGraphTitle = "Cups sold each day at the Harbour café"

    /// The days as written on the descriptor's category axis, in order.
    var categories: [String] {
        days.map { shortDayName($0.day) }
    }

    /// Actual values only: the span, the figures, and what is drawn on top of the bars.
    func audioGraphSummary(_ configuration: StartFromTheGoalConfiguration) -> String {
        guard hasSales, let first = days.first, let last = days.last, let range else {
            return "No cups sold in these days."
        }
        var sentences = [
            "\(CafeWording.days(days.count, locale: locale)), \(shortDayName(first.day)) to \(shortDayName(last.day)).",
        ]
        if configuration.whole.contains(.average) {
            sentences.append("A line marks the average, \(averageValue).")
        }
        if configuration.whole.contains(.range) {
            sentences.append("A band marks the range, \(number(range.lowerBound)) to \(CafeWording.cups(range.upperBound, locale: locale)).")
        }
        for subset in StartFromTheGoalSubset.allCases where configuration.subsets.contains(subset) {
            let inside = days.filter { isIn(subset, $0) }
            let outside = days.filter { !isIn(subset, $0) }
            let insideMean = Int((mean(inside) ?? 0).rounded())
            let outsideMean = Int((mean(outside) ?? 0).rounded())
            switch subset {
            case .weekends:
                sentences.append("Weekend days average \(CafeWording.cups(insideMean, locale: locale)), "
                    + "other days \(CafeWording.cups(outsideMean, locale: locale)).")
            case .lastWeek:
                sentences.append("The last \(CafeWording.days(inside.count, locale: locale)) average "
                    + "\(CafeWording.cups(insideMean, locale: locale)), the days before "
                    + "\(CafeWording.cups(outsideMean, locale: locale)).")
            }
        }
        if !configuration.subsets.isEmpty {
            sentences.append("Those days are drawn at full strength, the rest faded.")
        }
        sentences += singleSentences(configuration)
        return sentences.joined(separator: " ")
    }
}

// MARK: The view model

/// The screen's state: the insight chosen at each distance and the mistake switch, and everything derived
/// from them. The words come from `StartFromTheGoalSummary`, given the locale the view reads.
@Observable
final class StartFromTheGoalViewModel {
    let days: [DailySales]
    /// Three insights chosen to start with, one at each distance.
    var whole: StartFromTheGoalWhole? = .average
    var subset: StartFromTheGoalSubset? = .weekends
    var single: StartFromTheGoalSingle? = .bestDay
    var isShowingMistake = false

    init(days: [DailySales] = CafeData.thirtyDays) {
        self.days = days
    }

    var choice: StartFromTheGoalChoice {
        StartFromTheGoalChoice(whole: whole, subset: subset, single: single)
    }

    /// What is drawn: the chosen insights, or with the mistake on, every insight at once.
    var configuration: StartFromTheGoalConfiguration {
        isShowingMistake ? .everything : choice.configuration
    }

    func summary(locale: Locale) -> StartFromTheGoalSummary {
        StartFromTheGoalSummary(days: days, locale: locale)
    }

    var hasSales: Bool {
        days.map(\.cups).reduce(0, +) > 0
    }

    /// The pickers do nothing while the mistake shows every insight, or while there is nothing to draw.
    var arePickersEnabled: Bool {
        hasSales && !isShowingMistake
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline(configuration)
    }

    /// What changed, then the headline: posted after a control changes what the chart draws.
    func announcement(after change: StartFromTheGoalChange, locale: Locale) -> String {
        let what = switch change {
        case .distance(.whole): "\(StartFromTheGoalDistance.whole.title): \(whole?.title ?? "none")."
        case .distance(.subset): "\(StartFromTheGoalDistance.subset.title): \(subset?.title ?? "none")."
        case .distance(.single): "\(StartFromTheGoalDistance.single.title): \(single?.title ?? "none")."
        case .mistake: isShowingMistake ? "Every insight at once." : "Only the chosen insights."
        }
        return "\(what) \(headline(locale: locale))"
    }

    // MARK: Snippets

    static let insightsSnippet = SnippetReference(name: "start-from-the-goal-insights", title: "The insights decide the chart")
    static let rangeSnippet = SnippetReference(name: "start-from-the-goal-range", title: "The whole: a range band")
    static let subsetSnippet = SnippetReference(name: "start-from-the-goal-subset", title: "The bars, a chosen subset at full strength")
    static let averageSnippet = SnippetReference(name: "start-from-the-goal-average", title: "The whole: an average rule")
    static let singleSnippet = SnippetReference(name: "start-from-the-goal-single", title: "A single value: a marked day")

    /// Every snippet: the chart's layers in the order its code has them, then the mapping from the insights.
    /// The screen's registration.
    static let allSnippets = [subsetSnippet, rangeSnippet, averageSnippet, singleSnippet, insightsSnippet]

    /// The code for what is drawn now: the chart's layers first (the bars always, then each chosen insight's
    /// layer), so See Code opens on the chart, and the mapping from the insights last.
    var snippets: [SnippetReference] {
        let configuration = configuration
        var references = [Self.subsetSnippet]
        if configuration.whole.contains(.range) { references.append(Self.rangeSnippet) }
        if configuration.whole.contains(.average) { references.append(Self.averageSnippet) }
        if !configuration.singles.isEmpty { references.append(Self.singleSnippet) }
        return references + [Self.insightsSnippet]
    }
}
