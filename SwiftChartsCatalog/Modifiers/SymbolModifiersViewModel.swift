import Charts
import Foundation
import Observation

/// What each point is drawn as: one of the built-in shapes, or a SwiftUI view.
nonisolated enum SymbolModifiersSymbol: String, CaseIterable, Identifiable, Hashable {
    case circle
    case square
    case triangle
    case diamond
    case view

    var id: String {
        rawValue
    }

    /// The name on the picker.
    var title: String {
        switch self {
        case .circle: "Circle"
        case .square: "Square"
        case .triangle: "Triangle"
        case .diamond: "Diamond"
        case .view: "View"
        }
    }

    /// The built-in shape for `symbol(_:)`, or nil when a view is the symbol.
    var shape: BasicChartSymbolShape? {
        switch self {
        case .circle: .circle
        case .square: .square
        case .triangle: .triangle
        case .diamond: .diamond
        case .view: nil
        }
    }
}

/// The screen's state: which symbol the points use and how large they are.
@Observable
final class SymbolModifiersViewModel {
    /// The sizes the slider offers, as an area in square points.
    static let areaRange: ClosedRange<Double> = 25 ... 400
    static let areaStep: Double = 25

    var symbol: SymbolModifiersSymbol = .circle
    /// The symbol's size as an area in square points, the unit `symbolSize(_:)` takes.
    var area: Double = 100

    /// The snippet for the modifier the picker has chosen.
    var snippets: [SnippetReference] {
        Self.snippets(for: symbol)
    }

    static func snippets(for symbol: SymbolModifiersSymbol) -> [SnippetReference] {
        switch symbol {
        case .view:
            [SnippetReference(name: "symbol-modifiers-view", title: "symbol { }, sized by the view's frame")]
        default:
            [SnippetReference(name: "symbol-modifiers-shape", title: "symbol(_:) and symbolSize(_:)")]
        }
    }

    /// The size beside the slider: "100 pt²".
    func areaText(locale: Locale) -> String {
        "\(Int(area).formatted(.number.locale(locale))) pt²"
    }

    /// The size as VoiceOver says it: "100 square points".
    func spokenArea(locale: Locale) -> String {
        SymbolModifiersWording.squarePoints(Int(area), locale: locale)
    }
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum SymbolModifiersWording {
    /// "25 square points", "1 square point": agreeing in number through the inflected form.
    static func squarePoints(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) square point](inflect: true)", locale: locale).characters)
    }
}

/// What the chart says in words: the headline, each point's label and value, and the Audio Graph's summary.
nonisolated struct SymbolModifiersSummary {
    /// The days drawn, in order.
    let days: [DailySales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// The Harbour café's first two weeks: enough room between points for a symbol to grow.
    static let sampleDays = Array(CafeData.harbourSales.prefix(14))

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (240 → 300): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    /// The label written over a day the headline names: "Mar 14: 240".
    func calloutText(for day: DailySales) -> String {
        let date = day.day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day()
        )
        return "\(date): \(day.cups.formatted(.number.locale(locale)))"
    }

    /// Every day with the most cups, in order. More than one on a tie; none when nothing sold.
    var busiestDays: [DailySales] {
        guard let most = days.map(\.cups).max(), most > 0 else { return [] }
        return days.filter { $0.cups == most }
    }

    /// The chart's message: the highest point, which a reader can find at the top of the line.
    /// True on a tie, for days with no sales, and for no days at all.
    var headline: String {
        guard !days.isEmpty else { return "No sales yet." }
        guard let busiest = busiestDays.first else {
            return "No cups sold in these \(CafeWording.days(days.count, locale: locale))."
        }
        let cups = CafeWording.cups(busiest.cups, locale: locale)
        if busiestDays.count == 1 {
            return "The busiest day was \(spokenDate(busiest.day)), with \(cups)."
        }
        return "The busiest days were \(dates(busiestDays)), with \(cups) each."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let first = days.first, let last = days.last else { return "No sales yet." }
        var summary = "\(CafeWording.days(days.count, locale: locale)). "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), last day \(CafeWording.cups(last.cups, locale: locale))."
        if let busiest = busiestDays.first {
            summary += " Most: \(CafeWording.cups(busiest.cups, locale: locale)), on \(dates(busiestDays))."
        }
        return summary
    }

    /// The point's context first: "Sunday, March 1".
    func elementLabel(for day: DailySales) -> String {
        spokenDate(day.day)
    }

    /// The point's value with its unit: "150 cups".
    func elementValue(for day: DailySales) -> String {
        CafeWording.cups(day.cups, locale: locale)
    }

    /// A day written out in the calendar the sample dates were made in, so a device west of UTC
    /// does not name the day before: "Sunday, March 1".
    func spokenDate(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                .weekday(.wide).month(.wide).day()
        )
    }

    /// "Saturday, March 7 and Saturday, March 14".
    private func dates(_ days: [DailySales]) -> String {
        CafeWording.list(days.map { spokenDate($0.day) })
    }
}
