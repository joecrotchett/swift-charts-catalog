import Foundation
import Observation

/// The three marks the screen draws the same days with.
nonisolated enum RealDataMark: String, CaseIterable, Identifiable {
    case points
    case line
    case bars

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .points: "Points"
        case .line: "Line"
        case .bars: "Bars"
        }
    }

    /// The snippet that draws this mark.
    var snippet: SnippetReference {
        switch self {
        case .points: SnippetReference(name: "design-with-real-data-points", title: "Each day as a point")
        case .line: SnippetReference(name: "design-with-real-data-line", title: "The days joined by a line")
        case .bars: SnippetReference(name: "design-with-real-data-bars", title: "Each day as a bar")
        }
    }

    /// What VoiceOver says when the picker switches to this mark.
    var changeSentence: String {
        switch self {
        case .points: "Now drawn as points."
        case .line: "Now drawn as a line."
        case .bars: "Now drawn as bars."
        }
    }
}

/// "Design with real data": which days are drawn, with which mark, and what that says.
@Observable
final class RealDataViewModel {
    /// Smooth invented days: every day open, a gentle rhythm.
    let inventedDays: [DailySales]
    /// The same days as really traded: closed days at zero, a day with no record, an outlier.
    let realDays: [DailySales]

    /// Draw the days as really traded instead of the invented ones.
    var isRealData = false
    /// Set every recorded day to 0 cups, keeping which days have a record.
    var isOnlyZeros = false
    var mark: RealDataMark = .line

    /// The caption: both months are the invented sample, smooth or as traded, so neither is taken for the café's
    /// recorded March (`CafeWording.inventedDaysCaption`).
    func caption(locale: Locale) -> String {
        guard isRealData else { return CafeWording.inventedDaysCaption(locale: locale) }
        let month = CafeData.firstDay.formatted(CafeWording.monthYear(locale: locale))
        return "Invented sample as traded: cups a day at the \(CafeWording.harbour) café, \(month)"
    }

    init(inventedDays: [DailySales] = CafeData.thirtyDays, realDays: [DailySales] = CafeData.thirtyDaysReal) {
        self.inventedDays = inventedDays
        self.realDays = realDays
    }

    /// The days the chart draws in the current setting.
    var days: [DailySales] {
        let base = isRealData ? realDays : inventedDays
        return isOnlyZeros ? base.map { DailySales(day: $0.day, cups: 0) } : base
    }

    func summary(locale: Locale) -> RealDataSummary {
        RealDataSummary(days: days, mark: mark, locale: locale)
    }

    /// The line on real data is the mistake the screen names: its strokes overstate the zero days and
    /// run across the day with no record.
    var isShowingMistake: Bool {
        mark == .line && isRealData && !isOnlyZeros
    }

    /// While the placeholder shows, the data toggle would change only words about a chart that is not drawn.
    /// The mark picker and the zeros toggle stay on: they are the way back to a chart.
    var isDataToggleDisabled: Bool {
        RealDataSummary.showsPlaceholder(days: days, mark: mark)
    }

    /// A new identity for the chart whenever its elements' text can change while the days' ids do not.
    var chartIdentity: String {
        "\(isRealData)-\(isOnlyZeros)-\(mark.rawValue)"
    }

    /// The snippets See Code shows: the mark in use, then the check for a chart with nothing to draw.
    var snippets: [SnippetReference] {
        [mark.snippet, Self.placeholderSnippet]
    }

    static let placeholderSnippet = SnippetReference(
        name: "design-with-real-data-placeholder", title: "Only zeros: points draw, bars need a placeholder"
    )

    /// Every snippet the screen can show, for the catalog's registration.
    static let allSnippets = RealDataMark.allCases.map(\.snippet) + [placeholderSnippet]

    /// What VoiceOver says after the data toggle changes: what changed, then the new headline.
    func dataAnnouncement(locale: Locale) -> String {
        let change = isRealData ? "Now showing the days as really traded." : "Now showing the smooth invented days."
        return "\(change) \(summary(locale: locale).headline)"
    }

