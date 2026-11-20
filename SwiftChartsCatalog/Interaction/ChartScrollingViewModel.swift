import Accessibility
import Charts
import Foundation
import Observation
import SwiftUI

/// How much of the ten weeks the chart shows at once.
nonisolated enum ChartScrollingLength: Int, CaseIterable, Identifiable, Hashable {
    case oneWeek = 7
    case twoWeeks = 14
    case fourWeeks = 28

    var id: Int {
        rawValue
    }

    var days: Int {
        rawValue
    }

    /// The visible domain's length. On a date axis it is given in seconds; the data's calendar is UTC,
    /// which has no daylight saving, so every day is 86,400 seconds long.
    var seconds: Int {
        days * ChartScrollingSummary.secondsPerDay
    }

    /// "1 week", "2 weeks", "4 weeks".
    func title(locale: Locale) -> String {
        CafeWording.weeks(days / 7, locale: locale)
    }
}

/// Where a slow drag comes to rest: the date components the leading edge must match.
nonisolated enum ChartScrollingRest: String, CaseIterable, Identifiable, Hashable {
    case day
    case week

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .day: "Each day"
        case .week: "Each Sunday"
        }
    }

    // snippet:scrolling-rest-components
    /// The components a resting place must match. The sample dates are midnights in UTC, so the
    /// components name the data's calendar and time zone, which says which midnight is meant. (On a
    /// simulator at UTC−6 the chart rested on UTC midnights with or without them.)
    var components: DateComponents {
        let calendar = ChartScrollingSummary.calendar
        return switch self {
        // Any midnight: the window starts on a whole day.
        case .day: DateComponents(calendar: calendar, timeZone: calendar.timeZone, hour: 0)
        // Only a Sunday's midnight (weekday 1 in the Gregorian calendar): whole weeks.
        case .week: DateComponents(calendar: calendar, timeZone: calendar.timeZone, hour: 0, weekday: 1)
        }
    }
    // end
}

/// Where a swipe, as opposed to a slow drag, lands.
nonisolated enum ChartScrollingMajorAlignment: String, CaseIterable, Identifiable, Hashable {
    /// No major alignment: only the matching components apply.
    case none
    /// One visible window on.
    case page
    /// The next first of a month.
    case month

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .none: "Any match"
        case .page: "Next page"
        case .month: "1st of month"
        }
    }
}

/// Whether one gesture is limited in how far it can travel.
nonisolated enum ChartScrollingLimit: String, CaseIterable, Identifiable, Hashable {
    case automatic
    case always
    case never

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .always: "Always"
        case .never: "Never"
        }
    }
}

/// One week of the data: the portion one accessibility element describes.
nonisolated struct ChartScrollingWeek: Identifiable, Hashable {
    let days: [DailySales]
    /// "March 1 to March 7".
    let label: String
    /// "1,234 cups; lowest day 140 cups, highest 230 cups".
    let value: String

    var id: Date {
        days.first?.day ?? .distantPast
    }
}

