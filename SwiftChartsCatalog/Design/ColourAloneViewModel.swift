import Foundation
import Observation

/// The two forms the screen draws: points, where the second cue is a symbol shape, and stacked bars,
/// which have no symbol, so the second cue is a direct label.
nonisolated enum ColourAloneForm: String, CaseIterable, Identifiable {
    case points
    case stackedBars

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .points: "Points"
        case .stackedBars: "Stacked bars"
        }
    }
}

/// One café's cups in one week, a segment of a stacked bar.
nonisolated struct ColourAloneWeek: Identifiable, Hashable {
    /// "Week 1" to "Week 4": the bar's category.
    let week: String
    let store: String
    let cups: Int
    let firstDay: Date
    let lastDay: Date

    var id: String {
        "\(week)-\(store)"
    }
}

/// One café's days in one week of the scatter.
nonisolated struct ColourAlonePortion: Identifiable, Hashable {
    let store: String
    let days: [DailySales]

    var id: String {
        store
    }
}

/// One week of the scatter, both cafés in it: one accessibility element, read in café order.
nonisolated struct ColourAlonePointWeek: Identifiable, Hashable {
    let firstDay: Date
    let lastDay: Date
    /// Each café's days in the week, in the cafés' data order.
    let portions: [ColourAlonePortion]

    var id: Date {
        firstDay
    }
}

/// What changed, for the announcement.
nonisolated enum ColourAloneChange {
    case form
    case secondCue
}

/// The state and words of "Colour: never colour alone".
@Observable
final class ColourAloneViewModel {
    var form: ColourAloneForm = .points
    /// The second cue: a symbol shape on the points, a café name on each bar segment. Off is the mistake.
    var showsSecondCue = false
    /// Draws the chart in greys, so what colour alone carries can be seen to be lost.
    var showsGreyscale = false

    /// Two cafés' daily cups. Exactly the two the colour scale names.
    let stores: [StoreSales]

    init(stores: [StoreSales] = CafeData.storeSales) {
        self.stores = stores
    }

    /// The café names, in data order: the order of the legend, the stack, and the colour scale.
    var storeNames: [String] {
        stores.map(\.store)
    }

    // MARK: Points

    /// Whether the scatter has anything to draw. Points at zero are drawn, so only no days is empty.
    var drawsPoints: Bool {
        stores.contains { !$0.days.isEmpty }
    }

    /// The days split into weeks of seven, each holding both cafés' days: one accessibility element per week,
    /// so the two cafés of a week are always read in the same order.
    var pointWeeks: [ColourAlonePointWeek] {
        let dates = Set(stores.flatMap { $0.days.map(\.day) }).sorted()
        return stride(from: 0, to: dates.count, by: 7).compactMap { start in
            let week = Array(dates[start ..< min(start + 7, dates.count)])
            guard let first = week.first, let last = week.last else { return nil }
            let inWeek = Set(week)
            return ColourAlonePointWeek(firstDay: first, lastDay: last, portions: stores.map { store in
                ColourAlonePortion(store: store.store, days: store.days.filter { inWeek.contains($0.day) })
            })
        }
    }

    /// The value axis of the points, far from zero: the lowest and highest cups rounded out to 50, so the
    /// drawn axis and the descriptor share one range.
    var pointAxis: ClosedRange<Double> {
        let cups = stores.flatMap(\.days).map { Double($0.cups) }
        guard let lowest = cups.min(), let highest = cups.max() else { return 0 ... 50 }
        let bottom = (lowest / 50).rounded(.down) * 50
        let top = max(bottom + 50, (highest / 50).rounded(.up) * 50)
        return bottom ... top
    }

    /// Who sold more each day both cafés traded: the leading café's name, or `nil` on a tie.
    private var dailyLeaders: [(day: Date, leader: String?)] {
        guard stores.count == 2 else { return [] }
        let first = stores[0]
        let second = stores[1]
        let secondByDay = Dictionary(second.days.map { ($0.day, $0.cups) }, uniquingKeysWith: { lhs, _ in lhs })
        return first.days.compactMap { day in
            guard let other = secondByDay[day.day] else { return nil }
            if day.cups == other { return (day.day, nil) }
            return (day.day, day.cups > other ? first.store : second.store)
        }
    }

    /// The days each café sold more, in data order of the cafés.
    func daysLed(by store: String) -> Int {
        dailyLeaders.count { $0.leader == store }
    }

