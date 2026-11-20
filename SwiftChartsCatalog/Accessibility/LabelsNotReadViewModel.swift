import Accessibility
import Foundation
import Observation
import SwiftUI

/// One accessibility element as VoiceOver reads it: its label, then its value.
nonisolated struct LabelsNotReadElement: Hashable {
    let label: String
    let value: String

    /// The element as it is read, label then value: "Latte, total 128, 3 Sizes".
    var spoken: String {
        "\(label), \(value)"
    }
}

/// Every text this screen shows as "what VoiceOver reads", in one table.
///
/// Both match what was read on the iPhone 17 simulator, iOS 27
/// (`Docs/field-notes/epic-10/wave-2-dumps/lnr-mistake.txt` and `lnr-fixed.txt`):
/// - `ignoredLabelElement`: one element per bar, labelled with the drink, valued "total 128, 3 Sizes"; the
///   labels on the bare segments are not read.
/// - `plotElement`: one element per labelled `Plot`, read by exactly its label and value, bar by bar in
///   drink order, each bar from its bottom segment up.
nonisolated enum LabelsNotReadSpokenTable {
    /// One bar whose segments carry bare labels: the framework's summary of the stack, the labels unread.
    static func ignoredLabelElement(drink: String, total: Int, sizes: Int, locale: Locale) -> LabelsNotReadElement {
        // "3 Sizes" is the `.value` label "Size" made plural by the framework, so it keeps its capital.
        let sizeCount = String(AttributedString(
            localized: "^[\(sizes) \(CafeWording.size)](inflect: true)", locale: locale
        ).characters)
        return LabelsNotReadElement(
            label: drink,
            value: "total \(total.formatted(.number.locale(locale))), \(sizeCount)"
        )
    }

    /// One segment inside a labelled `Plot`: exactly the label and value the code wrote.
    static func plotElement(_ order: DrinkOrder, locale: Locale) -> LabelsNotReadElement {
        LabelsNotReadElement(
            label: LabelsNotReadText.elementLabel(order),
            value: LabelsNotReadText.elementValue(order, locale: locale)
        )
    }
}

/// The label and value the code writes on every segment, in both states. In the mistake they are
/// written and not read; on a `Plot` they are read.
nonisolated enum LabelsNotReadText {
    /// Context first: the drink, then the size. "Latte, Small".
    static func elementLabel(_ order: DrinkOrder) -> String {
        "\(order.drink), \(order.size)"
    }

    /// The value with its unit: "34 cups".
    static func elementValue(_ order: DrinkOrder, locale: Locale) -> String {
        CafeWording.cups(order.cups, locale: locale)
    }

    /// "1 element", "9 elements". The words are this screen's own; `CafeWording` has no such count.
    static func elements(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) element](inflect: true)", locale: locale).characters)
    }

    /// "1 label", "9 labels".
    static func labels(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) label](inflect: true)", locale: locale).characters)
    }
}

/// The state of "Labels that are not read": the same stacked bars, their segment labels written either
/// on the bare marks (the mistake) or on a `Plot` around each mark.
@Observable
final class LabelsNotReadViewModel {
    /// `true` while the labels sit on the bare segments, the mistake shown on purpose.
    var isShowingMistake: Bool
    let orders: [DrinkOrder]

    static let bareSnippet = "labels-not-read-bare"
    static let plotSnippet = "labels-not-read-plot"
    static let identitySnippet = "labels-not-read-identity"

    init(orders: [DrinkOrder] = CafeData.drinkOrders, isShowingMistake: Bool = false) {
        self.orders = orders
        self.isShowingMistake = isShowingMistake
    }

    /// The segments that draw something. A segment of zero cups has no height, so it is left out of
    /// the chart and of everything said about it.
    var drawnOrders: [DrinkOrder] {
        orders.filter { $0.cups > 0 }
    }

    /// `true` when nothing would be drawn: the chart shows a placeholder instead.
    var isEmpty: Bool {
        drawnOrders.isEmpty
    }

    /// The drinks that have a bar, in data order.
    var drinks: [String] {
        var seen = Set<String>()
        return drawnOrders.map(\.drink).filter { seen.insert($0).inserted }
    }

    /// The sizes that appear, in data order: the stacking order and the legend's order.
    var sizes: [String] {
        var seen = Set<String>()
        return drawnOrders.map(\.size).filter { seen.insert($0).inserted }
    }

