import Foundation
import Observation

/// The state of the "Bar" screen: which way the bars run, how thick they are, and whether the
/// drinks still have a category axis or every value lands in one bar.
@Observable
final class BarMarkViewModel {
    /// Which axis holds the number, and so which way the bars grow.
    nonisolated enum Orientation: String, CaseIterable, Identifiable {
        case vertical = "Vertical"
        case horizontal = "Horizontal"

        var id: Self {
            self
        }
    }

    /// How the thickness of a bar is given.
    nonisolated enum BarWidth: String, CaseIterable, Identifiable {
        case automatic = "Automatic"
        case ratio = "Ratio"
        case fixed = "Fixed"

        /// The fraction of the band the ratio setting uses. The screen's snippet writes the same number.
        static let bandRatio = 0.9
        /// The size in points the fixed setting uses. The screen's snippet writes the same number.
        static let fixedPoints = 12

        var id: Self {
            self
        }
    }

    var orientation = Orientation.vertical
    var width = BarWidth.automatic
    /// When on, the marks have no category, so every value lands in one bar.
    var removesCategory = false

    /// A bar's thickness is measured against its category's band. With no category there is no band,
    /// and the setting changes nothing that is drawn, so the control is offered only with a category.
    var isThicknessAvailable: Bool {
        !removesCategory
    }

    /// What the Thickness row shows. With the category removed the chosen setting is not in effect,
    /// so the row says so in place of the setting.
    var thicknessText: String {
        isThicknessAvailable ? width.rawValue : Self.thicknessNotUsed
    }

    static let thicknessNotUsed = "Not used"

    /// The drinks, largest first: the headline says which sold the most, so the bars are ranked.
    let sales: [DrinkSales]

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = BarMarkSummary.ranked(sales)
    }

    /// The chart's words in the locale given: the screen passes its environment's.
    func summary(locale: Locale) -> BarMarkSummary {
        BarMarkSummary(sales: sales, removesCategory: removesCategory, locale: locale)
    }

    var caption: String {
        removesCategory ? "Cups sold today, all drinks" : "Cups sold today, by drink"
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline
    }

    /// The parameter that sets a bar's thickness: across the bar, so it follows the orientation.
    var thicknessParameter: String {
        orientation == .vertical ? "width:" : "height:"
    }

    var explanation: String {
        // One bar is drawn with the category removed, so the sentence speaks of one.
        let direction = switch (orientation, removesCategory) {
        case (.vertical, false): "The number is on y, so the bars rise from zero."
        case (.horizontal, false): "The number is on x, so the bars grow from the leading edge."
        case (.vertical, true): "The number is on y, so the bar rises from zero."
        case (.horizontal, true): "The number is on x, so the bar grows from the leading edge."
        }
        guard !removesCategory else { return "\(direction) \(oneBarExplanation)" }
        return "\(direction) The drink on the other axis gives each bar a band of its own. \(widthExplanation)"
    }

    private var oneBarExplanation: String {
        // Across the bar: a vertical bar fills the plot's width, a horizontal one its height.
        let fill = switch orientation {
        case .vertical: "from side to side"
        case .horizontal: "from top to bottom"
        }
        return "Nothing is on the other axis, so every drink's cups land in one bar, end to end: its length is "
            + "their total, and faint lines mark where one drink ends and the next begins. With no category "
            + "there is no band to measure a thickness against, so the bar fills the plot \(fill); "
            + "here the chart's own frame keeps it slim."
    }

    private var widthExplanation: String {
        let ratio = BarWidth.bandRatio.formatted()
        let points = BarWidth.fixedPoints.formatted()
        switch width {
        case .automatic:
            return "With no \(thicknessParameter) the framework chooses the thickness, a share of the band."
        case .ratio:
            return "\(thicknessParameter) .ratio(\(ratio)) makes each bar that fraction of its band, "
                + "so the bars thin as more of them share the chart."
        case .fixed:
            return "\(thicknessParameter) .fixed(\(points)) is \(points) points, however many bars there are."
        }
    }

    /// The code for the current setting: the chart, then how its bars' thickness is given.
    /// The one bar takes no thickness, so it shows the chart alone.
    var snippets: [SnippetReference] {
        switch (orientation, removesCategory) {
        case (.vertical, true): return [SnippetReference(name: "bar-vertical-one", title: "One bar, no category")]
        case (.horizontal, true): return [SnippetReference(name: "bar-horizontal-one", title: "One bar, no category")]
        default: break
        }
        let chart = switch orientation {
        case .vertical: SnippetReference(name: "bar-vertical", title: "Vertical bars")
        case .horizontal: SnippetReference(name: "bar-horizontal", title: "Horizontal bars")
        }
        let size = switch width {
        case .automatic: SnippetReference(name: "bar-width-automatic", title: "Automatic thickness")
        case .ratio: SnippetReference(name: "bar-width-ratio", title: "A ratio of the band")
        case .fixed: SnippetReference(name: "bar-width-fixed", title: "A fixed size")
        }
        return [chart, size]
    }

    /// Every snippet the screen can show, for registering it.
    static let allSnippets: [SnippetReference] = [
        SnippetReference(name: "bar-vertical", title: "Vertical bars"),
        SnippetReference(name: "bar-horizontal", title: "Horizontal bars"),
        SnippetReference(name: "bar-vertical-one", title: "One bar, no category"),
        SnippetReference(name: "bar-horizontal-one", title: "One bar, no category"),
        SnippetReference(name: "bar-width-automatic", title: "Automatic thickness"),
        SnippetReference(name: "bar-width-ratio", title: "A ratio of the band"),
        SnippetReference(name: "bar-width-fixed", title: "A fixed size"),
    ]

    /// What to say aloud when a control redraws the chart: what it now shows, from every control.
    func announcement(locale: Locale) -> String {
        let summary = summary(locale: locale)
        guard !summary.isEmpty else { return summary.headline }
        switch (orientation, removesCategory) {
        case (.vertical, true): return "One vertical bar for all drinks. \(summary.headline)"
        case (.horizontal, true): return "One horizontal bar for all drinks. \(summary.headline)"
        default: break
        }
        let bars = switch orientation {
        case .vertical: "Vertical bars, one per drink"
        case .horizontal: "Horizontal bars, one per drink"
        }
        let size = switch width {
        case .automatic: "automatic thickness"
        case .ratio: "thickness \(BarWidth.bandRatio.formatted(.number.locale(locale))) of the band"
        case .fixed: "\(BarWidth.fixedPoints.formatted(.number.locale(locale))) points thick"
        }
        return "\(bars), \(size). \(summary.headline)"
    }
}

