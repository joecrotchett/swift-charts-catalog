import Accessibility
import Foundation
import Observation
import SwiftUI

/// The state of "Axes: the lower bound": whether zero is left off both value axes, and everything
/// that follows from it: the two domains, the headline, the announcement and the snippets.
@Observable
final class LowerBoundViewModel {
    /// Off: both value axes start at zero. On: both start near their data, right for the line and,
    /// on the bars, the mistake.
    var leavesOutZero = false

    let prices: [WeeklyPrice]
    let sales: [DrinkSales]

    init(prices: [WeeklyPrice] = CafeData.weeklyPrices, sales: [DrinkSales] = CafeData.drinkSales) {
        self.prices = prices
        self.sales = sales
    }

    // MARK: What is drawn

    /// The weekly closing prices the line draws.
    var closes: [Double] {
        prices.map(\.close)
    }

    /// Whether the line chart is drawn: there is at least one price.
    var drawsLine: Bool {
        !prices.isEmpty
    }

    /// Whether the bar chart is drawn: some drink sold a cup. Bars of zero draw nothing.
    var drawsBars: Bool {
        sales.contains { $0.cups > 0 }
    }

    /// The bars are drawn wrong only when there are bars and zero is left off their axis.
    var isShowingMistake: Bool {
        leavesOutZero && drawsBars
    }

    /// The toggle changes nothing while both charts are placeholders.
    var isToggleEnabled: Bool {
        drawsLine || drawsBars
    }

    /// The line's value axis as drawn, set on the chart and given to its descriptor.
    var lineDomain: ClosedRange<Double> {
        leavesOutZero ? LowerBoundDomains.fittedLine(closes) : LowerBoundDomains.zeroLine(closes)
    }

    /// The bars' value axis as drawn, set on the chart and given to its descriptor.
    var barDomain: ClosedRange<Double> {
        let cups = sales.map { Double($0.cups) }
        return leavesOutZero ? LowerBoundDomains.fittedBars(cups) : LowerBoundDomains.zeroBars(cups)
    }

    /// The week with the lowest close, the first if several share it.
    var lowestWeek: WeeklyPrice? {
        prices.min { $0.close < $1.close }
    }

    /// The week with the highest close, the first if several share it.
    var highestWeek: WeeklyPrice? {
        prices.max { $0.close < $1.close }
    }

    /// The share of the line plot's height the prices span, from 0 to 1.
    var lineFill: Double {
        guard let low = lowestWeek?.close, let high = highestWeek?.close else { return 0 }
        let span = lineDomain.upperBound - lineDomain.lowerBound
        return span > 0 ? (high - low) / span : 0
    }

    /// The drink with the most cups, the first if several share it.
    var tallestBar: DrinkSales? {
        sales.filter { $0.cups > 0 }.max { $0.cups < $1.cups }
    }

    /// The drink with the fewest cups among the bars that are drawn: a bar of zero has no top.
    var shortestBar: DrinkSales? {
        sales.filter { $0.cups > 0 }.min { $0.cups < $1.cups }
    }

    /// How many times as many cups the tallest bar's drink sold as the shortest's.
    var cupsRatio: Double? {
        guard let tallest = tallestBar, let shortest = shortestBar, shortest.cups > 0 else { return nil }
        return Double(tallest.cups) / Double(shortest.cups)
    }

    /// How many times as tall the tallest bar is drawn as the shortest, measured from the bottom of the plot.
    /// The same as `cupsRatio` from zero; far larger when the axis starts above zero.
    var heightRatio: Double? {
        guard let tallest = tallestBar, let shortest = shortestBar else { return nil }
        let base = barDomain.lowerBound
        let shortHeight = Double(shortest.cups) - base
        guard shortHeight > 0 else { return nil }
        return (Double(tallest.cups) - base) / shortHeight
    }

    // MARK: Words

    /// The chart's message: what the lower bound does to the line, and to the bars. True for every
    /// setting, and for no prices or no cups. Every figure is written on the charts.
    func headline(locale: Locale) -> String {
        "\(lineClause(locale: locale)) \(barClause(locale: locale))"
    }

    /// What changed, then the headline: spoken when the toggle redraws both charts.
    func announcement(locale: Locale) -> String {
        let change = leavesOutZero ? LowerBoundWords.zeroLeftOut : LowerBoundWords.zeroRestored
        return "\(change) \(headline(locale: locale))"
    }

