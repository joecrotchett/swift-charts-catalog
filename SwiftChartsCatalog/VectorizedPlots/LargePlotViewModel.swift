import Foundation
import Observation

/// The three pieces of advice for a large plot the screen turns on and off. Apple gives them as ways to keep
/// a plot fast; in a single render on the simulator none of them made a measurable difference.
nonisolated enum LargePlotAdvice: CaseIterable, Hashable {
    case storedProperties
    case sortedByStyle
    case explicitDomains

    /// The toggle's title, which is also how the advice is named in announcements and timings.
    var title: String {
        switch self {
        case .storedProperties: "Read stored properties"
        case .sortedByStyle: "Sort the orders by drink"
        case .explicitDomains: "State the wait and drink domains"
        }
    }

    /// What the chart does with the advice turned off, for the timings' rows.
    var offDescription: String {
        switch self {
        case .storedProperties: "A computed property"
        case .sortedByStyle: "Orders unsorted"
        case .explicitDomains: "Automatic domains"
        }
    }
}

/// The words this screen adds to `CafeWording` and `TimeOfDayWording`: it plots the wait for each cup,
/// which no other screen's wording names.
nonisolated enum LargePlotWording {
    /// The `.value` label for the y value, so the spoken axis name is the one drawn.
    static let waitPerCup = "Wait per cup"
    /// The y axis's visible title, also the descriptor's y axis title.
    static let waitPerCupAxisTitle = "Wait per cup (minutes)"
    /// The y axis's title at the accessibility text sizes from `.accessibility4`, where the long one meets the labels.
    static let shortWaitPerCupAxisTitle = "Per cup (min)"
    /// The descriptor's one series: the median of each hour's orders.
    static let medianSeries = "Median wait per cup"
}

/// The known bounds of the chart. Stated, they fix the picture: the wait axis ends at 10 and each drink keeps
/// its colour whatever order the data comes in.
nonisolated enum LargePlotScales {
    /// Every order's wait per cup lies inside this range (the tests check all 20,000).
    static let waitPerCupDomain: ClosedRange<Double> = 0 ... 10
    /// The drinks, in the order the legend lists them and the sorted orders come in.
    static let drinks = CafeData.manyOrderDrinks

    /// Where the automatic wait axis ends, so the Audio Graph's range matches the drawn one: the longest wait
    /// rounded up to a step of 1, 2 or 5 times a power of ten, the smallest that needs at most four steps.
    /// Not a documented rule: it matched where the framework ended the axis on the simulator for every count
    /// the slider allows (8) and for ten other longest waits from 0.9 to 47.
    static func automaticWaitTop(longest: Double) -> Double {
        guard longest > 0, longest.isFinite else { return 0 }
        let rough = longest / 4
        let power = pow(10, log10(rough).rounded(.down))
        let step = [1.0, 2, 5, 10].map { $0 * power }.first { $0 >= rough } ?? 10 * power
        return (longest / step).rounded(.up) * step
    }
}

extension CafeOrder {
    // snippet:keeping-a-large-plot-fast-computed
    /// The same number as the stored `minutesPerCup`, worked out by a getter every time it is read: once
    /// for every point, on every render. At 20,000 points that made no measurable difference to one render.
    var largePlotComputedMinutesPerCup: Double {
        waitMinutes / Double(max(cups, 1))
    }
    // end
}

/// The state and words of "Keeping a large plot fast": how many orders, which advice is followed, and the
/// headline, announcements and spoken stretches that follow from them.
@Observable
final class LargePlotViewModel {
    static let smallestCount = 1000
    static let countStep = 1000
    static let defaultCount = 5000

    /// How many orders are drawn. A `Double` for the slider.
    var orderCount = Double(LargePlotViewModel.defaultCount) {
        didSet { if orderCount != oldValue { regenerate() } }
    }

    /// Key paths to the stored `minutesPerCup`, or to the computed equivalent.
    var readsStoredProperties = true
    /// Orders grouped by drink, or as generated. With automatic domains this also changes the colours.
    var sortsByDrink = true
    /// The wait and drink domains stated, or left to the framework.
    var setsScaleDomains = true

    /// The orders as generated, drinks in no order.
    private(set) var generatedOrders: [CafeOrder] = []
    /// The same orders grouped by drink.
    private(set) var sortedOrders: [CafeOrder] = []
    /// The stretches of the day VoiceOver reads.
    private(set) var portions: [TimeOfDayPortion] = []

    init() {
        regenerate()
    }

    var count: Int {
        generatedOrders.count
    }

    /// What the chart is handed: sorted or not, nothing else changes.
    var orders: [CafeOrder] {
        sortsByDrink ? sortedOrders : generatedOrders
    }

    private func regenerate() {
        // snippet:keeping-a-large-plot-fast-unsorted
        // As generated: the drinks come in no order, so the colour changes almost every point.
        generatedOrders = CafeData.manyOrders(count: Int(orderCount))
        // end
        sortedOrders = Self.sortedByDrink(generatedOrders)
        portions = TimeOfDayPortion.make(
            generatedOrders, hour: \.hour, wait: \.minutesPerCup, category: \.drink, categoryOrder: LargePlotScales.drinks
        )
    }

