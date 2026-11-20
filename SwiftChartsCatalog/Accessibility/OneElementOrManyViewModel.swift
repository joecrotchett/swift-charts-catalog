import Accessibility
import Foundation
import Observation
import SwiftUI

/// How much of the chart one accessibility element covers, each shown on a chart whose purpose suits it.
nonisolated enum OneElementOrManyChoice: String, CaseIterable, Identifiable, Hashable {
    /// Exact values per item: one element per bar.
    case eachMark
    /// The overall shape: one element per meaningful part of the day, each summarised with units.
    case eachPortion
    /// A small preview: one element for the whole chart, with a succinct description.
    case wholeChart

    var id: String {
        rawValue
    }

    /// The picker's segment.
    var title: String {
        switch self {
        case .eachMark: "Each mark"
        case .eachPortion: "Each portion"
        case .wholeChart: "Whole chart"
        }
    }

    /// What the choice is, in the words of the announcement made when it is picked.
    var spokenName: String {
        switch self {
        case .eachMark: "One element per mark"
        case .eachPortion: "One element per portion"
        case .wholeChart: "One element for the whole chart"
        }
    }
}

/// One half hour of orders, placed on a time-of-day axis in hours since midnight.
nonisolated struct OneElementOrManyHalfHour: Identifiable, Hashable {
    /// Where the half hour starts, in hours since midnight: 8.5 for 8:30 am.
    let hour: Double
    let orders: Int

    var id: Double {
        hour
    }
}

/// A meaningful portion of the day: one named service period, holding the half hours that start in it.
/// Each is one accessibility element on the portion chart.
nonisolated struct OneElementOrManyPortion: Identifiable, Hashable {
    /// Its place in the day, from 0; every other portion is shaded.
    let index: Int
    let name: String
    let startHour: Double
    let endHour: Double
    let halfHours: [OneElementOrManyHalfHour]

    var id: String {
        name
    }

    var total: Int {
        halfHours.map(\.orders).reduce(0, +)
    }

    var isShaded: Bool {
        index.isMultiple(of: 2)
    }

    /// The day cut into its service periods. A period with no half hours in it is left out: it has no marks
    /// for an element to cover. No data gives no portions.
    static func make(halfHours: [OneElementOrManyHalfHour], periods: [ServicePeriod]) -> [OneElementOrManyPortion] {
        guard !halfHours.isEmpty else { return [] }
        return periods
            .map { period in
                let start = OneElementOrManyData.hour(of: period.start)
                let end = OneElementOrManyData.hour(of: period.end)
                return (period.name, start, end, halfHours.filter { $0.hour >= start && $0.hour < end })
            }
            .filter { !$0.3.isEmpty }
            .enumerated()
            .map { index, period in
                OneElementOrManyPortion(index: index, name: period.0, startHour: period.1, endHour: period.2, halfHours: period.3)
            }
    }
}

/// The data the screen draws: drinks for the chart of exact values, half hours of orders for the chart of
/// a shape and its preview, and the named parts of the day that cut the shape into portions.
nonisolated struct OneElementOrManyData: Hashable {
    var drinkSales = CafeData.drinkSales
    var halfHourOrders = CafeData.halfHourOrders
    var periods = CafeData.servicePeriods

    /// Hours since midnight on the sample day, in the data's UTC calendar, for a time-of-day axis.
    static func hour(of date: Date) -> Double {
        date.timeIntervalSince(CafeData.firstDay) / 3600
    }
}

/// One accessibility element as VoiceOver reads it.
nonisolated struct OneElementOrManyElement: Identifiable, Hashable {
    let label: String
    let value: String
    /// The trait VoiceOver adds after the value, such as "Button"; `nil` for none.
    var trait: String?

    var id: String {
        label
    }
}

/// What the Audio Graph is given for one choice: everything its chart descriptor holds, in plain values.
/// The descriptor is made from this, so what the screen shows is what the descriptor says.
nonisolated struct OneElementOrManyAudioGraph: Hashable {
    /// Which noun a value is said with.
    enum Unit: Hashable {
        case cups
        case orders
    }

    struct Point: Hashable {
        let category: String
        let value: Double
    }

    let title: String
    let summary: String
    let xAxisTitle: String
    let categories: [String]
    let yAxisTitle: String
    let yRange: ClosedRange<Double>
    let seriesName: String
    let isContinuous: Bool
    let unit: Unit
    let points: [Point]

    /// How the Audio Graph says a value: "164 cups", "1 order"; "" for a value that is not finite.
    static func valueDescription(_ value: Double, unit: Unit, locale: Locale) -> String {
        switch unit {
        case .cups: CafeWording.count(value, locale: locale)
        case .orders: CafeWording.count(value, locale: locale, as: CafeWording.orders(_:locale:))
        }
    }
}

