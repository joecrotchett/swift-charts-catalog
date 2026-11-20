import Foundation
import Observation

/// What the dashboard's per-day and weekday charts draw one series of: each café, or each drink.
nonisolated enum DashboardBreakdown: String, CaseIterable, Identifiable, Hashable {
    case cafe
    case drink

    var id: String {
        rawValue
    }

    /// The word for one series, singular: also the `.value` label of the encoding and the picker's segment.
    var seriesLabel: String {
        switch self {
        case .cafe: CafeWording.store
        case .drink: CafeWording.drink
        }
    }
}

/// Which of the shared selections changed, for the sentence that announces it.
nonisolated enum DashboardChange: Hashable {
    case day
    case drink
    case breakdown
    /// Clear selection: the day and the drink at once, said in one sentence.
    case clear
}

/// One series' cups on one day.
nonisolated struct DashboardSeriesValue: Identifiable, Hashable {
    let series: String
    let cups: Int

    var id: String {
        series
    }
}

/// One day of the per-day chart: every series' cups that day, and what VoiceOver says for it.
nonisolated struct DashboardDayPoint: Identifiable, Hashable {
    let day: Date
    let values: [DashboardSeriesValue]

    var id: Date {
        day
    }
}

/// One drink's cups for the period the drink mix shows.
nonisolated struct DashboardDrinkBar: Identifiable, Hashable {
    let drink: String
    let cups: Int

    var id: String {
        drink
    }
}

/// The average cups of one series on one weekday, over the four weeks.
nonisolated struct DashboardHeatCell: Identifiable, Hashable {
    /// The weekday as the axis writes it, from `CafeData.weekdays`.
    let weekday: String
    let series: String
    let averageCups: Double

    var id: String {
        "\(weekday)-\(series)"
    }

    /// The average as it is said and written: whole cups.
    var roundedCups: Int {
        Int(averageCups.rounded())
    }
}

/// The summary card's figures and words, worked out for one selection.
nonisolated struct DashboardSummary: Hashable {
    /// "Cups", or "Cups of Mocha".
    let caption: String
    let total: Int
    /// "1,234 cups".
    let totalText: String
    /// "March 1 to March 28", or "Tuesday, March 17".
    let period: String
    /// The change on the same weekday a week earlier, or why there is none.
    let change: String
    /// "Harbour, 5,900 cups", or "Harbour and Station, 120 cups each", or "None sold".
    let busiestCafe: String
    /// As `busiestCafe`, for drinks. It compares every drink, as the drink mix does, so it stays while a drink
    /// is selected and the card keeps one height.
    let busiestDrink: String
}

/// The dashboard's one model: the data, the selected day, the selected drink and the breakdown.
/// Every panel reads it, and every panel's chart writes its selection back here, so selecting on one
/// chart, or with a picker, moves all of them.
///
/// The rule every panel follows: a count that sums across drinks (a café's cups, the summary's total)
/// counts only the selected drink; a chart whose series are drinks keeps every drink and emphasises the
/// selected one.
@Observable @MainActor
final class DashboardModel {
    let sales: [DashboardSale]
    /// The calendar the days were recorded in (UTC).
    let calendar: Calendar
    /// Every day in the data, in order.
    let days: [Date]
    let stores: [String]
    let drinks: [String]
    /// The value domain of every position scale of cups a day: the per-day lines in both breakdowns and the
    /// drink mix for one day. The highest daily count of any café or drink, rounded up to 50.
    let cupsDomain: ClosedRange<Double>
    /// The drink mix's value domain for the four weeks, rounded up to 1,000.
    let periodDrinkDomain: ClosedRange<Double>

    private(set) var selectedDay: Date?
    private(set) var selectedDrink: String?
    var breakdown: DashboardBreakdown = .cafe

    /// The selection change the last action made, and how many actions have changed the selection, so the
    /// view posts one announcement per action: Clear selection changes two values and says one sentence.
    private(set) var lastSelectionChange: DashboardChange?
    private(set) var selectionChangeCount = 0

    /// The longest headline per locale identifier: it depends only on the data and the locale, so it is
    /// worked out once, not on every redraw.
    @ObservationIgnored private var longestHeadlines: [String: String] = [:]

