import CoreGraphics
import Foundation
import Observation

/// The two rectangles a scrolling chart's proxy reports, resolved in the overlay's coordinates.
/// Plain values, so the view model never sees the proxy.
nonisolated struct PlotFramesMeasurement: Equatable {
    /// `plotFrame`: the whole plot, the part scrolled out of view included.
    var plot: CGRect?
    /// `plotContainerFrame`: the visible part of the plot.
    var container: CGRect?
}

/// The state of the "Plot frame and container frame" screen: the days, which frame the border
/// follows, and the frames as last measured.
@MainActor @Observable
final class PlotFramesViewModel {
    /// How many days are visible at once. The rest of the plot is scrolled out of view.
    static let visibleDays = 7
    static let secondsPerDay = 86400

    let days: [DailySales]
    /// `true` draws the border around `plotFrame`; `false` around `plotContainerFrame`.
    var followsPlotFrame = false
    /// The frames as the chart last reported them, or `nil` before it has been laid out.
    private(set) var measurement: PlotFramesMeasurement?

    init(days: [DailySales] = CafeData.harbourSales) {
        self.days = days
    }

    /// Days visible at once: a week, or every day when there are fewer.
    var visibleDayCount: Int {
        min(Self.visibleDays, days.count)
    }

    /// The visible domain's length. On a date axis it is in seconds.
    var visibleSeconds: Int {
        max(visibleDayCount, 1) * Self.secondsPerDay
    }

    /// Whether any bar has a height. With none, the chart shows a placeholder.
    var hasMarks: Bool {
        days.contains { $0.cups > 0 }
    }

    func summary(locale: Locale) -> PlotFramesSummary {
        PlotFramesSummary(days: days, visibleDays: Self.visibleDays, locale: locale)
    }

    func headline(locale: Locale) -> String {
        summary(locale: locale).headline(followsPlotFrame: followsPlotFrame)
    }

    /// What the screen demonstrates, true of the chart as it is now: scrolling, fitting in view, or not drawn.
    var explanation: String {
        let concept = """
        In a scrolling chart, ChartProxy's plotFrame is the whole plot, the days scrolled out of view included, \
        so it moves as the chart scrolls. plotContainerFrame is only the part on screen, and stays put.
        """
        // With no bars the placeholder stands in for the chart: there is nothing to scroll and no border.
        guard hasMarks else { return concept }
        guard days.count > Self.visibleDays else {
            return concept + " Here every day fits in view, so the chart does not scroll and the two frames are "
                + "the same: the border is drawn in the same place whichever frame it follows."
        }
        return concept + " Scroll the chart and watch the border: a fixed border or overlay belongs on the "
            + "container frame. A scrolling chart ignores its chart descriptor, so the Audio Graph is given a "
            + "non-scrolling copy of every day through accessibilityRepresentation, with the descriptor inside."
    }

    /// Said aloud when the toggle moves the border: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        let change = followsPlotFrame ? "Border on plotFrame." : "Border on plotContainerFrame."
        return "\(change) \(headline(locale: locale))"
    }

    /// The snippets for the current setting: the scrolling chart, then the frame the border follows.
    var snippetNames: [String] {
        [
            "plot-frame-and-container-frame-chart",
            followsPlotFrame ? "plot-frame-and-container-frame-plot-frame" : "plot-frame-and-container-frame-container-frame",
        ]
    }

    var snippets: [SnippetReference] {
        snippetNames.map { name in
            switch name {
            case "plot-frame-and-container-frame-chart":
                SnippetReference(name: name, title: "A chart that scrolls")
            case "plot-frame-and-container-frame-plot-frame":
                SnippetReference(name: name, title: "A border on plotFrame")
            default:
                SnippetReference(name: name, title: "A border on plotContainerFrame")
            }
        }
    }

    /// Records the frames the chart reports. Called from the overlay as the chart lays out and scrolls.
    func record(_ measurement: PlotFramesMeasurement) {
        guard measurement != self.measurement else { return }
        self.measurement = measurement
    }

    /// A frame as a line of the readout: "1,092 points wide, at x −340 points", or a dash before layout.
    static func readout(_ rect: CGRect?, locale: Locale) -> String {
        guard let rect else { return "—" }
        let width = CafeWording.points(rect.width.rounded(), locale: locale)
        let x = CafeWording.points(rect.minX.rounded(), locale: locale)
        return "\(width) wide, at x \(x)"
    }
}

/// What the chart says in words: its headline, the bars' labels, and the Audio Graph's summary.
nonisolated struct PlotFramesSummary {
    let days: [DailySales]
    let visibleDays: Int
    /// The locale numbers and dates are written in. The view passes its environment's.
    let locale: Locale

    /// The value axis as drawn and as given to the descriptor: 0 to the most cups, rounded up to a tidy step.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    private var visibleDayCount: Int {
        min(visibleDays, days.count)
    }

    /// True of the chart as drawn, for either frame, and for empty, all-zero and short data.
    func headline(followsPlotFrame: Bool) -> String {
        let all = CafeWording.days(days.count, locale: locale)
        guard !days.isEmpty else { return "No days to chart yet." }
        guard days.contains(where: { $0.cups > 0 }) else { return "No cups sold in \(all)." }
        guard days.count > visibleDays else {
            return "The whole plot, \(all), is in view, so plotFrame and plotContainerFrame are the same."
        }
        let inView = CafeWording.days(visibleDayCount, locale: locale)
        return followsPlotFrame
            ? "All \(all) are inside plotFrame, with \(inView) in view."
            : "Only the \(inView) in view are inside plotContainerFrame, of \(all)."
    }

    /// A day written out in the data's own time zone: "Sunday, March 1".
    func dayName(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// Actual values, no judgement of them.
    var audioGraphSummary: String {
        guard let first = days.first, let last = days.last else { return "No days to chart yet." }
        let highest = days.map(\.cups).max() ?? 0
        let span = "\(CafeWording.days(days.count, locale: locale)), \(dayName(first.day)) to \(dayName(last.day))."
        let values = "First day \(CafeWording.cups(first.cups, locale: locale)), "
            + "last day \(CafeWording.cups(last.cups, locale: locale)), "
            + "highest \(CafeWording.cups(highest, locale: locale))."
        guard days.count > visibleDays else { return "\(span) \(values)" }
        return "\(span) \(values) \(CafeWording.days(visibleDayCount, locale: locale)) are in view at a time; the chart scrolls."
    }
}
