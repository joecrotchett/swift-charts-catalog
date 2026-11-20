import Foundation
import Observation

/// One day of the chart: the Harbour café's cups, drawn as a bar, and the Station café's, a point on a line.
nonisolated struct StylingMarksDay: Identifiable, Hashable {
    let day: Date
    let harbour: Int
    let station: Int

    var id: Date {
        day
    }
}

/// The styling toggles, the week they style, and the words written about it.
///
/// Every toggle restyles the same marks: none changes the data, the scale or the kind of mark, so
/// the headline is the same in every combination and no change is announced.
@Observable
final class StylingMarksViewModel {
    /// Paint the bars in a colour of their own instead of the chart's default blue. The line keeps
    /// its own colour either way, so it never disappears into blue bars.
    var usesFixedColour = true
    /// Paint Harbour's busiest day in a second colour.
    var highlightsBusiestDay = false
    /// Fade the bars, so the line over them shows. A highlighted bar stays at full strength.
    var fadesBars = false
    /// Round the two top corners of each bar.
    var roundsCorners = false
    /// Draw the line dashed and heavier.
    var dashesLine = false
    /// Give the line a drop shadow.
    var shadowsLine = false
    /// Blur the bars, so the line reads first.
    var blursBars = false

    let days: [StylingMarksDay]

    /// The first week of both cafés by default. The two lists are paired day by day.
    init(
        harbour: [DailySales] = Array(CafeData.storeSales[0].days.prefix(7)),
        station: [DailySales] = Array(CafeData.storeSales[1].days.prefix(7))
    ) {
        days = zip(harbour, station).map { StylingMarksDay(day: $0.day, harbour: $0.cups, station: $1.cups) }
    }

    /// From the start of the first day to the end of the last, in the data's calendar: the x domain the
    /// bars fill. A single instant when there are no days.
    var dayDomain: ClosedRange<Date> {
        guard let first = days.first?.day, let last = days.last?.day else { return Date.distantPast ... Date.distantPast }
        let end = CafeData.calendar.date(byAdding: .day, value: 1, to: last) ?? last
        return first ... max(first, end)
    }

    /// No cups at either café: the chart shows a placeholder instead of empty axes.
    var hasNoSales: Bool {
        days.allSatisfy { $0.harbour == 0 && $0.station == 0 }
    }

    /// Every day on which Harbour sold the most, in date order; more than one on a tie, none when it sold nothing.
    var busiestDays: [Date] {
        guard let most = days.map(\.harbour).max(), most > 0 else { return [] }
        return days.filter { $0.harbour == most }.map(\.day)
    }

    func isBusiest(_ day: StylingMarksDay) -> Bool {
        busiestDays.contains(day.day)
    }

    /// Whether this bar is drawn in the highlight colour.
    func isHighlighted(_ day: StylingMarksDay) -> Bool {
        highlightsBusiestDay && isBusiest(day)
    }

    /// The snippets for the current toggles: the chart always, then one for each modifier in use.
    var snippets: [SnippetReference] {
        var references = [SnippetReference(name: "styling-marks-chart", title: "The bars and the line")]
        if usesFixedColour || highlightsBusiestDay {
            references.append(SnippetReference(name: "styling-marks-colour", title: "A fixed colour and one highlighted bar"))
        }
        if fadesBars {
            references.append(SnippetReference(name: "styling-marks-opacity", title: "Opacity"))
        }
        if roundsCorners {
            references.append(SnippetReference(name: "styling-marks-corner-radius", title: "Corner radius"))
        }
        if dashesLine {
            references.append(SnippetReference(name: "styling-marks-line-style", title: "Line style"))
        }
        if shadowsLine {
            references.append(SnippetReference(name: "styling-marks-shadow", title: "Shadow"))
        }
        if blursBars {
            references.append(SnippetReference(name: "styling-marks-blur", title: "Blur"))
        }
        return references
    }

    // MARK: Words

    /// A day written out the way it is spoken, in the data's own time zone: "Saturday, March 7".
    func spokenDay(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// The chart's message. True in every combination of toggles, on a tie, and with nothing sold.
    func headline(locale: Locale) -> String {
        guard !hasNoSales else { return "No cups sold at either café this week." }
        guard let first = busiestDays.first, let cups = days.first(where: { $0.day == first })?.harbour else {
            return "Harbour sold no cups this week."
        }
        let names = CafeWording.list(busiestDays.map { spokenDay($0, locale: locale) })
        return "Harbour’s busiest day: \(names), \(CafeWording.cups(cups, locale: locale))."
    }

    /// What one day's element says: both cafés, with the highlight named while it is drawn.
    func accessibilityValue(for day: StylingMarksDay, locale: Locale) -> String {
        var value = "\(CafeWording.harbour) \(CafeWording.cups(day.harbour, locale: locale)), "
            + "\(CafeWording.station) \(CafeWording.cups(day.station, locale: locale))"
        if isHighlighted(day) {
            value += ", highlighted: Harbour’s busiest day"
        }
        return value
    }

    /// The Audio Graph's summary, in actual values only.
    func audioGraphSummary(locale: Locale) -> String {
        guard !hasNoSales else { return "No cups sold at either café this week." }
        return "\(CafeWording.days(days.count, locale: locale)). "
            + "Harbour, as bars: \(extremes(\.harbour, locale: locale)). "
            + "Station, as a line: \(extremes(\.station, locale: locale))."
    }

    /// "highest Saturday, March 7, 219 cups; lowest Tuesday, March 3, 152 cups", naming the first day of each.
    private func extremes(_ cups: KeyPath<StylingMarksDay, Int>, locale: Locale) -> String {
        let values = days.map { $0[keyPath: cups] }
        guard let most = values.max(), let fewest = values.min(),
              let highest = days.first(where: { $0[keyPath: cups] == most }),
              let lowest = days.first(where: { $0[keyPath: cups] == fewest })
        else { return "" }
        return "highest \(spokenDay(highest.day, locale: locale)), \(CafeWording.cups(highest[keyPath: cups], locale: locale)); "
            + "lowest \(spokenDay(lowest.day, locale: locale)), \(CafeWording.cups(lowest[keyPath: cups], locale: locale))"
    }
}
