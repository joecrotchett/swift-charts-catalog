import Foundation
import Observation

/// The six charts the screen can show, each a different kind of position for VoiceOver to read.
nonisolated enum DefaultElementsCase: String, CaseIterable, Identifiable {
    case oneMark
    case stacked
    case grouped
    case severalSeries
    case denseLine
    case monthOfDays

    var id: String {
        rawValue
    }

    /// The picker's name for the case.
    var title: String {
        switch self {
        case .oneMark: "One mark"
        case .stacked: "Stacked"
        case .grouped: "Grouped"
        case .severalSeries: "Several series"
        case .denseLine: "A dense line"
        case .monthOfDays: "A month of days"
        }
    }

    /// The caption above the chart: what it draws.
    var caption: String {
        switch self {
        case .oneMark: "Cups sold today, by drink"
        case .stacked: "Cups by drink, sizes stacked"
        case .grouped: "Cups by drink, sizes side by side"
        case .severalSeries: "Daily cups at two cafés, one week"
        case .denseLine: "People queuing, every two minutes"
        case .monthOfDays: "Daily cups at the Harbour café, 30 days"
        }
    }

    /// The See Code region that draws this case's chart.
    var snippet: SnippetReference {
        switch self {
        case .oneMark: SnippetReference(name: "default-elements-one-mark", title: "One mark per position")
        case .stacked: SnippetReference(name: "default-elements-stacked", title: "Stacked bars")
        case .grouped: SnippetReference(name: "default-elements-grouped", title: "Grouped bars")
        case .severalSeries: SnippetReference(name: "default-elements-several-series", title: "Several series")
        case .denseLine: SnippetReference(name: "default-elements-dense-line", title: "A dense line with a gap")
        case .monthOfDays: SnippetReference(name: "default-elements-month-of-days", title: "A month of days")
        }
    }
}

/// One reading of the queue: the time as hours since midnight, and how many people were waiting.
nonisolated struct DefaultElementsQueueReading: Identifiable, Hashable {
    let id: Int
    /// Hours since midnight, such as 8.5 for 8:30 am.
    let hour: Double
    let people: Int
    /// Which unbroken stretch of readings this one belongs to, so the line breaks where readings are missing.
    let partOfDay: String
}

/// The words this screen needs that `CafeWording` does not have, and the counts that agree in number.
nonisolated enum DefaultElementsWording {
    static let hour = "Hour"
    static let partOfDay = "Part of the day"
    static let morning = "Morning"
    static let afternoon = "Afternoon"

    /// "1 element", "15 elements".
    static func elements(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) element](inflect: true)", locale: locale).characters)
    }

    /// "1 segment", "9 segments".
    static func segments(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) segment](inflect: true)", locale: locale).characters)
    }

    /// "1 group", "3 groups".
    static func groups(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) group](inflect: true)", locale: locale).characters)
    }

    /// "1 line", "2 lines".
    static func lines(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) line](inflect: true)", locale: locale).characters)
    }

    /// "1 value", "30 values": how the framework counts the marks a merged stretch summarises.
    static func values(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) value](inflect: true)", locale: locale).characters)
    }

    /// "1 hour", "2 hours".
    static func hours(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) hour](inflect: true)", locale: locale).characters)
    }

    /// "1 series", "2 series": how the framework counts the lines at one day when each line has two encodings.
    static func series(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) series](inflect: true)", locale: locale).characters)
    }

    /// A `.value` label made plural, as the framework says it inside a summary: "3 Sizes".
    static func categories(_ count: Int, label: String, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) \(label)](inflect: true)", locale: locale).characters)
    }
}

