import Foundation
import Observation

/// One step of the screen: what differs between the two charts, and how much the design changes with it
/// (the table in the skill's `design.md`, *Charts in an app experience*).
nonisolated enum ChartSystemStep: Int, CaseIterable, Hashable {
    case period
    case kindOfData
    case measure

    /// "1" for the first step.
    var number: Int {
        rawValue + 1
    }

    /// The left column of the table: what changed between the two charts.
    var whatChanged: String {
        switch self {
        case .period: "The period"
        case .kindOfData: "The kind of data"
        case .measure: "The measure and how it is represented"
        }
    }

    /// The right column: how much the design changes with it.
    var designChange: String {
        switch self {
        case .period: "The description and the data"
        case .kindOfData: "Also a different colour"
        case .measure: "Also a different mark style"
        }
    }
}

/// What a chart of the system measures. Each measure has one mark and one scale, wherever it is drawn.
nonisolated enum ChartSystemMeasure: Hashable {
    /// Cups of one drink sold each month: bars from zero, on the system's one cups scale.
    case cups
    /// One drink's share of all the cups sold each month, as a percentage: a line with points, 0 to 100.
    case share
}

/// Everything that tells one chart of the system from another: which drink, which months, which measure.
/// The design (colours, scales, axes, marks) is not here: it follows from these three, the same way for every chart.
nonisolated struct ChartSystemChartSpec: Hashable {
    let drink: String
    /// The months shown, as offsets from March 2026 (`CafeData.month(_:)`).
    let months: Range<Int>
    let measure: ChartSystemMeasure

    /// The first day of each month the chart covers.
    var monthDates: [Date] {
        months.map(CafeData.month)
    }
}

/// One month of one chart: where it is drawn, and the cups behind it.
nonisolated struct ChartSystemPoint: Identifiable, Hashable {
    let month: Date
    /// What is drawn: cups, or the percentage of all cups.
    let value: Double
    /// The drink's cups that month, whichever measure is drawn.
    let cups: Int
    /// Which unbroken run of months the point belongs to, so a line breaks at a month with no record.
    let run: Int

    var id: Date {
        month
    }
}

