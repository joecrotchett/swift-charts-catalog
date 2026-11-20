import Foundation
import Observation

/// The colour ramps the screen can lay over the same number.
nonisolated enum ColourRampsRamp: String, CaseIterable, Identifiable {
    /// No colour scale set: the framework's own ramp.
    case automatic
    /// A `Gradient` of the app's choosing, from yellow to red, over the automatic domain (rounded
    /// outward past the data, so no bar is drawn in either end colour).
    case custom
    /// Orange through gray to blue, over a domain centred on zero.
    case diverging

    var id: String {
        rawValue
    }

    /// The picker's short title.
    var title: String {
        switch self {
        case .automatic: "Default"
        case .custom: "Yellow to red"
        case .diverging: "Diverging"
        }
    }

    /// What the ramp is, in words, for the Audio Graph's summary: what is drawn, not what it means.
    var spokenDescription: String {
        switch self {
        case .automatic: "the default ramp, shades of one blue"
        case .custom: "a ramp from yellow to red: the lower the change, the more yellow"
        case .diverging: "a ramp centred on zero: orange for fewer cups, gray at no change, blue for more"
        }
    }
}

/// The screen's state: which ramp colours the bars. The data does not change.
@Observable
final class ColourRampsViewModel {
    let changes: [DrinkChange]
    var ramp: ColourRampsRamp = .automatic

    init(changes: [DrinkChange] = CafeData.drinkChanges) {
        self.changes = changes
    }

    /// `isDark`: whether the chart is drawn in Dark Mode, where the default ramp runs the other way in lightness.
    func summary(locale: Locale, isDark: Bool = false) -> ColourRampsSummary {
        ColourRampsSummary(changes: changes, ramp: ramp, locale: locale, isDark: isDark)
    }

    /// The snippets for the current ramp: the encoding always, then the scale that sets the ramp, if any.
    var snippets: [SnippetReference] {
        Self.snippets(for: ramp)
    }

    static let encodeSnippet = SnippetReference(name: "colour-ramps-encode", title: "A number as colour")
    static let customSnippet = SnippetReference(name: "colour-ramps-custom-gradient", title: "A Gradient as the range")
    static let divergingSnippet = SnippetReference(name: "colour-ramps-diverging", title: "A ramp centred on zero")

    static func snippets(for ramp: ColourRampsRamp) -> [SnippetReference] {
        switch ramp {
        case .automatic: [encodeSnippet]
        case .custom: [encodeSnippet, customSnippet]
        case .diverging: [encodeSnippet, divergingSnippet]
        }
    }

    /// Said aloud when the ramp changes: what changed, then the headline.
    func announcement(locale: Locale, isDark: Bool = false) -> String {
        "Colour ramp: \(ramp.title). \(summary(locale: locale, isDark: isDark).headline)"
    }
}

