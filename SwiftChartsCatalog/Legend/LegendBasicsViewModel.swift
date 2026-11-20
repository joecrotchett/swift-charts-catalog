import Charts
import Foundation
import Observation
import SwiftUI

/// Whether the chart shows its automatic legend, or hides it and names each line at its end instead.
nonisolated enum LegendBasicsVisibility: String, CaseIterable, Identifiable {
    case shown = "Shown"
    case hidden = "Hidden"

    var id: Self {
        self
    }
}

/// The side of the chart the legend goes on. Leading and trailing follow the layout direction.
nonisolated enum LegendBasicsPosition: String, CaseIterable, Identifiable {
    case automatic = "Automatic"
    case top = "Top"
    case bottom = "Bottom"
    case leading = "Leading"
    case trailing = "Trailing"

    var id: Self {
        self
    }

    /// The value `chartLegend(position:)` takes.
    var annotationPosition: AnnotationPosition {
        switch self {
        case .automatic: .automatic
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        }
    }

    /// Whether the legend runs along the top or bottom edge, where its alignment is horizontal.
    /// Automatic puts it below the chart.
    var isAboveOrBelow: Bool {
        switch self {
        case .automatic, .top, .bottom: true
        case .leading, .trailing: false
        }
    }
}

/// Where the legend sits along its side: at the start, in the middle or at the end of that side.
nonisolated enum LegendBasicsAlignment: String, CaseIterable, Identifiable {
    case start = "Start"
    case centre = "Centre"
    case end = "End"

    var id: Self {
        self
    }

    /// The value `chartLegend(alignment:)` takes for a legend on the given side: along a top or
    /// bottom legend the alignment is horizontal, along a side legend it is vertical.
    func alignment(for position: LegendBasicsPosition) -> Alignment {
        switch (self, position.isAboveOrBelow) {
        case (.start, true): .leading
        case (.centre, true): .center
        case (.end, true): .trailing
        case (.start, false): .top
        case (.centre, false): .center
        case (.end, false): .bottom
        }
    }
}

/// The state of the "Legend" screen: whether the legend is shown, which side it is on, and how it
/// is aligned there. None of the three changes the data, so none changes the headline.
@Observable
final class LegendBasicsViewModel {
    var visibility = LegendBasicsVisibility.shown
    var position = LegendBasicsPosition.automatic
    var alignment = LegendBasicsAlignment.start

    /// Position and alignment only mean something while the legend is shown.
    var placesLegend: Bool {
        visibility == .shown
    }

    /// Whether the chart names each line at its end, in place of the legend.
    var labelsLineEnds: Bool {
        visibility == .hidden
    }

    /// The value passed to `chartLegend(_:)`: the automatic legend, or none.
    var legendVisibility: Visibility {
        placesLegend ? .automatic : .hidden
    }

    /// The value passed to `chartLegend(position:)`.
    var annotationPosition: AnnotationPosition {
        position.annotationPosition
    }

    /// The value passed to `chartLegend(alignment:)`.
    var legendAlignment: Alignment {
        alignment.alignment(for: position)
    }

    /// The snippets See Code shows for the current setting.
    var snippets: [SnippetReference] {
        Self.snippets(for: visibility)
    }

    static func snippets(for visibility: LegendBasicsVisibility) -> [SnippetReference] {
        let source = SnippetReference(name: "the-legend-source", title: "Where the legend comes from")
        switch visibility {
        case .shown:
            return [source, SnippetReference(name: "the-legend-placement", title: "Position and alignment")]
        case .hidden:
            return [
                source,
                SnippetReference(name: "the-legend-placement", title: "Hiding the legend"),
                SnippetReference(name: "the-legend-end-labels", title: "Names in its place"),
            ]
        }
    }
}

/// One week of one café's line: the stretch of days a single accessibility element describes.
nonisolated struct LegendBasicsPortion: Identifiable, Hashable {
    let store: String
    let days: [DailySales]

    var id: String {
        "\(store)-\(days.first?.day.timeIntervalSinceReferenceDate ?? 0)"
    }
}