/// The data each case draws. Dates are moved to the start of the same day in the device's calendar,
/// so the chart's default axis and VoiceOver's default date ranges both name the day that was counted.
nonisolated struct DefaultElementsData {
    var drinkSales: [DrinkSales]
    var drinkOrders: [DrinkOrder]
    var week: [StoreSales]
    var readings: [DefaultElementsQueueReading]
    var month: [DailySales]

    /// The café's sample data, with its UTC days moved into `calendar`.
    static func sample(calendar: Calendar) -> DefaultElementsData {
        DefaultElementsData(
            drinkSales: CafeData.drinkSales,
            drinkOrders: CafeData.drinkOrders,
            week: CafeData.storeSales.map { store in
                StoreSales(store: store.store, days: store.days.prefix(7).map { localDay($0, calendar: calendar) })
            },
            readings: queueReadings(),
            month: CafeData.tenWeeks.prefix(30).map { localDay($0, calendar: calendar) }
        )
    }

    /// A day counted in UTC, moved to the start of the same calendar day in `calendar`.
    static func localDay(_ sales: DailySales, calendar: Calendar) -> DailySales {
        let parts = CafeData.calendar.dateComponents([.year, .month, .day], from: sales.day)
        return DailySales(day: calendar.date(from: parts) ?? sales.day, cups: sales.cups)
    }

    /// A reading every two minutes from 6:00 to 18:00, with the hour from 12:00 missing (the counter was
    /// off): 330 readings. The same on every run.
    static func queueReadings() -> [DefaultElementsQueueReading] {
        var generator = SeededGenerator(seed: 1012)
        return (0 ..< 360).compactMap { index in
            let minutes = index * 2
            let hour = 6 + Double(minutes) / 60
            let noise = generator.nextUnit()
            guard minutes / 60 != 6 else { return nil }
            let morningRush = 7 * exp(-pow((hour - 8.5) / 1.1, 2))
            let afternoonRush = 4 * exp(-pow((hour - 15.5) / 1.4, 2))
            let people = Int((1 + morningRush + afternoonRush + noise * 2).rounded(.down))
            return DefaultElementsQueueReading(
                id: index, hour: hour, people: people,
                partOfDay: hour < 12 ? DefaultElementsWording.morning : DefaultElementsWording.afternoon
            )
        }
    }
}

/// One accessibility element as VoiceOver reads it (read on iOS 27, in the simulator).
nonisolated struct DefaultElementsSpokenElement: Hashable {
    let label: String
    let value: String

    /// Label then value, as VoiceOver reads them.
    var readAs: String {
        [label, value].filter { !$0.isEmpty }.joined(separator: ", ")
    }
}

/// What the default Audio Graph is given (read on iOS 27, in the simulator).
nonisolated struct DefaultElementsAudioGraph: Hashable {
    let title: String
    let summary: String
    let xAxis: String
    let yAxis: String
    let series: String
    let points: String
}

/// Everything the screen shows as spoken for one case: the elements, the Audio Graph, and what a real
/// chart would add.
nonisolated struct DefaultElementsSpokenText: Hashable {
    let elements: [DefaultElementsSpokenElement]
    let audioGraph: DefaultElementsAudioGraph
    let realChartAdds: String
}

/// The screen's state: which chart is shown, and every word the screen says about what assistive
/// technologies get from it.
@Observable
final class DefaultElementsViewModel {
    var chartCase: DefaultElementsCase = .oneMark
    let data: DefaultElementsData
    /// The calendar the framework cuts days in and writes dates in: by default, the device's.
    let calendar: Calendar

    init(data: DefaultElementsData? = nil, calendar: Calendar = .current) {
        self.calendar = calendar
        self.data = data ?? .sample(calendar: calendar)
    }

    /// The code for the chart now shown.
    var snippets: [SnippetReference] {
        [chartCase.snippet]
    }

    /// Whether the current case has marks to draw. Bars of nothing but zeros draw no marks either.
    var hasMarks: Bool {
        hasMarks(chartCase)
    }

    func hasMarks(_ chartCase: DefaultElementsCase) -> Bool {
        switch chartCase {
        case .oneMark: data.drinkSales.contains { $0.cups > 0 }
        case .stacked, .grouped: data.drinkOrders.contains { $0.cups > 0 }
        case .severalSeries: data.week.contains { !$0.days.isEmpty }
        case .denseLine: !data.readings.isEmpty
        case .monthOfDays: data.month.contains { $0.cups > 0 }
        }
    }

    // MARK: The spoken text, in one table

