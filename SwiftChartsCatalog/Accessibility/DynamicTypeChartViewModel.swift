import Accessibility
import Foundation
import Observation
import SwiftUI

/// The text sizes the screen can force on its chart: none, so the chart follows the device's own
/// size, then from the default up to the largest.
nonisolated enum DynamicTypeChartTextSize: String, CaseIterable, Identifiable, Hashable {
    case device
    case large
    case xxxLarge
    case accessibility1
    case accessibility3
    case accessibility5

    var id: String {
        rawValue
    }

    /// The size forced on the chart; `nil` forces nothing, so the chart follows the device.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .device: nil
        case .large: .large
        case .xxxLarge: .xxxLarge
        case .accessibility1: .accessibility1
        case .accessibility3: .accessibility3
        case .accessibility5: .accessibility5
        }
    }

    /// The name shown in the menu, the one Settings uses for the size.
    var title: String {
        switch self {
        case .device: "This device's size"
        case .large: "Large (the default)"
        case .xxxLarge: "Extra Extra Extra Large"
        case .accessibility1: "Accessibility 1"
        case .accessibility3: "Accessibility 3"
        case .accessibility5: "Accessibility 5"
        }
    }
}

/// The two charts the screen shows.
nonisolated enum DynamicTypeChartKind: String, CaseIterable, Identifiable, Hashable {
    /// The Harbour café's cups a day, stacked by drink over a date axis, with a legend.
    case dates
    /// Today's cups by drink as horizontal bars, the names inside the plot.
    case bars

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .dates: "By day"
        case .bars: "By drink"
        }
    }
}

/// How the date axis is labelled at one text size: how far apart the labels are, and whether they
/// carry the month or only the day.
nonisolated struct DynamicTypeChartDateLabels: Equatable {
    enum Style: Equatable {
        /// "Mar 1".
        case monthAndDay
        /// "1": the month is in the caption above the chart.
        case dayOnly
    }

    let daysPerLabel: Int
    let style: Style

    // snippet:dynamic-type-label-rule
    /// Fewer labels as the text grows, then shorter ones, so they do not collide on a phone.
    static func forSize(_ size: DynamicTypeSize) -> DynamicTypeChartDateLabels {
        if size >= .accessibility4 { return DynamicTypeChartDateLabels(daysPerLabel: 14, style: .dayOnly) }
        if size >= .accessibility1 { return DynamicTypeChartDateLabels(daysPerLabel: 14, style: .monthAndDay) }
        return DynamicTypeChartDateLabels(daysPerLabel: 7, style: .monthAndDay)
    }

    /// The days that get a label: the first day, then every `daysPerLabel` days after it.
    /// An exact list is always drawn in full, so the list itself is what gets thinned.
    func labelledDays(of days: [Date]) -> [Date] {
        days.enumerated().filter { $0.offset.isMultiple(of: daysPerLabel) }.map(\.element)
    }

    // end

    /// The label's format, in the data's time zone and the view's locale.
    func format(locale: Locale) -> Date.FormatStyle {
        let base = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        switch style {
        case .monthAndDay: return base.month(.abbreviated).day()
        case .dayOnly: return base.day()
        }
    }
}

/// Which values a value axis labels at one text size. `nil` keeps the framework's own labels.
nonisolated enum DynamicTypeChartValueLabels {
    /// At the accessibility sizes, at most three: zero, then a round step of 50 that reaches the top in two.
    /// The values are passed exactly, as `.automatic(desiredCount: 3)` gave four on a 0 to 300 axis.
    static func values(for size: DynamicTypeSize, domain: ClosedRange<Double>) -> [Double]? {
        guard size >= .accessibility1 else { return nil }
        let step = max(((domain.upperBound / 2) / 50).rounded(.up) * 50, 50)
        return Array(stride(from: domain.lowerBound, through: domain.upperBound, by: step))
    }
}

// snippet:dynamic-type-unadjusted
/// The mistake: every choice made for the default text size, kept at every size.
nonisolated enum DynamicTypeChartUnadjusted {
    /// A label every week, "Mar 1", however large the text.
    static let dateLabels = DynamicTypeChartDateLabels(daysPerLabel: 7, style: .monthAndDay)
    /// The framework's own value labels.
    static let valueLabels: [Double]? = nil
    /// The framework's legend, which wraps from XXX Large up but still clips or drops a name at the
    /// accessibility sizes, and takes its extra lines from the plot.
    static let legend = Visibility.automatic
    /// The panel's height, however tall the text.
    static let growsWithText = false
}

// end

