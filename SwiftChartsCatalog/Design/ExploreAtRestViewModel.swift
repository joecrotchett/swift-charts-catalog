import Foundation
import Observation

/// One day at both cafés: the values the chart draws at one position, and what a selection reveals.
nonisolated struct ExploreAtRestDay: Identifiable, Hashable {
    let day: Date
    let firstCups: Int
    let secondCups: Int

    var id: Date {
        day
    }
}

/// One café's line: its name and its days, as plain values for the chart.
nonisolated struct ExploreAtRestSeries: Identifiable, Hashable {
    let name: String
    let points: [ExploreAtRestPoint]

    var id: String {
        name
    }
}

/// One point of a café's line.
nonisolated struct ExploreAtRestPoint: Identifiable, Hashable {
    let day: Date
    let cups: Int

    var id: Date {
        day
    }
}

/// The run of days at the end of the period on which one café sold more than the other every day.
nonisolated struct ExploreAtRestLead: Hashable {
    let leader: String
    let trailer: String
    /// The days of the run, in order. Never empty.
    let days: [Date]
    /// Whether the run is the whole period.
    let coversEveryDay: Bool
}

/// What a selection reveals: the snapped day written out, and each café's cups on it.
nonisolated struct ExploreAtRestSelection: Hashable {
    let day: Date
    /// "Monday, March 23".
    let dayText: String
    /// "Mon, Mar 23", for the accessibility text sizes, where the long form is wider than the chart.
    let shortDayText: String
    let firstName: String
    let firstCups: Int
    let secondName: String
    let secondCups: Int
}

