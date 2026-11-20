import Foundation
import Observation

/// The domains the screen can give its chart: four for the cups axis, two for the order of the drinks.
nonisolated enum ScaleDomainOption: String, CaseIterable, Identifiable, Hashable {
    case automatic
    case exact
    case withoutZero
    case reversed
    case closure
    case array

    var id: String {
        rawValue
    }

    /// The segment's title.
    var title: String {
        switch self {
        case .automatic: "Auto"
        case .exact: "Exact"
        case .withoutZero: "No 0"
        case .reversed: "Flip"
        case .closure: "Sort"
        case .array: "Rank"
        }
    }

    /// Whether this option is the wrong way to draw bars, shown on purpose.
    var isMistake: Bool {
        self == .withoutZero
    }
}

extension ScaleDomainOption {
    /// The snippet that shows this option's domain.
    @MainActor var snippet: SnippetReference {
        switch self {
        case .automatic: SnippetReference(name: "scale-domain-automatic", title: "Automatic domain")
        case .exact: SnippetReference(name: "scale-domain-exact", title: "Exact domain")
        case .withoutZero: SnippetReference(name: "scale-domain-without-zero", title: "Without zero (the mistake on bars)")
        case .reversed: SnippetReference(name: "scale-domain-reversed", title: "Reversed domain")
        case .closure: SnippetReference(name: "scale-domain-closure", title: "Domain adjusted in a closure")
        case .array: SnippetReference(name: "scale-domain-array", title: "Categories ordered by an array")
        }
    }
}

/// The screen's state: which domain the chart is drawn with.
@Observable
final class ScaleDomainViewModel {
    /// The snippet with the chart itself, shown with every option.
    static let chartSnippet = SnippetReference(name: "scale-domain-chart", title: "The chart")

    let sales: [DrinkSales]
    var option: ScaleDomainOption

    init(sales: [DrinkSales] = CafeData.drinkSales, option: ScaleDomainOption = .automatic) {
        self.sales = sales
        self.option = option
    }

    /// The snippets for the current option: the chart, then its domain.
    var snippets: [SnippetReference] {
        [Self.chartSnippet, option.snippet]
    }

    func summary(locale: Locale) -> ScaleDomainSummary {
        ScaleDomainSummary(sales: sales, option: option, locale: locale)
    }
}

