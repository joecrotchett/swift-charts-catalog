import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct CalendarHeatMapTests {
    private let locale = Locale(identifier: "en_US")
    private let calendar = CafeData.calendar

    private func summary(
        _ days: [DailySales] = CafeData.tenWeeks, staircase: Bool = false, locale: Locale? = nil
    ) -> CalendarHeatMapSummary {
        CalendarHeatMapSummary(days: days, calendar: calendar, isStaircase: staircase, locale: locale ?? self.locale)
    }

    /// Days from 1 March 2026, a Sunday, with the cups given.
    private func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    // MARK: View model

    @Test("Given a new screen, when nothing is switched, then it draws weekday columns and hides the spoken text")
    func startsCorrect() {
        let viewModel = CalendarHeatMapViewModel()

        #expect(!viewModel.isShowingMistake)
        #expect(!viewModel.isShowingSpokenText)
        #expect(!viewModel.summary(locale: locale).isStaircase)
        #expect(viewModel.days == CafeData.tenWeeks)
    }

    @Test("Given the mistake is switched on, when the summary is made, then it describes the staircase")
    func mistakeMakesStaircase() {
        let viewModel = CalendarHeatMapViewModel()
        viewModel.isShowingMistake = true

        #expect(viewModel.summary(locale: locale).isStaircase)
    }

    @Test("Given each setting of the mistake, when the snippets are listed, then the first follows the setting and all exist")
    func snippetsFollowTheMistake() throws {
        let store = try SnippetStore()
        let viewModel = CalendarHeatMapViewModel()

        #expect(viewModel.snippets.map(\.name) == [
            "calendar-heat-map-weekday-column", "calendar-heat-map-tile", "calendar-heat-map-elements",
        ])
        viewModel.isShowingMistake = true
        #expect(viewModel.snippets.map(\.name) == [
            "calendar-heat-map-staircase", "calendar-heat-map-tile", "calendar-heat-map-elements",
        ])
        for name in [
            "calendar-heat-map-weekday-column", "calendar-heat-map-staircase", "calendar-heat-map-tile",
            "calendar-heat-map-elements",
        ] {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    // MARK: Geometry

    @Test("Given ten weeks from a Sunday, when the rows are worked out, then there are ten weeks of seven columns")
    func tenWeeksMakeTenRows() {
        let summary = summary()

        #expect(summary.weeks.count == 10)
        #expect(summary.weeks.first == CafeData.day(0))
        #expect(summary.columnCount == 7)
        #expect(summary.elementRows.count == 10)
        #expect(summary.elementRows.allSatisfy { $0.count == 7 && !$0.contains(nil) })
    }

    @Test("Given days a week apart, when their column dates are worked out, then they are the same date in the first week")
    func sameWeekdaySharesAColumn() {
        let summary = summary()

        #expect(summary.columnDate(for: CafeData.day(3)) == CafeData.day(3))
        #expect(summary.columnDate(for: CafeData.day(10)) == CafeData.day(3))
        #expect(summary.columnDate(for: CafeData.day(66)) == CafeData.day(3))
        #expect(summary.xDate(for: CafeData.day(66)) == CafeData.day(3))
        #expect(summary.column(for: CafeData.day(66)) == 3)
        #expect(summary.row(for: CafeData.day(66)) == 9)
    }

    @Test("Given the staircase, when a day's position is worked out, then x is its own date and its column its day number")
    func staircaseUsesTheDaysOwnDate() {
        let summary = summary(staircase: true)

        #expect(summary.xDate(for: CafeData.day(66)) == CafeData.day(66))
        #expect(summary.columnCount == 70)
        #expect(summary.column(for: CafeData.day(66)) == 66)
        #expect(summary.row(for: CafeData.day(66)) == 9)
    }

    @Test("Given each setting of the mistake, when the x value is named, then it is a weekday for columns and a day for the staircase")
    func xValueNameIsTrueOfWhatIsPlotted() {
        #expect(summary().xValueName == CafeWording.weekday)
        #expect(summary(staircase: true).xValueName == CafeWording.day)
    }

    @Test("Given the staircase, when the elements are laid out, then each week's seven start seven columns further along")
    func staircaseElementsStepAcross() {
        let rows = summary(staircase: true).elementRows

        #expect(rows.count == 10)
        #expect(rows.allSatisfy { $0.count == 70 })
        for (index, row) in rows.enumerated() {
            #expect(row.firstIndex { $0 != nil } == index * 7)
            #expect(row.count { $0 != nil } == 7)
        }
    }

    @Test("Given data that starts on a Wednesday, when the elements are laid out, then the first row starts in the fourth column")
    func partWeekLeavesGaps() {
        let midweek = (3 ..< 12).map { DailySales(day: CafeData.day($0), cups: 10) }
        let rows = summary(midweek).elementRows

        #expect(rows.count == 2)
        #expect(rows[0].prefix(3).allSatisfy { $0 == nil })
        #expect(rows[0][3]?.label == "Wednesday, March 4")
        #expect(rows[1].count { $0 != nil } == 5)
    }

    @Test("Given no days, when the geometry is worked out, then there are no rows and no elements")
    func emptyHasNoRows() {
        #expect(summary([]).weeks.isEmpty)
        #expect(summary([]).elementRows.isEmpty)
        #expect(summary([], staircase: true).columnCount == 0)
        #expect(summary([]).elements.isEmpty)
    }

    // MARK: Elements

    @Test("Given a day, when its element is written, then it gives the full date, the cups with their unit, and a heading on the first of a month")
    func elementsSayDateAndCups() {
        let summary = summary(days([193, 1]))

        #expect(summary.elements.map(\.label) == ["Sunday, March 1", "Monday, March 2"])
        #expect(summary.elements.map(\.value) == ["193 cups", "1 cup"])
        #expect(summary.elements.map(\.isHeading) == [true, false])
        #expect(summary.elements.map(\.spokenText) == ["Sunday, March 1, 193 cups, heading", "Monday, March 2, 1 cup"])
    }

    @Test("Given the sample data, when the elements are listed, then there is one per day and a heading for each month")
    func sampleHasThreeHeadings() {
        let elements = summary().elements

        #expect(elements.count == 70)
        #expect(elements.filter(\.isHeading).map(\.label) == ["Sunday, March 1", "Wednesday, April 1", "Friday, May 1"])
    }

    @Test("Given the spoken text is asked for, when it is written, then it shows the first week and says how many elements there are")
    func spokenTextShowsFirstWeek() {
        let correct = summary()
        let staircase = summary(staircase: true)

        #expect(correct.spokenPreview.count == 7)
        #expect(correct.spokenPreview.first == correct.elements.first?.spokenText)
        #expect(correct.spokenFootnote
            == "70 elements in all, one for each day, in date order. The first day of each month is a heading. Each lies over its tile, in its weekday's column.")
        #expect(staircase.spokenFootnote
            == "70 elements in all, one for each day, in date order. The first day of each month is a heading. Each lies over its tile, so each week's seven sit further along than the week before.")
        #expect(summary([]).spokenFootnote == "There are no elements: the chart has no days.")
        #expect(summary([]).spokenPreview.isEmpty)
    }

    // MARK: Headline

    @Test("Given the sample data, when the headline is written, then it names the busiest day with its weekday")
    func headlineNamesBusiestDay() {
        #expect(summary().caption == "Cups sold each day, March 1 to May 9")
        #expect(summary().headline == "The most sold in a day was 408 cups, on Saturday, May 9.")
    }

    @Test("Given the staircase, when the headline is written, then it gives the date without a weekday and says what is drawn")
    func staircaseHeadlineSaysWhatIsDrawn() {
        #expect(summary(staircase: true).headline
            == "The most sold in a day was 408 cups, on May 9. Drawn at its own date, each week starts further along and no weekday lines up.")
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        #expect(summary(days([5, 9, 9])).headline == "The most sold in a day was 9 cups, on Monday, March 2 and Tuesday, March 3.")
    }

    @Test("Given more days tied than can be listed, when the headline is written, then it counts them")
    func longTieIsCounted() {
        #expect(summary(days([9, 9, 9, 9, 2])).headline == "The most sold in a day was 9 cups, on 4 days.")
    }

    @Test("Given one cup on the busiest day, when the headline is written, then the unit agrees")
    func oneCupAgrees() {
        #expect(summary(days([0, 1])).headline == "The most sold in a day was 1 cup, on Monday, March 2.")
    }

    @Test("Given no days or only zeros, when the headline is written, then it says so")
    func emptyAndZeroHeadlines() {
        #expect(summary([]).headline == "No days recorded.")
        #expect(summary([]).caption == "Cups sold each day")
        #expect(summary(days([0, 0, 0])).headline == "No cups were sold on any of these days.")
        #expect(summary(days([0, 0, 0]), staircase: true).headline == "No cups were sold on any of these days.")
    }

    @Test("Given a German locale, when the headline is written, then the date and number are written its way")
    func headlineTakesTheLocale() {
        let german = summary(days([1200]), locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("1.200"))
        #expect(german.headline.contains("Sonntag"))
    }

    @Test("Given a German locale and a tie, when the headline is written, then the dates are German and the list is joined in English")
    func listStaysEnglish() {
        let german = summary(days([5, 9, 9]), locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("Montag"))
        #expect(german.headline.contains(" and "))
        #expect(!german.headline.contains(" und "))
    }

    @Test("Given the mistake is switched, when the change is announced, then it says what changed and then the headline")
    func announcementSaysChangeThenHeadline() {
        let correct = summary()
        let staircase = summary(staircase: true)

        #expect(correct.announcement == "Weekday columns on: every weekday shares a column. \(correct.headline)")
        #expect(staircase.announcement == "Weekday columns off: each day is drawn at its own date. \(staircase.headline)")
    }

    @Test("Given each setting of the mistake, when the explanation is written, then it describes the chart as drawn")
    func explanationFollowsTheMistake() {
        #expect(summary().explanation.contains("every weekday shares a column"))
        #expect(!summary(staircase: true).explanation.contains("every weekday shares a column"))
        #expect(summary(staircase: true).explanation.contains("Here x is each day's own date"))
    }

    // MARK: Audio Graph

    @Test("Given the sample data, when the Audio Graph summary is written, then it gives the layout and the extremes in actual values")
    func summaryGivesActualValues() {
        #expect(summary().audioGraphSummary
            == "70 days in 10 weeks, March 1 to May 9. Each row is a week and each column a weekday. "
            + "Fewest in a day: 152 cups, on Tuesday, March 3. Most in a day: 408 cups, on Saturday, May 9.")
        #expect(summary(staircase: true).audioGraphSummary
            == "70 days in 10 weeks, March 1 to May 9. Each row is a week and each day is drawn at its own date, "
            + "across 70 columns, so each week starts further along and no weekday shares a column. "
            + "Fewest in a day: 152 cups, on March 3. Most in a day: 408 cups, on May 9.")
    }

    @Test("Given one day, no days or only zeros, when the Audio Graph summary is written, then counts agree and nothing false is said")
    func summaryEdgeCases() {
        #expect(summary(days([3])).audioGraphSummary.hasPrefix("1 day in 1 week, March 1 to March 1."))
        #expect(summary([]).audioGraphSummary == "No days recorded.")
        #expect(summary(days([0, 0])).audioGraphSummary
            == "2 days in 1 week, March 1 to March 2. Each row is a week and each column a weekday. No cups were sold on any of these days.")
    }

    @Test("Given weekday columns, when the descriptor is made, then it has a series per week over the seven weekdays")
    func descriptorHasASeriesPerWeek() throws {
        let summary = summary()
        let descriptor = CalendarHeatMapDescriptor(summary: summary).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold each day, March 1 to May 9")
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(xAxis.title == "Weekday")
        #expect(xAxis.categoryOrder == ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"])
        #expect(descriptor.series.count == 10)
        #expect(descriptor.series.first?.name == "Week of March 1")
        #expect(descriptor.series.last?.name == "Week of May 3")
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 7 })
        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == 152 ... 408)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }

    @Test("Given the staircase, when the descriptor is made, then each week runs over its own dates")
    func staircaseDescriptorRunsOverDates() throws {
        let descriptor = CalendarHeatMapDescriptor(summary: summary(staircase: true)).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.count == 70)
        #expect(xAxis.categoryOrder.first == "March 1")
        #expect(xAxis.categoryOrder.last == "May 9")
        #expect(descriptor.series.count == 10)
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 7 })
    }

    @Test("Given no days, when the descriptor is made, then it has no series and says so")
    func emptyDescriptor() {
        let descriptor = CalendarHeatMapDescriptor(summary: summary([])).makeChartDescriptor()

        #expect(descriptor.series.isEmpty)
        #expect(descriptor.summary == "No days recorded.")
    }
}
