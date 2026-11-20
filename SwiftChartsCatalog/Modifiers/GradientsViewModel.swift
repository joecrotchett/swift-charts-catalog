import Foundation
import Observation

/// Where the bars' gradient is laid out: inside each bar, or once across the whole plot area.
nonisolated enum GradientsAlignment: String, CaseIterable, Identifiable {
    case perMark
    case plotArea

    var id: Self {
        self
    }

    /// The picker's words for the setting.
    var title: String {
        switch self {
        case .perMark: "Per mark"
        case .plotArea: "Plot area"
        }
    }

    /// The sentence announced when the reader switches to this setting, before the headline.
    var changeSentence: String {
        switch self {
        case .perMark: "The gradient is now laid out inside each bar."
        case .plotArea: "The gradient is now laid out across the plot area."
        }
    }

    /// The value passed to `alignsMarkStylesWithPlotArea(_:)`.
    var alignsWithPlotArea: Bool {
        self == .plotArea
    }
}

/// The state behind "Gradients and the plot area": the sales drawn and where the gradient is laid out.
@Observable
final class GradientsViewModel {
    /// Cups sold today, tallest bar first, so the aligned gradient climbs from bar to bar.
    let sales: [DrinkSales]
    var alignment: GradientsAlignment = .perMark

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = GradientsSummary.ranked(sales)
    }

    /// The snippets See Code shows. The code is the same in both settings: only the Bool passed to
    /// `alignsMarkStylesWithPlotArea` changes, and the snippet shows that argument.
    var snippets: [SnippetReference] {
        Self.snippets
    }

    static let snippets = [SnippetReference(name: "gradients-chart", title: "A gradient per mark or across the plot")]

    func summary(locale: Locale) -> GradientsSummary {
        GradientsSummary(sales: sales, alignment: alignment, locale: locale)
    }

    /// What VoiceOver says after the picker changes: what changed, then the new headline.
    func announcement(locale: Locale) -> String {
        "\(alignment.changeSentence) \(summary(locale: locale).headline)"
    }
}

/// What the chart says in words: the headline for each setting, and the Audio Graph's summary.
nonisolated struct GradientsSummary {
    let sales: [DrinkSales]
    let alignment: GradientsAlignment
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// Most cups first; drinks with the same cups keep their data order.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// The cups axis as drawn, from zero to the most rounded up to the axis step (164 → 200): the chart's scale,
    /// the plot area the aligned gradient spans, and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    /// True when there is nothing to draw: no drinks, or no cups sold.
    var isEmpty: Bool {
        total == 0
    }

    /// Every drink that sold the most, in data order.
    var tallest: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// The drinks with a bar on the chart. A drink with no cups draws nothing, so it has no top and
    /// no colour, and the headline's colour sentences leave it out.
    var drawn: [DrinkSales] {
        sales.filter { $0.cups > 0 }
    }

    /// Every drawn bar of the fewest cups, in data order.
    var shortest: [DrinkSales] {
        guard let fewest = drawn.map(\.cups).min() else { return [] }
        return drawn.filter { $0.cups == fewest }
    }

    /// Every drink that sold the fewest, a drink with no cups included, in data order: the Audio
    /// Graph gives the values, whether or not they draw a bar.
    var fewest: [DrinkSales] {
        guard let least = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == least }
    }

    /// The chart's message for the current setting, with figures read off the chart as drawn.
    var headline: String {
        guard let most = tallest.first?.cups, let least = shortest.first?.cups else {
            return "No cups sold yet today."
        }
        let high = "\(names(tallest)), \(CafeWording.cups(most, locale: locale))"
        let low = "\(names(shortest)), \(CafeWording.cups(least, locale: locale))"
        switch alignment {
        case .perMark:
            if most == least {
                return "Every bar runs the whole gradient, yellow at its base to red at its top."
            }
            // The explanation says why (each bar holds the whole gradient); the headline is what the chart shows.
            return "The tops of \(high), and \(low), are the same red."
        case .plotArea:
            if most == least {
                return "Every bar is \(CafeWording.cups(most, locale: locale)), so each shows the same stretch of the gradient."
            }
            return "Colour now follows height. The reddest: \(high). The most yellow: \(low)."
        }
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = tallest.first?.cups, let least = fewest.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(names(tallest)), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(names(fewest)), \(CafeWording.cups(least, locale: locale))."
    }

    /// "Tea", "Latte and Tea": joined the English way, as the sentence around it is English.
    func names(_ drinks: [DrinkSales]) -> String {
        CafeWording.list(drinks.map(\.drink))
    }
}
