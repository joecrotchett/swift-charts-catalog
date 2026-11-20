import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct ThreeWaysToCreateAChartTests {
    typealias ViewModel = ThreeWaysToCreateAChartViewModel

    /// Two cafés over three days: 10, 20, 30 and 40, 50, 60 cups.
    private let stores = [
        StoreSales(store: "Harbour", days: [
            DailySales(day: CafeData.day(0), cups: 10),
            DailySales(day: CafeData.day(1), cups: 20),
            DailySales(day: CafeData.day(2), cups: 30),
        ]),
        StoreSales(store: "Station", days: [
            DailySales(day: CafeData.day(0), cups: 40),
            DailySales(day: CafeData.day(1), cups: 50),
            DailySales(day: CafeData.day(2), cups: 60),
        ]),
    ]

    private func snippetNames(_ viewModel: ViewModel) -> [String] {
        viewModel.snippets.map(\.name)
    }

    // MARK: - State

    @Test("Given a new screen, when nothing is changed, then it shows Chart(data) with one series and no mistake")
    func startsWithDataAndOneSeries() {
        let viewModel = ViewModel(stores: stores)

        #expect(viewModel.way == .data)
        #expect(viewModel.seriesCount == .one)
        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.stores.map(\.store) == ["Harbour"])
        #expect(viewModel.ruleCount == 0)
    }

    @Test("Given the sample data, when the screen starts, then it shows the first seven days of each café")
    func sampleDataIsTheFirstWeek() {
        #expect(ViewModel.firstWeek.map(\.store) == ["Harbour", "Station"])
        #expect(ViewModel.firstWeek.map(\.days.count) == [7, 7])
        #expect(ViewModel.firstWeek.first?.days.first?.day == CafeData.firstDay)
    }

    @Test("Given one series, when the data is shaped, then there is a row and a reading per day of the first café")
    func oneSeriesShapesOneCafe() {
        let viewModel = ViewModel(stores: stores)

        #expect(viewModel.days.map(\.cups) == [10, 20, 30])
        #expect(viewModel.rows.map(\.cups) == [10, 20, 30])
        #expect(viewModel.readings.map(\.cups) == [10, 20, 30])
    }

    @Test("Given several series, when the data is shaped, then the rows are flat, one per café and day, each with its own id")
    func severalSeriesFlattenEveryCafe() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several

        #expect(viewModel.stores.count == 2)
        #expect(viewModel.rows.map(\.cups) == [10, 20, 30, 40, 50, 60])
        #expect(Set(viewModel.rows.map(\.id)).count == 6)
        #expect(Set(viewModel.readings).count == 6)
        #expect(viewModel.readings.map(\.store) == ["Harbour", "Harbour", "Harbour", "Station", "Station", "Station"])
    }

    @Test("Given Chart(data), when the mistake is shown, then the chart holds one rule per element", arguments: [
        (ViewModel.SeriesCount.one, 3), (ViewModel.SeriesCount.several, 6),
    ])
    func mistakeMakesARulePerElement(seriesCount: ViewModel.SeriesCount, expected: Int) {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = seriesCount
        viewModel.isShowingMistake = true

        #expect(viewModel.ruleCount == expected)
        #expect(viewModel.summary.showsAverage)
    }

    @Test("Given Chart { }, when the chart is drawn, then it holds exactly one rule and the mistake cannot be shown")
    func contentHasOneRule() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several
        viewModel.way = .content

        #expect(viewModel.ruleCount == 1)
        #expect(!viewModel.canShowMistake)
    }

    @Test("Given the mistake is showing, when the way changes to Chart { }, then the mistake is switched off")
    func contentClearsTheMistake() {
        let viewModel = ViewModel(stores: stores)
        viewModel.isShowingMistake = true
        viewModel.way = .content

        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.ruleCount == 1)
    }

    @Test("Given the mistake is showing, when the way changes to Chart(data, id:), then the mistake stays")
    func idKeepsTheMistake() {
        let viewModel = ViewModel(stores: stores)
        viewModel.isShowingMistake = true
        viewModel.way = .dataWithID

        #expect(viewModel.isShowingMistake)
        #expect(viewModel.canShowMistake)
    }

    // MARK: - Snippets

    @Test("Given each way and series count, when the snippets are listed, then the first is that chart's own region", arguments: [
        (ViewModel.Way.data, ViewModel.SeriesCount.one, "three-ways-to-create-a-chart-data-one"),
        (ViewModel.Way.data, ViewModel.SeriesCount.several, "three-ways-to-create-a-chart-data-several"),
        (ViewModel.Way.dataWithID, ViewModel.SeriesCount.one, "three-ways-to-create-a-chart-id-one"),
        (ViewModel.Way.dataWithID, ViewModel.SeriesCount.several, "three-ways-to-create-a-chart-id-several"),
        (ViewModel.Way.content, ViewModel.SeriesCount.one, "three-ways-to-create-a-chart-content-one"),
        (ViewModel.Way.content, ViewModel.SeriesCount.several, "three-ways-to-create-a-chart-content-several"),
    ])
    func chartSnippetFollowsTheControls(way: ViewModel.Way, seriesCount: ViewModel.SeriesCount, expected: String) {
        let viewModel = ViewModel(stores: stores)
        viewModel.way = way
        viewModel.seriesCount = seriesCount

        #expect(viewModel.chartSnippetName == expected)
        #expect(snippetNames(viewModel).first == expected)
        #expect(snippetNames(viewModel).last == "three-ways-to-create-a-chart-mark")
    }

    @Test("Given the mistake, when the snippets are listed, then they are the mistaken chart, the rule and the mark", arguments: [
        (ViewModel.Way.data, ViewModel.SeriesCount.one, "three-ways-to-create-a-chart-data-one-mistake"),
        (ViewModel.Way.data, ViewModel.SeriesCount.several, "three-ways-to-create-a-chart-data-several-mistake"),
        (ViewModel.Way.dataWithID, ViewModel.SeriesCount.one, "three-ways-to-create-a-chart-id-one-mistake"),
        (ViewModel.Way.dataWithID, ViewModel.SeriesCount.several, "three-ways-to-create-a-chart-id-several-mistake"),
    ])
    func mistakeSnippetFollowsTheControls(way: ViewModel.Way, seriesCount: ViewModel.SeriesCount, expected: String) {
        let viewModel = ViewModel(stores: stores)
        viewModel.way = way
        viewModel.seriesCount = seriesCount
        viewModel.isShowingMistake = true

        #expect(snippetNames(viewModel).first == expected)
        #expect(snippetNames(viewModel).contains("three-ways-to-create-a-chart-rule"))
        #expect(viewModel.snippets.first?.title.contains("the mistake") == true)
    }

    @Test("Given Chart(data) with one series, when the snippets are listed, then they are the chart and the mark, with no rule")
    func plainChartShowsNoRule() {
        #expect(snippetNames(ViewModel(stores: stores)) == [
            "three-ways-to-create-a-chart-data-one", "three-ways-to-create-a-chart-mark",
        ])
    }

    @Test("Given Chart(data) with several series, when the snippets are listed, then the flat row type is among them")
    func severalSeriesShowTheRow() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several

        #expect(snippetNames(viewModel) == [
            "three-ways-to-create-a-chart-data-several", "three-ways-to-create-a-chart-row", "three-ways-to-create-a-chart-mark",
        ])
    }

    @Test("Given Chart(data, id:), when the snippets are listed, then the type that is not Identifiable is among them")
    func idShowsTheReading() {
        let viewModel = ViewModel(stores: stores)
        viewModel.way = .dataWithID

        #expect(snippetNames(viewModel) == [
            "three-ways-to-create-a-chart-id-one", "three-ways-to-create-a-chart-reading", "three-ways-to-create-a-chart-mark",
        ])
    }

    @Test("Given Chart { }, when the snippets are listed, then the rule is among them")
    func contentShowsTheRule() {
        let viewModel = ViewModel(stores: stores)
        viewModel.way = .content

        #expect(snippetNames(viewModel) == [
            "three-ways-to-create-a-chart-content-one", "three-ways-to-create-a-chart-rule", "three-ways-to-create-a-chart-mark",
        ])
    }

    @Test("Given every setting, when its snippets are looked up, then each is in the bundle and starts with the screen's slug")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        let viewModel = ViewModel(stores: stores)
        for way in ViewModel.Way.allCases {
            for seriesCount in ViewModel.SeriesCount.allCases {
                for isShowingMistake in [false, true] {
                    viewModel.way = way
                    viewModel.seriesCount = seriesCount
                    viewModel.isShowingMistake = isShowingMistake && viewModel.canShowMistake
                    for name in snippetNames(viewModel) {
                        #expect(name.hasPrefix("three-ways-to-create-a-chart-"))
                        #expect(store[name] != nil, "\(name) is missing")
                    }
                }
            }
        }
    }

    // MARK: - Words

    @Test("Given one café, when the headline is written, then it gives the week's cups and the average per day")
    func headlineForOneCafe() {
        let summary = ViewModel(stores: stores).summary

        #expect(summary.total == 60)
        #expect(summary.average == 20)
        #expect(summary.headline == "Harbour sold 60 cups in the week: 20 a day on average.")
    }

    @Test("Given two cafés, when the headline is written, then it names both and gives the average per café")
    func headlineForSeveralCafes() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several

        #expect(viewModel.summary.average == 35)
        #expect(viewModel.summary.headline == "Harbour and Station sold 210 cups in the week: 35 per café a day on average.")
    }

    @Test("Given a café that sold one cup, when the headline is written, then the unit agrees with the number")
    func headlineAgreesInNumber() {
        let one = [StoreSales(store: "Harbour", days: [DailySales(day: CafeData.day(0), cups: 1)])]

        #expect(ViewModel(stores: one).summary.headline == "Harbour sold 1 cup in the week: 1 a day on average.")
    }

    @Test("Given no data, or only zeros, when the words are written, then they say nothing sold", arguments: [
        [StoreSales](),
        [StoreSales(store: "Harbour", days: [DailySales(day: .distantPast, cups: 0), DailySales(day: .now, cups: 0)])],
    ])
    func emptyAndZeroSaySo(stores: [StoreSales]) {
        let viewModel = ViewModel(stores: stores)

        #expect(!viewModel.summary.hasData)
        #expect(viewModel.summary.headline == "No cups sold in the week.")
        #expect(viewModel.summary.audioGraphSummary == "No cups sold in the week.")
        #expect(viewModel.changeAnnouncement == "Chart shows no data.")
    }

    @Test("Given days in the sample data's time zone, when the caption is written, then it gives the first and last day")
    func captionGivesThePeriod() {
        #expect(ViewModel(stores: stores).summary.caption == "Cups sold per day, March 1 to March 3")
        #expect(ViewModel(stores: []).summary.caption == "Cups sold per day")
    }

    @Test("Given a point, when its label is written, then the café comes first when there is one, then the written-out date")
    func pointLabelGivesContextFirst() {
        #expect(ThreeWaysDayPoint.label(day: CafeData.day(0), store: nil) == "Sunday, March 1")
        #expect(ThreeWaysDayPoint.label(day: CafeData.day(1), store: "Station") == "Station, Monday, March 2")
    }

    @Test("Given each setting, when the explanation is written, then it names the initializer on screen")
    func explanationNamesTheWay() {
        let viewModel = ViewModel(stores: stores)
        for way in ViewModel.Way.allCases {
            for seriesCount in ViewModel.SeriesCount.allCases {
                viewModel.way = way
                viewModel.seriesCount = seriesCount
                #expect(viewModel.explanation.hasPrefix(way.title))
            }
        }
    }

    @Test("Given the mistake with several series, when the explanation is written, then it says how many rules there are")
    func explanationCountsTheRules() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several
        viewModel.isShowingMistake = true

        #expect(viewModel.explanation.contains("holds 6 average rules"))
        #expect(viewModel.explanation.contains("“Average” 6 times"))
    }

    @Test("Given a change to the chart, when the announcement is written, then it says what the chart now shows")
    func announcementFollowsTheChart() {
        let viewModel = ViewModel(stores: stores)
        #expect(viewModel.changeAnnouncement == "Chart shows 1 café and no average line.")

        viewModel.seriesCount = .several
        #expect(viewModel.changeAnnouncement == "Chart shows 2 cafés and no average line.")

        viewModel.isShowingMistake = true
        #expect(viewModel.changeAnnouncement == "Chart shows 2 cafés and 6 average lines.")

        viewModel.way = .content
        #expect(viewModel.changeAnnouncement == "Chart shows 2 cafés and 1 average line.")
    }

    @Test("Given two ways that draw the same chart, when the way changes, then the announcement does not")
    func sameChartSameAnnouncement() {
        let viewModel = ViewModel(stores: stores)
        let before = viewModel.changeAnnouncement
        viewModel.way = .dataWithID

        #expect(viewModel.changeAnnouncement == before)
    }

    @Test("Given counts of cafés and average lines, when they are written, then the noun agrees with the number")
    func countsAgreeInNumber() {
        #expect(ThreeWaysFormat.cafesText(1) == "1 café")
        #expect(ThreeWaysFormat.cafesText(2) == "2 cafés")
        #expect(ThreeWaysFormat.averageLinesText(1) == "1 average line")
        #expect(ThreeWaysFormat.averageLinesText(6) == "6 average lines")
        #expect(ThreeWaysFormat.cupsText(1) == "1 cup")
    }

    @Test("Given one series or several, when the scales' domain is asked for, then it is every café in data order either way")
    func scaleDomainDoesNotFollowTheSeriesCount() {
        let viewModel = ViewModel(stores: stores)
        #expect(viewModel.cafes == ["Harbour", "Station"])

        viewModel.seriesCount = .several
        #expect(viewModel.cafes == ["Harbour", "Station"])
    }

    @Test("Given a text size, when the day labels are spaced, then there are fewer as the text grows", arguments: [
        (DynamicTypeSize.large, 1), (DynamicTypeSize.xLarge, 1), (DynamicTypeSize.xxLarge, 2),
        (DynamicTypeSize.accessibility2, 2), (DynamicTypeSize.accessibility3, 7), (DynamicTypeSize.accessibility5, 7),
    ])
    func dayLabelsThinWithTextSize(size: DynamicTypeSize, expected: Int) {
        #expect(ThreeWaysWeekStyle.daysPerLabel(for: size) == expected)
    }

    @Test("Given a café with a one-cup day, when the Audio Graph summary is written, then every figure has its unit and agrees in number")
    func summaryUnitsAgreeInNumber() {
        let one = [StoreSales(store: "Harbour", days: [
            DailySales(day: CafeData.day(0), cups: 1), DailySales(day: CafeData.day(1), cups: 4),
        ])]

        #expect(ViewModel(stores: one).summary.audioGraphSummary == "Harbour: 5 cups, lowest day 1 cup, highest day 4 cups.")
    }

    // MARK: - Audio Graph

    @Test("Given two cafés with the rule, when the summary is written, then it gives each café's actual values and the average")
    func summaryGivesActualValues() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several
        viewModel.way = .content

        #expect(
            viewModel.summary.audioGraphSummary
                == "Harbour: 60 cups, lowest day 10 cups, highest day 30 cups. "
                + "Station: 150 cups, lowest day 40 cups, highest day 60 cups. "
                + "Average: 35 cups a day."
        )
    }

    @Test("Given a chart with no rule, when the summary is written, then it does not state an average")
    func summaryLeavesOutAnAbsentRule() {
        #expect(ViewModel(stores: stores).summary.audioGraphSummary == "Harbour: 60 cups, lowest day 10 cups, highest day 30 cups.")
    }

    @Test("Given two cafés, when the chart descriptor is made, then it has a title, the summary and a named continuous line per café")
    func descriptorNamesEverySeries() {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several
        let descriptor = ThreeWaysChartDescriptor(summary: viewModel.summary).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold per day at Harbour and Station")
        #expect(descriptor.summary == viewModel.summary.audioGraphSummary)
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.isContinuous) == [true, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [3, 3])
    }

    @Test("Given two cafés, when the descriptor's axes are read, then the days are written out once each and values are said in cups")
    func descriptorAxesHaveDatesAndUnits() throws {
        let viewModel = ViewModel(stores: stores)
        viewModel.seriesCount = .several
        let descriptor = ThreeWaysChartDescriptor(summary: viewModel.summary).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder == ["Sunday, March 1", "Monday, March 2", "Tuesday, March 3"])
        #expect(yAxis.title == "Cups")
        // 10 to 60 cups, rounded out to the drawn axis's step of 20: 0 to 60, the range the chart is given too.
        #expect(yAxis.range == 0 ... 60)
        #expect(yAxis.range == viewModel.summary.valueDomain)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(42) == "42 cups")
    }

    @Test("Given the sample week at Harbour, when the value axis is worked out, then it is 140 to 220, off zero around 152 to 219")
    func sampleWeekValueDomain() {
        #expect(ViewModel().summary.valueDomain == 140 ... 220)
    }
}
