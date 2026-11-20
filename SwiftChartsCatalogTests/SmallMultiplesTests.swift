import Accessibility
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct SmallMultiplesTests {
    let locale = Locale(identifier: "en_US")

    private func row(_ drink: String, _ month: Int, _ cups: Int) -> MonthlyDrinkCups {
        MonthlyDrinkCups(drink: drink, month: CafeData.month(month), cups: cups)
    }

    @Test("Given the sample data, when the scale is shared, then every chart's domain is the app's trend scale, topping at 800")
    func sharedDomainTop() {
        let viewModel = SmallMultiplesViewModel()
        #expect(viewModel.summary.sharedDomain == 0 ... 800)
        #expect(viewModel.summary.sharedDomain == CafeDrinkStyle.trendCupsDomain(for: CafeData.monthlyDrinkTrends))
        for drink in CafeData.trendDrinks {
            #expect(viewModel.domain(for: drink) == 0 ... 800)
        }
    }

    @Test("Given the sample data, when each chart has its own scale, then Latte, Tea and Mocha top at 700, 600 and 500")
    func independentDomains() {
        let viewModel = SmallMultiplesViewModel()
        viewModel.usesIndependentScales = true
        #expect(viewModel.domain(for: "Latte") == 0 ... 700)
        #expect(viewModel.domain(for: "Tea") == 0 ... 600)
        #expect(viewModel.domain(for: "Mocha") == 0 ... 500)
    }

    @Test("Given a largest value on a step, when rounded, then it stays; given none, then one step")
    func roundedTop() {
        #expect(SmallMultiplesSummary.roundedTop(600) == 600)
        #expect(SmallMultiplesSummary.roundedTop(601) == 700)
        #expect(SmallMultiplesSummary.roundedTop(0) == 100)
    }

    @Test("Given the shared scale, when the headline is read, then it names the scale's top and what each chart shows at a glance")
    func sharedHeadline() {
        let viewModel = SmallMultiplesViewModel()
        #expect(viewModel.headline(locale: locale)
            == "On one scale of 0 to 800 cups, heights compare across drinks: Latte changes little all year, "
            + "Tea is busiest from June to August, and Mocha is busiest from November to January.")
    }

    @Test("Given the sample data, when each drink's shape is worked out, then Latte is level and the others have a busiest season")
    func shapes() {
        let summary = SmallMultiplesViewModel().summary
        #expect(summary.shape(of: "Latte") == .level)
        #expect(summary.shape(of: "Tea") == .busiest(first: CafeData.month(3), last: CafeData.month(5)))
        #expect(summary.shape(of: "Mocha") == .busiest(first: CafeData.month(8), last: CafeData.month(10)))
        #expect(summary.shape(of: "Cocoa") == .none)
    }

    @Test("Given independent scales, when the mistake note is read, then it points to Tea's July standing taller than Latte's December")
    func mistakeNote() {
        let viewModel = SmallMultiplesViewModel()
        viewModel.usesIndependentScales = true
        #expect(viewModel.summary.inversion(locale: locale)
            == "Tea's July (588 of 600) now stands taller than Latte's December (611 of 700), though Latte sold more.")
        #expect(viewModel.mistakeNote(locale: locale).hasSuffix(viewModel.summary.inversion(locale: locale) ?? "missing"))
    }

    @Test("Given independent scales that tell no lie, when the mistake note is read, then it names no inversion")
    func noInversion() {
        let viewModel = SmallMultiplesViewModel(trends: [row("Latte", 0, 450), row("Tea", 0, 420)], drinks: ["Latte", "Tea"])
        viewModel.usesIndependentScales = true
        #expect(viewModel.summary.inversion(locale: locale) == nil)
        #expect(viewModel.mistakeNote(locale: locale)
            == "Read the top label of each chart: each now ends at its own number, so equal heights no longer mean equal cups.")
    }

    @Test("Given independent scales, when the headline is read, then it names each chart's top")
    func independentHeadline() {
        let viewModel = SmallMultiplesViewModel()
        viewModel.usesIndependentScales = true
        #expect(viewModel.headline(locale: locale)
            == "Each chart has its own scale, Latte to 700, Tea to 600, and Mocha to 500 cups: equal heights no longer mean equal sales.")
    }

    @Test("Given independent scales that happen to share a top, when the headline is read, then it says heights still compare")
    func independentHeadlineEqualTops() {
        let viewModel = SmallMultiplesViewModel(trends: [row("Latte", 0, 450), row("Tea", 0, 420)], drinks: ["Latte", "Tea"])
        viewModel.usesIndependentScales = true
        #expect(viewModel.headline(locale: locale)
            == "Each chart has its own scale, but all reach 500 cups, so here the heights still compare.")
    }

    @Test("Given one month per drink, when the headline is read, then each drink is busiest in its month")
    func oneMonthHeadline() {
        let viewModel = SmallMultiplesViewModel(trends: [row("Latte", 0, 300), row("Tea", 4, 300)], drinks: ["Latte", "Tea"])
        #expect(viewModel.headline(locale: locale)
            == "On one scale of 0 to 400 cups, heights compare across drinks: Latte is busiest in March and Tea is busiest in July.")
    }

    @Test("Given no data or only zeros, when the screen is drawn, then it shows the placeholder and a true headline")
    func emptyAndZero() {
        for trends in [[], [row("Latte", 0, 0)]] {
            let viewModel = SmallMultiplesViewModel(trends: trends, drinks: ["Latte"])
            #expect(viewModel.hasNothingToDraw)
            #expect(viewModel.headline(locale: locale) == "No cups sold in these months.")
        }
    }

    @Test("Given the toggle, when it changes, then the announcement says what changed and then the headline")
    func announcement() {
        let viewModel = SmallMultiplesViewModel()
        viewModel.usesIndependentScales = true
        #expect(viewModel.announcement(locale: locale)
            == "Each chart now has its own scale. \(viewModel.headline(locale: locale))")
        viewModel.usesIndependentScales = false
        #expect(viewModel.announcement(locale: locale)
            == "All three charts now share one scale. \(viewModel.headline(locale: locale))")
    }

    @Test("Given each setting, when See Code opens, then it shows the matching domain snippet, and all exist")
    func snippets() throws {
        let store = try SnippetStore()
        let viewModel = SmallMultiplesViewModel()
        #expect(viewModel.snippets.map(\.name)
            == ["small-multiples-stack", "small-multiples-chart", "small-multiples-shared-domain", "small-multiples-crowded"])
        viewModel.usesIndependentScales = true
        #expect(viewModel.snippets.map(\.name)
            == ["small-multiples-stack", "small-multiples-chart", "small-multiples-independent-domain", "small-multiples-crowded"])
        for name in ["small-multiples-shared-domain"] + viewModel.snippets.map(\.name) {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    @Test("Given the crowded chart, when a month's value is read, then every drink is named with its cups")
    func crowdedValue() {
        let summary = SmallMultiplesViewModel().summary
        #expect(summary.crowdedValue(for: CafeData.month(0), locale: locale)
            == "Latte 512 cups, Tea 298 cups, and Mocha 244 cups")
    }

    @Test("Given one drink's chart, when its descriptor is made, then it carries the drink, the months and the drawn range")
    func drinkDescriptor() throws {
        let viewModel = SmallMultiplesViewModel()
        viewModel.usesIndependentScales = true
        let descriptor = SmallMultiplesDrinkDescriptor(
            drink: "Mocha", summary: viewModel.summary, domain: viewModel.domain(for: "Mocha"),
            usesIndependentScales: true, locale: locale
        ).makeChartDescriptor()
        #expect(descriptor.title == "Mocha, cups per month")
        #expect(descriptor.summary == "12 months. Highest 472 cups in December 2026, lowest 102 cups in July 2026. "
            + "Its own scale, 0 to 500 cups; the other charts' scales differ.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "March 2026")
        #expect(xAxis.categoryOrder.last == "February 2027")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 500)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(472) == "472 cups")
        #expect(descriptor.series.map(\.name) == ["Mocha"])
        #expect(descriptor.series.first?.dataPoints.count == 12)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given the crowded chart, when its descriptor is made, then it has one series per drink on the shared range")
    func crowdedDescriptor() throws {
        let descriptor = SmallMultiplesCrowdedDescriptor(summary: SmallMultiplesViewModel().summary, locale: locale)
            .makeChartDescriptor()
        #expect(descriptor.series.map(\.name) == ["Latte", "Tea", "Mocha"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 12 })
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 800)
        #expect(descriptor.summary
            == "3 drinks, 12 months, one scale of 0 to 800 cups. Highest: Latte in December 2026, 611 cups.")
    }
}
