import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct RuleMarkTests {
    private let locale = Locale(identifier: "en_US")
    private let orders = [
        RuleMarkOrder(number: 1, queueLength: 2, waitSeconds: 100),
        RuleMarkOrder(number: 2, queueLength: 9, waitSeconds: 200),
        RuleMarkOrder(number: 3, queueLength: 4, waitSeconds: 150),
    ]

    private func summary(
        _ direction: RuleDirection, _ use: RuleUse, marked: Int = 2, orders: [RuleMarkOrder]? = nil
    ) -> RuleMarkSummary {
        RuleMarkSummary(orders: orders ?? self.orders, direction: direction, use: use, markedNumber: marked, locale: locale)
    }

    @Test("Given a new screen, when nothing has been changed, then it shows a horizontal threshold and marks the first order")
    func startsWithAHorizontalThreshold() {
        let viewModel = RuleMarkViewModel(orders: orders)

        #expect(viewModel.direction == .horizontal)
        #expect(viewModel.use == .threshold)
        #expect(viewModel.markedNumber == 1)
        #expect(viewModel.markedNumberRange == 1 ... 3)
    }

    @Test("Given the sample data, when the Harbour orders are numbered, then there are twenty, counted from one")
    func harbourOrdersAreNumbered() {
        #expect(RuleMarkOrder.harbour.count == 20)
        #expect(RuleMarkOrder.harbour.map(\.number) == Array(1 ... 20))
    }

    @Test("Given a threshold, when the rule is placed, then it is at the target wait across the plot or the queue limit up it")
    func thresholdValues() {
        #expect(summary(.horizontal, .threshold).ruleValue == 180)
        #expect(summary(.horizontal, .threshold).ruleLabel == "Target: 180")
        #expect(summary(.vertical, .threshold).ruleValue == 8)
        #expect(summary(.vertical, .threshold).ruleLabel == "Limit: 8")
    }

    @Test("Given an average, when the rule is placed, then it is at the mean wait or the mean queue")
    func averageValues() {
        #expect(summary(.horizontal, .average).ruleValue == 150)
        #expect(summary(.horizontal, .average).ruleLabel == "Average: 150")
        #expect(summary(.vertical, .average).ruleValue == 5)
        #expect(summary(.vertical, .average).ruleLabel == "Average: 5")
    }

    @Test("Given a marked order, when the rule is placed, then it is at that order's wait or queue and named after it")
    func markedOrderValues() {
        #expect(summary(.horizontal, .markedOrder).ruleValue == 200)
        #expect(summary(.horizontal, .markedOrder).ruleLabel == "Order 2: 200")
        #expect(summary(.vertical, .markedOrder, marked: 3).ruleValue == 4)
        #expect(summary(.vertical, .markedOrder, marked: 3).ruleLabel == "Order 3: 4")
        #expect(summary(.horizontal, .threshold).markedOrder == nil)
    }

    @Test("Given each setting, when the headline is written, then its figure is the one on the rule")
    func headlinesFollowTheControls() {
        #expect(summary(.horizontal, .threshold).headline == "1 of 3 orders waited longer than the target of 180 seconds.")
        #expect(summary(.vertical, .threshold).headline == "1 of 3 orders met a queue longer than the limit of 8 people.")
        #expect(summary(.horizontal, .average).headline == "Orders waited 150 seconds on average.")
        #expect(summary(.vertical, .average).headline == "Orders met a queue of 5 people on average.")
        #expect(summary(.horizontal, .markedOrder).headline == "Order 2 waited 200 seconds.")
        #expect(summary(.vertical, .markedOrder).headline == "Order 2 met a queue of 9 people.")
    }

    @Test("Given every setting of the sample data, when the headline is written, then it contains the value written on the rule")
    func headlineCarriesTheRuleValue() throws {
        for direction in RuleDirection.allCases {
            for use in RuleUse.allCases {
                let summary = summary(direction, use, marked: 7, orders: RuleMarkOrder.harbour)
                let valueText = try #require(summary.ruleValueText)

                #expect(summary.headline.contains(valueText), "\(direction) \(use)")
            }
        }
    }

    @Test("Given an average that is not a whole number, when it is written, then it has one decimal place")
    func averageKeepsOneDecimal() {
        let uneven = [
            RuleMarkOrder(number: 1, queueLength: 1, waitSeconds: 100),
            RuleMarkOrder(number: 2, queueLength: 2, waitSeconds: 101),
            RuleMarkOrder(number: 3, queueLength: 2, waitSeconds: 101),
        ]

        #expect(summary(.horizontal, .average, orders: uneven).headline == "Orders waited 100.7 seconds on average.")
        #expect(summary(.vertical, .average, orders: uneven).ruleLabel == "Average: 1.7")
    }

    @Test("Given no orders, when the chart's words are written, then they say so and there is no rule")
    func emptyOrdersSaySo() {
        let empty = summary(.horizontal, .average, orders: [])

        #expect(empty.isEmpty)
        #expect(empty.ruleValue == nil)
        #expect(empty.ruleLabel == nil)
        #expect(empty.headline == "No orders yet.")
        #expect(empty.audioGraphSummary == "No orders yet.")
        #expect(RuleMarkViewModel(orders: []).markedNumberRange == 1 ... 1)
        #expect(RuleMarkViewModel(orders: []).announcement(locale: locale) == "No orders yet.")
    }

    @Test("Given orders that are all zeros, when the chart's words are written, then they say there are no orders, not an average of zero")
    func allZeroOrdersSaySo() {
        let zeros = [RuleMarkOrder(number: 1, queueLength: 0, waitSeconds: 0), RuleMarkOrder(number: 2, queueLength: 0, waitSeconds: 0)]

        for use in RuleUse.allCases {
            let summary = summary(.vertical, use, marked: 1, orders: zeros)

            #expect(summary.isEmpty)
            #expect(summary.ruleValue == nil)
            #expect(summary.markedOrder == nil)
            #expect(summary.headline == "No orders yet.")
        }
    }

    @Test("Given a count or a measure of one, when it is written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(RuleMarkSummary.secondsText(1, locale: locale) == "1 second")
        #expect(RuleMarkSummary.secondsText(0, locale: locale) == "0 seconds")
        #expect(RuleMarkSummary.peopleText(1, locale: locale) == "1 person")
        #expect(RuleMarkSummary.peopleText(5.5, locale: locale) == "5.5 people")
        #expect(RuleMarkSummary.ordersText(1, locale: locale) == "1 order")
    }

    @Test("Given a German locale, when the headline, the rule's label and a point's value are written, then their numbers are written the German way")
    func wordsTakeTheLocale() {
        let german = Locale(identifier: "de_DE")
        let slow = [
            RuleMarkOrder(number: 1, queueLength: 1, waitSeconds: 1200),
            RuleMarkOrder(number: 2, queueLength: 2, waitSeconds: 1301),
        ]
        let average = RuleMarkSummary(orders: slow, direction: .horizontal, use: .average, markedNumber: 1, locale: german)

        #expect(average.headline == "Orders waited 1.250,5 seconds on average.")
        #expect(average.ruleLabel == "Average: 1.250,5")
        #expect(average.accessibilityValue(for: slow[0]) == "1 person queuing, waited 1.200 seconds")
        let viewModel = RuleMarkViewModel(orders: slow)
        viewModel.use = .markedOrder
        #expect(viewModel.announcement(locale: german).hasSuffix("Order 1 waited 1.200 seconds."))
    }

    @Test("Given an order, when VoiceOver reads its point, then it hears the order, the queue and the wait, and whether the rule marks it")
    func pointLabelsNameTheOrder() {
        let marked = summary(.horizontal, .markedOrder)

        #expect(marked.accessibilityLabel(for: orders[1]) == "Order 2, marked by the rule")
        #expect(marked.accessibilityLabel(for: orders[0]) == "Order 1")
        #expect(marked.accessibilityValue(for: orders[1]) == "9 people queuing, waited 200 seconds")
        #expect(summary(.horizontal, .threshold).accessibilityLabel(for: orders[1]) == "Order 2")
    }

    @Test("Given each setting, when the screen's snippets are listed, then the rule's code for that setting comes first, then the label's placement and the chart")
    func snippetsFollowTheControls() {
        let viewModel = RuleMarkViewModel(orders: orders)
        let expected: [(RuleDirection, RuleUse, String, String)] = [
            (.horizontal, .threshold, "rule-horizontal", "A threshold: RuleMark(y:)"),
            (.horizontal, .average, "rule-horizontal", "An average: RuleMark(y:)"),
            (.horizontal, .markedOrder, "rule-horizontal-marked", "A marked position: RuleMark(y:)"),
            (.vertical, .threshold, "rule-vertical", "A threshold: RuleMark(x:)"),
            (.vertical, .average, "rule-vertical", "An average: RuleMark(x:)"),
            (.vertical, .markedOrder, "rule-vertical-marked", "A marked position: RuleMark(x:)"),
        ]

        for (direction, use, name, title) in expected {
            viewModel.direction = direction
            viewModel.use = use

            #expect(viewModel.snippets == [
                SnippetReference(name: name, title: title),
                SnippetReference(name: "rule-label-placement", title: "Where the label sits"),
                SnippetReference(name: "rule-chart", title: "One rule beside the data"),
            ])
        }
    }

    @Test("Given the built app, when the screen's snippets are looked up, then each one exists in this screen's source")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        let names = [
            "rule-chart", "rule-horizontal", "rule-vertical", "rule-horizontal-marked", "rule-vertical-marked",
            "rule-label-placement",
        ]
        for name in names {
            #expect(store[name]?.file == "Marks/RuleMarkScreen.swift", "\(name) is missing")
        }
    }

    // MARK: Where the label sits

    @Test("Given the screen as it opens, when the target's label is placed, then it leaves the trailing end, where orders lie, for the leading end above the rule")
    func targetLabelAvoidsTheOrders() throws {
        let target = summary(.horizontal, .threshold, orders: RuleMarkOrder.harbour)
        let usual = try #require(RuleLabelPlacement.preferred.first)

        #expect(usual == RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: true))
        #expect(!target.ordersUnderLabel(usual).isEmpty)
        #expect(target.labelPlacement == RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: false))
    }

    @Test(
        "Given every direction, use and marked order of the sample data, when the label is placed, then it covers no order and stays inside the plot",
        arguments: RuleDirection.allCases, RuleUse.allCases
    )
    func labelIsClearInEveryState(direction: RuleDirection, use: RuleUse) throws {
        let orders = RuleMarkOrder.harbour
        for marked in use == .markedOrder ? orders.map(\.number) : [1] {
            let summary = summary(direction, use, marked: marked, orders: orders)
            let placement = try #require(summary.labelPlacement)

            #expect(summary.ordersUnderLabel(placement).isEmpty, "\(direction) \(use) \(marked)")
            #expect(!summary.labelLeavesPlot(placement), "\(direction) \(use) \(marked)")
        }
    }

    @Test("Given a vertical rule at the highest or the lowest queue, when the label is placed, then it is on the side of the rule that has room")
    func labelStaysInsideAtTheEdges() throws {
        let orders = RuleMarkOrder.harbour
        let longest = try #require(orders.max { $0.queueLength < $1.queueLength })
        let shortest = try #require(orders.min { $0.queueLength < $1.queueLength })
        let atTrailingEdge = summary(.vertical, .markedOrder, marked: longest.number, orders: orders)
        let atLeadingEdge = summary(.vertical, .markedOrder, marked: shortest.number, orders: orders)

        #expect(atTrailingEdge.labelLeavesPlot(RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: true)))
        #expect(atTrailingEdge.labelPlacement?.isOnHigherSide == false)
        #expect(atLeadingEdge.labelLeavesPlot(RuleLabelPlacement(isOnHigherSide: false, isAtHighEnd: true)))
        #expect(atLeadingEdge.labelPlacement?.isOnHigherSide == true)
    }

    @Test("Given no order near the rule's usual label, when it is placed, then it takes the usual place: above the trailing end, or beside the top")
    func labelPrefersTheUsualPlace() {
        let falling = [RuleMarkOrder(number: 1, queueLength: 2, waitSeconds: 40), RuleMarkOrder(number: 2, queueLength: 9, waitSeconds: 10)]
        let usual = RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: true)

        #expect(summary(.horizontal, .average, orders: falling).labelPlacement == usual)
        #expect(summary(.vertical, .average, orders: falling).labelPlacement == usual)
    }

    @Test("Given no orders, when the label is placed, then there is no placement, as there is no rule")
    func noPlacementWithoutARule() {
        let empty = summary(.horizontal, .average, orders: [])

        #expect(empty.labelPlacement == nil)
        #expect(empty.ordersUnderLabel(RuleLabelPlacement(isOnHigherSide: true, isAtHighEnd: true)).isEmpty)
    }

    @Test("Given a control is changed, when the announcement is written, then it says what the rule now is and the new headline")
    func announcementFollowsEveryControl() {
        let viewModel = RuleMarkViewModel(orders: orders)
        #expect(viewModel.announcement(locale: locale)
            == "A horizontal rule marks the target wait, 180 seconds. 1 of 3 orders waited longer than the target of 180 seconds.")

        viewModel.direction = .vertical
        #expect(viewModel.announcement(locale: locale)
            == "A vertical rule marks the queue limit, 8 people. 1 of 3 orders met a queue longer than the limit of 8 people.")

        viewModel.use = .markedOrder
        #expect(viewModel.announcement(locale: locale) == "A vertical rule marks the queue of Order 1, 2 people. Order 1 met a queue of 2 people.")

        viewModel.markedNumber = 3
        #expect(viewModel.announcement(locale: locale) == "A vertical rule marks the queue of Order 3, 4 people. Order 3 met a queue of 4 people.")
    }

    @Test("Given orders and a rule, when the Audio Graph summary is written, then it gives the count, both extents and the rule in actual values")
    func summaryGivesActualValues() {
        #expect(
            summary(.horizontal, .average).audioGraphSummary
                == "3 orders. Queues from 2 to 9 people. Waits from 100 to 200 seconds. "
                + "A horizontal rule marks the average wait, 150 seconds."
        )
    }

    @Test("Given orders, when the chart descriptor is made, then it has a title, the summary, two number axes with units and one series of separate points")
    func descriptorDescribesTheChart() throws {
        let summary = summary(.vertical, .threshold)
        let descriptor = RuleMarkChartDescriptor(summary: summary).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Queue and wait for each order at the Harbour café")
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(xAxis.title == "People queuing")
        // A queue of 9 on an axis drawn to 10.
        #expect(xAxis.range == 0 ... 10)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person")
        #expect(yAxis.title == "Wait (seconds)")
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(150) == "150 seconds")
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 3)
    }

    @Test("Given a rule beyond every order, when the descriptor's axes are made, then their ranges reach the rule as the drawn scale does")
    func descriptorRangeReachesTheRule() throws {
        let short = [RuleMarkOrder(number: 1, queueLength: 2, waitSeconds: 90)]
        let across = RuleMarkChartDescriptor(summary: summary(.horizontal, .threshold, orders: short)).makeChartDescriptor()
        let up = RuleMarkChartDescriptor(summary: summary(.vertical, .threshold, orders: short)).makeChartDescriptor()

        // A target of 180 seconds above every wait: the axis is drawn to 200, and the descriptor says the same.
        #expect(try #require(across.yAxis).range == 0 ... 200)
        #expect(try #require(up.xAxis as? AXNumericDataAxisDescriptor).range == 0 ... 8)
    }
}