/// Cups of one drink sold on one day at the Harbour café.
nonisolated struct DynamicTypeChartDrinkDay: Identifiable, Hashable {
    let day: Date
    let drink: String
    let cups: Int

    var id: String {
        "\(day.timeIntervalSinceReferenceDate)-\(drink)"
    }

    /// The sample data has no drinks by day, so each of the Harbour café's days is split across the
    /// drinks in the proportions of today's drink sales: each drink's share rounded down, and what
    /// rounding leaves over given to the first drink, so every day still adds up to its total.
    static func split(_ days: [DailySales], by drinks: [DrinkSales]) -> [DynamicTypeChartDrinkDay] {
        let total = drinks.map(\.cups).reduce(0, +)
        guard total > 0, let first = drinks.first else { return [] }
        return days.flatMap { day in
            let shares = drinks.map { day.cups * $0.cups / total }
            let leftOver = day.cups - shares.reduce(0, +)
            return zip(drinks, shares).map { drink, share in
                DynamicTypeChartDrinkDay(
                    day: day.day, drink: drink.drink, cups: share + (drink.drink == first.drink ? leftOver : 0)
                )
            }
        }
    }
}

/// One week of days: the portion one accessibility element describes.
nonisolated struct DynamicTypeChartWeek: Identifiable, Hashable {
    let start: Date
    let end: Date
    /// Every drink's cups on every day of the week, in data order.
    let rows: [DynamicTypeChartDrinkDay]

    var id: Date {
        start
    }

    /// Midnight at the end of the week's last day, where its last bar ends.
    var endOfLastDay: Date {
        CafeData.calendar.date(byAdding: .day, value: 1, to: end) ?? end
    }

    /// The days cut into weeks of seven, the last one shorter if the days do not divide.
    static func weeks(of rows: [DynamicTypeChartDrinkDay]) -> [DynamicTypeChartWeek] {
        let days = DynamicTypeChartWords.distinctDays(of: rows)
        return stride(from: 0, to: days.count, by: 7).compactMap { first in
            let weekDays = Array(days[first ..< min(first + 7, days.count)])
            guard let start = weekDays.first, let end = weekDays.last else { return nil }
            return DynamicTypeChartWeek(start: start, end: end, rows: rows.filter { weekDays.contains($0.day) })
        }
    }
}

