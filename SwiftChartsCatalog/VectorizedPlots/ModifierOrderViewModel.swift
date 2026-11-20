import Foundation
import Observation

/// The state and words of "Modifier order": a point plot of orders in the right modifier order,
/// or, as the mistake, the compiler error the wrong order gave.
@Observable
final class ModifierOrderViewModel {
    /// How many generated orders the plot draws: a collection, few enough for every point to be seen.
    static let orderCount = 400

    /// The orders, grouped by drink in the colour scale's order, so the style changes as few times
    /// as possible along the collection.
    let orders: [CafeOrder]
    /// Whether the screen shows the wrong order: a plain-value modifier before the key-path one.
    var isShowingMistake = false

    init(orders: [CafeOrder] = CafeData.manyOrders(count: ModifierOrderViewModel.orderCount)) {
        self.orders = ModifierOrderSummary.groupedByDrink(orders)
    }

    /// Nothing to plot: the placeholder replaces the chart, and the mistake toggle is disabled.
    var showsPlaceholder: Bool {
        orders.isEmpty
    }

    func summary(locale: Locale) -> ModifierOrderSummary {
        ModifierOrderSummary(orders: orders, locale: locale)
    }

    /// The headline for the current state: the data's, or what the wrong order leaves on screen.
    func headline(locale: Locale) -> String {
        isShowingMistake ? ModifierOrderCompilerError.headline : summary(locale: locale).headline
    }

    var explanation: String {
        """
        On a plot, key-path modifiers such as foregroundStyle(by:) and symbol(by:) read a value from each element, \
        and exist only on the plot itself. A plain-value modifier such as symbolSize(_:) or opacity(_:) styles the \
        whole plot and returns ordinary chart content, which has no key-path modifiers. So the key-path ones come first.
        """
    }

    /// The code the current state shows: the right order, or the wrong one followed by the fix.
    var snippets: [SnippetReference] {
        isShowingMistake ? [Self.wrongSnippet, Self.rightSnippet] : [Self.rightSnippet]
    }

    static let rightSnippet = SnippetReference(name: "modifier-order-right", title: "Key-path modifiers first")
    static let wrongSnippet = SnippetReference(name: "modifier-order-wrong", title: "The mistake: plain-value modifiers first")

    /// What VoiceOver hears when the toggle changes what is drawn: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = isShowingMistake
            ? "Showing the wrong order. The chart is replaced by the compiler error."
            : "Showing the right order. The chart is drawn."
        return "\(change) \(headline(locale: locale))"
    }
}

/// What Xcode gave for the wrong order, copied from the build log, with the version that gave it.
nonisolated enum ModifierOrderCompilerError {
    static let xcodeVersion = "Xcode 27.0 (27A266a)"
    /// The two errors, in the order the build log listed them: one on each plain-value line, none on the
    /// key-path modifiers that are actually out of place.
    static let messages = [
        "error: no exact matches in call to instance method 'symbolSize'",
        "error: cannot convert value of type 'Double' to expected argument type "
            + "'KeyPath<PointPlot<VectorizedPointPlotContent<[CafeOrder]>>.DataElement, CGFloat>' "
            + "(aka 'KeyPath<CafeOrder, CGFloat>')",
    ]
    static let title = "Build failed: two errors, on the symbolSize(_:) and opacity(_:) lines"
    static let note = "Both point at lines that are right on their own, and neither says that the order is the problem."
    static let headline = "In this order the plot does not compile, so there is no chart to draw."
}

/// The chart's words: headline, the Audio Graph's summary, and how a time and a wait are said.
nonisolated struct ModifierOrderSummary {
    let orders: [CafeOrder]
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The hours the x scale covers: the generated orders fall between 6 am and 6 pm.
    static let hourDomain = TimeOfDayWording.dayHours

    /// The orders sorted by drink, in the order of `CafeData.manyOrderDrinks`, keeping their order within a drink.
    static func groupedByDrink(_ orders: [CafeOrder]) -> [CafeOrder] {
        let drinks = CafeData.manyOrderDrinks
        return orders.enumerated().sorted { first, second in
            let firstRank = drinks.firstIndex(of: first.element.drink) ?? drinks.count
            let secondRank = drinks.firstIndex(of: second.element.drink) ?? drinks.count
            return (firstRank, first.offset) < (secondRank, second.offset)
        }
        .map(\.element)
    }

    /// The order with the longest wait, the first of them on a tie.
    var longest: CafeOrder? {
        orders.max { $0.waitMinutes < $1.waitMinutes }
    }

    var shortest: CafeOrder? {
        orders.min { $0.waitMinutes < $1.waitMinutes }
    }

    /// The top of the y scale: the longest wait rounded up to a whole minute, at least one.
    var waitDomain: ClosedRange<Double> {
        0 ... max(1, (longest?.waitMinutes ?? 0).rounded(.up))
    }

    var headline: String {
        guard let longest else { return "No orders yet." }
        return "Of \(CafeWording.orders(orders.count, locale: locale)), the longest wait was "
            + "\(ModifierOrderWording.minutes(longest.waitMinutes, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let longest, let shortest else { return "No orders yet." }
        return "\(CafeWording.orders(orders.count, locale: locale)), between "
            + "\(ModifierOrderWording.clockTime(Self.hourDomain.lowerBound, locale: locale)) and "
            + "\(ModifierOrderWording.clockTime(Self.hourDomain.upperBound, locale: locale)). "
            + "Shortest wait \(ModifierOrderWording.minutes(shortest.waitMinutes, locale: locale)), "
            + "longest \(ModifierOrderWording.minutes(longest.waitMinutes, locale: locale)) "
            + "at \(ModifierOrderWording.clockTime(longest.hour, locale: locale))."
    }

    /// The day in stretches as VoiceOver reads it, each counting its orders by drink.
    var portions: [TimeOfDayPortion] {
        TimeOfDayPortion.make(
            orders, hour: \.hour, wait: \.waitMinutes, category: \.drink, categoryOrder: CafeData.manyOrderDrinks
        )
    }

    /// The drinks present, in the colour scale's order.
    var drinks: [String] {
        CafeData.manyOrderDrinks.filter { drink in orders.contains { $0.drink == drink } }
    }
}

/// Words this screen needs that `CafeWording` does not have: the vectorized-plot screens' shared ones.
nonisolated enum ModifierOrderWording {
    static let timeOfDay = TimeOfDayWording.timeOfDay
    static let wait = TimeOfDayWording.wait
    static let waitAxisTitle = TimeOfDayWording.waitAxisTitle

    /// A wait with at most one decimal place, agreeing in number: "1 minute", "9.8 minutes".
    static func minutes(_ amount: Double, locale: Locale) -> String {
        TimeOfDayWording.minutes(amount, locale: locale)
    }

    /// An hour since midnight as the locale writes a clock time: 8.5 is "8:30 AM" in the United States.
    static func clockTime(_ hour: Double, locale: Locale) -> String {
        TimeOfDayWording.time(hour: hour, locale: locale)
    }
}