    /// Every case's elements and Audio Graph, in one place. Each was read on iOS 27 in the simulator with
    /// `scripts/ax-dump.sh` (`Docs/field-notes/epic-10/wave-1-dumps/def-*.txt`); the wording is built from
    /// the data so it follows the locale, and the field note says which parts are a reading for this data
    /// rather than a rule.
    func spokenTable(locale: Locale) -> [DefaultElementsCase: DefaultElementsSpokenText] {
        let noName = "One series with no name"
        let chartTitle = "Chart"
        let noSummary = "None"
        let drink = CafeWording.drink
        let cups = CafeWording.cups
        let dateAxis = "\(CafeWording.day), as numbers (seconds since 2001); both ends read as empty"
        let sizesSeries = "\(sizeNames): one series per size, separate values, "
            + "\(DefaultElementsWording.values(drinkTotals.count, locale: locale)) each"

        return [
            .oneMark: DefaultElementsSpokenText(
                elements: data.drinkSales.map {
                    DefaultElementsSpokenElement(label: $0.drink, value: number($0.cups, locale: locale))
                },
                audioGraph: DefaultElementsAudioGraph(
                    title: chartTitle, summary: noSummary,
                    xAxis: "\(drink): the drinks as categories", yAxis: drawnScale(cups, case: .oneMark, locale: locale),
                    series: "\(noName), separate values, \(DefaultElementsWording.values(data.drinkSales.count, locale: locale))",
                    points: firstPoint(data.drinkSales.first.map { "\($0.drink), \(number($0.cups, locale: locale))" })
                ),
                realChartAdds: """
                The unit: a labelled Plot around each bar reads "Latte, 128 cups" (Labels that give context). \
                A chart descriptor gives the Audio Graph a real title and a summary (Audio Graph title and summary).
                """
            ),
            .stacked: DefaultElementsSpokenText(
                elements: drinkTotalElements(locale: locale),
                audioGraph: DefaultElementsAudioGraph(
                    title: chartTitle, summary: noSummary,
                    xAxis: "\(drink): the drinks as categories", yAxis: drawnScale(cups, case: .stacked, locale: locale),
                    series: sizesSeries,
                    points: firstPoint(data.drinkOrders.first.map {
                        "\($0.drink), \(number($0.cups, locale: locale))\": each segment's own cups, not its height in the stack"
                    }, closesQuote: false)
                ),
                realChartAdds: """
                Each segment read on its own needs a labelled Plot around it; a label on a bare segment is ignored \
                (Labels that are not read). One total per drink with its parts said in words is A simpler chart for VoiceOver.
                """
            ),
            .grouped: DefaultElementsSpokenText(
                // Read on iOS: grouped bars are read exactly as stacked ones, as each drink's total.
                elements: drinkTotalElements(locale: locale),
                audioGraph: DefaultElementsAudioGraph(
                    title: chartTitle, summary: noSummary,
                    xAxis: "\(drink): the drinks as categories", yAxis: drawnScale(cups, case: .grouped, locale: locale),
                    series: sizesSeries,
                    points: firstPoint(data.drinkOrders.first.map { "\($0.drink), \(number($0.cups, locale: locale))" })
                ),
                realChartAdds: """
                Side by side or stacked, the elements are the same: each drink's total, with nothing to say the \
                sizes stand apart. A labelled Plot around each bar reads each size's cups (Labels that are not \
                read), and a descriptor says the unit (Audio Graph title and summary).
                """
            ),
            .severalSeries: DefaultElementsSpokenText(
                elements: weekElements(locale: locale),
                audioGraph: DefaultElementsAudioGraph(
                    title: chartTitle, summary: noSummary,
                    xAxis: dateAxis, yAxis: drawnScale(cups, case: .severalSeries, locale: locale),
                    // Each series is named by both of its encodings, colour and symbol: "Harbour Harbour".
                    series: "\(CafeWording.list(data.week.map { "\($0.store) \($0.store)" })): one series per café, "
                        + "named once for each of its two encodings, continuous, "
                        + "\(DefaultElementsWording.values(weekDays.count, locale: locale)) each",
                    points: firstPoint(data.week.first?.days.first.map {
                        "\(seconds(middleOf: $0.day)), \(number($0.cups, locale: locale))\": "
                            + "the middle of the day in seconds since 2001, and the bare value"
                    }, closesQuote: false)
                ),
                realChartAdds: """
                Each day is read as a midnight-to-midnight range, and its value runs from the first café's cups \
                to the last's without naming either. A label per day writes the date once and names each café \
                (Labels that give context), and a descriptor gives the Audio Graph its dates and unit (Audio \
                Graph title and summary).
                """
            ),
            .denseLine: DefaultElementsSpokenText(
                elements: readingStretches.map { stretch in
                    DefaultElementsSpokenElement(
                        label: "\(number(stretch.start, locale: locale)) to \(number(stretch.end, locale: locale))",
                        value: merged(stretch.values, locale: locale)
                    )
                },
                audioGraph: DefaultElementsAudioGraph(
                    title: chartTitle, summary: noSummary,
                    xAxis: "\(DefaultElementsWording.hour), \(Self.denseLineDrawnHours.lowerBound) to "
                        + "\(Self.denseLineDrawnHours.upperBound), the drawn scale",
                    yAxis: drawnScale(CafeWording.queueAxisTitle, case: .denseLine, locale: locale),
                    series: "\(noName), continuous, \(DefaultElementsWording.values(data.readings.count, locale: locale)): "
                        + "the tone runs on through the missing hour, since series: breaks only the drawn line",
                    points: firstPoint(data.readings.first.map {
                        "\(number($0.hour, locale: locale)), \(number($0.people, locale: locale))\": bare numbers, no time or unit"
                    }, closesQuote: false)
                ),
                realChartAdds: """
                The framework picks the stretches, folds the hour after the gap into a stretch that starts at \
                the gap, says no unit, and the Audio Graph plays straight across the gap. A labelled Plot per \
                portion chooses the stretches and their words (One element or many); a descriptor states the \
                gap (Audio Graph title and summary).
                """
            ),
            .monthOfDays: DefaultElementsSpokenText(
                elements: monthElements(locale: locale),
                audioGraph: DefaultElementsAudioGraph(
                    title: chartTitle, summary: noSummary,
                    xAxis: dateAxis, yAxis: drawnScale(cups, case: .monthOfDays, locale: locale),
                    series: "\(noName), separate values, \(DefaultElementsWording.values(data.month.count, locale: locale))",
                    points: firstPoint(data.month.first.map {
                        "\(seconds(middleOf: $0.day)), \(number($0.cups, locale: locale))\": "
                            + "the middle of the day in seconds since 2001, and the bare value"
                    }, closesQuote: false)
                ),
                realChartAdds: """
                Two days share an element here, a reading for these days at local midnight and not a rule: the \
                same days at midnight UTC were merged into weeks. A labelled Plot around each bar makes every \
                day its own element (One element or many), read with its date written out (Labels that give context).
                """
            ),
        ]
    }

