import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct WhatYouGetForFreeTests {
    private let orders = [
        DrinkOrder(drink: "Tea", size: "Small", cups: 10), DrinkOrder(drink: "Tea", size: "Large", cups: 30),
        DrinkOrder(drink: "Cocoa", size: "Small", cups: 5), DrinkOrder(drink: "Cocoa", size: "Large", cups: 1),
    ]

    private let noSales = [
        DrinkOrder(drink: "Tea", size: "Small", cups: 0), DrinkOrder(drink: "Cocoa", size: "Small", cups: 0),
    ]

    // MARK: The mark and its snippets

    @Test("Given a new screen, when nothing has been chosen, then the chart is drawn with bars")
    func startsWithBars() {
        #expect(WhatYouGetForFreeViewModel().mark == .bars)
    }

    @Test(
        "Given a mark, when it is chosen, then the Code view shows that mark's snippet alone",
        arguments: [
            (FreeDefaultsMark.bars, "what-you-get-for-free-bars"),
            (FreeDefaultsMark.lines, "what-you-get-for-free-lines"),
            (FreeDefaultsMark.points, "what-you-get-for-free-points"),
        ]
    )
    func snippetFollowsMark(mark: FreeDefaultsMark, name: String) {
        let viewModel = WhatYouGetForFreeViewModel()
        viewModel.mark = mark

        #expect(viewModel.snippets.map(\.name) == [name])
    }

    @Test("Given every mark, when the app's snippets are read, then each mark's snippet was extracted from the source")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for mark in FreeDefaultsMark.allCases {
            #expect(store[mark.snippet.name] != nil)
        }
    }

    // MARK: The defaults named on screen

    @Test(
        "Given a mark, when the defaults are listed, then the same five come first and one about the mark comes last",
        arguments: [
            (FreeDefaultsMark.bars, "Stacking"),
            (FreeDefaultsMark.lines, "Lines and symbols"),
            (FreeDefaultsMark.points, "Symbols"),
        ]
    )
    func defaultsNamed(mark: FreeDefaultsMark, last: String) {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)
        viewModel.mark = mark

        #expect(viewModel.defaults.map(\.name) == ["Value axis", "Category axis", "Category order", "Colours", "Legend", last])
    }

    @Test("Given data that is not alphabetical, when the category order is described, then it is the order of the data")
    func categoryOrderFollowsData() {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)
        let order = viewModel.defaults.first { $0.name == "Category order" }

        #expect(viewModel.summary.drinks == ["Tea", "Cocoa"])
        #expect(order?.detail.hasPrefix("Tea and Cocoa:") == true)
    }

    @Test("Given two sizes, when the colours are described, then the first size in the data is blue and the second green")
    func coloursFollowDataOrder() {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)

        #expect(viewModel.colourAssignments == ["Small is blue", "Large is green"])
        #expect(viewModel.symbolAssignments == ["Small is circle", "Large is cross"])
        #expect(viewModel.lineSymbolAssignments == ["Small is circle", "Large is square"])
    }

    @Test("Given lines, when their symbols are described, then the shapes named are the outlined ones lines get, not the ones points get")
    func lineSymbolsDescribed() {
        let viewModel = WhatYouGetForFreeViewModel()
        viewModel.mark = .lines

        #expect(viewModel.defaults.last?.detail.hasSuffix("Small is circle, Medium is square, and Large is triangle.") == true)
    }

    @Test("Given more sizes than line symbols this screen has seen, when lines are described, then no shape is named")
    func lineSymbolsNotGuessed() {
        let many = (1 ... 4).map { DrinkOrder(drink: "Tea", size: "Size \($0)", cups: $0) }
        let viewModel = WhatYouGetForFreeViewModel(orders: many)
        viewModel.mark = .lines

        #expect(viewModel.lineSymbolAssignments.isEmpty)
        #expect(viewModel.defaults.last?.detail.hasSuffix("an outlined shape for its size.") == true)
    }

    @Test("Given more sizes than there are automatic colours, when the colours are described, then the eighth starts again at blue")
    func coloursRepeatAfterSeven() {
        let many = (1 ... 8).map { DrinkOrder(drink: "Tea", size: "Size \($0)", cups: $0) }
        let viewModel = WhatYouGetForFreeViewModel(orders: many)

        #expect(viewModel.colourAssignments.first == "Size 1 is blue")
        #expect(viewModel.colourAssignments.last == "Size 8 is blue")
    }

    @Test("Given the sample data, when the colours are described, then Small, Medium and Large get blue, green and orange")
    func sampleDataColours() {
        #expect(WhatYouGetForFreeViewModel().colourAssignments == ["Small is blue", "Medium is green", "Large is orange"])
    }

    @Test("Given bars, when the legend is described, then it has circles; given lines or points, each size's own symbol")
    func legendSwatchFollowsMark() {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)
        let barsLegend = viewModel.defaults.first { $0.name == "Legend" }
        viewModel.mark = .points
        let pointsLegend = viewModel.defaults.first { $0.name == "Legend" }

        #expect(barsLegend?.detail.contains("a circle for each size") == true)
        #expect(pointsLegend?.detail.contains("its own symbol for each size") == true)
    }

    @Test("Given bars, when the value axis is described, then it rounds past the tallest stack, not the largest value")
    func valueAxisFollowsMark() {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)
        let bars = viewModel.defaults.first?.detail
        viewModel.mark = .lines
        let lines = viewModel.defaults.first?.detail

        #expect(bars?.contains("the tallest stack") == true)
        #expect(lines?.contains("the largest value") == true)
    }

    @Test("Given no sales, when the defaults are listed, then the only one named is that a chart with no data draws nothing")
    func noDataDefault() {
        #expect(WhatYouGetForFreeViewModel(orders: []).defaults.map(\.name) == ["No data"])
        #expect(WhatYouGetForFreeViewModel(orders: noSales).defaults.map(\.name) == ["No data"])
    }

    @Test(
        "Given a change of mark, when it is announced, then the announcement names the mark and gives the headline true of that mark",
        arguments: [
            (FreeDefaultsMark.bars, "Chart now drawn with bars. Tea sold the most: 40 cups."),
            (FreeDefaultsMark.lines, "Chart now drawn with lines. Large Tea sold the most: 30 cups."),
            (FreeDefaultsMark.points, "Chart now drawn with points. Large Tea sold the most: 30 cups."),
        ]
    )
    func announcementNamesMark(mark: FreeDefaultsMark, expected: String) {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)
        viewModel.mark = mark

        #expect(viewModel.changeAnnouncement == expected)
        #expect(viewModel.changeAnnouncement.hasSuffix(viewModel.summary.headline))
    }

    @Test(
        "Given the café's sample data, when the headline is written for a mark, then its figure is the largest value that mark draws",
        arguments: [
            (FreeDefaultsMark.bars, "Tea sold the most: 164 cups."),
            (FreeDefaultsMark.lines, "Small Tea sold the most: 71 cups."),
            (FreeDefaultsMark.points, "Small Tea sold the most: 71 cups."),
        ]
    )
    func headlineFollowsMark(mark: FreeDefaultsMark, expected: String) {
        let viewModel = WhatYouGetForFreeViewModel()
        viewModel.mark = mark

        #expect(viewModel.summary.headline == expected)
    }

    @Test("Given lines, when the explanation is written, then it says a line over categories is here only to show the defaults; given bars or points, it does not")
    func explanationQualifiesTheLine() {
        let viewModel = WhatYouGetForFreeViewModel(orders: orders)
        let bars = viewModel.explanation
        viewModel.mark = .lines
        let lines = viewModel.explanation
        viewModel.mark = .points

        #expect(bars.hasPrefix("Nothing about this chart was configured"))
        #expect(lines.hasPrefix(bars))
        #expect(lines.hasSuffix("a line over them is shown here only to show the defaults a line gets."))
        #expect(viewModel.explanation == bars)
    }

    // MARK: The chart's words

    @Test("Given orders by drink and size, when the headline is written, then it names the drink with the most cups across sizes")
    func headlineNamesBestSeller() {
        #expect(FreeDefaultsSummary(orders: orders).headline == "Tea sold the most: 40 cups.")
    }

    @Test("Given the café's sample data, when the headline is written, then it is Tea with 164 cups")
    func headlineForSampleData() {
        #expect(FreeDefaultsSummary(orders: CafeData.drinkOrders).headline == "Tea sold the most: 164 cups.")
    }

    @Test("Given two drinks tied for the most cups, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [
            DrinkOrder(drink: "Mocha", size: "Small", cups: 20), DrinkOrder(drink: "Tea", size: "Small", cups: 5),
            DrinkOrder(drink: "Tea", size: "Large", cups: 15),
        ]

        #expect(FreeDefaultsSummary(orders: tied).headline == "Mocha and Tea sold the most: 20 cups.")
    }

    @Test("Given one cup sold, when the headline is written, then the unit agrees with the number")
    func oneCupIsSingular() {
        let one = [DrinkOrder(drink: "Tea", size: "Small", cups: 1)]

        #expect(FreeDefaultsSummary(orders: one).headline == "Tea sold the most: 1 cup.")
        #expect(FreeDefaultsSummary(orders: one).audioGraphSummary == "1 drink in 1 size, 1 cup in total. Most: Tea, 1 cup. Fewest: Tea, 1 cup.")
    }

    @Test("Given values that are not stacked, when the headline is written, then it names the drink and size with the most cups, and both on a tie")
    func unstackedHeadlineNamesDrinkAndSize() {
        let tied = [
            DrinkOrder(drink: "Mocha", size: "Small", cups: 20), DrinkOrder(drink: "Tea", size: "Small", cups: 5),
            DrinkOrder(drink: "Tea", size: "Large", cups: 20),
        ]

        #expect(FreeDefaultsSummary(orders: orders, isStacked: false).headline == "Large Tea sold the most: 30 cups.")
        #expect(FreeDefaultsSummary(orders: tied, isStacked: false).headline == "Small Mocha and Large Tea sold the most: 20 cups.")
    }

    @Test("Given values that are not stacked, when the Audio Graph summary is written, then the most and fewest are single values, not totals")
    func unstackedSummaryGivesSingleValues() {
        #expect(
            FreeDefaultsSummary(orders: orders, isStacked: false).audioGraphSummary
                == "2 drinks in 2 sizes, 46 cups in total. Most: Large Tea, 30 cups. Fewest: Large Cocoa, 1 cup."
        )
    }

    @Test("Given counts of cups, drinks and sizes, when they are written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(FreeDefaultsSummary.cupsText(1) == "1 cup")
        #expect(FreeDefaultsSummary.cupsText(0) == "0 cups")
        #expect(FreeDefaultsSummary.drinksText(1) == "1 drink")
        #expect(FreeDefaultsSummary.drinksText(3) == "3 drinks")
        #expect(FreeDefaultsSummary.sizesText(1) == "1 size")
        #expect(FreeDefaultsSummary.sizesText(3) == "3 sizes")
    }

    @Test("Given no orders or only zeros, when the chart's words are written, then they say nothing sold", arguments: [true, false])
    func emptyAndZeroSaySo(isStacked: Bool) {
        for data in [[], noSales] {
            let summary = FreeDefaultsSummary(orders: data, isStacked: isStacked)

            #expect(summary.total == 0)
            #expect(summary.bestSellers.isEmpty)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
        }
    }

    @Test("Given orders, when the Audio Graph summary is written, then it gives counts, the total, the most and the fewest")
    func audioGraphSummaryGivesValues() {
        #expect(
            FreeDefaultsSummary(orders: orders).audioGraphSummary
                == "2 drinks in 2 sizes, 46 cups in total. Most: Tea, 40 cups. Fewest: Cocoa, 6 cups."
        )
    }

    // MARK: The chart descriptor

    @Test("Given stacked bars, when the chart is described, then it has a title, a summary, named axes, one named series per size and a scale up to the tallest stack")
    func descriptorDescribesChart() {
        let descriptor = FreeDefaultsChartDescriptor(orders: orders, isStacked: true).makeChartDescriptor()
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor

        #expect(descriptor.title == "Cups sold today, by drink and size")
        #expect(descriptor.summary == FreeDefaultsSummary(orders: orders).audioGraphSummary)
        #expect(xAxis?.title == "Drink")
        #expect(xAxis?.categoryOrder == ["Tea", "Cocoa"])
        #expect(descriptor.yAxis?.title == "Cups")
        #expect(descriptor.yAxis?.range == 0 ... 40)
        #expect(descriptor.series.map(\.name) == ["Small", "Large"])
        #expect(descriptor.series.map(\.dataPoints.count) == [2, 2])
        #expect(descriptor.yAxis?.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.yAxis?.valueDescriptionProvider(30) == "30 cups")
    }

    @Test("Given lines or points, when the chart is described, then the summary and the scale are about single values, not stacks")
    func descriptorFollowsWhatIsDrawn() {
        let descriptor = FreeDefaultsChartDescriptor(orders: orders, isStacked: false).makeChartDescriptor()

        #expect(descriptor.summary == FreeDefaultsSummary(orders: orders, isStacked: false).audioGraphSummary)
        #expect(descriptor.summary?.contains("Most: Large Tea, 30 cups.") == true)
        #expect(descriptor.yAxis?.range == 0 ... 30)
    }

    @Test("Given the sample data, when the descriptor is made, then its range is the drawn axis: 0 to 200 for the stacks, 0 to 80 for single values")
    func descriptorRangeIsTheDrawnAxis() {
        let stacked = FreeDefaultsChartDescriptor(orders: CafeData.drinkOrders, isStacked: true).makeChartDescriptor()
        let single = FreeDefaultsChartDescriptor(orders: CafeData.drinkOrders, isStacked: false).makeChartDescriptor()
        #expect(stacked.yAxis?.range == 0 ... 200)
        #expect(single.yAxis?.range == 0 ... 80)
    }

    @Test("Given any mark, when the chart is described, then no series is continuous, because drinks are separate categories", arguments: [true, false])
    func descriptorSeriesAreNeverContinuous(isStacked: Bool) {
        let descriptor = FreeDefaultsChartDescriptor(orders: orders, isStacked: isStacked).makeChartDescriptor()

        #expect(descriptor.series.map(\.isContinuous) == [false, false])
    }

    @Test("Given each mark, when it is asked whether it stacks, then only bars do")
    func onlyBarsStack() {
        #expect(FreeDefaultsMark.allCases.map(\.stacksValues) == [true, false, false])
    }
}
