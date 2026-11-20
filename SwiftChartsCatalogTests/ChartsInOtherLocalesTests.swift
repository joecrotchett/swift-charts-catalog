import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct ChartsInOtherLocalesTests {
    private let english = Locale(identifier: "en_US")

    private func store(_ name: String, _ cups: [Int]) -> StoreSales {
        StoreSales(store: name, days: cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) })
    }

    private func totals(_ stores: [StoreSales]) -> [CafeRunningTotals] {
        stores.map(CafeRunningTotals.init)
    }

    // MARK: The view model

    @Test("Given a new screen, when nothing has been changed, then the chart follows the device and shows no mistake")
    func startsOnTheDevice() {
        let model = ChartsInOtherLocalesViewModel()

        #expect(model.localeChoice == .device)
        #expect(!model.isRightToLeft)
        #expect(!model.isShowingMistake)
        #expect(model.environment == .device)
        #expect(model.cafes.map(\.store) == ["Harbour", "Station"])
    }

    @Test("Given a locale is chosen, when the environment is read, then only the locale is forced on the chart")
    func localeChoiceForcesOnlyTheLocale() {
        let model = ChartsInOtherLocalesViewModel()
        model.localeChoice = .german

        #expect(model.environment == ChartEnvironment(locale: Locale(identifier: "de_DE")))
    }

    @Test("Given right-to-left is switched on, when the environment is read, then only the layout direction is forced")
    func rightToLeftForcesOnlyTheDirection() {
        let model = ChartsInOtherLocalesViewModel()
        model.isRightToLeft = true

        #expect(model.environment == ChartEnvironment(layoutDirection: .rightToLeft))
    }

    @Test("Given the mistake is switched on, when the environment is read, then it has not changed")
    func mistakeLeavesTheEnvironmentAlone() {
        let model = ChartsInOtherLocalesViewModel()
        model.localeChoice = .arabic
        model.isRightToLeft = true
        let before = model.environment
        model.isShowingMistake = true

        #expect(model.environment == before)
        #expect(before == ChartEnvironment(locale: Locale(identifier: "ar_EG"), layoutDirection: .rightToLeft))
    }

    @Test("Given the locale choices, when they are listed, then the device comes first and two are right-to-left languages")
    func localeChoicesIncludeRightToLeftLanguages() {
        #expect(ChartLocaleChoice.allCases.first == .device)
        #expect(ChartLocaleChoice.device.locale == nil)
        let rightToLeft = ChartLocaleChoice.allCases.filter { choice in
            choice.locale.map { Locale.Language(identifier: $0.identifier).characterDirection == .rightToLeft } ?? false
        }
        #expect(rightToLeft == [.arabic, .hebrew])
        #expect(Set(ChartLocaleChoice.allCases.map(\.title)).count == ChartLocaleChoice.allCases.count)
    }

    // MARK: Snippets

    @Test("Given the mistake is off, when the snippets are read, then they are the four that adapt, and each exists")
    func correctSnippets() throws {
        let model = ChartsInOtherLocalesViewModel()
        let store = try SnippetStore()

        #expect(model.snippets.map(\.name) == [
            "charts-in-other-locales-marks", "charts-in-other-locales-x-axis",
            "charts-in-other-locales-y-axis", "charts-in-other-locales-annotation",
        ])
        for snippet in model.snippets {
            #expect(store[snippet.name] != nil, "\(snippet.name) is missing")
        }
    }

    @Test("Given the mistake is on, when the snippets are read, then they are the four mistakes, and each exists")
    func mistakeSnippets() throws {
        let model = ChartsInOtherLocalesViewModel()
        model.isShowingMistake = true
        let store = try SnippetStore()

        #expect(model.snippets.map(\.name) == [
            "charts-in-other-locales-mistake-strings", "charts-in-other-locales-mistake-x-axis",
            "charts-in-other-locales-mistake-y-axis", "charts-in-other-locales-mistake-annotation",
        ])
        for snippet in model.snippets {
            #expect(store[snippet.name] != nil, "\(snippet.name) is missing")
            #expect(snippet.title.hasPrefix("The mistake"))
        }
    }

    @Test("Given the locale or direction changes, when the snippets are read, then they stay the same")
    func snippetsFollowOnlyTheMistake() {
        let model = ChartsInOtherLocalesViewModel()
        let before = model.snippets
        model.localeChoice = .japanese
        model.isRightToLeft = true

        #expect(model.snippets == before)
    }

    // MARK: Running totals

    @Test("Given daily sales, when running totals are made, then each day holds the total so far")
    func runningTotalsAddUp() {
        let cafe = CafeRunningTotals(sales: store("Harbour", [10, 0, 5, 7]))

        #expect(cafe.days.map(\.cups) == [10, 10, 15, 22])
        #expect(cafe.days.map(\.day) == (0 ..< 4).map(CafeData.day))
        #expect(cafe.finalTotal == 22)
    }

    @Test("Given the sample data, when running totals are made, then the last day equals the sum of the daily sales")
    func sampleTotalsMatchTheData() {
        for sales in CafeData.storeSales {
            #expect(CafeRunningTotals(sales: sales).finalTotal == sales.days.map(\.cups).reduce(0, +))
        }
    }

    @Test("Given ten days, when they are split into weeks, then there is a week of seven and one of three, with distinct ids")
    func weeksAreRunsOfSeven() {
        let weeks = CafeRunningTotals(sales: store("Harbour", Array(repeating: 1, count: 10))).weeks

        #expect(weeks.map(\.days.count) == [7, 3])
        #expect(Set(weeks.map(\.id)).count == 2)
        #expect(CafeRunningTotals(sales: store("Harbour", [])).weeks.isEmpty)
    }

    // MARK: Headline

    @Test("Given the sample data, when the headline is written, then it names the café whose line ends highest")
    func headlineNamesTheLeader() {
        let model = ChartsInOtherLocalesViewModel()
        let leader = model.cafes.max { $0.finalTotal < $1.finalTotal }

        #expect(model.headline == "\(leader?.store ?? "?") ended the period with the most cups sold.")
    }

    @Test("Given any setting of the controls, when the headline is written, then it is the same sentence")
    func headlineHoldsForEveryControl() {
        let model = ChartsInOtherLocalesViewModel()
        let before = model.headline
        model.localeChoice = .arabic
        model.isRightToLeft = true
        model.isShowingMistake = true

        #expect(model.headline == before)
    }

    @Test("Given two cafés that end level, when the headline is written, then it says so")
    func headlineOnATie() {
        let summary = RunningTotalsSummary(cafes: totals([store("Harbour", [3, 4]), store("Station", [5, 2])]), locale: english)

        #expect(summary.leaders.map(\.store) == ["Harbour", "Station"])
        #expect(summary.headline == "Harbour and Station ended the period level.")
    }

    @Test("Given one café, when the headline is written, then it does not claim a tie")
    func headlineForOneCafe() {
        let summary = RunningTotalsSummary(cafes: totals([store("Harbour", [3, 4])]), locale: english)

        #expect(summary.headline == "Harbour ended the period with the most cups sold.")
    }

    @Test("Given no cafés, no days or only zeros, when the words are written, then they say nothing was sold")
    func emptyAndZeroDataSaySo() {
        let cases = [[], totals([store("Harbour", [])]), totals([store("Harbour", [0, 0]), store("Station", [0, 0])])]
        for cafes in cases {
            let summary = RunningTotalsSummary(cafes: cafes, locale: english)

            #expect(!summary.hasData)
            #expect(summary.leaders.isEmpty)
            #expect(summary.headline == "No cups sold yet.")
            #expect(summary.audioGraphSummary == "No cups sold yet.")
        }
    }

    // MARK: Formatted text and baked text

    @Test("Given a count of cups, when it is written for a locale, then the number follows the locale and the unit agrees")
    func cupsTextFollowsTheLocale() {
        #expect(RunningTotalsSummary(cafes: [], locale: english).cupsText(5726) == "5,726 cups")
        #expect(RunningTotalsSummary(cafes: [], locale: Locale(identifier: "de_DE")).cupsText(5726) == "5.726 cups")
        #expect(RunningTotalsSummary(cafes: [], locale: english).cupsText(1) == "1 cup")
        #expect(RunningTotalsSummary(cafes: [], locale: english).cupsText(0) == "0 cups")
    }

    @Test("Given a day, when it is written for a locale, then it is the day in the data's time zone, in that locale's words")
    func dayTextFollowsTheLocale() {
        #expect(RunningTotalsSummary(cafes: [], locale: english).dayText(CafeData.day(0)) == "March 1")
        #expect(RunningTotalsSummary(cafes: [], locale: Locale(identifier: "de_DE")).dayText(CafeData.day(7)) == "8. März")
    }

    @Test("Given the baked labels, when they are made, then they are the same fixed English strings whatever the locale")
    func bakedLabelsNeverChange() {
        #expect(BakedLabels.day(CafeData.day(7)) == "Mar 8")
        #expect(BakedLabels.day(CafeData.month(9)) == "Dec 1")
        #expect(BakedLabels.cups(5000) == "5000")
        #expect(BakedLabels.total(stores: ["Harbour"], cups: 5726) == "Harbour: 5726 cups")
        #expect(BakedLabels.total(stores: ["Harbour", "Station"], cups: 2800) == "Harbour and Station: 2800 cups")
    }

    @Test("Given a week of a café's line, when its accessibility words are written, then the café and days come first and the values have units")
    func weekWords() throws {
        let cafe = CafeRunningTotals(sales: store("Harbour", [100, 100, 100, 100, 100, 100, 100, 1000]))
        let summary = RunningTotalsSummary(cafes: [cafe], locale: english)
        let first = try #require(cafe.weeks.first)
        let last = try #require(cafe.weeks.last)

        #expect(summary.weekLabel(first) == "Harbour, March 1 to March 7")
        #expect(summary.weekValue(first) == "Running total from 100 cups to 700 cups")
        #expect(summary.weekLabel(last) == "Harbour, March 8")
        #expect(summary.weekValue(last) == "Running total from 1,700 cups to 1,700 cups")
    }

    @Test("Given the controls, when the display description is written, then it names the formats, the direction and the mistake")
    func displayDescriptionFollowsEveryControl() {
        let model = ChartsInOtherLocalesViewModel()
        #expect(model.displayDescription == "Shown in the device's formats, in the device's layout direction.")

        model.localeChoice = .hebrew
        #expect(model.displayDescription == "Shown in Hebrew (Israel) formats, in the device's layout direction.")

        model.isRightToLeft = true
        #expect(model.displayDescription == "Shown in Hebrew (Israel) formats, laid out right to left.")

        model.isShowingMistake = true
        #expect(
            model.displayDescription
                == "Shown in Hebrew (Israel) formats, laid out right to left. "
                + "Its axis labels and end label are fixed English strings that ignore the locale."
        )
    }

    // MARK: The chart descriptor

    @Test("Given two cafés, when the chart descriptor is made, then it has a title, a summary in actual values and a continuous series per café")
    func descriptorDescribesTheChart() {
        let cafes = totals([store("Harbour", [1000, 500]), store("Station", [700, 1])])
        let descriptor = RunningTotalsChartDescriptor(cafes: cafes, locale: english, displayDescription: "Shown plainly.")
            .makeChartDescriptor()

        #expect(descriptor.title == "Cups sold so far in March, by café")
        #expect(
            descriptor.summary
                == "Running totals from March 1 to March 2. On the last day: Harbour 1,500 cups and Station 701 cups. Shown plainly."
        )
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.isContinuous) == [true, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [2, 2])
    }

    @Test("Given two cafés, when the descriptor's axes are read, then the days are written out and the values are said in cups from zero")
    func descriptorAxes() throws {
        let cafes = totals([store("Harbour", [1000, 500]), store("Station", [700, 1])])
        let descriptor = RunningTotalsChartDescriptor(cafes: cafes, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder == ["March 1", "March 2"])
        #expect(yAxis.title == "Cups sold so far")
        #expect(yAxis.range == 0 ... 1500)
        #expect(yAxis.range == RunningTotalsSummary(cafes: cafes).valueDomain)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(1500) == "1,500 cups")
    }

    @Test("Given no display description, when the descriptor is made, then the summary is the data's alone")
    func descriptorSummaryWithoutDisplay() {
        let cafes = totals([store("Harbour", [2])])
        let descriptor = RunningTotalsChartDescriptor(cafes: cafes, locale: english).makeChartDescriptor()

        #expect(descriptor.summary == "Running totals from March 1 to March 1. On the last day: Harbour 2 cups.")
    }

    @Test("Given March's running totals, when the value axis is worked out, then it runs to 6,000, the drawn top above 5,726")
    func valueDomainIsTheDrawnAxis() {
        let summary = RunningTotalsSummary(cafes: CafeData.storeSales.map(CafeRunningTotals.init), locale: english)
        #expect(summary.valueDomain == 0 ... 6000)
    }
}
