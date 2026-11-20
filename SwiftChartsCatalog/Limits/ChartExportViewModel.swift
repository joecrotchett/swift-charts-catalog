import Foundation
import Observation
import UIKit

/// One way of turning a chart into an image, as the screen tries them.
nonisolated enum ChartExportRoute: CaseIterable, Identifiable, Hashable {
    /// `ImageRenderer` on the scrolling chart exactly as it is on screen.
    case scrollingChart
    /// `ImageRenderer` on a second chart with no scrolling modifiers, its x domain fixed to the visible week.
    case staticTwin
    /// `ImageRenderer` on a `Chart3D`.
    case chart3DRenderer
    /// The same `Chart3D` hosted in a window and drawn with `drawHierarchy`.
    case chart3DWindow
    /// `ImageRenderer` on a 2D chart of the same bean scores: acidity across, body up.
    case flatTwin3D

    var id: Self {
        self
    }

    /// The tile's title.
    var title: String {
        switch self {
        case .scrollingChart: "Scrolling chart, ImageRenderer"
        case .staticTwin: "Static twin, ImageRenderer"
        case .chart3DRenderer: "3D chart, ImageRenderer"
        case .chart3DWindow: "3D chart, window capture"
        case .flatTwin3D: "2D twin of the 3D chart, ImageRenderer"
        }
    }

    /// What the route does, in a sentence.
    var method: String {
        switch self {
        case .scrollingChart:
            "The chart above, with its four scrolling modifiers, handed to ImageRenderer as it is."
        case .staticTwin:
            "A second chart of the same bars without the scrolling modifiers, its x domain fixed to the week in view."
        case .chart3DRenderer:
            "A Chart3D of 60 bean samples handed to ImageRenderer."
        case .chart3DWindow:
            "The same Chart3D in a hosting controller in a window of this app, drawn with drawHierarchy."
        case .flatTwin3D:
            "The bean samples as a 2D scatter plot, acidity across and body up, handed to ImageRenderer."
        }
    }

    /// What this route produced when the screen was built: seen on the iPhone 17 simulator, iOS 27.0.
    var seenWhenBuilt: String {
        switch self {
        case .scrollingChart: ChartExportSeen.scrollingChart
        case .staticTwin: ChartExportSeen.staticTwin
        case .chart3DRenderer: ChartExportSeen.chart3DRenderer
        case .chart3DWindow: ChartExportSeen.chart3DWindow
        case .flatTwin3D: ChartExportSeen.flatTwin3D
        }
    }

    /// Whether the route needs `Chart3D`, so iOS 26.
    var needsChart3D: Bool {
        self == .chart3DRenderer || self == .chart3DWindow
    }

    /// Whether the route gives a real picture of the chart, worth sharing.
    var givesTheChart: Bool {
        switch self {
        case .scrollingChart, .chart3DRenderer: false
        case .staticTwin, .chart3DWindow, .flatTwin3D: true
        }
    }
}

/// What each route produced when the screen was built, written after looking at the renders: the one place
/// to change if a later system draws something else.
nonisolated enum ChartExportSeen {
    static let scrollingChart = "Seen when built: the value axis alone, its grid lines and labels 0 to 300. No bars and no day labels."
    static let staticTwin = "Seen when built: the week in view, its seven bars, the busiest day's figure, the day labels, and the twin's two axis titles, which the scrolling chart on screen does not set."
    static let chart3DRenderer = "Seen when built: a yellow square with a red prohibited sign in place of the chart."
    static let chart3DWindow = "Seen when built: the chart in full, its points, the box of grid lines and the three axis titles."
    static let flatTwin3D = "Seen when built: the scatter plot in full, the three origins apart from each other."
}

/// What one route produced on this device.
nonisolated enum ChartExportOutcome {
    /// The image the route made.
    case image(UIImage)
    /// The route could not run on this system, and why.
    case unavailable(String)
    /// The route ran and gave no image.
    case failed
}

