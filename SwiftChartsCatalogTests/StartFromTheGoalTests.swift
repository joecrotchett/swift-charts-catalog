import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct StartFromTheGoalTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ days: [DailySales] = CafeData.thirtyDays) -> StartFromTheGoalSummary {
        StartFromTheGoalSummary(days: days, locale: english)
    }

    // MARK: Choices and configurations

    @Test("Given every distance, when the choices are listed, then there are 27, one for each mix of none or one insight")
    func everyChoiceIsListed() {
        #expect(StartFromTheGoalChoice.all.count == 27)
        #expect(Set(StartFromTheGoalChoice.all).count == 27)
    }

    @Test("Given every possible choice, when each is mapped, then each has one configuration and no two share one")
    func everyChoiceHasItsOwnConfiguration() {
        let configurations = StartFromTheGoalChoice.all.map(\.configuration)
        #expect(Set(configurations).count == StartFromTheGoalChoice.all.count)
    }

    @Test("Given a choice, when it is mapped, then the configuration holds exactly the chosen insights", arguments: StartFromTheGoalChoice.all)
    func configurationHoldsTheChoice(choice: StartFromTheGoalChoice) {
        let configuration = choice.configuration
        #expect(configuration.whole == Set([choice.whole].compactMap(\.self)))
        #expect(configuration.subsets == Set([choice.subset].compactMap(\.self)))
        #expect(configuration.singles == Set([choice.single].compactMap(\.self)))
        #expect(configuration.insightCount <= 3)
    }

    @Test("Given the mistake, when its configuration is read, then it draws all six insights and no choice can reach it")
    func mistakeIsEverything() {
        let model = StartFromTheGoalViewModel()
        model.isShowingMistake = true
        #expect(model.configuration == .everything)
        #expect(model.configuration.insightCount == 6)
        #expect(!StartFromTheGoalChoice.all.map(\.configuration).contains(.everything))
        #expect(!model.arePickersEnabled)
    }

    @Test("Given the screen opens, when its state is read, then three insights are chosen, one at each distance")
    func startsWithThree() {
        let model = StartFromTheGoalViewModel()
        #expect(model.choice == StartFromTheGoalChoice(whole: .average, subset: .weekends, single: .bestDay))
        #expect(model.configuration.insightCount == 3)
        #expect(model.arePickersEnabled)
    }

    // MARK: Figures

    @Test("Given the thirty days, when the figures are worked out, then they match the data")
    func figures() throws {
        let summary = summary()
        #expect(summary.days.count == 30)
        #expect(summary.total == 5596)
        #expect(summary.roundedAverage == 187)
        #expect(summary.range == 150 ... 230)
        #expect(summary.cupsAxis == 0 ... 300)
        #expect(summary.days.filter(summary.isWeekend).count == 9)
        #expect(summary.lastWeek.count == 7)
        let best = try #require(summary.days(for: .bestDay).first)
        #expect(best.day == CafeData.day(28))
        let quietest = try #require(summary.days(for: .quietestDay).first)
        #expect(quietest.day == CafeData.day(2))
    }

    @Test("Given no subset, when emphasis is read, then every day is at full strength; with weekends, only weekend days")
    func emphasis() {
        let summary = summary()
        let none = StartFromTheGoalChoice().configuration
        #expect(summary.days.allSatisfy { summary.isEmphasised($0, in: none) })
        let weekends = StartFromTheGoalChoice(subset: .weekends).configuration
        #expect(summary.days.filter { summary.isEmphasised($0, in: weekends) } == summary.days.filter(summary.isWeekend))
        let lastWeek = StartFromTheGoalChoice(subset: .lastWeek).configuration
        #expect(summary.days.filter { summary.isEmphasised($0, in: lastWeek) } == Array(summary.days.suffix(7)))
    }

    @Test("Given a tie for the best day, when the days are marked, then every tied day is marked and named")
    func tiesAreMarked() {
        let days = [DailySales(day: CafeData.day(0), cups: 40), DailySales(day: CafeData.day(1), cups: 40), DailySales(day: CafeData.day(2), cups: 10)]
        let summary = summary(days)
        let configuration = StartFromTheGoalChoice(single: .bestDay).configuration
        #expect(summary.markedDays(configuration).count == 2)
        #expect(summary.headline(configuration) == "Most cups in a day: 40, on Sunday, March 1 and Monday, March 2.")
    }

    // MARK: Headlines

    @Test("Given the opening choice, when the headline is written, then it states each insight with figures drawn on the chart")
    func openingHeadline() {
        let model = StartFromTheGoalViewModel()
        #expect(model.headline(locale: english)
            == "Averaged 187 cups a day. Weekends sold more a day than weekdays. Most cups in a day: 230, on Sunday, March 29.")
    }

    @Test("Given each single insight, when the headline is written, then it is that insight's sentence")
    func singleInsightHeadlines() {
        let summary = summary()
        #expect(summary.headline(StartFromTheGoalChoice(whole: .range).configuration) == "Between 150 and 230 cups a day.")
        #expect(summary.headline(StartFromTheGoalChoice(subset: .lastWeek).configuration)
            == "The last 7 days sold more a day than the 23 days before.")
        #expect(summary.headline(StartFromTheGoalChoice(single: .quietestDay).configuration)
            == "Fewest cups in a day: 150, on Tuesday, March 3.")
        #expect(summary.headline(StartFromTheGoalChoice().configuration) == "30 days of sales, with nothing singled out.")
    }

    @Test("Given every choice, when its headline is written, then it is not empty")
    func everyChoiceHasAHeadline() {
        let model = StartFromTheGoalViewModel()
        let summary = model.summary(locale: english)
        let headlines = StartFromTheGoalChoice.all.map { summary.headline($0.configuration) }
        #expect(headlines.allSatisfy { !$0.isEmpty })
    }

    @Test("Given no days or only zeros, when the headline is written, then it says nothing sold and the controls are off")
    func emptyAndZeros() {
        for days in [[], [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]] {
            let model = StartFromTheGoalViewModel(days: days)
            #expect(model.headline(locale: english) == "No cups sold in these days.")
            #expect(!model.hasSales)
            #expect(!model.arePickersEnabled)
            #expect(model.summary(locale: english).markedDays(.everything).isEmpty)
            #expect(model.summary(locale: english).audioGraphSummary(.everything) == "No cups sold in these days.")
        }
    }

    @Test("Given a German locale, when the headline is written, then numbers and dates take that locale and the sentence stays English")
    func localeIsPassedIn() {
        let summary = StartFromTheGoalSummary(days: [DailySales(day: CafeData.day(0), cups: 1200)], locale: Locale(identifier: "de_DE"))
        let headline = summary.headline(StartFromTheGoalChoice(single: .bestDay).configuration)
        #expect(headline.contains("1.200"))
        #expect(headline.hasPrefix("Most cups in a day"))
    }

    // MARK: Elements and the Audio Graph

    @Test("Given weekends and the best day, when the best bar's element is written, then it gives the day, cups and both notes")
    func elementText() throws {
        let summary = summary()
        let best = try #require(summary.days(for: .bestDay).first)
        let configuration = StartFromTheGoalChoice(subset: .weekends, single: .bestDay).configuration
        #expect(summary.elementLabel(best) == "Sunday, March 29")
        #expect(summary.elementValue(best, configuration) == "230 cups, weekend, most cups in a day")
        #expect(summary.elementValue(best, StartFromTheGoalChoice().configuration) == "230 cups")
        #expect(summary.averageValue == "187 cups a day")
        #expect(summary.rangeValue == "150 to 230 cups a day")
    }

    @Test("Given one cup, when counts are written, then they agree in number")
    func countsAgree() {
        let summary = summary([DailySales(day: CafeData.day(1), cups: 1)])
        #expect(summary.elementValue(summary.days[0], StartFromTheGoalChoice().configuration) == "1 cup")
        #expect(summary.headline(StartFromTheGoalChoice(whole: .average).configuration) == "Averaged 1 cup a day.")
    }

    @Test("Given the opening choice, when the descriptor is made, then it names the axes, days and series, and summarises what is drawn")
    func descriptor() throws {
        let model = StartFromTheGoalViewModel()
        let summary = model.summary(locale: english)
        let descriptor = StartFromTheGoalChartDescriptor(summary: summary, configuration: model.configuration).makeChartDescriptor()
        #expect(descriptor.title == StartFromTheGoalSummary.audioGraphTitle)
        #expect(descriptor.summary == "30 days, March 1 to March 30. A line marks the average, 187 cups a day. "
            + "Weekend days average 202 cups, other days 180 cups. Those days are drawn at full strength, the rest faded. "
            + "Most cups in a day: 230, on Sunday, March 29.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.count == 30)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan).isEmpty)
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 30)
    }

    // MARK: Announcements

    @Test("Given a picker changes, when the announcement is written, then it says what changed and then the headline")
    func announcements() {
        let model = StartFromTheGoalViewModel()
        model.whole = .range
        #expect(model.announcement(after: .distance(.whole), locale: english)
            == "The whole: Range. \(model.headline(locale: english))")
        model.single = nil
        #expect(model.announcement(after: .distance(.single), locale: english).hasPrefix("A single value: none. "))
        model.isShowingMistake = true
        #expect(model.announcement(after: .mistake, locale: english).hasPrefix("Every insight at once. Averaged 187 cups a day."))
    }

    @Test("Given a marked day, when its label is written, then it carries the day's date as the axis writes it")
    func markerCarriesDate() throws {
        let summary = StartFromTheGoalSummary(days: CafeData.thirtyDays, locale: Locale(identifier: "en_US"))
        let marked = try #require(summary.markedDays(StartFromTheGoalConfiguration.everything).first { $0.insight == .bestDay })
        #expect(summary.markerDate(marked) == "Mar 29")
        #expect(summary.markerAnnotation(marked) == "Most: 230")
    }

    @Test("Given every insight, when the key for the largest text sizes is written, then it repeats each label on the chart")
    func keyEntries() {
        let summary = StartFromTheGoalSummary(days: CafeData.thirtyDays, locale: Locale(identifier: "en_US"))
        #expect(summary.keyEntries(.everything) == [
            "Band: 150 to 230", "Line: Average 187", "Dot: Most: 230, Mar 29", "Dot: Fewest: 150, Mar 3",
        ])
        #expect(summary.keyEntries(StartFromTheGoalChoice().configuration).isEmpty)
    }

    // MARK: Snippets

    @Test("Given each state, when its snippets are listed, then they open on the bars, then each drawn insight's layer, then the mapping")
    func snippetsFollowTheChoice() {
        let model = StartFromTheGoalViewModel()
        #expect(model.snippets.map(\.name) == ["start-from-the-goal-subset", "start-from-the-goal-average",
                                               "start-from-the-goal-single", "start-from-the-goal-insights"])
        model.whole = nil
        model.single = nil
        #expect(model.snippets.map(\.name) == ["start-from-the-goal-subset", "start-from-the-goal-insights"])
        model.isShowingMistake = true
        #expect(model.snippets == StartFromTheGoalViewModel.allSnippets)
    }

    @Test("Given the built app, when its snippets are read, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for reference in StartFromTheGoalViewModel.allSnippets {
            #expect(store[reference.name] != nil, "Missing \(reference.name)")
        }
    }
}