/// The words of the screen, worked out from the data, the mistake setting and the locale. Every sentence the
/// screen shows or speaks comes from here, so a test can read it and it can be changed in one place.
nonisolated struct ExploreAtRestWords {
    let days: [ExploreAtRestDay]
    let firstName: String
    let secondName: String
    let calendar: Calendar
    let locale: Locale

    /// The run of days at the end of the period on which one café led every day. `nil` when the last day
    /// is a tie, or there is no data.
    var lead: ExploreAtRestLead? {
        guard let last = days.last, last.firstCups != last.secondCups else { return nil }
        let firstLeads = last.firstCups > last.secondCups
        let run = days.reversed().prefix { firstLeads ? $0.firstCups > $0.secondCups : $0.secondCups > $0.firstCups }
        return ExploreAtRestLead(
            leader: firstLeads ? firstName : secondName,
            trailer: firstLeads ? secondName : firstName,
            days: run.reversed().map(\.day),
            coversEveryDay: run.count == days.count
        )
    }

    /// The days the chart shades at rest to carry the message: the leader's run, unless it is the whole period
    /// (every day is then already the message, and shading all of it would mark nothing) or there is none.
    var shadedDays: [Date] {
        guard let lead, !lead.coversEveryDay else { return [] }
        return lead.days
    }

    /// The chart's message, true of the data as drawn, including no data and all zeros.
    var message: String {
        guard !days.isEmpty else { return "No sales recorded at either café." }
        if days.allSatisfy({ $0.firstCups == 0 && $0.secondCups == 0 }) {
            return "Neither café sold a cup in these \(CafeWording.days(days.count, locale: locale))."
        }
        guard let lead, let start = lead.days.first else {
            let firstWins = days.count(where: { $0.firstCups > $0.secondCups })
            let secondWins = days.count(where: { $0.secondCups > $0.firstCups })
            let (winner, loser, wins) = firstWins >= secondWins
                ? (firstName, secondName, firstWins) : (secondName, firstName, secondWins)
            return "\(winner) sold more than \(loser) on \(wins.formatted(.number.locale(locale))) of "
                + "\(CafeWording.days(days.count, locale: locale))."
        }
        if lead.coversEveryDay, days.count > 1 {
            return "\(lead.leader) sold more than \(lead.trailer) on every one of the \(CafeWording.days(days.count, locale: locale))."
        }
        if lead.days.count == 1 {
            return "\(lead.leader) sold more than \(lead.trailer) on the last day, \(longDay(start))."
        }
        return "\(lead.leader) has sold more than \(lead.trailer) every day since \(longDay(start))."
    }

    /// The headline the mistake shows: an instruction in place of the message.
    static let mistakeHeadline = "Touch and hold the chart to compare the cafés."

    /// The key under the chart where the shading's first day is not written inside it, so that day can still be
    /// found: the axis labels only every seventh day.
    var shadedLabel: String? {
        guard let lead, let start = shadedDays.first else { return nil }
        if shadedDays.count == 1 {
            return "\(lead.leader) ahead on \(shortDay(start))"
        }
        return "\(lead.leader) ahead since \(shortDay(start))"
    }

    /// The fewest shaded days whose first day can be written inside the shading at phone width: a narrower band
    /// has its key under the chart instead, as at the accessibility sizes.
    static let fewestDaysLabelledInShading = 5

    /// Whether the shading's first day is written inside it at this text size, rather than in a key under the chart.
    func labelsShadingInPlot(isAccessibilitySize: Bool) -> Bool {
        !isAccessibilitySize && shadedDays.count >= Self.fewestDaysLabelledInShading
    }

    /// What is written inside the shading, longest first: the chart shows the first that fits the band.
    /// "Since Mar 21", then "Mar 21".
    var bandLabels: [String] {
        guard let start = shadedDays.first else { return [] }
        return ["Since \(shortDay(start))", shortDay(start)]
    }

    /// The screen's explanation, true of the chart as drawn at this text size and setting.
    func explanation(isAccessibilitySize: Bool, isShowingMistake: Bool) -> String {
        let atRest = if isShowingMistake {
            "With the mistake on, nothing is shaded and the headline only asks for a gesture; turn it off "
                + "and the message is drawn at rest."
        } else if shadedDays.isEmpty {
            "At rest the headline already says the message, and the lines show it."
        } else if labelsShadingInPlot(isAccessibilitySize: isAccessibilitySize) {
            "At rest the chart already says its message: the shaded days are the ones the headline names, "
                + "with the day they start written in the shading."
        } else {
            "At rest the chart already says its message: the shaded days are the ones the headline names, "
                + "and the key under the chart gives the day they start."
        }
        return atRest + " Touch and hold anywhere in the plot, above, below or between the lines, and drag to read "
            + "both cafés' exact cups for each day; it adds detail, it is not needed for the point. VoiceOver reads "
            + "the same figures without a gesture, one element per day. To hear it on a device, turn VoiceOver on and "
            + "swipe through the chart; the rotor's Audio Graph has Describe chart and Play Audio Graph."
    }

    /// What VoiceOver reads for one day: the day first, then both cafés' cups. The same figures a selection shows.
    func elementLabel(_ day: ExploreAtRestDay) -> String {
        longDay(day.day)
    }

    func elementValue(_ day: ExploreAtRestDay) -> String {
        "\(firstName) \(CafeWording.cups(day.firstCups, locale: locale)), "
            + "\(secondName) \(CafeWording.cups(day.secondCups, locale: locale))"
    }

    /// The Audio Graph's summary: actual values, and the shading only when it is drawn.
    func audioGraphSummary(isShowingMistake: Bool) -> String {
        guard let first = days.first, let last = days.last else { return message }
        var sentences = [
            "\(CafeWording.days(days.count, locale: locale)), \(longDay(first.day)) to \(longDay(last.day)).",
            message,
        ]
        if !isShowingMistake, !shadedDays.isEmpty {
            sentences.append(shadedDays.count == 1 ? "That day is shaded on the chart." : "Those days are shaded on the chart.")
        }
        sentences.append(range(of: firstName, days.map(\.firstCups)))
        sentences.append(range(of: secondName, days.map(\.secondCups)))
        return sentences.joined(separator: " ")
    }

    /// What is said when the mistake is switched on or off: what changed, then the headline.
    func announcement(isShowingMistake: Bool) -> String {
        isShowingMistake
            ? "Mistake shown: the shading is gone and the headline asks for a gesture. \(Self.mistakeHeadline)"
            : "Mistake hidden: the message is back on the chart. \(message)"
    }

    /// What a selection on `day` reveals, written in the data's time zone.
    func selection(of day: ExploreAtRestDay) -> ExploreAtRestSelection {
        ExploreAtRestSelection(
            day: day.day, dayText: longDay(day.day),
            shortDayText: day.day.formatted(
                Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.abbreviated).month(.abbreviated).day()
            ),
            firstName: firstName, firstCups: day.firstCups,
            secondName: secondName, secondCups: day.secondCups
        )
    }

    /// "Saturday, March 21", in the data's time zone and the view's locale.
    func longDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// "Mar 21", in the data's time zone and the view's locale.
    func shortDay(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.abbreviated).day())
    }

    private func range(of name: String, _ cups: [Int]) -> String {
        "\(name) from \(CafeWording.cups(cups.min() ?? 0, locale: locale)) to \(CafeWording.cups(cups.max() ?? 0, locale: locale))."
    }
}

