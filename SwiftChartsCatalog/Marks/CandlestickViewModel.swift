import Charts
import Foundation
import Observation

/// Which way a week's price went between its open and its close. The raw values are the words the
/// legend shows; `CafeWording` has none for this, so they live here.
nonisolated enum CandlestickDirection: String, Plottable, CaseIterable {
    case rose = "Closed higher"
    case fell = "Closed lower"
    case unchanged = "Closed level"

    init(_ price: WeeklyPrice) {
        if price.close > price.open {
            self = .rose
        } else if price.close < price.open {
            self = .fell
        } else {
            self = .unchanged
        }
    }

    /// A symbol that says the same as the colour, for the mark's annotation.
    var symbolName: String {
        switch self {
        case .rose: "arrowtriangle.up.fill"
        case .fell: "arrowtriangle.down.fill"
        case .unchanged: "minus"
        }
    }
}

/// What the candlestick chart says in words: its headline, each candle's label and value, and the
/// summary the Audio Graph speaks. Numbers and dates are written in the locale it is given, and
/// dates in the calendar the weeks were made in.
nonisolated struct CandlestickSummary {
    /// The label of the colour encoding. `CafeWording` has no word for it.
    static let directionLabel = "Direction"
    static let openLabel = "Open"
    static let closeLabel = "Close"
    static let lowLabel = "Low"
    static let highLabel = "High"
    static let noPrices = "No bean prices recorded yet."
    static let currencyCode = "USD"
    /// The caption and the Audio Graph title: one string, so the two cannot drift apart.
    static let chartTitle = "Wholesale bean price by week"
    /// Said once before a run of prices, so each price need not repeat the unit.
    static let pricesPerKilogram = "Prices \(CafeWording.perKilogram)"

    let prices: [WeeklyPrice]
    let locale: Locale
    var calendar = CafeData.calendar

    /// No weeks, or weeks with no price in them: a candle from zero to zero draws nothing.
    var isEmpty: Bool {
        prices.allSatisfy { $0.open == 0 && $0.high == 0 && $0.low == 0 && $0.close == 0 }
    }

    func count(of direction: CandlestickDirection) -> Int {
        prices.count { CandlestickDirection($0) == direction }
    }

    /// The lowest low and the highest high: the range the price axis is drawn over.
    var priceRange: ClosedRange<Double>? {
        guard let lowest = prices.map(\.low).min(), let highest = prices.map(\.high).max(), lowest <= highest else {
            return nil
        }
        return lowest ... highest
    }

    /// The price axis as drawn, off zero: the lowest low and highest high rounded out to the axis step ($10.80 to
    /// $13.20 → $10 to $14). The chart's scale and the descriptor's range.
    var priceDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: prices.flatMap { [$0.low, $0.high] }, includesZero: false)
    }

    /// True whatever colours the candles are drawn in: the symbol above each candle says which way it went.
    var headline: String {
        guard !isEmpty else { return Self.noPrices }
        let risen = count(of: .rose).formatted(.number.locale(locale))
        return "The bean price closed higher in \(risen) of \(CafeWording.weeks(prices.count, locale: locale))."
    }

    func priceText(_ price: Double) -> String {
        price.formatted(.currency(code: Self.currencyCode).locale(locale))
    }

    /// "March 1", in the time zone the weeks were made in, so it names the day that is drawn.
    func dayText(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// Context first: which week the candle is.
    func label(for price: WeeklyPrice) -> String {
        "Week of \(dayText(price.week))"
    }

    /// A price with its unit, for the descriptor's value description: "$11.20 per kilogram".
    func spokenPriceText(_ price: Double) -> String {
        "\(priceText(price)) \(CafeWording.perKilogram)"
    }

    /// The four prices, in the order the app always gives them, after which way the week went.
    /// The unit is said once, before the prices it applies to.
    func value(for price: WeeklyPrice) -> String {
        "\(CandlestickDirection(price).rawValue). \(Self.pricesPerKilogram): "
            + "\(Self.openLabel.lowercased()) \(priceText(price.open)), \(Self.closeLabel.lowercased()) \(priceText(price.close)), "
            + "\(Self.lowLabel.lowercased()) \(priceText(price.low)), \(Self.highLabel.lowercased()) \(priceText(price.high))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard !isEmpty, let range = priceRange, let first = prices.first, let last = prices.last else {
            return Self.noPrices
        }
        func weeks(_ direction: CandlestickDirection) -> String {
            count(of: direction).formatted(.number.locale(locale))
        }
        return "\(CafeWording.weeks(prices.count, locale: locale)). "
            + "Closed higher in \(weeks(.rose)), lower in \(weeks(.fell)), level in \(weeks(.unchanged)). "
            + "\(Self.pricesPerKilogram): first open \(priceText(first.open)), last close \(priceText(last.close)), "
            + "lowest \(priceText(range.lowerBound)), highest \(priceText(range.upperBound))."
    }
}

/// The state behind the Candlestick screen: the prices, and whether the custom mark is making the
/// mistake of setting its own colour.
@Observable
final class CandlestickViewModel {
    static let markSnippet = SnippetReference(name: "candlestick-mark", title: "The custom mark")
    static let mistakeMarkSnippet = SnippetReference(
        name: "candlestick-mark-mistake", title: "The mistake: a colour set inside the mark"
    )
    static let callSnippet = SnippetReference(name: "candlestick-call", title: "Called like a built-in mark")
    static let mistakeCallSnippet = SnippetReference(name: "candlestick-call-mistake", title: "The same call")
    static let chartSnippet = SnippetReference(name: "candlestick-chart", title: "Coloured by the caller")

    let prices: [WeeklyPrice]
    /// The mistake: the mark type sets its own colour, so the caller's colour never arrives.
    var setsColourInside = false

    init(prices: [WeeklyPrice] = CafeData.weeklyPrices) {
        self.prices = prices
    }

    func summary(locale: Locale) -> CandlestickSummary {
        CandlestickSummary(prices: prices, locale: locale)
    }

    /// The mark type that is drawing the candles, how it is called, then the chart that colours it.
    var snippets: [SnippetReference] {
        setsColourInside
            ? [Self.mistakeMarkSnippet, Self.mistakeCallSnippet, Self.chartSnippet]
            : [Self.markSnippet, Self.callSnippet, Self.chartSnippet]
    }

    var explanation: String {
        let form = """
        Swift Charts has no candlestick mark, so this one is a ChartContent type: a RuleMark from low to high \
        for the wick and a RectangleMark from open to close for the body, in one Plot.
        """
        if setsColourInside {
            return form + """
             Here the type sets a grey of its own, and a style set inside a custom mark wins over the one \
            applied to it from outside: the chart still asks for a colour by direction, but every candle is \
            grey. The legend either disappears or stays to name colours no candle has, depending on the \
            system. Only the arrows still say which way each week went.
            """
        }
        return form + """
         The type sets no colour, so the chart colours it from outside like a built-in mark: \
        by whether the week closed higher or lower.
        """
    }

    /// What changed, then the headline, for people who cannot see the candles change colour.
    func announcement(locale: Locale) -> String {
        let change = setsColourInside
            ? "Every candle is now drawn in one grey, set inside the mark."
            : "Each candle is now coloured by whether the week closed higher or lower."
        return "\(change) \(summary(locale: locale).headline)"
    }
}
