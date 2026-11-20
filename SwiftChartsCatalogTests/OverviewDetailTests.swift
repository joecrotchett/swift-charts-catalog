import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct OverviewDetailTests {
    private let locale = Locale(identifier: "en_US")

    /// Every run of digits in a text, with grouping separators removed: "5,726 cups" gives "5726".
    private func numbers(in text: String) -> [String] {
        text.replacing(",", with: "").split { !$0.isNumber }.map(String.init)
    }

    private func numbers(in headline: OverviewDetailHeadline) -> [String] {
        numbers(in: headline.caption) + numbers(in: headline.figure) + numbers(in: headline.period)
    }

    // MARK: States

    @Test("Given a new screen, when it opens, then the detail is closed and nothing is selected")
    func startsClosed() {
        let viewModel = OverviewDetailViewModel()

        #expect(!viewModel.isShowingDetail)
        #expect(viewModel.rawSelectedDate == nil)
        #expect(viewModel.selectedDay == nil)
        #expect(viewModel.hasChart)
    }

    @Test("Given the overview, when it is tapped, then the detail opens")
    func tapOpensDetail() {
        let viewModel = OverviewDetailViewModel()

        viewModel.openDetail()

        #expect(viewModel.isShowingDetail)
    }

    @Test("Given no days or only zeros, when the overview is tapped, then nothing opens and the message says why")
    func emptyDoesNotOpen() {
        let zeros = CafeData.harbourSales.map { DailySales(day: $0.day, cups: 0) }
        for days in [[], zeros] {
            let viewModel = OverviewDetailViewModel(days: days)

            viewModel.openDetail()

            #expect(!viewModel.isShowingDetail)
            #expect(!viewModel.hasChart)
            #expect(viewModel.summary(locale: locale).message == "No cups sold in these days, so there is no chart to open.")
            #expect(viewModel.summary(locale: locale).spoken.descriptorSummary == "No cups sold in these days.")
        }
    }

    // MARK: Headlines

    @Test("Given no selection, when both headlines are written, then they agree on every number they share")
    func headlinesAgreeAtRest() {
        let viewModel = OverviewDetailViewModel()
        let compact = viewModel.compactHeadline(locale: locale)
        let detail = viewModel.detailHeadline(locale: locale)

        #expect(compact == detail)
        #expect(numbers(in: compact) == numbers(in: detail))
        #expect(compact.figure == "5,726 cups")
        // The interval format puts thin spaces around its dash; compare its words.
        #expect(compact.period.split(whereSeparator: \.isWhitespace).joined(separator: " ") == "Mar 1 – 28, 2026", "\(compact.period.unicodeScalars.map { String($0.value, radix: 16) })")
        #expect(numbers(in: compact).contains("5726"))
    }

    @Test("Given the overview's spoken value, when it is compared with both headlines, then the total is the same")
    func spokenTotalMatchesHeadlines() {
        let viewModel = OverviewDetailViewModel()
        let spoken = viewModel.summary(locale: locale).spoken

        #expect(spoken.compactValue == viewModel.compactHeadline(locale: locale).figure)
        #expect(spoken.compactValue == viewModel.detailHeadline(locale: locale).figure)
        #expect(spoken.compactLabel == "Total at Harbour, March 1 to March 28, 2026")
        #expect(OverviewDetailSpokenText.source == "Read on the iPhone 17 simulator, iOS 27")
    }

    @Test("Given a raw position during a day, when the detail is selected, then it snaps to that day and the headline names it")
    func selectionSnapsAndHeadlineFollows() throws {
        let viewModel = OverviewDetailViewModel()
        let lastDay = try #require(CafeData.harbourSales.last)
        viewModel.rawSelectedDate = lastDay.day.addingTimeInterval(7 * 3600)

        #expect(viewModel.selectedDay == lastDay)
        let headline = viewModel.detailHeadline(locale: locale)
        #expect(headline.caption == "Selected day")
        #expect(headline.figure == "282 cups")
        #expect(headline.period == "Saturday, Mar 28, 2026")
        #expect(viewModel.isEmphasised(lastDay))
        #expect(!viewModel.isEmphasised(CafeData.harbourSales[0]))
        // The overview is not changed by the detail's selection.
        #expect(viewModel.compactHeadline(locale: locale).figure == "5,726 cups")
    }

    @Test("Given a raw position off the data, when the detail is selected, then nothing is selected")
    func selectionOffDataIsNil() {
        let viewModel = OverviewDetailViewModel()
        viewModel.rawSelectedDate = CafeData.day(40)

        #expect(viewModel.selectedDay == nil)
        #expect(viewModel.detailHeadline(locale: locale) == viewModel.compactHeadline(locale: locale))
    }

    @Test("Given every day, when the longest selected headline is found, then no selected headline is longer")
    func longestSelectedHeadlineCoversAll() throws {
        let summary = OverviewDetailViewModel().summary(locale: locale)
        let longest = try #require(summary.longestSelectedHeadline)
        let length = "\(longest.figure)\(longest.period)".count

        for day in summary.days {
            let headline = summary.selectedHeadline(day)
            #expect("\(headline.figure)\(headline.period)".count <= length)
        }
    }

    @Test("Given the Harbour days, when the message is written, then it says each Saturday beat the last, with the total")
    func message() {
        let summary = OverviewDetailViewModel().summary(locale: locale)

        #expect(summary.weeklyPeaks.map(\.cups) == [219, 240, 261, 282])
        #expect(summary.message == "Each Saturday was its week's busiest day and beat the Saturday before: 5,726 cups in 28 days.")
    }

    @Test("Given peaks that do not rise, or under two whole weeks, when the message is written, then it gives the total alone")
    func messageWithoutRisingPeaks() {
        let flat = CafeData.harbourSales.map { DailySales(day: $0.day, cups: 100) }
        let shortWeek = Array(CafeData.harbourSales.prefix(10))
        for days in [flat, shortWeek] {
            let summary = OverviewDetailSummary(days: days, calendar: CafeData.calendar, locale: locale)
            #expect(summary.risingPeakWeekday == nil)
        }
        #expect(OverviewDetailSummary(days: flat, calendar: CafeData.calendar, locale: locale).message == "2,800 cups in 28 days.")
    }

    @Test("Given no selection or a selected day, when a bar's strength is read, then only the selected day is emphasised")
    func emphasis() {
        let first = CafeData.day(0)
        let second = CafeData.day(1)

        #expect(OverviewDetailSummary.isEmphasised(first, selectedDay: nil))
        #expect(OverviewDetailSummary.isEmphasised(first, selectedDay: first))
        #expect(!OverviewDetailSummary.isEmphasised(second, selectedDay: first))
    }

    // MARK: Shared scale

    @Test("Given the Harbour days, when the detail's date axis is labelled, then it marks only days the data has")
    func labelledDays() {
        let summary = OverviewDetailViewModel().summary(locale: locale)

        #expect(summary.labelledDays(thinned: false) == [0, 7, 14, 21].map(CafeData.day))
        #expect(summary.labelledDays(thinned: true) == [0, 14].map(CafeData.day))
    }

    @Test("Given the Harbour days, when the value axis is worked out, then both charts run from 0 to 300 in steps of 100")
    func sharedAxis() {
        let summary = OverviewDetailViewModel().summary(locale: locale)

        #expect(summary.axisStep == 100)
        #expect(summary.axisTop == 300)
        #expect(summary.axisValues(thinned: false) == [0, 100, 200, 300])
        #expect(summary.axisValues(thinned: true) == [0, 200, 300])
    }

    @Test("Given one day of one cup, when the value axis is worked out, then it still has a top above the bar")
    func axisForOneCup() {
        let summary = OverviewDetailSummary(days: [DailySales(day: CafeData.day(0), cups: 1)], calendar: CafeData.calendar, locale: locale)

        #expect(summary.axisTop == 1)
        #expect(summary.headline.figure == "1 cup")
        #expect(summary.headline.period == "Sunday, Mar 1, 2026")
    }

    // MARK: Accessibility text

    @Test("Given a day, when its element is labelled, then it is the written-out day and the cups agree in number")
    func elementText() {
        let summary = OverviewDetailViewModel().summary(locale: locale)

        #expect(summary.elementLabel(CafeData.day(0)) == "Sunday, March 1")
        #expect(CafeWording.cups(1, locale: locale) == "1 cup")
    }

    @Test("Given the detail chart, when its descriptor is made, then it names the café, the days and the shared axis")
    func descriptor() throws {
        let summary = OverviewDetailViewModel().summary(locale: locale)
        let descriptor = OverviewDetailDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Daily cups at the Harbour café, March 1 to March 28, 2026")
        #expect(descriptor.summary == "28 days, 5,726 cups in total. First day 190 cups, last day 282 cups, highest 282 cups on Saturday, March 28.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 28)
    }

    // MARK: Snippets

    @Test("Given the built app, when its snippets are read, then the screen's three regions exist")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in ["overview-and-detail-bars", "overview-and-detail-compact", "overview-and-detail-detail"] {
            #expect(store[name] != nil)
        }
    }
}