/// One route's result, for one tile.
nonisolated struct ChartExportResult: Identifiable {
    let route: ChartExportRoute
    let outcome: ChartExportOutcome

    var id: ChartExportRoute {
        route
    }

    var image: UIImage? {
        if case let .image(image) = outcome { return image }
        return nil
    }

    /// What the tile's image stands for, for VoiceOver: an exported image is a picture, so it is described
    /// by what the route was seen to produce.
    var imageDescription: String {
        switch outcome {
        case .image: "Exported image. \(route.seenWhenBuilt)"
        case let .unavailable(reason): reason
        case .failed: "No image was made."
        }
    }
}

/// The state of the export screen: the scrolling chart's window, its headline, and the images each route made.
@Observable
final class ChartExportViewModel {
    /// How many days the chart shows at once.
    static let visibleDayCount = 7
    static let secondsPerDay = 24 * 60 * 60
    /// The visible length for `chartXVisibleDomain(length:)`: on a date axis, in seconds.
    static let visibleSeconds = visibleDayCount * secondsPerDay

    let days: [DailySales]
    /// The calendar the days were counted in (UTC): days are cut, and written, in it.
    let calendar: Calendar
    /// The leading edge of the visible window, bound to `chartScrollPosition(x:)`.
    var scrollStart: Date
    /// The images the last export made, in route order. Empty before the first export.
    private(set) var results: [ChartExportResult] = []
    private(set) var isExporting = false
    /// The longest headline for the last locale asked: worked out once per locale, not on every body pass.
    @ObservationIgnored private var reservedHeadlineCache: (locale: Locale, text: String)?

    init(days: [DailySales] = CafeData.harbourSales, calendar: Calendar = CafeData.calendar) {
        self.days = days
        self.calendar = calendar
        // Open on the latest week: the last day minus the visible length.
        let last = days.map(\.day).max() ?? CafeData.firstDay
        let first = days.map(\.day).min() ?? last
        let start = calendar.date(byAdding: .day, value: -(Self.visibleDayCount - 1), to: last) ?? last
        scrollStart = max(first, start)
    }

    var hasData: Bool {
        !days.isEmpty
    }

    /// The visible window: from the scroll position to the position plus the visible length.
    var visibleWindow: ClosedRange<Date> {
        scrollStart ... scrollStart.addingTimeInterval(TimeInterval(Self.visibleSeconds))
    }

