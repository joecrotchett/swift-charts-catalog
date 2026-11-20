import Foundation
import Observation

/// The ten places an annotation can go: nine outside the mark, and on top of it.
nonisolated enum MarkLabelsPosition: String, CaseIterable, Identifiable {
    case automatic
    case top
    case bottom
    case leading
    case trailing
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing
    case overlay

    var id: Self {
        self
    }

    /// The name shown in the picker, in words VoiceOver reads well.
    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .top: "Top"
        case .bottom: "Bottom"
        case .leading: "Leading"
        case .trailing: "Trailing"
        case .topLeading: "Top leading"
        case .topTrailing: "Top trailing"
        case .bottomLeading: "Bottom leading"
        case .bottomTrailing: "Bottom trailing"
        case .overlay: "Overlay"
        }
    }

    /// On top of the bar, so the label is drawn inside it.
    var isInside: Bool {
        self == .overlay
    }

    /// Under the bar. A bar that rises from zero has no room under it, so the chart makes some.
    var isBelow: Bool {
        self == .bottom || self == .bottomLeading || self == .bottomTrailing
    }

    /// Off one of the bar's corners, where the alignment has no effect.
    var isCorner: Bool {
        self == .topLeading || self == .topTrailing || self == .bottomLeading || self == .bottomTrailing
    }

    /// Beside the bar or off one of its corners, in the gap it shares with the next bar.
    var isBeside: Bool {
        switch self {
        case .leading, .trailing, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing: true
        case .automatic, .top, .bottom, .overlay: false
        }
    }
}

/// Where along the chosen side the label sits; with `overlay`, the spot inside the bar.
nonisolated enum MarkLabelsAlignment: String, CaseIterable, Identifiable {
    case center
    case leading
    case trailing
    case top
    case bottom
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .center: "Center"
        case .leading: "Leading"
        case .trailing: "Trailing"
        case .top: "Top"
        case .bottom: "Bottom"
        case .topLeading: "Top leading"
        case .topTrailing: "Top trailing"
        case .bottomLeading: "Bottom leading"
        case .bottomTrailing: "Bottom trailing"
        }
    }
}

/// Whether the label sits outside the bar or inside it.
nonisolated enum MarkLabelsPlacement: String, CaseIterable, Identifiable {
    case outside
    case inside

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .outside: "Outside the bar"
        case .inside: "Inside the bar"
        }
    }
}

/// The state of "Labelling a mark": where each bar's value label goes, and the words around the chart.
@Observable
final class MarkLabelsViewModel {
    let sales: [DrinkSales]
    var position: MarkLabelsPosition = .top {
        didSet {
            if !position.isInside { lastOutsidePosition = position }
        }
    }

    var alignment: MarkLabelsAlignment = .center
    /// The outside position to go back to when the label is moved out of the bar again.
    private var lastOutsidePosition: MarkLabelsPosition = .top