    private func lineClause(locale: Locale) -> String {
        guard let low = lowestWeek?.close, let high = highestWeek?.close else {
            return "No bean prices recorded."
        }
        let opening = leavesOutZero ? "Without zero," : "From zero,"
        if low == high {
            return "\(opening) the bean price holds at \(LowerBoundWords.price(low, locale: locale)) every week."
        }
        return "\(opening) the bean price's range, \(LowerBoundWords.price(low, locale: locale)) to "
            + "\(LowerBoundWords.price(high, locale: locale)), \(lineFillWords)."
    }

    /// How much of the line's plot the prices span, in words a reader can check against the chart:
    /// "is a thin band at the top of its plot", "fills most of its plot".
    var lineFillWords: String {
        if lineFill >= 0.5 { return "fills most of its plot" }
        guard lineFill < 0.25 else { return "fills less than half of its plot" }
        let span = lineDomain.upperBound - lineDomain.lowerBound
        let middle = ((lowestWeek?.close ?? 0) + (highestWeek?.close ?? 0)) / 2
        let isHigh = span > 0 && (middle - lineDomain.lowerBound) / span > 0.5
        return isHigh ? "is a thin band at the top of its plot" : "is a thin band in its plot"
    }

    private func barClause(locale: Locale) -> String {
        guard let tallest = tallestBar, let shortest = shortestBar else { return "No cups sold yet." }
        if tallest.cups == shortest.cups {
            return "Every bar stands at \(CafeWording.cups(tallest.cups, locale: locale))."
        }
        let tall = "\(tallest.drink)'s bar (\(CafeWording.cups(tallest.cups, locale: locale)))"
        let short = "\(shortest.drink.lowercased())'s (\(shortest.cups.formatted(.number.locale(locale))))"
        guard let heights = heightRatio, let cups = cupsRatio else {
            return "\(tall) is drawn; \(short) is cut off below the axis."
        }
        let times = LowerBoundWords.times(heights, locale: locale)
        if isShowingMistake {
            return "But \(LowerBoundWords.lowercasedFirst(tall)) stands \(times) as tall as \(short), "
                + "for \(LowerBoundWords.times(cups, locale: locale)) the cups."
        }
        return "\(tall) stands \(times) as tall as \(short), in proportion to the cups."
    }

    // MARK: See Code

    /// The code for the chart as drawn: the two charts, then the domains in effect.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "axes-the-lower-bound-line", title: "The line"),
            SnippetReference(name: "axes-the-lower-bound-bars", title: "The bars"),
            leavesOutZero
                ? SnippetReference(name: "axes-the-lower-bound-fitted-domains", title: "Zero left out (wrong for bars)")
                : SnippetReference(name: "axes-the-lower-bound-zero-domains", title: "Both axes from zero"),
        ]
    }
}

/// The words the screen speaks about the toggle.
nonisolated enum LowerBoundWords {
    static let zeroLeftOut = "Zero left off both value axes."
    static let zeroRestored = "Both value axes start at zero."
    static let toggleTitle = "Leave zero off both value axes"
    static let mistakeNote = "On the bars this is the mistake, shown on purpose."
    static let lineTitle = "Bean \(CafeWording.priceAxisTitle.lowercased()), each week"
    static let barsTitle = "\(CafeWording.cupsAxisTitle) sold today, by \(CafeWording.drink.lowercased())"
    static let mistakeBadge = "Mistake: bars cut short"
    static let mistakeBadgeShort = "Mistake"
    static let priceSeries = "Bean price"

    /// "$11.00", in the view's locale.
    static func price(_ value: Double, locale: Locale) -> String {
        value.formatted(.currency(code: "USD").locale(locale))
    }

    /// "2.9 times", "16.3 times".
    static func times(_ ratio: Double, locale: Locale) -> String {
        "\(ratio.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))) times"
    }

    /// "Week of March 15", written in the time zone the dates were made in.
    static func weekName(_ week: Date, locale: Locale) -> String {
        "Week of \(week.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).day()))"
    }

    /// The text with its first character lowercased: "week of March 15" from "Week of March 15".
    static func lowercasedFirst(_ text: String) -> String {
        text.prefix(1).lowercased() + text.dropFirst()
    }
}