    /// The spoken text for the chart now shown.
    func spokenText(locale: Locale) -> DefaultElementsSpokenText? {
        spokenTable(locale: locale)[chartCase]
    }

    // MARK: The headline

    /// The headline for the chart now shown.
    func headline(locale: Locale) -> String {
        headline(for: chartCase, locale: locale)
    }

    /// The chart's message: what is drawn, and how many elements VoiceOver reads for it. Its counts are
    /// ones a reader can find on the chart, and the element count is the length of the list read on iOS.
    func headline(for chartCase: DefaultElementsCase, locale: Locale) -> String {
        guard hasMarks(chartCase) else {
            return "No data: the chart draws nothing, so VoiceOver has nothing to read."
        }
        let elements = DefaultElementsWording.elements(
            spokenTable(locale: locale)[chartCase]?.elements.count ?? 0, locale: locale
        )
        switch chartCase {
        case .oneMark:
            return "\(CafeWording.bars(data.drinkSales.count, locale: locale)), one per drink: "
                + "VoiceOver reads \(elements), one per bar."
        case .stacked:
            return "\(DefaultElementsWording.segments(data.drinkOrders.count, locale: locale)) in "
                + "\(CafeWording.bars(drinkTotals.count, locale: locale)): VoiceOver reads \(elements), "
                + "each bar as its total."
        case .grouped:
            return "\(CafeWording.bars(data.drinkOrders.count, locale: locale)) in "
                + "\(DefaultElementsWording.groups(drinkTotals.count, locale: locale)): VoiceOver reads "
                + "\(elements), each group as its total, exactly as if stacked."
        case .severalSeries:
            return "\(DefaultElementsWording.lines(data.week.count, locale: locale)) over "
                + "\(CafeWording.days(weekDays.count, locale: locale)): VoiceOver reads \(elements), "
                + "each day from the first café's cups to the last's."
        case .denseLine:
            let first = number(data.readings.first.map { Int($0.hour.rounded(.down)) } ?? 0, locale: locale)
            let last = number(data.readings.last.map { Int($0.hour.rounded(.up)) } ?? 0, locale: locale)
            let gap = missingHours.first.map {
                " with no readings from \(number($0, locale: locale)) to \(number($0 + 1, locale: locale))"
            } ?? ""
            let silent = gapStretch.map {
                ", and the one from \(number($0.start, locale: locale)) to \(number($0.end, locale: locale)) "
                    + "says nothing of the missing hour"
            } ?? ""
            return "A line from \(first) to \(last)\(gap): VoiceOver reads \(elements) of "
                + "\(DefaultElementsWording.hours(Self.denseLineStretchHours, locale: locale))\(silent)."
        case .monthOfDays:
            return "\(CafeWording.bars(data.month.count, locale: locale)), one per day: "
                + "VoiceOver reads \(elements) of \(CafeWording.days(Self.daysPerMonthElement, locale: locale))."
        }
    }

