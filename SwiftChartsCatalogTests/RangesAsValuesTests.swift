import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct RangesAsValuesTests {
    private let english = Locale(identifier: "en_US")

    /// The time format puts a narrow no-break space before AM and PM; the expected strings are written
    /// with a plain space and converted here.
    private func times(_ text: String) -> String {
        text.replacing(" AM", with: "\u{202F}AM").replacing(" PM", with: "\u{202F}PM")
    }

    private func time(_ hour: Int, _ minute: Int = 0) -> Date {
        CafeData.calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: CafeData.firstDay) ?? .distantPast
    }

    private func summary(_ period: RangesAsValuesPeriod, locale: Locale? = nil) -> RangesAsValuesSummary {
        let model = RangesAsValuesViewModel()
        model.period = period
        return model.summary(locale: locale ?? english)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when it opens, then it shows half hours from the café's sample data")
    func startsWithHalfHours() {
        let model = RangesAsValuesViewModel()

        #expect(model.period == .halfHour)
        #expect(model.halfHours == CafeData.halfHourOrders)
        #expect(model.servicePeriods == CafeData.servicePeriods)
    }

    @Test(
        "Given a period, when the snippets are asked for, then they are the chart's and then that period's ranges",
        arguments: [
            (RangesAsValuesPeriod.halfHour, ["ranges-as-values-chart", "ranges-as-values-half-hours"]),
            (.twoHours, ["ranges-as-values-chart", "ranges-as-values-two-hours"]),
            (.named, ["ranges-as-values-chart", "ranges-as-values-named-periods"]),
        ]
    )
    func snippetsFollowPeriod(period: RangesAsValuesPeriod, names: [String]) {
        let model = RangesAsValuesViewModel()
        model.period = period

        #expect(model.snippets.map(\.name) == names)
    }

    @Test("Given every period, when the snippets are looked up in the bundle, then each one exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let model = RangesAsValuesViewModel()
        for period in RangesAsValuesPeriod.allCases {
            model.period = period
            for snippet in model.snippets {
                #expect(store[snippet.name] != nil, "missing \(snippet.name)")
            }
        }
    }

    // MARK: The bars

    @Test("Given the half-hour data, when it is drawn by half hour, then each bar is a 30-minute range")
    func halfHourBarsAreThirtyMinutes() {
        let bars = RangesAsValuesViewModel().bars

        #expect(bars.count == 24)
        #expect(bars.allSatisfy { $0.time.upperBound.timeIntervalSince($0.time.lowerBound) == 30 * 60 })
        #expect(bars.first?.time == time(6) ..< time(6, 30))
        #expect(bars.last?.time == time(17, 30) ..< time(18))
        #expect(bars.map(\.orders) == CafeData.halfHourOrders.map(\.orders))
    }

    @Test("Given the half-hour data, when it is drawn by two hours, then six ranges from 6 am to 6 pm sum the half hours")
    func twoHourBarsSumHalfHours() {
        let model = RangesAsValuesViewModel()
        model.period = .twoHours

        #expect(model.bars.map(\.time) == stride(from: 6, to: 18, by: 2).map { time($0) ..< time($0 + 2) })
        #expect(model.bars.map(\.orders) == [133, 171, 91, 112, 42, 39])
        #expect(model.bars.map(\.orders).reduce(0, +) == CafeData.halfHourOrders.map(\.orders).reduce(0, +))
    }

    @Test("Given the service periods, when they are drawn, then each bar spans its own period and sums its half hours")
    func namedBarsSpanTheirPeriods() {
        let model = RangesAsValuesViewModel()
        model.period = .named

        #expect(model.bars.map(\.name) == CafeData.servicePeriods.map(\.name))
        #expect(model.bars.map(\.time) == CafeData.servicePeriods.map { $0.start ..< $0.end })
        #expect(model.bars.map(\.orders) == [87, 148, 128, 130, 74, 21])
    }

    @Test("Given a two-hour stretch past the last half hour, when the bars are built, then the last range ends with the data")
    func twoHourBarsStopAtTheData() {
        let rows = (0 ..< 5).map { HalfHourOrders(start: time(6).addingTimeInterval(Double($0) * 1800), orders: 10) }

        let bars = RangesAsValuesData.twoHourBars(rows)

        #expect(bars.map(\.time) == [time(6) ..< time(8), time(8) ..< time(8, 30)])
        #expect(bars.map(\.orders) == [40, 10])
    }

    // MARK: The words

    @Test(
        "Given a period, when the headline is written, then it gives the tallest bar's orders and times",
        arguments: [
            (RangesAsValuesPeriod.halfHour, "The most in one half hour: 57 orders, from 8:00 AM to 8:30 AM."),
            (.twoHours, "The most in one two-hour stretch: 171 orders, from 8:00 AM to 10:00 AM."),
            (.named, "The most in one named period: 148 orders, Morning rush, from 7:30 AM to 9:00 AM."),
        ]
    )
    func headlineFollowsPeriod(period: RangesAsValuesPeriod, headline: String) {
        #expect(summary(period).headline == times(headline))
    }

    @Test(
        "Given a period, when the caption is written, then it says what one bar stands for",
        arguments: [
            (RangesAsValuesPeriod.halfHour, "Orders per half hour"),
            (.twoHours, "Orders per two hours"),
            (.named, "Orders per named period"),
        ]
    )
    func captionFollowsPeriod(period: RangesAsValuesPeriod, caption: String) {
        #expect(summary(period).caption == caption)
    }

    @Test("Given a change of period, when it is announced, then it says what changed and then the headline")
    func announcementSaysWhatChanged() {
        let words = summary(.named)

        #expect(words.announcement == "Showing orders per named period. \(words.headline)")
    }

    @Test("Given two half hours tied for the most, when the headline is written, then it names both and stays true")
    func tieNamesBoth() {
        let rows = [
            HalfHourOrders(start: time(7), orders: 30),
            HalfHourOrders(start: time(7, 30), orders: 12),
            HalfHourOrders(start: time(8), orders: 30),
        ]
        let model = RangesAsValuesViewModel(halfHours: rows, servicePeriods: [])

        #expect(model.summary(locale: english).headline
            == times("The most in one half hour: 30 orders, from 7:00 AM to 7:30 AM and from 8:00 AM to 8:30 AM."))
    }

    @Test(
        "Given no orders or only zeros, when the words are written, then the chart is empty and they say nothing was ordered",
        arguments: [[], [HalfHourOrders(start: Date(timeIntervalSince1970: 0), orders: 0)]]
    )
    func emptySaysSo(rows: [HalfHourOrders]) {
        let words = RangesAsValuesViewModel(halfHours: rows, servicePeriods: []).summary(locale: english)

        #expect(words.isEmpty)
        #expect(words.busiest.isEmpty)
        #expect(words.headline == "No orders taken yet.")
        #expect(words.audioGraphSummary == "No orders taken yet.")
    }

    @Test("Given a named bar, when it is labelled, then the label gives its name and then its times in UTC")
    func labelGivesNameThenTimes() {
        let words = summary(.named)

        #expect(words.bars.map(words.label).first == times("Early, 6:00 AM to 7:30 AM"))
        #expect(summary(.halfHour).bars.map(summary(.halfHour).label).first == times("6:00 AM to 6:30 AM"))
    }

    @Test("Given one order or many, when they are written, then the noun agrees with the number")
    func ordersAgreeInNumber() {
        let words = summary(.halfHour)

        #expect(words.orders(1) == "1 order")
        #expect(words.orders(57) == "57 orders")
    }

    @Test("Given a German locale, when the headline is written, then its numbers and times take that locale")
    func headlineTakesLocale() {
        let german = summary(.twoHours, locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("08:00"))
        #expect(german.orders(1200) == "1.200 orders")
    }

    @Test(
        "Given a period, when the explanation is written, then only the named periods, whose bars differ in width, say height is the total",
        arguments: [(RangesAsValuesPeriod.halfHour, false), (.twoHours, false), (.named, true)]
    )
    func explanationFollowsPeriod(period: RangesAsValuesPeriod, saysHeightIsTotal: Bool) {
        let explanation = summary(period).explanation

        #expect(explanation.hasPrefix("Each bar's x value is a range of dates"))
        #expect(explanation.contains("The height of each bar is its total, not its area") == saysHeightIsTotal)
    }

    // MARK: The Audio Graph

    @Test("Given a single half hour, when the Audio Graph summary is written, then the bar count agrees in number")
    func summaryBarSingular() {
        let row = HalfHourOrders(start: time(8), orders: 4)
        let words = RangesAsValuesViewModel(halfHours: [row], servicePeriods: []).summary(locale: english)

        #expect(words.audioGraphSummary.hasPrefix("1 bar, 4 orders in total."))
    }

    @Test("Given the named periods, when the descriptor is made, then its axes, series and summary describe the bars drawn")
    func descriptorDescribesBars() {
        let words = summary(.named)
        let descriptor = RangesAsValuesChartDescriptor(summary: words).makeChartDescriptor()
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        let yAxis = descriptor.yAxis

        #expect(descriptor.title == "Orders per named period, March 1")
        #expect(xAxis?.title == CafeWording.slot)
        #expect(xAxis?.categoryOrder.first == times("Early, 6:00 AM to 7:30 AM"))
        #expect(xAxis?.categoryOrder.count == 6)
        // The busiest period is 148 orders; the axis is drawn to 150, and the descriptor says the same.
        #expect(yAxis?.range == 0 ... 150)
        #expect(yAxis?.valueDescriptionProvider(1) == "1 order")
        #expect(yAxis?.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == [CafeWording.orders])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 6)
        #expect(descriptor.summary == times("6 bars, 588 orders in total. "
                + "Most: Morning rush, 7:30 AM to 9:00 AM, 148 orders. Fewest: Close, 5:00 PM to 6:00 PM, 21 orders."))
    }
}