/// Every word the screen writes or speaks about its charts, in one place: the headlines, the captions,
/// the element labels and values, the announcement and the descriptors' text. The locale has no
/// default: the view passes its environment's.
nonisolated struct DynamicTypeChartWords {
    /// Each day's cups by drink, for the stacked bars over dates.
    let drinkDays: [DynamicTypeChartDrinkDay]
    /// Today's cups by drink, ranked, for the horizontal bars.
    let drinks: [DrinkSales]
    let locale: Locale

    // MARK: Dates

    /// Every day in the data, once each, in order.
    var days: [Date] {
        DynamicTypeChartWords.distinctDays(of: drinkDays)
    }

    /// The drinks in the order they first appear: the stacking order, and the legend's.
    var stackedDrinks: [String] {
        drinkDays.reduce(into: [String]()) { names, row in
            if !names.contains(row.drink) { names.append(row.drink) }
        }
    }

    var weeks: [DynamicTypeChartWeek] {
        DynamicTypeChartWeek.weeks(of: drinkDays)
    }

    var dateTotal: Int {
        drinkDays.map(\.cups).reduce(0, +)
    }

    /// Each day's total of every drink, in day order.
    var dailyTotals: [DailySales] {
        days.map { day in DailySales(day: day, cups: drinkDays.filter { $0.day == day }.map(\.cups).reduce(0, +)) }
    }

    /// "March 1": written out, in the data's time zone, as a string first so `Text` cannot move it.
    func spokenDay(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).day())
    }

    /// "Cups a day by drink at the Harbour café, March 2026".
    var datesCaption: String {
        let caption = "Cups a day by drink at the \(CafeWording.harbour) café"
        guard let first = days.first else { return caption }
        let month = first.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).year())
        return "\(caption), \(month)"
    }

    /// Every day that ties for the most cups.
    var busiestDays: [DailySales] {
        guard let most = dailyTotals.map(\.cups).max(), most > 0 else { return [] }
        return dailyTotals.filter { $0.cups == most }
    }

    var datesHeadline: String {
        guard let cups = busiestDays.first?.cups else { return "No cups sold on these days." }
        return "Busiest day: \(CafeWording.list(busiestDays.map { spokenDay($0.day) })), with \(CafeWording.cups(cups, locale: locale))."
    }

    /// "March 1 to March 7".
    func weekLabel(_ week: DynamicTypeChartWeek) -> String {
        "\(spokenDay(week.start)) to \(spokenDay(week.end))"
    }

    /// "Latte 236 cups, Tea 302 cups, …, and Americano 220 cups. 1,203 cups in total."
    func weekValue(_ week: DynamicTypeChartWeek) -> String {
        let perDrink = stackedDrinks.map { drink in
            "\(drink) \(CafeWording.cups(week.rows.filter { $0.drink == drink }.map(\.cups).reduce(0, +), locale: locale))"
        }
        let total = week.rows.map(\.cups).reduce(0, +)
        return "\(CafeWording.list(perDrink)). \(CafeWording.cups(total, locale: locale)) in total."
    }

    /// The value axis's domain, shared by the chart and its descriptor: from zero, as the bars grow from
    /// it, to the next whole fifty above the busiest day.
    var dateValueDomain: ClosedRange<Double> {
        DynamicTypeChartWords.roundedDomain(dailyTotals.map(\.cups))
    }

    var datesDescriptorSummary: String {
        guard let most = busiestDays.first?.cups, let fewest = dailyTotals.map(\.cups).min() else {
            return "No cups sold on these days."
        }
        let quietest = dailyTotals.filter { $0.cups == fewest }.map { spokenDay($0.day) }
        return "\(CafeWording.days(days.count, locale: locale)), \(CafeWording.drinks(stackedDrinks.count, locale: locale)), "
            + "\(CafeWording.cups(dateTotal, locale: locale)) in total. "
            + "Busiest: \(CafeWording.list(busiestDays.map { spokenDay($0.day) })), \(CafeWording.cups(most, locale: locale)). "
            + "Quietest: \(CafeWording.list(quietest)), \(CafeWording.cups(fewest, locale: locale))."
    }

    static func distinctDays(of rows: [DynamicTypeChartDrinkDay]) -> [Date] {
        Array(Set(rows.map(\.day))).sorted()
    }

    // MARK: Bars

    var barTotal: Int {
        drinks.map(\.cups).reduce(0, +)
    }

    var barsCaption: String {
        "Cups sold today at the \(CafeWording.harbour) café"
    }

    var bestSellers: [DrinkSales] {
        guard let most = drinks.map(\.cups).max(), most > 0 else { return [] }
        return drinks.filter { $0.cups == most }
    }

    var barsHeadline: String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    func barLabel(_ drink: DrinkSales) -> String {
        drink.drink
    }

    func barValue(_ drink: DrinkSales) -> String {
        CafeWording.cups(drink.cups, locale: locale)
    }

    /// The value axis's domain, shared by the chart and its descriptor: from zero, as bars grow from it,
    /// to the next whole fifty.
    var barValueDomain: ClosedRange<Double> {
        DynamicTypeChartWords.roundedDomain(drinks.map(\.cups))
    }

    var barsDescriptorSummary: String {
        guard let most = bestSellers.first?.cups,
              let fewest = drinks.map(\.cups).min() else { return "No cups sold yet today." }
        let slowest = drinks.filter { $0.cups == fewest }.map(\.drink)
        return "\(CafeWording.drinks(drinks.count, locale: locale)), \(CafeWording.cups(barTotal, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowest)), \(CafeWording.cups(fewest, locale: locale))."
    }

    // MARK: Both

    func headline(for kind: DynamicTypeChartKind) -> String {
        switch kind {
        case .dates: datesHeadline
        case .bars: barsHeadline
        }
    }

    func caption(for kind: DynamicTypeChartKind) -> String {
        switch kind {
        case .dates: datesCaption
        case .bars: barsCaption
        }
    }

    /// Whether a chart has nothing to draw: both are bars, which grow from zero, so nothing sold means
    /// no bars, and a placeholder takes the chart's place.
    func isEmpty(for kind: DynamicTypeChartKind) -> Bool {
        switch kind {
        case .dates: dateTotal == 0
        case .bars: barTotal == 0
        }
    }

    /// What the placeholder says under its title, which the headline does not already say.
    func placeholderDescription(for kind: DynamicTypeChartKind) -> String {
        switch kind {
        case .dates: "Each day's cups appear here, stacked by drink, once the café has sold some."
        case .bars: "Each drink's cups appear here as a bar, once the café has sold some."
        }
    }

    /// Said when the chart switches: what changed, then the headline. With nothing to draw, what
    /// changed is that the placeholder shows.
    func announcement(for kind: DynamicTypeChartKind) -> String {
        if isEmpty(for: kind) {
            return "No sales yet, so no chart is shown. \(headline(for: kind))"
        }
        return switch kind {
        case .dates: "Showing cups a day, stacked by drink. \(datesHeadline)"
        case .bars: "Showing horizontal bars of cups by drink. \(barsHeadline)"
        }
    }

    /// From zero to the next whole fifty above the highest value.
    static func roundedDomain(_ values: [Int]) -> ClosedRange<Double> {
        let step = 50.0
        let upper = (Double(max(values.max() ?? 0, 0)) / step).rounded(.up) * step
        return 0 ... max(upper, step)
    }
}