/// The state of "Interaction: explore, do not require": the two cafés' days, the raw selection under the finger,
/// and whether the mistake (the message left to the gesture) is shown.
@Observable
final class ExploreAtRestViewModel {
    /// The step the value axis is rounded to, and its labels are spaced by: a sequence people count in.
    static let cupsStep = 50

    let stores: [StoreSales]
    let calendar: Calendar
    /// The exact position under the finger, as the chart reports it. `nil` when nothing is selected.
    var rawSelection: Date?
    var isShowingMistake = false

    init(stores: [StoreSales] = CafeData.storeSales, calendar: Calendar = CafeData.calendar) {
        self.stores = stores
        self.calendar = calendar
    }

    var firstName: String {
        stores.first?.store ?? CafeWording.harbour
    }

    var secondName: String {
        stores.dropFirst().first?.store ?? CafeWording.station
    }

    /// The days both cafés have a record for, in date order.
    var days: [ExploreAtRestDay] {
        guard stores.count >= 2 else { return [] }
        let second = stores[1].days
        return stores[0].days.compactMap { day in
            guard let other = second.first(where: { calendar.isDate($0.day, inSameDayAs: day.day) }) else { return nil }
            return ExploreAtRestDay(day: day.day, firstCups: day.cups, secondCups: other.cups)
        }
    }

    /// Each café's line, from the same days.
    var series: [ExploreAtRestSeries] {
        let days = days
        return [
            ExploreAtRestSeries(name: firstName, points: days.map { ExploreAtRestPoint(day: $0.day, cups: $0.firstCups) }),
            ExploreAtRestSeries(name: secondName, points: days.map { ExploreAtRestPoint(day: $0.day, cups: $0.secondCups) }),
        ]
    }

    var hasData: Bool {
        !days.isEmpty
    }

    func words(locale: Locale) -> ExploreAtRestWords {
        ExploreAtRestWords(days: days, firstName: firstName, secondName: secondName, calendar: calendar, locale: locale)
    }

    // snippet:interaction-explore-do-not-require-mistake
    /// The headline: the message at rest, or the mistake's instruction, which leaves the message to a gesture
    /// that a tap, a scroll or VoiceOver never makes.
    func headline(locale: Locale) -> String {
        hasData && isShowingMistake ? ExploreAtRestWords.mistakeHeadline : words(locale: locale).message
    }

    // end

    /// The day under the finger, snapped to a day that has data. `nil` when nothing is selected, or the finger is
    /// on a day with no record.
    var selectedDay: ExploreAtRestDay? {
        guard let rawSelection else { return nil }
        return days.first { calendar.isDate($0.day, inSameDayAs: rawSelection) }
    }

    func selection(locale: Locale) -> ExploreAtRestSelection? {
        selectedDay.map { words(locale: locale).selection(of: $0) }
    }

    /// The value axis, worked out here so the chart and the Audio Graph share it: from the lowest value rounded
    /// down to the step to the highest rounded up. A line does not need zero, so the lines fill the plot.
    var cupsDomain: ClosedRange<Int> {
        let cups = days.flatMap { [$0.firstCups, $0.secondCups] }
        let step = Self.cupsStep
        let lower = ((cups.min() ?? 0) / step) * step
        let upper = Int((Double(cups.max() ?? 0) / Double(step)).rounded(.up)) * step
        return lower ... max(upper, lower + step)
    }

    /// The value axis's labels: every step from the bottom to the top of the domain.
    var cupsAxisValues: [Int] {
        Array(stride(from: cupsDomain.lowerBound, through: cupsDomain.upperBound, by: Self.cupsStep))
    }
}
