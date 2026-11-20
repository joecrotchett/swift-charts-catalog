import Foundation
import Observation

/// The state and logic behind "Small multiples": three drinks over twelve months, one small chart each,
/// on one shared scale or (the mistake) each on its own.
@Observable
final class SmallMultiplesViewModel {
    let trends: [MonthlyDrinkCups]
    let drinks: [String]
    /// The mistake: each chart scales to its own data, so equal heights mean different values.
    var usesIndependentScales = false

    init(trends: [MonthlyDrinkCups] = CafeData.monthlyDrinkTrends, drinks: [String] = CafeData.trendDrinks) {
        self.trends = trends
        self.drinks = drinks
    }

    var summary: SmallMultiplesSummary {
        SmallMultiplesSummary(trends: trends, drinks: drinks)
    }

    /// No data, or only zeros: bars of zero draw nothing, so the screen shows a placeholder instead.
    var hasNothingToDraw: Bool {
        summary.hasNothingToDraw
    }

    /// The y domain of one drink's chart in the current setting.
    func domain(for drink: String) -> ClosedRange<Double> {
        usesIndependentScales ? summary.independentDomain(for: drink) : summary.sharedDomain
    }

    func headline(locale: Locale) -> String {
        summary.headline(usesIndependentScales: usesIndependentScales, locale: locale)
    }

    /// The line under the mistake toggle: read the top labels, then the bars that have swapped places.
    func mistakeNote(locale: Locale) -> String {
        let read = "Read the top label of each chart: each now ends at its own number, so equal heights no longer mean equal cups."
        guard let inversion = summary.inversion(locale: locale) else { return read }
        return "\(read) \(inversion)"
    }

    /// What VoiceOver says when the toggle redraws the charts: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = usesIndependentScales
            ? "Each chart now has its own scale."
            : "All three charts now share one scale."
        return "\(change) \(headline(locale: locale))"
    }

    /// The snippets See Code shows for the current setting.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "small-multiples-stack", title: "One chart per drink, stacked"),
            SnippetReference(name: "small-multiples-chart", title: "Each chart: one plot height, one time axis"),
            usesIndependentScales
                ? SnippetReference(name: "small-multiples-independent-domain", title: "The mistake: a scale per chart")
                : SnippetReference(name: "small-multiples-shared-domain", title: "One scale for every chart"),
            SnippetReference(name: "small-multiples-crowded", title: "The crowded chart, for comparison"),
        ]
    }
}