/// The screen's state: which chart, at which text size, and whether the adjustments are left out.
@Observable
final class DynamicTypeChartViewModel {
    var textSize: DynamicTypeChartTextSize = .device
    var kind: DynamicTypeChartKind = .dates
    var isShowingMistake = false

    let drinkDays: [DynamicTypeChartDrinkDay]
    let drinks: [DrinkSales]

    init(days: [DailySales] = CafeData.harbourSales, drinks: [DrinkSales] = CafeData.drinkSales) {
        // Stacked in data order, so the stack and the legend agree.
        drinkDays = DynamicTypeChartDrinkDay.split(days, by: drinks)
        // Ranked, as the headline says which sold the most.
        self.drinks = drinks.sorted { $0.cups > $1.cups }
    }

    func words(locale: Locale) -> DynamicTypeChartWords {
        DynamicTypeChartWords(drinkDays: drinkDays, drinks: drinks, locale: locale)
    }

    /// Whether the current chart has nothing to draw, so a placeholder takes its place.
    var isEmpty: Bool {
        switch kind {
        // Both charts are bars, which grow from zero: with nothing sold there is nothing to draw.
        case .dates: drinkDays.map(\.cups).reduce(0, +) == 0
        case .bars: drinks.map(\.cups).reduce(0, +) == 0
        }
    }

    /// What is forced on the chart: nothing at the device's size, so the kit leaves the device's in place.
    var chartEnvironment: ChartEnvironment {
        ChartEnvironment(dynamicTypeSize: textSize.dynamicTypeSize)
    }

    /// The code the screen shows for the current chart and state.
    var snippets: [SnippetReference] {
        switch (kind, isShowingMistake) {
        case (.dates, false):
            [
                SnippetReference(name: "dynamic-type-dates-chart", title: "The chart, its axes following the text size"),
                SnippetReference(name: "dynamic-type-label-rule", title: "Fewer, shorter date labels"),
                SnippetReference(name: "dynamic-type-legend", title: "A legend that wraps"),
                SnippetReference(name: "dynamic-type-height", title: "A height that grows with the text"),
            ]
        case (.dates, true):
            [
                SnippetReference(name: "dynamic-type-dates-chart", title: "The chart"),
                SnippetReference(name: "dynamic-type-unadjusted", title: "The mistake: the default size's choices kept"),
            ]
        case (.bars, false):
            [
                SnippetReference(name: "dynamic-type-bars-chart", title: "Bars with their names inside the plot"),
                SnippetReference(name: "dynamic-type-bar-height", title: "Rows that grow with their names"),
            ]
        case (.bars, true):
            [
                SnippetReference(name: "dynamic-type-bars-chart", title: "Bars with their names inside the plot"),
                SnippetReference(name: "dynamic-type-unadjusted", title: "The mistake: the default size's choices kept"),
            ]
        }
    }
}

/// The Audio Graph for the stacked bars: a title, a summary, every day written out, and each drink a
/// series, each point its own segment's cups.
nonisolated struct DynamicTypeChartDatesDescriptor: AXChartDescriptorRepresentable {
    let words: DynamicTypeChartWords

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = words.locale
        let days = words.days
        return AXChartDescriptor(
            title: words.datesCaption,
            summary: words.datesDescriptorSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: days.map(words.spokenDay)),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle, range: words.dateValueDomain, gridlinePositions: []
            ) { CafeWording.count($0, locale: locale) },
            additionalAxes: [],
            series: words.stackedDrinks.map { drink in
                AXDataSeriesDescriptor(
                    name: drink,
                    isContinuous: false,
                    dataPoints: words.drinkDays.filter { $0.drink == drink }.map {
                        AXDataPoint(x: words.spokenDay($0.day), y: Double($0.cups))
                    }
                )
            }
        )
    }
}

/// The Audio Graph for the bars: drinks on the descriptor's x axis, as categories always are.
nonisolated struct DynamicTypeChartBarsDescriptor: AXChartDescriptorRepresentable {
    let words: DynamicTypeChartWords

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = words.locale
        return AXChartDescriptor(
            title: "\(words.barsCaption), by drink",
            summary: words.barsDescriptorSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: words.drinks.map(\.drink)),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle, range: words.barValueDomain, gridlinePositions: []
            ) { CafeWording.count($0, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: false,
                dataPoints: words.drinks.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )]
        )
    }
}