    init(sales: [DashboardSale] = CafeData.dashboardSales, calendar: Calendar = CafeData.calendar) {
        self.sales = sales
        self.calendar = calendar
        days = Array(Set(sales.map(\.day))).sorted()
        // The shared orders, so every panel lists cafés and drinks the same way; anything else in the
        // data follows in the order it first appears.
        stores = Self.ordered(CafeSeriesStyle.stores, then: sales.map(\.store))
        drinks = Self.ordered(CafeDrinkStyle.drinks, then: sales.map(\.drink))

        var cafeDay: [String: Int] = [:]
        var drinkDay: [String: Int] = [:]
        var drinkPeriod: [String: Int] = [:]
        for sale in sales {
            cafeDay["\(sale.store)-\(sale.day.timeIntervalSinceReferenceDate)", default: 0] += sale.cups
            drinkDay["\(sale.drink)-\(sale.day.timeIntervalSinceReferenceDate)", default: 0] += sale.cups
            drinkPeriod[sale.drink, default: 0] += sale.cups
        }
        let dailyTop = max(cafeDay.values.max() ?? 0, drinkDay.values.max() ?? 0)
        cupsDomain = 0 ... Double(Self.roundedUp(dailyTop, step: 50))
        // An eighth more than the longest bar before rounding, so the value written after it has room
        // inside the plot: fitted to the plot, a label with no room is pushed back over its own bar (seen on iPad).
        let periodTop = drinkPeriod.values.max() ?? 0
        periodDrinkDomain = 0 ... Double(Self.roundedUp(periodTop + periodTop / 8, step: 1000))
    }

    var isEmpty: Bool {
        sales.isEmpty
    }

    // MARK: Selection

    /// Selects the day containing `date`, in the data's calendar, so a raw position under a finger
    /// (with a time of day) lands on its day. A date outside the data, or nil, clears the selection.
    func selectDay(_ date: Date?) {
        let day = date.flatMap { date in days.first { calendar.isDate($0, inSameDayAs: date) } }
        guard day != selectedDay else { return }
        selectedDay = day
        recordSelectionChange(.day)
    }

    /// Selects a drink in the data; anything else, or nil, clears the selection.
    func selectDrink(_ drink: String?) {
        let drink = drink.flatMap { drinks.contains($0) ? $0 : nil }
        guard drink != selectedDrink else { return }
        selectedDrink = drink
        recordSelectionChange(.drink)
    }

    /// Clears the day and the drink as one action.
    func clearSelection() {
        guard hasSelection else { return }
        selectedDay = nil
        selectedDrink = nil
        recordSelectionChange(.clear)
    }

    private func recordSelectionChange(_ change: DashboardChange) {
        lastSelectionChange = change
        selectionChangeCount += 1
    }

    var hasSelection: Bool {
        selectedDay != nil || selectedDrink != nil
    }

    // MARK: Counting

    /// Cups matching every filter given; a nil filter matches everything.
    func cups(store: String? = nil, drink: String? = nil, day: Date? = nil) -> Int {
        sales.lazy
            .filter { store == nil || $0.store == store }
            .filter { drink == nil || $0.drink == drink }
            .filter { day == nil || $0.day == day }
            .map(\.cups)
            .reduce(0, +)
    }

    /// Cups for the current selection: the selected day (or the four weeks) and the selected drink (or all).
    var selectionTotal: Int {
        cups(drink: selectedDrink, day: selectedDay)
    }

    /// The series the breakdown draws, in the shared order.
    var seriesNames: [String] {
        breakdown == .cafe ? stores : drinks
    }

    /// The series drawn at full strength. With drinks as the series and one drink selected, only that one;
    /// otherwise all of them (cafés are already counted for the selected drink).
    var emphasisedSeries: Set<String> {
        if breakdown == .drink, let selectedDrink { return [selectedDrink] }
        return Set(seriesNames)
    }

    /// One series' cups on one day, following the panel rule: a café counts the selected drink only.
    private func cups(series: String, day: Date?) -> Int {
        switch breakdown {
        case .cafe: cups(store: series, drink: selectedDrink, day: day)
        case .drink: cups(drink: series, day: day)
        }
    }

    // MARK: Cups per day

    var dayPoints: [DashboardDayPoint] {
        days.map { day in
            DashboardDayPoint(day: day, values: seriesNames.map { DashboardSeriesValue(series: $0, cups: cups(series: $0, day: day)) })
        }
    }