/// The value axis of each chart, from zero or fitted to the data. The top stays where it is either way,
/// so the toggle moves only the lower bound.
nonisolated enum LowerBoundDomains {
    // snippet:axes-the-lower-bound-zero-domains
    /// From zero to half a dollar above the highest price.
    static func zeroLine(_ closes: [Double]) -> ClosedRange<Double> {
        0 ... lineTop(closes)
    }

    /// From zero to the next ten cups above the most sold.
    static func zeroBars(_ cups: [Double]) -> ClosedRange<Double> {
        0 ... barTop(cups)
    }

    // end

    // snippet:axes-the-lower-bound-fitted-domains
    /// Right for a line far from zero: from half a dollar below the lowest price.
    /// `.automatic(includesZero: false)` fits it too, but rounds its ends where the descriptor cannot read them.
    static func fittedLine(_ closes: [Double]) -> ClosedRange<Double> {
        guard let lowest = closes.min() else { return zeroLine(closes) }
        let bottom = max(0, (lowest * 2).rounded(.down) / 2 - 0.5)
        return bottom ... lineTop(closes)
    }

    /// The mistake: bars measured from just below the fewest cups. A bar's length is its value, so cutting
    /// the bottom off misstates every bar. `.automatic(includesZero: false)` cannot do this to bars; only an
    /// exact domain that leaves zero out can.
    static func fittedBars(_ cups: [Double]) -> ClosedRange<Double> {
        guard let fewest = cups.filter({ $0 > 0 }).min() else { return zeroBars(cups) }
        let bottom = max(0, ((fewest - 1) / 10).rounded(.down) * 10)
        return bottom ... barTop(cups)
    }

    // end

    static func lineTop(_ closes: [Double]) -> Double {
        ((closes.max() ?? 0) * 2).rounded(.up) / 2 + 0.5
    }

    static func barTop(_ cups: [Double]) -> Double {
        max(10, ((cups.max() ?? 0) / 10).rounded(.up) * 10)
    }
}

/// The line's Audio Graph: the weekly closes over written-out weeks, on the axis as drawn.
nonisolated struct LowerBoundLineDescriptor: AXChartDescriptorRepresentable {
    let prices: [WeeklyPrice]
    let domain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let weeks = prices.map { LowerBoundWords.weekName($0.week, locale: locale) }
        let lowest = prices.min { $0.close < $1.close }
        let highest = prices.max { $0.close < $1.close }
        var summary = "\(CafeWording.weeks(prices.count, locale: locale))."
        if let lowest, let highest {
            summary += " Lowest \(spoken(lowest.close)), \(LowerBoundWords.lowercasedFirst(LowerBoundWords.weekName(lowest.week, locale: locale)))."
                + " Highest \(spoken(highest.close)), \(LowerBoundWords.lowercasedFirst(LowerBoundWords.weekName(highest.week, locale: locale)))."
        }
        summary += " The value axis runs from \(spoken(domain.lowerBound)) to \(spoken(domain.upperBound))."
        return AXChartDescriptor(
            title: "Bean price, \(CafeWording.perKilogram), each week",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.week, categoryOrder: weeks),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.priceAxisTitle, range: domain, gridlinePositions: []) { value in
                value.isFinite ? "\(LowerBoundWords.price(value, locale: locale)) \(CafeWording.perKilogram)" : ""
            },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: LowerBoundWords.priceSeries,
                isContinuous: true,
                dataPoints: zip(weeks, prices).map { AXDataPoint(x: $0, y: $1.close) }
            )]
        )
    }

    private func spoken(_ value: Double) -> String {
        "\(LowerBoundWords.price(value, locale: locale)) \(CafeWording.perKilogram)"
    }
}

/// The bars' Audio Graph: cups by drink, on the axis as drawn, saying so when it does not start at zero.
nonisolated struct LowerBoundBarsDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    let domain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let drawn = sales.filter { $0.cups > 0 }
        var summary = "\(CafeWording.drinks(sales.count, locale: locale))."
        if let most = drawn.max(by: { $0.cups < $1.cups }), let fewest = drawn.min(by: { $0.cups < $1.cups }) {
            summary += " Most: \(most.drink), \(CafeWording.cups(most.cups, locale: locale))."
                + " Fewest: \(fewest.drink), \(CafeWording.cups(fewest.cups, locale: locale))."
        }
        let bottom = CafeWording.count(domain.lowerBound, locale: locale)
        let top = CafeWording.count(domain.upperBound, locale: locale)
        summary += domain.lowerBound > 0
            ? " The value axis starts at \(bottom), not zero, so the bars' heights are not in proportion to the cups. It runs to \(top)."
            : " The value axis runs from zero to \(top)."
        return AXChartDescriptor(
            title: "Cups sold today at the Harbour café, by drink",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink)),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: domain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: locale)
            },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )]
        )
    }
}
