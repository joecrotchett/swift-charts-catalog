import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DescriptionLevelsTests {
    private let english = Locale(identifier: "en_US")

    /// Two weeks from 1 March 2026: the first at `before` cups a day, the second at `now`.
    private func twoWeeks(before: Int, now: Int) -> [DailySales] {
        (0 ..< 14).map { DailySales(day: CafeData.day($0), cups: $0 < 7 ? before : now) }
    }

    private func summary(_ days: [DailySales], locale: Locale? = nil) -> DescriptionLevelsSummary {
        DescriptionLevelsSummary(days: days, locale: locale ?? english)
    }

    // MARK: The four levels on the sample data

    @Test("Given the Harbour café's last two weeks, when the view model is made, then it draws fourteen days ending on the last day of data")
    func drawsLastTwoWeeks() {
        let viewModel = DescriptionLevelsViewModel()

        #expect(viewModel.days.count == 14)
        #expect(viewModel.days.last == CafeData.harbourSales.last)
        #expect(viewModel.level == .title)
    }

    @Test("Given the sample data, when each level is written, then each has its own text with the figures from the data")
    func sampleLevels() {
        let words = summary(DescriptionLevelsViewModel().days)

        #expect(words.headline(.title) == "Daily cups sold at the Harbour café over 14 days")
        #expect(words.headline(.keyValue) == "Daily average this week: 236 cups")
        #expect(words.headline(.sentence) == "From March 22 to March 28, the Harbour café sold 236 cups a day on average.")
        #expect(words.headline(.interpretation)
            == "Daily sales are up 10% on the week before, averaging 236 cups from March 22 to March 28.")
    }

    @Test("Given the sample data, when the weekly averages are worked out, then they are the rounded means of each week's cups")
    func sampleAverages() {
        let days = DescriptionLevelsViewModel().days
        let words = summary(days)
        let before = Double(days.prefix(7).map(\.cups).reduce(0, +)) / 7
        let now = Double(days.suffix(7).map(\.cups).reduce(0, +)) / 7

        #expect(words.weekBefore.average == Int(before.rounded()))
        #expect(words.thisWeek.average == Int(now.rounded()))
        #expect(words.weekBefore.average == 215)
    }

    @Test("Given other data, when each level is written, then every figure and date follows that data")
    func levelsFollowTheData() {
        let words = summary(twoWeeks(before: 100, now: 90))

        #expect(words.headline(.title) == "Daily cups sold at the Harbour café over 14 days")
        #expect(words.headline(.keyValue) == "Daily average this week: 90 cups")
        #expect(words.headline(.sentence) == "From March 8 to March 14, the Harbour café sold 90 cups a day on average.")
        #expect(words.headline(.interpretation)
            == "Daily sales are down 10% on the week before, averaging 90 cups from March 8 to March 14.")
    }

    @Test("Given two weeks with the same average, when the interpretation is written, then it says level, not up or down")
    func levelWeeks() {
        #expect(summary(twoWeeks(before: 120, now: 120)).interpretation
            == "Daily sales are level with the week before, averaging 120 cups from March 8 to March 14.")
    }

    @Test("Given a change too small to show as a whole percent, when the interpretation is written, then it does not say up 0%")
    func tinyChange() {
        #expect(summary(twoWeeks(before: 300, now: 301)).interpretation
            == "Daily sales are within 1% of the week before, averaging 301 cups from March 8 to March 14.")
    }

    @Test("Given only one week of data, when the interpretation is written, then it compares with nothing")
    func oneWeekOnly() {
        let days = (0 ..< 7).map { DailySales(day: CafeData.day($0), cups: 80) }
        let words = summary(days)

        #expect(words.weekBefore.days.isEmpty)
        #expect(words.interpretation
            == "With no sales the week before to compare with, this week is averaging 80 cups from March 1 to March 7.")
    }

    @Test("Given a week before with no sales, when the interpretation is written, then it gives no percentage of zero")
    func weekBeforeZero() {
        #expect(summary(twoWeeks(before: 0, now: 50)).interpretation
            == "With no sales the week before to compare with, this week is averaging 50 cups from March 8 to March 14.")
    }

    @Test("Given an average of one cup, when the figure is written, then the unit agrees in number")
    func singularFigure() {
        let words = summary(twoWeeks(before: 1, now: 1))

        #expect(words.figure == "1 cup")
        #expect(words.figureNumber == "1")
        #expect(words.figureUnit == "cup")
        #expect(words.headline(.keyValue) == "Daily average this week: 1 cup")
    }

    @Test("Given a German locale, when the figure is written, then the number takes the locale's grouping")
    func germanFigure() {
        let words = summary(twoWeeks(before: 1000, now: 1500), locale: Locale(identifier: "de_DE"))

        #expect(words.figureNumber == "1.500")
        #expect(words.figureUnit == "cups")
    }

    // MARK: Empty and all-zero data

    @Test("Given no data, when the words are written, then the chart is a placeholder and no level names a figure")
    func noData() {
        let words = summary([])

        #expect(words.hasNoSales)
        #expect(words.headline(.title) == "Daily cups sold at the Harbour café")
        #expect(words.headline(.keyValue) == "Daily average: no cups sold yet")
        #expect(words.headline(.sentence) == "The Harbour café has no sales to show for these days yet.")
        #expect(words.headline(.interpretation) == "No cups sold in these days, so there is nothing to compare yet.")
        #expect(words.audioGraphSummary == "No cups sold.")
        #expect(words.period == "")
    }

    @Test("Given two weeks of zeros, when the words are written, then the chart is a placeholder and the title still counts the days")
    func allZeros() {
        let words = summary(twoWeeks(before: 0, now: 0))

        #expect(words.hasNoSales)
        #expect(words.headline(.title) == "Daily cups sold at the Harbour café over 14 days")
        #expect(words.headline(.keyValue) == "Daily average: no cups sold yet")
    }

    @Test("Given no sales, when the explanation is written, then it does not point at lines the placeholder does not draw")
    func explanationFollowsChart() {
        #expect(DescriptionLevelsViewModel.explanation(hasNoSales: false).contains("the solid line is this week's daily average"))
        #expect(!DescriptionLevelsViewModel.explanation(hasNoSales: true).contains("solid line"))
        #expect(!DescriptionLevelsViewModel.explanation(hasNoSales: true).contains("dashed line"))
        #expect(DescriptionLevelsViewModel.explanation(hasNoSales: true).contains("placeholder"))
    }

    @Test("Given the sample data, when the key under the chart is written for large text, then each line names its rule, week and figure")
    func ruleKey() {
        let words = summary(DescriptionLevelsViewModel().days)

        #expect(words.ruleKey(isEmphasised: true) == "Solid line, this week: 236")
        #expect(words.ruleKey(isEmphasised: false) == "Dashed line, week before: 215")
    }

    // MARK: Card, caption, headline height

    @Test("Given the sample data, when the summary card's period is written, then it is this week in the data's calendar")
    func period() {
        let period = summary(DescriptionLevelsViewModel().days).period

        #expect(period.contains("Mar 22"))
        #expect(period.contains("28"))
        #expect(period.contains("2026"))
        #expect(!period.contains("21"))
    }

    @Test("Given the sample data, when the card's period is written for VoiceOver, then it is written out in full")
    func spokenPeriod() {
        #expect(summary(DescriptionLevelsViewModel().days).spokenPeriod == "March 22 to March 28, 2026")
        #expect(summary([DailySales(day: CafeData.day(0), cups: 3)]).spokenPeriod == "March 1, 2026")
        #expect(summary([]).spokenPeriod == "")
    }

    @Test("Given a drawn chart, when the explanation is written, then it says the card carries the figure even at level 1")
    func explanationNamesCardFigure() {
        #expect(DescriptionLevelsViewModel.explanation(hasNoSales: false)
            .contains("Even at level 1, where the headline only names the chart, the card under it already carries the figure."))
    }

    @Test("Given each level, when its caption is written, then it numbers the level and names it")
    func captions() {
        #expect(DescriptionLevelsLevel.title.caption == "Level 1 of 4: a title that only names the chart")
        #expect(DescriptionLevelsLevel.interpretation.caption == "Level 4 of 4: an interpretation")
    }

    @Test("Given a level is chosen, when the announcement is written, then it says the level and then the headline")
    func announcement() {
        let viewModel = DescriptionLevelsViewModel()
        viewModel.level = .keyValue

        #expect(viewModel.announcement(locale: english)
            == "Level 2: a title that carries the key value. Daily average this week: 236 cups")
    }

    // MARK: Snippets

    @Test("Given each level, when the snippets are listed, then the summary card comes first and the level's own code second")
    func snippetsFollowLevel() {
        let viewModel = DescriptionLevelsViewModel()
        let expected: [DescriptionLevelsLevel: String] = [
            .title: "descriptions-say-the-message-title",
            .keyValue: "descriptions-say-the-message-key-value",
            .sentence: "descriptions-say-the-message-sentence",
            .interpretation: "descriptions-say-the-message-interpretation",
        ]
        for level in DescriptionLevelsLevel.allCases {
            viewModel.level = level
            #expect(viewModel.snippets.map(\.name) == ["descriptions-say-the-message-summary-card", expected[level]])
        }
    }

    @Test("Given the app's extracted snippets, when every snippet this screen shows is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [DescriptionLevelsViewModel.cardSnippet.name]
            + DescriptionLevelsLevel.allCases.map { DescriptionLevelsViewModel.levelSnippet($0).name }

        for name in names {
            #expect(store[name] != nil, "\(name) is missing")
        }
    }

    // MARK: Accessibility

    @Test("Given the sample data, when the rules are labelled, then each names its week and the descriptor summary gives both averages")
    func accessibilityText() {
        let words = summary(DescriptionLevelsViewModel().days)

        #expect(words.averageLabel(words.thisWeek) == "Daily average, March 22 to March 28")
        #expect(words.fullDayName(CafeData.day(0)) == "Sunday, March 1")
        #expect(words.audioGraphSummary == "14 days, March 15 to March 28. Daily average, March 15 to March 21: 215 cups. "
            + "Daily average, March 22 to March 28: 236 cups. Highest: Saturday, March 28, 282 cups.")
    }

    @Test("Given the sample data, when the chart descriptor is made, then it has the title, days, range and units")
    func descriptor() throws {
        let words = summary(DescriptionLevelsViewModel().days)
        let descriptor = DescriptionLevelsChartDescriptor(summary: words).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Daily cups sold at the Harbour café over 14 days")
        #expect(descriptor.summary == words.audioGraphSummary)
        #expect(xAxis.categoryOrder.count == 14)
        #expect(xAxis.categoryOrder.first == "March 15")
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 14)
    }
}
