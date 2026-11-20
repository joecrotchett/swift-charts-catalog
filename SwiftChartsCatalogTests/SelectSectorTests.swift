import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SelectSectorTests {
    private let english = Locale(identifier: "en_US")
    /// Drawn largest first: Tea 0–164, Latte 164–292, Americano 292–402, Mocha 402–494, Cocoa 494–551.
    private let slices = SelectSectorMapping.slices(from: CafeData.drinkSales)

    private func drink(at value: Double) -> String? {
        SelectSectorMapping.slice(at: value, in: slices)?.drink
    }

    // MARK: Slices

    @Test("Given the day's sales, when they become sectors, then they run largest first with running ranges")
    func slicesRunLargestFirst() {
        #expect(slices.map(\.drink) == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        #expect(slices.map(\.start) == [0, 164, 292, 402, 494])
        #expect(slices.map(\.end) == [164, 292, 402, 494, 551])
    }

    @Test("Given a tie and a drink with no cups, when they become sectors, then the tie keeps data order and the empty drink is left out")
    func slicesKeepTiesAndDropZeros() {
        let tied = SelectSectorMapping.slices(from: [
            DrinkSales(drink: "Mocha", cups: 0),
            DrinkSales(drink: "Latte", cups: 40),
            DrinkSales(drink: "Tea", cups: 40),
        ])
        #expect(tied.map(\.drink) == ["Latte", "Tea"])
        #expect(tied.map(\.end) == [40, 80])
    }

    // MARK: Mapping a running-total value to a sector

    @Test("Given a value inside a sector's range, when it is mapped, then it selects that sector")
    func mapsInsideASector() {
        #expect(drink(at: 80) == "Tea")
        #expect(drink(at: 210.4) == "Latte")
        #expect(drink(at: 350) == "Americano")
        #expect(drink(at: 450) == "Mocha")
        #expect(drink(at: 520) == "Cocoa")
    }

    @Test("Given a value exactly on a boundary between sectors, when it is mapped, then it selects the sector that starts there")
    func mapsEachInnerBoundaryToTheNextSector() {
        #expect(drink(at: 164) == "Latte")
        #expect(drink(at: 292) == "Americano")
        #expect(drink(at: 402) == "Mocha")
        #expect(drink(at: 494) == "Cocoa")
    }

    @Test("Given a value just below a boundary, when it is mapped, then it selects the sector that ends there")
    func mapsJustBelowEachBoundary() {
        #expect(drink(at: 163.999) == "Tea")
        #expect(drink(at: 291.999) == "Latte")
        #expect(drink(at: 401.999) == "Americano")
        #expect(drink(at: 493.999) == "Mocha")
    }

    @Test("Given zero or the total, when they are mapped, then they select the first and the last sector")
    func mapsTheOuterBoundaries() {
        #expect(drink(at: 0) == "Tea")
        #expect(drink(at: 551) == "Cocoa")
    }

    @Test("Given a value outside the total, when it is mapped, then no sector is selected")
    func mapsOutsideTheTotalToNothing() {
        #expect(drink(at: -0.001) == nil)
        #expect(drink(at: -50) == nil)
        #expect(drink(at: 551.001) == nil)
        #expect(drink(at: 1000) == nil)
        #expect(drink(at: .nan) == nil)
        #expect(drink(at: .infinity) == nil)
        #expect(SelectSectorMapping.slice(at: 10, in: []) == nil)
    }

    // MARK: View model states

    @Test("Given no selection, when the screen is at rest, then no sector is faded and the headline names the best seller")
    func restingState() {
        let viewModel = SelectSectorViewModel()
        #expect(viewModel.selectedSlice == nil)
        #expect(viewModel.slices.allSatisfy { !viewModel.isFaded($0) })
        #expect(viewModel.headline(locale: english) == "Tea sold the most: 164 cups.")
        #expect(viewModel.slices.map { viewModel.label(for: $0, locale: english) } == ["164", "128", "110", "92", "57"])
    }

    @Test("Given a selected value in Latte's range, when the raw value is hidden, then Latte is highlighted and the headline gives its cups")
    func selectionWithoutRawValue() {
        let viewModel = SelectSectorViewModel()
        viewModel.selectedValue = 210.4
        #expect(viewModel.selectedSlice?.drink == "Latte")
        #expect(viewModel.slices.filter { viewModel.isFaded($0) }.map(\.drink) == ["Tea", "Americano", "Mocha", "Cocoa"])
        #expect(viewModel.headline(locale: english) == "Latte: 128 cups.")
    }

    @Test("Given the raw value shown, when nothing is selected, then each sector is labelled with where it ends along the running total")
    func rawValueAtRest() {
        let viewModel = SelectSectorViewModel()
        viewModel.showsRawValue = true
        #expect(viewModel.slices.map { viewModel.label(for: $0, locale: english) } == ["164", "292", "402", "494", "551"])
        #expect(viewModel.headline(locale: english) == "Tea sold the most: 164 cups.")
    }

    @Test("Given the raw value shown, when a value is selected, then the selected sector shows it rounded down and the headline places it")
    func rawValueWhileSelecting() {
        let viewModel = SelectSectorViewModel()
        viewModel.showsRawValue = true
        viewModel.selectedValue = 291.9
        #expect(viewModel.slices.map { viewModel.label(for: $0, locale: english) } == ["164", "291", "402", "494", "551"])
        #expect(viewModel.headline(locale: english) == "Raw value 291 lands in Latte, past Tea’s 164.")

        viewModel.selectedValue = 80
        #expect(viewModel.headline(locale: english) == "Raw value 80 lands in Tea, the first sector.")
    }

    @Test("Given a value outside the total, when it is reported, then nothing is selected and the headline is the resting one")
    func valueOutsideTheTotal() {
        let viewModel = SelectSectorViewModel()
        viewModel.showsRawValue = true
        viewModel.selectedValue = 600
        #expect(viewModel.selectedSlice == nil)
        #expect(viewModel.slices.allSatisfy { !viewModel.isFaded($0) })
        #expect(viewModel.headline(locale: english) == "Tea sold the most: 164 cups.")
    }

    @Test("Given every state, when the reserved headline is measured, then no headline is longer")
    func reservedHeadlineIsTheLongest() {
        let viewModel = SelectSectorViewModel()
        for showsRawValue in [false, true] {
            viewModel.showsRawValue = showsRawValue
            let reserved = viewModel.reservedHeadline(locale: english)
            for value in [nil, 0, 100, 200, 300, 450, 551] as [Double?] {
                viewModel.selectedValue = value
                #expect(viewModel.headline(locale: english).count <= reserved.count)
            }
        }
    }

    @Test("Given no sales or only zeros, when the screen is built, then it has no data and a true headline")
    func emptyAndZeroData() {
        for sales in [[], [DrinkSales(drink: "Tea", cups: 0)]] {
            let viewModel = SelectSectorViewModel(sales: sales)
            #expect(!viewModel.hasData)
            viewModel.selectedValue = 0
            #expect(viewModel.selectedSlice == nil)
            #expect(viewModel.headline(locale: english) == "No cups sold yet today.")
            #expect(viewModel.descriptor(locale: english).summary == "No cups sold yet today.")
        }
    }

    @Test("Given a tie for the most, when the screen is at rest, then the headline names both")
    func tieHeadline() {
        let viewModel = SelectSectorViewModel(sales: [DrinkSales(drink: "Latte", cups: 40), DrinkSales(drink: "Tea", cups: 40)])
        #expect(viewModel.headline(locale: english) == "Latte and Tea sold the most: 40 cups.")
    }

    @Test("Given one cup, when the headline is written, then the count agrees in number")
    func oneCupAgrees() {
        let viewModel = SelectSectorViewModel(sales: [DrinkSales(drink: "Tea", cups: 1)])
        #expect(viewModel.headline(locale: english) == "Tea sold the most: 1 cup.")
    }

    @Test("Given a German locale, when numbers are written, then they use its grouping")
    func localeReachesTheWords() {
        let german = Locale(identifier: "de_DE")
        let viewModel = SelectSectorViewModel(sales: [DrinkSales(drink: "Tea", cups: 1200), DrinkSales(drink: "Latte", cups: 300)])
        viewModel.showsRawValue = true
        viewModel.selectedValue = 1400.7
        #expect(viewModel.headline(locale: german) == "Raw value 1.400 lands in Latte, past Tea’s 1.200.")
    }

    // MARK: Element text, announcements and snippets

    @Test("Given each setting, when a sector's element value is read, then it gives cups and, with the raw value, its running range")
    func elementValues() {
        let viewModel = SelectSectorViewModel()
        let latte = viewModel.slices[1]
        #expect(viewModel.elementValue(for: latte, locale: english) == "128 cups")
        viewModel.showsRawValue = true
        #expect(viewModel.elementValue(for: latte, locale: english) == "128 cups, running total 164 to 292")
    }

    @Test("Given the toggle changes, when the announcement is written, then it says what changed and then the headline")
    func announcements() {
        let viewModel = SelectSectorViewModel()
        viewModel.showsRawValue = true
        #expect(viewModel.announcement(locale: english)
            == "Sectors now show where each ends along the running total. Tea sold the most: 164 cups.")
        viewModel.showsRawValue = false
        #expect(viewModel.announcement(locale: english) == "Sectors now show each drink’s cups. Tea sold the most: 164 cups.")
    }

    @Test("Given each setting, when the snippets are listed, then they follow the toggle and exist in the bundle")
    func snippetsFollowTheToggle() throws {
        let store = try SnippetStore()
        let viewModel = SelectSectorViewModel()
        #expect(viewModel.snippets.map(\.name) == ["select-a-sector-chart", "select-a-sector-mapping"])
        viewModel.showsRawValue = true
        #expect(viewModel.snippets.map(\.name) == ["select-a-sector-chart", "select-a-sector-mapping", "select-a-sector-raw-label"])
        for snippet in viewModel.snippets {
            #expect(store[snippet.name] != nil)
        }
    }

    // MARK: Audio Graph

    @Test("Given the day's sales, when the descriptor is made, then it describes the drinks in drawing order with cups")
    func descriptor() throws {
        let descriptor = SelectSectorViewModel().descriptor(locale: english)
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        let chart = descriptor.makeChartDescriptor()
        #expect(chart.title == descriptor.title)
        let xAxis = try #require(chart.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        let yAxis = try #require(chart.yAxis)
        // A donut runs from 0 to the total, of which each sector is a share.
        #expect(yAxis.range == 0 ... 551)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(128) == "128 cups")
        #expect(chart.series.count == 1)
        #expect(chart.series.first?.name == CafeWording.harbour)
        #expect(chart.series.first?.isContinuous == false)
        #expect(chart.series.first?.dataPoints.count == 5)
    }

    @Test("Given a tie for the most and for the fewest, when the summary is written, then it names every tied drink")
    func descriptorSummaryNamesTies() {
        let sales = [
            DrinkSales(drink: "Latte", cups: 40),
            DrinkSales(drink: "Tea", cups: 40),
            DrinkSales(drink: "Mocha", cups: 10),
            DrinkSales(drink: "Cocoa", cups: 10),
        ]
        let summary = SelectSectorViewModel(sales: sales).descriptor(locale: english).summary
        #expect(summary == "4 drinks, 100 cups in total. Most: Latte and Tea, 40 cups. Fewest: Mocha and Cocoa, 10 cups.")
    }

    @Test("Given one drink, or every drink selling the same, when the summary is written, then it leaves out the fewest")
    func descriptorSummaryWithoutFewest() {
        let single = SelectSectorViewModel(sales: [DrinkSales(drink: "Tea", cups: 1)]).descriptor(locale: english)
        #expect(single.summary == "1 drink, 1 cup in total. Most: Tea, 1 cup.")
        let tied = SelectSectorViewModel(sales: [DrinkSales(drink: "Latte", cups: 40), DrinkSales(drink: "Tea", cups: 40)])
        #expect(tied.descriptor(locale: english).summary == "2 drinks, 80 cups in total. Most: Latte and Tea, 40 cups.")
    }

    // MARK: What the chart's body reads

    @Test("Given each selection, when the chart reads its plain values, then the faded drinks and labels follow it")
    func chartValuesFollowTheSelection() {
        let viewModel = SelectSectorViewModel()
        #expect(viewModel.fadedDrinks.isEmpty)
        viewModel.selectedValue = 80
        #expect(viewModel.fadedDrinks == ["Latte", "Americano", "Mocha", "Cocoa"])
        #expect(viewModel.labels(locale: english) == ["Tea": "164", "Latte": "128", "Americano": "110", "Mocha": "92", "Cocoa": "57"])
        viewModel.showsRawValue = true
        viewModel.selectedValue = 163.9
        #expect(viewModel.labels(locale: english) == ["Tea": "163", "Latte": "292", "Americano": "402", "Mocha": "494", "Cocoa": "551"])
        viewModel.selectedValue = nil
        #expect(viewModel.fadedDrinks.isEmpty)
    }
}