    /// The longest headline any case writes, so the headline keeps one height as the picker changes.
    func longestHeadline(locale: Locale) -> String {
        DefaultElementsCase.allCases.map { headline(for: $0, locale: locale) }.max { $0.count < $1.count } ?? ""
    }

    /// Said when the picker changes the chart: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        "Showing \(chartCase.title.lowercased()). \(headline(locale: locale))"
    }

    // MARK: Readings for this data

    /// How many days the framework merged into one element on this 30-day axis, read on iOS 27 with the
    /// days at local midnight. A reading for this data, not a rule: the same days at midnight UTC were
    /// merged into 6 one-week stretches.
    static let daysPerMonthElement = 2

    /// How many hours the framework merged into one element on the dense line, from an even hour, read on
    /// iOS 27 for these readings. A reading for this data, not a rule.
    static let denseLineStretchHours = 2

    /// The dense line's drawn x scale, read on iOS 27 as the Audio Graph's x axis range.
    static let denseLineDrawnHours = 5 ... 20

    /// The top of each chart's drawn y scale, read on iOS 27 as the default Audio Graph's y range, which is
    /// the drawn scale, not the data. A reading for the sample data.
    static let drawnYAxisTop: [DefaultElementsCase: Int] = [
        .oneMark: 200, .stacked: 200, .grouped: 75, .severalSeries: 300, .denseLine: 10, .monthOfDays: 300,
    ]

    // MARK: Workings

    /// One drink's stacked or grouped bar: its total and how many sizes make it.
    struct DrinkTotal {
        let drink: String
        let cups: Int
        let sizes: Int
    }

    /// The drinks in data order, each with its cups and number of sizes.
    var drinkTotals: [DrinkTotal] {
        var order: [String] = []
        var rows: [String: [DrinkOrder]] = [:]
        for row in data.drinkOrders {
            if rows[row.drink] == nil { order.append(row.drink) }
            rows[row.drink, default: []].append(row)
        }
        return order.map { drink in
            let drinkRows = rows[drink] ?? []
            return DrinkTotal(drink: drink, cups: drinkRows.map(\.cups).reduce(0, +), sizes: Set(drinkRows.map(\.size)).count)
        }
    }

    /// "Latte, total 128, 3 Sizes": stacked and grouped bars alike.
    private func drinkTotalElements(locale: Locale) -> [DefaultElementsSpokenElement] {
        drinkTotals.map { total in
            DefaultElementsSpokenElement(
                label: total.drink,
                value: "total \(number(total.cups, locale: locale)), "
                    + DefaultElementsWording.categories(total.sizes, label: CafeWording.size, locale: locale)
            )
        }
    }

    private var sizeNames: String {
        var seen: [String] = []
        for row in data.drinkOrders where !seen.contains(row.size) {
            seen.append(row.size)
        }
        return CafeWording.list(seen)
    }

    /// Every day that any café has, in order.
    private var weekDays: [Date] {
        Set(data.week.flatMap { $0.days.map(\.day) }).sorted()
    }

    /// One element per day, its value the first café's cups to the last café's, in series order (not
    /// lowest to highest), then the number of series.
    private func weekElements(locale: Locale) -> [DefaultElementsSpokenElement] {
        weekDays.map { day in
            let values = data.week.compactMap { store in store.days.first { $0.day == day }?.cups }
            let value = if let first = values.first, let last = values.last, values.count > 1 {
                "\(number(first, locale: locale)) to \(number(last, locale: locale)), "
                    + DefaultElementsWording.series(values.count, locale: locale)
            } else {
                // One café on a day was not read; predicted as its value alone.
                values.first.map { number($0, locale: locale) } ?? ""
            }
            return DefaultElementsSpokenElement(label: dayRange(from: day, days: 1, locale: locale), value: value)
        }
    }

    /// The month's days merged in twos from the first day, each summarised as the framework summarises a stretch.
    private func monthElements(locale: Locale) -> [DefaultElementsSpokenElement] {
        stride(from: 0, to: data.month.count, by: Self.daysPerMonthElement).map { start in
            let days = Array(data.month[start ..< min(start + Self.daysPerMonthElement, data.month.count)])
            return DefaultElementsSpokenElement(
                label: dayRange(from: days.first?.day ?? .distantPast, days: days.count, locale: locale),
                value: merged(days.map(\.cups), locale: locale)
            )
        }
    }

    /// A stretch of the dense line: from `start` to `end` hours, and its readings in order.
    struct ReadingStretch {
        let start: Int
        let end: Int
        let values: [Int]
    }

    /// The readings in stretches of `denseLineStretchHours` from an even hour, as read on iOS. A stretch
    /// with no readings at all has no element.
    var readingStretches: [ReadingStretch] {
        let width = Self.denseLineStretchHours
        let byStart = Dictionary(grouping: data.readings) { Int($0.hour.rounded(.down)) / width * width }
        return byStart.keys.sorted().map { start in
            ReadingStretch(
                start: start, end: start + width,
                values: (byStart[start] ?? []).sorted { $0.hour < $1.hour }.map(\.people)
            )
        }
    }

    /// Whole hours between the first and last reading that have no readings.
    var missingHours: [Int] {
        let hours = Set(data.readings.map { Int($0.hour.rounded(.down)) })
        guard let first = hours.min(), let last = hours.max() else { return [] }
        return (first ... last).filter { !hours.contains($0) }
    }

    /// The stretch that covers the first missing hour, read as if the hour were not missing.
    private var gapStretch: ReadingStretch? {
        guard let hour = missingHours.first else { return nil }
        return readingStretches.first { $0.start <= hour && hour < $0.end }
    }

    /// How a merged stretch is summarised, in the three forms read on iOS 27:
    /// two values, "193 to 146, 2 values"; a stretch whose first and last values are its extremes,
    /// "3 to 1, decreases inconsistently, 60 values"; any other, "starts at 8, varies between 9 and 2,
    /// ends at 3, 60 values", the two extremes in the order they are reached, not lowest first.
    func merged(_ values: [Int], locale: Locale) -> String {
        guard let first = values.first, let last = values.last, let lowest = values.min(), let highest = values.max()
        else { return "" }
        let count = DefaultElementsWording.values(values.count, locale: locale)
        // One value alone was not read; predicted as the bare number.
        guard values.count > 1 else { return number(first, locale: locale) }
        if values.count == 2 {
            return "\(number(first, locale: locale)) to \(number(last, locale: locale)), \(count)"
        }
        if lowest != highest, Set([first, last]) == Set([lowest, highest]) {
            // Read only for a stretch that wanders on the way; a steady rise or fall was not read.
            let direction = last > first ? "increases" : "decreases"
            return "\(number(first, locale: locale)) to \(number(last, locale: locale)), \(direction) inconsistently, \(count)"
        }
        let firstExtreme = values.firstIndex(of: lowest) ?? 0
        let secondExtreme = values.firstIndex(of: highest) ?? 0
        let (one, other) = firstExtreme <= secondExtreme ? (lowest, highest) : (highest, lowest)
        return "starts at \(number(first, locale: locale)), varies between \(number(one, locale: locale)) "
            + "and \(number(other, locale: locale)), ends at \(number(last, locale: locale)), \(count)"
    }

    /// "Mar 1, 2026 at 12 AM to Mar 2, 2026 at 12 AM": a stretch of days written in full, in the device's
    /// time zone, as the framework labels a stretch of a date axis.
    private func dayRange(from day: Date, days: Int, locale: Locale) -> String {
        let style = Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
            .month(.abbreviated).day().year().hour()
        let end = calendar.date(byAdding: .day, value: days, to: day) ?? day
        return "\(day.formatted(style)) to \(end.formatted(style))"
    }

    /// The x value the default Audio Graph gets for a day on a date axis: the middle of that day in the
    /// device's calendar, in seconds since 2001, written as a plain integer as it was read.
    private func seconds(middleOf day: Date) -> String {
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        let middle = start.timeIntervalSinceReferenceDate + end.timeIntervalSince(start) / 2
        return Int(middle).formatted(.number.grouping(.never))
    }

    /// "Cups, 0 to 200, the drawn scale".
    private func drawnScale(_ title: String, case chartCase: DefaultElementsCase, locale: Locale) -> String {
        let top = Self.drawnYAxisTop[chartCase] ?? 0
        return "\(title), \(number(0, locale: locale)) to \(number(top, locale: locale)), the drawn scale"
    }

    private func number(_ value: Int, locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }

    private func number(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
    }

    /// `Each point like "…"`; pass `closesQuote: false` when `text` closes the quote itself and goes on.
    private func firstPoint(_ text: String?, closesQuote: Bool = true) -> String {
        text.map { "Each point like \"\($0)\(closesQuote ? "\"" : "")" } ?? "No points"
    }
}
