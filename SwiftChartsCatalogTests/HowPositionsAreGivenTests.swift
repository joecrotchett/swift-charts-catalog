import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct HowPositionsAreGivenTests {
    private let harbour = CafeData.orderWaits.filter { $0.store == "Harbour" }

    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    private func description(
        _ mark: PositionedMark, _ x: AxisInput, _ y: AxisInput, orders: [OrderWait]? = nil, locale: Locale? = nil
    ) -> PositionsDescription {
        PositionsDescription(mark: mark, x: x, y: y, orders: orders ?? harbour, locale: locale ?? english)
    }

    // MARK: The view model

    @Test("Given a new screen, when it opens, then it shows a bar with a value on x and an interval on y over the Harbour orders")
    func startsOnAFloatingBar() {
        let viewModel = HowPositionsAreGivenViewModel()

        #expect(viewModel.mark == .bar)
        #expect(viewModel.x == .value)
        #expect(viewModel.y == .interval)
        #expect(viewModel.orders.count == 20)
        #expect(viewModel.orders.allSatisfy { $0.store == "Harbour" })
        #expect(viewModel.description(locale: english).form == .bar(.valueInterval))
    }

    @Test("Given the controls, when each is changed, then the description follows that control alone")
    func controlsChangeOneThing() {
        let viewModel = HowPositionsAreGivenViewModel()

        viewModel.mark = .rule
        #expect(viewModel.description(locale: english) == description(.rule, .value, .interval))
        viewModel.x = .nothing
        #expect(viewModel.description(locale: english) == description(.rule, .nothing, .interval))
        viewModel.y = .value
        #expect(viewModel.description(locale: english) == description(.rule, .nothing, .value))
    }

    // MARK: Which combinations exist

    @Test("Given every combination, when its initializer is looked up, then 25 exist and 11 do not")
    func countsOfCombinations() {
        var existing: [PositionedMark: Int] = [:]
        for mark in PositionedMark.allCases {
            for x in AxisInput.allCases {
                for y in AxisInput.allCases where PositionForm.form(mark: mark, x: x, y: y) != nil {
                    existing[mark, default: 0] += 1
                }
            }
        }

        #expect(existing == [.bar: 7, .rectangle: 9, .rule: 6, .point: 3])
    }

    @Test(
        "Given a combination the mark has no initializer for, when it is looked up, then there is none",
        arguments: [
            (PositionedMark.bar, AxisInput.interval, AxisInput.interval), (.bar, .nothing, .nothing),
            (.rule, .value, .value), (.rule, .interval, .interval), (.rule, .nothing, .nothing),
            (.point, .interval, .value), (.point, .value, .interval), (.point, .interval, .interval),
            (.point, .interval, .nothing), (.point, .nothing, .interval), (.point, .nothing, .nothing),
        ]
    )
    func missingCombinations(mark: PositionedMark, x: AxisInput, y: AxisInput) {
        #expect(PositionForm.form(mark: mark, x: x, y: y) == nil)
    }

    @Test("Given combinations that exist, when they are looked up, then each is the form of its own mark and axes")
    func existingCombinations() {
        #expect(PositionForm.form(mark: .bar, x: .nothing, y: .value) == .bar(.nothingValue))
        #expect(PositionForm.form(mark: .rectangle, x: .nothing, y: .nothing) == .rectangle(.nothingNothing))
        #expect(PositionForm.form(mark: .rule, x: .interval, y: .nothing) == .rule(.intervalNothing))
        #expect(PositionForm.form(mark: .point, x: .value, y: .nothing) == .point(.valueNothing))
    }

    // MARK: The figures

    @Test("Given the Harbour orders, when they are summarised, then the averages have one decimal place and the extremes are the data's")
    func summaryOfTheSampleData() throws {
        let summary = try #require(OrderSummary(orders: harbour))

        #expect(summary.count == 20)
        #expect(summary.averageQueue == 5.8)
        #expect(summary.shortestQueue == 1)
        #expect(summary.longestQueue == 11)
        #expect(summary.averageWait == 142.3)
        #expect(summary.shortestWait == 59)
        #expect(summary.longestWait == 214)
    }

    @Test("Given an average with more decimals than are written, when it is summarised, then the mark's position is the figure the words give")
    func averageIsPlottedWhereItIsWritten() throws {
        let orders = [
            OrderWait(id: 0, store: "Harbour", queueLength: 1, waitSeconds: 100),
            OrderWait(id: 1, store: "Harbour", queueLength: 2, waitSeconds: 101),
            OrderWait(id: 2, store: "Harbour", queueLength: 2, waitSeconds: 101),
        ]
        let summary = try #require(OrderSummary(orders: orders))

        #expect(summary.averageQueue == 1.7)
        #expect(summary.averageWait == 100.7)
        #expect(description(.point, .value, .value, orders: orders).headline
            == "The point shows an average queue of 1.7 people and an average wait of 100.7 seconds at the Harbour café.")
    }

    @Test("Given this screen and the Rule screen, when their axes are titled, then the same orders have the same titles")
    func axisTitlesMatchTheRuleScreen() throws {
        let rule = RuleMarkChartDescriptor(
            summary: RuleMarkSummary(orders: RuleMarkOrder.harbour, direction: .horizontal, use: .average, markedNumber: 1, locale: Locale(identifier: "en_US"))
        ).makeChartDescriptor()
        let positions = PositionsChartDescriptor(description: description(.bar, .value, .interval)).makeChartDescriptor()

        #expect(PositionsDescription.queueAxisTitle == "People queuing")
        #expect(PositionsDescription.waitAxisTitle == "Wait (seconds)")
        #expect(positions.xAxis.title == rule.xAxis.title)
        #expect(try #require(positions.yAxis).title == rule.yAxis?.title)
    }

    @Test("Given this screen and the Rule screen, when each writes the Harbour averages, then the figures agree")
    func averagesMatchTheRuleScreen() throws {
        let summary = try #require(OrderSummary(orders: harbour))
        let ruleQueue = RuleMarkSummary(orders: RuleMarkOrder.harbour, direction: .vertical, use: .average, markedNumber: 1, locale: Locale(identifier: "en_US"))
        let ruleWait = RuleMarkSummary(orders: RuleMarkOrder.harbour, direction: .horizontal, use: .average, markedNumber: 1, locale: Locale(identifier: "en_US"))

        #expect(CafeWording.people(summary.averageQueue, locale: english) == ruleQueue.ruleValueText)
        #expect(CafeWording.seconds(summary.averageWait, locale: english) == ruleWait.ruleValueText)
    }

    @Test("Given no orders, when they are summarised, then there is no summary")
    func noSummaryWithoutOrders() {
        #expect(OrderSummary(orders: []) == nil)
    }

    // MARK: The words

    @Test("Given a value on x and an interval on y, when the headline is written, then it gives the average queue and the range of waits")
    func headlineForValueAndInterval() {
        #expect(description(.bar, .value, .interval).headline
            == "The bar shows an average queue of 5.8 people and waits from 59 to 214 seconds at the Harbour café.")
    }

    @Test("Given nothing on x, when the headline is written, then it says nothing about queues")
    func headlineLeavesOutTheEmptyAxis() {
        #expect(description(.rule, .nothing, .value).headline == "The rule shows an average wait of 142.3 seconds at the Harbour café.")
        #expect(description(.point, .value, .nothing).headline == "The point shows an average queue of 5.8 people at the Harbour café.")
        #expect(description(.rectangle, .interval, .nothing).headline == "The rectangle shows queues from 1 to 11 people at the Harbour café.")
    }

    @Test("Given a rectangle with nothing on either axis, when the headline is written, then it says the rectangle covers every order")
    func headlineForNoPosition() {
        #expect(description(.rectangle, .nothing, .nothing).headline
            == "Given no position, the rectangle covers the whole plot and all 20 orders.")
        #expect(description(.rectangle, .nothing, .nothing).markValue == "all 20 orders, with no position given")
    }

    @Test("Given a combination with no initializer, when the words are written, then they say so and describe no mark")
    func headlineForMissingInitializer() {
        #expect(description(.bar, .interval, .interval).headline == "BarMark has no initializer with an interval on both axes.")
        #expect(description(.rule, .value, .value).headline == "RuleMark has no initializer with a value on both axes.")
        #expect(description(.point, .nothing, .nothing).headline == "PointMark has no initializer with nothing on either axis.")
        #expect(description(.point, .interval, .value).headline == "PointMark has no initializer with an interval on x and a value on y.")
        #expect(description(.point, .interval, .value).markValue == nil)
    }

    @Test("Given no orders, when the words are written, then they say there are none, whatever the controls")
    func headlineForNoOrders() {
        #expect(description(.bar, .value, .interval, orders: []).headline == "No Harbour orders to show.")
        #expect(description(.rule, .value, .value, orders: []).headline == "No Harbour orders to show.")
        #expect(description(.bar, .value, .interval, orders: []).markValue == nil)
        #expect(description(.bar, .value, .interval, orders: []).audioGraphSummary == "No Harbour orders to show.")
    }

    @Test("Given a mark that is drawn, when VoiceOver's value is written, then it is what the mark shows, with units")
    func markValueMatchesTheMark() {
        #expect(description(.bar, .value, .interval).markValue == "an average queue of 5.8 people and waits from 59 to 214 seconds")
        #expect(description(.rule, .nothing, .value).markValue == "an average wait of 142.3 seconds")
    }

    @Test("Given two settings that differ in one control, when the announcement is written, then it names the setting and what is shown")
    func announcementNamesEveryControl() {
        #expect(description(.rule, .nothing, .value).announcement
            == "RuleMark, nothing on x, a value on y. The rule shows an average wait of 142.3 seconds at the Harbour café.")

        let announcements = Set(PositionedMark.allCases.flatMap { mark in
            AxisInput.allCases.flatMap { x in AxisInput.allCases.map { y in description(mark, x, y).announcement } }
        })
        #expect(announcements.count == 36)
    }

    @Test("Given counts of one and of several, when they are written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(CafeWording.people(1, locale: english) == "1 person")
        #expect(CafeWording.people(11, locale: english) == "11 people")
        #expect(CafeWording.seconds(1, locale: english) == "1 second")
        #expect(CafeWording.seconds(142, locale: english) == "142 seconds")
        #expect(CafeWording.people(5.8, locale: english) == "5.8 people")
        #expect(CafeWording.seconds(142.3, locale: english) == "142.3 seconds")
        #expect(CafeWording.orders(1, locale: english) == "1 order")
        #expect(CafeWording.orders(20, locale: english) == "20 orders")
    }

    @Test("Given a German locale, when the chart's words are written, then numbers are written its way and the words stay English")
    func numbersTakeTheLocale() {
        #expect(description(.rule, .nothing, .value, locale: german).headline
            == "The rule shows an average wait of 142,3 seconds at the Harbour café.")
        #expect(description(.point, .value, .nothing, locale: german).headline
            == "The point shows an average queue of 5,8 people at the Harbour café.")
        #expect(HowPositionsAreGivenViewModel().description(locale: german).locale == german)
    }

    // MARK: Snippets

    @Test("Given a combination that exists, when its snippets are listed, then there is one, named for the mark and both axes")
    func snippetForAnInitializer() {
        #expect(description(.bar, .value, .interval).snippets == [
            SnippetReference(name: "how-positions-are-given-bar-value-interval", title: "BarMark: value on x, interval on y"),
        ])
        #expect(description(.rectangle, .nothing, .nothing).snippets.map(\.name) == ["how-positions-are-given-rectangle-nothing-nothing"])
    }

    @Test("Given a combination with no initializer, when its snippets are listed, then it shows the table of combinations")
    func snippetForAMissingInitializer() {
        #expect(description(.rule, .value, .value).snippets == [
            SnippetReference(name: "how-positions-are-given-combinations", title: "Which combinations exist"),
        ])
    }

    @Test("Given every setting of the controls, when the bundle is read, then the snippet each one shows exists in this screen's source")
    func snippetsExistInTheBundle() throws {
        let store = try SnippetStore(bundle: .main)
        var names: Set<String> = []

        for mark in PositionedMark.allCases {
            for x in AxisInput.allCases {
                for y in AxisInput.allCases {
                    for snippet in description(mark, x, y).snippets {
                        names.insert(snippet.name)
                        #expect(store[snippet.name]?.file.hasPrefix("Marks/HowPositionsAreGiven") == true, "\(snippet.name) is missing")
                    }
                }
            }
        }

        #expect(names.count == 26)
        #expect(store["how-positions-are-given-rule-nothing-value"]?.code.hasPrefix("RuleMark(") == true)
    }

    // MARK: The Audio Graph

    @Test("Given the Harbour orders, when the chart descriptor is made, then it has a title, both axes with units and one named series of every order")
    func descriptorDescribesTheOrders() throws {
        let descriptor = PositionsChartDescriptor(description: description(.bar, .value, .interval)).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Queue and wait for each order at the Harbour café")
        #expect(xAxis.title == "People queuing")
        // The longest queue is 11 and the longest wait 214: the axes are drawn to 15 and 300.
        #expect(xAxis.range == 0 ... 15)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person")
        #expect(yAxis.title == "Wait (seconds)")
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(142) == "142 seconds")
        #expect(yAxis.valueDescriptionProvider(142.3) == "142.3 seconds")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 20)
    }

    @Test("Given a setting of the controls, when the Audio Graph summary is written, then it gives the orders in actual values and what the mark shows")
    func descriptorSummaryFollowsTheControls() {
        let summary = PositionsChartDescriptor(description: description(.rule, .nothing, .value)).makeChartDescriptor().summary

        #expect(summary == "20 orders. Queues from 1 to 11 people, waits from 59 to 214 seconds. "
            + "The rule shows an average wait of 142.3 seconds at the Harbour café.")
    }
}