// snippet:one-element-or-many-descriptor
/// The chart descriptor for the per-mark and per-portion charts. Labels on Plots change only the elements,
/// so the Audio Graph's data, units included, comes from here. Not tied to the main actor: the
/// accessibility system calls its value description when it chooses.
nonisolated struct OneElementOrManyChartDescriptor: AXChartDescriptorRepresentable {
    let graph: OneElementOrManyAudioGraph
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let unit = graph.unit
        let locale = locale
        return AXChartDescriptor(
            title: graph.title,
            summary: graph.summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: graph.xAxisTitle, categoryOrder: graph.categories),
            yAxis: AXNumericDataAxisDescriptor(title: graph.yAxisTitle, range: graph.yRange, gridlinePositions: []) { value in
                OneElementOrManyAudioGraph.valueDescription(value, unit: unit, locale: locale)
            },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: graph.seriesName,
                isContinuous: graph.isContinuous,
                dataPoints: graph.points.map { AXDataPoint(x: $0.category, y: $0.value) }
            )]
        )
    }
}

// end

/// Every word the screen speaks or shows about its charts, in one table: the headlines, each element's label
/// and value, and the Audio Graph's data, for each choice. Every element and descriptor here matches what was
/// read on the iPhone 17 simulator, iOS 27 (`Docs/field-notes/epic-10/wave-2-dumps/oem-*.txt`); a line that
/// differs from a later reading is replaced here and nowhere else.
nonisolated struct OneElementOrManySpokenText {
    let data: OneElementOrManyData
    /// The locale every number, count and time is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The value axis of the bars runs to the next multiple of this, and of the orders line to the next of
    /// `ordersStep`, so the descriptor's range is the drawn scale.
    static let cupsStep = 50
    static let ordersStep = 20

    // MARK: Data

    /// Drinks ranked from most to fewest cups, as the bars are drawn.
    var drinks: [DrinkSales] {
        data.drinkSales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    var cupsTotal: Int {
        data.drinkSales.map(\.cups).reduce(0, +)
    }

    var halfHours: [OneElementOrManyHalfHour] {
        data.halfHourOrders.map { OneElementOrManyHalfHour(hour: OneElementOrManyData.hour(of: $0.start), orders: $0.orders) }
    }

    var portions: [OneElementOrManyPortion] {
        OneElementOrManyPortion.make(halfHours: halfHours, periods: data.periods)
    }

    var ordersTotal: Int {
        data.halfHourOrders.map(\.orders).reduce(0, +)
    }

    /// The top of the bars' value axis: the most cups rounded up to a step, and one step for no cups.
    var cupsTop: Int {
        Self.roundedUp(data.drinkSales.map(\.cups).max() ?? 0, step: Self.cupsStep)
    }

    /// The top of the orders line's value axis.
    var ordersTop: Int {
        Self.roundedUp(data.halfHourOrders.map(\.orders).max() ?? 0, step: Self.ordersStep)
    }

    static func roundedUp(_ value: Int, step: Int) -> Int {
        max(step, (value + step - 1) / step * step)
    }

    /// Whether the choice draws a chart, or a placeholder. Bars of no cups draw nothing; a line of zero
    /// orders is still drawn, along zero. The portions need a part of the day that holds a half hour, or the
    /// chart would have marks and no element over them.
    func drawsChart(_ choice: OneElementOrManyChoice) -> Bool {
        switch choice {
        case .eachMark: cupsTotal > 0
        case .eachPortion: !data.halfHourOrders.isEmpty && !portions.isEmpty
        case .wholeChart: !data.halfHourOrders.isEmpty
        }
    }

    // MARK: Headlines

    func headline(_ choice: OneElementOrManyChoice) -> String {
        switch choice {
        case .eachMark: markHeadline
        case .eachPortion: portionHeadline
        case .wholeChart: wholeHeadline
        }
    }

    /// Every drink that sold the most, in rank order; none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = drinks.first?.cups, most > 0 else { return [] }
        return drinks.filter { $0.cups == most }
    }

    var slowestSellers: [DrinkSales] {
        guard let fewest = drinks.last?.cups, cupsTotal > 0 else { return [] }
        return drinks.filter { $0.cups == fewest }
    }

    var markHeadline: String {
        guard let most = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most today: \(CafeWording.cups(most, locale: locale))."
    }

    /// The half hours with the most orders, in order of the day; none when there were no orders.
    var busiestHalfHours: [OneElementOrManyHalfHour] {
        guard let most = halfHours.map(\.orders).max(), most > 0 else { return [] }
        return halfHours.filter { $0.orders == most }
    }

    var quietestHalfHours: [OneElementOrManyHalfHour] {
        guard let fewest = halfHours.map(\.orders).min(), ordersTotal > 0 else { return [] }
        return halfHours.filter { $0.orders == fewest }
    }

    var portionHeadline: String {
        let busiest = busiestHalfHours
        guard let first = busiest.first else { return "No orders yet today." }
        guard !portions.isEmpty else { return "No orders fall in a named part of the day." }
        let count = CafeWording.orders(first.orders, locale: locale)
        if busiest.count == 1 {
            let portion = portions.first { $0.halfHours.contains(first) }
            let within = portion.map { ", in the \($0.name)" } ?? ""
            return "The busiest half hour started at \(time(first.hour))\(within): \(count)."
        }
        return "The busiest half hours started at \(CafeWording.list(busiest.map { time($0.hour) })): \(count) each."
    }

    var wholeHeadline: String {
        ordersTotal > 0 ? "\(CafeWording.orders(ordersTotal, locale: locale)) today." : "No orders yet today."
    }

    /// Said after the choice when it changes: what changed, then the headline.
    func announcement(_ choice: OneElementOrManyChoice) -> String {
        "\(choice.spokenName). \(headline(choice))"
    }

    // MARK: Elements

    /// What VoiceOver reads, element by element, for each choice. With no chart drawn, nothing.
    func elements(_ choice: OneElementOrManyChoice) -> [OneElementOrManyElement] {
        guard drawsChart(choice) else { return [] }
        switch choice {
        case .eachMark:
            return drinks.map { OneElementOrManyElement(label: markLabel($0), value: markValue($0)) }
        case .eachPortion:
            return portions.map { OneElementOrManyElement(label: portionLabel($0), value: portionValue($0)) }
        case .wholeChart:
            return [OneElementOrManyElement(label: previewLabel, value: previewValue, trait: "Button")]
        }
    }

    func markLabel(_ sale: DrinkSales) -> String {
        sale.drink
    }

    func markValue(_ sale: DrinkSales) -> String {
        CafeWording.cups(sale.cups, locale: locale)
    }

    /// Context first: the part of the day, then its clock times. "Morning rush, 7:30 AM to 9:00 AM".
    func portionLabel(_ portion: OneElementOrManyPortion) -> String {
        "\(portion.name), \(time(portion.startHour)) to \(time(portion.endHour))"
    }

    /// Actual values with their units: "150 orders in total; first half hour 46 orders, last 45 orders,
    /// highest 57 orders at 8:00 AM".
    func portionValue(_ portion: OneElementOrManyPortion) -> String {
        guard portion.total > 0, let first = portion.halfHours.first, let last = portion.halfHours.last,
              let highest = portion.halfHours.max(by: { $0.orders < $1.orders })
        else { return "\(CafeWording.orders(portion.total, locale: locale)) in total." }
        // `max(by:)` keeps the last of a tie; the first, in order of the day, is the one named.
        let peak = portion.halfHours.first { $0.orders == highest.orders } ?? highest
        return "\(CafeWording.orders(portion.total, locale: locale)) in total; "
            + "first half hour \(CafeWording.orders(first.orders, locale: locale)), "
            + "last \(CafeWording.orders(last.orders, locale: locale)), "
            + "highest \(CafeWording.orders(peak.orders, locale: locale)) at \(time(peak.hour))."
    }

    /// The preview's one element: a succinct description of the whole chart.
    var previewLabel: String {
        "Orders today, by half hour"
    }

    var previewValue: String {
        "\(CafeWording.orders(ordersTotal, locale: locale)) in total"
    }

    // MARK: Audio Graph

    /// What the Audio Graph gets for the choice; `nil` when it has none.
    func audioGraph(_ choice: OneElementOrManyChoice) -> OneElementOrManyAudioGraph? {
        guard drawsChart(choice) else { return nil }
        switch choice {
        case .eachMark: return markGraph
        case .eachPortion: return portionGraph
        case .wholeChart: return nil
        }
    }

    /// What the choice does to the Audio Graph, in a sentence or two.
    func audioGraphEffect(_ choice: OneElementOrManyChoice) -> String {
        switch choice {
        case .eachMark:
            "A labelled Plot changes the elements only. The descriptor gives the Audio Graph the same point per drink, said with its unit."
        case .eachPortion:
            "The elements are \(Self.portionCount(portions.count, locale: locale)), but the Audio Graph still gets a point for every half hour: "
                + "labels on Plots change the elements only, and the descriptor describes the whole line."
        case .wholeChart:
            "None. Ignoring the chart's children makes one element and removes its Audio Graph: right for a preview, "
                + "wrong for a chart people study."
        }
    }

    var markGraph: OneElementOrManyAudioGraph {
        OneElementOrManyAudioGraph(
            title: "Cups sold today, by drink",
            summary: markSummary,
            xAxisTitle: CafeWording.drink,
            categories: drinks.map(\.drink),
            yAxisTitle: CafeWording.cupsAxisTitle,
            yRange: 0 ... Double(cupsTop),
            seriesName: CafeWording.harbour,
            isContinuous: false,
            unit: .cups,
            points: drinks.map { .init(category: $0.drink, value: Double($0.cups)) }
        )
    }

    /// Actual values only, with no judgement of them.
    var markSummary: String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        return "\(CafeWording.drinks(drinks.count, locale: locale)), \(CafeWording.cups(cupsTotal, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
    }

    var portionGraph: OneElementOrManyAudioGraph {
        OneElementOrManyAudioGraph(
            title: "Orders by half hour today",
            summary: portionSummary,
            xAxisTitle: TimeOfDayWording.timeOfDay,
            categories: halfHours.map { time($0.hour) },
            yAxisTitle: CafeWording.orders,
            yRange: 0 ... Double(ordersTop),
            seriesName: CafeWording.orders,
            isContinuous: true,
            unit: .orders,
            points: halfHours.map { .init(category: time($0.hour), value: Double($0.orders)) }
        )
    }

    /// The parts of the day with the most orders between them, in order of the day; none with no orders.
    var busiestPortions: [OneElementOrManyPortion] {
        guard let most = portions.map(\.total).max(), most > 0 else { return [] }
        return portions.filter { $0.total == most }
    }

    var portionSummary: String {
        guard let first = halfHours.first, let last = halfHours.last else { return "No orders yet today." }
        let span = "Every half hour from \(time(first.hour)) to \(time(last.hour + 0.5))"
        guard let most = busiestHalfHours.first?.orders, let fewest = quietestHalfHours.first?.orders,
              let busiestPart = busiestPortions.first?.total
        else { return "\(span): \(CafeWording.orders(0, locale: locale)) in total." }
        return "\(span): \(CafeWording.orders(ordersTotal, locale: locale)) in total. "
            + "Most: \(CafeWording.list(busiestHalfHours.map { time($0.hour) })), \(CafeWording.orders(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(quietestHalfHours.map { time($0.hour) })), \(CafeWording.orders(fewest, locale: locale)). "
            + "Busiest part of the day: \(CafeWording.list(busiestPortions.map(\.name))), \(CafeWording.orders(busiestPart, locale: locale))."
    }

    // MARK: Words

    /// A clock time in the data's UTC calendar, in the locale's own form: "8:00 AM".
    func time(_ hour: Double) -> String {
        TimeOfDayWording.time(hour: hour, locale: locale)
    }

    /// "1 portion", "6 portions". `CafeWording` has no such count, so it is added here, in the same form.
    static func portionCount(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) portion](inflect: true)", locale: locale).characters)
    }
}

