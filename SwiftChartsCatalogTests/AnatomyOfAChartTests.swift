import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AnatomyOfAChartTests {
    private let orders = [
        DrinkOrder(drink: "Latte", size: "Small", cups: 10), DrinkOrder(drink: "Latte", size: "Large", cups: 30),
        DrinkOrder(drink: "Tea", size: "Small", cups: 25), DrinkOrder(drink: "Tea", size: "Large", cups: 1),
    ]

    // MARK: The parts

    @Test("Given the parts of a chart, when they are sorted, then four are building blocks and three can be customised")
    func partsAreSorted() {
        #expect(ChartPart.allCases.map(\.title) == ["Marks", "Scales", "Axes", "Legend", "Plot area"])
        #expect(ChartPart.allCases.filter(\.isBuildingBlock) == [.marks, .scales, .axes, .legend])
        #expect(ChartPart.allCases.filter(\.isCustomisable) == [.axes, .legend, .plotArea])
    }

    // MARK: The view model's states

    @Test("Given a new screen, when nothing is highlighted, then every part is drawn as the framework draws it")
    func startsWithNoHighlight() {
        let viewModel = AnatomyOfAChartViewModel()

        #expect(viewModel.highlight == nil)
        #expect(viewModel.orders == CafeData.drinkOrders)
        #expect(viewModel.look.marksOpacity == 1)
        #expect(viewModel.look.axes == .standard)
        #expect(!viewModel.look.showsScaleNote)
        #expect(!viewModel.look.styledPlotArea)
    }

    @Test("Given the marks are highlighted, when the chart is drawn, then the marks stay at full strength and the axes step back")
    func marksHighlight() {
        let look = AnatomyOfAChartViewModel(highlight: .marks).look

        #expect(look.marksOpacity == 1)
        #expect(look.axes == .muted)
        #expect(!look.showsScaleNote)
        #expect(!look.styledPlotArea)
    }

    @Test("Given the scales are highlighted, when the chart is drawn, then the marks fade and the scales are written on the chart")
    func scalesHighlight() {
        let look = AnatomyOfAChartViewModel(highlight: .scales).look

        #expect(look.marksOpacity == AnatomyMetrics.fadedOpacity)
        #expect(look.axes == .standard)
        #expect(look.showsScaleNote)
        #expect(!look.styledPlotArea)
    }

    @Test("Given the axes are highlighted, when the chart is drawn, then the marks fade and the axes are drawn heavier")
    func axesHighlight() {
        let look = AnatomyOfAChartViewModel(highlight: .axes).look

        #expect(look.marksOpacity == AnatomyMetrics.fadedOpacity)
        #expect(look.axes == .emphasised)
        #expect(!look.showsScaleNote)
        #expect(!look.styledPlotArea)
    }

    @Test("Given the legend is highlighted, when the chart is drawn, then the marks and the axes step back and nothing else changes")
    func legendHighlight() {
        let look = AnatomyOfAChartViewModel(highlight: .legend).look

        #expect(look.marksOpacity == AnatomyMetrics.fadedOpacity)
        #expect(look.axes == .muted)
        #expect(!look.showsScaleNote)
        #expect(!look.styledPlotArea)
    }

    @Test("Given the plot area is highlighted, when the chart is drawn, then it is styled and the marks and axes step back")
    func plotAreaHighlight() {
        let look = AnatomyOfAChartViewModel(highlight: .plotArea).look

        #expect(look.marksOpacity == AnatomyMetrics.fadedOpacity)
        #expect(look.axes == .muted)
        #expect(!look.showsScaleNote)
        #expect(look.styledPlotArea)
    }

    @Test("Given a highlight, when it is set back to none, then the chart returns to the framework's drawing")
    func highlightClears() {
        let viewModel = AnatomyOfAChartViewModel(highlight: .plotArea)

        viewModel.highlight = nil

        #expect(viewModel.look == AnatomyLook(highlight: nil))
    }

    // MARK: Snippets

    @Test("Given no highlight, when See Code opens, then it shows the code of all five parts in order")
    func noHighlightShowsEveryPart() {
        #expect(AnatomyOfAChartViewModel().snippets.map(\.name) == [
            "anatomy-of-a-chart-marks", "anatomy-of-a-chart-scales", "anatomy-of-a-chart-axes",
            "anatomy-of-a-chart-axis-marks", "anatomy-of-a-chart-legend", "anatomy-of-a-chart-plot-area",
        ])
    }

    @Test(
        "Given a highlighted part, when See Code opens, then it shows the code that produces or customises that part",
        arguments: [
            (ChartPart.marks, ["anatomy-of-a-chart-marks"]),
            (.scales, ["anatomy-of-a-chart-marks", "anatomy-of-a-chart-scales", "anatomy-of-a-chart-scale-note"]),
            (.axes, ["anatomy-of-a-chart-axes", "anatomy-of-a-chart-axis-marks"]),
            (.legend, ["anatomy-of-a-chart-marks", "anatomy-of-a-chart-legend"]),
            (.plotArea, ["anatomy-of-a-chart-plot-area"]),
        ]
    )
    func highlightChoosesSnippets(part: ChartPart, names: [String]) {
        #expect(AnatomyOfAChartViewModel(highlight: part).snippets.map(\.name) == names)
    }

    @Test("Given every setting of the highlight, when its snippets are looked up, then each exists in the app and has a title")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for highlight in [ChartPart?.none] + ChartPart.allCases.map(Optional.some) {
            for snippet in AnatomyOfAChartViewModel(highlight: highlight).snippets {
                #expect(store[snippet.name] != nil, "\(snippet.name) is missing")
                #expect(snippet.name.hasPrefix("anatomy-of-a-chart-"))
                #expect(!snippet.title.isEmpty)
            }
        }
    }

    // MARK: Derived text

    @Test("Given any highlight, when the headline is written, then it is the same sentence, about the tallest bar")
    func headlineIgnoresHighlight() {
        for highlight in [ChartPart?.none] + ChartPart.allCases.map(Optional.some) {
            #expect(AnatomyOfAChartViewModel(highlight: highlight).headline == "Tea sold the most: 164 cups.")
        }
    }

    @Test("Given orders by size, when they are summarised, then each drink's total is the height of its bar")
    func totalsPerDrink() {
        let summary = AnatomySummary(orders: orders)

        #expect(summary.drinks == ["Latte", "Tea"])
        #expect(summary.sizes == ["Small", "Large"])
        #expect(summary.totals == [.init(drink: "Latte", cups: 40), .init(drink: "Tea", cups: 26)])
        #expect(summary.headline == "Latte sold the most: 40 cups.")
    }

    @Test("Given two drinks with the same total, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [
            DrinkOrder(drink: "Latte", size: "Small", cups: 20), DrinkOrder(drink: "Tea", size: "Small", cups: 5),
            DrinkOrder(drink: "Tea", size: "Large", cups: 15),
        ]

        #expect(AnatomySummary(orders: tied).headline == "Latte and Tea sold the most: 20 cups.")
    }

    @Test("Given no orders, or orders that are all zero, when the chart's words are written, then they say nothing sold")
    func emptyAndZeroSaySo() {
        let zeros = [DrinkOrder(drink: "Latte", size: "Small", cups: 0), DrinkOrder(drink: "Tea", size: "Small", cups: 0)]

        for summary in [AnatomySummary(orders: []), AnatomySummary(orders: zeros)] {
            #expect(summary.isEmpty)
            #expect(summary.bestSellers.isEmpty)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
        }
    }

    @Test("Given the sample data, when the Audio Graph summary is written, then the drinks and sizes are counted from the data")
    func summaryCountsDrinksAndSizes() {
        #expect(AnatomySummary(orders: CafeData.drinkOrders).audioGraphSummary.hasPrefix("3 drinks in 3 sizes: Small, Medium, and Large. "))
    }

    @Test("Given a drink sold in one size and not in another, when the Audio Graph summary is written, then it does not claim every drink comes in every size")
    func summaryDoesNotClaimEverySize() {
        let uneven = [
            DrinkOrder(drink: "Latte", size: "Small", cups: 10), DrinkOrder(drink: "Latte", size: "Large", cups: 30),
            DrinkOrder(drink: "Tea", size: "Small", cups: 25),
        ]
        let single = [DrinkOrder(drink: "Latte", size: "Small", cups: 10)]

        #expect(AnatomySummary(orders: uneven).audioGraphSummary.hasPrefix("2 drinks in 2 sizes: Small and Large. "))
        #expect(!AnatomySummary(orders: uneven).audioGraphSummary.contains("each in"))
        #expect(AnatomySummary(orders: single).audioGraphSummary.hasPrefix("1 drink in 1 size: Small. "))
    }

    @Test("Given a count of cups, when it is written, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        #expect(AnatomySummary.spokenCups(1) == "1 cup")
        #expect(AnatomySummary.spokenCups(0) == "0 cups")
        #expect(AnatomySummary.spokenCups(164) == "164 cups")
    }

    @Test("Given no highlight, when the sentence under the picker is written, then it invites a choice; otherwise it names the part")
    func highlightSummaryFollowsHighlight() {
        #expect(AnatomyOfAChartViewModel().highlightSummary.hasPrefix("Choose a part"))
        for part in ChartPart.allCases {
            let text = AnatomyOfAChartViewModel(highlight: part).highlightSummary
            #expect(text == part.summary)
            #expect(text.localizedCaseInsensitiveContains(part.title))
        }
    }

    @Test("Given a change of highlight, when it is announced, then the words name the part and say the data is unchanged")
    func announcementNamesThePart() {
        #expect(AnatomyOfAChartViewModel().announcement == "No part highlighted. The chart shows the same cups as before.")
        #expect(AnatomyOfAChartViewModel(highlight: .axes).announcement == "Axes highlighted. The chart shows the same cups as before.")
        #expect(AnatomyOfAChartViewModel(highlight: .plotArea).announcement.hasPrefix("Plot area highlighted."))
        #expect(AnatomyOfAChartViewModel(highlight: .scales).announcement.contains("drawn shorter"))
        for part in ChartPart.allCases {
            #expect(AnatomyOfAChartViewModel(highlight: part).announcement.hasSuffix("The chart shows the same cups as before."))
        }
    }

    // MARK: The Audio Graph

    @Test("Given orders by size, when the chart is described, then it has a title, actual values, and a named series per size")
    func descriptorDescribesTheChart() {
        let descriptor = AnatomyChartDescriptor(orders: orders).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today, by drink and size")
        #expect(descriptor.summary == "2 drinks in 2 sizes: Small and Large. 66 cups in total. Most: Latte, 40 cups. Fewest: Tea, 26 cups.")
        #expect(descriptor.xAxis.title == "Drink")
        #expect((descriptor.xAxis as? AXCategoricalDataAxisDescriptor)?.categoryOrder == ["Latte", "Tea"])
        #expect(descriptor.yAxis?.title == "Cups")
        #expect(descriptor.yAxis?.range == 0 ... 40)
        // The screen's data: a tallest stack of 164 on an axis drawn to 200, and the descriptor says 200.
        #expect(AnatomyChartDescriptor(orders: CafeData.drinkOrders).makeChartDescriptor().yAxis?.range == 0 ... 200)
        #expect(descriptor.yAxis?.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.map(\.name) == ["Small", "Large"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 2 })
    }
}
