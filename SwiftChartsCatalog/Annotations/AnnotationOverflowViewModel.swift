import Charts
import Foundation
import Observation
import SwiftUI

/// The two axes an overflow strategy is chosen for.
enum AnnotationOverflowAxis: CaseIterable {
    case x
    case y

    /// The axis as the controls and the spoken text name it.
    var title: String {
        switch self {
        case .x: "Across (x)"
        case .y: "Up and down (y)"
        }
    }
}

/// The four strategies the screen compares, one chosen per axis.
enum AnnotationOverflowStrategy: CaseIterable, Identifiable {
    case disabled
    case fitToPlot
    case fitToChart
    case padScale

    var id: Self {
        self
    }

    /// The name shown in the picker, and spoken by it.
    var title: String {
        switch self {
        case .disabled: "Disabled"
        case .fitToPlot: "Fit to plot"
        case .fitToChart: "Fit to chart"
        case .padScale: "Pad scale"
        }
    }

    /// The framework's strategy for this choice.
    var strategy: AnnotationOverflowResolution.Strategy {
        switch self {
        case .disabled: AnnotationOverflowStrategies.disabled
        case .fitToPlot: AnnotationOverflowStrategies.fitToPlot
        case .fitToChart: AnnotationOverflowStrategies.fitToChart
        case .padScale: AnnotationOverflowStrategies.padScale
        }
    }

    /// The snippet that shows this strategy's code.
    var snippetName: String {
        switch self {
        case .disabled: "overflow-disabled"
        case .fitToPlot: "overflow-fit-to-plot"
        case .fitToChart: "overflow-fit-to-chart"
        case .padScale: "overflow-pad-scale"
        }
    }

    /// What this strategy does to a label that would cross the edge on `axis`, as a clause that
    /// follows "Across," or "up and down,".
    func effect(on axis: AnnotationOverflowAxis) -> String {
        switch (self, axis) {
        case (.disabled, .x): "the label stays centred on its point and runs past the edge"
        case (.fitToPlot, .x): "the label slides inward to stay inside the plot"
        case (.fitToChart, .x): "the label slides inward to stay inside the chart, over the axis labels if it must"
        case (.padScale, .x): "the scale grows past the data so the label fits over its point"
        case (.disabled, .y): "it stays above its point and runs past the top"
        case (.fitToPlot, .y): "it moves down to stay inside the plot"
        case (.fitToChart, .y): "it moves down to stay inside the chart"
        case (.padScale, .y): "the scale grows above the data so it fits"
        }
    }
}

/// The strategies as the framework spells them, each in a region of its own for See Code.
private enum AnnotationOverflowStrategies {
    // snippet:overflow-disabled
    /// Leaves the label where it is: past the edge it is cut off or drawn outside the chart.
    static let disabled: AnnotationOverflowResolution.Strategy = .disabled
    // end

    // snippet:overflow-fit-to-plot
    /// Slides the label inward to stay inside the plot area. The scale is unchanged.
    static let fitToPlot: AnnotationOverflowResolution.Strategy = .fit(to: .plot)
    // end

    // snippet:overflow-fit-to-chart
    /// Slides the label inward to stay inside the whole chart, so it may sit over the axis labels.
    static let fitToChart: AnnotationOverflowResolution.Strategy = .fit(to: .chart)
    // end

    // snippet:overflow-pad-scale
    /// Extends the scale past the data until the label fits, centred on its mark.
    static let padScale: AnnotationOverflowResolution.Strategy = .padScale
    // end
}

/// Which day carries the label: the first and last sit at the ends of the x axis.
enum AnnotationOverflowLabelledDay: CaseIterable, Identifiable {
    case first
    case middle
    case last

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .first: "First"
        case .middle: "Middle"
        case .last: "Last"
        }
    }

    /// The index of the labelled day in `count` days, or `nil` when there are none.
    func index(in count: Int) -> Int? {
        guard count > 0 else { return nil }
        return switch self {
        case .first: 0
        case .middle: count / 2
        case .last: count - 1
        }
    }
}

/// The control that changed and the value it had before, for the announcement that follows it.
enum AnnotationOverflowChange {
    case labelledDay(from: AnnotationOverflowLabelledDay)
    case strategy(AnnotationOverflowAxis, from: AnnotationOverflowStrategy)
}

/// The screen's state: which day is labelled and the overflow strategy on each axis.
@Observable
final class AnnotationOverflowViewModel {
    let days: [DailySales]
    var labelledDay = AnnotationOverflowLabelledDay.last
    var xStrategy = AnnotationOverflowStrategy.padScale
    /// Fit to plot, not pad scale, to start: a padded scale's top cannot be read back, so the screen opens on a
    /// chart whose value axis the Audio Graph is given exactly.
    var yStrategy = AnnotationOverflowStrategy.fitToPlot

    init(days: [DailySales] = CafeData.harbourSales) {
        self.days = days
    }