/// What the chart says in words: the headline, each portion's label and value, and the Audio Graph's summary.
nonisolated struct LegendBasicsSummary {
    let stores: [StoreSales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// How many days one accessibility element describes.
    static let daysPerPortion = 7

    /// The cafés that have any days to draw.
    var drawnStores: [StoreSales] {
        stores.filter { !$0.days.isEmpty }
    }

    var hasData: Bool {
        !drawnStores.isEmpty
    }

    /// A day written out in the time zone the data was counted in: "28 March" or "March 28".
    func dayText(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).day().month(.wide))
    }

    /// The cups axis as drawn, from zero to the busiest day at either café rounded up to the axis step (282 →
    /// 300): the chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: drawnStores.flatMap { $0.days.map(\.cups) })
    }

    /// The label written over the day the headline names: "Mar 28: 282".
    func calloutText(day: Date, cups: Int) -> String {
        let date = day.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day())
        return "\(date): \(cups.formatted(.number.locale(locale)))"
    }

    /// Every day drawn, in order, written out: the Audio Graph's categories.
    var dayOrder: [Date] {
        Array(Set(drawnStores.flatMap { $0.days.map(\.day) })).sorted()
    }

    /// Every `count`th day from the first, for the date axis: only days the data has.
    func axisDays(every count: Int) -> [Date] {
        stride(from: 0, to: dayOrder.count, by: max(count, 1)).map { dayOrder[$0] }
    }

    /// The last day any café has, and each café's cups on it.
    var lastDay: (day: Date, cups: [(store: String, cups: Int)])? {
        guard let day = dayOrder.last else { return nil }
        let cups = drawnStores.compactMap { store in
            store.days.first { $0.day == day }.map { (store: store.store, cups: $0.cups) }
        }
        return (day, cups)
    }

    /// The chart's message in a sentence, about the end of each line, where the eye and the line
    /// labels land. True on a tie, at zero, and with no data. The legend's settings do not change it.
    var headline: String {
        guard let last = lastDay, let most = last.cups.map(\.cups).max() else {
            return "No cups sold yet this month."
        }
        let leaders = last.cups.filter { $0.cups == most }.map(\.store)
        let cups = CafeWording.cups(most, locale: locale)
        let day = dayText(last.day)
        if last.cups.count == 1 {
            return "On \(day), \(CafeWording.list(leaders)) sold \(cups)."
        }
        if leaders.count == last.cups.count {
            return "On \(day), \(CafeWording.list(leaders)) sold the same: \(cups)."
        }
        return "On \(day), \(CafeWording.list(leaders)) sold the most: \(cups)."
    }

    /// Each café's line in weeks, café by café, so a listener hears one café before the other.
    var portions: [LegendBasicsPortion] {
        drawnStores.flatMap { store in
            stride(from: 0, to: store.days.count, by: Self.daysPerPortion).map { start in
                let end = min(start + Self.daysPerPortion, store.days.count)
                return LegendBasicsPortion(store: store.store, days: Array(store.days[start ..< end]))
            }
        }
    }

    /// "Harbour, 1 March to 7 March": the café first, then the stretch.
    func label(for portion: LegendBasicsPortion) -> String {
        guard let first = portion.days.first?.day, let last = portion.days.last?.day else { return portion.store }
        if first == last {
            return "\(portion.store), \(dayText(first))"
        }
        return "\(portion.store), \(dayText(first)) to \(dayText(last))"
    }

    /// "Starts at 150 cups, ends at 170 cups, lowest 146 cups, highest 199 cups."
    func value(for portion: LegendBasicsPortion) -> String {
        let cups = portion.days.map(\.cups)
        guard let first = cups.first, let last = cups.last, let lowest = cups.min(), let highest = cups.max() else {
            return ""
        }
        return "Starts at \(CafeWording.cups(first, locale: locale)), ends at \(CafeWording.cups(last, locale: locale)), "
            + "lowest \(CafeWording.cups(lowest, locale: locale)), highest \(CafeWording.cups(highest, locale: locale))"
    }

    /// The highest daily count drawn, the top of the descriptor's range.
    var highest: Int {
        drawnStores.flatMap { $0.days.map(\.cups) }.max() ?? 0
    }

    /// Actual values only, café by café.
    var audioGraphSummary: String {
        guard hasData, let first = dayOrder.first, let last = dayOrder.last else {
            return "No cups sold yet this month."
        }
        let opening = "\(CafeWording.cafes(drawnStores.count, locale: locale)), "
            + "\(CafeWording.days(dayOrder.count, locale: locale)) from \(dayText(first)) to \(dayText(last))."
        let perStore = drawnStores.map { store in
            let cups = store.days.map(\.cups)
            return "\(store.store): first day \(CafeWording.cups(cups.first ?? 0, locale: locale)), "
                + "last day \(CafeWording.cups(cups.last ?? 0, locale: locale)), "
                + "highest \(CafeWording.cups(cups.max() ?? 0, locale: locale))."
        }
        return ([opening] + perStore).joined(separator: " ")
    }
}