/// What the chart says in words, for the headline and for the Audio Graph.
nonisolated struct BarMarkSummary {
    /// The label of the single bar when the category is removed.
    static let allDrinks = "All drinks"

    let sales: [DrinkSales]
    let removesCategory: Bool
    /// The locale every count and list here is written in. It has no default: the views pass the
    /// environment's, so the headline, the elements and the Audio Graph agree.
    let locale: Locale

    /// Largest first; drinks that sold the same keep the order they came in.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .sorted { $0.element.cups == $1.element.cups ? $0.offset < $1.offset : $0.element.cups > $1.element.cups }
            .map(\.element)
    }

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn: from zero to the longest bar rounded up to the axis step (164 → 200; the one bar of
    /// 551 → 600). The chart's scale, on y or x as the bars are drawn, and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: removesCategory ? [total] : sales.map(\.cups))
    }

    /// Nothing sold is no data: the chart shows a placeholder.
    var isEmpty: Bool {
        total == 0
    }

    /// Every drink that sold the most, in data order. More than one when there is a tie.
    var bestSellers: [DrinkSales] {
        guard !isEmpty, let most = sales.map(\.cups).max() else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order.
    var slowestSellers: [DrinkSales] {
        guard !isEmpty, let fewest = sales.map(\.cups).min() else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The chart's message with its key value: the longest bar, or the one bar's total.
    var headline: String {
        guard let most = bestSellers.first?.cups else { return "No cups sold yet today." }
        if removesCategory {
            return "\(cupsText(total)) sold in total."
        }
        return "\(names(bestSellers)) sold the most: \(cupsText(most))."
    }

    /// Actual values only, for the chart as it is drawn.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        if removesCategory {
            return "One bar for \(drinksText(sales.count)): \(cupsText(total)) in total."
        }
        return "\(drinksText(sales.count)), \(cupsText(total)) in total. "
            + "Most: \(names(bestSellers)), \(cupsText(most)). "
            + "Fewest: \(names(slowestSellers)), \(cupsText(fewest))."
    }

    func names(_ drinks: [DrinkSales]) -> String {
        drinks.map(\.drink).formatted(.list(type: .and).locale(locale))
    }

    /// A count with its unit, agreeing in number: "1 cup", "164 cups".
    func cupsText(_ cups: Int) -> String {
        CafeWording.cups(cups, locale: locale)
    }

    func drinksText(_ count: Int) -> String {
        CafeWording.drinks(count, locale: locale)
    }
}
