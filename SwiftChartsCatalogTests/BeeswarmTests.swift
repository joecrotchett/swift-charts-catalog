import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct BeeswarmTests {
    private let locale = Locale(identifier: "en_US")

    private func order(_ id: Int, _ wait: Int, store: String = "Harbour") -> OrderWait {
        OrderWait(id: id, store: store, queueLength: 0, waitSeconds: wait)
    }

    private func summary(_ orders: [OrderWait], crowding: Double, locale: Locale? = nil) -> BeeswarmSummary {
        BeeswarmSummary(
            placed: BeeswarmLayout.place(orders, crowding: crowding), crowding: crowding, locale: locale ?? self.locale
        )
    }

    // MARK: Rows

    @Test("Given waits closer than the crowding, when rows are worked out, then each takes the first free row")
    func closeWaitsStack() {
        let placed = BeeswarmLayout.place([order(0, 100), order(1, 104), order(2, 108), order(3, 150)], crowding: 10)

        #expect(placed.map(\.row) == [0, 1, 2, 0])
    }

    @Test("Given a wait far from the bottom of a pile but close to its top, when it is placed, then it takes the free row beneath")
    func firstFreeRowIsReused() {
        let placed = BeeswarmLayout.place([order(0, 100), order(1, 106), order(2, 112)], crowding: 10)

        #expect(placed.map(\.row) == [0, 1, 0])
    }

    @Test("Given orders out of order, when rows are worked out, then the result runs from the shortest wait to the longest")
    func placedOrdersAreSorted() {
        let placed = BeeswarmLayout.place([order(0, 300), order(1, 50), order(2, 120)], crowding: 10)

        #expect(placed.map(\.order.waitSeconds) == [50, 120, 300])
        #expect(placed.map(\.id) == [1, 2, 0])
    }

    @Test("Given two waits exactly the crowding apart, when rows are worked out, then they share a row")
    func crowdingIsExclusive() {
        let placed = BeeswarmLayout.place([order(0, 100), order(1, 110)], crowding: 10)

        #expect(placed.map(\.row) == [0, 0])
    }

    @Test("Given the sample orders at any crowding, when rows are worked out, then no two orders in a row are closer than the crowding")
    func noOverlapInARow() {
        for crowding in stride(from: 2.0, through: 30.0, by: 1.0) {
            let rows = Dictionary(grouping: BeeswarmLayout.place(CafeData.orderWaits, crowding: crowding), by: \.row)
            for row in rows.values {
                let waits = row.map(\.order.waitSeconds).sorted()
                for (left, right) in zip(waits, waits.dropFirst()) {
                    #expect(Double(right - left) >= crowding)
                }
            }
        }
    }

    // MARK: View model

    @Test("Given a new view model, when it is read, then it holds the forty sample orders at the default crowding")
    func initialState() {
        let viewModel = BeeswarmViewModel()

        #expect(viewModel.orders == CafeData.orderWaits)
        #expect(viewModel.crowding == BeeswarmViewModel.defaultCrowding)
        #expect(BeeswarmViewModel.crowdingRange.contains(viewModel.crowding))
        #expect(viewModel.placed.count == 40)
    }

    @Test("Given the sample orders, when the crowding grows, then the swarm gets deeper and the headline follows it")
    func crowdingChangesDepthAndHeadline() {
        let viewModel = BeeswarmViewModel()
        viewModel.crowding = 2
        let shallow = viewModel.summary(locale: locale)
        viewModel.crowding = 30
        let deep = viewModel.summary(locale: locale)

        #expect(shallow.depth == 2)
        #expect(deep.depth == 8)
        #expect(shallow.headline == "The tallest piles are 2 orders high, in 4 places from 93 to 167 seconds.")
        #expect(deep.headline == "The tallest piles are 8 orders high, in 3 places from 95 to 189 seconds.")
    }

    @Test("Given the sample orders at the default crowding, when the headline is written, then it gives the one tallest pile and where it is")
    func defaultHeadline() {
        let summary = BeeswarmViewModel().summary(locale: locale)

        #expect(summary.depth == 5)
        #expect(summary.peaks.map(\.order.waitSeconds) == [95])
        #expect(summary.headline == "The tallest pile is 5 orders high, at 95 seconds.")
    }

    // MARK: Derived text

    @Test("Given waits that are all far apart, when the headline is written, then it says nothing is stacked")
    func nothingStacked() {
        let summary = summary([order(0, 50), order(1, 100)], crowding: 10)

        #expect(summary.depth == 1)
        #expect(summary.headline == "No two waits are closer than 10 seconds, so nothing is stacked.")
    }

    @Test("Given one order, when the headline is written, then it is still true")
    func oneOrder() {
        #expect(summary([order(0, 50)], crowding: 10).headline == "No two waits are closer than 10 seconds, so nothing is stacked.")
    }

    @Test("Given no orders, when the words are written, then every one of them says so")
    func noOrders() {
        let summary = summary([], crowding: 10)

        #expect(summary.depth == 0)
        #expect(summary.peaks.isEmpty)
        #expect(summary.headline == "No orders yet.")
        #expect(summary.audioGraphSummary == "No orders yet.")
        #expect(summary.spokenCrowding == "10 seconds")
    }

    @Test("Given waits that are all zero, when the headline is written, then it describes the one pile that is drawn")
    func allZeroWaits() {
        let summary = summary([order(0, 0), order(1, 0), order(2, 0)], crowding: 10)

        #expect(summary.headline == "The tallest pile is 3 orders high, at 0 seconds.")
    }

    @Test("Given a pile topped by a one-second wait, when the headline is written, then the unit agrees in number")
    func unitsAgreeInNumber() {
        let summary = summary([order(0, 1), order(1, 1)], crowding: 2)

        #expect(summary.headline == "The tallest pile is 2 orders high, at 1 second.")
    }

    @Test("Given a crowding, when the slider's words are written, then it shows its value and speaks the crowding then the headline")
    func sliderText() {
        let summary = BeeswarmViewModel().summary(locale: locale)

        #expect(summary.crowdingText == "10 seconds")
        #expect(summary.spokenCrowding == "10 seconds. The tallest pile is 5 orders high, at 95 seconds.")
    }

    @Test("Given a crowding that moves the peaks, when the slider's words are written, then they say where the tallest piles now are")
    func sliderTextFollowsThePeaks() {
        let summary = BeeswarmViewModel().summary(locale: locale)
        let viewModel = BeeswarmViewModel()
        viewModel.crowding = 30
        let deep = viewModel.summary(locale: locale)

        #expect(deep.spokenCrowding == "30 seconds. \(deep.headline)")
        #expect(deep.spokenCrowding != summary.spokenCrowding)
    }

    @Test("Given no stacked waits, when the slider's words are written, then they say nothing is stacked")
    func sliderTextWithNothingStacked() {
        #expect(
            summary([order(0, 50)], crowding: 10).spokenCrowding
                == "10 seconds. No two waits are closer than 10 seconds, so nothing is stacked."
        )
    }

    @Test("Given a German locale, when numbers are written, then they follow it")
    func numbersTakeTheLocale() {
        let summary = summary([order(1233, 1500), order(1234, 1500)], crowding: 10, locale: Locale(identifier: "de_DE"))

        #expect(summary.headline.contains("1.500"))
        #expect(BeeswarmWording.name(of: order(1233, 1500), locale: Locale(identifier: "de_DE")) == "Order 1.234, Harbour")
    }

    @Test("Given an order, when it is named, then the order comes first and the café second")
    func orderName() {
        #expect(BeeswarmWording.name(of: order(11, 142, store: "Station"), locale: locale) == "Order 12, Station")
    }

    @Test("Given the sample orders, when the Audio Graph summary is written, then it gives actual values and the crowding")
    func audioGraphSummary() {
        #expect(
            BeeswarmViewModel().summary(locale: locale).audioGraphSummary
                == "40 orders. Shortest wait 59 seconds, longest 309 seconds. "
                + "Orders closer than 10 seconds are stacked. The tallest pile is 5 orders high, at 95 seconds."
        )
    }

    // MARK: Descriptor

    @Test("Given the sample orders, when the descriptor is made, then it has one named series of separate points, one per order")
    func descriptorSeries() throws {
        let summary = BeeswarmViewModel().summary(locale: locale)
        let descriptor = BeeswarmChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Order waits")
        #expect(descriptor.title == BeeswarmWording.chartTitle)
        #expect(descriptor.summary == summary.audioGraphSummary)
        let series = try #require(descriptor.series.first)
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Orders, shortest wait first")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 40)
    }

    @Test("Given the sample orders, when the descriptor's axes are read, then orders run shortest wait first and waits are said in seconds over the drawn range")
    func descriptorAxes() throws {
        let descriptor = BeeswarmChartDescriptor(summary: BeeswarmViewModel().summary(locale: locale)).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Order")
        #expect(xAxis.categoryOrder.count == 40)
        #expect(xAxis.categoryOrder.first == "Order 23, Harbour")
        #expect(yAxis.title == CafeWording.waitAxisTitle)
        // The longest wait is 309 seconds; the axis is drawn to 400, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 400)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        #expect(yAxis.valueDescriptionProvider(142) == "142 seconds")
    }

    @Test("Given no orders, when the descriptor is made, then it has no points and says there are no orders")
    func descriptorWithNoOrders() throws {
        let descriptor = BeeswarmChartDescriptor(summary: summary([], crowding: 10)).makeChartDescriptor()

        #expect(descriptor.summary == "No orders yet.")
        #expect(try #require(descriptor.series.first).dataPoints.isEmpty)
    }

    // MARK: Snippets

    @Test("Given the built app, when the screen's snippets are looked up, then each exists and shows the concept")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        #expect(BeeswarmViewModel.snippetNames == ["beeswarm-rows", "beeswarm-chart"])
        let rows = try #require(store["beeswarm-rows"])
        let chart = try #require(store["beeswarm-chart"])
        #expect(rows.file == "Marks/BeeswarmViewModel.swift")
        #expect(rows.code.contains("first { !taken.contains($0) }"))
        #expect(chart.file == "Marks/BeeswarmScreen.swift")
        #expect(chart.code.contains("PointMark("))
        #expect(chart.code.contains(".chartYAxis(.hidden)"))
    }
}
