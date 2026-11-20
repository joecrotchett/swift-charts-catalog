import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct GroupingTests {
    private let orders = [
        DrinkOrder(drink: "Latte", size: "Small", cups: 30), DrinkOrder(drink: "Latte", size: "Large", cups: 50),
        DrinkOrder(drink: "Tea", size: "Small", cups: 70), DrinkOrder(drink: "Tea", size: "Large", cups: 1),
    ]

    // MARK: The view model's states

    @Test("Given a new screen, when it appears, then the bars are grouped with the default span")
    func startsGrouped() {
        let viewModel = GroupingViewModel()

        #expect(viewModel.arrangement == .grouped)
        #expect(viewModel.span == .automatic)
        #expect(viewModel.layout == .grouped)
        #expect(viewModel.isSpanEnabled)
        #expect(viewModel.orders == CafeData.drinkOrders)
    }

    @Test("Given grouped bars, when a span is chosen, then the layout carries its ratio of the band")
    func spanSetsRatio() {
        let viewModel = GroupingViewModel(orders: orders)

        viewModel.span = .half
        #expect(viewModel.layout == .groupedWithSpan(ratio: 0.5))
        viewModel.span = .whole
        #expect(viewModel.layout == .groupedWithSpan(ratio: 1))
        viewModel.span = .automatic
        #expect(viewModel.layout == .grouped)
    }

    @Test("Given a chosen span, when the bars are stacked, then the span is disabled and has no effect, and is kept")
    func stackedIgnoresSpan() {
        let viewModel = GroupingViewModel(orders: orders, span: .half)

        viewModel.arrangement = .stacked

        #expect(viewModel.layout == .stacked)
        #expect(!viewModel.isSpanEnabled)
        #expect(viewModel.span == .half)
    }

    // MARK: Snippets

    @Test("Given each setting of the controls, when the code is shown, then it is the one snippet that draws that chart")
    func snippetsFollowControls() {
        let viewModel = GroupingViewModel(orders: orders)

        #expect(viewModel.snippets.map(\.name) == ["grouping-grouped"])
        viewModel.span = .half
        #expect(viewModel.snippets.map(\.name) == ["grouping-span"])
        viewModel.span = .whole
        #expect(viewModel.snippets.map(\.name) == ["grouping-span"])
        viewModel.arrangement = .stacked
        #expect(viewModel.snippets.map(\.name) == ["grouping-stacked"])
    }

    @Test("Given the screen's snippets, when they are named, then every name starts with the screen's slug")
    func snippetNamesStartWithSlug() {
        let all = [GroupingViewModel.stackedSnippet, GroupingViewModel.groupedSnippet, GroupingViewModel.spanSnippet]

        #expect(all.allSatisfy { $0.name.hasPrefix("grouping-") })
        #expect(Set(all.map(\.name)).count == all.count)
    }

    // MARK: Derived text

    @Test("Given grouped bars, when the headline is written, then its figure is the tallest single bar")
    func groupedHeadlineNamesTallestBar() {
        let viewModel = GroupingViewModel(orders: orders, arrangement: .grouped)

        #expect(viewModel.headline == "Small Tea sold the most of any drink and size: 70 cups.")
    }

    @Test("Given stacked bars, when the headline is written, then its figure is the tallest stack's total")
    func stackedHeadlineNamesTallestStack() {
        let viewModel = GroupingViewModel(orders: orders, arrangement: .stacked)

        #expect(viewModel.headline == "Latte sold the most across all sizes: 80 cups.")
    }

    @Test("Given the café's sample data, when the headline is written for each arrangement, then it names Tea's total and small Tea")
    func headlinesFollowSampleData() {
        #expect(DrinkOrdersSummary(orders: CafeData.drinkOrders, isStacked: true).headline
            == "Tea sold the most across all sizes: 164 cups.")
        #expect(DrinkOrdersSummary(orders: CafeData.drinkOrders, isStacked: false).headline
            == "Small Tea sold the most of any drink and size: 71 cups.")
    }

    @Test("Given two bars tied for the tallest, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [
            DrinkOrder(drink: "Latte", size: "Small", cups: 40), DrinkOrder(drink: "Latte", size: "Large", cups: 10),
            DrinkOrder(drink: "Tea", size: "Small", cups: 10), DrinkOrder(drink: "Tea", size: "Large", cups: 40),
        ]

        #expect(DrinkOrdersSummary(orders: tied, isStacked: false).headline
            == "Small Latte and Large Tea sold the most of any drink and size: 40 cups.")
        #expect(DrinkOrdersSummary(orders: tied, isStacked: true).headline
            == "Latte and Tea sold the most across all sizes: 50 cups.")
    }

    @Test(
        "Given no rows or only zeros, when the chart's words are written, then they say nothing sold",
        arguments: [[], [DrinkOrder(drink: "Latte", size: "Small", cups: 0), DrinkOrder(drink: "Tea", size: "Small", cups: 0)]],
        [true, false]
    )
    func nothingSoldSaysSo(orders: [DrinkOrder], isStacked: Bool) {
        let summary = DrinkOrdersSummary(orders: orders, isStacked: isStacked)

        #expect(summary.total == 0)
        #expect(summary.tallestBars.isEmpty)
        #expect(summary.headline == "No cups sold yet today.")
        #expect(summary.audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given a count of cups, when it is written, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        #expect(DrinkOrdersSummary.cupsText(1) == "1 cup")
        #expect(DrinkOrdersSummary.cupsText(0) == "0 cups")
        #expect(DrinkOrdersSummary.cupsText(71) == "71 cups")
    }

    @Test("Given each layout, when the Audio Graph summary is written, then it gives the values of the bars as drawn")
    func summaryGivesActualValues() {
        #expect(DrinkOrdersSummary(orders: orders, isStacked: false).audioGraphSummary
            == "2 drinks in 2 sizes, 151 cups in total. Sizes are side by side, so each bar is one size of one drink. "
            + "Most: Small Tea, 70 cups. Fewest: Large Tea, 1 cup.")
        #expect(DrinkOrdersSummary(orders: orders, isStacked: true).audioGraphSummary
            == "2 drinks in 2 sizes, 151 cups in total. Sizes are stacked, so each bar is a drink's total. "
            + "Most: Latte, 80 cups. Fewest: Tea, 71 cups.")
    }

    @Test("Given each setting, when the change is announced, then it says how the bars are arranged and the headline")
    func announcementSaysWhatChanged() {
        let viewModel = GroupingViewModel(orders: orders)

        #expect(viewModel.announcement
            == "Bars side by side, one bar per size in each drink. Small Tea sold the most of any drink and size: 70 cups.")
        viewModel.span = .half
        #expect(viewModel.announcement.hasPrefix("Bars side by side, each group using 50% of its drink's band."))
        viewModel.arrangement = .stacked
        #expect(viewModel.announcement == "Bars stacked, one bar per drink. Latte sold the most across all sizes: 80 cups.")
    }

    @Test("Given each setting, when the explanation is written, then it is about what that setting shows")
    func explanationFollowsControls() {
        let viewModel = GroupingViewModel(orders: orders)

        #expect(viewModel.explanation.contains("position(by:)"))
        viewModel.span = .whole
        #expect(viewModel.explanation.contains("span:"))
        viewModel.arrangement = .stacked
        #expect(viewModel.explanation.contains("stack"))
    }

    @Test("Given orders, when the sizes for the colour scale are listed, then every size is there once in data order")
    func sizesAreInDataOrder() {
        let orders = [
            DrinkOrder(drink: "Latte", size: "Large", cups: 3), DrinkOrder(drink: "Latte", size: "Small", cups: 2),
            DrinkOrder(drink: "Tea", size: "Small", cups: 5), DrinkOrder(drink: "Tea", size: "Medium", cups: 1),
        ]

        #expect(DrinkOrdersSummary(orders: orders, isStacked: true).sizes == ["Large", "Small", "Medium"])
        #expect(DrinkOrdersSummary(orders: CafeData.drinkOrders, isStacked: false).sizes == ["Small", "Medium", "Large"])
    }

    // MARK: The chart descriptor

    @Test("Given grouped bars, when the chart is described, then it has a series per size and a range up to the tallest bar")
    func descriptorWhenGrouped() {
        let descriptor = DrinkOrdersChartDescriptor(orders: orders, isStacked: false).makeChartDescriptor()
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor

        #expect(descriptor.title == "Cups sold today by drink and size, sizes side by side")
        #expect(descriptor.summary == DrinkOrdersSummary(orders: orders, isStacked: false).audioGraphSummary)
        #expect(xAxis?.title == "Drink")
        #expect(xAxis?.categoryOrder == ["Latte", "Tea"])
        #expect(descriptor.yAxis?.title == "Cups")
        // The tallest bar is 70; the axis is drawn to 80, and the descriptor says so.
        #expect(descriptor.yAxis?.range == 0 ... 80)
        #expect(descriptor.series.map(\.name) == ["Small", "Large"])
        #expect(descriptor.series.map(\.dataPoints.count) == [2, 2])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        #expect(descriptor.yAxis?.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.yAxis?.valueDescriptionProvider(70) == "70 cups")
    }

    @Test("Given stacked bars, when the chart is described, then its title says so and its range reaches the tallest stack")
    func descriptorWhenStacked() {
        let descriptor = DrinkOrdersChartDescriptor(orders: orders, isStacked: true).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today by drink, with sizes stacked")
        #expect(descriptor.yAxis?.range == 0 ... 80)
        #expect(descriptor.series.map(\.name) == ["Small", "Large"])
    }

    @Test("Given the café's sample data, when the value axis is worked out, then it is 0 to 200 stacked and 0 to 80 grouped")
    func sampleValueAxis() {
        #expect(DrinkOrdersSummary(orders: CafeData.drinkOrders, isStacked: true).valueDomain == 0 ... 200)
        #expect(DrinkOrdersSummary(orders: CafeData.drinkOrders, isStacked: false).valueDomain == 0 ... 80)
    }
}
