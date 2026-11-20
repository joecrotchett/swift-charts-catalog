import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ColourSeparationTests {
    private let locale = Locale(identifier: "en_US")

    // MARK: The view model

    @Test("Given a new screen, when it appears, then the segments are separated by a 3-point gap")
    func startsSeparated() {
        let viewModel = ColourSeparationViewModel()

        #expect(!viewModel.isTouching)
        #expect(viewModel.gapEachSide == 1.5)
        #expect(viewModel.gapBetweenSegments == 3)
    }

    @Test("Given separated segments, when they are let touch, then there is no gap")
    func touchingHasNoGap() {
        let viewModel = ColourSeparationViewModel()

        viewModel.isTouching = true

        #expect(viewModel.gapEachSide == 0)
        #expect(viewModel.gapBetweenSegments == 0)
    }

    @Test("Given the sample drinks, when they are drawn, then they run largest first")
    func largestFirst() {
        let viewModel = ColourSeparationViewModel()

        #expect(viewModel.drinkNames == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
    }

    @Test("Given a drink with no cups, when the charts are drawn, then it has no segment")
    func zeroLeftOut() {
        let viewModel = ColourSeparationViewModel(sales: [
            DrinkSales(drink: "Tea", cups: 10), DrinkSales(drink: "Cocoa", cups: 0),
        ])

        #expect(viewModel.drinkNames == ["Tea"])
    }

    @Test("Given a tie, when the drinks are ordered, then the tied drinks keep the data's order")
    func tieKeepsOrder() {
        let viewModel = ColourSeparationViewModel(sales: [
            DrinkSales(drink: "Mocha", cups: 5), DrinkSales(drink: "Tea", cups: 9), DrinkSales(drink: "Latte", cups: 9),
        ])

        #expect(viewModel.drinkNames == ["Tea", "Latte", "Mocha"])
    }

    @Test("Given either state, when the snippets are listed, then the gap, bar and donut snippets are shown")
    func snippetNames() {
        let viewModel = ColourSeparationViewModel()
        let names = ["colour-separation-gap", "colour-separation-bar", "colour-separation-donut"]

        #expect(viewModel.snippets.map(\.name) == names)
        viewModel.isTouching = true
        #expect(viewModel.snippets.map(\.name) == names)
    }

    @Test("Given the app's bundle, when its snippets are loaded, then every snippet the screen names exists")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for reference in ColourSeparationViewModel().snippets {
            #expect(store[reference.name] != nil, "missing \(reference.name)")
        }
    }

    @Test("Given each state, when the chart identity is read, then it differs")
    func identityFollowsState() {
        let viewModel = ColourSeparationViewModel()
        let separated = viewModel.chartIdentity

        viewModel.isTouching = true

        #expect(viewModel.chartIdentity != separated)
    }

    // MARK: Words

    @Test("Given the sample drinks, when the headline is written, then it names Tea and the 164 cups in the hole")
    func headline() {
        let viewModel = ColourSeparationViewModel()

        #expect(viewModel.headline(locale: locale) == "Tea sold the most today: 164 cups.")
        viewModel.isTouching = true
        #expect(viewModel.headline(locale: locale) == "Tea sold the most today: 164 cups.")
    }

    @Test("Given a tie for the most, when the headline is written, then it names both and says each")
    func headlineTie() {
        let viewModel = ColourSeparationViewModel(sales: [
            DrinkSales(drink: "Tea", cups: 9), DrinkSales(drink: "Latte", cups: 9), DrinkSales(drink: "Mocha", cups: 1),
        ])

        #expect(viewModel.headline(locale: locale) == "Tea and Latte sold the most today: 9 cups each.")
    }

    @Test("Given no sales, or only zeros, when the screen is drawn, then there is no chart and the headline says so")
    func emptyAndZeros() {
        for sales in [[], [DrinkSales(drink: "Tea", cups: 0)]] {
            let viewModel = ColourSeparationViewModel(sales: sales)

            #expect(!viewModel.hasChart)
            #expect(viewModel.headline(locale: locale) == "No cups sold yet today.")
        }
    }

    @Test("Given one cup, when it is written, then the count agrees in number")
    func oneCup() {
        let viewModel = ColourSeparationViewModel(sales: [DrinkSales(drink: "Tea", cups: 1)])

        #expect(viewModel.headline(locale: locale) == "Tea sold the most today: 1 cup.")
    }

    @Test("Given Tea, when its element value is written, then it gives cups and its share of the total")
    func elementValue() {
        let summary = ColourSeparationViewModel().summary(locale: locale)

        #expect(summary.elementValue(for: DrinkSales(drink: "Tea", cups: 164)) == "164 cups, 30% of all cups")
    }

    @Test("Given a German locale, when a large count is written, then it groups thousands the German way")
    func germanLocale() {
        let viewModel = ColourSeparationViewModel(sales: [DrinkSales(drink: "Tea", cups: 1234)])

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")) == "Tea sold the most today: 1.234 cups.")
    }

    @Test("Given each state, when the explanation is written, then it gives the 1.5-point inset and 3-point gap")
    func explanation() {
        let text = ColourSeparationViewModel().explanation(locale: locale)

        #expect(text.contains("inset by 1.5 points"))
        #expect(text.contains("a gap of 3 points between neighbours"))
    }

    // MARK: The Audio Graph

    @Test("Given separated segments, when the descriptor is made, then its summary gives values and the gap")
    func descriptorSeparated() throws {
        let viewModel = ColourSeparationViewModel()
        let descriptor = ColourSeparationDescriptor(form: .donut, summary: viewModel.summary(locale: locale))
            .makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today by drink, as a donut")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups. "
            + "Neighbouring segments are separated by a gap of 3 points.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        let yAxis = try #require(descriptor.yAxis)
        // Each sector is a share of the total, so the range runs to it.
        #expect(yAxis.range == 0 ... 551)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == 5)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given touching segments, when the bar's descriptor is made, then its summary says they touch")
    func descriptorTouching() {
        let viewModel = ColourSeparationViewModel()
        viewModel.isTouching = true
        let descriptor = ColourSeparationDescriptor(form: .bar, summary: viewModel.summary(locale: locale))
            .makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today by drink, as one stacked bar")
        #expect(descriptor.summary?.hasSuffix("Neighbouring segments touch, with no gap between them.") == true)
    }

    @Test("Given the single bar, when its descriptor is made, then its range is the bar's drawn scale, zero to the total")
    func barDescriptorRange() throws {
        let viewModel = ColourSeparationViewModel()
        let descriptor = ColourSeparationDescriptor(form: .bar, summary: viewModel.summary(locale: locale))
            .makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 551)
    }

    @Test("Given the explanation, when it is read, then it says what the narrow segments give up")
    func explanationNamesUnlabelledSegments() {
        let text = ColourSeparationViewModel().explanation(locale: locale)
        #expect(text.contains("a narrower one is left unnamed"))
    }
}