/// What the charts say in words, worked out from the data alone so the descriptors can use it from any thread.
nonisolated struct SmallMultiplesSummary {
    let trends: [MonthlyDrinkCups]
    let drinks: [String]

    /// The step each independent scale's top is rounded up to, in the mistake. The shared scale is the app's one
    /// scale for the drink trends, `CafeDrinkStyle.trendCupsDomain`.
    static let scaleStep = 100.0

    var hasNothingToDraw: Bool {
        trends.allSatisfy { $0.cups == 0 }
    }

    func rows(for drink: String) -> [MonthlyDrinkCups] {
        trends.filter { $0.drink == drink }
    }

    /// The months in data order, once each.
    var months: [Date] {
        var seen: [Date] = []
        for trend in trends where !seen.contains(trend.month) {
            seen.append(trend.month)
        }
        return seen
    }

    /// The largest value rounded up to the next step, at least one step, so an empty chart still has an axis.
    static func roundedTop(_ largest: Int) -> Double {
        max(scaleStep, (Double(largest) / scaleStep).rounded(.up) * scaleStep)
    }

    // snippet:small-multiples-shared-domain
    /// One domain for every chart, from the largest value in any of them: heights compare across charts. It is the
    /// app's one scale for these cups, so A chart design system draws the same cups at the same height too.
    var sharedDomain: ClosedRange<Double> {
        CafeDrinkStyle.trendCupsDomain(for: trends)
    }

    // end

    // snippet:small-multiples-independent-domain
    /// The mistake: each chart's domain from its own data, so equal heights mean different values.
    func independentDomain(for drink: String) -> ClosedRange<Double> {
        0 ... Self.roundedTop(rows(for: drink).map(\.cups).max() ?? 0)
    }

    // end

    func domain(for drink: String, usesIndependentScales: Bool) -> ClosedRange<Double> {
        usesIndependentScales ? independentDomain(for: drink) : sharedDomain
    }

    /// The tallest bars on the shared scale, in data order: more than one on a tie, none when all are zero.
    var tallestBars: [MonthlyDrinkCups] {
        guard let most = trends.map(\.cups).max(), most > 0 else { return [] }
        return trends.filter { $0.cups == most }
    }

    /// How many months a "busiest stretch" spans: a season.
    static let stretchLength = 3
    /// A drink whose highest and lowest months differ by less than this share of the shared scale is drawn
    /// as bars of nearly one height: the eye sees it change little, not a busiest stretch.
    static let levelShare = 0.2

    /// What one drink's chart shows at a glance on the shared scale: a season the eye can see, not a month
    /// that stands a point or two above its neighbours.
    enum Shape: Equatable {
        case none
        case level
        /// The busiest run of `stretchLength` months, first and last.
        case busiest(first: Date, last: Date)
    }

    func shape(of drink: String) -> Shape {
        let rows = rows(for: drink)
        guard let highest = rows.map(\.cups).max(), let lowest = rows.map(\.cups).min(), highest > 0 else { return .none }
        if rows.count > 1, Double(highest - lowest) < Self.levelShare * sharedDomain.upperBound { return .level }
        let length = min(Self.stretchLength, rows.count)
        var best = 0
        var bestTotal = Int.min
        for start in 0 ... rows.count - length {
            let total = rows[start ..< start + length].map(\.cups).reduce(0, +)
            if total > bestTotal {
                best = start
                bestTotal = total
            }
        }
        return .busiest(first: rows[best].month, last: rows[best + length - 1].month)
    }

    /// "Latte changes little all year", "Tea is busiest from June to August".
    func shapePhrase(of drink: String, locale: Locale) -> String {
        switch shape(of: drink) {
        case .none:
            "\(drink) sold none"
        case .level:
            "\(drink) changes little all year"
        case let .busiest(first, last) where first == last:
            "\(drink) is busiest in \(SmallMultiplesWording.monthName(first, locale: locale))"
        case let .busiest(first, last):
            "\(drink) is busiest from \(SmallMultiplesWording.monthName(first, locale: locale)) "
                + "to \(SmallMultiplesWording.monthName(last, locale: locale))"
        }
    }

    /// The chart's message for the current setting: the scale's top, an axis label, and what each chart's
    /// bars show at a glance. No figure in it needs reading a bar's height to the cup.
    func headline(usesIndependentScales: Bool, locale: Locale) -> String {
        guard !hasNothingToDraw else { return "No cups sold in these months." }
        if usesIndependentScales {
            let tops = drinks.map { independentDomain(for: $0).upperBound }
            if Set(tops).count == 1, let top = tops.first {
                return "Each chart has its own scale, but all reach \(SmallMultiplesWording.cups(top, locale: locale)), "
                    + "so here the heights still compare."
            }
            let each = CafeWording.list(drinks.map { drink in
                "\(drink) to \(Int(independentDomain(for: drink).upperBound).formatted(.number.locale(locale)))"
            })
            return "Each chart has its own scale, \(each) cups: equal heights no longer mean equal sales."
        }
        let shapes = CafeWording.list(drinks.map { shapePhrase(of: $0, locale: locale) })
        return "On one scale of 0 to \(SmallMultiplesWording.cups(sharedDomain.upperBound, locale: locale)), "
            + "heights compare across drinks: \(shapes)."
    }

    /// On independent scales, the bar drawn tallest against the bar that sold most, when they are different
    /// drinks and the taller-looking one sold less: "Tea's July (588 of 600) now stands taller than
    /// Latte's December (611 of 700), though Latte sold more." Nil when the scales tell no such lie.
    func inversion(locale: Locale) -> String? {
        let drawnHeight: (MonthlyDrinkCups) -> Double = { row in
            Double(row.cups) / independentDomain(for: row.drink).upperBound
        }
        guard let mostSold = trends.max(by: { $0.cups < $1.cups }),
              let drawnTallest = trends.max(by: { drawnHeight($0) < drawnHeight($1) }),
              drawnTallest.drink != mostSold.drink, drawnTallest.cups < mostSold.cups,
              drawnHeight(drawnTallest) > drawnHeight(mostSold)
        else { return nil }
        let describe: (MonthlyDrinkCups) -> String = { row in
            let top = Int(independentDomain(for: row.drink).upperBound)
            return "\(row.drink)'s \(SmallMultiplesWording.monthName(row.month, locale: locale)) "
                + "(\(row.cups.formatted(.number.locale(locale))) of \(top.formatted(.number.locale(locale))))"
        }
        return "\(describe(drawnTallest)) now stands taller than \(describe(mostSold)), though \(mostSold.drink) sold more."
    }

    /// The Audio Graph's summary for one drink's chart, in actual values.
    func audioGraphSummary(for drink: String, usesIndependentScales: Bool, locale: Locale) -> String {
        let rows = rows(for: drink)
        guard let highest = rows.max(by: { $0.cups < $1.cups }), let lowest = rows.min(by: { $0.cups < $1.cups }),
              highest.cups > 0
        else { return "No \(drink) sold in these months." }
        let top = domain(for: drink, usesIndependentScales: usesIndependentScales).upperBound
        let scale = usesIndependentScales
            ? "Its own scale, 0 to \(SmallMultiplesWording.cups(top, locale: locale)); the other charts' scales differ."
            : "One scale for all three charts, 0 to \(SmallMultiplesWording.cups(top, locale: locale))."
        return "\(CafeWording.months(rows.count, locale: locale)). "
            + "Highest \(CafeWording.cups(highest.cups, locale: locale)) in \(SmallMultiplesWording.monthAndYear(highest.month, locale: locale)), "
            + "lowest \(CafeWording.cups(lowest.cups, locale: locale)) in \(SmallMultiplesWording.monthAndYear(lowest.month, locale: locale)). "
            + scale
    }

    /// The crowded chart's value for one month: every drink's cups, in chart order.
    func crowdedValue(for month: Date, locale: Locale) -> String {
        CafeWording.list(drinks.compactMap { drink in
            trends.first { $0.drink == drink && $0.month == month }.map {
                "\(drink) \(CafeWording.cups($0.cups, locale: locale))"
            }
        })
    }
}

/// Words this screen needs that `CafeWording` does not have: month names written in the data's time zone.
nonisolated enum SmallMultiplesWording {
    /// "December", written in the calendar the months were made in, whatever the device's time zone.
    static func monthName(_ month: Date, locale: Locale) -> String {
        month.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide))
    }

    /// "December 2026", for what is spoken: the twelve months cross a new year.
    static func monthAndYear(_ month: Date, locale: Locale) -> String {
        month.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).year())
    }

    /// A scale's top as a count of cups: "700 cups".
    static func cups(_ value: Double, locale: Locale) -> String {
        CafeWording.count(value, locale: locale)
    }
}
