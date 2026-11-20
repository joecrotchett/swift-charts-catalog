import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DifferenceChartTests {
    private let english = Locale(identifier: "en_US")
    private let sample = DifferenceChartComparison(stores: CafeData.storeSales)

    /// Two cafés over consecutive days from 1 March 2026, from each one's cups.
    private func comparison(_ first: [Int], _ second: [Int]) -> DifferenceChartComparison {
        DifferenceChartComparison(stores: [
            StoreSales(store: "Harbour", days: first.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }),
            StoreSales(store: "Station", days: second.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }),
        ])
    }

    // MARK: The view model

    @Test("Given a new screen, when it appears, then the difference is filled and all three snippets are shown")
    func startsWithFills() {
        let viewModel = DifferenceChartViewModel()

        #expect(viewModel.showsFills)
        #expect(viewModel.snippets.map(\.name) == [
            "difference-chart-fills", "difference-chart-crossings", "difference-chart-lines",
        ])
    }

    @Test("Given the fills are switched off, when the snippets are read, then only the lines' code is shown")
    func linesAloneShowLinesSnippet() {
        let viewModel = DifferenceChartViewModel()
        viewModel.showsFills = false

        #expect(viewModel.snippets.map(\.name) == ["difference-chart-lines"])
    }

    @Test("Given the built app, when the screen's snippets are looked up, then each one exists in this screen's source")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let files = [
            "difference-chart-fills": "Marks/DifferenceChartScreen.swift",
            "difference-chart-crossings": "Marks/DifferenceChartViewModel.swift",
            "difference-chart-lines": "Marks/DifferenceChartScreen.swift",
        ]

        for snippet in DifferenceChartViewModel().snippets {
            #expect(store[snippet.name]?.file == files[snippet.name], "\(snippet.name) is missing")
        }
    }

    @Test("Given either setting, when the explanation is read, then it describes the chart as drawn")
    func explanationFollowsToggle() {
        let viewModel = DifferenceChartViewModel()
        let filled = viewModel.explanation
        viewModel.showsFills = false

        #expect(filled.contains("AreaMark"))
        #expect(viewModel.explanation.hasPrefix("These are the two lines alone."))
    }

    @Test("Given the toggle changes, when the announcement is written, then it says what changed and then the headline")
    func announcementSaysChangeThenHeadline() {
        let viewModel = DifferenceChartViewModel()
        let headline = viewModel.headline(locale: english)

        #expect(viewModel.announcement(locale: english)
            == "Now showing the two lines with the difference between them filled. \(headline)")
        viewModel.showsFills = false
        #expect(viewModel.announcement(locale: english) == "Now showing the two lines alone. \(headline)")
    }

    // MARK: The headline

    @Test("Given the sample data, when the headline is written, then it gives the crossings and the widest gap")
    func headlineForSampleData() {
        #expect(sample.days.count == 28)
        #expect(sample.leadChanges == 6)
        #expect(sample.headline(locale: english)
            == "The lead changed 6 times. The widest gap was 89 cups, on March 28, with Harbour ahead.")
    }

    @Test("Given one change of lead and a gap of one cup, when the headline is written, then both counts agree in number")
    func headlineAgreesInNumber() {
        #expect(comparison([10, 11], [11, 10]).headline(locale: english)
            == "The lead changed 1 time. The widest gap was 1 cup, on March 1, with Station ahead.")
    }

    @Test("Given one café ahead on every day, when the headline is written, then it says the lead never changed")
    func headlineWhenLeadNeverChanges() {
        #expect(comparison([20, 30, 25], [10, 12, 25]).headline(locale: english)
            == "The lead never changed. The widest gap was 18 cups, on March 2, with Harbour ahead.")
    }

    @Test("Given the cafés level on every day, when the headline is written, then it claims no lead and no gap")
    func headlineWhenLevel() {
        let level = comparison([10, 12], [10, 12])

        #expect(level.widestGapDay == nil)
        #expect(level.headline(locale: english) == "Harbour and Station sold the same number of cups every day.")
    }

    @Test("Given no data or only zeros, when the words are written, then they say nothing was sold")
    func emptyAndZeroSaySo() {
        for nothing in [DifferenceChartComparison(stores: []), comparison([0, 0], [0, 0])] {
            #expect(nothing.hasNoSales)
            #expect(nothing.headline(locale: english) == "No cups sold yet at either café.")
            #expect(nothing.audioGraphSummary(locale: english) == "No cups sold yet at either café.")
        }
    }

    @Test("Given a German locale, when the headline is written, then its numbers and date are written that way")
    func headlineTakesLocale() {
        let headline = comparison([2500, 10], [10, 20]).headline(locale: Locale(identifier: "de_DE"))

        #expect(headline.contains("2.490"))
        #expect(headline.contains("1. März"))
    }

    @Test("Given two cafés, when the scale domains are read, then they are the two names in data order")
    func domainsAreTheTwoCafes() {
        #expect(sample.storeNames == [CafeWording.harbour, CafeWording.station])
        #expect(DifferenceChartComparison(stores: []).storeNames == [CafeWording.harbour, CafeWording.station])
    }

    @Test("Given days recorded in a calendar eleven hours ahead of UTC, when a day is written, then it is the day in that calendar")
    func datesTakeTheDatasCalendar() throws {
        var ahead = Calendar(identifier: .gregorian)
        ahead.timeZone = try #require(TimeZone(secondsFromGMT: 11 * 3600))
        // 20:00 UTC on 1 March is already 2 March eleven hours ahead.
        let evening = CafeData.day(0).addingTimeInterval(20 * 3600)
        let stores = [
            StoreSales(store: "Harbour", days: [DailySales(day: evening, cups: 30)]),
            StoreSales(store: "Station", days: [DailySales(day: evening, cups: 10)]),
        ]

        let inData = DifferenceChartComparison(stores: stores, calendar: ahead)
        let inUTC = DifferenceChartComparison(stores: stores)

        #expect(inData.dayText(evening, locale: english) == "March 2")
        #expect(inData.headline(locale: english).contains("on March 2,"))
        #expect(inUTC.dayText(evening, locale: english) == "March 1")
    }

    // MARK: The data the fills draw

    @Test("Given a level day between two leads, when changes are counted, then the level day is not a change of its own")
    func levelDayIsNotAChange() {
        #expect(comparison([12, 10, 8], [10, 10, 10]).leadChanges == 1)
        #expect(comparison([12, 10, 12], [10, 10, 10]).leadChanges == 0)
    }

    @Test("Given lines that cross between two days, when the fill points are made, then a point is added where they meet")
    func crossingPointIsInserted() {
        // Harbour falls 20 to 10 while Station stays at 14: they meet 0.6 of the way through the day, at 14 cups.
        let points = comparison([20, 10], [14, 14]).fillPoints

        #expect(points.count == 3)
        #expect(points[1].first == 14)
        #expect(points[1].second == 14)
        #expect(points[1].lower == 14)
        #expect(abs(points[1].day.timeIntervalSince(CafeData.day(0)) - 0.6 * 86400) < 1)
    }

    @Test("Given the sample data, when the fill points are made, then there is one extra point per change of lead, in date order")
    func samplePointsFollowCrossings() {
        let points = sample.fillPoints

        #expect(points.count == 28 + 6)
        #expect(points.map(\.day) == points.map(\.day).sorted())
        #expect(Set(points.map(\.day)).count == points.count)
    }

    @Test("Given a level day, when the fill points are made, then no point is added beside it")
    func levelDayAddsNoPoint() {
        #expect(comparison([12, 10, 8], [10, 10, 10]).fillPoints.count == 3)
    }

    @Test("Given cafés with different days, when they are compared, then only the shared days are kept")
    func onlySharedDaysAreCompared() {
        let stores = [
            StoreSales(store: "Harbour", days: (0 ..< 3).map { DailySales(day: CafeData.day($0), cups: 10) }),
            StoreSales(store: "Station", days: (1 ..< 4).map { DailySales(day: CafeData.day($0), cups: 12) }),
        ]

        #expect(DifferenceChartComparison(stores: stores).days.map(\.day) == [CafeData.day(1), CafeData.day(2)])
    }

    // MARK: Accessibility text

    @Test("Given the sample data, when it is split into portions, then there are four weeks with both cafés in each")
    func portionsAreWeeks() {
        let portions = sample.portions

        #expect(portions.count == 4)
        #expect(portions.allSatisfy { $0.days.count == 7 && $0.series.map(\.store) == ["Harbour", "Station"] })
        #expect(sample.label(for: portions[0], locale: english) == "March 1 to March 7")
        #expect(sample.label(for: portions[3], locale: english) == "March 22 to March 28")
    }

    @Test("Given a week, when its value is written, then it gives who was ahead on how many days and the widest gap")
    func portionValueGivesActualValues() {
        #expect(sample.value(for: sample.portions[0], locale: english)
            == "Harbour ahead on 2 days, Station ahead on 5 days. Widest gap 47 cups, on March 7, with Harbour ahead.")
        #expect(sample.value(for: sample.portions[3], locale: english)
            == "Harbour ahead on 7 days, Station ahead on 0 days. Widest gap 89 cups, on March 28, with Harbour ahead.")
    }

    @Test("Given a portion of one level day, when its text is written, then it names the day and counts it as level")
    func singleLevelDayPortion() throws {
        let level = comparison([10], [10])
        let portion = try #require(level.portions.first)

        #expect(level.label(for: portion, locale: english) == "March 1")
        #expect(level.value(for: portion, locale: english) == "Harbour ahead on 0 days, Station ahead on 0 days, level on 1 day.")
    }

    @Test("Given the sample data, when the Audio Graph summary is written, then it gives the days, the leads, the changes and the widest gap")
    func summaryGivesActualValues() {
        #expect(sample.audioGraphSummary(locale: english)
            == "28 days. Harbour ahead on 13 days, Station ahead on 15 days. The lead changed 6 times. "
            + "Widest gap 89 cups, on March 28, with Harbour ahead.")
    }

    @Test("Given the sample data, when the chart descriptor is made, then it names both cafés over written-out dates with cups as the unit")
    func descriptorDescribesBothSeries() throws {
        let descriptor = DifferenceChartDescriptor(comparison: sample, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Daily cups sold at the Harbour and Station cafés")
        #expect(descriptor.summary == sample.audioGraphSummary(locale: english))
        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "March 1")
        #expect(xAxis.categoryOrder.last == "March 28")
        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == sample.valueRange)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(193) == "193 cups")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.allSatisfy { $0.isContinuous && $0.dataPoints.count == 28 })
    }

    @Test("Given the sample data, when the value range is read, then it is the drawn axis, 150 to 300, around the lowest and highest values and not from zero")
    func valueRangeMatchesDrawnScale() {
        let cups = CafeData.storeSales.flatMap(\.days).map(\.cups)

        #expect(sample.valueRange == 150 ... 300)
        #expect(sample.valueRange.contains(Double(cups.min() ?? 0)) && sample.valueRange.contains(Double(cups.max() ?? 0)))
        #expect(sample.valueRange.lowerBound > 0)
    }
}