    /// The drinks ranked most cups first, as the headline is about the best seller; a tie keeps data order.
    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = MarkLabelsSummary.ranked(sales)
    }

    /// Outside or inside the bar: the same choice as the position picker, made in one step.
    var placement: MarkLabelsPlacement {
        get { position.isInside ? .inside : .outside }
        set { position = newValue == .inside ? .overlay : lastOutsidePosition }
    }

    var summary: MarkLabelsSummary {
        MarkLabelsSummary(sales: sales)
    }

    /// The chart for the Audio Graph, saying where the y axis starts for the current position.
    func descriptor(locale: Locale) -> MarkLabelsChartDescriptor {
        MarkLabelsChartDescriptor(sales: sales, startsBelowZero: position.isBelow, locale: locale)
    }

    /// Nothing sold is no data: the chart is replaced by a placeholder and the controls are disabled.
    var hasData: Bool {
        summary.total > 0
    }

    /// The snippets for the current setting: the annotation, and the label's style for where it sits.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "labelling-a-mark-annotation", title: "A value label on each bar"),
            position.isInside
                ? SnippetReference(name: "labelling-a-mark-label-inside", title: "The label inside the bar")
                : SnippetReference(name: "labelling-a-mark-label-outside", title: "The label outside the bar"),
        ]
    }

    /// Sentences beside the chart, each shown only while it is true of the chart as drawn.
    func notes(isAccessibilityTextSize: Bool) -> [String] {
        guard hasData else { return [] }
        var notes: [String] = []
        if position.isBelow {
            notes.append("A bar that rises from zero has no room under it, so the chart extends its y scale below zero to fit "
                + "the labels, leaving an empty negative band under every bar. Fixing the y scale's domain stops that, "
                + "but the labels are then drawn over the drink names: put the label above or inside the bar.")
        }
        if position.isBeside {
            notes.append("Beside a vertical bar a label has only the gap to the next bar: at larger text sizes it runs into that bar, "
                + "which can cover it, and beside the last bar it can run onto the axis labels.")
        }
        if position.isCorner {
            notes.append("Off a corner the alignment changes nothing: every alignment draws the label in the same place, "
                + "diagonally off the corner. Along an edge it moves the label along that edge.")
        }
        if position.isInside, isAccessibilityTextSize {
            notes.append("At this text size a bar is too narrow to hold its value, so the label inside it is cut short. "
                + "VoiceOver still reads every value, and a position outside the bar shows them.")
        }
        return notes
    }

    /// What to announce when the position changes from `old`. Only a change that moves the scale is announced;
    /// every other position only moves the labels, and the picker speaks its own value.
    func announcement(from old: MarkLabelsPosition, locale: Locale) -> String? {
        guard hasData, old.isBelow != position.isBelow else { return nil }
        let change = position.isBelow
            ? "The labels are under the bars, and the scale now runs below zero to fit them."
            : "The scale starts at zero again."
        return "\(change) \(summary.headline(locale: locale))"
    }
}

/// What the chart says in words: its headline, and the summary the Audio Graph speaks.
nonisolated struct MarkLabelsSummary {
    let sales: [DrinkSales]

    var total: Int {
        sales.map(\.cups).reduce(0, +)
    }

    /// The drinks most cups first; drinks that tie keep their order in the data.
    static func ranked(_ sales: [DrinkSales]) -> [DrinkSales] {
        sales.enumerated()
            .sorted { $0.element.cups != $1.element.cups ? $0.element.cups > $1.element.cups : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Every drink that sold the most, in data order. More than one on a tie; none when nothing sold.
    var bestSellers: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Every drink that sold the fewest, in data order; none when nothing sold.
    var slowestSellers: [DrinkSales] {
        guard let fewest = sales.map(\.cups).min(), total > 0 else { return [] }
        return sales.filter { $0.cups == fewest }
    }

    /// The headline: the best seller and its figure, which is the label on its bar wherever the label sits.
    func headline(locale: Locale) -> String {
        guard let cups = bestSellers.first?.cups else { return "No cups sold yet today." }
        return "\(CafeWording.list(bestSellers.map(\.drink))) sold the most: \(CafeWording.cups(cups, locale: locale))."
    }

    /// Actual values only, with no judgement of them. With the labels under the bars, it also says the
    /// y axis starts below zero, as the chart extends it to fit them.
    func audioGraphSummary(locale: Locale, startsBelowZero: Bool = false) -> String {
        guard let most = bestSellers.first?.cups, let fewest = slowestSellers.first?.cups else {
            return "No cups sold yet today."
        }
        let summary = "\(CafeWording.drinks(sales.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(CafeWording.list(bestSellers.map(\.drink))), \(CafeWording.cups(most, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowestSellers.map(\.drink))), \(CafeWording.cups(fewest, locale: locale))."
        return startsBelowZero
            ? summary + " The labels are under the bars, so the y axis starts below zero, under an empty band."
            : summary
    }
}
