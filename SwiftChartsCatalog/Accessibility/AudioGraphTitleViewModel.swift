import Accessibility
import Foundation
import Observation

/// One line of Audio Graph data written out on screen: which part it is, and what it says.
nonisolated struct AudioGraphTitleRow: Identifiable, Hashable {
    let id: String
    let part: String
    let text: String
}

/// Every word this screen speaks or shows about the chart, in one table, so a prediction that proves
/// wrong on a device is replaced in one place: the headline, each element's label and value, the
/// descriptor's title, summary and value descriptions, and the default Audio Graph as read on iOS.
/// Not tied to the main actor: the chart descriptor reads it when the accessibility system asks.
nonisolated struct AudioGraphTitleWords {
    let days: [DailySales]
    /// The locale every number and date is written in. The view passes its environment's.
    let locale: Locale

    // MARK: Words this screen adds

    /// The descriptor's axis titles. They differ on purpose from the chart's `.value` labels
    /// (`CafeWording.day` and `CafeWording.cups`), so someone listening to *Describe chart* can tell
    /// which of the two VoiceOver names the axes from. Not in `CafeWording`, so kept here.
    static let descriptorDateAxisTitle = "Date"
    static let descriptorCupsAxisTitle = "Cups sold"
    /// The descriptor's title. The café's name comes from `CafeWording`.
    static let descriptorTitle = "Cups sold each day at the \(CafeWording.harbour) café"

    // MARK: Dates

    /// The sample days were made as midnight UTC, so they are written in the data's calendar and time zone,
    /// whatever the device's: the spoken day is the day that is drawn.
    var dayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .weekday(.wide).month(.wide).day()
    }

    /// The short form for the axis labels: "Mar 1".
    var axisDayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.abbreviated).day()
    }

    /// The day of the month alone, "1", for the axis at the largest text sizes.
    var axisDayOnlyStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone).day()
    }

    /// "Sunday, March 1".
    func dayName(_ date: Date) -> String {
        date.formatted(dayStyle)
    }

    /// "March 1": a day without its weekday, for the period the chart covers.
    func periodDay(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                .month(.wide).day()
        )
    }

    /// "March 1 to March 7", or "" with no days.
    var period: String {
        guard let first = days.first?.day, let last = days.last?.day else { return "" }
        return "\(periodDay(first)) to \(periodDay(last))"
    }

    // MARK: Figures

    var total: Int {
        days.map(\.cups).reduce(0, +)
    }

    /// The tallest bar, or `nil` when nothing was sold.
    var most: Int? {
        guard total > 0 else { return nil }
        return days.map(\.cups).max()
    }

    /// The shortest bar, or `nil` when nothing was sold.
    var fewest: Int? {
        guard total > 0 else { return nil }
        return days.map(\.cups).min()
    }

    /// Every day with `cups`, in data order, written out and joined: "Saturday, March 7".
    func dayNames(with cups: Int) -> String {
        CafeWording.list(days.filter { $0.cups == cups }.map { dayName($0.day) })
    }

    /// The one value scale: the chart draws it with `chartYScale(domain:)` and the descriptor's y axis
    /// gives the same range, so the Audio Graph's axis is the axis that is drawn. From zero, as bars grow
    /// from it, to the tallest bar rounded up to the next hundred: 0 to 300 for the sample week, the
    /// scale the framework drew by itself.
    var yDomain: ClosedRange<Double> {
        Self.yDomain(for: days)
    }

    static func yDomain(for days: [DailySales]) -> ClosedRange<Double> {
        let step = Double(AudioGraphTitleScale.step)
        let tallest = Double(days.map(\.cups).max() ?? 0)
        return 0 ... max(step, (tallest / step).rounded(.up) * step)
    }

    // MARK: Headline

    /// The chart's message, with a figure the reader can find in the chart. True on a tie, with no days,
    /// and when every day is zero.
    var headline: String {
        guard !days.isEmpty else { return "No days to show." }
        guard let most else { return "No cups sold from \(period)." }
        return "The café sold the most on \(dayNames(with: most)): \(CafeWording.cups(most, locale: locale))."
    }

    // MARK: Elements (the same in both states: the shortfall is the Audio Graph's, not the elements')

    func elementLabel(_ day: DailySales) -> String {
        dayName(day.day)
    }

    func elementValue(_ day: DailySales) -> String {
        CafeWording.cups(day.cups, locale: locale)
    }

    // MARK: The chart descriptor's words

    /// The value description the descriptor's y axis gives every number: "190 cups".
    func valueDescription(_ value: Double) -> String {
        CafeWording.count(value, locale: locale)
    }

    /// Actual values only, no judgement of them.
    var descriptorSummary: String {
        guard !days.isEmpty else { return "No days to show." }
        let span = "\(CafeWording.days(days.count, locale: locale)), \(period)."
        guard let most, let fewest else { return "\(span) No cups sold." }
        return "\(span) \(CafeWording.cups(total, locale: locale)) in total. "
            + "Fewest: \(CafeWording.cups(fewest, locale: locale)) on \(dayNames(with: fewest)). "
            + "Most: \(CafeWording.cups(most, locale: locale)) on \(dayNames(with: most))."
    }

    // MARK: The default Audio Graph, read on iOS 27 (Docs/field-notes/epic-10/wave-1-dumps/agt-off.txt)

    static let defaultTitle = "Chart"
    static let defaultSummary = "None"
    static let defaultXAxis = "\(CafeWording.day), as numbers (seconds since 2001), both ends read as empty"
    static let defaultSeries = "One series with no name, separate values"

    /// "Cups, 0 to 300, the drawn scale, no unit": the default y axis is the drawn scale, `yDomain`.
    var defaultYAxis: String {
        let low = Int(yDomain.lowerBound).formatted(.number.locale(locale))
        let high = Int(yDomain.upperBound).formatted(.number.locale(locale))
        return "\(CafeWording.cups), \(low) to \(high), the drawn scale, no unit"
    }

    /// A point of the default Audio Graph: its value alone, a bare number with no unit (read). How a value
    /// of 1,000 or more is grouped in a locale was not read: this formatting is a prediction.
    func defaultPoint(_ day: DailySales) -> String {
        day.cups.formatted(.number.locale(locale))
    }

    /// The default Audio Graph, as read on iOS.
    var defaultRows: [AudioGraphTitleRow] {
        [
            AudioGraphTitleRow(id: "title", part: "Title", text: Self.defaultTitle),
            AudioGraphTitleRow(id: "summary", part: "Summary", text: Self.defaultSummary),
            AudioGraphTitleRow(id: "x-axis", part: "X axis", text: Self.defaultXAxis),
            AudioGraphTitleRow(id: "y-axis", part: "Y axis", text: defaultYAxis),
            AudioGraphTitleRow(id: "series", part: "Series", text: Self.defaultSeries),
        ] + days.enumerated().map { index, day in
            AudioGraphTitleRow(id: "point-\(index)", part: "Point \(index + 1)", text: defaultPoint(day))
        }
    }
}