/// What the chart says in words for one ramp: headline, element values and the Audio Graph's summary.
nonisolated struct ColourRampsSummary {
    let changes: [DrinkChange]
    let ramp: ColourRampsRamp
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale
    /// Whether the chart is drawn in Dark Mode. The default ramp's low end is pale on a light panel and near
    /// black on a dark one, so the words for its lightness follow the appearance (read in the view and passed in).
    var isDark = false

    /// The drinks that draw a bar. A change of zero has no length and no colour.
    var drawn: [DrinkChange] {
        changes.filter { $0.change != 0 }
    }

    /// True when there is nothing to draw: no data, or only changes of zero.
    var isEmpty: Bool {
        drawn.isEmpty
    }

    /// The drinks with the lowest drawn change, in data order. More than one on a tie.
    var lowest: [DrinkChange] {
        guard let low = drawn.map(\.change).min() else { return [] }
        return drawn.filter { $0.change == low }
    }

    /// The drinks with the highest drawn change, in data order.
    var highest: [DrinkChange] {
        guard let high = drawn.map(\.change).max() else { return [] }
        return drawn.filter { $0.change == high }
    }

    var rose: [DrinkChange] {
        drawn.filter { $0.change > 0 }
    }

    var fell: [DrinkChange] {
        drawn.filter { $0.change < 0 }
    }

    /// Half the width of the diverging ramp's domain: the largest change either way, so zero is its middle.
    var divergingLimit: Int {
        max(changes.map { abs($0.change) }.max() ?? 0, 1)
    }

    /// The range the value axis draws: bars grow from zero, so it always includes zero, and its ends are rounded
    /// out to the axis step (-305 and 212 → -400 to 400). The chart's x scale and the descriptor's range.
    var valueRange: ClosedRange<Double> {
        ChartAxis.valueDomain(for: changes.map(\.change))
    }

    /// The headline, true of the bars as drawn under the current ramp.
    var headline: String {
        guard let low = lowest.first, let high = highest.first else { return emptyMessage }
        if ramp == .diverging {
            return divergingHeadline
        }
        if low.change == high.change {
            return "Every bar is the same colour: \(names(drawn)) \(Self.movement(low.change, locale: locale))."
        }
        // The automatic domain rounds outward past the data, so no bar is said to be at an end of the ramp.
        let lowWords = "\(names(lowest)), \(Self.movement(low.change, locale: locale))"
        let highWords = "\(names(highest)), \(Self.movement(high.change, locale: locale))"
        switch ramp {
        case .automatic, .diverging:
            // Said as palest and deepest, not as ends: the lowest bar can be too pale to see on a light panel,
            // and the reader can still find it by its drink and its value.
            // In Dark Mode the ramp's low end is the darkest bar and its high end the brightest.
            return isDark
                ? "The higher the change, the brighter the blue: \(highWords), is the brightest, and \(lowWords), the darkest."
                : "The higher the change, the deeper the blue: \(highWords), is the deepest, and \(lowWords), the palest."
        case .custom:
            return "\(lowWords), is the most yellow; \(highWords), the most red."
        }
    }

    /// Small changes sit near the gray middle, so bars are said to be on a side of the ramp, not a colour.
    private var divergingHeadline: String {
        let more = "\(CafeWording.drinks(rose.count, locale: locale)) sold more than last month, on the blue side"
        let fewer = "\(CafeWording.drinks(fell.count, locale: locale)) sold fewer, on the orange side"
        if fell.isEmpty { return "\(more); zero is the gray middle of the ramp." }
        if rose.isEmpty {
            return "\(CafeWording.drinks(fell.count, locale: locale)) sold fewer than last month, on the orange side; "
                + "zero is the gray middle of the ramp."
        }
        return "\(more), and \(fewer)."
    }

    private var emptyMessage: String {
        changes.isEmpty ? "No changes against last month to show." : "Every drink sold the same as last month."
    }

    /// Actual values only, then what the colour shows.
    var audioGraphSummary: String {
        guard let low = lowest.first, let high = highest.first else { return emptyMessage }
        let counts = "\(CafeWording.drinks(changes.count, locale: locale)): "
            + "\(rose.count.formatted(.number.locale(locale))) sold more than last month, "
            + "\(fell.count.formatted(.number.locale(locale))) fewer."
        let extremes = "Highest \(names(highest)), \(Self.movement(high.change, locale: locale)); "
            + "lowest \(names(lowest)), \(Self.movement(low.change, locale: locale))."
        return "\(counts) \(extremes) Colour repeats each change, on \(ramp.spokenDescription)."
    }

    /// "Mocha", "Tea and Chai": joined the English way, as the sentence around it is English.
    func names(_ drinks: [DrinkChange]) -> String {
        CafeWording.list(drinks.map(\.drink))
    }

    /// A change said in words: "up 212 cups", "down 1 cup", "no change". The count agrees in number.
    static func movement(_ change: Int, locale: Locale) -> String {
        if change > 0 { return "up \(CafeWording.cups(change, locale: locale))" }
        if change < 0 { return "down \(CafeWording.cups(-change, locale: locale))" }
        return "no change"
    }
}