    /// The scrolling chart's whole x scale: from the first day to the end of the last, so the visible window
    /// moves along every day and the bound position places it.
    var fullDomain: ClosedRange<Date> {
        guard let first = days.map(\.day).min(), let last = days.map(\.day).max(),
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return visibleWindow }
        return first ... end
    }

    /// The static twin's x domain: the visible window widened to the whole days whose bars are in view, so the
    /// twin draws every bar in full and needs no clipping. A window that rests on midnight is unchanged.
    var twinDomain: ClosedRange<Date> {
        guard let first = daysInView.first?.day, let last = daysInView.last?.day,
              let end = calendar.date(byAdding: .day, value: 1, to: last) else { return visibleWindow }
        return first ... end
    }

    /// The days whose bar is at least half in view: its middle lies inside the window.
    var daysInView: [DailySales] {
        let halfDay = TimeInterval(Self.secondsPerDay / 2)
        return days.filter { visibleWindow.contains($0.day.addingTimeInterval(halfDay)) }
    }

    /// Every day in view that sold the most. More than one on a tie; none when nothing sold.
    var busiestInView: [DailySales] {
        guard let most = daysInView.map(\.cups).max(), most > 0 else { return [] }
        return daysInView.filter { $0.cups == most }
    }

    /// The value axis of the chart, its twin and the descriptor: zero to the highest day plus room for the
    /// label above the busiest bar, rounded up to the next 50 cups (at least 50).
    var cupsAxis: ClosedRange<Double> {
        let highest = Double(days.map(\.cups).max() ?? 0)
        return 0 ... max(50, (highest * 1.15 / 50).rounded(.up) * 50)
    }

    /// "Saturday, March 28", in the data's time zone.
    func dayName(_ day: Date, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// "March 22", in the data's time zone.
    func shortDayName(_ day: Date, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// "March 2026", the x axis title: the month of the window's first day.
    func monthTitle(locale: Locale) -> String {
        let first = daysInView.first?.day ?? scrollStart
        return first.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).year())
    }

    /// The chart's message: the week in view and its busiest day, whose bar carries its figure.
    func headline(locale: Locale) -> String {
        guard let first = daysInView.first, let last = daysInView.last else {
            return hasData ? "No days in view." : "No days to show."
        }
        let range = "\(shortDayName(first.day, locale: locale)) to \(shortDayName(last.day, locale: locale)) in view"
        guard let cups = busiestInView.first?.cups else { return "\(range); no cups sold." }
        let names = CafeWording.list(busiestInView.map { dayName($0.day, locale: locale) })
        // A tie is a fact about the data, not a count that agrees in number.
        let verb = busiestInView.count > 1 ? "the busiest, tied" : "the busiest"
        return "\(range); \(verb), \(names), sold \(CafeWording.cups(cups, locale: locale))."
    }

    /// The longest headline the data can give, so the chart does not move while it scrolls. Worked out once
    /// per locale.
    func reservedHeadline(locale: Locale) -> String {
        if let cache = reservedHeadlineCache, cache.locale == locale { return cache.text }
        let candidates = (0 ..< max(1, days.count)).map { index -> String in
            let probe = ChartExportViewModel(days: days, calendar: calendar)
            probe.scrollStart = days.indices.contains(index) ? days[index].day : scrollStart
            return probe.headline(locale: locale)
        }
        let text = candidates.max { $0.count < $1.count } ?? headline(locale: locale)
        reservedHeadlineCache = (locale, text)
        return text
    }

    /// The calendar and locale the bars are cut and spoken in, as plain values for the chart views.
    func barWords(locale: Locale) -> ChartExportBarWords {
        ChartExportBarWords(calendar: calendar, locale: locale)
    }

    /// What VoiceOver hears for one bar: the day, then its cups.
    func barLabel(_ day: DailySales, locale: Locale) -> String {
        barWords(locale: locale).label(day)
    }

    func barValue(_ day: DailySales, locale: Locale) -> String {
        barWords(locale: locale).value(day)
    }

    // MARK: Exporting

    func beginExport() {
        isExporting = true
    }

    func finishExport(_ results: [ChartExportResult]) {
        self.results = ChartExportRoute.allCases.compactMap { route in results.first { $0.route == route } }
        isExporting = false
    }

    /// Said aloud when the export finishes: the images are below, out of sight.
    func exportAnnouncement(locale: Locale) -> String {
        let made = results.count(where: { $0.image != nil })
        return "Export finished: \(ChartExportWording.images(made, locale: locale)) below."
    }

    func result(for route: ChartExportRoute) -> ChartExportResult? {
        results.first { $0.route == route }
    }

    /// The snippets the screen shows, in order.
    static let snippets = [
        SnippetReference(name: "exporting-an-image-renderer", title: "ImageRenderer"),
        SnippetReference(name: "exporting-an-image-scrolling", title: "The scrolling chart in an image"),
        SnippetReference(name: "exporting-an-image-static-twin", title: "A static twin of a scrolling chart"),
        SnippetReference(name: "exporting-an-image-3d-routes", title: "A 3D chart, behind its availability check"),
        SnippetReference(name: "exporting-an-image-window-capture", title: "Capturing a window"),
        SnippetReference(name: "exporting-an-image-share", title: "Sharing the image"),
    ]
}

/// What VoiceOver hears for each bar, and the calendar its day is cut in: plain values the chart views take
/// instead of the view model.
nonisolated struct ChartExportBarWords {
    /// The calendar the days were counted in (UTC).
    let calendar: Calendar
    let locale: Locale

    /// "Saturday, March 28", in the data's time zone.
    func label(_ day: DailySales) -> String {
        day.day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// "282 cups".
    func value(_ day: DailySales) -> String {
        CafeWording.cups(day.cups, locale: locale)
    }
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum ChartExportWording {
    /// "1 image", "4 images".
    static func images(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) image](inflect: true)", locale: locale).characters)
    }

    // The bean scores' names, from `CafeWording`.
    static let acidity = CafeWording.acidity
    static let body = CafeWording.body
    static let sweetness = CafeWording.sweetness
    static let origin = CafeWording.origin
}