    func pointHeadline(locale: Locale) -> String {
        guard stores.count == 2, drawsPoints else { return "No sales to compare." }
        let leaders = dailyLeaders
        guard !leaders.isEmpty else { return "The two cafés have no day in common to compare." }
        let first = storeNames[0]
        let second = storeNames[1]
        let firstLed = daysLed(by: first)
        let secondLed = daysLed(by: second)
        if firstLed == 0, secondLed == 0 {
            return "\(first) and \(second) sold the same on all \(CafeWording.days(leaders.count, locale: locale))."
        }
        // The café that led more often is named first.
        let (more, moreCount, fewer, fewerCount) = firstLed >= secondLed
            ? (first, firstLed, second, secondLed) : (second, secondLed, first, firstLed)
        var sentence = "\(more) sold more on \(CafeWording.days(moreCount, locale: locale))"
        sentence += fewerCount == 0 ? ", \(fewer) on none" : " and \(fewer) on \(CafeWording.days(fewerCount, locale: locale))"
        return sentence + "."
    }

    // MARK: Stacked bars

    /// Each café's weekly totals, Harbour's segment first in every week so it is at the bottom of each stack.
    var weeks: [ColourAloneWeek] {
        let weekCount = ((stores.map(\.days.count).max() ?? 0) + 6) / 7
        let rows: [[ColourAloneWeek]] = (0 ..< weekCount).map { index in
            stores.compactMap { store in
                let start = index * 7
                guard start < store.days.count else { return nil }
                let days = store.days[start ..< min(start + 7, store.days.count)]
                guard let firstDay = days.first?.day, let lastDay = days.last?.day else { return nil }
                return ColourAloneWeek(
                    week: Self.weekName(index), store: store.store,
                    cups: days.map(\.cups).reduce(0, +), firstDay: firstDay, lastDay: lastDay
                )
            }
        }
        return rows.flatMap(\.self)
    }

    /// "Week 1" for the first week.
    static func weekName(_ index: Int) -> String {
        "\(CafeWording.week) \(index + 1)"
    }

    /// "H" for "Harbour": a café's name on a bar at the accessibility sizes.
    static func initial(of store: String) -> String {
        String(store.prefix(1))
    }

    /// "1" for "Week 1": the week's number alone, for the axis at the accessibility sizes.
    static func weekNumber(_ week: String) -> String {
        week.split(separator: " ").last.map(String.init) ?? week
    }

    /// The week names in order: the bars' categories.
    var weekNames: [String] {
        var names: [String] = []
        for week in weeks where !names.contains(week.week) {
            names.append(week.week)
        }
        return names
    }

    /// Bars grow from zero, so with no cups at all there is nothing to draw.
    var drawsBars: Bool {
        weeks.contains { $0.cups > 0 }
    }

    /// The value axis of the bars, from zero to the tallest stack rounded up to 500.
    var barAxis: ClosedRange<Double> {
        let tallest = weekNames.map { name in weeks.filter { $0.week == name }.map(\.cups).reduce(0, +) }.max() ?? 0
        return 0 ... max(500, (Double(tallest) / 500).rounded(.up) * 500)
    }

    func barHeadline(locale _: Locale) -> String {
        guard stores.count == 2, drawsBars else { return "No cups sold to compare." }
        let first = storeNames[0]
        let second = storeNames[1]
        var firstWeeks: [String] = []
        var secondWeeks: [String] = []
        var tiedWeeks: [String] = []
        for name in weekNames {
            let rows = weeks.filter { $0.week == name }
            let firstCups = rows.first { $0.store == first }?.cups ?? 0
            let secondCups = rows.first { $0.store == second }?.cups ?? 0
            if firstCups > secondCups {
                firstWeeks.append(name)
            } else if secondCups > firstCups {
                secondWeeks.append(name)
            } else {
                tiedWeeks.append(name)
            }
        }
        // The café that led the first week is named first, so the sentence follows the bars in order.
        let parts = [(first, firstWeeks), (second, secondWeeks)]
            .filter { !$0.1.isEmpty }
            .sorted { (weekNames.firstIndex(of: $0.1[0]) ?? 0) < (weekNames.firstIndex(of: $1.1[0]) ?? 0) }
        var clauses = parts.enumerated().map { index, part in
            index == 0
                ? "\(part.0) sold more in \(CafeWording.list(part.1))"
                : "\(part.0) in \(CafeWording.list(part.1))"
        }
        if !tiedWeeks.isEmpty {
            clauses.append(clauses.isEmpty
                ? "\(first) and \(second) sold the same in \(CafeWording.list(tiedWeeks))"
                : "the same in \(CafeWording.list(tiedWeeks))")
        }
        return clauses.joined(separator: "; ") + "."
    }

    // MARK: State-dependent text

    func headline(locale: Locale) -> String {
        switch form {
        case .points: pointHeadline(locale: locale)
        case .stackedBars: barHeadline(locale: locale)
        }
    }