    /// The cups in each drink's bar, in data order.
    var totals: [(drink: String, cups: Int, sizes: Int)] {
        drinks.map { drink in
            let rows = drawnOrders.filter { $0.drink == drink }
            return (drink, rows.map(\.cups).reduce(0, +), rows.count)
        }
    }

    /// The top of the value axis, given to the chart's scale and to the descriptor alike: the tallest
    /// bar rounded up to the next 50 cups.
    var valueDomainTop: Int {
        let tallest = totals.map(\.cups).max() ?? 0
        let step = 50
        return max(step, (tallest + step - 1) / step * step)
    }

    /// What VoiceOver reads for the chart as it is drawn now, one entry per element, in reading order.
    func predictedElements(locale: Locale) -> [LabelsNotReadElement] {
        if isShowingMistake {
            totals.map {
                LabelsNotReadSpokenTable.ignoredLabelElement(drink: $0.drink, total: $0.cups, sizes: $0.sizes, locale: locale)
            }
        } else {
            drawnOrders.map { LabelsNotReadSpokenTable.plotElement($0, locale: locale) }
        }
    }

    /// The chart's headline: how many elements VoiceOver reads, which a reader can count as bars or
    /// segments in the chart. True for both settings and for no data.
    func headline(locale: Locale) -> String {
        guard !isEmpty else { return "No cups sold yet, so there is nothing for VoiceOver to read." }
        if isShowingMistake {
            return "VoiceOver reads \(LabelsNotReadText.elements(drinks.count, locale: locale)), one per bar, "
                + "and none of the \(LabelsNotReadText.labels(drawnOrders.count, locale: locale)) on the segments."
        }
        return "VoiceOver reads \(LabelsNotReadText.elements(drawnOrders.count, locale: locale)), "
            + "one per segment, each by the label on its Plot."
    }

    /// What is announced when the toggle changes the elements: what changed, then the headline.
    func changeAnnouncement(locale: Locale) -> String {
        let change = isShowingMistake
            ? "Labels moved onto the bare segments."
            : "Labels moved onto a Plot around each segment."
        return "\(change) \(headline(locale: locale))"
    }

    /// The Audio Graph for the chart as drawn, made from the same drinks, sizes and scale as the bars.
    func chartDescriptor(locale: Locale) -> LabelsNotReadChartDescriptor {
        LabelsNotReadChartDescriptor(
            orders: drawnOrders, drinks: drinks, sizes: sizes, valueDomainTop: valueDomainTop, locale: locale
        )
    }

    /// The snippet names for the current setting: the marks as written, then the chart's new identity.
    var snippetNames: [String] {
        [isShowingMistake ? Self.bareSnippet : Self.plotSnippet, Self.identitySnippet]
    }

    /// The snippets the scaffold shows for the current setting.
    var snippets: [SnippetReference] {
        snippetNames.map { name in
            switch name {
            case Self.bareSnippet: SnippetReference(name: name, title: "The mistake: labels on bare segments")
            case Self.plotSnippet: SnippetReference(name: name, title: "Labels on a Plot around each segment")
            default: SnippetReference(name: name, title: "A new identity when the labels move")
            }
        }
    }
}

/// The Audio Graph for the chart: the same in both settings, since labels on marks or plots never reach it
/// (`accessibility-defaults.md`, *Audio Graph*, "Each point"). One series per size, each point its own
/// segment's cups (`audio-graph.md`). Not tied to the main actor: the accessibility system calls its value
/// description when it chooses.
nonisolated struct LabelsNotReadChartDescriptor: AXChartDescriptorRepresentable {
    /// The segments drawn, none of zero cups.
    let orders: [DrinkOrder]
    /// The drinks with a bar and the sizes that appear, in data order, as the view model has them.
    let drinks: [String]
    let sizes: [String]
    let valueDomainTop: Int
    let locale: Locale

    var summary: String {
        guard !orders.isEmpty else { return "No cups sold yet." }
        let total = orders.map(\.cups).reduce(0, +)
        let perDrink = drinks.map { drink in
            "\(drink) \(CafeWording.cups(orders.filter { $0.drink == drink }.map(\.cups).reduce(0, +), locale: locale))"
        }
        return "\(CafeWording.drinks(drinks.count, locale: locale)) in \(CafeWording.sizes(sizes.count, locale: locale)), "
            + "\(CafeWording.cups(total, locale: locale)) in total. \(perDrink.joined(separator: ", "))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: drinks)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: 0 ... Double(valueDomainTop),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = sizes.map { size in
            AXDataSeriesDescriptor(
                name: size,
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold by drink and size",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}