/// The screen's state: which choice is shown. Everything it says comes from `OneElementOrManySpokenText`.
@Observable
final class OneElementOrManyViewModel {
    var choice: OneElementOrManyChoice = .eachMark
    let data: OneElementOrManyData

    init(data: OneElementOrManyData = OneElementOrManyData()) {
        self.data = data
    }

    /// The table of everything spoken and shown, in the view's locale.
    func text(locale: Locale) -> OneElementOrManySpokenText {
        OneElementOrManySpokenText(data: data, locale: locale)
    }

    /// The picker is disabled only when no choice has anything to draw.
    func hasAnythingToDraw(locale: Locale) -> Bool {
        let text = text(locale: locale)
        return OneElementOrManyChoice.allCases.contains(where: text.drawsChart)
    }

    /// The preview opens the fuller chart of the same orders.
    func openFullChart() {
        choice = .eachPortion
    }

    /// The code for the current choice.
    var snippets: [SnippetReference] {
        Self.snippets(for: choice)
    }

    static func snippets(for choice: OneElementOrManyChoice) -> [SnippetReference] {
        switch choice {
        case .eachMark: [allSnippets[0], allSnippets[3]]
        case .eachPortion: [allSnippets[1], allSnippets[3]]
        case .wholeChart: [allSnippets[2]]
        }
    }

    /// Every snippet the screen shows, for its registration.
    static let allSnippets = [
        SnippetReference(name: "one-element-or-many-each-mark", title: "One element per mark"),
        SnippetReference(name: "one-element-or-many-each-portion", title: "One element per portion"),
        SnippetReference(name: "one-element-or-many-whole-chart", title: "One element for the whole chart"),
        SnippetReference(name: "one-element-or-many-descriptor", title: "The chart descriptor"),
    ]
}
