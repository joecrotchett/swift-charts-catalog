import Charts
import Foundation
import Observation

/// Which binning the screen shows.
enum BinningKind: String, CaseIterable, Identifiable {
    case waits = "Wait histogram"
    case weeks = "Weekly totals"

    var id: Self {
        self
    }
}

/// How wide each bar is drawn.
enum BinningBarWidth: String, CaseIterable, Identifiable {
    case touching = "Touching"
    case standard = "Default"

    var id: Self {
        self
    }

    // snippet:binning-bar-width
    /// A bin covers a stretch of the axis, so `.ratio(1)` makes each bar fill its bin and neighbours meet;
    /// `.automatic`, the width a bar gets when none is given, is narrower than the bin and leaves a gap.
    var dimension: MarkDimension {
        switch self {
        case .touching: .ratio(1)
        case .standard: .automatic
        }
    }
    // end
}

/// What changed on the screen, for the announcement that follows it.
enum BinningChange {
    case kind
    case mistake
}

/// One bin of order waits: the seconds it covers and how many orders fall in it.
nonisolated struct BinningWaitBin: Identifiable {
    let range: ChartBinRange<Int>
    let orders: Int

    var id: Int {
        range.lowerBound
    }
}

/// One week of daily cups: the dates it covers and the cups sold in them.
nonisolated struct BinningWeekBin: Identifiable {
    let range: ChartBinRange<Date>
    let cups: Int

    var id: Date {
        range.lowerBound
    }
}

/// The binning functions the screen shows, as plain functions of the data.
nonisolated enum BinningBins {
    // snippet:binning-number-bins
    /// About `desiredCount` bins with round boundaries, and how many waits fall in each.
    /// `NumberBins` may return more or fewer bins than asked for.
    static func waitBins(of waits: [Int], desiredCount: Int) -> [BinningWaitBin] {
        guard let lowest = waits.min(), let highest = waits.max() else { return [] }
        // Data with a single distinct value gives no bins at all: give it a range one second wide.
        let bins = lowest < highest
            ? NumberBins(data: waits, desiredCount: desiredCount)
            : NumberBins(range: lowest ... lowest + 1, desiredCount: desiredCount)
        // index(for:) gives `count`, one past the last bin, for a value equal to the top of the range
        // (read on iOS 27): clamp it into the last bin, or the longest wait is not counted.
        let grouped = Dictionary(grouping: waits) { min(bins.index(for: $0), bins.count - 1) }
        return bins.indices.map { index in
            BinningWaitBin(range: bins[index], orders: grouped[index]?.count ?? 0)
        }
    }

    // end

    // snippet:binning-date-bins
    /// One bin per calendar week, cut in the calendar the days were recorded in, with each week's total.
    static func weekBins(of days: [DailySales], calendar: Calendar) -> [BinningWeekBin] {
        guard let first = days.first?.day, let last = days.last?.day else { return [] }
        let bins = DateBins(unit: .weekOfYear, range: first ... last, calendar: calendar)
        // A last day that starts a new week sits on the range's top, where index(for:) gives `count`,
        // one past the last bin (read on iOS 27): clamp it into the last bin, or its cups are lost.
        let grouped = Dictionary(grouping: days) { min(bins.index(for: $0.day), bins.count - 1) }
        return bins.indices.map { index in
            BinningWeekBin(range: bins[index], cups: grouped[index]?.reduce(0) { $0 + $1.cups } ?? 0)
        }
    }
    // end
}

/// The state of the Binning screen: which binning, how many bins are asked for, how wide the bars
/// are, and whether the mistake is showing.
@Observable
final class BinningViewModel {
    static let binCountRange = 2 ... 24

    var kind: BinningKind = .waits
    /// The number of bins asked of `NumberBins`.
    var desiredBinCount = 8
    var barWidth: BinningBarWidth = .touching
    var isShowingMistake = false

    let waits: [Int]
    let days: [DailySales]
    let calendar: Calendar

    init(
        waits: [Int] = CafeData.orderWaits.map(\.waitSeconds),
        days: [DailySales] = CafeData.tenWeeks,
        calendar: Calendar = CafeData.calendar
    ) {
        self.waits = waits
        self.days = days
        self.calendar = calendar
    }

    /// The line under the bar-width control: why it is disabled in the mistake, and what the default
    /// width draws that the data does not have. None when the bars touch.
    var barWidthFootnote: String? {
        if isShowingMistake { return "A dash has no width to set: the mistake draws no bars." }
        if barWidth == .standard {
            return "At the default width the bars are narrower than their bins and leave gaps the data does not have."
        }
        return nil
    }

    var waitBins: [BinningWaitBin] {
        BinningBins.waitBins(of: waits, desiredCount: desiredBinCount)
    }

    var weekBins: [BinningWeekBin] {
        BinningBins.weekBins(of: days, calendar: calendar)
    }

    /// The number of bins drawn, which can differ from the number asked for.
    var drawnBinCount: Int {
        switch kind {
        case .waits: waitBins.count
        case .weeks: weekBins.count
        }
    }

