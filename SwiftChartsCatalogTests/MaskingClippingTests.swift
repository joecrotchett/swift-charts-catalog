import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct MaskingClippingTests {
    private let locale = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    @Test("Given a new screen, when nothing has been changed, then the bars are pills")
    func startsWithPills() {
        #expect(MaskingClippingViewModel().shape == .pill)
    }

    @Test("Given drink sales in any order, when the model is made, then the bars are ranked largest first")
    func ranksTheBars() {
        #expect(MaskingClippingViewModel(sales: sales).sales.map(\.drink) == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given drinks tied on cups, when the model is made, then they keep their data order whatever the order of the rest")
    func tiesKeepDataOrder() {
        let tied = [
            DrinkSales(drink: "Mocha", cups: 20), DrinkSales(drink: "Tea", cups: 50),
            DrinkSales(drink: "Cocoa", cups: 20), DrinkSales(drink: "Latte", cups: 50),
        ]
        #expect(MaskingClippingViewModel(sales: tied).sales.map(\.drink) == ["Tea", "Latte", "Mocha", "Cocoa"])
        #expect(MaskingClippingViewModel.ranked(tied.reversed()).map(\.drink) == ["Latte", "Tea", "Cocoa", "Mocha"])
    }

    @Test("Given each shape, when the headline is written, then it names the tallest bar and its cups")
    func headlineIsTheSameForEveryShape() {
        let model = MaskingClippingViewModel(sales: sales)

        for shape in MaskingClippingShape.allCases {
            model.shape = shape
            #expect(model.summary(locale: locale).headline == "Tea sold the most: 164 cups.")
        }
    }

    @Test("Given two drinks tied for the most, when the headline is written, then it names both")
    func headlineNamesATie() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Cocoa", cups: 40)]

        #expect(MaskingClippingViewModel(sales: tied).summary(locale: locale).headline == "Mocha and Tea sold the most: 90 cups.")
    }

    @Test("Given no sales or only zeros, when the headline is written, then it says nothing has sold")
    func headlineWithNoSales() {
        let zeros = [DrinkSales(drink: "Tea", cups: 0), DrinkSales(drink: "Latte", cups: 0)]

        #expect(MaskingClippingViewModel(sales: []).summary(locale: locale).headline == "No cups sold yet today.")
        #expect(MaskingClippingViewModel(sales: zeros).summary(locale: locale).headline == "No cups sold yet today.")
        #expect(MaskingClippingSummary(sales: zeros, locale: locale).total == 0)
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesTheLocale() {
        let big = [DrinkSales(drink: "Tea", cups: 1234)]

        #expect(MaskingClippingSummary(sales: big, locale: Locale(identifier: "de_DE")).headline == "Tea sold the most: 1.234 cups.")
    }

    @Test("Given a bar of 57 cups, when it is cut into blocks, then there are three and the last ends at 57")
    func blocksEndAtTheValue() {
        let blocks = maskingClippingBlocks(cups: 57)

        #expect(blocks == [
            MaskingClippingBlock(start: 0, end: 18),
            MaskingClippingBlock(start: 20, end: 38),
            MaskingClippingBlock(start: 40, end: 57),
        ])
    }

    @Test("Given a bar that is an exact number of blocks, when it is cut, then the top block has no gap")
    func exactBlocksHaveNoGapAtTheTop() {
        let blocks = maskingClippingBlocks(cups: 40)

        #expect(blocks == [MaskingClippingBlock(start: 0, end: 18), MaskingClippingBlock(start: 20, end: 40)])
    }

    @Test("Given every drink, when its bar is cut into blocks, then the blocks never reach past its cups")
    func blocksNeverWidenTheScale() {
        for item in CafeData.drinkSales {
            let blocks = maskingClippingBlocks(cups: item.cups)
            #expect(blocks.last?.end == item.cups)
            #expect(blocks.allSatisfy { $0.start < $0.end && $0.end <= item.cups })
        }
    }

    @Test("Given no cups or a gap as large as a block, when a bar is cut, then there are no blocks")
    func noBlocksForNothing() {
        #expect(maskingClippingBlocks(cups: 0).isEmpty)
        #expect(maskingClippingBlocks(cups: 50, size: 2, gap: 2).isEmpty)
    }

    @Test("Given each shape, when its snippets are looked up, then they are the ones for that cut")
    func snippetsFollowTheShape() {
        let model = MaskingClippingViewModel(sales: sales)

        model.shape = .none
        #expect(model.snippets.map(\.name) == ["masking-clipping-none"])
        model.shape = .pill
        #expect(model.snippets.map(\.name) == ["masking-clipping-pill"])
        model.shape = .blocks
        #expect(model.snippets.map(\.name) == ["masking-clipping-blocks", "masking-clipping-block-ranges"])
    }

    @Test("Given every shape, when its snippets are read from the bundle, then each exists and shows its modifier")
    func everySnippetExists() throws {
        let store = try SnippetStore()

        for shape in MaskingClippingShape.allCases {
            for reference in shape.snippets {
                #expect(reference.name.hasPrefix("masking-clipping-"))
                #expect(store[reference.name] != nil, "Missing snippet \(reference.name)")
            }
        }
        #expect(try #require(store["masking-clipping-pill"]).code.contains(".clipShape(Capsule())"))
        #expect(try #require(store["masking-clipping-blocks"]).code.contains(".mask {"))
        #expect(try #require(store["masking-clipping-block-ranges"]).code.contains("size: Int = 20"))
    }

    @Test("Given the ranked sales, when the descriptor is made, then it has a title, a summary with units, the drinks in order and a range from zero")
    func descriptorDescribesTheChart() throws {
        let model = MaskingClippingViewModel(sales: sales)
        let descriptor = MaskingClippingChartDescriptor(sales: model.sales, locale: locale).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Cocoa"])
        let yAxis = try #require(descriptor.yAxis)
        // The tallest bar is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }
}
