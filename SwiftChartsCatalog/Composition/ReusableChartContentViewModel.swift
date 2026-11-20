import Foundation
import Observation

/// The state of "Reusable chart content": whether the reference lines use the type that fixes its own colour.
@Observable
final class ReusableChartContentViewModel {
    /// The café's daily target. Not part of `CafeData`: this screen needs a second line to reuse the type on.
    static let dailyTarget = 250

    let days: [DailySales]
    let target: Int
    /// When on, the lines are drawn with the type that sets its colour inside, so the chart's colours are ignored.
    var isShowingMistake = false

    init(days: [DailySales] = CafeData.harbourSales, target: Int = ReusableChartContentViewModel.dailyTarget) {
        self.days = days
        self.target = target
    }

    var summary: ReusableContentSummary {
        ReusableContentSummary(days: days, target: target)
    }

    /// The chart's message. The same in both states: the mistake changes the lines' colour, not their values.
    var headline: String {
        summary.headline
    }

    var explanation: String {
        if isShowingMistake {
            """
            This version of the type sets foregroundStyle(.red) inside its body. The chart still asks for an orange \
            average and a purple target, and both lines are drawn red: a style set inside a custom type wins over \
            the same style applied from outside. Set inside only what must never change.
            """
        } else {
            """
            ReferenceLine is a custom ChartContent type: a rule and its label, defined once and used twice, for the \
            average and for the target. The bars are a @ChartContentBuilder property, which names part of this one \
            chart without making a type. The type sets no colour inside, so each line takes the colour the chart gives it.
            """
        }
    }

    /// The code behind the chart as it is drawn now.
    var snippets: [SnippetReference] {
        if isShowingMistake {
            [
                SnippetReference(name: "reusable-chart-content-mistake-type", title: "The mistake: a colour set inside the type"),
                SnippetReference(name: "reusable-chart-content-mistake-use", title: "The chart's colours are ignored"),
            ]
        } else {
            [
                SnippetReference(name: "reusable-chart-content-type", title: "A ChartContent type"),
                SnippetReference(name: "reusable-chart-content-builder", title: "A @ChartContentBuilder property"),
                SnippetReference(name: "reusable-chart-content-use", title: "Both in one chart"),
            ]
        }
    }

    /// What to say aloud when the toggle changes the chart, for people who cannot see the lines change colour.
    var changeAnnouncement: String {
        isShowingMistake
            ? "Both lines are now drawn in red. The colours the chart asks for are ignored."
            : "The average line is orange and the target line is purple, as the chart asks."
    }
}
