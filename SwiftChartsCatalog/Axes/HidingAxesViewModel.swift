import Foundation
import Observation

/// The state of "Hiding axes": which of the two axes is hidden, and the words and code that follow from it.
@Observable
final class HidingAxesViewModel {
    /// Hides the x axis: here the cups, the value axis of horizontal bars.
    var hidesXAxis = false
    /// Hides the y axis: here the drinks, the category axis.
    var hidesYAxis = false

    /// The code for what is in effect: hiding always, and the replacement for each axis that is hidden.
    var snippets: [SnippetReference] {
        var references = [HidingAxesSnippets.hide]
        if hidesXAxis { references.append(HidingAxesSnippets.values) }
        if hidesYAxis { references.append(HidingAxesSnippets.names) }
        return references
    }

    /// What the x axis gives the reader now, or what took its place.
    var xAxisNote: String {
        hidesXAxis
            ? "Gone: the cups scale, its ticks and its grid lines. Nothing measures the bars now, so each one has its value written at its end."
            : "The cups scale along the bottom, with a grid line at each value to measure the bars against."
    }

    /// What the y axis gives the reader now, or what took its place.
    var yAxisNote: String {
        hidesYAxis
            ? "Gone: the drink names and the lines between the rows. A bar with no name says nothing, so each name is written inside its bar, faded to keep the text readable."
            : "Each drink's name above its bar, and a line between the rows."
    }
}

/// The screen's code regions, by name and title.
enum HidingAxesSnippets {
    static let hide = SnippetReference(name: "hiding-axes-hide", title: "Hiding each axis")
    static let values = SnippetReference(name: "hiding-axes-values", title: "Values in place of the x axis")
    static let names = SnippetReference(name: "hiding-axes-names", title: "Names in place of the y axis")
}