    /// The strategy chosen for `axis`.
    func strategy(on axis: AnnotationOverflowAxis) -> AnnotationOverflowStrategy {
        switch axis {
        case .x: xStrategy
        case .y: yStrategy
        }
    }

    var isEmpty: Bool {
        days.isEmpty
    }

    /// The value axis the chart is given and the descriptor reads: 0 to the most cups, rounded up to a tidy step.
    /// With pad scale on y the chart is left to grow its own scale (it cannot extend a domain you set), so the
    /// drawn top is then above this one by an amount the screen cannot read.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    /// Whether the y scale is left automatic: only under pad scale, which grows it to fit the label.
    var leavesValueScaleAutomatic: Bool {
        yStrategy == .padScale
    }

    /// The day that carries the label, or `nil` when there is no data.
    var labelled: DailySales? {
        labelled(labelledDay)
    }

    /// Whether the labelled day is at either end of the x axis.
    var isAtSideEdge: Bool {
        isAtSideEdge(labelledDay)
    }

    /// Whether the labelled day is the highest point, the one nearest the top of the plot.
    var isHighest: Bool {
        isHighest(labelledDay)
    }

    private func labelled(_ choice: AnnotationOverflowLabelledDay) -> DailySales? {
        choice.index(in: days.count).map { days[$0] }
    }

    private func isAtSideEdge(_ choice: AnnotationOverflowLabelledDay) -> Bool {
        guard let index = choice.index(in: days.count) else { return false }
        return index == 0 || index == days.count - 1
    }

    private func isHighest(_ choice: AnnotationOverflowLabelledDay) -> Bool {
        guard let labelled = labelled(choice), let most = days.map(\.cups).max(), most > 0 else { return false }
        return labelled.cups == most
    }

    /// The room to keep free around the chart for a label that a disabled strategy leaves past its edge,
    /// so it neither covers the headline nor leaves the panel: half the label's width on the side it
    /// overflows, and its height above. The room is outside the chart, so the label still runs past the
    /// chart's edge, as the headline says. Nothing is reserved where the label has room or is moved.
    func reservedRoom(for labelSize: CGSize) -> EdgeInsets {
        var room = EdgeInsets()
        if xStrategy == .disabled, let index = labelledDay.index(in: days.count) {
            if index == 0 { room.leading = labelSize.width / 2 }
            if index == days.count - 1 { room.trailing = labelSize.width / 2 }
        }
        if yStrategy == .disabled, isHighest {
            room.top = labelSize.height
        }
        return room
    }

    /// The days the x axis labels: every week's first day, or every other week's at the accessibility
    /// text sizes, where a label a week would be cut short.
    func axisDays(at size: DynamicTypeSize) -> [Date] {
        let daysPerLabel = size >= .accessibility1 ? 14 : 7
        return days.enumerated().filter { $0.offset.isMultiple(of: daysPerLabel) }.map(\.element.day)
    }

    /// How the x axis writes a day, in UTC as the days were counted: "Mar 8", or the day alone ("8") at
    /// the accessibility text sizes, where the month would crowd the value axis's labels. The caption names the month.
    func axisFormat(at size: DynamicTypeSize, locale: Locale) -> Date.FormatStyle {
        let style = Self.dateStyle(locale: locale)
        return size >= .accessibility1 ? style.day() : style.month(.abbreviated).day()
    }

    /// The day as spoken and written in sentences: "Saturday, March 28", in the data's calendar and time zone.
    func spokenDay(_ day: DailySales, locale: Locale) -> String {
        day.day.formatted(Self.dateStyle(locale: locale).weekday(.wide).month(.wide).day())
    }

    /// The day as the label draws it: "Mar 28", in the data's calendar and time zone.
    func shortDay(_ day: DailySales, locale: Locale) -> String {
        day.day.formatted(Self.dateStyle(locale: locale).month(.abbreviated).day())
    }

    /// The days the chart covers: "March 1 to March 28", or `nil` with no data.
    func period(locale: Locale) -> String? {
        guard let first = days.first?.day, let last = days.last?.day else { return nil }
        let style = Self.dateStyle(locale: locale).month(.wide).day()
        return "\(first.formatted(style)) to \(last.formatted(style))"
    }

    /// The caption over the chart, in the words every screen of these days uses:
    /// "Cups sold each day at the Harbour café, March 1 – 28, 2026".
    func caption(locale: Locale) -> String {
        CafeWording.harbourDaysCaption(from: days.first?.day, to: days.last?.day, locale: locale)
    }

    /// The Audio Graph's title: "Cups sold each day from March 1 to March 28 at the Harbour café".
    func audioGraphTitle(locale: Locale) -> String {
        guard let period = period(locale: locale) else { return "Cups sold each day at the \(CafeWording.harbour) café" }
        return "Cups sold each day from \(period) at the \(CafeWording.harbour) café"
    }

    /// Dates written in the calendar and time zone the days were counted in (UTC), whatever the device's.
    private static func dateStyle(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
    }