    /// What VoiceOver says after the zeros toggle changes.
    func zerosAnnouncement(locale: Locale) -> String {
        let change = isOnlyZeros ? "Every recorded day set to 0 cups." : "Every day's cups restored."
        return "\(change) \(summary(locale: locale).headline)"
    }

    /// What VoiceOver says after the mark picker changes.
    func markAnnouncement(locale: Locale) -> String {
        let summary = summary(locale: locale)
        let placeholder = summary.showsPlaceholder ? " \(summary.placeholderTitle)." : ""
        return "\(mark.changeSentence)\(placeholder) \(summary.headline)"
    }
}

/// What the chart says in words for one setting: the headline, what to look for, and the Audio Graph's summary.
nonisolated struct RealDataSummary {
    let days: [DailySales]
    let mark: RealDataMark
    /// The locale every count and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The days are midnight UTC; written in the data's own time zone so the day named is the day drawn.
    var dayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
    }

    /// "Saturday, March 21".
    func dayName(_ date: Date) -> String {
        date.formatted(dayStyle)
    }

    var cupsValues: [Int] {
        days.map(\.cups)
    }

    var isAllZero: Bool {
        !days.isEmpty && cupsValues.allSatisfy { $0 == 0 }
    }

    var showsPlaceholder: Bool {
        Self.showsPlaceholder(days: days, mark: mark)
    }

    // snippet:design-with-real-data-placeholder
    /// No days at all draws nothing. Only zeros draw nothing as bars, whose marks grow from zero:
    /// the chart would be bare axes. Points and a line at zero are drawn, so they keep the chart.
    /// It needs no locale: whether the placeholder shows does not depend on how anything is written.
    static func showsPlaceholder(days: [DailySales], mark: RealDataMark) -> Bool {
        days.isEmpty || (mark == .bars && days.allSatisfy { $0.cups == 0 })
    }

    // end

    var placeholderTitle: String {
        days.isEmpty ? "No days recorded" : "No cups sold"
    }

    var placeholderDescription: String {
        days.isEmpty
            ? "Days appear here once the till records them."
            : "Every recorded day is 0 cups, and a bar of 0 has no height: the chart would be bare axes. Points or a line draw the zeros."
    }

    /// Days between the first and the last with no record, in order.
    var missingDays: [Date] {
        guard let first = days.first?.day, let last = days.last?.day else { return [] }
        let recorded = Set(days.map(\.day))
        var missing: [Date] = []
        var day = first
        while day < last {
            if !recorded.contains(day) { missing.append(day) }
            guard let next = CafeData.calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return missing
    }

    var zeroDayCount: Int {
        cupsValues.count(where: { $0 == 0 })
    }

    /// Every day with the most cups, in data order. Empty when nothing was sold.
    var busiestDays: [DailySales] {
        guard let most = cupsValues.max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// The most cups on any day that is not one of the busiest.
    var nextBusiestCups: Int? {
        let most = cupsValues.max()
        return cupsValues.filter { $0 != most }.max()
    }

    /// One busiest day at least twice the next busiest: a value far above the rest that stretches the scale.
    var outlier: DailySales? {
        guard busiestDays.count == 1, let busiest = busiestDays.first, let next = nextBusiestCups,
              busiest.cups >= 2 * next else { return nil }
        return busiest
    }

    /// The value axis, rounded up to the next 50 cups and at least 50, so zeros still have an axis.
    /// The chart's scale and the descriptor share it.
    var cupsAxis: ClosedRange<Double> {
        0 ... max(50, (Double(cupsValues.max() ?? 0) / 50).rounded(.up) * 50)
    }

    /// "29 days on record".
    var recordedDays: String {
        "\(CafeWording.days(days.count, locale: locale)) on record"
    }

    /// The chart's message: the busiest day, a figure the reader can find at the chart's peak.
    var headline: String {
        if days.isEmpty { return "No days recorded." }
        guard let cups = busiestDays.first?.cups else { return "No cups sold in the \(recordedDays)." }
        let names = CafeWording.list(busiestDays.map { dayName($0.day) })
        return "Busiest of the \(recordedDays): \(names), with \(CafeWording.cups(cups, locale: locale))."
    }

    /// What to look for in the chart as drawn, sentence by sentence, for this mark and these days.
    var lookFor: String {
        if days.isEmpty { return "There is nothing to draw, so a placeholder takes the chart's place." }
        if isAllZero { return zeroLookFor }
        var sentences: [String] = []
        let zeros = zeroDayCount
        let zeroDays = CafeWording.days(zeros, locale: locale)
        switch mark {
        case .points:
            if zeros > 0 { sentences.append("Each of the \(zeroDays) at 0 cups is a dot on the zero line.") }
            if !missingDays.isEmpty {
                sentences.append("There is no dot at all on \(missingNames), with no record: points tell a day with no record from a day of 0.")
            }
        case .line:
            if zeros > 0 {
                sentences.append("Each of the \(zeroDays) at 0 cups pulls the line down to zero and back up: two long strokes for a day with no sales.")
            }
            if !missingDays.isEmpty {
                sentences.append("Across \(missingNames), with no record, the line runs straight on as if the café had traded.")
            }
        case .bars:
            if zeros > 0 {
                sentences.append("Each of the \(zeroDays) at 0 cups is an empty slot, so the zeros sit quietly and the bar on screen matches the cups sold.")
            }
            if !missingDays.isEmpty {
                sentences.append("\(missingNames), with no record, is left empty too: bars cannot tell a day with no record from a day of 0, so the Audio Graph's summary says which days have no record.")
            }
        }
        if let outlier, let next = nextBusiestCups {
            sentences.append("\(dayName(outlier.day)) stands alone at \(CafeWording.cups(outlier.cups, locale: locale)), and every other day is \(CafeWording.cups(next, locale: locale)) or fewer, reaching only about \(Self.fractionName(Double(next) / cupsAxis.upperBound)) of the way up the plot.")
        }
        if sentences.isEmpty {
            switch mark {
            case .points: sentences.append("Each day is its own dot, and the weekly rhythm and slow rise read without a line.")
            case .line: sentences.append("Every day is a small step from the last, so the line reads as the month's trend.")
            case .bars: sentences.append("One bar per day, each its own amount: the month's slow rise shows along their tops.")
            }
        }
        return sentences.joined(separator: " ")
    }

    private var zeroLookFor: String {
        let gap = missingDays.isEmpty ? "" : " There is no dot on \(missingNames), with no record."
        switch mark {
        case .points:
            return "Every day is a dot on the zero line: a chart of zeros is still drawn.\(gap)"
        case .line:
            let across = missingDays.isEmpty ? "" : ", straight across \(missingNames), with no record"
            return "The line lies flat along zero from the first day to the last\(across): a chart of zeros is still drawn."
        case .bars:
            return "A bar of 0 has no height, so the chart would be bare axes under the headline; a placeholder says why instead."
        }
    }

    /// The plain fraction nearest to a share of the plot's height: "a third" for 230 of 650.
    /// An outlier is at least twice every other day, so the rest never reach past half.
    static func fractionName(_ share: Double) -> String {
        let fractions: [(value: Double, name: String)] = [
            (0.1, "a tenth"), (0.2, "a fifth"), (0.25, "a quarter"), (1.0 / 3, "a third"), (0.5, "half"),
        ]
        return fractions.min { abs($0.value - share) < abs($1.value - share) }?.name ?? "half"
    }

    private var missingNames: String {
        CafeWording.list(missingDays.map(dayName))
    }

    /// The Audio Graph's summary: actual values, no judgement of them.
    var audioGraphSummary: String {
        if days.isEmpty { return "No days recorded." }
        var parts = ["\(recordedDays.prefix(1).uppercased())\(recordedDays.dropFirst())."]
        if let cups = busiestDays.first?.cups {
            parts.append("Busiest \(CafeWording.list(busiestDays.map { dayName($0.day) })), \(CafeWording.cups(cups, locale: locale)).")
        }
        if isAllZero {
            parts.append("Every day 0 cups.")
        } else if zeroDayCount > 0 {
            parts.append("\(CafeWording.days(zeroDayCount, locale: locale)) at 0 cups.")
        }
        if !missingDays.isEmpty {
            parts.append("No record for \(missingNames).")
        }
        return parts.joined(separator: " ")
    }
}