    // snippet:keeping-a-large-plot-fast-sorted
    /// The orders grouped by drink, in legend order, so the colour changes as few times as possible
    /// along the collection: Apple's advice for a large plot, which made no measurable difference to one
    /// render here. Sorted once, here, when the data changes; never while drawing.
    nonisolated static func sortedByDrink(_ orders: [CafeOrder]) -> [CafeOrder] {
        let rank = Dictionary(uniqueKeysWithValues: LargePlotScales.drinks.enumerated().map { ($1, $0) })
        return orders.sorted {
            (rank[$0.drink] ?? Int.max, $0.id) < (rank[$1.drink] ?? Int.max, $1.id)
        }
    }

    // end

    /// How many times the drink, and so the colour, changes from one order to the next along `orders`.
    nonisolated static func styleChanges(in orders: [CafeOrder]) -> Int {
        zip(orders, orders.dropFirst()).count { $0.drink != $1.drink }
    }

    var styleChanges: Int {
        Self.styleChanges(in: orders)
    }

    /// Under the sort toggle: how often the colour changes along the data as it is now handed to the plot, and
    /// what the order does to the picture: points are drawn in data order, so the last drink covers the others.
    func styleChangesText(locale: Locale) -> String {
        "The colour changes \(Self.times(styleChanges, locale: locale)) along the data. \(drawingOrderText)"
    }

    /// Where points overlap, the one drawn later covers the earlier: sorted, that is always the last drink.
    var drawingOrderText: String {
        guard let last = LargePlotScales.drinks.last else { return "" }
        return sortsByDrink
            ? "\(last), drawn last, covers the other drinks where points overlap."
            : "The drinks are drawn mixed, so none covers the others."
    }

    /// Under the domain toggle while the domains are automatic: what that changes in the picture. `nil` when stated.
    /// Changing the picture is what stating the domains is for here; the render time did not move.
    var domainNote: String? {
        setsScaleDomains ? nil
            : "The wait axis now ends where the framework rounds the data to, and each drink takes its colour "
            + "in the order it first appears in the data, so sorting the orders changes the colours."
    }

    // MARK: Headline

    /// The order with the longest wait per cup, the first of them on a tie.
    var longestWait: CafeOrder? {
        generatedOrders.max { $0.minutesPerCup < $1.minutesPerCup || ($0.minutesPerCup == $1.minutesPerCup && $0.id > $1.id) }
    }

    /// True in every setting, because every setting draws the same orders.
    func headline(locale: Locale) -> String {
        guard let longest = longestWait else { return "No orders to draw." }
        return "Of \(CafeWording.orders(count, locale: locale)), the longest wait per cup, "
            + "\(TimeOfDayWording.minutes(longest.minutesPerCup, locale: locale)), "
            + "came at \(TimeOfDayWording.time(hour: longest.hour, locale: locale))."
    }

    /// The slider's spoken value: the count, then the headline, so dragging it says what is drawn without an
    /// announcement on every step.
    func countSpokenValue(locale: Locale) -> String {
        "\(CafeWording.orders(count, locale: locale)). \(headline(locale: locale))"
    }

    func countText(locale: Locale) -> String {
        count.formatted(.number.locale(locale))
    }

    // MARK: Announcements

    /// What a toggle changed, then the headline.
    func announcement(for advice: LargePlotAdvice, locale: Locale) -> String {
        let change = switch advice {
        case .storedProperties:
            readsStoredProperties
                ? "The plot now reads the stored wait per cup."
                : "The plot now reads a computed wait per cup."
        case .sortedByStyle:
            (sortsByDrink ? "The orders are now sorted by drink." : "The orders are now unsorted.")
                + " \(drawingOrderText)"
                + (sortChangesColours ? " With automatic domains, the drinks change colour too." : "")
        case .explicitDomains:
            setsScaleDomains
                ? "The wait and drink domains are now stated."
                : "The wait and drink domains are now automatic."
        }
        return "\(change) \(headline(locale: locale))"
    }

    /// Whether switching the sort now changes the drinks' colours: only with automatic domains, where each
    /// drink takes its colour in the order it first appears, and only when the two orders differ there.
    var sortChangesColours: Bool {
        !setsScaleDomains && Self.firstAppearance(in: generatedOrders) != Self.firstAppearance(in: sortedOrders)
    }

    /// The drinks in the order they first appear along `orders`, which is the order automatic colours follow.
    nonisolated static func firstAppearance(in orders: [CafeOrder]) -> [String] {
        var seen: [String] = []
        for order in orders where !seen.contains(order.drink) {
            seen.append(order.drink)
            if seen.count == LargePlotScales.drinks.count { break }
        }
        return seen
    }

    // MARK: Spoken stretches

