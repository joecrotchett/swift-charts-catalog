import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SymbolModifiersTests {
    private let english = Locale(identifier: "en_US")
    private let days = [
        DailySales(day: CafeData.day(0), cups: 150),
        DailySales(day: CafeData.day(1), cups: 210),
        DailySales(day: CafeData.day(2), cups: 180),
    ]

    // MARK: View model

    @Test("Given a new screen, when it opens, then the points are circles of 100 square points")
    func defaultState() {
        let viewModel = SymbolModifiersViewModel()

        #expect(viewModel.symbol == .circle)
        #expect(viewModel.area == 100)
        #expect(SymbolModifiersViewModel.areaRange.contains(viewModel.area))
    }

    @Test("Given each built-in shape, when its snippets are asked for, then the shape snippet is shown", arguments: [
        SymbolModifiersSymbol.circle, .square, .triangle, .diamond,
    ])
    func shapeSnippets(symbol: SymbolModifiersSymbol) {
        let viewModel = SymbolModifiersViewModel()
        viewModel.symbol = symbol

        #expect(symbol.shape != nil)
        #expect(viewModel.snippets.map(\.name) == ["symbol-modifiers-shape"])
    }

    @Test("Given a view as the symbol, when its snippets are asked for, then the view snippet is shown")
    func viewSnippets() {
        let viewModel = SymbolModifiersViewModel()
        viewModel.symbol = .view

        #expect(SymbolModifiersSymbol.view.shape == nil)
        #expect(viewModel.snippets.map(\.name) == ["symbol-modifiers-view"])
        #expect(viewModel.snippets.map(\.title) == ["symbol { }, sized by the view's frame"])
    }

    @Test("Given the catalog, when the Symbols screen's snippets are listed, then the view snippet has the same title as the view model's")
    func registryTitleMatches() throws {
        let screen = try #require(Catalog.screen(id: "mark-modifiers/symbols"))
        let titles = Dictionary(uniqueKeysWithValues: screen.snippets.map { ($0.name, $0.title) })

        #expect(titles["symbol-modifiers-view"] == SymbolModifiersViewModel.snippets(for: .view).first?.title)
    }

    @Test("Given the built app, when the snippets are read, then neither LineMark gives the day a unit")
    func pointsAreInstants() throws {
        let store = try SnippetStore(bundle: .main)
        for name in ["symbol-modifiers-shape", "symbol-modifiers-view"] {
            let snippet = try #require(store[name])
            #expect(snippet.code.contains("x: .value(CafeWording.day, day.day),"))
            #expect(!snippet.code.contains("unit:"))
        }
    }

    @Test("Given the built app, when every state's snippets are looked up, then each exists in the bundle")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        for symbol in SymbolModifiersSymbol.allCases {
            for reference in SymbolModifiersViewModel.snippets(for: symbol) {
                let snippet = try #require(store[reference.name])
                #expect(snippet.file == "Modifiers/SymbolModifiersScreen.swift")
            }
        }
        #expect(store["symbol-modifiers-shape"]?.code.contains(".symbol(shape)") == true)
        #expect(store["symbol-modifiers-view"]?.code.contains(".symbol {") == true)
    }

    @Test("Given a size, when the slider's text is written, then it is shown in pt² and spoken in square points")
    func sliderText() {
        let viewModel = SymbolModifiersViewModel()
        viewModel.area = 400

        #expect(viewModel.areaText(locale: english) == "400 pt²")
        #expect(viewModel.spokenArea(locale: english) == "400 square points")
        #expect(SymbolModifiersWording.squarePoints(1, locale: english) == "1 square point")
    }

    // MARK: Headline and elements

    @Test("Given days, when the headline is written, then it gives the busiest day and its cups")
    func headlineNamesBusiestDay() {
        let summary = SymbolModifiersSummary(days: days, locale: english)

        #expect(summary.headline == "The busiest day was Monday, March 2, with 210 cups.")
    }

    @Test("Given the sample data, when the headline is written, then its figure is the highest of the days drawn")
    func headlineFollowsSampleData() throws {
        let sample = SymbolModifiersSummary.sampleDays
        let most = try #require(sample.map(\.cups).max())

        #expect(sample.count == 14)
        #expect(sample.first?.day == CafeData.harbourSales.first?.day)
        #expect(SymbolModifiersSummary(days: sample, locale: english).headline.contains("with \(most) cups"))
    }

    @Test("Given two days tied for the most cups, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = days + [DailySales(day: CafeData.day(3), cups: 210)]

        #expect(SymbolModifiersSummary(days: tied, locale: english).headline
            == "The busiest days were Monday, March 2 and Wednesday, March 4, with 210 cups each.")
    }

    @Test("Given no days, when the headline and summary are written, then they say there are no sales")
    func emptyData() {
        let summary = SymbolModifiersSummary(days: [], locale: english)

        #expect(summary.headline == "No sales yet.")
        #expect(summary.audioGraphSummary == "No sales yet.")
    }

    @Test("Given days that sold nothing, when the headline is written, then it says so instead of naming a busiest day")
    func allZero() {
        let zeros = [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]
        let summary = SymbolModifiersSummary(days: zeros, locale: english)

        #expect(summary.headline == "No cups sold in these 2 days.")
        #expect(summary.audioGraphSummary == "2 days. First day 0 cups, last day 0 cups.")
    }

    @Test("Given one day of one cup, when it is described, then counts agree in number")
    func oneAgrees() {
        let summary = SymbolModifiersSummary(days: [DailySales(day: CafeData.day(0), cups: 1)], locale: english)

        #expect(summary.headline == "The busiest day was Sunday, March 1, with 1 cup.")
        #expect(summary.audioGraphSummary == "1 day. First day 1 cup, last day 1 cup. Most: 1 cup, on Sunday, March 1.")
    }

    @Test("Given a day, when its element is written, then it reads the date written out, then the cups")
    func elementText() throws {
        let summary = SymbolModifiersSummary(days: days, locale: english)
        let first = try #require(days.first)

        #expect(summary.elementLabel(for: first) == "Sunday, March 1")
        #expect(summary.elementValue(for: first) == "150 cups")
    }

    @Test("Given a German locale, when the headline is written, then its date and number are written the German way")
    func headlineTakesLocale() {
        let big = [DailySales(day: CafeData.day(0), cups: 1500)]
        let headline = SymbolModifiersSummary(days: big, locale: Locale(identifier: "de_DE")).headline

        #expect(headline.contains("1.500"))
        #expect(headline.contains("Sonntag"))
    }

    // MARK: Chart descriptor

    @Test("Given days, when the descriptor is made, then it has the title, summary, written dates and one connected series")
    func descriptor() throws {
        let descriptor = SymbolModifiersChartDescriptor(days: days, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café")
        #expect(descriptor.summary == "3 days. First day 150 cups, last day 180 cups. Most: 210 cups, on Monday, March 2.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder == ["Sunday, March 1", "Monday, March 2", "Tuesday, March 3"])
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The busiest day is 210; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }

    @Test("Given the sample fortnight, when the busiest day's label is written, then it names March 14, which the axis does not label")
    func calloutNamesTheBusiestDay() throws {
        let summary = SymbolModifiersSummary(days: SymbolModifiersSummary.sampleDays, locale: Locale(identifier: "en_US"))
        let busiest = try #require(summary.busiestDays.first)
        #expect(summary.calloutText(for: busiest) == "Mar 14: 240")
    }
}