/// The step the value scale is rounded up to.
nonisolated enum AudioGraphTitleScale {
    static let step = 100
}

/// The screen's state: which Audio Graph data the chart carries, and the text for both.
@Observable
final class AudioGraphTitleViewModel {
    /// The Harbour café's first week: seven days, one bar each.
    static let sampleWeek = Array(CafeData.harbourSales.prefix(7))

    /// True when the chart carries no descriptor and the Audio Graph gets the framework's default.
    var isShowingDefault = false
    let days: [DailySales]

    init(days: [DailySales] = AudioGraphTitleViewModel.sampleWeek) {
        self.days = days
    }

    func words(locale: Locale) -> AudioGraphTitleWords {
        AudioGraphTitleWords(days: days, locale: locale)
    }

    func descriptor(locale: Locale) -> AudioGraphTitleDescriptor {
        AudioGraphTitleDescriptor(words: words(locale: locale))
    }

    /// No days, or only zeros: bars from zero would draw nothing, so a placeholder replaces the chart.
    var showsPlaceholder: Bool {
        days.map(\.cups).reduce(0, +) == 0
    }

    /// The one value scale, shared by the chart's `chartYScale(domain:)` and the descriptor's y axis.
    var yDomain: ClosedRange<Double> {
        AudioGraphTitleWords.yDomain(for: days)
    }

    /// The default Audio Graph as read on iOS.
    func defaultRows(locale: Locale) -> [AudioGraphTitleRow] {
        words(locale: locale).defaultRows
    }

    /// The descriptor's Audio Graph, read back from the descriptor the chart is given, so the text on
    /// screen cannot say something the descriptor does not.
    func descriptorRows(locale: Locale) -> [AudioGraphTitleRow] {
        Self.rows(from: descriptor(locale: locale).makeChartDescriptor(), days: days)
    }

    /// Writes out a built descriptor: its title, summary, axes, series and every point's spoken text.
    /// A data point's own number cannot be read back, so each point pairs the descriptor's category
    /// with the descriptor's value description of that day's cups.
    static func rows(from descriptor: AXChartDescriptor, days: [DailySales]) -> [AudioGraphTitleRow] {
        let categories = (descriptor.xAxis as? AXCategoricalDataAxisDescriptor)?.categoryOrder ?? []
        let describe = descriptor.yAxis?.valueDescriptionProvider ?? { _ in "" }
        var rows = [
            AudioGraphTitleRow(id: "title", part: "Title", text: descriptor.title ?? ""),
            AudioGraphTitleRow(id: "summary", part: "Summary", text: descriptor.summary ?? ""),
            AudioGraphTitleRow(id: "x-axis", part: "X axis", text: xAxisText(title: descriptor.xAxis.title, categories)),
        ]
        if let yAxis = descriptor.yAxis {
            rows.append(AudioGraphTitleRow(
                id: "y-axis", part: "Y axis",
                text: "\(yAxis.title): \(describe(yAxis.range.lowerBound)) to \(describe(yAxis.range.upperBound))"
            ))
        }
        rows += descriptor.series.enumerated().map { index, series in
            AudioGraphTitleRow(
                id: "series-\(index)", part: "Series",
                text: "\(series.name ?? "No name"), \(series.isContinuous ? "continuous" : "separate values")"
            )
        }
        rows += zip(categories, days).enumerated().map { index, pair in
            AudioGraphTitleRow(
                id: "point-\(index)", part: "Point \(index + 1)", text: "\(pair.0), \(describe(Double(pair.1.cups)))"
            )
        }
        return rows
    }

    /// "Date: Sunday, March 1 to Saturday, March 7", or the title alone with no categories.
    static func xAxisText(title: String, _ categories: [String]) -> String {
        guard let first = categories.first, let last = categories.last else { return title }
        return "\(title): \(first) to \(last)"
    }

    /// The snippets for the current state: the chart, then how the descriptor is attached or left out.
    var snippets: [SnippetReference] {
        let chart = SnippetReference(name: "audio-graph-title-chart", title: "The chart, its elements labelled")
        if isShowingDefault {
            return [chart, SnippetReference(name: "audio-graph-title-default", title: "No descriptor: the default")]
        }
        return [
            chart,
            SnippetReference(name: "audio-graph-title-attach", title: "Attaching the descriptor"),
            SnippetReference(name: "audio-graph-title-descriptor", title: "The chart descriptor"),
        ]
    }
}