    /// The x domain of the per-day chart: from the first day to the end of the last.
    var dayDomain: ClosedRange<Date> {
        let first = days.first ?? CafeData.firstDay
        let last = days.last ?? first
        return first ... (calendar.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    /// The per-day chart's heading under its title: "By café", "By café, Mocha only", "By drink".
    func cupsPerDaySubtitle() -> String {
        var text = "By \(breakdown.seriesLabel.lowercased())"
        if breakdown == .cafe, let selectedDrink { text += ", \(selectedDrink) only" }
        return text
    }

    /// What VoiceOver says for one day: the day, then each series with its cups.
    func dayPointLabel(_ point: DashboardDayPoint, locale: Locale) -> String {
        dayName(point.day, locale: locale)
    }

    /// "Harbour, 194 cups; Station, 202 cups", and "; selected" on the selected day: the band is hidden, so
    /// the selection is spoken here.
    func dayPointValue(_ point: DashboardDayPoint, locale: Locale) -> String {
        let values = point.values.map { "\($0.series), \(CafeWording.cups($0.cups, locale: locale))" }.joined(separator: "; ")
        return point.day == selectedDay ? "\(values); \(Self.selectedWord)" : values
    }

    /// Added to the value of whatever is selected, since a `Plot` takes no traits.
    nonisolated static let selectedWord = "selected"

    /// A new identity for the per-day chart whenever its element text or descriptor changes for the same days.
    var cupsPerDayIdentity: String {
        "\(breakdown.rawValue)-\(selectedDrink ?? "all")"
    }

    // MARK: Drink mix

    /// Cups per drink for the selected day, or for the four weeks, in the shared drink order. Every drink is
    /// counted at both cafés: the mix compares drinks, so a selected drink is emphasised, not filtered.
    var drinkBars: [DashboardDrinkBar] {
        drinks.map { DashboardDrinkBar(drink: $0, cups: cups(drink: $0, day: selectedDay)) }
    }

    /// For one day the bars are cups a day, the per-day chart's measure, so they share its domain; the four
    /// weeks' totals are another measure, with their own.
    var drinkMixDomain: ClosedRange<Double> {
        selectedDay == nil ? periodDrinkDomain : cupsDomain
    }

    /// "5,558 cups", and ", selected" on the selected drink's bar.
    func drinkBarValue(_ bar: DashboardDrinkBar, locale: Locale) -> String {
        let cups = CafeWording.cups(bar.cups, locale: locale)
        return bar.drink == selectedDrink ? "\(cups), \(Self.selectedWord)" : cups
    }

    /// The drinks drawn at full strength: the selected one, or all.
    var emphasisedDrinks: Set<String> {
        selectedDrink.map { [$0] } ?? Set(drinks)
    }

    var drinkMixIdentity: String {
        selectedDay.map { "\($0.timeIntervalSinceReferenceDate)" } ?? "all"
    }

    // MARK: Weekday rhythm

    /// The average cups of each series on each weekday, Monday first, over every day in the data.
    var heatCells: [DashboardHeatCell] {
        seriesNames.flatMap { series in
            CafeData.weekdays.indices.map { index in
                let matching = days.filter { weekdayIndex(of: $0) == index }
                let total = matching.map { cups(series: series, day: $0) }.reduce(0, +)
                let average = matching.isEmpty ? 0 : Double(total) / Double(matching.count)
                return DashboardHeatCell(weekday: CafeData.weekdays[index], series: series, averageCups: average)
            }
        }
    }

    /// The selected day's weekday as the heat map's axis writes it.
    var selectedWeekday: String? {
        selectedDay.map { CafeData.weekdays[weekdayIndex(of: $0)] }
    }

    /// The row outlined on the heat map: the selected drink, when the rows are drinks. With cafés as rows the
    /// rows already count only that drink.
    var selectedHeatRow: String? {
        breakdown == .drink ? selectedDrink : nil
    }

    /// The heat map's colour domain: the averages its rows show now, rounded out to 10 cups. A colour ramp is
    /// read by comparing shades, so it spans the values drawn rather than starting at zero; on the per-day
    /// chart's 0 to 300 the averages (24 to 59 for mocha alone) used a sliver of the ramp. It follows the
    /// breakdown and the drink, and the subtitle and legend say its range.
    var heatDomain: ClosedRange<Double> {
        let averages = heatCells.map(\.averageCups)
        guard let low = averages.min(), let high = averages.max() else { return 0 ... Double(Self.heatStep) }
        let step = Double(Self.heatStep)
        let lower = (low / step).rounded(.down) * step
        let upper = max((high / step).rounded(.up) * step, lower + step)
        return lower ... upper
    }

    private static let heatStep = 10

    var weekdayIdentity: String {
        cupsPerDayIdentity
    }

    /// "Average cups by weekday and café. Shades from 160 to 260 cups." The range is said because it follows
    /// what the rows show.
    func weekdaySubtitle(locale: Locale) -> String {
        var text = "Average \(CafeWording.cups.lowercased()) by \(CafeWording.weekday.lowercased()) and \(breakdown.seriesLabel.lowercased())"
        if breakdown == .cafe, let selectedDrink { text += ", \(selectedDrink) only" }
        let domain = heatDomain
        let low = Int(domain.lowerBound).formatted(.number.locale(locale))
        let high = CafeWording.cups(Int(domain.upperBound), locale: locale)
        return "\(text). Shades from \(low) to \(high)."
    }

    /// "Monday, Harbour".
    func heatCellLabel(_ cell: DashboardHeatCell, locale: Locale) -> String {
        "\(weekdayName(cell.weekday, locale: locale)), \(cell.series)"
    }

    /// "182 cups on average", and ", selected" in the selected day's weekday column and the selected drink's row.
    func heatCellValue(_ cell: DashboardHeatCell, locale: Locale) -> String {
        let value = "\(CafeWording.cups(cell.roundedCups, locale: locale)) on average"
        let isSelected = cell.weekday == selectedWeekday || cell.series == selectedHeatRow
        return isSelected ? "\(value), \(Self.selectedWord)" : value
    }

    /// Monday is 0, as in `CafeData.weekdays`.
    func weekdayIndex(of day: Date) -> Int {
        (calendar.component(.weekday, from: day) + 5) % 7
    }

    /// The weekday's full name in the locale: "Monday" for "Mon".
    func weekdayName(_ weekday: String, locale: Locale) -> String {
        weekdayName(weekday, locale: locale, width: .wide)
    }

    /// The weekday's narrow name, "M" for "Mon": the heat map's column labels at the accessibility text sizes.
    func narrowWeekdayName(_ weekday: String, locale: Locale) -> String {
        weekdayName(weekday, locale: locale, width: .narrow)
    }

    private func weekdayName(_ weekday: String, locale: Locale, width: Date.FormatStyle.Symbol.Weekday) -> String {
        guard let index = CafeData.weekdays.firstIndex(of: weekday) else { return weekday }
        // 1 March 2026 is a Sunday, so Monday is the day after it.
        let sample = calendar.date(byAdding: .day, value: index + 1, to: CafeData.firstDay) ?? CafeData.firstDay
        return sample.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(width))
    }

    // MARK: Words

    /// "Tuesday, March 17", in the data's time zone.
    func dayName(_ day: Date, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// "March 17", in the data's time zone.
    func shortDayName(_ day: Date, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// "Tuesday, March 17", or "March 1 to March 28" with no day selected.
    func periodText(locale: Locale) -> String {
        if let selectedDay { return dayName(selectedDay, locale: locale) }
        guard let first = days.first, let last = days.last else { return "No days" }
        return "\(shortDayName(first, locale: locale)) to \(shortDayName(last, locale: locale))"
    }

    /// "Harbour, 5,900 cups"; "Harbour and Station, 120 cups each" for a tie; "None sold" when every count is zero.
    private func leaderText(_ counts: [(name: String, cups: Int)], locale: Locale) -> String {
        guard let top = counts.map(\.cups).max(), top > 0 else { return "None sold" }
        let leaders = counts.filter { $0.cups == top }.map(\.name)
        if leaders.count == 1 { return "\(leaders[0]), \(CafeWording.cups(top, locale: locale))" }
        return "\(CafeWording.list(leaders)), \(CafeWording.cups(top, locale: locale)) each"
    }

    private var cafeCounts: [(name: String, cups: Int)] {
        stores.map { ($0, cups(store: $0, drink: selectedDrink, day: selectedDay)) }
    }

    private var drinkCounts: [(name: String, cups: Int)] {
        drinks.map { ($0, cups(drink: $0, day: selectedDay)) }
    }

    /// The day a week before the selected one, and how the selection's cups changed since, when the data has it.
    var weekEarlierChange: (day: Date, difference: Int)? {
        guard let selectedDay,
              let earlier = calendar.date(byAdding: .day, value: -7, to: selectedDay),
              days.contains(earlier) else { return nil }
        return (earlier, selectionTotal - cups(drink: selectedDrink, day: earlier))
    }

    func summary(locale: Locale) -> DashboardSummary {
        let total = selectionTotal
        let change: String
        if selectedDay == nil {
            change = "Select a day to compare it with a week earlier."
        } else if let (earlier, difference) = weekEarlierChange {
            let name = dayName(earlier, locale: locale)
            if difference == 0 {
                change = "The same as \(name)."
            } else {
                change = "\(CafeWording.cups(abs(difference), locale: locale)) \(difference > 0 ? "more" : "fewer") than \(name)."
            }
        } else {
            change = "No day a week earlier in the data."
        }
        return DashboardSummary(
            caption: selectedDrink.map { "\(CafeWording.cups) of \($0)" } ?? CafeWording.cups,
            total: total,
            totalText: CafeWording.cups(total, locale: locale),
            period: periodText(locale: locale),
            change: change,
            busiestCafe: leaderText(cafeCounts, locale: locale),
            busiestDrink: leaderText(drinkCounts, locale: locale)
        )
    }

    // MARK: Headline

    /// One sentence or three for the whole dashboard, true of every panel: the selection's cups, the café
    /// that sold the most of them (and any that sold none), and with every drink shown, the busiest drink.
    func headline(locale: Locale) -> String {
        guard !isEmpty else { return "There are no sales to show." }
        let period = selectedDay.map { "On \(dayName($0, locale: locale))" }
            ?? "From \(periodText(locale: locale))"
        let what = selectedDrink.map { " of \($0)" } ?? ""
        var sentences = ["\(period), \(CafeWording.list(stores)) sold \(CafeWording.cups(selectionTotal, locale: locale))\(what)."]
        let counts = cafeCounts
        if let top = counts.map(\.cups).max(), top > 0 {
            let leaders = counts.filter { $0.cups == top }.map(\.name)
            if leaders.count == 1 {
                sentences.append("\(leaders[0]) sold the most: \(CafeWording.cups(top, locale: locale)).")
            } else {
                sentences.append("\(CafeWording.list(leaders)) sold the same: \(CafeWording.cups(top, locale: locale)) each.")
            }
            let none = counts.filter { $0.cups == 0 }.map(\.name)
            if !none.isEmpty { sentences.append("\(CafeWording.list(none)) sold none.") }
        }
        if selectedDrink == nil, let top = drinkCounts.map(\.cups).max(), top > 0 {
            let leaders = drinkCounts.filter { $0.cups == top }.map(\.name)
            if leaders.count == 1 {
                sentences.append("\(leaders[0]) was the busiest drink: \(CafeWording.cups(top, locale: locale)).")
            } else {
                sentences.append("\(CafeWording.list(leaders)) sold the same: \(CafeWording.cups(top, locale: locale)) each.")
            }
        }
        return sentences.joined(separator: " ")
    }

    /// The longest headline any selection can produce, so the headline keeps one height while the selection moves.
    /// Worked out once per locale.
    func longestHeadline(locale: Locale) -> String {
        if let cached = longestHeadlines[locale.identifier] { return cached }
        let longest = Self.longestHeadline(sales: sales, calendar: calendar, locale: locale)
        longestHeadlines[locale.identifier] = longest
        return longest
    }

    private static func longestHeadline(sales: [DashboardSale], calendar: Calendar, locale: Locale) -> String {
        let probe = DashboardModel(sales: sales, calendar: calendar)
        let days = probe.days
        let drinks = probe.drinks
        var longest = ""
        for day in [nil] + days.map(Optional.some) {
            for drink in [nil] + drinks.map(Optional.some) {
                probe.selectDay(day)
                probe.selectDrink(drink)
                let text = probe.headline(locale: locale)
                if text.count > longest.count { longest = text }
            }
        }
        return longest
    }

    /// What changed, then the headline: the sentence posted when a selection or the breakdown changes.
    func announcement(for change: DashboardChange, locale: Locale) -> String {
        let what = switch change {
        case .day: selectedDay.map { "Showing \(dayName($0, locale: locale))." } ?? "Showing every day."
        case .drink: selectedDrink.map { "Showing \($0) only." } ?? "Showing every drink."
        case .breakdown: "Cups per day by \(breakdown.seriesLabel.lowercased())."
        case .clear: "Showing every day and every drink."
        }
        return "\(what) \(headline(locale: locale))"
    }

    // MARK: Chart descriptors

    func cupsPerDayDescriptor(locale: Locale) -> DashboardCupsPerDayDescriptor {
        let points = dayPoints
        let series = seriesNames.map { name in
            DashboardDescribedSeries(
                name: name,
                values: points.map { point in
                    (shortDayName(point.day, locale: locale), point.values.first { $0.series == name }?.cups ?? 0)
                }
            )
        }
        let highlights = seriesNames.compactMap { name -> String? in
            let values = points.map { point in (point.day, point.values.first { $0.series == name }?.cups ?? 0) }
            guard let top = values.map(\.1).max() else { return nil }
            // Every day that shares the top is named, as the summary names every café that does.
            let topDays = values.filter { $0.1 == top }.map { dayName($0.0, locale: locale) }
            let total = values.map(\.1).reduce(0, +)
            return "\(name): \(CafeWording.cups(total, locale: locale)) in all, highest \(CafeWording.cups(top, locale: locale)) on \(CafeWording.list(topDays))."
        }
        let drinkNote = breakdown == .cafe ? selectedDrink.map { ", \($0) only" } ?? "" : ""
        return DashboardCupsPerDayDescriptor(
            title: "\(CafeWording.cups) per \(CafeWording.day.lowercased()) by \(breakdown.seriesLabel.lowercased())\(drinkNote)",
            summary: "\(CafeWording.days(days.count, locale: locale)), \(periodTextAll(locale: locale)). " + highlights.joined(separator: " "),
            categories: points.map { shortDayName($0.day, locale: locale) },
            series: series,
            cupsDomain: cupsDomain,
            locale: locale
        )
    }

    func drinkMixDescriptor(locale: Locale) -> DashboardDrinkMixDescriptor {
        let bars = drinkBars
        return DashboardDrinkMixDescriptor(
            title: "\(CafeWording.cups) by \(CafeWording.drink.lowercased()), \(periodText(locale: locale))",
            summary: bars.map { "\($0.drink), \(CafeWording.cups($0.cups, locale: locale))" }.joined(separator: "; ") + ".",
            bars: bars.map { ($0.drink, $0.cups) },
            domain: drinkMixDomain,
            locale: locale
        )
    }

    func weekdayDescriptor(locale: Locale) -> DashboardWeekdayDescriptor {
        let cells = heatCells
        let series = seriesNames.map { name in
            DashboardDescribedSeries(
                name: name,
                values: cells.filter { $0.series == name }.map { (weekdayName($0.weekday, locale: locale), $0.roundedCups) }
            )
        }
        let highlights = series.compactMap { row -> String? in
            // The rounded averages are what is spoken, so every weekday that rounds to the top is named.
            guard let top = row.values.map(\.cups).max() else { return nil }
            let topDays = row.values.filter { $0.cups == top }.map(\.category)
            return "\(row.name) busiest on \(CafeWording.list(topDays)), \(CafeWording.cups(top, locale: locale)) on average."
        }
        let drinkNote = breakdown == .cafe ? selectedDrink.map { ", \($0) only" } ?? "" : ""
        return DashboardWeekdayDescriptor(
            title: "Average \(CafeWording.cups.lowercased()) by \(CafeWording.weekday.lowercased()) and \(breakdown.seriesLabel.lowercased())\(drinkNote)",
            summary: highlights.joined(separator: " "),
            categories: CafeData.weekdays.map { weekdayName($0, locale: locale) },
            series: series,
            cupsDomain: heatDomain,
            locale: locale
        )
    }

    /// "March 1 to March 28" whatever is selected.
    private func periodTextAll(locale: Locale) -> String {
        guard let first = days.first, let last = days.last else { return "no days" }
        return "\(shortDayName(first, locale: locale)) to \(shortDayName(last, locale: locale))"
    }

    // MARK: Helpers

    private static func ordered(_ preferred: [String], then found: [String]) -> [String] {
        var result = preferred.filter { found.contains($0) }
        for name in found where !result.contains(name) {
            result.append(name)
        }
        return result
    }

    /// Rounded up to the next multiple of `step`, and at least one step, so empty data still has an axis.
    static func roundedUp(_ value: Int, step: Int) -> Int {
        max(step, (value + step - 1) / step * step)
    }
}
