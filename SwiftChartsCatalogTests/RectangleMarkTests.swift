import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct RectangleMarkTests {
    private let locale = Locale(identifier: "en_US")
    private let region = OrderRegion(queue: 2 ... 3, wait: 100 ... 200)
    private let orders = [
        OrderWait(id: 0, store: "Harbour", queueLength: 1, waitSeconds: 90),
        OrderWait(id: 1, store: "Station", queueLength: 2, waitSeconds: 150),
        OrderWait(id: 2, store: "Harbour", queueLength: 3, waitSeconds: 240),
        OrderWait(id: 3, store: "Station", queueLength: 6, waitSeconds: 200),
    ]
    private let months = [
        MonthlySummary(month: CafeData.month(0), lowestDay: 100, highestDay: 200, averageDay: 150),
        MonthlySummary(month: CafeData.month(1), lowestDay: 90, highestDay: 260, averageDay: 180),
        MonthlySummary(month: CafeData.month(2), lowestDay: 1, highestDay: 210, averageDay: 160),
    ]

    private func summary(_ bounds: RegionBounds) -> OrderRegionSummary {
        OrderRegionSummary(orders: orders, region: region, bounds: bounds, locale: locale)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when it opens, then it shows the region bounded on x with its bounds control")
    func startsOnRegion() {
        let viewModel = RectangleMarkViewModel()

        #expect(viewModel.use == .region)
        #expect(viewModel.bounds == .xOnly)
        #expect(viewModel.showsBoundsControl)
    }

    @Test("Given the tick is chosen, when the controls are laid out, then the bounds control is not offered")
    func tickHidesBounds() {
        let viewModel = RectangleMarkViewModel()
        viewModel.use = .tick

        #expect(!viewModel.showsBoundsControl)
    }

    @Test("Given each use, when the caption and explanation are read, then they are about that use")
    func wordsFollowUse() {
        let viewModel = RectangleMarkViewModel()
        let regionCaption = viewModel.caption
        let regionExplanation = viewModel.explanation
        viewModel.use = .tick

        #expect(regionCaption == "Queue and wait for each order")
        #expect(viewModel.caption == "Cups a day at the Harbour café, by month")
        #expect(regionExplanation.contains("behind"))
        #expect(viewModel.explanation.contains("tick"))
    }

    @Test("Given the sample data, when each setting is chosen, then the headline is the one for the chart then drawn")
    func headlineFollowsControls() {
        let viewModel = RectangleMarkViewModel()

        #expect(viewModel.headline(locale: locale) == "The shaded region holds 12 of 40 orders: queues of 6 to 9 people.")
        viewModel.bounds = .yOnly
        #expect(viewModel.headline(locale: locale) == "The shaded region holds 24 of 40 orders: waits of 100 to 220 seconds.")
        viewModel.bounds = .both
        #expect(viewModel.headline(locale: locale) == "The shaded region holds 9 of 40 orders: queues of 6 to 9 people and waits of 100 to 220 seconds.")
        viewModel.use = .tick
        #expect(viewModel.headline(locale: locale) == "July had the highest average day: 253 cups.")
    }

    @Test("Given a control changes the chart, when the announcement is read, then it changes and carries the new headline")
    func announcementFollowsControls() {
        let viewModel = RectangleMarkViewModel()
        var announcements = [viewModel.announcement(locale: locale)]
        viewModel.bounds = .yOnly
        announcements.append(viewModel.announcement(locale: locale))
        viewModel.bounds = .both
        announcements.append(viewModel.announcement(locale: locale))
        viewModel.use = .tick
        announcements.append(viewModel.announcement(locale: locale))

        #expect(Set(announcements).count == announcements.count)
        #expect(viewModel.announcement(locale: locale) == "Chart changed. Cups a day at the Harbour café, by month. July had the highest average day: 253 cups.")
    }

    // MARK: Snippets

    @Test(
        "Given the region with each bounds, when the snippets are listed, then the edges snippet is the one for those bounds, then the layering",
        arguments: [
            (RegionBounds.xOnly, "rectangle-region-x"), (.yOnly, "rectangle-region-y"), (.both, "rectangle-region-both"),
        ]
    )
    func regionSnippets(bounds: RegionBounds, name: String) {
        let viewModel = RectangleMarkViewModel()
        viewModel.bounds = bounds

        #expect(viewModel.snippets.map(\.name) == [name, "rectangle-region-layer"])
    }

    @Test("Given the tick, when the snippets are listed, then only the tick's code is shown, whatever the bounds")
    func tickSnippets() {
        let viewModel = RectangleMarkViewModel()
        viewModel.use = .tick
        viewModel.bounds = .both

        #expect(viewModel.snippets.map(\.name) == ["rectangle-tick"])
    }

    @Test("Given every setting, when its snippets are looked up in the built app, then each exists and shows a RectangleMark or the region's layer")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = RectangleMarkViewModel()
        var references: [SnippetReference] = []
        for use in RectangleUse.allCases {
            for bounds in RegionBounds.allCases {
                viewModel.use = use
                viewModel.bounds = bounds
                references += viewModel.snippets
            }
        }

        for reference in Set(references) {
            let snippet = try #require(store[reference.name])
            #expect(reference.name.hasPrefix("rectangle-"))
            #expect(!reference.title.isEmpty)
            #expect(snippet.code.contains(reference.name == "rectangle-region-layer" ? "shadedRegion" : "RectangleMark("))
            #expect(snippet.file.hasSuffix("RectangleMarkScreen.swift"))
        }
        #expect(Set(references).count == 5)
    }

    // MARK: The region

    @Test("Given a region, when it is drawn, then its x edges are half a person either side of its queue lengths")
    func regionEdges() {
        #expect(region.queueStart == 1.5)
        #expect(region.queueEnd == 3.5)
    }

    @Test("Given orders, when they are counted in the region, then only the axes that bound it are tested, ends included")
    func regionCounts() {
        #expect(summary(.xOnly).ordersInRegion == 2)
        #expect(summary(.yOnly).ordersInRegion == 2)
        #expect(summary(.both).ordersInRegion == 1)
    }

    @Test("Given orders, when the headline is written, then its count and the region it names follow the bounds")
    func regionHeadline() {
        #expect(summary(.xOnly).headline == "The shaded region holds 2 of 4 orders: queues of 2 to 3 people.")
        #expect(summary(.yOnly).headline == "The shaded region holds 2 of 4 orders: waits of 100 to 200 seconds.")
        #expect(summary(.both).headline == "The shaded region holds 1 of 4 orders: queues of 2 to 3 people and waits of 100 to 200 seconds.")
    }

    @Test("Given one order outside the region, when the headline is written, then the count is zero and the unit agrees")
    func regionHeadlineForOneOrder() {
        let summary = OrderRegionSummary(orders: [orders[0]], region: region, bounds: .xOnly, locale: locale)

        #expect(summary.headline == "The shaded region holds 0 of 1 order: queues of 2 to 3 people.")
    }

    @Test("Given no orders, when the chart's words are written, then they say there are none")
    func noOrders() {
        let summary = OrderRegionSummary(orders: [], region: region, bounds: .both, locale: locale)

        #expect(summary.headline == "No orders yet.")
        #expect(summary.audioGraphSummary == "No orders yet.")
        #expect(summary.portions.isEmpty)
    }

    @Test("Given orders, when the region's element is written, then it names the region and gives its count")
    func regionElement() {
        #expect(summary(.both).regionLabel == "Shaded region, queues of 2 to 3 people and waits of 100 to 200 seconds")
        #expect(summary(.both).regionValue == "1 of 4 orders")
    }

    @Test("Given orders, when they are divided for VoiceOver, then there is a portion per café and stretch of queue lengths holding every order once")
    func portionsCoverEveryOrder() {
        let portions = summary(.xOnly).portions

        #expect(portions.map(\.id) == ["Harbour-0", "Station-0", "Station-4"])
        #expect(portions.flatMap(\.orders).map(\.id).sorted() == [0, 1, 2, 3])
        #expect(portions[0].label == "Harbour, queues of 0 to 3 people")
        #expect(portions[0].value == "2 orders, waits from 90 to 240 seconds")
        #expect(portions[2].value == "1 order, wait 200 seconds")
    }

    @Test("Given the sample data, when it is divided for VoiceOver, then all forty orders are in six portions")
    func samplePortions() {
        let portions = OrderRegionSummary(orders: CafeData.orderWaits, region: .sample, bounds: .xOnly, locale: locale).portions

        #expect(portions.count == 6)
        #expect(portions.map(\.orders.count).reduce(0, +) == 40)
    }

    @Test("Given orders, when the Audio Graph summary is written, then it gives the counts, both ranges and the region in actual values")
    func regionAudioSummary() {
        #expect(
            summary(.xOnly).audioGraphSummary
                == "4 orders at 2 cafés. Queues from 1 to 6 people, waits from 90 to 240 seconds. "
                + "The shaded region, queues of 2 to 3 people, holds 2 orders."
        )
    }

    @Test("Given orders, when the chart descriptor is made, then it has a number on both axes from zero and a named series per café")
    func regionDescriptor() throws {
        let descriptor = OrderRegionChartDescriptor(orders: orders, region: region, bounds: .both, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Queue and wait for each order, by café")
        #expect(descriptor.summary == summary(.both).audioGraphSummary)
        #expect(xAxis.title == "People queuing")
        #expect(xAxis.range == 0 ... 6)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person")
        #expect(yAxis.title == "Wait (seconds)")
        // The longest wait is 240; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(150) == "150 seconds")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.dataPoints.count) == [2, 2])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }

    // MARK: The tick

    @Test("Given months, when the headline is written, then it names the month with the highest average day")
    func tickHeadline() {
        #expect(MonthlyTickSummary(months: months, locale: locale).headline == "April had the highest average day: 180 cups.")
    }

    @Test("Given two months tied for the highest average day, when the headline is written, then it names both")
    func tickHeadlineOnATie() {
        let tied = [
            MonthlySummary(month: CafeData.month(0), lowestDay: 100, highestDay: 200, averageDay: 150),
            MonthlySummary(month: CafeData.month(1), lowestDay: 90, highestDay: 260, averageDay: 150),
        ]

        #expect(MonthlyTickSummary(months: tied, locale: locale).headline == "March and April had the highest average day: 150 cups.")
    }

    @Test("Given no months, or months of zeros, when the chart's words are written, then they say nothing sold")
    func noMonths() {
        let zeros = [MonthlySummary(month: CafeData.month(0), lowestDay: 0, highestDay: 0, averageDay: 0)]

        for summary in [MonthlyTickSummary(months: [], locale: locale), MonthlyTickSummary(months: zeros, locale: locale)] {
            #expect(!summary.hasData)
            #expect(summary.headline == "No sales yet.")
            #expect(summary.audioGraphSummary == "No sales yet.")
        }
    }

    @Test("Given a month, when its element's value is written, then it gives the three figures with units that agree in number")
    func monthValue() {
        #expect(MonthlyTickSummary(months: months, locale: locale).value(for: months[2]) == "Lowest day 1 cup, highest day 210 cups, average day 160 cups")
        #expect(RectangleMarkText.monthAndYear(months[2].month, locale: locale) == "May 2026")
    }

    @Test("Given months, when the Audio Graph summary is written, then it gives the period and the figures in actual values")
    func tickAudioSummary() {
        #expect(
            MonthlyTickSummary(months: months, locale: locale).audioGraphSummary
                == "3 months, March 2026 to May 2026. Lowest day 1 cup, highest day 260 cups. Average day from 150 to 180 cups."
        )
    }

    @Test("Given a German locale, when the region chart's words are written, then their numbers are grouped the German way and the units still agree")
    func regionWordsFollowTheLocale() {
        let german = Locale(identifier: "de_DE")
        let slow = [
            OrderWait(id: 0, store: "Harbour", queueLength: 2, waitSeconds: 1500),
            OrderWait(id: 1, store: "Harbour", queueLength: 3, waitSeconds: 2400),
        ]
        let wide = OrderRegion(queue: 2 ... 3, wait: 1000 ... 2000)
        let summary = OrderRegionSummary(orders: slow, region: wide, bounds: .yOnly, locale: german)
        let descriptor = OrderRegionChartDescriptor(orders: slow, region: wide, bounds: .yOnly, locale: german).makeChartDescriptor()

        #expect(summary.headline == "The shaded region holds 1 of 2 orders: waits of 1.000 to 2.000 seconds.")
        #expect(summary.portions.first?.value == "2 orders, waits from 1.500 to 2.400 seconds")
        #expect(summary.audioGraphSummary.contains("at 1 café."))
        #expect(summary.audioGraphSummary.contains("holds 1 order."))
        #expect(descriptor.yAxis?.valueDescriptionProvider(2400) == "2.400 seconds")
        #expect((descriptor.xAxis as? AXNumericDataAxisDescriptor)?.valueDescriptionProvider(1) == "1 person")
    }

    @Test("Given a locale, when the tick chart's spoken words are written, then months and numbers are in that locale")
    func tickWordsFollowTheLocale() throws {
        let german = Locale(identifier: "de_DE")
        let thousands = [MonthlySummary(month: CafeData.month(0), lowestDay: 900, highestDay: 2400, averageDay: 1500)]
        let summary = MonthlyTickSummary(months: thousands, locale: german)
        let descriptor = MonthlyTickChartDescriptor(months: thousands, locale: german).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(RectangleMarkText.monthAndYear(thousands[0].month, locale: german) == "März 2026")
        #expect(summary.value(for: thousands[0]) == "Lowest day 900 cups, highest day 2.400 cups, average day 1.500 cups")
        #expect(summary.audioGraphSummary.contains("März 2026"))
        #expect(summary.audioGraphSummary.contains("2.400 cups"))
        #expect(xAxis.categoryOrder == ["März 2026"])
        #expect(descriptor.yAxis?.valueDescriptionProvider(2400) == "2.400 cups")
        #expect(descriptor.summary == summary.audioGraphSummary)
    }

    @Test("Given months, when the chart descriptor is made, then months are written out and each figure is a named series from zero")
    func tickDescriptor() throws {
        let descriptor = MonthlyTickChartDescriptor(months: months, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups a day at the Harbour café, by month")
        #expect(descriptor.summary == MonthlyTickSummary(months: months, locale: locale).audioGraphSummary)
        #expect(xAxis.categoryOrder == ["March 2026", "April 2026", "May 2026"])
        #expect(yAxis.title == "Cups")
        // The busiest day is 260, on an axis drawn to 300.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.map(\.name) == ["Lowest day", "Average day", "Highest day"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 3 && !$0.isContinuous })
    }
}
