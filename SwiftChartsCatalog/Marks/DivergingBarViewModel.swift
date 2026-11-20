import Foundation
import Observation

/// The state of the "Diverging bar" screen: whether the rows are sorted, and the words that follow.
@Observable
final class DivergingBarViewModel {
    /// Sorted by change when on; in the order of the data when off.
    var isSorted = true
    let changes: [DrinkChange]

    init(changes: [DrinkChange] = CafeData.drinkChanges) {
        self.changes = changes
    }

    /// The rows in the order the chart draws them, top to bottom.
    var drawnChanges: [DrinkChange] {
        if isSorted {
            // snippet:diverging-bar-sorted
            // The chart keeps the order of the data, so the data is what gets sorted:
            // from the largest fall to the largest rise, the bars form one sweep.
            return changes.sorted { $0.change < $1.change }
            // end
        }
        // snippet:diverging-bar-data-order
        // Unsorted, the rows come in the order of the data and the bars jump from side to side.
        return changes
        // end
    }

    /// The snippets for the chart as it is drawn: the row (the large-text one when the labels sit above
    /// the bars), the axes, then how the rows are ordered.
    func snippets(labelsAboveBars: Bool) -> [SnippetReference] {
        [
            labelsAboveBars
                ? SnippetReference(name: "diverging-bar-large-text", title: "At large text sizes: the label above the bar")
                : SnippetReference(name: "diverging-bar-marks", title: "Bars from zero, labelled by sign"),
            SnippetReference(name: "diverging-bar-axes", title: "No y axis, a signed x axis on top"),
            isSorted
                ? SnippetReference(name: "diverging-bar-sorted", title: "Sorting the data")
                : SnippetReference(name: "diverging-bar-data-order", title: "Data order"),
        ]
    }

    /// What the screen says about the form. The sentence on the labels follows how they are drawn:
    /// beside the bars, or above them at the accessibility text sizes.
    func explanation(labelsAboveBars: Bool) -> String {
        let labels = labelsAboveBars
            ? "At this text size a name and a number no longer fit beside a bar, so both sit above it on one line, and the bar is thinner to make room."
            : "Each bar carries two annotations placed by its sign: the drink's name at its base, on the side it leaves empty, and the signed number beyond its end."
        return "A BarMark given a signed number grows from zero toward it, left or right. \(labels) "
            + "The y axis is hidden because the names are already on the bars' rows, and the x axis moves to the top with signed labels. "
            + "The chart draws rows in the order of the data, so sorting the data is what turns the bars into one sweep."
            + (isSorted ? "" : " \(Self.unsortedNote)")
    }

    /// Said under the chart while the sort is off: the headline still names the largest fall and rise,
    /// and nothing in the order of the bars points to them.
    static let unsortedNote = "With the sort off, the bars are in data order, the weaker form: "
        + "the reader has to hunt for the largest fall and the largest rise."

    func summary(locale: Locale) -> DivergingBarSummary {
        DivergingBarSummary(changes: drawnChanges, locale: locale)
    }

    /// What to say aloud when the order changes: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = isSorted
            ? "Drinks sorted from the largest fall to the largest rise."
            : "Drinks in the order of the data."
        return "\(change) \(summary(locale: locale).headline)"
    }
}

/// What the chart says in words: its headline, each bar's value, and the Audio Graph's summary.
nonisolated struct DivergingBarSummary {
    /// The rows in the order they are drawn.
    let changes: [DrinkChange]
    let locale: Locale

    /// Whether any bar has a length. Bars grow from zero, so rows of zero draw nothing.
    var hasBars: Bool {
        changes.contains { $0.change != 0 }
    }

    /// The change axis as drawn, through zero: the largest fall and rise rounded out to the axis step (-305 and
    /// 212 → -400 to 400). The chart's x scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: changes.map(\.change))
    }

    /// Every drink that rose the most, in drawn order. Empty when none rose.
    var largestRises: [DrinkChange] {
        guard let most = changes.map(\.change).max(), most > 0 else { return [] }
        return changes.filter { $0.change == most }
    }

    /// Every drink that fell the most, in drawn order. Empty when none fell.
    var largestFalls: [DrinkChange] {
        guard let least = changes.map(\.change).min(), least < 0 else { return [] }
        return changes.filter { $0.change == least }
    }

    /// The chart's message. Its figures are the signed numbers written at the ends of two bars.
    var headline: String {
        if changes.isEmpty { return "No changes to show yet." }
        switch (largestFalls.first, largestRises.first) {
        case let (fall?, rise?):
            return "\(names(largestFalls)) fell the most, by \(cupsText(-fall.change)); "
                + "\(names(largestRises)) rose the most, by \(cupsText(rise.change))."
        case let (fall?, nil):
            return "\(names(largestFalls)) fell the most, by \(cupsText(-fall.change)); no drink rose."
        case let (nil, rise?):
            return "\(names(largestRises)) rose the most, by \(cupsText(rise.change)); no drink fell."
        case (nil, nil):
            return "No drink sold more or fewer cups than last month."
        }
    }

    /// Actual values only: how many rose and fell, and the largest of each.
    var audioGraphSummary: String {
        guard hasBars else { return headline }
        let rose = changes.count { $0.change > 0 }
        let fell = changes.count { $0.change < 0 }
        var sentences = ["\(drinksText(changes.count)): \(rose.formatted(.number.locale(locale))) sold more cups than last month, \(fell.formatted(.number.locale(locale))) sold fewer."]
        if let rise = largestRises.first {
            sentences.append("Largest rise: \(names(largestRises)), \(valueText(rise.change)).")
        }
        if let fall = largestFalls.first {
            sentences.append("Largest fall: \(names(largestFalls)), \(valueText(fall.change)).")
        }
        return sentences.joined(separator: " ")
    }

    /// A change said in words, with its unit and direction: "212 cups more than last month".
    func valueText(_ change: Int) -> String {
        if change > 0 { return "\(cupsText(change)) more than last month" }
        if change < 0 { return "\(cupsText(-change)) fewer than last month" }
        return "No change from last month"
    }

    /// A count with its unit, agreeing in number: "1 cup", "305 cups".
    func cupsText(_ count: Int) -> String {
        CafeWording.cups(count, locale: locale)
    }

    func drinksText(_ count: Int) -> String {
        CafeWording.drinks(count, locale: locale)
    }

    func names(_ drinks: [DrinkChange]) -> String {
        drinks.map(\.drink).formatted(.list(type: .and).locale(locale))
    }
}