    func caption(locale: Locale) -> String {
        let period = period(locale: locale).map { ", \($0)" } ?? ""
        return switch form {
        case .points: "Cups a day at two cafés\(period)"
        case .stackedBars: "Cups a week at two cafés\(period)"
        }
    }

    /// The days the data covers, in the locale and the data's calendar: "March 1 – 28". `nil` with no days.
    func period(locale: Locale) -> String? {
        let dates = stores.flatMap { $0.days.map(\.day) }
        guard let first = dates.min(), let last = dates.max() else { return nil }
        let calendar = CafeData.calendar
        return (first ..< last).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day()
        )
    }

    /// What the toggle adds on this form.
    var secondCueTitle: String {
        switch form {
        case .points: "Add shape as a second cue"
        case .stackedBars: "Add labels as a second cue"
        }
    }

    /// Whether the chart says which café is which with anything but colour.
    var isShowingMistake: Bool {
        !showsSecondCue
    }

    /// The screen's explanation, true of the chart as it is now drawn, at the text size it is drawn in.
    func explanation(isAccessibilitySize: Bool) -> String {
        let rule = "Never let colour alone tell series apart: put it on top of a second difference. "
            + "Harbour is purple and Station red, two colours of the same weight: they differ in hue but hardly in lightness."
        let check = switch (form, showsSecondCue, showsGreyscale) {
        case (.points, false, false):
            " Every point is a circle, so only colour says which café it is. Turn on greyscale to see what that leaves."
        case (.points, false, true):
            " In greyscale both cafés are circles of the same grey: nothing on the chart says which point is which, so the headline cannot be checked."
        case (.points, true, false):
            " Harbour's points are now circles and Station's crosses, and the legend shows each shape beside its colour."
        case (.points, true, true):
            " In greyscale the colours are gone but the shapes remain: Harbour's circles and Station's crosses can still be followed day by day."
        case (.stackedBars, false, false):
            " A bar has no symbol to change, and every segment is the same rectangle: only colour, and a stack order nothing explains, say which café is which."
        case (.stackedBars, false, true):
            " In greyscale the two segments of each bar are the same grey: the legend cannot say which is Harbour."
        case (.stackedBars, true, false):
            " A bar has no symbol shape, so the second cue is a direct label: each segment names its café, and the legend it makes redundant is hidden."
        case (.stackedBars, true, true):
            " In greyscale each segment still names its café, so every week can be read without colour."
        }
        let size = switch (form, isAccessibilitySize) {
        case (_, false): ""
        case (.points, true): " At this text size the dates under the chart are days of March, every two weeks."
        case (.stackedBars, true): " At this text size the weeks are numbered 1 to 4 under the bars"
            + (showsSecondCue ? ", and the labels on the bars stop growing at a standard size and shorten each café to its initial, "
                + "\(storeNames.map { "\(Self.initial(of: $0)) for \($0)" }.joined(separator: " and ")), so they still fit." : ".")
        }
        return rule + check + size
    }

    /// Said after a control redraws the chart: what changed, then the headline. Greyscale only restyles,
    /// and its switch speaks its own value, so it is not announced.
    func announcement(after change: ColourAloneChange, locale: Locale) -> String {
        let what = switch (change, form, showsSecondCue) {
        case (.form, .points, _):
            "Showing points, one per café per day."
        case (.form, .stackedBars, _):
            "Showing stacked bars, one segment per café per week."
        case (.secondCue, .points, true):
            "Shapes added: Harbour as circles, Station as crosses."
        case (.secondCue, .points, false):
            "Shapes removed: both cafés as circles, told apart by colour alone."
        case (.secondCue, .stackedBars, true):
            "Labels added: each segment names its café."
        case (.secondCue, .stackedBars, false):
            "Labels removed: the segments are told apart by colour alone."
        }
        return "\(what) \(headline(locale: locale))"
    }

    // MARK: Snippets

    static let snippetColourOnly = "colour-never-colour-alone-points-colour-only"
    static let snippetColourAndShape = "colour-never-colour-alone-points-colour-and-shape"
    static let snippetBarsColourOnly = "colour-never-colour-alone-bars-colour-only"
    static let snippetBarsLabelled = "colour-never-colour-alone-bars-labelled"
    static let snippetEqualWeight = "colour-never-colour-alone-equal-weight"
    static let snippetGreyscale = "colour-never-colour-alone-greyscale"

    var snippets: [SnippetReference] {
        var references: [SnippetReference] = switch (form, showsSecondCue) {
        case (.points, false): [SnippetReference(name: Self.snippetColourOnly, title: "Colour alone (the mistake)")]
        case (.points, true): [SnippetReference(name: Self.snippetColourAndShape, title: "Colour and shape")]
        case (.stackedBars, false): [SnippetReference(name: Self.snippetBarsColourOnly, title: "Colour alone (the mistake)")]
        case (.stackedBars, true): [SnippetReference(name: Self.snippetBarsLabelled, title: "Colour and a direct label")]
        }
        references.append(SnippetReference(name: Self.snippetEqualWeight, title: "Two colours of equal weight"))
        if showsGreyscale {
            references.append(SnippetReference(name: Self.snippetGreyscale, title: "The greyscale check"))
        }
        return references
    }

    // MARK: Audio Graph

    /// The scatter's descriptor: one series per café over the written-out days, on the drawn value axis.
    func pointDescriptor(locale: Locale) -> ColourAloneDescriptor {
        let days = stores.first?.days.map { dayName($0.day, locale: locale) } ?? []
        let lows = stores.map { store -> String in
            let cups = store.days.map(\.cups)
            guard let lowest = cups.min(), let highest = cups.max() else { return "\(store.store) has no days" }
            return "\(store.store) from \(CafeWording.cups(lowest, locale: locale)) to \(CafeWording.cups(highest, locale: locale))"
        }
        return ColourAloneDescriptor(
            title: "Cups a day at the \(CafeWording.list(storeNames)) cafés" + (period(locale: locale).map { ", \($0)" } ?? ""),
            summary: "\(CafeWording.days(days.count, locale: locale)). \(pointHeadline(locale: locale)) "
                + (lows.isEmpty ? "" : "\(lows.joined(separator: "; "))."),
            xTitle: CafeWording.day,
            categories: days,
            series: stores.map { store in
                ColourAloneDescriptor.Series(
                    name: store.store,
                    points: store.days.map { (dayName($0.day, locale: locale), Double($0.cups)) }
                )
            },
            range: pointAxis,
            locale: locale
        )
    }

    /// The stacked bars' descriptor: one series per café, each point its segment's own cups.
    func barDescriptor(locale: Locale) -> ColourAloneDescriptor {
        let perWeek = weekNames.map { name in
            let parts = weeks.filter { $0.week == name }.map { "\($0.store) \(CafeWording.cups($0.cups, locale: locale))" }
            return "\(name): \(CafeWording.list(parts))"
        }
        return ColourAloneDescriptor(
            title: "Cups a week at the \(CafeWording.list(storeNames)) cafés, stacked",
            summary: "\(CafeWording.weeks(weekNames.count, locale: locale)). \(barHeadline(locale: locale)) "
                + perWeek.joined(separator: ". ") + (perWeek.isEmpty ? "" : "."),
            xTitle: CafeWording.week,
            categories: weekNames,
            series: storeNames.map { store in
                ColourAloneDescriptor.Series(
                    name: store,
                    points: weeks.filter { $0.store == store }.map { ($0.week, Double($0.cups)) }
                )
            },
            range: barAxis,
            locale: locale
        )
    }

    // MARK: Spoken text

    /// "March 21" (en_US), in the data's time zone and the view's locale.
    func dayName(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone).day().month(.wide))
    }

    /// One week of the points: "March 1 to March 7".
    func weekLabel(_ week: ColourAlonePointWeek, locale: Locale) -> String {
        Self.spokenRange(from: week.firstDay, to: week.lastDay, locale: locale)
    }

    /// Both cafés in the week, in café order: "Harbour lowest 152 cups, highest 219 cups; Station lowest …".
    func weekValue(_ week: ColourAlonePointWeek, locale: Locale) -> String {
        week.portions.compactMap { portion -> String? in
            let cups = portion.days.map(\.cups)
            guard let lowest = cups.min(), let highest = cups.max() else { return nil }
            return "\(portion.store) lowest \(CafeWording.cups(lowest, locale: locale)), "
                + "highest \(CafeWording.cups(highest, locale: locale))"
        }
        .joined(separator: "; ")
    }

    /// One segment of a stacked bar: "Week 1, Harbour".
    func segmentLabel(_ week: ColourAloneWeek) -> String {
        "\(week.week), \(week.store)"
    }

    func segmentValue(_ week: ColourAloneWeek, locale: Locale) -> String {
        CafeWording.cups(week.cups, locale: locale)
    }

    /// "March 1 to March 7", each day written out in full in the locale's order, in the data's time zone.
    nonisolated static func spokenRange(from first: Date, to last: Date, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .day().month(.wide)
        return "\(first.formatted(style)) to \(last.formatted(style))"
    }
}
