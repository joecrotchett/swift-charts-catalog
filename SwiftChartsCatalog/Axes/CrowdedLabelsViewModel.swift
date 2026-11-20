import Accessibility
import Foundation
import Observation
import SwiftUI

/// What the x axis does with drink names that do not fit their bands.
nonisolated enum CrowdedLabelsResolution: String, CaseIterable, Identifiable {
    /// The default: a name that does not fit its band is cut short.
    case truncate
    /// Only the names that fit are drawn; the rest are left out.
    case greedy
    /// Every name is drawn in full, even where names overlap.
    case disabled
    /// The names are turned to read top to bottom.
    case vertical

    var id: String {
        rawValue
    }

    /// The picker's segment title.
    var title: String {
        switch self {
        case .truncate: "Truncate"
        case .greedy: "Greedy"
        case .disabled: "Disabled"
        case .vertical: "Vertical"
        }
    }

    /// What this setting does, in a sentence that is true at any width: it says what happens to a name
    /// that does not fit, not that any name fails to fit.
    var note: String {
        switch self {
        case .truncate:
            "The default. Each name gets the width of its band, the bar and the gap beside it; a name that does not "
                + "fit is cut short."
        case .greedy:
            "Names are drawn in order while they fit; a name that would collide with one already drawn is left out."
        case .disabled:
            "Every name is drawn in full, and names that do not fit run into each other."
        case .vertical:
            "The names are turned to read top to bottom, so each needs only a line's height across its band; the plot gives up height to the longest name."
        }
    }

    /// The See Code region for this setting's axis.
    var snippetName: String {
        "crowded-labels-\(rawValue)"
    }

    var snippetTitle: String {
        switch self {
        case .truncate: "The default axis truncates"
        case .greedy: "Greedy labels"
        case .disabled: "Collision resolution disabled"
        case .vertical: "Vertical labels"
        }
    }
}

/// The screen's state: how the axis resolves crowded names, and how wide the chart is drawn.
@Observable
final class CrowdedLabelsViewModel {
    static let chartSnippet = SnippetReference(name: "crowded-labels-chart", title: "The bars")
    /// The narrowest and widest the chart is drawn, as a share of the panel's width.
    static let widthRange: ClosedRange<Double> = 0.4 ... 1
    static let widthStep = 0.1

    let sales: [DrinkSales]
    var resolution: CrowdedLabelsResolution = .truncate
    /// The chart's width as a share of the panel's width, from 0.4 to 1.
    var widthFraction: Double = 1

    init(sales: [DrinkSales] = CrowdedLabelsData.menu) {
        self.sales = sales
    }

    /// The bars, then the axis for the current setting.
    var snippets: [SnippetReference] {
        [Self.chartSnippet, SnippetReference(name: resolution.snippetName, title: resolution.snippetTitle)]
    }

    /// "60% of the panel", beside the slider's title: the same words VoiceOver reads.
    func widthText(locale: Locale) -> String {
        "\(widthFraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))) of the panel"
    }

    /// "60% of the panel", as VoiceOver reads the slider: the setting described as it is shown. The slider
    /// only restyles the chart, so its spoken value is the whole announcement it needs.
    func spokenWidth(locale: Locale) -> String {
        widthText(locale: locale)
    }
}

/// A full menu of drinks, so there are more names along the axis than fit at phone width. `CafeData`
/// has no data set with ten categories of long names drawn as bars, so it lives here.
nonisolated enum CrowdedLabelsData {
    /// Cups sold today at the Station café, by drink, ranked from most to fewest.
    static let menu: [DrinkSales] = [
        DrinkSales(drink: "Latte", cups: 42),
        DrinkSales(drink: "Cappuccino", cups: 35),
        DrinkSales(drink: "Flat white", cups: 29),
        DrinkSales(drink: "Americano", cups: 26),
        DrinkSales(drink: "Hot chocolate", cups: 21),
        DrinkSales(drink: "Chai latte", cups: 17),
        DrinkSales(drink: "Iced coffee", cups: 14),
        DrinkSales(drink: "Matcha latte", cups: 11),
        DrinkSales(drink: "Macchiato", cups: 9),
        DrinkSales(drink: "Espresso", cups: 7),
    ]
}

/// What the chart says in words: its headline and the Audio Graph's summary. The controls change only
/// how the names along the axis are drawn, never the data, so neither changes with them.
nonisolated struct CrowdedLabelsSummary {
    let sales: [DrinkSales]
    /// The locale every count is written in, passed in from the view's environment.
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

    static let nothingSold = "No cups sold yet today."

    /// The chart's message: the best seller and its cups, a bar a reader can find at the top of the scale.
    var headline: String {
        guard let cups = bestSellers.first?.cups else { return Self.nothingSold }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values only.
    var audioGraphSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return Self.nothingSold
        }
        return "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }
}

/// The chart for the Audio Graph. It carries every drink's full name, whatever the axis draws.
nonisolated struct CrowdedLabelsChartDescriptor: AXChartDescriptorRepresentable {
    static let title = "Cups sold today at the \(CafeWording.station) café, by drink"

    let sales: [DrinkSales]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = CrowdedLabelsSummary(sales: sales, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink))
        // The bars grow from zero, so the drawn scale starts at zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: ChartAxis.valueDomain(for: sales.map(\.cups)),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.station,
            isContinuous: false,
            dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: Self.title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
