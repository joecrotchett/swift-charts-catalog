import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LineMarkTests {
    private let locale = Locale(identifier: "en_US")

    private func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    @Test("Given a new screen, when nothing has been changed, then the line is straight with symbols over a week of seven days in date order")
    func startsStraightWithSymbols() {
        let viewModel = LineMarkViewModel()

        #expect(viewModel.interpolation == .straight)
        #expect(viewModel.showsSymbols)
        #expect(viewModel.days.count == 7)
        #expect(viewModel.days.map(\.day) == (0 ..< 7).map(CafeData.day))
    }

    @Test("Given the sample week, when it is read, then it is the Harbour café's March 1 to 7, the days the other screens draw")
    func sampleWeekIsHarbours() {
        #expect(LineMarkViewModel.sampleWeek == Array(CafeData.harbourSales.prefix(7)))
        #expect(LineMarkViewModel.sampleWeek.map(\.cups) == [190, 159, 152, 168, 155, 168, 219])
    }

    @Test("Given the sample week, when the headline is written, then it names the busiest day and its cups")
    func headlineNamesBusiestDay() {
        let summary = WeekSalesSummary(days: LineMarkViewModel.sampleWeek, locale: locale)

        #expect(summary.headline == "Saturday, March 7 was the busiest day: 219 cups.")
    }

    @Test("Given days within a few cups of the most, when the headline is written, then it names them together and calls none the busiest")
    func nearTieNamesTheLeaders() {
        let summary = WeekSalesSummary(days: days([162, 158, 160, 157, 210, 207, 209]), locale: locale)

        #expect(summary.leadingDays.map(\.cups) == [210, 207, 209])
        #expect(
            summary.headline
                == "Thursday, March 5, Friday, March 6, and Saturday, March 7 sold the most, within a few cups of each other: 207 to 210 cups."
        )
        #expect(!summary.headline.contains("busiest"))
    }

    @Test("Given any interpolation and symbol setting, when the headline is read, then it is the same sentence about a day's own value", arguments: LineInterpolation.allCases, [true, false])
    func headlineHoldsForEverySetting(interpolation: LineInterpolation, showsSymbols: Bool) {
        let viewModel = LineMarkViewModel()
        let headline = viewModel.headline(locale: locale)
        viewModel.interpolation = interpolation
        viewModel.showsSymbols = showsSymbols

        #expect(viewModel.headline(locale: locale) == headline)
        #expect(viewModel.summary(locale: locale).busiestDays.map(\.cups) == [219])
    }

    @Test("Given a count of days, when it is written, then it agrees in number and its number takes the locale")
    func daysAgreeInNumber() {
        let summary = WeekSalesSummary(days: [], locale: locale)

        #expect(summary.daysText(1) == "1 day")
        #expect(summary.daysText(7) == "7 days")
        #expect(WeekSalesSummary(days: [], locale: Locale(identifier: "de_DE")).daysText(1400) == "1.400 days")
    }

    @Test("Given two days tied for the most cups, when the headline is written, then it names both")
    func tieNamesBothDays() {
        let summary = WeekSalesSummary(days: days([200, 150, 200]), locale: locale)

        #expect(summary.headline == "Sunday, March 1 and Tuesday, March 3 were the busiest days: 200 cups each.")
    }

    @Test("Given no days, when the chart's words are written, then they say nothing was sold and there is no line")
    func emptyDataSaysSo() {
        let summary = WeekSalesSummary(days: [], locale: locale)

        #expect(!summary.hasLine)
        #expect(summary.headline == "No cups sold in this period.")
        #expect(summary.audioGraphSummary(drawnAs: "Drawn.") == "No cups sold in this period.")
    }

    @Test("Given days that are all zero, when the chart's words are written, then they say nothing was sold, not that a day was busiest")
    func allZeroDataSaysSo() {
        let summary = WeekSalesSummary(days: days([0, 0, 0]), locale: locale)

        #expect(!summary.hasLine)
        #expect(summary.busiestDays.isEmpty)
        #expect(summary.headline == "No cups sold in this period.")
    }

    @Test("Given a single day, when the chart's words are written, then they say one day is not a line")
    func oneDayIsNotALine() {
        let summary = WeekSalesSummary(days: days([120]), locale: locale)

        #expect(!summary.hasLine)
        #expect(summary.headline == "One day of sales is not yet a line.")
    }

    @Test("Given a count of cups, when it is written, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        let summary = WeekSalesSummary(days: [], locale: locale)

        #expect(summary.cupsText(1) == "1 cup")
        #expect(summary.cupsText(0) == "0 cups")
        #expect(summary.cupsText(219) == "219 cups")
    }

    @Test("Given a locale that groups thousands with a full stop, when cups are written, then the number follows that locale")
    func cupsFollowTheLocale() {
        #expect(WeekSalesSummary(days: [], locale: Locale(identifier: "de_DE")).cupsText(1640) == "1.640 cups")
        #expect(WeekSalesSummary(days: [], locale: locale).cupsText(1640) == "1,640 cups")
    }

    @Test("Given a locale passed in, when the headline, the summary and the chart descriptor are written, then all three use it")
    func everyWordUsesTheLocalePassedIn() throws {
        let french = Locale(identifier: "fr_FR")
        let viewModel = LineMarkViewModel()
        let summary = viewModel.summary(locale: french)
        let descriptor = WeekLineChartDescriptor(days: viewModel.days, locale: french, drawing: "").makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(summary.locale == french)
        #expect(viewModel.headline(locale: french) == summary.headline)
        #expect(viewModel.headline(locale: french).contains("samedi"))
        #expect(viewModel.headline(locale: french) != viewModel.headline(locale: locale))
        #expect(xAxis.categoryOrder.first == summary.dayName(CafeData.day(0)))
        #expect(xAxis.categoryOrder.first?.contains("dimanche") == true)
    }

    @Test("Given each interpolation, when the explanation is written, then it ends with that interpolation's own sentence", arguments: LineInterpolation.allCases)
    func explanationFollowsInterpolation(interpolation: LineInterpolation) {
        let viewModel = LineMarkViewModel()
        viewModel.interpolation = interpolation

        #expect(viewModel.explanation.hasPrefix("LineMark joins one mark per day"))
        #expect(viewModel.explanation.hasSuffix(interpolation.explanation))
    }

    @Test("Given no line to draw, when the explanation is written, then it does not describe a line that is not there")
    func explanationWithoutLineIsTheConceptOnly() {
        let viewModel = LineMarkViewModel(days: [])
        viewModel.interpolation = .smooth

        #expect(!viewModel.explanation.contains(LineInterpolation.smooth.explanation))
    }

    @Test("Given each interpolation with symbols on, when the snippets are listed, then they are the line, that method and the symbols", arguments: LineInterpolation.allCases)
    func snippetsWithSymbols(interpolation: LineInterpolation) {
        let viewModel = LineMarkViewModel()
        viewModel.interpolation = interpolation

        #expect(viewModel.snippets.map(\.name) == ["line-mark", "line-method-\(interpolation.rawValue)", "line-symbols"])
    }

    @Test("Given symbols switched off, when the snippets are listed, then the symbols snippet is gone")
    func snippetsWithoutSymbols() {
        let viewModel = LineMarkViewModel()
        viewModel.interpolation = .smooth
        viewModel.showsSymbols = false

        #expect(viewModel.snippets.map(\.name) == ["line-mark", "line-method-smooth"])
    }

    @Test("Given the built app, when every snippet the screen can show is looked up, then each is in the store")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        let names = [LineMarkViewModel.lineSnippet.name, LineMarkViewModel.symbolSnippet.name]
            + LineInterpolation.allCases.map(\.snippet.name)

        for name in names {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    @Test("Given the two controls, when either changes, then the sentence that is announced changes with it")
    func drawingDescriptionFollowsBothControls() {
        let viewModel = LineMarkViewModel()
        #expect(viewModel.drawingDescription == "The line is drawn as straight segments from day to day, with a circle at each day.")

        viewModel.showsSymbols = false
        #expect(viewModel.drawingDescription == "The line is drawn as straight segments from day to day, with no symbol at the days.")

        viewModel.interpolation = .stepped
        #expect(viewModel.drawingDescription == "The line is drawn as steps, each day's value held level around its day, with no symbol at the days.")
        #expect(Set(LineInterpolation.allCases.map(\.spokenShape)).count == LineInterpolation.allCases.count)
    }

    @Test("Given the sample week, when the Audio Graph summary is written, then it gives the days, first, last, highest and lowest in actual values and how the line is drawn")
    func summaryGivesActualValues() {
        let summary = WeekSalesSummary(days: LineMarkViewModel.sampleWeek, locale: locale)

        #expect(
            summary.audioGraphSummary(drawnAs: "Drawn straight.")
                == "7 days, Sunday, March 1 to Saturday, March 7. First day 190 cups, last day 219 cups. "
                + "Highest: Saturday, March 7, 219 cups. Lowest: Tuesday, March 3, 152 cups. Drawn straight."
        )
    }

    @Test("Given the sample week, when the chart descriptor is made, then it has a title, the summary, and one named continuous series with a point per day")
    func descriptorDescribesTheChart() throws {
        let week = LineMarkViewModel.sampleWeek
        let descriptor = WeekLineChartDescriptor(days: week, locale: locale, drawing: "Drawn straight.").makeChartDescriptor()
        let series = try #require(descriptor.series.first)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(descriptor.title == "Cups sold per day at the Harbour café")
        #expect(descriptor.summary == WeekSalesSummary(days: week, locale: locale).audioGraphSummary(drawnAs: "Drawn straight."))
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Harbour")
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == 7)
        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.last == "Saturday, March 7")
    }

    @Test("Given the sample week, when the descriptor's value axis is read, then it is the drawn scale, the lowest to the highest day rounded to the step and leaving out zero, and says values in cups")
    func descriptorValueAxisHasUnits() throws {
        let yAxis = try #require(
            WeekLineChartDescriptor(days: LineMarkViewModel.sampleWeek, locale: locale, drawing: "").makeChartDescriptor().yAxis
        )

        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == 140 ... 220)
        #expect(yAxis.range == WeekSalesSummary.valueDomain(for: LineMarkViewModel.sampleWeek))
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(190) == "190 cups")
    }
}