    func summary(locale: Locale) -> BinningSummary {
        BinningSummary(
            kind: kind, waitBins: waitBins, weekBins: weekBins, timeZone: calendar.timeZone,
            isShowingMistake: isShowingMistake, locale: locale
        )
    }

    /// "8 asked for, 6 drawn": the stepper's visible value.
    func binCountText(locale: Locale) -> String {
        "\(desiredBinCount.formatted(.number.locale(locale))) asked for, "
            + "\(waitBins.count.formatted(.number.locale(locale))) drawn"
    }

    /// What VoiceOver says for the stepper: the setting, then the headline, so a step needs no announcement.
    func binCountSpokenValue(locale: Locale) -> String {
        "\(CafeWording.bins(desiredBinCount, locale: locale)) asked for, "
            + "\(waitBins.count.formatted(.number.locale(locale))) drawn. \(summary(locale: locale).headline)"
    }

    /// What changed, then the headline.
    func announcement(after change: BinningChange, locale: Locale) -> String {
        let headline = summary(locale: locale).headline
        switch change {
        case .kind:
            return kind == .waits
                ? "Showing a histogram of order waits. \(headline)"
                : "Showing weekly totals of cups. \(headline)"
        case .mistake:
            return isShowingMistake
                ? "Showing the mistake: each bin drawn with xStart and xEnd, as a dash at its value. \(headline)"
                : "Showing each bin as a bar. \(headline)"
        }
    }

    /// Changes whenever the element text changes, so VoiceOver reads the new words.
    var chartIdentity: String {
        "\(kind.rawValue)-\(isShowingMistake)-\(desiredBinCount)"
    }

    /// The snippets for the current setting.
    var snippets: [SnippetReference] {
        switch (kind, isShowingMistake) {
        case (.waits, false):
            [
                SnippetReference(name: "binning-number-bins", title: "Bin the waits with NumberBins"),
                SnippetReference(name: "binning-histogram", title: "One bar per bin"),
                SnippetReference(name: "binning-bar-width", title: "Touching or default width"),
            ]
        case (.waits, true):
            [
                SnippetReference(name: "binning-number-bins", title: "Bin the waits with NumberBins"),
                SnippetReference(name: "binning-histogram-mistake", title: "The mistake: xStart and xEnd"),
            ]
        case (.weeks, false):
            [
                SnippetReference(name: "binning-date-bins", title: "Total each week with DateBins"),
                SnippetReference(name: "binning-weekly-bars", title: "One bar per week"),
                SnippetReference(name: "binning-bar-width", title: "Touching or default width"),
            ]
        case (.weeks, true):
            [
                SnippetReference(name: "binning-date-bins", title: "Total each week with DateBins"),
                SnippetReference(name: "binning-weekly-mistake", title: "The mistake: xStart and xEnd"),
            ]
        }
    }
}

/// Where the histogram's wait axis is labelled when the text is too large for the default labels.
nonisolated enum BinningAxis {
    /// Steps a label may be placed at: round numbers only.
    private static let steps = [1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000]

    /// Two round values from `lower` up to three quarters of the way to `upper`, at the smallest step
    /// that gives exactly two. Labels start at their value and run toward the trailing edge, so the
    /// last quarter is kept clear of the value axis there. Falls back to the start and the middle.
    static func sparseLabels(from lower: Int, to upper: Int) -> [Int] {
        guard upper > lower else { return [lower] }
        let limit = upper - (upper - lower) / 4
        for step in steps {
            let first = Int((Double(lower) / Double(step)).rounded(.up)) * step
            let values = Array(stride(from: first, through: limit, by: step))
            if values.count == 2 { return values }
        }
        return [lower, lower + (upper - lower) / 2]
    }
}

