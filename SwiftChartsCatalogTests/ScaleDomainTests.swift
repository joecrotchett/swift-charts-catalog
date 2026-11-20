import Accessibility
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ScaleDomainTests {
    private let locale = Locale(identifier: "en_US")

    private func summary(_ option: ScaleDomainOption, sales: [DrinkSales] = CafeData.drinkSales) -> ScaleDomainSummary {
        ScaleDomainSummary(sales: sales, option: option, locale: locale)
    }

    @Test("Given a new screen, when nothing has been changed, then the domain is automatic and the chart and its domain are shown as code")
    func startsAutomatic() {
        let model = ScaleDomainViewModel()

        #expect(model.option == .automatic)
        #expect(model.snippets.map(\.name) == ["scale-domain-chart", "scale-domain-automatic"])
    }

    @Test(
        "Given each option, when it is chosen, then the code shows the chart and that option's domain",
        arguments: zip(ScaleDomainOption.allCases, [
            "scale-domain-automatic", "scale-domain-exact", "scale-domain-without-zero",
            "scale-domain-reversed", "scale-domain-closure", "scale-domain-array",
        ])
    )
    func snippetsFollowTheOption(option: ScaleDomainOption, name: String) {
        let model = ScaleDomainViewModel(option: option)

        #expect(model.snippets.map(\.name) == ["scale-domain-chart", name])
    }

    @Test("Given the app's snippets, when every option's names are looked up, then each region exists")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        let names = [ScaleDomainViewModel.chartSnippet.name] + ScaleDomainOption.allCases.map(\.snippet.name)

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given the options, when one is the zero-free domain, then it alone is marked as the mistake")
    func onlyWithoutZeroIsTheMistake() {
        #expect(ScaleDomainOption.allCases.filter(\.isMistake) == [.withoutZero])
    }

    @Test("Given today's sales, when each option draws them, then the headline is true of that chart")
    func headlines() {
        #expect(summary(.automatic).headline == "Tea sold the most: 164 cups.")
        #expect(summary(.exact).headline == "Tea sold the most, 164 cups, on a fixed scale, not one fitted to the data.")
        #expect(summary(.withoutZero).headline
            == "Tea sold 2.9 times as many cups as Cocoa, 164 to 57, but without zero the bars make the gap look far larger.")
        #expect(summary(.reversed).headline
            == "With the cups axis reversed, the bars grow from the other side. Tea sold the most: 164 cups.")
        #expect(summary(.closure).headline
            == "Sorted by name in a closure, from Americano to Tea. Tea sold the most: 164 cups.")
        #expect(summary(.array).headline == "Ranked by a domain array: Tea at the top, with 164 cups.")
    }

    @Test("Given no sales or only zeros, when any option is chosen, then the headline says nothing has sold", arguments: ScaleDomainOption.allCases)
    func headlineWithNoSales(option: ScaleDomainOption) {
        #expect(summary(option, sales: []).headline == "No cups sold yet today.")
        #expect(summary(option, sales: [DrinkSales(drink: "Tea", cups: 0)]).headline == "No cups sold yet today.")
        #expect(summary(option, sales: []).audioGraphSummary == "No cups sold yet today.")
    }

    @Test("Given two drinks tied for most, when the headline is written, then it names both")
    func headlineNamesATie() {
        let tied = [DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Cocoa", cups: 30)]

        #expect(summary(.automatic, sales: tied).headline == "Tea and Mocha sold the most: 90 cups.")
        #expect(summary(.withoutZero, sales: tied).headline.hasPrefix("Tea and Mocha sold 3.0 times as many cups as Cocoa, 90 to 30"))
    }

    @Test("Given a drink that sold none, when the zero-free domain is chosen, then the headline names no bar that is not drawn")
    func withoutZeroAndANoneDrink() {
        let sales = [DrinkSales(drink: "Tea", cups: 120), DrinkSales(drink: "Cocoa", cups: 0)]

        #expect(summary(.withoutZero, sales: sales).headline
            == "Without zero, the bars no longer measure cups: Tea sold 120 cups.")
    }

    @Test("Given sales past the exact domain, when the exact option is chosen, then the headline says the bar runs past the scale")
    func exactWithSalesPastTheScale() {
        let sales = [DrinkSales(drink: "Tea", cups: 320), DrinkSales(drink: "Cocoa", cups: 40)]

        #expect(summary(.exact, sales: sales).headline
            == "Tea sold 320 cups, past the end of the fixed scale.")
    }

    @Test("Given one cup, when counts are written, then they agree in number")
    func countsAgree() {
        let one = [DrinkSales(drink: "Tea", cups: 1)]

        #expect(summary(.automatic, sales: one).headline == "Tea sold the most: 1 cup.")
        #expect(summary(.automatic, sales: one).audioGraphSummary
            == "The cups axis starts at zero. 1 drink, 1 cup in total. Most: Tea, 1 cup. Fewest: Tea, 1 cup.")
    }

    @Test("Given a German locale, when the headline is written, then numbers follow the locale")
    func headlineTakesTheLocale() {
        let sales = [DrinkSales(drink: "Tea", cups: 1640), DrinkSales(drink: "Cocoa", cups: 570)]
        let german = ScaleDomainSummary(sales: sales, option: .withoutZero, locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("2,9 times"))
        #expect(german.headline.contains("1.640 to 570"))
    }

    @Test("Given a change of option, when it is announced, then it says what changed and then the headline")
    func announcement() {
        #expect(summary(.exact).announcement
            == "Exact domain, 0 to 300 cups. Tea sold the most, 164 cups, on a fixed scale, not one fitted to the data.")
        #expect(summary(.array).announcement.hasPrefix("Drinks ordered by a domain array. Ranked"))
    }

    @Test("Given the domain that leaves zero out, when it is announced, then it says it is an exact domain and gives its ends in the locale")
    func zeroFreeAnnouncement() {
        #expect(summary(.withoutZero).announcement.hasPrefix("Exact domain leaving zero out, 50 to 170 cups. "))

        let sales = CafeData.drinkSales.map { DrinkSales(drink: $0.drink, cups: $0.cups * 10) }
        let german = ScaleDomainSummary(sales: sales, option: .withoutZero, locale: Locale(identifier: "de_DE"))
        #expect(german.announcement.hasPrefix("Exact domain leaving zero out, 570 to 1.640 cups. "))
    }

    @Test("Given the zero-free domain, when a bar is read, then its value says the bar does not start at zero")
    func elementValues() {
        let tea = DrinkSales(drink: "Tea", cups: 164)

        #expect(summary(.automatic).elementValue(for: tea) == "164 cups")
        #expect(summary(.withoutZero).elementValue(for: tea) == "164 cups; the bar does not start at zero")
    }

    @Test("Given each option, when the rows are ordered, then the order is the data's, by name, or by rank")
    func drawnOrder() {
        #expect(summary(.automatic).drawnOrder == ["Latte", "Tea", "Mocha", "Cocoa", "Americano"])
        #expect(summary(.closure).drawnOrder == ["Americano", "Cocoa", "Latte", "Mocha", "Tea"])
        #expect(summary(.array).drawnOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
    }

    @Test("Given today's sales, when the zero-free domain is worked out, then it rounds the data out to tens and leaves zero out")
    func zeroFreeDomain() {
        #expect(summary(.withoutZero).zeroFreeDomain == 50 ... 170)
        #expect(summary(.withoutZero, sales: [DrinkSales(drink: "Tea", cups: 40), DrinkSales(drink: "Cocoa", cups: 0)]).zeroFreeDomain == 40 ... 50)
    }

    @Test("Given each option, when the descriptor is made, then it has the drawn order, the drawn range and real words")
    func descriptor() throws {
        let exact = ScaleDomainChartDescriptor(summary: summary(.exact)).makeChartDescriptor()
        let exactAxis = try #require(exact.yAxis)

        #expect(exact.title == "Cups sold today at the Harbour café, by drink")
        #expect(exactAxis.range == 0 ... 300)
        #expect(exactAxis.title == CafeWording.cupsAxisTitle)
        #expect(exactAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(exact.series.first?.name == CafeWording.harbour)
        #expect(exact.series.first?.isContinuous == false)
        #expect(exact.series.first?.dataPoints.count == 5)
        #expect(exact.summary == "The cups axis is fixed at 0 to 300 cups. 5 drinks, 551 cups in total. "
            + "Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")

        let withoutZero = ScaleDomainChartDescriptor(summary: summary(.withoutZero)).makeChartDescriptor()
        #expect(try #require(withoutZero.yAxis).range == 50 ... 170)
        #expect(withoutZero.summary?.hasPrefix("The cups axis does not start at zero, so the bars are cut short.") == true)

        let ranked = ScaleDomainChartDescriptor(summary: summary(.array)).makeChartDescriptor()
        let categories = try #require(ranked.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(categories.categoryOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        // The automatic axis rounds the longest bar, 164, up to 200; the descriptor says the same.
        #expect(try #require(ranked.yAxis).range == 0 ... 200)
    }
}
