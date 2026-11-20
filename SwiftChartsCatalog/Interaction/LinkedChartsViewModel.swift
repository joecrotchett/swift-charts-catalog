import Foundation
import Observation

/// The sample data for this screen. The Harbour café's four weeks as they are; the Station café's
/// records start a week later, on 8 March, so the two charts cover different spans and an inferred
/// x domain would put the same day at different places. Made here from `CafeData.storeSales`,
/// which has both cafés over the same 28 days.
nonisolated enum LinkedChartsData {
    /// The day the Station café's records start, a week after the Harbour café's.
    static let stationFirstRecord = CafeData.day(7)

    static let harbour: StoreSales = CafeData.storeSales[0]

    static let station: StoreSales = {
        let full = CafeData.storeSales[1]
        return StoreSales(store: full.store, days: full.days.filter { $0.day >= stationFirstRecord })
    }()
}

/// The state of the "Linked charts" screen: one selection shared by two charts, and whether the two
/// share one x domain or each infers its own (the mistake).
@Observable
final class LinkedChartsViewModel {
    /// The chart drawn on top, and the one below it.
    let top: StoreSales
    let bottom: StoreSales
    /// The raw x position under the finger in either chart, as `chartXSelection` writes it: a date with a
    /// time of day, or `nil` when no finger is down. Both charts bind to this one value.
    var rawSelection: Date?
    /// The mistake: each chart infers its own x domain from its own days.
    var isShowingOwnDomains = false

    init(top: StoreSales = LinkedChartsData.harbour, bottom: StoreSales = LinkedChartsData.station) {
        self.top = top
        self.bottom = bottom
    }

    var stores: [StoreSales] {
        [top, bottom]
    }

    /// Every day either café has a record for, in order.
    var allDays: [Date] {
        Array(Set(stores.flatMap { $0.days.map(\.day) })).sorted()
    }

    /// The selection snapped to a day of the data: the day the raw position falls in, in the data's calendar.
    /// `nil` when nothing is selected or the position is on no day either café recorded.
    var selectedDay: Date? {
        guard let rawSelection else { return nil }
        let day = CafeData.calendar.startOfDay(for: rawSelection)
        return allDays.contains(day) ? day : nil
    }

    /// The day a chart draws its band behind: the selected day, when that chart has a bar on it.
    func bandDay(for store: StoreSales) -> Date? {
        guard let selectedDay, cups(in: store, on: selectedDay) != nil else { return nil }
        return selectedDay
    }

    func cups(in store: StoreSales, on day: Date) -> Int? {
        store.days.first { $0.day == day }?.cups
    }

    /// The x domain both charts share: from the start of the first day either café recorded to the end of
    /// the last. `nil` with no data.
    var sharedDomain: ClosedRange<Date>? {
        guard let first = allDays.first, let last = allDays.last else { return nil }
        return first ... (CafeData.calendar.date(byAdding: .day, value: 1, to: last) ?? last)
    }

    /// The x domain a chart is given: the shared one, or `nil` in the mistake, where it infers its own.
    var xDomain: ClosedRange<Date>? {
        isShowingOwnDomains ? nil : sharedDomain
    }

    /// The highest daily cups at either café, so both charts' heights compare on one y domain.
    var highestCups: Int {
        stores.flatMap { $0.days.map(\.cups) }.max() ?? 0
    }

    /// Bars grow from zero, so a café with no cups, or none at all, has nothing to draw.
    func hasCups(_ store: StoreSales) -> Bool {
        store.days.contains { $0.cups > 0 }
    }

    /// Nothing to chart at either café: the screen shows a placeholder and disables its toggle.
    var isEmpty: Bool {
        !stores.contains { hasCups($0) }
    }

    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "linked-charts-shared-selection", title: "One selection, two charts"),
            SnippetReference(name: "linked-charts-band", title: "The band behind the selected day"),
            isShowingOwnDomains
                ? SnippetReference(name: "linked-charts-own-domain", title: "The mistake: each chart's own x domain")
                : SnippetReference(name: "linked-charts-shared-domain", title: "One x domain for both charts"),
        ]
    }

    func summary(locale: Locale) -> LinkedChartsSummary {
        LinkedChartsSummary(viewModel: self, locale: locale)
    }

    /// What is said when the toggle redraws the charts on a new x domain: what changed, then the headline.
    func changeAnnouncement(locale: Locale) -> String {
        let summary = summary(locale: locale)
        let change = isShowingOwnDomains
            ? "Each chart now chooses its own x domain from its own days."
            : "Both charts now share one x domain, \(summary.span(sharedDomain))."
        return "\(change) \(summary.headline)"
    }
}

