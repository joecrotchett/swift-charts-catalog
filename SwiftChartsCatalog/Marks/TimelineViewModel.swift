import Foundation
import Observation

/// The mark that draws each shift.
nonisolated enum TimelineMarkStyle: String, CaseIterable, Identifiable {
    case bars
    case rules

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .bars: "Bars"
        case .rules: "Rules"
        }
    }
}

/// Where the baristas' names sit.
nonisolated enum TimelineLabelPlacement: String, CaseIterable, Identifiable {
    case inside
    case outside

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .inside: "Inside"
        case .outside: "Outside"
        }
    }
}

/// The words this screen needs that `CafeWording` does not have.
nonisolated enum TimelineWording {
    static let shift = "Shift"

    /// "1 barista", "4 baristas".
    static func baristas(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) barista](inflect: true)", locale: locale).characters)
    }
}

/// What the timeline says in words: its headline, each bar's spoken value, and the Audio Graph's summary.
/// Times are written in the data's time zone, the one the axis is labelled in, and in the locale it is given.
nonisolated struct TimelineSummary {
    /// The shifts that can be drawn, in data order: one with no length has no bar and is left out.
    let shifts: [Shift]
    let calendar: Calendar
    let locale: Locale

    static let noShifts = "No shifts scheduled."

    init(shifts: [Shift], calendar: Calendar = CafeData.calendar, locale: Locale) {
        self.shifts = shifts.filter { $0.end > $0.start }
        self.calendar = calendar
        self.locale = locale
    }

    /// Each barista once, in the order the rows are drawn.
    var baristas: [String] {
        var seen = Set<String>()
        return shifts.map(\.barista).filter { seen.insert($0).inserted }
    }

    var earliestStart: Date? {
        shifts.map(\.start).min()
    }

    var latestEnd: Date? {
        shifts.map(\.end).max()
    }

    /// Every shift of the greatest length, in data order. More than one when there is a tie.
    var longestShifts: [Shift] {
        guard let longest = shifts.map({ Self.length(of: $0) }).max() else { return [] }
        return shifts.filter { Self.length(of: $0) == longest }
    }

    static func length(of shift: Shift) -> TimeInterval {
        shift.end.timeIntervalSince(shift.start)
    }

    /// "6:00 AM", in the data's time zone.
    func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, timeZone: calendar.timeZone).hour().minute())
    }

    /// "6 hours, 30 minutes", in English whatever the view's locale: the length sits inside an English
    /// sentence, so its words are English, as `CafeWording.list` keeps a list's conjunction English.
    /// The units format style takes one locale for its numbers and its words alike, so the numbers are
    /// English too; a shift's hours and minutes are below a thousand, where that changes no digit.
    func duration(of shift: Shift) -> String {
        Duration.seconds(Self.length(of: shift))
            .formatted(.units(allowed: [.hours, .minutes], width: .wide).locale(CafeWording.listLocale))
    }

    /// "6:00 AM to 12:00 PM".
    func span(of shift: Shift) -> String {
        "\(time(shift.start)) to \(time(shift.end))"
    }

    /// What VoiceOver reads after the barista's name: "6:00 AM to 12:00 PM, 6 hours".
    func spokenValue(of shift: Shift) -> String {
        "\(span(of: shift)), \(duration(of: shift))"
    }

    /// The chart's message in a sentence. True on a tie, and when there is nothing to draw.
    var headline: String {
        guard let longest = longestShifts.first else { return Self.noShifts }
        let who = longestShifts.map { "\($0.barista), \(span(of: $0))" }
        // The times are written in the view's locale; the list that joins them is English, like the sentence.
        return "The longest shift is \(duration(of: longest)): \(CafeWording.list(who))."
    }

    /// Actual values only: how many, from when to when, and the longest.
    var audioGraphSummary: String {
        guard let first = earliestStart, let last = latestEnd else { return Self.noShifts }
        let counts = "\(TimelineWording.baristas(baristas.count, locale: locale)), "
            + "\(CafeWording.shifts(shifts.count, locale: locale)), "
        return counts + "from \(time(first)) to \(time(last)). \(headline)"
    }

    /// One name per shift for the Audio Graph. A barista with several shifts has the start added,
    /// so every category is different: "Ana", "Mia, from 6:00 AM", "Mia, from 1:00 PM".
    var shiftNames: [String] {
        let counts = Dictionary(grouping: shifts, by: \.barista).mapValues(\.count)
        return shifts.map { shift in
            (counts[shift.barista] ?? 0) > 1 ? "\(shift.barista), from \(time(shift.start))" : shift.barista
        }
    }

    /// A time as hours since midnight on the day of the first shift, the number the Audio Graph plays.
    func hours(_ date: Date) -> Double {
        guard let first = earliestStart else { return 0 }
        return date.timeIntervalSince(calendar.startOfDay(for: first)) / Self.secondsPerHour
    }

    /// The time those hours stand for, as it is written everywhere else: 13.5 is "1:30 PM".
    func time(atHours hours: Double) -> String {
        guard let first = earliestStart else { return "" }
        return time(calendar.startOfDay(for: first).addingTimeInterval(hours * Self.secondsPerHour))
    }

    private static let secondsPerHour: TimeInterval = 3600
}

/// The state of the Timeline screen: which mark draws the shifts and where the row names sit.
@Observable
final class TimelineViewModel {
    let shifts: [Shift]
    let calendar: Calendar
    var markStyle = TimelineMarkStyle.bars
    /// Outside is the form the skill's recipe builds; inside is the framework's default.
    var labelPlacement = TimelineLabelPlacement.outside

    init(shifts: [Shift] = CafeData.shifts, calendar: Calendar = CafeData.calendar) {
        self.shifts = shifts
        self.calendar = calendar
    }

    func summary(locale: Locale) -> TimelineSummary {
        TimelineSummary(shifts: shifts, calendar: calendar, locale: locale)
    }

    /// The same for every setting: neither control changes a shift's start or end.
    func headline(locale: Locale) -> String {
        summary(locale: locale).headline
    }

    /// The code for what is drawn now: the mark, then the row labels.
    var snippets: [SnippetReference] {
        [markSnippet, labelSnippet]
    }

    private var markSnippet: SnippetReference {
        switch markStyle {
        case .bars: SnippetReference(name: "timeline-bars", title: "One bar per interval")
        case .rules: SnippetReference(name: "timeline-rules", title: "The thin-rule version")
        }
    }

    private var labelSnippet: SnippetReference {
        switch labelPlacement {
        case .inside: SnippetReference(name: "timeline-labels-inside", title: "Row labels inside (the default)")
        case .outside: SnippetReference(name: "timeline-labels-outside", title: "Row labels outside")
        }
    }

    /// What to say aloud after the mark changes: what changed, then the headline.
    func markStyleAnnouncement(locale: Locale) -> String {
        let change = switch markStyle {
        case .bars: "Shifts drawn as bars."
        case .rules: "Shifts drawn as thin rules."
        }
        return "\(change) \(headline(locale: locale))"
    }
}
