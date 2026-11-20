import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct BarMarkTests {
    private let locale = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    @Test("Given a new screen, when nothing has been changed, then the bars are vertical, automatic and one per drink")
    func startsWithVerticalBars() {
        let model = BarMarkViewModel()

        #expect(model.orientation == .vertical)
        #expect(model.width == .automatic)
        #expect(!model.removesCategory)
    }

    @Test("Given drink sales in any order, when the model is made, then the bars are ranked largest first")
    func ranksTheBars() {
        #expect(BarMarkViewModel(sales: sales).sales.map(\.drink) == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given two drinks that sold the same, when the bars are ranked, then the tied drinks keep their order")
    func rankingKeepsTiesInOrder() {
        let tied = [DrinkSales(drink: "Cocoa", cups: 40), DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90)]

        #expect(BarMarkSummary.ranked(tied).map(\.drink) == ["Mocha", "Tea", "Cocoa"])
    }

    @Test("Given a bar per drink, when the headline is written, then it names the longest bar and its cups in either orientation")
    func headlineNamesTheLongestBar() {
        let model = BarMarkViewModel(sales: sales)

        #expect(model.headline(locale: locale) == "Tea sold the most: 164 cups.")
        model.orientation = .horizontal
        model.width = .fixed
        #expect(model.headline(locale: locale) == "Tea sold the most: 164 cups.")
        #expect(model.caption == "Cups sold today, by drink")
    }

    @Test("Given the category removed, when the headline is written, then it gives the one bar's total")
    func headlineGivesTheTotalOfOneBar() {
        let model = BarMarkViewModel(sales: sales)
        model.removesCategory = true

        #expect(model.headline(locale: locale) == "349 cups sold in total.")
        #expect(model.caption == "Cups sold today, all drinks")
    }

    @Test("Given two drinks tied for the most, when the headline is written, then it names both")
    func headlineNamesATie() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Cocoa", cups: 40)]

        #expect(BarMarkViewModel(sales: tied).headline(locale: locale) == "Mocha and Tea sold the most: 90 cups.")
    }

    @Test(
        "Given no sales or only zeros, when the chart's words are written, then they say nothing sold in every setting",
        arguments: [[], [DrinkSales(drink: "Latte", cups: 0), DrinkSales(drink: "Tea", cups: 0)]], [false, true]
    )
    func emptySalesSaySo(sales: [DrinkSales], removesCategory: Bool) {
        let model = BarMarkViewModel(sales: sales)
        model.removesCategory = removesCategory

        #expect(model.summary(locale: locale).isEmpty)
        #expect(model.headline(locale: locale) == "No cups sold yet today.")
        #expect(model.summary(locale: locale).audioGraphSummary == "No cups sold yet today.")
        #expect(model.announcement(locale: locale) == "No cups sold yet today.")
    }

    @Test("Given a count, when it is written with its unit, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(CafeWording.cups(1, locale: locale) == "1 cup")
        #expect(CafeWording.cups(0, locale: locale) == "0 cups")
        #expect(CafeWording.cups(1640, locale: locale) == "1,640 cups")
        #expect(CafeWording.drinks(1, locale: locale) == "1 drink")
        #expect(CafeWording.drinks(5, locale: locale) == "5 drinks")
    }

    @Test("Given a German locale, when the headline and a bar's value are written, then the numbers are grouped the German way")
    func countsTakeTheLocale() {
        let german = Locale(identifier: "de_DE")
        let model = BarMarkViewModel(sales: [DrinkSales(drink: "Tea", cups: 1640)])

        #expect(model.headline(locale: german) == "Tea sold the most: 1.640 cups.")
        #expect(CafeWording.cups(1640, locale: german) == "1.640 cups")
        #expect(CafeWording.cups(1, locale: german) == "1 cup")
    }

    @Test("Given each orientation, when the explanation is written, then it names the parameter that runs across the bar")
    func thicknessParameterFollowsOrientation() {
        let model = BarMarkViewModel(sales: sales)
        model.width = .fixed

        #expect(model.thicknessParameter == "width:")
        #expect(model.explanation.contains("width: .fixed(12) is 12 points"))
        model.orientation = .horizontal
        #expect(model.thicknessParameter == "height:")
        #expect(model.explanation.contains("height: .fixed(12) is 12 points"))
    }

    @Test("Given each setting of the controls, when the explanation is written, then it describes that setting")
    func explanationFollowsTheControls() {
        let model = BarMarkViewModel(sales: sales)

        #expect(model.explanation.contains("the bars rise from zero"))
        #expect(model.explanation.contains("a band of its own"))
        #expect(model.explanation.contains("the framework chooses"))
        model.orientation = .horizontal
        model.width = .ratio
        #expect(model.explanation.contains("grow from the leading edge"))
        #expect(model.explanation.contains("height: .ratio(0.9)"))
        model.removesCategory = true
        #expect(model.explanation.contains("land in one bar"))
        #expect(model.explanation.contains("there is no band"))
        #expect(!model.explanation.contains(".ratio("))
    }

    @Test("Given the category removed, when the explanation is written, then it speaks of one bar and of the direction that bar fills the plot in")
    func oneBarExplanationFollowsOrientation() {
        let model = BarMarkViewModel(sales: sales)
        model.removesCategory = true

        #expect(model.explanation.hasPrefix("The number is on y, so the bar rises from zero."))
        #expect(model.explanation.contains("the bar fills the plot from side to side"))
        #expect(!model.explanation.contains("the bars"))
        model.orientation = .horizontal
        #expect(model.explanation.hasPrefix("The number is on x, so the bar grows from the leading edge."))
        #expect(model.explanation.contains("the bar fills the plot from top to bottom"))
        #expect(!model.explanation.contains("the bars"))
        #expect(!model.explanation.contains("side to side"))
    }

    @Test("Given each setting of the controls, when the snippets are listed, then the chart's code and the thickness's code follow it")
    func snippetsFollowTheControls() {
        let model = BarMarkViewModel(sales: sales)

        #expect(model.snippets.map(\.name) == ["bar-vertical", "bar-width-automatic"])
        model.orientation = .horizontal
        model.width = .ratio
        #expect(model.snippets.map(\.name) == ["bar-horizontal", "bar-width-ratio"])
        model.removesCategory = true
        model.width = .fixed
        #expect(model.snippets.map(\.name) == ["bar-horizontal-one"])
        model.orientation = .vertical
        #expect(model.snippets.map(\.name) == ["bar-vertical-one"])
        model.removesCategory = false
        #expect(model.snippets.map(\.name) == ["bar-vertical", "bar-width-fixed"])
    }

    @Test("Given every setting of the controls, when its snippets are looked up, then each is in the bundle and listed for registration")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        let model = BarMarkViewModel(sales: sales)
        var shown = Set<String>()

        for orientation in BarMarkViewModel.Orientation.allCases {
            for width in BarMarkViewModel.BarWidth.allCases {
                for removesCategory in [false, true] {
                    model.orientation = orientation
                    model.width = width
                    model.removesCategory = removesCategory
                    shown.formUnion(model.snippets.map(\.name))
                }
            }
        }

        #expect(shown == Set(BarMarkViewModel.allSnippets.map(\.name)))
        for name in shown {
            #expect(name.hasPrefix("bar-"))
            #expect(store[name] != nil, "Missing snippet \(name)")
        }
    }

    @Test("Given the thickness snippets, when they are read, then they carry the numbers the explanation gives")
    func snippetsAgreeWithTheExplanation() throws {
        let store = try SnippetStore()

        #expect(try #require(store["bar-width-ratio"]).code.contains(".ratio(\(BarMarkViewModel.BarWidth.bandRatio.formatted()))"))
        #expect(try #require(store["bar-width-fixed"]).code.contains(".fixed(\(BarMarkViewModel.BarWidth.fixedPoints.formatted()))"))
    }

    @Test("Given every setting that draws a different chart, when the announcements are written, then no two say the same thing")
    func announcementFollowsEveryControl() {
        let model = BarMarkViewModel(sales: sales)
        var announcements = Set<String>()

        for orientation in BarMarkViewModel.Orientation.allCases {
            for width in BarMarkViewModel.BarWidth.allCases {
                for removesCategory in [false, true] {
                    model.orientation = orientation
                    model.width = width
                    model.removesCategory = removesCategory
                    announcements.insert(model.announcement(locale: locale))
                }
            }
        }

        // Six charts with a bar per drink; the one bar is drawn the same whatever the thickness, once each way.
        #expect(announcements.count == 8)
        model.orientation = .horizontal
        model.width = .fixed
        model.removesCategory = false
        #expect(model.announcement(locale: locale) == "Horizontal bars, one per drink, 12 points thick. Tea sold the most: 164 cups.")
        model.removesCategory = true
        #expect(model.announcement(locale: locale) == "One horizontal bar for all drinks. 349 cups sold in total.")
    }

    @Test("Given the category removed, when the thickness control is asked for, then it is not offered, and it returns with the category")
    func thicknessNeedsACategory() {
        let model = BarMarkViewModel(sales: sales)

        #expect(model.isThicknessAvailable)
        model.removesCategory = true
        #expect(!model.isThicknessAvailable)
        model.removesCategory = false
        #expect(model.isThicknessAvailable)
    }

    @Test("Given a thickness chosen, when the category is removed, then the row reads Not used, and the choice is shown again with the category")
    func thicknessRowSaysWhenItIsNotUsed() {
        let model = BarMarkViewModel(sales: sales)
        model.width = .fixed

        #expect(model.thicknessText == "Fixed")
        model.removesCategory = true
        #expect(model.thicknessText == "Not used")
        #expect(model.width == .fixed)
        model.removesCategory = false
        #expect(model.thicknessText == "Fixed")
    }

    @Test("Given a bar per drink, when the chart descriptor is made, then it has a point per drink in ranked order with units")
    func descriptorDescribesBarsPerDrink() throws {
        let ranked = BarMarkViewModel(sales: sales).sales
        let descriptor = BarMarkChartDescriptor(sales: ranked, removesCategory: false, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Cocoa"])
        #expect(yAxis.title == "Cups")
        // The longest bar is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 3)
    }

    @Test("Given the category removed, when the chart descriptor is made, then it describes the one bar that is drawn: one point, the total")
    func descriptorDescribesOneBar() throws {
        let descriptor = BarMarkChartDescriptor(sales: sales, removesCategory: true, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Cups sold today at the Harbour café, all drinks in one bar")
        #expect(descriptor.summary == "One bar for 3 drinks: 349 cups in total.")
        #expect(xAxis.categoryOrder == ["All drinks"])
        // The one bar is 349 long, on an axis drawn to 400.
        #expect(yAxis.range == 0 ... 400)
        #expect(series.dataPoints.count == 1)
        #expect(!series.isContinuous)
    }
}
