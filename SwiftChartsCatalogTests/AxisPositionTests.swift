import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AxisPositionTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given a new screen, when it opens, then both charts are at the bottom edge with the automatic preset")
    func startsAtDefaults() {
        let model = AxisPositionViewModel()
        #expect(model.edge == .bottom)
        #expect(model.preset == .automatic)
        #expect(model.barsCaption == "Bars: category axis, bottom, automatic")
        #expect(model.horizontalCaption == "Horizontal bars: value axis, bottom, automatic")
        #expect(model.note == nil)
    }

    @Test("Given a side edge, when it is chosen, then the bars' value axis and the horizontal bars' category axis move")
    func sideEdgeMovesValueAndCategory() {
        let model = AxisPositionViewModel()
        model.edge = .leading
        model.preset = .extended
        #expect(model.barsCaption == "Bars: value axis, leading, extended")
        #expect(model.horizontalCaption == "Horizontal bars: category axis, leading, extended")
    }

    @Test("Given the top edge, when it is chosen, then the bars' category axis and the horizontal bars' value axis move")
    func topEdgeMovesCategoryAndValue() {
        let model = AxisPositionViewModel()
        model.edge = .top
        model.preset = .aligned
        #expect(model.barsMovedAxis == "Category axis")
        #expect(model.horizontalMovedAxis == "Value axis")
        #expect(model.barsCaption == "Bars: category axis, top, aligned")
    }

    @Test("Given each edge, when the snippets are read, then they name that edge's code for both charts and the presets")
    func snippetsFollowEdge() {
        let model = AxisPositionViewModel()
        for edge in AxisPositionEdge.allCases {
            model.edge = edge
            #expect(model.snippets.map(\.name) == [
                "axis-position-bars-\(edge.rawValue)",
                "axis-position-horizontal-\(edge.rawValue)",
                "axis-position-presets",
            ])
        }
    }

    @Test("Given the built app, when its snippets are loaded, then every snippet the screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let model = AxisPositionViewModel()
        for edge in AxisPositionEdge.allCases {
            model.edge = edge
            for reference in model.snippets {
                #expect(store[reference.name] != nil, "missing \(reference.name)")
            }
        }
    }

    @Test("Given the trailing edge, when the preset is automatic or inset, then a note says the names are drawn outside the chart")
    func trailingNotes() throws {
        let model = AxisPositionViewModel()
        model.edge = .trailing
        model.preset = .automatic
        #expect(try #require(model.note).contains("outside the chart's frame"))
        model.preset = .inset
        #expect(try #require(model.note).contains("outside the chart's frame"))
        model.preset = .aligned
        #expect(model.note == nil)
        model.preset = .extended
        #expect(model.note == nil)
    }

    @Test("Given another edge, when the preset is inset, then the note says the labels are inside the plot")
    func insetNote() {
        let model = AxisPositionViewModel()
        model.preset = .inset
        model.edge = .leading
        #expect(model.note == "Inset draws the moved axis's labels inside the plot, in the space the bars use.")
        for edge in [AxisPositionEdge.top, .bottom] {
            model.edge = edge
            #expect(model.note == "Inset draws the moved axis's labels inside the plot, in the space the bars use: "
                + "the vertical bars narrow and cover their names.")
        }
    }

    @Test("Given the screen's data, when the headline is written, then it names the best seller and its cups")
    func headline() {
        let summary = AxisPositionSummary(sales: AxisPositionData.sales, locale: english)
        #expect(AxisPositionData.sales.map(\.drink) == ["Latte", "Tea", "Mocha"])
        #expect(summary.headline == "Tea sold the most: 164 cups.")
        #expect(summary.audioGraphSummary
            == "3 of the 5 drinks, 384 cups between them. Most: Tea, 164 cups. Fewest: Mocha, 92 cups.")
        #expect(summary.caption == "Cups sold today, 3 of the 5 drinks")
    }

    @Test("Given every drink on the menu, when the caption is written, then it does not call them some of the drinks")
    func captionWholeMenu() {
        let summary = AxisPositionSummary(sales: CafeData.drinkSales, locale: english)
        #expect(summary.caption == "Cups sold today, 5 drinks")
    }

    @Test("Given a tie, when the headline is written, then it names both drinks")
    func headlineTie() {
        let sales = [DrinkSales(drink: "Latte", cups: 1), DrinkSales(drink: "Tea", cups: 1)]
        let summary = AxisPositionSummary(sales: sales, locale: english)
        #expect(summary.headline == "Latte and Tea sold the most: 1 cup.")
    }

    @Test("Given no sales or only zeros, when the headline is written, then it says nothing has sold")
    func headlineEmpty() {
        let empty = AxisPositionSummary(sales: [], locale: english)
        let zeros = AxisPositionSummary(sales: [DrinkSales(drink: "Tea", cups: 0)], locale: english)
        #expect(empty.headline == "No cups sold yet today.")
        #expect(zeros.headline == "No cups sold yet today.")
        #expect(zeros.total == 0)
        #expect(zeros.audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given the horizontal chart's descriptor, when it is made, then the categories are on x and values have their unit")
    func descriptor() throws {
        let descriptor = AxisPositionChartDescriptor(
            sales: AxisPositionData.sales, form: "horizontal bars", locale: english
        ).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold today at the Harbour café, 3 of the 5 drinks, as horizontal bars")
        #expect(descriptor.summary
            == "3 of the 5 drinks, 384 cups between them. Most: Tea, 164 cups. Fewest: Mocha, 92 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.drink)
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The longest bar is 164; both axes are drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(164) == "164 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour])
        #expect(descriptor.series.first?.dataPoints.count == 3)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given each text size, when the captions are written, then from Accessibility 3 they name only the chart")
    func captionsShortenAtLargeSizes() {
        let model = AxisPositionViewModel()
        #expect(model.barsCaption(at: .xxxLarge) == "Bars: category axis, bottom, automatic")
        #expect(model.horizontalCaption(at: .accessibility2) == "Horizontal bars: value axis, bottom, automatic")
        #expect(model.barsCaption(at: .accessibility3) == "Bars")
        #expect(model.horizontalCaption(at: .accessibility5) == "Horizontal bars")
    }

    @Test("Given each text size, when the bar chart is laid out, then it thins its numbers from Accessibility 3 and turns its names from Accessibility 4")
    func textSizeThresholds() {
        #expect(!AxisPositionTextSize.isLarge(.accessibility2))
        #expect(AxisPositionTextSize.isLarge(.accessibility3))
        #expect(!AxisPositionTextSize.namesAreVertical(at: .accessibility3))
        #expect(AxisPositionTextSize.namesAreVertical(at: .accessibility4))
        #expect(AxisPositionTextSize.largeValueStride == 100)
    }
}