/// What the chart says in words for one scroll position: the visible window, its headline, the
/// weekly elements and the Audio Graph's summary. Plain values in, plain text out, so tests can set
/// a position and read what the screen would say.
nonisolated struct ChartScrollingSummary {
    static let calendar = CafeData.calendar
    static let secondsPerDay = 86400

    let days: [DailySales]
    /// The leading edge of the visible window: the bound scroll position.
    let position: Date
    let visibleDays: Int
    /// The locale every date and count is written in. It has no default: the view passes its environment's.
    let locale: Locale

    /// No data, or only zeros: bars that grow from zero would draw nothing.
    var hasNoSales: Bool {
        days.allSatisfy { $0.cups == 0 }
    }

    /// The whole x axis: from the first day's midnight to the end of the last day.
    var domain: ClosedRange<Date>? {
        Self.domain(of: days)
    }

    /// The value axis as drawn, rounded up to the next 50 cups (at least 50). Set on the chart and passed to the
    /// descriptor, which cannot read an automatic axis's rounded ends.
    var cupsAxis: ClosedRange<Double> {
        0 ... max(50, (Double(days.map(\.cups).max() ?? 0) / 50).rounded(.up) * 50)
    }

    static func domain(of days: [DailySales]) -> ClosedRange<Date>? {
        guard let first = days.first?.day, let last = days.last?.day,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return nil }
        return first ... end
    }

    // snippet:scrolling-window
    /// The window is from the bound position, its leading edge, to the position plus the visible length.
    var windowEnd: Date {
        position.addingTimeInterval(TimeInterval(visibleDays * Self.secondsPerDay))
    }

    /// The days in view: those whose bar is at least half inside the window. When scrolling rests on
    /// midnights that is every bar fully in view; with snapping off, a bar cut in half or less is left out.
    var visibleSales: [DailySales] {
        days.filter { day in
            let middle = day.day.addingTimeInterval(TimeInterval(Self.secondsPerDay / 2))
            return middle >= position && middle < windowEnd
        }
    }

    // end

    var visibleTotal: Int {
        visibleSales.map(\.cups).reduce(0, +)
    }

    /// What is said with no sales: how many days had none, or that there are no days at all.
    var noSalesText: String {
        days.isEmpty ? "No days of sales yet." : "No cups sold in \(CafeWording.days(days.count, locale: locale))."
    }

    /// The headline: the window's first and last day, how many days, and the cups sold in them.
    var headline: String {
        if hasNoSales { return noSalesText }
        let visible = visibleSales
        guard let first = visible.first?.day, let last = visible.last?.day else { return "No days in view." }
        let range = first == last ? long(first) : "\(long(first)) to \(long(last))"
        return "\(range): \(CafeWording.days(visible.count, locale: locale)), \(CafeWording.cups(visibleTotal, locale: locale))."
    }

    /// The window written out for what is spoken: "March 1 to March 14, 14 days and 2,461 cups".
    var spokenWindow: String {
        let visible = visibleSales
        guard let first = visible.first?.day, let last = visible.last?.day else { return "no days" }
        let range = first == last ? long(first) : "\(long(first)) to \(long(last))"
        return "\(range), \(CafeWording.days(visible.count, locale: locale)) and \(CafeWording.cups(visibleTotal, locale: locale))"
    }

    /// The longest the headline gets, laid out unseen so the chart does not move while it scrolls: the
    /// longest of the headlines at every day the window can start on, for this visible length and locale.
    /// Measured in characters, which follows the width closely enough for the headline to keep its height.
    var reservedHeadline: String {
        let starts = days.count > visibleDays ? days[0 ... days.count - visibleDays].map(\.day) : [position]
        let headlines = starts.map { start in
            ChartScrollingSummary(days: days, position: start, visibleDays: visibleDays, locale: locale).headline
        }
        return headlines.max { $0.count < $1.count } ?? headline
    }

    /// One element per week, the data being longer than a month of single days (`accessibility.md`).
    /// The sample data starts on a Sunday, so each portion is a week from Sunday to Saturday.
    var weeks: [ChartScrollingWeek] {
        stride(from: 0, to: days.count, by: 7).map { start in
            let portion = Array(days[start ..< min(start + 7, days.count)])
            let cups = portion.map(\.cups)
            let firstDay = portion.first?.day ?? .distantPast
            let lastDay = portion.last?.day ?? .distantPast
            let label = firstDay == lastDay ? long(firstDay) : "\(long(firstDay)) to \(long(lastDay))"
            let total = CafeWording.cups(cups.reduce(0, +), locale: locale)
            let lowest = CafeWording.cups(cups.min() ?? 0, locale: locale)
            let highest = CafeWording.cups(cups.max() ?? 0, locale: locale)
            return ChartScrollingWeek(days: portion, label: label, value: "\(total); lowest day \(lowest), highest \(highest)")
        }
    }

    /// Actual values only: the whole span, what is in view, and the lowest and highest day.
    var audioGraphSummary: String {
        guard !hasNoSales, let first = days.first?.day, let last = days.last?.day,
              let lowest = days.min(by: { $0.cups < $1.cups }),
              let highest = days.max(by: { $0.cups < $1.cups })
        else { return noSalesText }
        return "\(CafeWording.days(days.count, locale: locale)), \(long(first)) to \(long(last)). "
            + "In view: \(spokenWindow). "
            + "Lowest day \(CafeWording.cups(lowest.cups, locale: locale)) on \(long(lowest.day)), "
            + "highest \(CafeWording.cups(highest.cups, locale: locale)) on \(long(highest.day))."
    }

    /// "March 1", in the data's time zone, for what is spoken.
    func long(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale, calendar: Self.calendar, timeZone: Self.calendar.timeZone).month(.wide).day())
    }
}

