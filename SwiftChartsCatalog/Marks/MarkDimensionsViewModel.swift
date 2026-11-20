import Charts
import Foundation
import Observation

/// The state behind "Mark dimensions": which `MarkDimension` case sizes the bars, its amount,
/// and how many days are drawn.
@Observable
final class MarkDimensionsViewModel {
    /// The four cases of `MarkDimension`.
    enum Kind: String, CaseIterable, Identifiable {
        case automatic, ratio, inset, fixed

        var id: String {
            rawValue
        }

        var title: String {
            switch self {
            case .automatic: "Automatic"
            case .ratio: "Ratio"
            case .inset: "Inset"
            case .fixed: "Fixed"
            }
        }

        /// What the slider sets for this case.
        var amountTitle: String {
            switch self {
            case .automatic: "Amount"
            case .ratio: "Fraction of the step"
            case .inset: "Taken off each side"
            case .fixed: "Width"
            }
        }

        /// The slider's range, or nil for the case that has no amount.
        var amountRange: ClosedRange<Double>? {
            switch self {
            case .automatic: nil
            case .ratio: 0.1 ... 1
            case .inset: 0 ... 3
            case .fixed: 1 ... 24
            }
        }

        var amountStep: Double {
            switch self {
            case .automatic: 1
            case .ratio: 0.05
            case .inset: 0.5
            case .fixed: 1
            }
        }

        /// What the case does as bars are added. True whatever the amount.
        var note: String {
            switch self {
            case .automatic:
                "The default for the mark: the framework chooses the width."
            case .ratio:
                "A fraction of each day's step. Bars and gaps shrink together as bars are added; at 1 neighbours touch."
            case .inset:
                "The step less this many points on each side. The gaps stay the same width as bars are added, and the bars take what is left."
            case .fixed:
                "The same width in points however many bars there are. Add bars and the gaps close, then the bars run into each other, and the first and last are cut off at the plot's edge."
            }
        }

        var snippet: SnippetReference {
            switch self {
            case .automatic: SnippetReference(name: "mark-dimensions-automatic", title: "Automatic")
            case .ratio: SnippetReference(name: "mark-dimensions-ratio", title: "A ratio of the step")
            case .inset: SnippetReference(name: "mark-dimensions-inset", title: "An inset from the step")
            case .fixed: SnippetReference(name: "mark-dimensions-fixed", title: "A fixed width")
            }
        }
    }

    static let chartSnippet = SnippetReference(name: "mark-dimensions-chart", title: "The width of each bar")
    /// Every snippet the screen can show, for registration.
    static let allSnippets = [chartSnippet] + Kind.allCases.map(\.snippet)
    static let dayCountRange = 3 ... 28

    let sales: [DailySales]
    var kind = Kind.automatic
    var ratio = 0.6
    var inset = 2.0
    var fixed = 8.0
    /// How many days, and so how many bars. Kept inside `dayCountRange`.
    var dayCount = 14 {
        didSet {
            let clamped = min(max(dayCount, Self.dayCountRange.lowerBound), Self.dayCountRange.upperBound)
            if clamped != dayCount { dayCount = clamped }
        }
    }

    init(sales: [DailySales] = CafeData.harbourSales) {
        self.sales = sales
    }

    /// The first `dayCount` days: one bar each.
    var days: [DailySales] {
        Array(sales.prefix(dayCount))
    }

    /// The width handed to every bar.
    var width: MarkDimension {
        switch kind {
        case .automatic:
            // snippet:mark-dimensions-automatic
            // The default for the mark.
            .automatic
        // end
        case .ratio:
            // snippet:mark-dimensions-ratio
            // A fraction, from 0 to 1, of the scale's step: here the width of one day.
            // The gaps are the rest of the step, so they shrink with the bars. At 1 neighbours touch.
            .ratio(ratio)
        // end
        case .inset:
            // snippet:mark-dimensions-inset
            // The step less this many points on each side.
            // The gap between two bars is twice the inset, however many bars there are.
            .inset(inset)
        // end
        case .fixed:
            // snippet:mark-dimensions-fixed
            // A width in points, whatever the step. A bare number means the same: `width: 8`.
            // Once the step is narrower than this, the bars overlap.
            .fixed(fixed)
            // end
        }
    }

    /// The amount of the current case, for the slider. The automatic case has none.
    var amount: Double {
        get {
            switch kind {
            case .automatic: 0
            case .ratio: ratio
            case .inset: inset
            case .fixed: fixed
            }
        }
        set {
            switch kind {
            case .automatic: break
            case .ratio: ratio = newValue
            case .inset: inset = newValue
            case .fixed: fixed = newValue
            }
        }
    }

    /// The amount in words, with its unit: "0.6", "2 points", "8 points". Nil for the automatic case.
    func amountText(locale: Locale) -> String? {
        switch kind {
        case .automatic: nil
        case .ratio: ratio.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
        case .inset: CafeWording.points(inset, locale: locale)
        case .fixed: CafeWording.points(fixed, locale: locale)
        }
    }

    /// The day count as the slider's value.
    var dayCountValue: Double {
        get { Double(dayCount) }
        set { dayCount = Int(newValue.rounded()) }
    }

    /// "1 day", "14 days": the number of bars, as the slider shows and speaks it.
    func dayCountText(locale: Locale) -> String {
        CafeWording.days(days.count, locale: locale)
    }

    /// The snippets for the current setting: the bar that takes the width, then the width chosen.
    var snippets: [SnippetReference] {
        [Self.chartSnippet, kind.snippet]
    }

    /// The width as code would write it, in words: "ratio 0.6 of each day's step".
    func widthDescription(locale: Locale) -> String {
        let amount = amountText(locale: locale) ?? ""
        return switch kind {
        case .automatic: "automatic"
        case .ratio: "ratio, \(amount) of each day's step"
        case .inset: "inset, \(amount) off each side of each day's step"
        case .fixed: "fixed, \(amount)"
        }
    }

    /// What to say aloud when a control redraws the chart. Different for every setting.
    func announcement(locale: Locale) -> String {
        "\(dayCountText(locale: locale)) shown. Bar width: \(widthDescription(locale: locale))."
    }
}