    /// One stretch's value: "382 orders, waits per cup from 0.3 minutes to 8.1 minutes, median 2 minutes;
    /// Latte 95, Tea 90, Mocha 100, and Espresso 97".
    nonisolated static func spokenValue(of portion: TimeOfDayPortion, locale: Locale) -> String {
        let sorted = portion.waits.sorted()
        guard let shortest = sorted.first, let longest = sorted.last else { return "No orders." }
        var words = "\(CafeWording.orders(sorted.count, locale: locale)), waits per cup from "
            + "\(TimeOfDayWording.minutes(shortest, locale: locale)) to \(TimeOfDayWording.minutes(longest, locale: locale)), "
            + "median \(TimeOfDayWording.minutes(median(sorted), locale: locale))"
        if !portion.categoryCounts.isEmpty {
            words += "; " + CafeWording.list(portion.categoryCounts.map {
                "\($0.name) \($0.count.formatted(.number.locale(locale)))"
            })
        }
        return words
    }

    /// The median of values already sorted, or 0 for none.
    nonisolated static func median(_ sorted: [Double]) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    /// "1 time", "3 times", "14,987 times".
    nonisolated static func times(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) time](inflect: true)", locale: locale).characters)
    }

    // MARK: - Timings

    // Measured 2026-11-18 on the iPhone 17 simulator: `ImageRenderer` at scale 3, 360 × 260 points, the median
    // of 9 renders per variant after one warm-up, the variants' order rotated each round. One render, not
    // live updates, scrolling or a device: the figures say nothing about those.

    /// How many orders the main timings drew.
    static let measuredOrderCount = 20000
    /// Each variant's median render time at `measuredOrderCount`, in milliseconds, all on first and all off last.
    static let measurements: [LargePlotMeasurement] = [
        LargePlotMeasurement(name: "All three on", milliseconds: 178.1),
        LargePlotMeasurement(name: LargePlotAdvice.storedProperties.offDescription, milliseconds: 180.6),
        LargePlotMeasurement(name: LargePlotAdvice.sortedByStyle.offDescription, milliseconds: 178.4),
        LargePlotMeasurement(name: LargePlotAdvice.explicitDomains.offDescription, milliseconds: 179.1),
        LargePlotMeasurement(name: "All three off", milliseconds: 182.4),
    ]
    /// How far apart one variant's fastest and slowest renders were, across the variants.
    static let spreadMilliseconds: ClosedRange<Double> = 5 ... 13
    /// The smaller count measured, and the range every variant's median fell in there.
    static let smallerOrderCount = 5000
    static let smallerMilliseconds: ClosedRange<Double> = 52 ... 54

    /// One row per variant: "A computed property: 180.6 ms".
    nonisolated static func timingLines(_ measurements: [LargePlotMeasurement], locale: Locale) -> [String] {
        measurements.compactMap { measurement in
            guard measurement.milliseconds.isFinite else { return nil }
            return "\(measurement.name): \(milliseconds(measurement.milliseconds, locale: locale))"
        }
    }

    /// Over the rows: what was measured and how much one variant varied.
    nonisolated static func timingCaption(orderCount: Int, spread: ClosedRange<Double>, locale: Locale) -> String {
        "One render on the iOS simulator at \(CafeWording.orders(orderCount, locale: locale)), the median of 9. "
            + "One variant's renders varied by \(spread.lowerBound.formatted(.number.locale(locale))) to "
            + "\(milliseconds(spread.upperBound, locale: locale))."
    }

    /// Under the rows: what the figures show and what they do not. A setting counts as measurably faster only
    /// when it beats every other by more than the smallest spread between one variant's renders.
    nonisolated static func timingVerdict(
        _ measurements: [LargePlotMeasurement],
        orderCount: Int,
        spread: ClosedRange<Double>,
        smallerCount: Int,
        smallerMilliseconds: ClosedRange<Double>,
        locale: Locale
    ) -> String {
        let medians = measurements.map(\.milliseconds).filter(\.isFinite)
        guard let fastest = medians.min(), let slowest = medians.max() else { return "" }
        let firstSentence = slowest - fastest <= spread.lowerBound
            ? "No setting was measurably faster: the medians lie within the spread of one variant's renders."
            : "The settings' medians differ by more than one variant's renders did."
        let smaller = (smallerMilliseconds.lowerBound + smallerMilliseconds.upperBound) / 2
        let timeRatio = (fastest / smaller).formatted(.number.precision(.fractionLength(1)).locale(locale))
        let pointRatio = (Double(orderCount) / Double(smallerCount)).formatted(.number.locale(locale))
        return firstSentence + " What costs time is the number of points: "
            + "\(CafeWording.orders(smallerCount, locale: locale)) took "
            + "\(smallerMilliseconds.lowerBound.formatted(.number.locale(locale))) to "
            + "\(milliseconds(smallerMilliseconds.upperBound, locale: locale)) in every setting, so \(pointRatio) times "
            + "the points took about \(timeRatio) times as long. A single render says nothing about live updates, "
            + "scrolling or a device."
    }

    /// "178.1 ms".
    nonisolated static func milliseconds(_ value: Double, locale: Locale) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))) ms"
    }
}

/// One variant's measured render time.
nonisolated struct LargePlotMeasurement: Hashable {
    let name: String
    let milliseconds: Double
}