/// The screen's state: the visible length, the bound scroll position and the snapping choices.
@Observable
final class ChartScrollingViewModel {
    let days: [DailySales]
    var visibleLength: ChartScrollingLength = .twoWeeks
    /// The leading edge of the visible window. The chart writes it as it scrolls; the Earlier and Later
    /// buttons write it too, and the chart follows.
    var scrollPosition: Date
    var isSnapping = true
    var restingPoint: ChartScrollingRest = .day
    var majorAlignment: ChartScrollingMajorAlignment = .none
    var limitBehavior: ChartScrollingLimit = .automatic

    init(days: [DailySales] = CafeData.tenWeeks) {
        self.days = days
        scrollPosition = days.first?.day ?? CafeData.firstDay
    }

    func summary(locale: Locale) -> ChartScrollingSummary {
        ChartScrollingSummary(days: days, position: scrollPosition, visibleDays: visibleLength.days, locale: locale)
    }

    /// The furthest the leading edge can go: one visible length before the end of the data.
    var latestPosition: Date {
        guard let domain = ChartScrollingSummary.domain(of: days) else { return scrollPosition }
        let latest = domain.upperBound.addingTimeInterval(-TimeInterval(visibleLength.seconds))
        return max(domain.lowerBound, latest)
    }

    var earliestPosition: Date {
        ChartScrollingSummary.domain(of: days)?.lowerBound ?? scrollPosition
    }

    var canShowEarlier: Bool {
        scrollPosition > earliestPosition
    }

    var canShowLater: Bool {
        scrollPosition < latestPosition
    }

    /// Keeps the window inside the data, as after the visible length grows near the end.
    func clampPosition() {
        scrollPosition = min(max(scrollPosition, earliestPosition), latestPosition)
    }

    /// Moves the window one visible length earlier, without a gesture.
    func showEarlier() {
        scrollPosition = max(scrollPosition.addingTimeInterval(-TimeInterval(visibleLength.seconds)), earliestPosition)
    }

    /// Moves the window one visible length later, without a gesture.
    func showLater() {
        scrollPosition = min(scrollPosition.addingTimeInterval(TimeInterval(visibleLength.seconds)), latestPosition)
    }

    /// Said after Earlier or Later: what changed, then the headline.
    func moveAnnouncement(earlier: Bool, locale: Locale) -> String {
        "Showing \(earlier ? "earlier" : "later") days. \(summary(locale: locale).headline)"
    }

    /// Said when the visible length changes: what changed, then the headline.
    func lengthAnnouncement(locale: Locale) -> String {
        "Showing \(visibleLength.title(locale: locale)) at a time. \(summary(locale: locale).headline)"
    }

    /// The snippets for the current setting.
    var snippets: [SnippetReference] {
        var snippets = [
            SnippetReference(name: "scrolling-chart", title: "The scrolling modifiers"),
            SnippetReference(name: "scrolling-window", title: "The visible window from the position"),
            SnippetReference(name: "scrolling-representation", title: "What the Audio Graph gets"),
        ]
        if isSnapping {
            snippets += [
                SnippetReference(name: "scrolling-value-aligned", title: "Where scrolling rests"),
                SnippetReference(name: "scrolling-rest-components", title: "Matching date components"),
            ]
        } else {
            snippets.append(SnippetReference(name: "scrolling-free", title: "No snapping"))
        }
        return snippets
    }
}

/// The chart for the Audio Graph: every day of the ten weeks, with the window in view in the summary.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ChartScrollingChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ChartScrollingSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let days = summary.days
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.long($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: days.map { AXDataPoint(x: summary.long($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the \(CafeWording.harbour) café over ten weeks, a scrolling chart",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
