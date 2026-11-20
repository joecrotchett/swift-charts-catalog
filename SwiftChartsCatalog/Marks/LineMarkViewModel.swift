import Charts
import Foundation
import Observation

/// How the line travels between its points: the choices the screen's picker offers.
enum LineInterpolation: String, CaseIterable, Identifiable {
    case straight, smooth, monotone, stepped

    // snippet:line-method-straight
    /// Straight segments between the points. This is the default, so the modifier can be left out:
    /// the data is the points, and nothing is implied between them.
    static let straightMethod: InterpolationMethod = .linear
    // end

    // snippet:line-method-smooth
    /// A smooth curve through every point. Between points it can rise above or dip below the data,
    /// so its peaks and troughs are not always values anyone recorded.
    static let smoothMethod: InterpolationMethod = .catmullRom
    // end

    // snippet:line-method-monotone
    /// A smooth curve that never overshoots: it rises only where the data rises,
    /// so its peaks and troughs are real values.
    static let monotoneMethod: InterpolationMethod = .monotone
    // end

    // snippet:line-method-stepped
    /// A staircase with each jump halfway between two points: every value stands for a period
    /// centred on its point, here a whole day. `.stepEnd` and `.stepStart` put the jump at a point.
    static let steppedMethod: InterpolationMethod = .stepCenter
    // end

    var id: String {
        rawValue
    }

    /// The name in the picker.
    var title: String {
        switch self {
        case .straight: "Straight"
        case .smooth: "Smooth"
        case .monotone: "Monotone"
        case .stepped: "Stepped"
        }
    }

    /// The framework's method for this choice.
    var method: InterpolationMethod {
        switch self {
        case .straight: Self.straightMethod
        case .smooth: Self.smoothMethod
        case .monotone: Self.monotoneMethod
        case .stepped: Self.steppedMethod
        }
    }

    /// The snippet that shows this choice's method.
    var snippet: SnippetReference {
        SnippetReference(name: "line-method-\(rawValue)", title: title)
    }

    /// One sentence on what this choice draws, for the text under the chart.
    var explanation: String {
        switch self {
        case .straight:
            "Straight segments are the default: the line turns a corner at each day and implies nothing between two days."
        case .smooth:
            "The catmullRom method curves through every day's value, and between two days it can pass above or below both of them, showing a level nobody recorded."
        case .monotone:
            "The monotone method is smooth as well, but it never overshoots: every peak and trough of the curve is a day's real value."
        case .stepped:
            "The stepCenter method holds each day's value flat around its point and jumps halfway to the next, which suits a total that stands for a whole day."
        }
    }

    /// The shape in words, for the Audio Graph's summary and the announcement when it changes.
    var spokenShape: String {
        switch self {
        case .straight: "straight segments from day to day"
        case .smooth: "a smooth curve through every day's value, which can pass above or below the values between days"
        case .monotone: "a smooth curve that never passes above or below the values of the days it joins"
        case .stepped: "steps, each day's value held level around its day"
        }
    }

    /// How the line is drawn, in a sentence, for the Audio Graph and for announcing a change.
    func drawingDescription(showsSymbols: Bool) -> String {
        "The line is drawn as \(spokenShape), "
            + (showsSymbols ? "with a circle at each day." : "with no symbol at the days.")
    }
}