/// What the chart says in words for one option: the headline, the announcement, the elements' values
/// and the Audio Graph's summary.
nonisolated struct ScaleDomainSummary {
    /// The exact domain of the cups axis: the same scale every day, whatever today's sales.
    static let exactDomain = 0 ... 300

    let sales: [DrinkSales]
    let option: ScaleDomainOption
    /// The locale every number is written in. It has no default: the view passes its environment's.
    let locale: Locale

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// Every drink that sold the most, in data order.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order.
    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The data's extent rounded out to tens, starting from the fewest cups any drink sold (a drink that sold
    /// none draws no bar either way): a domain that leaves zero out, for the mistake. Today's sales give 50 ... 170.
    var zeroFreeDomain: ClosedRange<Int> {
        let sold = sales.map(\.cups).filter { $0 > 0 }
        guard let fewest = sold.min(), let most = sold.max() else { return 0 ... 1 }
        let step = 10
        let lower = fewest / step * step
        let upper = (most + step - 1) / step * step
        return lower ... max(upper, lower + step)
    }

    /// The drinks sorted by name, as the closure sorts them.
    var drinksByName: [String] {
        sales.map(\.drink).sorted()
    }

    /// The drinks from most cups to fewest; a tie keeps data order. The array given as the domain.
    var drinksByRank: [String] {
        sales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element.drink)
    }

    /// The drinks from the top row to the bottom, as the current domain draws them.
    var drawnOrder: [String] {
        switch option {
        case .closure: drinksByName
        case .array: drinksByRank
        default: sales.map(\.drink)
        }
    }

    /// The range of the cups axis as drawn, for the Audio Graph. The automatic options leave the chart's domain to
    /// the framework (this screen's subject), which rounds it out from zero; `ChartAxis` gives the same rounded
    /// top (0 to 200 for a longest bar of 164), so the Audio Graph reads the drawn ends.
    var valueRange: ClosedRange<Double> {
        switch option {
        case .exact:
            Double(Self.exactDomain.lowerBound) ... Double(Self.exactDomain.upperBound)
        case .withoutZero:
            Double(zeroFreeDomain.lowerBound) ... Double(zeroFreeDomain.upperBound)
        default:
            ChartAxis.valueDomain(for: sales.map(\.cups))
        }
    }

    /// The chart's message in a sentence, true for the option and the data, including no sales and ties.
    var headline: String {
        guard let most = bestSellers.first?.cups else { return "No cups sold yet today." }
        let best = names(bestSellers)
        let mostText = CafeWording.cups(most, locale: locale)
        switch option {
        case .automatic:
            return "\(best) sold the most: \(mostText)."
        case .exact:
            // The scale's end is not labelled (no room at the plot's edge), so the headline does not quote it.
            if most > Self.exactDomain.upperBound {
                return "\(best) sold \(mostText), past the end of the fixed scale."
            }
            return "\(best) sold the most, \(mostText), on a fixed scale, not one fitted to the data."
        case .withoutZero:
            guard let fewest = slowestSellers.first?.cups, fewest > 0, fewest < most else {
                return "Without zero, the bars no longer measure cups: \(best) sold \(mostText)."
            }
            let ratio = (Double(most) / Double(fewest)).formatted(.number.precision(.fractionLength(1)).locale(locale))
            return "\(best) sold \(ratio) times as many cups as \(names(slowestSellers)), "
                + "\(number(most)) to \(number(fewest)), but without zero the bars make the gap look far larger."
        case .reversed:
            return "With the cups axis reversed, the bars grow from the other side. \(best) sold the most: \(mostText)."
        case .closure:
            let byName = drinksByName
            guard let first = byName.first, let last = byName.last, byName.count > 1 else {
                return "Sorted by name in a closure: \(best) sold \(mostText)."
            }
            return "Sorted by name in a closure, from \(first) to \(last). \(best) sold the most: \(mostText)."
        case .array:
            return "Ranked by a domain array: \(best) at the top, with \(mostText)."
        }
    }

    /// What changed, for the announcement that follows a change of option.
    var changeDescription: String {
        switch option {
        case .automatic: "Automatic domain."
        case .exact: "Exact domain, \(exactRangeText)."
        case .withoutZero: "Exact domain leaving zero out, \(zeroFreeRangeText)."
        case .reversed: "Reversed domain."
        case .closure: "Drink domain sorted in a closure."
        case .array: "Drinks ordered by a domain array."
        }
    }

    /// Spoken when the option changes: what changed, then the headline.
    var announcement: String {
        "\(changeDescription) \(headline)"
    }

    /// One bar's value as read by VoiceOver. Without zero it says the bar is cut short, as it is drawn.
    func elementValue(for item: DrinkSales) -> String {
        let cups = CafeWording.cups(item.cups, locale: locale)
        return option == .withoutZero ? "\(cups); the bar does not start at zero" : cups
    }

    /// The Audio Graph's summary: how the axis is drawn, then actual values only.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(axisSentence) \(CafeWording.drinks(sales.count, locale: locale)), "
            + "\(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(names(bestSellers)), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(names(slowestSellers)), \(CafeWording.cups(fewest, locale: locale))."
    }

    private var axisSentence: String {
        switch option {
        case .automatic: "The cups axis starts at zero."
        case .exact: "The cups axis is fixed at \(exactRangeText)."
        case .withoutZero: "The cups axis does not start at zero, so the bars are cut short."
        case .reversed: "The cups axis is reversed: the bars grow from the other side."
        case .closure: "Drinks are in name order."
        case .array: "Drinks are ranked from most to fewest cups."
        }
    }

    /// "0 to 300 cups".
    private var exactRangeText: String {
        "\(number(Self.exactDomain.lowerBound)) to \(CafeWording.cups(Self.exactDomain.upperBound, locale: locale))"
    }

    /// The ends of the domain that leaves zero out: "50 to 170 cups" for today's sales.
    private var zeroFreeRangeText: String {
        "\(number(zeroFreeDomain.lowerBound)) to \(CafeWording.cups(zeroFreeDomain.upperBound, locale: locale))"
    }

    private func number(_ value: Int) -> String {
        value.formatted(.number.locale(locale))
    }

    private func names(_ drinks: [DrinkSales]) -> String {
        CafeWording.list(drinks.map(\.drink))
    }
}
