import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SectorMarkTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    /// A model with all three settings at zero: the bare mark.
    private func plainPie(sales: [DrinkSales] = CafeData.drinkSales) -> SectorMarkViewModel {
        let model = SectorMarkViewModel(sales: sales)
        model.angularInset = 0
        model.cornerRadius = 0
        return model
    }

    @Test("Given a new screen, when nothing has been moved, then the chart is a pie with a small gap and small rounding, not none")
    func startsWithSmallGaps() {
        let model = SectorMarkViewModel()

        #expect(model.innerRadiusRatio == 0)
        #expect(model.angularInset == 1.5)
        #expect(model.cornerRadius == 2)
        #expect(!model.isPlainPie)
        #expect(model.snippets.map(\.name) == ["sector-order", "sector-shaped"])
        #expect(model.shapeAnnouncement(locale: english) == "Pie: 3 point gaps, corners 2 points.")
    }

    @Test("Given a plain pie, when any one of the three settings is raised, then it is no longer a plain pie")
    func anySettingLeavesPlainPie() {
        let hole = plainPie()
        hole.innerRadiusRatio = 0.6
        let gap = plainPie()
        gap.angularInset = 1.5
        let rounded = plainPie()
        rounded.cornerRadius = 4

        #expect(!hole.isPlainPie)
        #expect(!gap.isPlainPie)
        #expect(!rounded.isPlainPie)
    }

    @Test("Given a plain pie, when the snippets are listed, then they are the data order and the bare mark")
    func plainPieSnippets() {
        #expect(plainPie().snippets.map(\.name) == ["sector-order", "sector-pie"])
    }

    @Test("Given a setting above zero, when the snippets are listed, then they are the data order and the shaped mark")
    func shapedSnippets() {
        let model = plainPie()
        model.angularInset = 1

        #expect(model.snippets.map(\.name) == ["sector-order", "sector-shaped"])
    }

    @Test("Given the built app, when each state's snippets are looked up, then every one exists and shows its concept")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let shaped = SectorMarkViewModel()
        shaped.innerRadiusRatio = 0.6

        for reference in plainPie().snippets + shaped.snippets {
            #expect(store[reference.name] != nil, "\(reference.name) is missing")
        }
        let pie = try #require(store["sector-pie"])
        #expect(pie.code.contains("SectorMark(angle:"))
        #expect(!pie.code.contains("innerRadius"))
        let shapedCode = try #require(store["sector-shaped"]).code
        #expect(shapedCode.contains("innerRadius: .ratio("))
        #expect(shapedCode.contains("angularInset:"))
        #expect(shapedCode.contains(".cornerRadius("))
    }

    @Test("Given the sliders' values, when they are written beside the sliders, then each carries its unit")
    func sliderTexts() {
        let model = SectorMarkViewModel()
        model.innerRadiusRatio = 0.6
        model.angularInset = 1.5
        model.cornerRadius = 4

        #expect(model.innerRadiusText == "60%")
        #expect(model.angularInsetText == "1.5 pt")
        #expect(model.cornerRadiusText == "4 pt")
    }

    @Test("Given the sliders' values, when they are spoken, then units are written out and agree in number")
    func sliderSpokenTexts() {
        let model = plainPie()

        #expect(model.innerRadiusSpokenText == "No hole, a pie")
        #expect(model.angularInsetSpokenText(locale: english) == "0 points")

        model.innerRadiusRatio = 0.6
        model.angularInset = 1
        model.cornerRadius = 1.5

        #expect(model.innerRadiusSpokenText == "60% of the outer radius")
        #expect(model.angularInsetSpokenText(locale: english) == "1 point")
        #expect(model.cornerRadiusSpokenText(locale: english) == "1.5 points")
    }

    @Test("Given drink sales in any order, when the sectors are made, then the largest comes first")
    func slicesLargestFirst() {
        #expect(SectorSalesSummary(sales: sales, locale: english).slices.map(\.drink) == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given a drink with no cups, when the sectors are made, then it has no sector and ties keep their order")
    func zeroHasNoSector() {
        let summary = SectorSalesSummary(sales: [
            DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Cocoa", cups: 0), DrinkSales(drink: "Tea", cups: 90),
        ], locale: english)

        #expect(summary.slices.map(\.drink) == ["Mocha", "Tea"])
    }

    @Test("Given the café's sample data, when the headline is written, then it gives the largest drink and its cups")
    func headlineFollowsSampleData() {
        let summary = SectorSalesSummary(sales: CafeData.drinkSales, locale: english)

        #expect(summary.slices.count == 5)
        #expect(summary.total == 551)
        #expect(summary.headline == "Tea is the largest share: 164 cups.")
    }

    @Test("Given any slider setting, when the headline is read, then it is the same true sentence")
    func headlineHoldsForEverySetting() {
        let model = SectorMarkViewModel()
        let before = model.summary(locale: english).headline
        model.innerRadiusRatio = 0.7
        model.angularInset = 4
        model.cornerRadius = 12

        #expect(model.summary(locale: english).headline == before)
    }

    @Test("Given two drinks tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        let summary = SectorSalesSummary(sales: [
            DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Cocoa", cups: 40),
        ], locale: english)

        #expect(summary.headline == "Mocha and Tea share the largest part: 90 cups each.")
    }

    @Test("Given one drink sold, when the headline is written, then it does not call it the largest of several")
    func oneDrink() {
        let summary = SectorSalesSummary(sales: [DrinkSales(drink: "Tea", cups: 1), DrinkSales(drink: "Latte", cups: 0)], locale: english)

        #expect(summary.headline == "Tea is the only drink sold: 1 cup.")
    }

    @Test("Given no rows or only zeros, when the chart's words are written, then they say nothing sold")
    func emptyAndAllZeroSaySo() {
        for rows in [[], [DrinkSales(drink: "Latte", cups: 0), DrinkSales(drink: "Tea", cups: 0)]] {
            let summary = SectorSalesSummary(sales: rows, locale: english)

            #expect(summary.slices.isEmpty)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
        }
    }

    @Test("Given a sector, when its value is spoken, then it gives the cups with their unit and the share")
    func spokenValue() {
        let summary = SectorSalesSummary(sales: CafeData.drinkSales, locale: english)
        let tea = DrinkSales(drink: "Tea", cups: 164)

        #expect(summary.shareText(of: tea) == "30%")
        #expect(summary.spokenValue(of: tea) == "164 cups, 30% of the total")
    }

    @Test("Given drink sales, when the Audio Graph summary is written, then it gives the count, total, largest and smallest")
    func summaryGivesActualValues() {
        #expect(
            SectorSalesSummary(sales: CafeData.drinkSales, locale: english).audioGraphSummary
                == "5 drinks, 551 cups in total. Largest share: Tea, 164 cups, 30%. Smallest share: Cocoa, 57 cups, 10%."
        )
    }

    @Test("Given one drink sold, when the Audio Graph summary is written, then it agrees in number and names no largest or smallest")
    func oneDrinkSummary() {
        let summary = SectorSalesSummary(sales: [DrinkSales(drink: "Tea", cups: 12), DrinkSales(drink: "Latte", cups: 0)], locale: english)

        #expect(summary.audioGraphSummary == "1 drink, Tea: 12 cups, 100% of the total.")
    }

    @Test("Given a German locale, when the chart's words are written, then numbers are written its way and the words stay English")
    func numbersTakeTheLocale() {
        let summary = SectorSalesSummary(
            sales: [DrinkSales(drink: "Tea", cups: 1640), DrinkSales(drink: "Mocha", cups: 1640), DrinkSales(drink: "Latte", cups: 1)],
            locale: german
        )
        let model = SectorMarkViewModel()
        model.cornerRadius = 1.5

        #expect(summary.headline == "Tea and Mocha share the largest part: 1.640 cups each.")
        #expect(summary.audioGraphSummary.hasPrefix("3 drinks, 3.281 cups in total."))
        #expect(model.cornerRadiusSpokenText(locale: german) == "1,5 points")
        #expect(model.summary(locale: german).locale == german)
    }

    @Test("Given the sliders, when one is let go, then the announcement says what the chart now is")
    func shapeAnnouncementFollowsTheSliders() {
        let model = plainPie()
        #expect(model.shapeAnnouncement(locale: english) == "A pie.")

        model.angularInset = 0.5
        #expect(model.shapeAnnouncement(locale: english) == "Pie: 1 point gaps, square corners.")

        model.innerRadiusRatio = 0.6
        model.angularInset = 1.5
        model.cornerRadius = 4
        #expect(model.shapeAnnouncement(locale: english) == "Donut: hole 60% of the radius, 3 point gaps, corners 4 points.")

        model.angularInset = 0
        model.cornerRadius = 1
        #expect(model.shapeAnnouncement(locale: english) == "Donut: hole 60% of the radius, no gaps, corners 1 point.")
    }

    @Test("Given nothing sold, when a slider is let go, then the announcement says there is nothing to draw")
    func shapeAnnouncementWithNoSales() {
        let model = SectorMarkViewModel(sales: [])
        model.innerRadiusRatio = 0.6

        #expect(model.shapeAnnouncement(locale: english) == "No sales to draw.")
    }

    @Test("Given drink sales, when the chart descriptor is made, then the sectors are its categories in drawn order")
    func descriptorDescribesSectors() throws {
        let descriptor = SectorChartDescriptor(summary: SectorSalesSummary(sales: sales, locale: english)).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today at the Harbour café, each drink's share")
        #expect(descriptor.summary == SectorSalesSummary(sales: sales, locale: english).audioGraphSummary)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Cocoa"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        // A pie's range runs from 0 to the total, of which each sector is a share: 164 + 128 + 57.
        #expect(yAxis.range == 0 ... 349)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(57) == "57 cups")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }
}