/// What the chart says in words: the headline, each element's text, and the Audio Graph's summary.
nonisolated struct BinningSummary {
    let kind: BinningKind
    let waitBins: [BinningWaitBin]
    let weekBins: [BinningWeekBin]
    /// The time zone the days were recorded in, so a week is named by the day that is drawn.
    let timeZone: TimeZone
    let isShowingMistake: Bool
    let locale: Locale

    /// Whether there is anything to draw: no data, or only zeros, is a placeholder.
    var hasData: Bool {
        switch kind {
        case .waits: waitBins.contains { $0.orders > 0 }
        case .weeks: weekBins.contains { $0.cups > 0 }
        }
    }

    /// "150 to 200 seconds".
    func waitRangeText(_ bin: BinningWaitBin) -> String {
        "\(bin.range.lowerBound.formatted(.number.locale(locale))) to "
            + CafeWording.seconds(bin.range.upperBound, locale: locale)
    }

    /// "Sunday, March 1", in the data's time zone and the view's locale.
    func weekStartText(_ bin: BinningWeekBin) -> String {
        bin.range.lowerBound.formatted(
            Date.FormatStyle(locale: locale, timeZone: timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// "Week starting Sunday, March 1": the element's label and the descriptor's category.
    func weekLabel(_ bin: BinningWeekBin) -> String {
        "Week starting \(weekStartText(bin))"
    }

    /// An element's value: the count, or, in the mistake, what is actually drawn.
    func waitValue(_ bin: BinningWaitBin) -> String {
        let orders = CafeWording.orders(bin.orders, locale: locale)
        return isShowingMistake ? "A dash at \(orders), no bar" : orders
    }

    func weekValue(_ bin: BinningWeekBin) -> String {
        let cups = CafeWording.cups(bin.cups, locale: locale)
        return isShowingMistake ? "A dash at \(cups), no bar" : cups
    }

    var tallestWaitBins: [BinningWaitBin] {
        guard let most = waitBins.map(\.orders).max(), most > 0 else { return [] }
        return waitBins.filter { $0.orders == most }
    }

    var tallestWeekBins: [BinningWeekBin] {
        guard let most = weekBins.map(\.cups).max(), most > 0 else { return [] }
        return weekBins.filter { $0.cups == most }
    }

    /// The count axis as drawn, from zero to the tallest bin rounded up to the axis step (11 orders → 15): the
    /// chart's scale and the descriptor's range.
    var waitCountDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: waitBins.map(\.orders))
    }

    /// The cups axis as drawn for the weekly bins, from zero to the busiest week rounded up.
    var weekCupsDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: weekBins.map(\.cups))
    }

    /// The label written over a bin the headline names, whose edges the axis may not label: "150–200 s".
    func waitCallout(_ bin: BinningWaitBin) -> String {
        "\(bin.range.lowerBound.formatted(.number.locale(locale)))–\(bin.range.upperBound.formatted(.number.locale(locale))) s"
    }

    /// The label written over a week the headline names, which the axis may not label: "From Mar 22".
    func weekCallout(_ bin: BinningWeekBin) -> String {
        "From \(bin.range.lowerBound.formatted(Date.FormatStyle(locale: locale, timeZone: timeZone).month(.abbreviated).day()))"
    }

    /// The chart's message in a sentence, true of what is drawn: ties, the mistake and no data included.
    var headline: String {
        switch kind {
        case .waits:
            guard let orders = tallestWaitBins.first?.orders else { return "No orders to bin yet." }
            let ranges = CafeWording.list(tallestWaitBins.map(waitRangeText))
            let count = CafeWording.orders(orders, locale: locale)
            if isShowingMistake {
                return "Drawn with xStart and xEnd, each bin is a dash at its count: the highest, "
                    + "\(ranges), sits at \(count)\(tallestWaitBins.count > 1 ? " each" : "")."
            }
            return tallestWaitBins.count > 1
                ? "The most common waits were \(ranges): \(count) each."
                : "The most common wait was \(ranges): \(count)."
        case .weeks:
            guard let cups = tallestWeekBins.first?.cups else { return "No cups sold in these weeks." }
            let weeks = CafeWording.list(tallestWeekBins.map(weekStartText))
            let count = CafeWording.cups(cups, locale: locale)
            if isShowingMistake {
                return "Drawn with xStart and xEnd, each week is a dash at its total: the highest, "
                    + "starting \(weeks), sits at \(count)\(tallestWeekBins.count > 1 ? " each" : "")."
            }
            return tallestWeekBins.count > 1
                ? "The busiest weeks, starting \(weeks), sold \(count) each."
                : "The busiest week, starting \(weeks), sold \(count)."
        }
    }

    /// Actual values only, for the Audio Graph.
    var audioGraphSummary: String {
        guard hasData else { return headline }
        let drawing = isShowingMistake ? "Drawn as a dash at each value, with no bars. " : ""
        switch kind {
        case .waits:
            let total = waitBins.map(\.orders).reduce(0, +)
            let fewest = waitBins.map(\.orders).min() ?? 0
            let fewestBins = waitBins.filter { $0.orders == fewest }
            let first = waitBins.first?.range.lowerBound ?? 0
            let last = waitBins.last?.range.upperBound ?? 0
            return drawing
                + "\(CafeWording.orders(total, locale: locale)) in \(CafeWording.bins(waitBins.count, locale: locale)) "
                + "from \(first.formatted(.number.locale(locale))) to \(CafeWording.seconds(last, locale: locale)). "
                + "Most: \(CafeWording.list(tallestWaitBins.map(waitRangeText))), "
                + "\(CafeWording.orders(tallestWaitBins.first?.orders ?? 0, locale: locale)). "
                + "Fewest: \(CafeWording.list(fewestBins.map(waitRangeText))), \(CafeWording.orders(fewest, locale: locale))."
        case .weeks:
            let total = weekBins.map(\.cups).reduce(0, +)
            let fewest = weekBins.map(\.cups).min() ?? 0
            let fewestBins = weekBins.filter { $0.cups == fewest }
            return drawing
                + "\(CafeWording.weeks(weekBins.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
                + "Most: week starting \(CafeWording.list(tallestWeekBins.map(weekStartText))), "
                + "\(CafeWording.cups(tallestWeekBins.first?.cups ?? 0, locale: locale)). "
                + "Fewest: week starting \(CafeWording.list(fewestBins.map(weekStartText))), "
                + "\(CafeWording.cups(fewest, locale: locale))."
        }
    }
}