/// What the week's line says in words: the headline, and the summary the Audio Graph speaks.
nonisolated struct WeekSalesSummary {
    let days: [DailySales]
    /// The locale every word and number here is written in. It has no default: the screen passes the
    /// environment's, so the headline, the chart's labels and the Audio Graph agree.
    let locale: Locale

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// A line needs two points, and a week of zeros is no data.
    var hasLine: Bool {
        Self.hasLine(days)
    }

    /// The value axis, worked out once for the chart's scale and the descriptor's range: the week's lowest to
    /// highest day rounded to the step, leaving out zero (140 to 220 for the sample week).
    static func valueDomain(for days: [DailySales]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups), includesZero: false)
    }

    /// The same question without a locale, which the answer does not depend on.
    static func hasLine(_ days: [DailySales]) -> Bool {
        days.count >= 2 && days.map(\.cups).reduce(0, +) > 0
    }

    /// Every day that sold the most, in date order. More than one when there is a tie.
    var busiestDays: [DailySales] {
        guard hasLine, let most = days.map(\.cups).max() else { return [] }
        return days.filter { $0.cups == most }
    }

    /// Every day that sold the fewest, in date order.
    var quietestDays: [DailySales] {
        guard hasLine, let fewest = days.map(\.cups).min() else { return [] }
        return days.filter { $0.cups == fewest }
    }

    /// How close to the most a day must come to share the headline, as a share of the most. Within it two days
    /// cannot be told apart on the line, so neither is called the busiest (`design.md`: a superlative within a
    /// few points of its rivals is left out).
    static let nearTieShare = 0.03

    /// Every day within `nearTieShare` of the most, in date order: the days the headline names.
    var leadingDays: [DailySales] {
        guard let most = busiestDays.first?.cups else { return [] }
        let threshold = Double(most) * (1 - Self.nearTieShare)
        return days.filter { Double($0.cups) >= threshold }
    }

    /// The chart's message in a sentence. Its figure is a day's own value, which the line passes
    /// through however it is interpolated. True on a tie and a near-tie, and when there is no line to draw.
    var headline: String {
        let leading = leadingDays
        guard let most = busiestDays.first?.cups, let fewest = leading.map(\.cups).min() else { return noLineMessage }
        let names = dayNames(leading)
        if leading.count == 1 { return "\(names) was the busiest day: \(cupsText(most))." }
        if fewest == most { return "\(names) were the busiest days: \(cupsText(most)) each." }
        return "\(names) sold the most, within a few cups of each other: "
            + "\(fewest.formatted(.number.locale(locale))) to \(cupsText(most))."
    }

    /// Why there is no line, for the headline, the placeholder and the Audio Graph alike.
    var noLineMessage: String {
        total == 0 ? "No cups sold in this period." : "One day of sales is not yet a line."
    }

    /// Actual values only, with no judgement of them, then how the line is drawn.
    func audioGraphSummary(drawnAs drawing: String) -> String {
        guard let first = days.first, let last = days.last,
              let most = busiestDays.first?.cups, let fewest = quietestDays.first?.cups
        else { return noLineMessage }
        return "\(daysText(days.count)), \(dayName(first.day)) to \(dayName(last.day)). "
            + "First day \(cupsText(first.cups)), last day \(cupsText(last.cups)). "
            + "Highest: \(dayNames(busiestDays)), \(cupsText(most)). "
            + "Lowest: \(dayNames(quietestDays)), \(cupsText(fewest)). "
            + drawing
    }

    /// A day written out in the time zone the data was recorded in: "Saturday, March 7".
    func dayName(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    private func dayNames(_ days: [DailySales]) -> String {
        days.map { dayName($0.day) }.formatted(.list(type: .and).locale(locale))
    }

    /// A count of days, agreeing in number: "1 day", "7 days".
    func daysText(_ count: Int) -> String {
        String(AttributedString(localized: "^[\(count) day](inflect: true)", locale: locale).characters)
    }

    /// A count with its unit, agreeing in number, the number written in the summary's locale: "1 cup", "210 cups".
    func cupsText(_ cups: Int) -> String {
        CafeWording.cups(cups, locale: locale)
    }
}

/// The state behind the Line screen: how the line is interpolated and whether its points carry symbols.
@Observable
final class LineMarkViewModel {
    /// The Harbour café's first week, 1 to 7 March 2026: the same days every other screen draws for that café.
    /// A busy Sunday, a quiet run, then the jump to Saturday is where a smooth curve overshoots, and seven points
    /// are few enough to see what the line does between them.
    static let sampleWeek = Array(CafeData.harbourSales.prefix(7))

    let days: [DailySales]
    var interpolation: LineInterpolation = .straight
    var showsSymbols = true

    init(days: [DailySales] = LineMarkViewModel.sampleWeek) {
        self.days = days
    }

    /// The week's words in the locale given: the screen passes its environment's.
    func summary(locale: Locale) -> WeekSalesSummary {
        WeekSalesSummary(days: days, locale: locale)
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline
    }

    /// The concept, then what the current settings draw. With no line, only the concept.
    var explanation: String {
        let concept = "LineMark joins one mark per day into a single line. interpolationMethod decides how the line travels "
            + "between its points, lineStyle sets its stroke, and symbol marks each point without adding any marks."
        guard WeekSalesSummary.hasLine(days) else { return concept }
        return "\(concept) \(interpolation.explanation)"
    }

    /// How the line is drawn now, in a sentence: both controls, so neither changes the chart silently.
    var drawingDescription: String {
        interpolation.drawingDescription(showsSymbols: showsSymbols)
    }

    /// The code for the current settings: the line, its interpolation method, and the symbols when on.
    var snippets: [SnippetReference] {
        var snippets = [Self.lineSnippet, interpolation.snippet]
        if showsSymbols {
            snippets.append(Self.symbolSnippet)
        }
        return snippets
    }

    static let lineSnippet = SnippetReference(name: "line-mark", title: "The line")
    static let symbolSnippet = SnippetReference(name: "line-symbols", title: "Symbols")
}
