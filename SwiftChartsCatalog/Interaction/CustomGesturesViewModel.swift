import CoreGraphics
import Foundation
import Observation

/// The three ways the screen lets a reader pick a day.
enum CustomGesturesMode: String, CaseIterable, Identifiable {
    /// `chartXSelection` alone, with the framework's own gesture.
    case builtInDrag
    /// `chartXSelection` with its gesture replaced by a tap, through `chartGesture` and `selectXValue(at:)`.
    case tapToSelect
    /// A tap on a clear view in `chartOverlay`, converted to a date by the proxy.
    case overlay

    var id: Self {
        self
    }

    /// The segment's title.
    var title: String {
        switch self {
        case .builtInDrag: "Built-in drag"
        case .tapToSelect: "Tap to select"
        case .overlay: "Overlay"
        }
    }

    /// What to do in this mode, shown under the picker. It names no direction, so it is true in right to left.
    var instruction: String {
        switch self {
        case .builtInDrag:
            "Touch and hold a day, then drag. The selection ends when you lift your finger."
        case .tapToSelect:
            "Tap a day. chartGesture replaces the built-in gesture, and the selection stays after you lift your finger. A tap on the date labels selects nothing."
        case .overlay:
            "Tap a day. A clear view over the chart converts the position itself, and the selection stays after you lift your finger."
        }
    }

    /// Whether a selection outlives the finger that made it.
    var selectionLastsAfterLift: Bool {
        self != .builtInDrag
    }

    /// Whether the chart's own selection modifier, `chartXSelection`, is on the chart in this mode.
    var usesChartSelection: Bool {
        self != .overlay
    }

    /// The code the mode shows under See Code.
    var snippets: [SnippetReference] {
        let gesture: [SnippetReference] = switch self {
        case .builtInDrag:
            [SnippetReference(name: "custom-gestures-built-in", title: "The built-in gesture: chartXSelection")]
        case .tapToSelect:
            [
                SnippetReference(name: "custom-gestures-tap", title: "Tap to select: chartGesture and selectXValue(at:)"),
                SnippetReference(name: "custom-gestures-plot-origin", title: "Where the plot starts, in the chart's space"),
            ]
        case .overlay:
            [SnippetReference(name: "custom-gestures-overlay", title: "A tap in chartOverlay, converted by the proxy")]
        }
        return gesture + [
            SnippetReference(name: "custom-gestures-snap", title: "Snap the raw date to a day"),
            SnippetReference(name: "custom-gestures-band", title: "A band behind the selected day"),
        ]
    }
}

/// The state and words of the Custom gestures screen. Everything here is a plain value: the selected
/// date, the plot's origin in points. The proxy and the gestures stay in the view.
@Observable
final class CustomGesturesViewModel {
    let sales: [DailySales]
    /// The calendar the days were counted in (UTC). Days are cut and written in it, not the device's.
    let calendar: Calendar

    /// Which gesture the chart uses. Changing it clears the selection, which a tap would otherwise leave behind.
    var mode: CustomGesturesMode = .builtInDrag {
        didSet {
            if mode != oldValue { rawSelection = nil }
        }
    }

    /// The position on the date axis under the finger, exactly as the chart or the overlay reports it:
    /// a date with a time of day, or one beyond the data. `nil` when nothing is selected.
    var rawSelection: Date?

    /// The plot area's top-leading corner in the chart's own coordinate space, read from a
    /// `GeometryReader`. Zero while the value axis is on the trailing edge in left to right;
    /// the width of the axis labels in right to left, where that axis moves to the left.
    var plotOrigin: CGPoint = .zero

    init(sales: [DailySales] = CafeData.harbourSales, calendar: Calendar = CafeData.calendar) {
        self.sales = sales
        self.calendar = calendar
    }

    // snippet:custom-gestures-snap
    /// The raw date snapped to the day that contains it. `nil` for a position beyond the data.
    var selectedDay: DailySales? {
        guard let rawSelection else { return nil }
        return sales.first { calendar.isDate($0.day, inSameDayAs: rawSelection) }
    }

    // end

    /// Whether there is anything to draw: no days, or only zeros, shows a placeholder instead.
    var hasData: Bool {
        sales.contains { $0.cups > 0 }
    }

    /// Every day with the most cups, in data order.
    var busiestDays: [DailySales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    /// Clears the selection, as a tap outside the plot does.
    func clearSelection() {
        rawSelection = nil
    }

    /// A gesture's location turned into a position in the plot area, or `nil` when it falls outside it.
    /// `location` and `plotOrigin` are in the same coordinate space.
    static func plotPosition(of location: CGPoint, plotOrigin: CGPoint, plotSize: CGSize) -> CGPoint? {
        let position = CGPoint(x: location.x - plotOrigin.x, y: location.y - plotOrigin.y)
        guard (0 ... plotSize.width).contains(position.x), (0 ... plotSize.height).contains(position.y) else {
            return nil
        }
        return position
    }

    // MARK: Words

    /// A day written out, in the data's time zone: "Wednesday, March 4".
    func spokenDay(_ day: Date, locale: Locale) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                .weekday(.wide).month(.wide).day()
        )
    }

    /// A day written out without its weekday, in the data's time zone: "March 4".
    func writtenDay(_ day: Date, locale: Locale) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    /// What is said with no sales: how many days had none, or that there are no days at all.
    func noSalesText(locale: Locale) -> String {
        sales.isEmpty ? "No days of sales yet." : "No cups sold in \(CafeWording.days(sales.count, locale: locale))."
    }

    /// The headline: the selected day and its cups while there is a selection, the busiest day otherwise.
    func headline(locale: Locale) -> String {
        guard hasData else { return noSalesText(locale: locale) }
        if let selectedDay {
            return selectionHeadline(for: selectedDay, locale: locale)
        }
        let names = CafeWording.list(busiestDays.map { spokenDay($0.day, locale: locale) })
        let cups = busiestDays.first?.cups ?? 0
        return "Busiest day: \(names), \(CafeWording.cups(cups, locale: locale))."
    }

    /// The headline for one selected day: "Wednesday, March 4: 179 cups."
    func selectionHeadline(for day: DailySales, locale: Locale) -> String {
        "\(spokenDay(day.day, locale: locale)): \(CafeWording.cups(day.cups, locale: locale))."
    }

    /// The longest headline the screen can show, so the chart does not move when a selection changes it.
    func reservedHeadline(locale: Locale) -> String {
        let all = [headline(locale: locale)] + sales.map { selectionHeadline(for: $0, locale: locale) }
        return all.max { $0.count < $1.count } ?? ""
    }

    /// What to say aloud when the mode changes. Only a change that clears a selection changes the
    /// headline, so only that is announced: what changed, then the headline.
    func modeChangeAnnouncement(clearedSelection: Bool, locale: Locale) -> String? {
        guard clearedSelection else { return nil }
        return "Selection cleared. \(headline(locale: locale))"
    }

    // MARK: Audio Graph

    /// The Audio Graph's summary, in actual values.
    func audioGraphSummary(locale: Locale) -> String {
        guard hasData, let first = sales.first, let last = sales.last, let busiest = busiestDays.first else {
            return noSalesText(locale: locale)
        }
        return "\(CafeWording.days(sales.count, locale: locale)), \(writtenDay(first.day, locale: locale)) to \(writtenDay(last.day, locale: locale)). "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), last day \(CafeWording.cups(last.cups, locale: locale)). "
            + "Most: \(CafeWording.list(busiestDays.map { spokenDay($0.day, locale: locale) })), \(CafeWording.cups(busiest.cups, locale: locale))."
    }
}
