import Charts
import Foundation
import Observation
import SwiftUI

/// The ten cafés of the chain as a fixed set of categories, so the colour of each one is checked by
/// the compiler instead of looked up by name. The raw values are the names in `CafeData.chainCafes`.
nonisolated enum ColourMeaningCafe: String, Plottable, CaseIterable {
    case kiosk = "Kiosk"
    case pier = "Pier"
    case market = "Market"
    case library = "Library"
    case riverside = "Riverside"
    case campus = "Campus"
    case station = "Station"
    case harbour = "Harbour"
    case airport = "Airport"
    case central = "Central"
}

// snippet:colour-meaning-colours
/// The colour each café always has: ten colours that are easy to name apart (pink was dropped: beside red it read as a second red), so no two cafés share
/// one, and a café keeps its colour whichever others are shown.
nonisolated extension ColourMeaningCafe {
    var colour: Color {
        switch self {
        case .kiosk: .mint
        case .pier: .cyan
        case .market: .orange
        case .library: .purple
        case .riverside: .indigo
        case .campus: .yellow
        case .station: .green
        case .harbour: .blue
        case .airport: .brown
        case .central: .red
        }
    }
}

// end

/// One café as the chart draws it: its category and its yearly cups.
nonisolated struct ColourMeaningRow: Identifiable, Hashable {
    let cafe: ColourMeaningCafe
    let yearlyCups: Int

    var id: ColourMeaningCafe {
        cafe
    }
}

/// Where the chart's colours come from.
nonisolated enum ColourMeaningColours: String, CaseIterable, Identifiable {
    /// The framework's palette, handed out in data order.
    case automatic
    /// A colour chosen for each café with `chartForegroundStyleScale`.
    case explicit

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .explicit: "Explicit"
        }
    }
}

/// What the chart says in words, for the colours and cafés it is drawn with: the headline, the
/// Audio Graph's summary and what is announced when a control changes the chart.
nonisolated struct ColourMeaningSummary {
    /// How many colours the automatic palette has before it starts again: blue, green, orange,
    /// purple, red, cyan and yellow (the skill's `gallery/README.md` and `scales.md`).
    static let automaticPaletteSize = 7

    let rows: [ColourMeaningRow]
    let colours: ColourMeaningColours
    /// The locale every count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// How many different colours the chart draws.
    var colourCount: Int {
        switch colours {
        case .automatic: min(rows.count, Self.automaticPaletteSize)
        case .explicit: Set(rows.map(\.cafe.colour)).count
        }
    }

    /// Each café drawn in a colour an earlier café already has, with that earlier café, in data order.
    /// Empty with explicit colours, which are all different.
    var repeats: [(cafe: ColourMeaningCafe, sharesWith: ColourMeaningCafe)] {
        guard colours == .automatic else { return [] }
        return rows.indices.dropFirst(Self.automaticPaletteSize).map { index in
            (rows[index].cafe, rows[index % Self.automaticPaletteSize].cafe)
        }
    }

    /// The chart's message in a sentence. Its figures, the number of cafés and of colours, can be
    /// counted in the chart's rows and legend as it is drawn.
    var headline: String {
        guard !rows.isEmpty else { return "No cafés to colour." }
        let cafes = CafeWording.cafes(rows.count, locale: locale)
        let colourWords = Self.colours(colourCount, locale: locale)
        switch colours {
        case .automatic where repeats.isEmpty:
            return "\(cafes), \(colourWords): one each, in the order the cafés appear."
        case .automatic:
            let pairs = repeats.map { "\($0.cafe.rawValue) has \($0.sharesWith.rawValue)’s" }
            return "\(cafes) but only \(colourWords), so they repeat: \(CafeWording.list(pairs))."
        case .explicit:
            return "\(cafes), \(colourWords): each café keeps its own."
        }
    }

    /// Actual values, then the headline. No judgement of the values.
    var audioGraphSummary: String {
        guard let first = rows.first, let last = rows.last else { return headline }
        let range = rows.count == 1
            ? "\(first.cafe.rawValue), \(CafeWording.cups(first.yearlyCups, locale: locale)) a year."
            : "From \(first.cafe.rawValue), \(CafeWording.cups(first.yearlyCups, locale: locale)) a year, "
            + "to \(last.cafe.rawValue), \(CafeWording.cups(last.yearlyCups, locale: locale)) a year."
        return "\(range) \(headline)"
    }

    /// "1 colour", "7 colours". `CafeWording` has no count for colours, so it is added here in the same form.
    static func colours(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) colour](inflect: true)", locale: locale).characters)
    }
}

/// The state of the "Colour that means something" screen: how many of the chain's cafés are shown,
/// and whether their colours are automatic or set.
@Observable
final class ColourMeaningViewModel {
    /// Every café that can be shown, in data order (smallest first).
    let allRows: [ColourMeaningRow]
    /// How many cafés are shown, from the first. The stepper keeps it within `countRange`.
    var cafeCount: Int

    var colours: ColourMeaningColours = .automatic

    /// The cafés of `CafeData.chainCafes`, or any others. A café whose name has no case is left out.
    init(cafes: [ChainCafe] = CafeData.chainCafes, cafeCount: Int = 5) {
        allRows = cafes.compactMap { cafe in
            ColourMeaningCafe(rawValue: cafe.name).map { ColourMeaningRow(cafe: $0, yearlyCups: cafe.yearlyCups) }
        }
        let range = min(2, allRows.count) ... allRows.count
        self.cafeCount = min(max(cafeCount, range.lowerBound), range.upperBound)
    }

    /// From two cafés (or fewer, if there are fewer) to all of them.
    var countRange: ClosedRange<Int> {
        min(2, allRows.count) ... allRows.count
    }

    /// The cafés the chart draws.
    var rows: [ColourMeaningRow] {
        Array(allRows.prefix(max(cafeCount, 0)))
    }

    func summary(locale: Locale) -> ColourMeaningSummary {
        ColourMeaningSummary(rows: rows, colours: colours, locale: locale)
    }

    /// Said when the number of cafés changes: what changed, then the headline.
    func countAnnouncement(locale: Locale) -> String {
        "\(CafeWording.cafes(rows.count, locale: locale)) shown. \(summary(locale: locale).headline)"
    }

    /// Said when the colour scale changes: what changed, then the headline.
    func coloursAnnouncement(locale: Locale) -> String {
        "\(colours.title) colours. \(summary(locale: locale).headline)"
    }

    /// The snippets for the current setting: the automatic scale alone, or with the scale that sets it.
    var snippets: [SnippetReference] {
        switch colours {
        case .automatic:
            [Self.automaticSnippet]
        case .explicit:
            [Self.automaticSnippet, Self.explicitSnippet, Self.coloursSnippet]
        }
    }

    static let automaticSnippet = SnippetReference(name: "colour-meaning-automatic", title: "A colour scale from the data")
    static let explicitSnippet = SnippetReference(name: "colour-meaning-explicit", title: "Setting the scale")
    static let coloursSnippet = SnippetReference(name: "colour-meaning-colours", title: "Each café’s colour")
}