    /// The chart's message in one sentence: which day is labelled, and where.
    func headline(locale: Locale) -> String {
        parts(locale: locale, labelledDay: labelledDay, xStrategy: xStrategy, yStrategy: yStrategy).headline
    }

    /// What each strategy that has work to do does to the label, shown under the controls that choose them.
    func effectNote(locale: Locale) -> String {
        parts(locale: locale, labelledDay: labelledDay, xStrategy: xStrategy, yStrategy: yStrategy).effect
    }

    /// The headline, then the effect: what an announcement says after a change.
    func headlineAndEffect(locale: Locale) -> String {
        headlineAndEffect(locale: locale, labelledDay: labelledDay, xStrategy: xStrategy, yStrategy: yStrategy)
    }

    private func headlineAndEffect(
        locale: Locale,
        labelledDay: AnnotationOverflowLabelledDay,
        xStrategy: AnnotationOverflowStrategy,
        yStrategy: AnnotationOverflowStrategy
    ) -> String {
        let parts = parts(locale: locale, labelledDay: labelledDay, xStrategy: xStrategy, yStrategy: yStrategy)
        return parts.effect.isEmpty ? parts.headline : "\(parts.headline) \(parts.effect)"
    }

    /// The headline and the effect for any setting of the controls, so an announcement can tell whether a
    /// change altered them.
    private func parts(
        locale: Locale,
        labelledDay: AnnotationOverflowLabelledDay,
        xStrategy: AnnotationOverflowStrategy,
        yStrategy: AnnotationOverflowStrategy
    ) -> (headline: String, effect: String) {
        guard let labelled = labelled(labelledDay) else { return ("No cups sold in March yet.", "") }
        let isHighest = isHighest(labelledDay)
        let subject = "\(spokenDay(labelled, locale: locale)), \(CafeWording.cups(labelled.cups, locale: locale)),"
        let place = switch labelledDay {
        case .first: "at the start of the x axis"
        case .middle: "in the middle of the x axis"
        case .last: "at the end of the x axis"
        }
        let first = "\(subject) is labelled \(place)\(isHighest ? " and is the highest point" : "")."
        let across = "Across, \(xStrategy.effect(on: .x))"
        let upAndDown = "up and down, \(yStrategy.effect(on: .y))"
        let rest = switch (isAtSideEdge(labelledDay), isHighest) {
        case (true, true): "\(across); \(upAndDown)."
        case (true, false): "\(across); above it there is room, so the y strategy changes nothing."
        case (false, true): "Up and down, \(yStrategy.effect(on: .y)); at the sides there is room, so the x strategy changes nothing."
        case (false, false): "There is room on every side, so neither strategy moves it."
        }
        return (first, rest)
    }

    /// Said after a control changes the chart: what changed, then the headline. `nil` when the headline
    /// is the same as before the change, as for a strategy on an axis with room: the picker speaks its own value.
    func announcement(for change: AnnotationOverflowChange, locale: Locale) -> String? {
        var before = (day: labelledDay, x: xStrategy, y: yStrategy)
        let what: String
        switch change {
        case let .labelledDay(old):
            before.day = old
            what = "Labelled day: \(labelledDay.title)."
        case let .strategy(axis, old):
            switch axis {
            case .x: before.x = old
            case .y: before.y = old
            }
            what = "\(axis.title): \(strategy(on: axis).title)."
        }
        let now = headlineAndEffect(locale: locale)
        let previous = headlineAndEffect(locale: locale, labelledDay: before.day, xStrategy: before.x, yStrategy: before.y)
        guard now != previous else { return nil }
        return "\(what) \(now)"
    }

    /// The code for the labelled point, then the strategy on each axis.
    var snippets: [SnippetReference] {
        var references = [SnippetReference(name: "overflow-annotation", title: "The labelled point")]
        if xStrategy == yStrategy {
            references.append(SnippetReference(name: xStrategy.snippetName, title: "Both axes: \(xStrategy.title)"))
        } else {
            references.append(SnippetReference(name: xStrategy.snippetName, title: "\(AnnotationOverflowAxis.x.title): \(xStrategy.title)"))
            references.append(SnippetReference(name: yStrategy.snippetName, title: "\(AnnotationOverflowAxis.y.title): \(yStrategy.title)"))
        }
        return references
    }

    /// The Audio Graph's summary, in actual values.
    func audioGraphSummary(locale: Locale) -> String {
        guard let first = days.first, let last = days.last, let labelled,
              let highest = days.max(by: { $0.cups < $1.cups })
        else { return "No cups sold in March yet." }
        return "\(CafeWording.days(days.count, locale: locale)). "
            + "First day \(CafeWording.cups(first.cups, locale: locale)), "
            + "last day \(CafeWording.cups(last.cups, locale: locale)), "
            + "highest \(CafeWording.cups(highest.cups, locale: locale)) on \(spokenDay(highest, locale: locale)). "
            + "Labelled: \(spokenDay(labelled, locale: locale))."
    }
}
