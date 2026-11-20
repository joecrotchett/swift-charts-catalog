import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct SimplerChartTests {
    let english = Locale(identifier: "en_US")

    let zeros: [DrinkOrder] = [
        DrinkOrder(drink: "Latte", size: "Small", cups: 0), DrinkOrder(drink: "Latte", size: "Large", cups: 0),
        DrinkOrder(drink: "Tea", size: "Small", cups: 0), DrinkOrder(drink: "Tea", size: "Large", cups: 0),
    ]

    func speech(_ orders: [DrinkOrder] = CafeData.drinkOrders) -> SimplerChartSpeech {
        SimplerChartSpeech(orders: orders, locale: english)
    }

    // MARK: Totals and detail

    @Test("Given the day's orders, when totals are made, then each drink has its total and its sizes in words, in data order")
    func totalsNormal() {
        let totals = speech().totals
        #expect(totals.map(\.drink) == ["Latte", "Tea", "Mocha"])
        #expect(totals.map(\.cups) == [128, 164, 92])
        #expect(totals.map(\.detail) == [
            "Small 34, Medium 58, and Large 36",
            "Small 71, Medium 62, and Large 31",
            "Small 22, Medium 41, and Large 29",
        ])
    }

    @Test("Given no orders, when totals are made, then there are none and the chart is empty")
    func totalsEmpty() {
        let speech = speech([])
        #expect(speech.totals.isEmpty)
        #expect(speech.isEmpty)
        #expect(speech.representationElements.isEmpty)
    }

    @Test("Given only zeros, when totals are made, then each drink totals zero with its sizes at zero, and the chart is empty")
    func totalsZeros() {
        let speech = speech(zeros)
        #expect(speech.totals.map(\.cups) == [0, 0])
        #expect(speech.totals.map(\.detail) == ["Small 0 and Large 0", "Small 0 and Large 0"])
        #expect(speech.isEmpty)
    }

    @Test("Given a German locale, when the detail is written, then numbers take the locale and the list stays English")
    func detailLocale() {
        let orders = [DrinkOrder(drink: "Latte", size: "Small", cups: 1234), DrinkOrder(drink: "Latte", size: "Large", cups: 1)]
        let speech = SimplerChartSpeech(orders: orders, locale: Locale(identifier: "de_DE"))
        #expect(speech.totals.first?.detail == "Small 1.234 and Large 1")
    }

    // MARK: Headline

    @Test("Given the day's orders, when the headline is written, then it names the tallest stack and its height")
    func headlineNormal() {
        #expect(speech().headline == "Tea sold the most: 164 cups across every size.")
    }

    @Test("Given no orders or only zeros, when the headline is written, then it says nothing sold")
    func headlineEmptyAndZeros() {
        #expect(speech([]).headline == "No cups sold yet today.")
        #expect(speech(zeros).headline == "No cups sold yet today.")
    }

    @Test("Given a tie, when the headline is written, then both drinks are named")
    func headlineTie() {
        let orders = [DrinkOrder(drink: "Latte", size: "Small", cups: 1), DrinkOrder(drink: "Tea", size: "Small", cups: 1)]
        #expect(speech(orders).headline == "Latte and Tea sold the most: 1 cup across every size.")
    }

    // MARK: Elements

    @Test("Given the representation, when its elements are predicted, then each drink reads its total then its sizes")
    func representationElements() {
        #expect(speech().representationElements.map(\.spoken) == [
            "Latte, 128 cups: Small 34, Medium 58, and Large 36",
            "Tea, 164 cups: Small 71, Medium 62, and Large 31",
            "Mocha, 92 cups: Small 22, Medium 41, and Large 29",
        ])
    }

    @Test("Given no representation, when the elements are predicted, then each stack reads as the framework's total")
    func defaultElements() {
        #expect(speech().defaultElements.map(\.spoken) == [
            "Latte, total 128, 3 Sizes", "Tea, total 164, 3 Sizes", "Mocha, total 92, 3 Sizes",
        ])
    }

    @Test("Given only zeros, when the representation's elements are predicted, then each reads 0 cups and its sizes at zero")
    func zeroElements() {
        #expect(speech(zeros).representationElements.map(\.spoken) == [
            "Latte, 0 cups: Small 0 and Large 0", "Tea, 0 cups: Small 0 and Large 0",
        ])
    }

    // MARK: View model states

    @MainActor
    @Test("Given the screen opens, when nothing is touched, then the representation is on and its elements and Audio Graph are shown")
    func initialState() {
        let viewModel = SimplerChartViewModel()
        #expect(viewModel.usesRepresentation)
        #expect(viewModel.elements(locale: english).count == 3)
        #expect(viewModel.audioGraph(locale: english).title == SimplerChartSpeech.representationTitle)
        #expect(viewModel.audioGraph(locale: english).series == ["All sizes: Latte 128 cups, Tea 164 cups, Mocha 92 cups"])
    }

    @MainActor
    @Test("Given the representation is turned off, when the Audio Graph is predicted, then it has one series per size")
    func stackedState() {
        let viewModel = SimplerChartViewModel()
        viewModel.usesRepresentation = false
        let audioGraph = viewModel.audioGraph(locale: english)
        #expect(audioGraph.title == SimplerChartSpeech.stackedTitle)
        #expect(audioGraph.series == [
            "Small: Latte 34 cups, Tea 71 cups, Mocha 22 cups",
            "Medium: Latte 58 cups, Tea 62 cups, Mocha 41 cups",
            "Large: Latte 36 cups, Tea 31 cups, Mocha 29 cups",
        ])
        #expect(viewModel.elements(locale: english).first?.spoken == "Latte, total 128, 3 Sizes")
    }

    @MainActor
    @Test("Given each state, when the snippets are listed, then they are the ones for that state and all exist")
    func snippetsPerState() throws {
        let store = try SnippetStore()
        let viewModel = SimplerChartViewModel()
        #expect(viewModel.snippets.map(\.name) == [
            "simpler-chart-representation", "simpler-chart-totals", "simpler-chart-totals-descriptor",
        ])
        viewModel.usesRepresentation = false
        #expect(viewModel.snippets.map(\.name) == ["simpler-chart-stacked", "simpler-chart-stacked-descriptor"])
        for snippet in SimplerChartViewModel.allSnippets {
            #expect(store[snippet.name] != nil, "missing \(snippet.name)")
        }
    }

    @Test("Given each state, when the toggle changes, then the announcement says what changed and then the headline")
    func announcement() {
        #expect(speech().announcement(usesRepresentation: true)
            == "VoiceOver now gets one bar per drink, with its sizes in words. Tea sold the most: 164 cups across every size.")
        #expect(speech().announcement(usesRepresentation: false)
            == "VoiceOver now gets the stacked chart as drawn. Tea sold the most: 164 cups across every size.")
    }

    // MARK: Descriptors

    @Test("Given the day's orders, when the totals descriptor is made, then it has one named series of separate totals over the drinks")
    func totalsDescriptor() throws {
        let descriptor = SimplerChartTotalsDescriptor(speech: speech()).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold today by drink, every size together")
        #expect(descriptor.summary == "3 drinks in 3 sizes, 384 cups in total. Most: Tea, 164 cups. Fewest: Mocha, 92 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        let series = try #require(descriptor.series.first)
        #expect(descriptor.series.count == 1)
        #expect(series.name == "All sizes")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 3)
    }

    @Test("Given the day's orders, when the stacked descriptor is made, then it has a separate series per size")
    func stackedDescriptor() throws {
        let descriptor = SimplerChartStackedDescriptor(speech: speech()).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold today by drink and size")
        #expect(descriptor.series.map(\.name) == ["Small", "Medium", "Large"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 3 })
        #expect(try #require(descriptor.yAxis).range == 0 ... 200)
    }

    @Test("Given no orders or only zeros, when the summary is written, then it says nothing sold")
    func summaryEmptyAndZeros() {
        #expect(speech([]).audioGraphSummary == "No cups sold yet today.")
        #expect(speech(zeros).audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given the totals, when the value axis is sized, then it is the largest total rounded up to the next 50")
    func valueAxisTop() {
        #expect(speech().valueAxisTop == 200)
        #expect(speech([]).valueAxisTop == 50)
        #expect(speech(zeros).valueAxisTop == 50)
    }
}
