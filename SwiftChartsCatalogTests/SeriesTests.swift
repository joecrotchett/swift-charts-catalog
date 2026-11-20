import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SeriesTests {
    private static let locale = Locale(identifier: "en_US")

    private static func day(_ offset: Int) -> Date {
        CafeData.day(offset)
    }

    private static func store(_ name: String, _ cups: [Int]) -> StoreSales {
        StoreSales(store: name, days: cups.enumerated().map { DailySales(day: day($0.offset), cups: $0.element) })
    }

    private let stores = [
        store("Harbour", [10, 14, 12, 20, 18, 22, 30, 28, 31]),
        store("Station", [40, 38, 35, 36, 30, 29, 25, 26, 1]),
    ]

    private func summary(_ stores: [StoreSales]) -> SeriesSummary {
        SeriesSummary(stores: stores, locale: Self.locale)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when nothing has been changed, then the series is declared with series: and no mistake is shown")
    func startsWithTheSeriesParameter() {
        let viewModel = SeriesViewModel()

        #expect(viewModel.declaration == .seriesParameter)
        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.stores == CafeData.storeSales)
    }

    @Test(
        "Given a way of declaring the series, when it is chosen, then the screen shows that way's snippet and nothing else",
        arguments: zip(
            SeriesDeclaration.allCases,
            ["series-parameter", "series-foreground-style", "series-symbol", "series-line-style"]
        )
    )
    func snippetFollowsDeclaration(declaration: SeriesDeclaration, name: String) {
        let viewModel = SeriesViewModel()

        viewModel.declaration = declaration

        #expect(viewModel.snippets.map(\.name) == [name])
        #expect(viewModel.explanation == declaration.explanation)
        #expect(viewModel.announcement == declaration.announcement)
    }

    @Test("Given any way of declaring the series, when the mistake is switched on, then the mistake's snippet and words replace it")
    func mistakeReplacesTheDeclaration() {
        let viewModel = SeriesViewModel()
        viewModel.declaration = .symbol

        viewModel.isShowingMistake = true

        #expect(viewModel.snippets.map(\.name) == ["series-mistake"])
        #expect(viewModel.explanation == SeriesViewModel.mistakeExplanation)
        #expect(viewModel.explanation.hasPrefix("This is the mistake."))
        #expect(viewModel.announcement == SeriesViewModel.mistakeAnnouncement)
    }

    @Test("Given the mistake is shown, when it is switched off, then the declaration chosen before is back")
    func mistakeKeepsTheDeclaration() {
        let viewModel = SeriesViewModel()
        viewModel.declaration = .lineStyle
        viewModel.isShowingMistake = true

        viewModel.isShowingMistake = false

        #expect(viewModel.declaration == .lineStyle)
        #expect(viewModel.snippets.map(\.name) == ["series-line-style"])
    }

    @Test("Given every state of the screen, when their snippets are listed, then each name starts with the screen's slug and none repeats")
    func snippetNamesAreTheScreensOwn() {
        let names = SeriesDeclaration.allCases.map(\.snippet.name) + [SeriesViewModel.mistakeSnippet.name]

        #expect(names.allSatisfy { $0.hasPrefix("series-") })
        #expect(Set(names).count == names.count)
        #expect(SeriesDeclaration.allCases.map(\.title) == ["series:", "foregroundStyle(by:)", "symbol(by:)", "lineStyle(by:)"])
    }

    @Test("Given every state of the screen, when their announcements are compared, then each change says something different")
    func announcementsDiffer() {
        let announcements = SeriesDeclaration.allCases.map(\.announcement) + [SeriesViewModel.mistakeAnnouncement]

        #expect(Set(announcements).count == announcements.count)
    }

    // MARK: The headline

    @Test("Given two cafés, when the headline is written, then it gives each one's first and last day in cups")
    func headlineGivesFirstAndLastDays() {
        #expect(summary(stores).headline == "Harbour went from 10 to 31 cups a day and Station from 40 to 1.")
    }

    @Test("Given the café sample data, when the headline is written, then it is about that data")
    func headlineFollowsSampleData() {
        #expect(
            summary(CafeData.storeSales).headline
                == "Harbour went from 190 to 282 cups a day and Station from 155 to 193."
        )
    }

    @Test("Given one café that ends on a single cup, when the headline is written, then the unit agrees with the number")
    func headlineAgreesInNumber() {
        #expect(summary([Self.store("Station", [40, 1])]).headline == "Station went from 40 to 1 cup a day.")
    }

    @Test("Given no cafés, days that are all zero, or cafés with no days, when the chart's words are written, then they say nothing was sold")
    func noDataSaysSo() {
        let cases = [[], [Self.store("Harbour", [0, 0, 0]), Self.store("Station", [0])], [Self.store("Harbour", [])]]

        for stores in cases {
            let summary = summary(stores)
            #expect(!summary.hasData)
            #expect(summary.headline == "No cups sold in this period.")
            #expect(summary.audioGraphSummary == "No cups sold in this period.")
        }
    }

    @Test("Given a café with no days beside one with sales, when the headline is written, then only the café with days is in it")
    func headlineSkipsCafesWithNoDays() {
        let summary = summary([Self.store("Harbour", []), Self.store("Station", [5, 9])])

        #expect(summary.hasData)
        #expect(summary.headline == "Station went from 5 to 9 cups a day.")
    }

    // MARK: Accessibility elements

    @Test("Given nine days, when a café's line is divided for VoiceOver, then there is a stretch per week and the days keep their order")
    func portionsAreWeeks() throws {
        let harbour = try #require(stores.first)
        let portions = summary(stores).portions(of: harbour)

        #expect(portions.map(\.days.count) == [7, 2])
        #expect(portions.flatMap(\.days) == harbour.days)
        #expect(Set(portions.map(\.id)).count == portions.count)
    }

    @Test("Given a week of a café's line, when its element is described, then the label is the café and written-out dates and the value is in cups")
    func portionSaysCafeDatesAndCups() throws {
        let harbour = try #require(stores.first)
        let portion = try #require(summary(stores).portions(of: harbour).first)

        #expect(portion.label == "Harbour, March 1 to March 7")
        #expect(portion.value == "Starts at 10 cups, ends at 30 cups, lowest 10 cups, highest 30 cups")
    }

    @Test("Given a stretch of one day, when its element is described, then the date is said once and one cup is singular")
    func singleDayPortion() throws {
        let station = Self.store("Station", [3, 3, 3, 3, 3, 3, 3, 1])
        let portion = try #require(summary([station]).portions(of: station).last)

        #expect(portion.label == "Station, March 8")
        #expect(portion.value == "Starts at 1 cup, ends at 1 cup, lowest 1 cup, highest 1 cup")
    }

    @Test("Given the café sample data, when the lines are divided for VoiceOver, then each café has four weeks")
    func sampleDataHasFourWeeksEach() {
        let summary = summary(CafeData.storeSales)

        #expect(CafeData.storeSales.map { summary.portions(of: $0).count } == [4, 4])
        #expect(summary.portions(of: CafeData.storeSales[0]).first?.value
            == "Starts at 190 cups, ends at 219 cups, lowest 152 cups, highest 219 cups")
    }

    @Test("Given no calendar of its own, when the screen writes dates, then it uses the sample data's calendar and time zone")
    func calendarIsTheSampleDatas() {
        #expect(summary(stores).calendar == CafeData.calendar)
        #expect(summary(stores).dayName(CafeData.firstDay) == "March 1")
    }

    @Test("Given the mistake, when a café's days are divided for VoiceOver, then each element says it is a stretch of the joined line")
    func joinedPortionsSaySo() throws {
        let station = try #require(stores.last)
        let joined = SeriesSummary(stores: stores, isJoined: true, locale: Self.locale)
        let portions = joined.portions(of: station)

        #expect(portions.map(\.label) == ["Joined line, Station's days, March 1 to March 7", "Joined line, Station's days, March 8 to March 9"])
        #expect(portions.first?.value == "Starts at 40 cups, ends at 25 cups, lowest 25 cups, highest 40 cups")
        #expect(portions.map(\.days) == summary(stores).portions(of: station).map(\.days))
    }

    // MARK: The Audio Graph

    @Test("Given two cafés, when the Audio Graph summary is written, then it gives the period and each café's first, last, lowest and highest in cups")
    func summaryGivesActualValues() {
        #expect(
            summary(stores).audioGraphSummary
                == "2 cafés, 9 days, March 1 to March 9. "
                + "Harbour: first day 10 cups, last day 31 cups, lowest 10 cups, highest 31 cups. "
                + "Station: first day 40 cups, last day 1 cup, lowest 1 cup, highest 40 cups."
        )
    }

    @Test("Given two cafés, when the chart descriptor is made, then it has a title, the summary and one named continuous series per café")
    func descriptorNamesEverySeries() {
        let descriptor = SeriesChartDescriptor(stores: stores).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold per day at each café")
        #expect(descriptor.summary == SeriesSummary(stores: stores).audioGraphSummary)
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.isContinuous) == [true, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [9, 9])
    }

    @Test("Given two cafés, when the descriptor's axes are read, then the days are written out in order and values are said in cups")
    func descriptorAxesHaveDatesAndUnits() throws {
        let descriptor = SeriesChartDescriptor(stores: stores).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.count == 9)
        #expect(xAxis.categoryOrder == summary(stores).dayNames)
        #expect(summary(stores).dayNames.first == "March 1")
        #expect(summary(stores).dayNames.last == "March 9")
        #expect(yAxis.title == "Cups")
        // 1 to 40 cups, rounded out to the drawn axis's step of 10.
        #expect(yAxis.range == 0 ... 40)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(193) == "193 cups")
    }

    @Test("Given no cafés, when the chart descriptor is made, then it has no series and says nothing was sold", arguments: [false, true])
    func emptyDescriptor(isJoined: Bool) {
        let descriptor = SeriesChartDescriptor(stores: [], isJoined: isJoined).makeChartDescriptor()

        #expect(descriptor.series.isEmpty)
        #expect(descriptor.summary == "No cups sold in this period.")
    }

    @Test("Given the mistake, when the Audio Graph summary is written, then it says the cafés are joined into one line and gives that line's values")
    func joinedSummarySaysSo() {
        #expect(
            SeriesSummary(stores: stores, isJoined: true, locale: Self.locale).audioGraphSummary
                == "2 cafés, 9 days, March 1 to March 9. "
                + "The cafés are not separate series: every day is joined into one line, Harbour's days, then Station's days. "
                + "First point 10 cups, last point 1 cup, lowest 1 cup, highest 40 cups."
        )
    }

    @Test("Given the mistake, when the chart descriptor is made, then it is one continuous series through every café's days in the order drawn")
    func joinedDescriptorIsOneSeries() throws {
        let descriptor = SeriesChartDescriptor(stores: stores, isJoined: true).makeChartDescriptor()
        let series = try #require(descriptor.series.first)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(descriptor.title == "Cups sold per day, every café joined into one line")
        #expect(descriptor.summary == SeriesSummary(stores: stores, isJoined: true).audioGraphSummary)
        #expect(descriptor.series.count == 1)
        #expect(series.name == "All cafés, joined")
        #expect(series.isContinuous)
        let expected = [10, 14, 12, 20, 18, 22, 30, 28, 31, 40, 38, 35, 36, 30, 29, 25, 26, 1]
        #expect(series.dataPoints.count == 18)
        #expect(SeriesSummary(stores: stores, isJoined: true).joinedDays.map(\.cups) == expected)
        #expect(xAxis.categoryOrder.count == 9)
        #expect(descriptor.yAxis?.range == 0 ... 40)
    }

    @Test("Given one café and one day, when the period is written, then café and day are singular")
    func periodAgreesInNumber() {
        #expect(summary([Self.store("Harbour", [4])]).audioGraphSummary
            == "1 café, 1 day, March 1. Harbour: first day 4 cups, last day 4 cups, lowest 4 cups, highest 4 cups.")
    }

    @Test("Given the two cafés' March, when the value axis is worked out, then it is 150 to 300, off zero around 152 to 282")
    func sampleValueAxis() {
        #expect(SeriesSummary(stores: CafeData.storeSales).cupsRange == 150 ... 300)
    }
}
