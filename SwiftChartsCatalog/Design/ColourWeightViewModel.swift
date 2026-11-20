import Charts
import Observation
import SwiftUI
import UIKit

/// The two pairs of café colours the screen switches between.
nonisolated enum ColourWeightPalette: Equatable {
    /// A blue and an orange that come out the same grey: neither line outweighs the other.
    case equal
    /// The mistake: a dark navy beside a bright orange, so one line looks more important than the other.
    case unequal

    /// The colour each café's line and points are drawn in. The chart's scale and the legend both read it.
    func colour(for store: String) -> Color {
        switch self {
        case .equal: ColourWeightPalette.equalColour(for: store)
        case .unequal: ColourWeightPalette.unequalColour(for: store)
        }
    }

    /// The colour's everyday name, as the legend writes it. Each pair is two names nobody mixes up.
    func colourName(for store: String) -> String {
        let isStation = store == CafeWording.station
        switch self {
        case .equal: return isStation ? "orange" : "blue"
        case .unequal: return isStation ? "bright orange" : "navy"
        }
    }

    // snippet:colour-weight-and-meaning-equal
    /// Equal weight: the same grey, hues far apart. Harbour takes the sea's blue; orange is the hue
    /// furthest from it, and the pair avoids red and green, which are often read as good or bad news.
    /// Each has a darker version for Increase Contrast, and a lighter one for Increase Contrast
    /// in Dark Mode, matched to each other in the same way.
    static func equalColour(for store: String) -> Color {
        store == CafeWording.station
            ? adaptive(normal: (0.827, 0.471, 0.133), darker: (0.576, 0.277, 0.062), lighter: (0.900, 0.572, 0.382))
            : adaptive(normal: (0.255, 0.569, 0.859), darker: (0.049, 0.376, 0.640), lighter: (0.403, 0.665, 0.929))
    }

    // end

    // snippet:colour-weight-and-meaning-unequal
    /// The mistake: a dark, muted navy beside a vivid, light orange. The names are still easy to tell
    /// apart, but the weights are not equal: in greyscale one is a dark grey and the other a pale one.
    /// In Dark Mode the navy is lifted to 3:1 against the panel, still far darker than the orange.
    static func unequalColour(for store: String) -> Color {
        store == CafeWording.station
            ? Color(.sRGB, red: 0.988, green: 0.580, blue: 0.090)
            : Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.302, green: 0.408, blue: 0.651, alpha: 1)
                    : UIColor(red: 0.086, green: 0.173, blue: 0.333, alpha: 1)
            })
    }

    // end

    /// A colour that moves to a matched darker or lighter version when Increase Contrast is on.
    private static func adaptive(
        normal: (Double, Double, Double), darker: (Double, Double, Double), lighter: (Double, Double, Double)
    ) -> Color {
        Color(uiColor: UIColor { traits in
            let rgb = traits.accessibilityContrast != .high ? normal : (traits.userInterfaceStyle == .dark ? lighter : darker)
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }
}

/// The name of the symbol `CafeSeriesStyle` draws a café with, for the legend's spoken text. The symbol is
/// read from `CafeSeriesStyle` and matched by its outline against the framework's shapes, so a change there
/// changes what is said here too.
nonisolated enum ColourWeightSymbolName {
    private static let shapes: [(shape: AnyChartSymbolShape, plural: String)] = [
        (AnyChartSymbolShape(.circle), "circles"),
        (AnyChartSymbolShape(.square), "squares"),
        (AnyChartSymbolShape(.triangle), "triangles"),
        (AnyChartSymbolShape(.diamond), "diamonds"),
        (AnyChartSymbolShape(.pentagon), "pentagons"),
        (AnyChartSymbolShape(.plus), "plus signs"),
        (AnyChartSymbolShape(.cross), "crosses"),
        (AnyChartSymbolShape(.asterisk), "asterisks"),
    ]
    private static let unit = CGRect(x: 0, y: 0, width: 10, height: 10)

    /// "circles" for Harbour, "squares" for Station; "points" for a shape not in the list.
    static func plural(for store: String) -> String {
        let outline = CafeSeriesStyle.symbol(for: store).path(in: unit)
        return shapes.first { $0.shape.path(in: unit) == outline }?.plural ?? "points"
    }
}

/// One café's cups on one day.
nonisolated struct ColourWeightReading: Identifiable, Hashable {
    let store: String
    let cups: Int

    var id: String {
        store
    }
}

/// One day of the chart: every café's cups that day, the unit one accessibility element describes.
nonisolated struct ColourWeightDay: Identifiable, Hashable {
    let date: Date
    /// The start of the next day, where this day's band ends.
    let end: Date
    let readings: [ColourWeightReading]
    /// The last day drawn, whose values are written on the chart because the headline names them.
    let isLast: Bool

    var id: Date {
        date
    }

    /// Whether this reading is the day's lowest of several: its label goes below its point.
    func isLowest(_ reading: ColourWeightReading) -> Bool {
        guard readings.count > 1, let lowest = readings.map(\.cups).min() else { return false }
        return reading.cups == lowest && readings.contains { $0.cups > lowest }
    }
}

/// The state and words of "Colour: weight and meaning": which pair of colours is drawn, and what the chart says.
@Observable
final class ColourWeightViewModel {
    let stores: [StoreSales]
    /// The calendar the sample days were made in.
    let calendar: Calendar
    /// The mistake toggle: on draws the cafés in colours of unequal weight.
    var isShowingUnequalWeight = false

    /// The caption, month first as on every other screen of these days: "Cups sold each day, March 1 – 28, 2026".
    func caption(locale: Locale) -> String {
        let dates = stores.flatMap { $0.days.map(\.day) }
        guard let first = dates.min(), let last = dates.max() else { return "Cups sold each day" }
        return "Cups sold each day, \(CafeWording.dayRange(first, last, locale: locale))"
    }

    init(stores: [StoreSales] = CafeData.storeSales, calendar: Calendar = CafeData.calendar) {
        self.stores = stores
        self.calendar = calendar
    }

    var palette: ColourWeightPalette {
        isShowingUnequalWeight ? .unequal : .equal
    }

    /// The cafés in legend order: the shared order first, then any other in data order.
    var storeNames: [String] {
        let names = stores.filter { !$0.days.isEmpty }.map(\.store)
        return CafeSeriesStyle.stores.filter(names.contains) + names.filter { !CafeSeriesStyle.stores.contains($0) }
    }

    /// No days at all: the chart is replaced by a placeholder. A line of zeros is still drawn.
    var hasData: Bool {
        !storeNames.isEmpty
    }

    /// Every day any café has a record for, in date order, with each café's cups in legend order.
    var days: [ColourWeightDay] {
        let dates = Set(stores.flatMap { $0.days.map(\.day) }).sorted()
        return dates.enumerated().map { index, date in
            let readings = storeNames.compactMap { name -> ColourWeightReading? in
                guard let day = stores.first(where: { $0.store == name })?.days.first(where: { $0.day == date }) else {
                    return nil
                }
                return ColourWeightReading(store: name, cups: day.cups)
            }
            return ColourWeightDay(
                date: date,
                end: calendar.date(byAdding: .day, value: 1, to: date) ?? date,
                readings: readings,
                isLast: index == dates.count - 1
            )
        }
    }

    /// The days the date axis labels: the first, then every seventh day after it.
    var labelledDays: [Date] {
        days.enumerated().filter { $0.offset % 7 == 0 }.map(\.element.date)
    }

    /// The value axis as drawn and as the Audio Graph is told it: the cups rounded out to steps of 50.
    /// The lines are far from zero, so the axis does not start at zero.
    var cupsAxis: ClosedRange<Double> {
        let cups = stores.flatMap { $0.days.map { Double($0.cups) } }
        let lowest = ((cups.min() ?? 0) / 50).rounded(.down) * 50
        let highest = max(lowest + 50, ((cups.max() ?? 0) / 50).rounded(.up) * 50)
        return lowest ... highest
    }

    /// A day written out in the data's time zone, as the elements, headline and descriptor say it.
    func dayName(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .weekday(.wide).month(.wide).day())
    }

    /// The chart's message: who sold more on the last day, with both figures, which are written on the chart.
    func headline(locale: Locale) -> String {
        guard let last = days.last, let first = last.readings.first else { return "No cups sold yet." }
        let day = dayName(last.date, locale: locale)
        if last.readings.count == 1 {
            return "On \(day), \(first.store) sold \(CafeWording.cups(first.cups, locale: locale))."
        }
        let ranked = last.readings.sorted { $0.cups > $1.cups }
        let top = ranked[0]
        let others = ranked.dropFirst()
        if others.allSatisfy({ $0.cups == top.cups }) {
            return "On \(day), \(CafeWording.list(ranked.map(\.store))) each sold \(CafeWording.cups(top.cups, locale: locale))."
        }
        let rest = others.map { "\($0.store)’s \($0.cups.formatted(.number.locale(locale)))" }
        return "On \(day), \(top.store) sold more: \(CafeWording.cups(top.cups, locale: locale)) to \(CafeWording.list(rest))."
    }

    /// What one day's element says after its label: each café, then its cups.
    func dayValue(_ day: ColourWeightDay, locale: Locale) -> String {
        day.readings.map { "\($0.store), \(CafeWording.cups($0.cups, locale: locale))" }.joined(separator: "; ")
    }

    /// What the legend says for a café: its name, then the colour and symbol it is drawn in.
    func legendLabel(for store: String) -> String {
        "\(store): \(palette.colourName(for: store)) line with \(ColourWeightSymbolName.plural(for: store))"
    }

    /// Said aloud when the toggle changes which colour each café gets: what changed, then the headline.
    func changeAnnouncement(locale: Locale) -> String {
        let pair = CafeWording.list(storeNames.map { "\($0) \(palette.colourName(for: $0))" })
        let change = isShowingUnequalWeight
            ? "Colours of unequal weight: \(pair)."
            : "Colours of equal weight: \(pair)."
        return "\(change) \(headline(locale: locale))"
    }

    /// The code See Code shows: the chart, then the pair of colours now drawn.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "colour-weight-and-meaning-chart", title: "Each café's colour from one mapping"),
            isShowingUnequalWeight
                ? SnippetReference(name: "colour-weight-and-meaning-unequal", title: "The mistake: a dark colour beside a vivid one")
                : SnippetReference(name: "colour-weight-and-meaning-equal", title: "Two colours of equal weight, easy to name"),
        ]
    }
}