/// Everything the screen writes about its charts, in one locale: the headline, element text and the
/// summaries the Audio Graphs speak. Plain values, so it can be made off the main actor.
nonisolated struct LinkedChartsSummary {
    let top: StoreSales
    let bottom: StoreSales
    let selectedDay: Date?
    let sharedDomain: ClosedRange<Date>?
    let isShowingOwnDomains: Bool
    let highestCups: Int
    let locale: Locale

    @MainActor
    init(viewModel: LinkedChartsViewModel, locale: Locale) {
        top = viewModel.top
        bottom = viewModel.bottom
        selectedDay = viewModel.selectedDay
        sharedDomain = viewModel.sharedDomain
        isShowingOwnDomains = viewModel.isShowingOwnDomains
        highestCups = viewModel.highestCups
        self.locale = locale
    }

    private var dayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.wide).day()
    }

    private var fullDayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
    }

    /// "March 25", in the data's time zone, so the day written is the day drawn.
    func dayText(_ day: Date) -> String {
        day.formatted(dayStyle)
    }

    /// "Wednesday, March 25", for an element's label and the selected headline.
    func fullDayText(_ day: Date) -> String {
        day.formatted(fullDayStyle)
    }

    /// "March 1 to March 28": a domain's days, its last day being the day before its end.
    func span(_ domain: ClosedRange<Date>?) -> String {
        guard let domain else { return "no days" }
        let lastDay = CafeData.calendar.date(byAdding: .day, value: -1, to: domain.upperBound) ?? domain.upperBound
        return "\(dayText(domain.lowerBound)) to \(dayText(lastDay))"
    }

    private func cups(in store: StoreSales, on day: Date) -> Int? {
        store.days.first { $0.day == day }?.cups
    }

    /// Every day a café sold the most, in order. Empty when it sold nothing.
    func busiestDays(_ store: StoreSales) -> [DailySales] {
        guard let most = store.days.map(\.cups).max(), most > 0 else { return [] }
        return store.days.filter { $0.cups == most }
    }

    /// "Harbour on March 28, 282 cups", or "no cups recorded at Station".
    private func busiestPhrase(_ store: StoreSales) -> String {
        let busiest = busiestDays(store)
        guard let cups = busiest.first?.cups else { return "no cups recorded at \(store.store)" }
        let days = CafeWording.list(busiest.map { dayText($0.day) })
        return "\(store.store) on \(days), \(CafeWording.cups(cups, locale: locale))"
    }

    /// "Harbour 231 cups", or "no record at Station".
    private func dayPhrase(_ store: StoreSales, on day: Date) -> String {
        guard let cups = cups(in: store, on: day) else { return "no record at \(store.store)" }
        return "\(store.store) \(CafeWording.cups(cups, locale: locale))"
    }

    /// The headline: both cafés on the selected day, or each café's busiest day when nothing is selected.
    var headline: String {
        if let selectedDay { return headline(selecting: selectedDay) }
        if busiestDays(top).isEmpty, busiestDays(bottom).isEmpty {
            return "No cups recorded at either café."
        }
        return "Busiest days: \(busiestPhrase(top)); \(busiestPhrase(bottom))."
    }

    /// The headline while a day is selected.
    func headline(selecting day: Date) -> String {
        "\(fullDayText(day)): \(dayPhrase(top, on: day)), \(dayPhrase(bottom, on: day))."
    }

    /// The longest headline the screen can show, so the headline keeps one height while a finger moves.
    var reservedHeadline: String {
        let days = Array(Set((top.days + bottom.days).map(\.day)))
        return ([headline] + days.map { headline(selecting: $0) }).max { $0.count < $1.count } ?? headline
    }

    /// An element's value: the café's cups that day, then the other café's, so the comparison the selection
    /// shows is reachable without a gesture.
    func elementValue(for store: StoreSales, day: DailySales) -> String {
        let other = store.id == top.id ? bottom : top
        let otherText = cups(in: other, on: day.day).map { "\(other.store) \(CafeWording.cups($0, locale: locale))" }
            ?? "no record at \(other.store)"
        return "\(CafeWording.cups(day.cups, locale: locale)). Same day: \(otherText)."
    }

    /// The Audio Graph's summary for one café's chart, in actual values, saying which days it is drawn on.
    func audioGraphSummary(for store: StoreSales) -> String {
        guard let first = store.days.first?.day, let last = store.days.last?.day else {
            return "No days recorded at \(store.store)."
        }
        let busiest = busiestDays(store)
        let busiestText = busiest.first.map {
            "Busiest \(CafeWording.list(busiest.map { dayText($0.day) })), \(CafeWording.cups($0.cups, locale: locale))."
        } ?? "No cups sold."
        let ownSpan = first ... (CafeData.calendar.date(byAdding: .day, value: 1, to: last) ?? last)
        let drawnOn = if isShowingOwnDomains {
            ownSpan == sharedDomain
                ? "Drawn on its own days, \(span(ownSpan))."
                : "Drawn on its own days, \(span(ownSpan)), which do not line up with the other chart's days."
        } else {
            "Drawn on the same days as the other chart, \(span(sharedDomain))."
        }
        return "\(CafeWording.days(store.days.count, locale: locale)) recorded, \(dayText(first)) to \(dayText(last)). "
            + "\(busiestText) \(drawnOn)"
    }
}