/// The words this screen needs that `CafeWording` does not have.
nonisolated enum ChartSystemWording {
    static let share = "Share of all cups"
    /// The series value that breaks a line at a month with no record. Every point is labelled, so it is not read.
    static let run = "Stretch of months"

    /// "August", in the data's calendar and time zone.
    static func monthName(_ month: Date, locale: Locale) -> String {
        month.formatted(style(locale).month(.wide))
    }

    /// "August 2026", for elements and the Audio Graph.
    static func monthAndYear(_ month: Date, locale: Locale) -> String {
        month.formatted(style(locale).month(.wide).year())
    }

    /// "Mar – Aug 2026": the months a chart covers.
    static func period(_ spec: ChartSystemChartSpec, locale: Locale) -> String {
        guard let first = spec.monthDates.first, let last = spec.monthDates.last else { return "" }
        guard first < last else { return monthAndYear(first, locale: locale) }
        let calendar = CafeData.calendar
        return (first ..< last).formatted(
            Date.IntervalFormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month().year()
        )
    }

    /// "46%": a share of all cups, given from 0 to 100, as the chart and the headline both write it.
    static func percent(_ value: Double, locale: Locale) -> String {
        (value / 100).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// The chart's heading: what it measures, of which drink, over which months.
    static func heading(_ spec: ChartSystemChartSpec, locale: Locale) -> String {
        switch spec.measure {
        case .cups: "\(spec.drink): cups a month, \(period(spec, locale: locale))"
        case .share: "\(spec.drink): share of all cups, \(period(spec, locale: locale))"
        }
    }

    /// "August and December".
    static func months(_ months: [Date], locale: Locale) -> String {
        CafeWording.list(months.map { monthName($0, locale: locale) })
    }

    private static func style(_ locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
    }
}

/// The sample data as the system's charts read it. Pure values, so the descriptor and the tests use it too.
nonisolated struct ChartSystemData {
    let trends: [MonthlyDrinkCups]

    /// The top of the one cups scale every cups chart shares: the app's scale for the drink trends
    /// (`CafeDrinkStyle.trendCupsDomain`), the one Small multiples draws on too, so the same bar height means the
    /// same cups in every chart of the system and on both screens.
    var cupsTop: Double {
        CafeDrinkStyle.trendCupsDomain(for: trends).upperBound
    }

    /// The value axis of a chart, as drawn and as given to its descriptor.
    func valueDomain(for measure: ChartSystemMeasure) -> ClosedRange<Double> {
        switch measure {
        case .cups: 0 ... cupsTop
        case .share: 0 ... 100
        }
    }

    /// Whether any drink sold anything in any month.
    var hasCups: Bool {
        trends.contains { $0.cups > 0 }
    }

    /// The chart's months in order, each with its value. A month with no record, or (for a share) no cups
    /// sold at all, has no point, and the run after it is a new one.
    func points(for spec: ChartSystemChartSpec) -> [ChartSystemPoint] {
        var points: [ChartSystemPoint] = []
        var run = 0
        for month in spec.monthDates {
            guard let record = trends.first(where: { $0.drink == spec.drink && $0.month == month }),
                  let value = value(of: record, measure: spec.measure)
            else {
                if !points.isEmpty { run += 1 }
                continue
            }
            points.append(ChartSystemPoint(month: month, value: value, cups: record.cups, run: run))
        }
        return points
    }

    /// Whether the chart has anything to draw. Bars of zero draw nothing; a share of zero is a point and is drawn.
    func hasMarks(for spec: ChartSystemChartSpec) -> Bool {
        let points = points(for: spec)
        switch spec.measure {
        case .cups: return points.contains { $0.cups > 0 }
        case .share: return !points.isEmpty
        }
    }

    /// The drink's best month or months in cups over the chart's period, or nil when it sold nothing.
    func peak(of spec: ChartSystemChartSpec) -> (months: [Date], cups: Int)? {
        let cupsSpec = ChartSystemChartSpec(drink: spec.drink, months: spec.months, measure: .cups)
        let points = points(for: cupsSpec)
        guard let most = points.map(\.cups).max(), most > 0 else { return nil }
        return (points.filter { $0.cups == most }.map(\.month), most)
    }

    /// The months a chart marks with its value: the drink's best month in cups, the figure the headline names.
    /// A share chart marks the same months, so the two charts can be read against each other.
    func markedMonths(for spec: ChartSystemChartSpec) -> Set<Date> {
        Set(peak(of: spec)?.months ?? [])
    }

    private func value(of record: MonthlyDrinkCups, measure: ChartSystemMeasure) -> Double? {
        switch measure {
        case .cups:
            return Double(record.cups)
        case .share:
            let total = trends.filter { $0.month == record.month }.map(\.cups).reduce(0, +)
            return total > 0 ? Double(record.cups) / Double(total) * 100 : nil
        }
    }
}

/// The two charts of the screen and the step between them.
@Observable
final class ChartSystemViewModel {
    private(set) var step: ChartSystemStep = .period
    let data: ChartSystemData

    /// The drink the first chart always shows, and the other drink the kind-of-data step brings in.
    private let referenceDrink: String
    private let otherDrink: String

    init(trends: [MonthlyDrinkCups] = CafeData.monthlyDrinkTrends) {
        data = ChartSystemData(trends: trends)
        referenceDrink = CafeData.trendDrinks.first ?? ""
        otherDrink = CafeData.trendDrinks.dropFirst().first ?? ""
    }

    /// The first chart: the same in every step, so each step changes only the second.
    var reference: ChartSystemChartSpec {
        ChartSystemChartSpec(drink: referenceDrink, months: 0 ..< 6, measure: .cups)
    }

    /// The second chart: the first with one more thing changed at each step.
    var compared: ChartSystemChartSpec {
        // snippet:a-chart-design-system-pairs
        // The first chart is always Latte's cups, March to August. The second differs from it by one thing,
        // and the design follows from that one thing: the period, the drink (its colour) or the measure (its mark).
        switch step {
        case .period:
            ChartSystemChartSpec(drink: referenceDrink, months: 6 ..< 12, measure: .cups)
        case .kindOfData:
            ChartSystemChartSpec(drink: otherDrink, months: 0 ..< 6, measure: .cups)
        case .measure:
            ChartSystemChartSpec(drink: referenceDrink, months: 0 ..< 6, measure: .share)
        }
        // end
    }

    /// While there are no cups at all, both charts are placeholders and the steps change nothing drawn.
    var canStep: Bool {
        data.hasCups
    }

    var canGoBack: Bool {
        canStep && step != .period
    }

    var canGoForward: Bool {
        canStep && step != .measure
    }

    func goBack() {
        guard canGoBack, let previous = ChartSystemStep(rawValue: step.rawValue - 1) else { return }
        step = previous
    }

    func goForward() {
        guard canGoForward, let next = ChartSystemStep(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    /// "Step 2 of 3".
    var stepTitle: String {
        "Step \(step.number) of \(ChartSystemStep.allCases.count)"
    }

    /// The code worth showing at this step.
    var snippets: [SnippetReference] {
        let pairs = SnippetReference(name: "a-chart-design-system-pairs", title: "What differs between the two charts")
        switch step {
        case .period:
            return [pairs, SnippetReference(name: "a-chart-design-system-one-style", title: "One scale and one axis for every chart")]
        case .kindOfData:
            return [pairs, SnippetReference(name: "a-chart-design-system-colour", title: "One colour for each drink")]
        case .measure:
            return [pairs, SnippetReference(name: "a-chart-design-system-mark", title: "The mark follows the measure")]
        }
    }

    /// The chart's message, true of both charts as they are drawn now.
    func headline(locale: Locale) -> String {
        let first = reference
        let second = compared
        switch step {
        case .period:
            switch (peakPhrase(first, locale: locale), peakPhrase(second, locale: locale)) {
            case let (first?, second?):
                return "\(reference.drink) peaked at \(first), and at \(second)."
            case let (first?, nil):
                return "\(reference.drink) peaked at \(first); none were sold in \(ChartSystemWording.period(second, locale: locale))."
            case let (nil, second?):
                return "\(reference.drink) sold none in \(ChartSystemWording.period(first, locale: locale)), and peaked at \(second)."
            case (nil, nil):
                return "No cups of \(reference.drink) were sold in either period."
            }
        case .kindOfData:
            switch (peakPhrase(first, locale: locale), peakPhrase(second, locale: locale)) {
            case let (first?, second?):
                return "\(reference.drink) peaked at \(first), \(compared.drink) at \(second)."
            case let (first?, nil):
                return "\(reference.drink) peaked at \(first); no \(compared.drink) was sold."
            case let (nil, second?):
                return "No \(reference.drink) was sold; \(compared.drink) peaked at \(second)."
            case (nil, nil):
                return "No cups of \(reference.drink) or \(compared.drink) were sold "
                    + "in \(ChartSystemWording.period(first, locale: locale))."
            }
        case .measure:
            guard let peak = data.peak(of: first) else {
                return "No cups of \(reference.drink) were sold in \(ChartSystemWording.period(first, locale: locale))."
            }
            let shares = data.points(for: second)
                .filter { peak.months.contains($0.month) }
                .map { ChartSystemWording.percent($0.value, locale: locale) }
            let months = ChartSystemWording.months(peak.months, locale: locale)
            let cups = CafeWording.cups(peak.cups, locale: locale)
            if peak.months.count == 1 {
                return "\(reference.drink)'s best month, \(months) with \(cups), was \(CafeWording.list(shares)) of all cups sold."
            }
            return "\(reference.drink)'s best months, \(months) with \(cups) each, were \(CafeWording.list(shares)) of all cups sold."
        }
    }

    /// What VoiceOver hears when a step redraws the second chart: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        "\(stepTitle). \(changeSentence(locale: locale)) \(headline(locale: locale))"
    }

    /// What the step changed in the second chart, in a sentence.
    func changeSentence(locale: Locale) -> String {
        switch step {
        case .period:
            "The second chart now shows \(ChartSystemWording.period(compared, locale: locale)), in the same design."
        case .kindOfData:
            "The second chart now shows \(compared.drink), in its own colour."
        case .measure:
            "The second chart now shows \(compared.drink)'s share of all cups, as a line."
        }
    }

    /// What a reader can check against the two charts at this step.
    func lookFor(locale: Locale) -> String {
        let top = data.cupsTop.formatted(.number.locale(locale))
        let first = CafeDrinkStyle.colourName(for: reference.drink)
        let second = CafeDrinkStyle.colourName(for: compared.drink)
        return switch step {
        case .period:
            "Both charts are \(first) bars on the same 0 to \(top) cups axis; only the headings and the bars' heights differ."
        case .kindOfData:
            "\(compared.drink)'s bars are \(second), on the same 0 to \(top) cups axis; \(reference.drink) stays \(first)."
        case .measure:
            "The share is a line with points on a 0 to 100% axis. It is still \(compared.drink), so it stays \(second), "
                + "and its months line up with the bars above."
        }
    }

    /// "561 cups in August", or nil when the drink sold nothing in the chart's months.
    private func peakPhrase(_ spec: ChartSystemChartSpec, locale: Locale) -> String? {
        guard let peak = data.peak(of: spec) else { return nil }
        return "\(CafeWording.cups(peak.cups, locale: locale)) in \(ChartSystemWording.months(peak.months, locale: locale))"
    }
}
