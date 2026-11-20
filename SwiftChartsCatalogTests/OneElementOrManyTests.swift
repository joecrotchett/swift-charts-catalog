import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct OneElementOrManyTests {
    private let english = Locale(identifier: "en_US")

    /// The time format puts a narrow no-break space before "AM"; compare with ordinary spaces.
    private func plain(_ text: String) -> String {
        text.replacing("\u{202F}", with: " ")
    }

    private func text(_ data: OneElementOrManyData = OneElementOrManyData()) -> OneElementOrManySpokenText {
        OneElementOrManySpokenText(data: data, locale: english)
    }

    private var empty: OneElementOrManyData {
        OneElementOrManyData(drinkSales: [], halfHourOrders: [])
    }

    private var allZero: OneElementOrManyData {
        OneElementOrManyData(
            drinkSales: CafeData.drinkSales.map { DrinkSales(drink: $0.drink, cups: 0) },
            halfHourOrders: CafeData.halfHourOrders.map { HalfHourOrders(start: $0.start, orders: 0) }
        )
    }

    // MARK: Portions

    @Test("Given the day's orders, when it is cut into portions, then each service period is one portion with its own half hours")
    func portionBoundaries() {
        let portions = text().portions

        #expect(portions.map(\.name) == ["Early", "Morning rush", "Late morning", "Lunch", "Afternoon", "Close"])
        #expect(portions.map(\.startHour) == [6, 7.5, 9, 11.5, 13.5, 17])
        #expect(portions.map(\.endHour) == [7.5, 9, 11.5, 13.5, 17, 18])
        #expect(portions.map(\.halfHours.count) == [3, 3, 5, 4, 7, 2])
        #expect(portions.map(\.total) == [87, 148, 128, 130, 74, 21])
        #expect(portions.map(\.isShaded) == [true, false, true, false, true, false])
    }

    @Test("Given the morning rush, when its element is written, then the label gives its clock times and the value its orders with units")
    func portionLabelAndValue() throws {
        let text = text()
        let rush = try #require(text.portions.first { $0.name == "Morning rush" })

        #expect(plain(text.portionLabel(rush)) == "Morning rush, 7:30 AM to 9:00 AM")
        #expect(plain(text.portionValue(rush))
            == "148 orders in total; first half hour 46 orders, last 45 orders, highest 57 orders at 8:00 AM.")
    }

    @Test("Given no orders at all, when the day is cut into portions, then there are none and nothing is spoken")
    func portionsOfEmptyData() {
        let text = text(empty)

        #expect(text.portions.isEmpty)
        #expect(text.elements(.eachPortion).isEmpty)
        #expect(text.audioGraph(.eachPortion) == nil)
        #expect(!text.drawsChart(.eachPortion))
        #expect(text.headline(.eachPortion) == "No orders yet today.")
    }

    @Test("Given every half hour at zero, when the day is cut into portions, then the line is drawn and each portion says it had none")
    func portionsOfAllZeroData() {
        let text = text(allZero)

        #expect(text.drawsChart(.eachPortion))
        #expect(text.portions.map(\.halfHours.count) == [3, 3, 5, 4, 7, 2])
        #expect(text.portions.allSatisfy { text.portionValue($0) == "0 orders in total." })
        #expect(text.headline(.eachPortion) == "No orders yet today.")
        #expect(plain(text.portionSummary) == "Every half hour from 6:00 AM to 6:00 PM: 0 orders in total.")
        #expect(text.ordersTop == OneElementOrManySpokenText.ordersStep)
    }

    @Test("Given a period with no half hours in it, when the day is cut into portions, then it is left out and the rest keep alternating")
    func emptyPeriodLeftOut() {
        let mornings = CafeData.halfHourOrders.filter { OneElementOrManyData.hour(of: $0.start) < 9 }
        let portions = text(OneElementOrManyData(halfHourOrders: mornings)).portions

        #expect(portions.map(\.name) == ["Early", "Morning rush"])
        #expect(portions.map(\.index) == [0, 1])
    }

    // MARK: Headlines

    @Test("Given the sample data, when each headline is written, then it carries a figure the chart shows")
    func headlines() {
        let text = text()

        #expect(text.headline(.eachMark) == "Tea sold the most today: 164 cups.")
        #expect(plain(text.headline(.eachPortion)) == "The busiest half hour started at 8:00 AM, in the Morning rush: 57 orders.")
        #expect(text.headline(.wholeChart) == "588 orders today.")
    }

    @Test("Given two half hours tied for the most orders, when the headline is written, then it names both")
    func portionHeadlineTie() {
        let orders = [
            HalfHourOrders(start: CafeData.time(8), orders: 30),
            HalfHourOrders(start: CafeData.time(12), orders: 30),
            HalfHourOrders(start: CafeData.time(14), orders: 10),
        ]

        #expect(plain(text(OneElementOrManyData(halfHourOrders: orders)).headline(.eachPortion))
            == "The busiest half hours started at 8:00 AM and 12:00 PM: 30 orders each.")
    }

    @Test("Given drinks with no cups, when the bars would be drawn, then a placeholder shows and the headline says nothing sold")
    func allZeroDrinks() {
        let text = text(allZero)

        #expect(!text.drawsChart(.eachMark))
        #expect(text.elements(.eachMark).isEmpty)
        #expect(text.audioGraph(.eachMark) == nil)
        #expect(text.headline(.eachMark) == "No cups sold yet today.")
    }

    @Test("Given each choice, when it is announced, then the announcement says what changed and then the headline")
    func announcement() {
        #expect(text().announcement(.wholeChart) == "One element for the whole chart. 588 orders today.")
    }

    // MARK: The whole chart

    @Test("Given the day's orders, when the preview is described, then it is one button element with a succinct total, as read on iOS 27")
    func wholeChartSummary() {
        let text = text()

        #expect(text.elements(.wholeChart) == [
            OneElementOrManyElement(label: "Orders today, by half hour", value: "588 orders in total", trait: "Button"),
        ])
        #expect(text.audioGraph(.wholeChart) == nil)
    }

    @Test("Given no orders, when the preview would be drawn, then a placeholder shows and nothing is spoken")
    func wholeChartEmpty() {
        let text = text(empty)

        #expect(!text.drawsChart(.wholeChart))
        #expect(text.elements(.wholeChart).isEmpty)
        #expect(text.headline(.wholeChart) == "No orders yet today.")
        #expect(text.previewValue == "0 orders in total")
    }

    @Test("Given every half hour at zero, when the preview is described, then it is drawn and says no orders")
    func wholeChartAllZero() {
        let text = text(allZero)

        #expect(text.drawsChart(.wholeChart))
        #expect(text.elements(.wholeChart).map(\.value) == ["0 orders in total"])
        #expect(text.headline(.wholeChart) == "No orders yet today.")
    }

    // MARK: Elements and the Audio Graph

    @Test("Given each mark, when the elements are written, then there is one per drink, ranked, with cups")
    func markElements() {
        let elements = text().elements(.eachMark)

        #expect(elements.map(\.label) == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        #expect(elements.first?.value == "164 cups")
    }

    @Test("Given each mark, when the descriptor is made, then it names the drinks, matches the drawn scale and says cups")
    func markDescriptor() throws {
        let text = text()
        let descriptor = OneElementOrManyChartDescriptor(graph: text.markGraph, locale: english).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today, by drink")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }

    @Test("Given each portion, when the descriptor is made, then the Audio Graph still gets every half hour as one continuous line")
    func portionDescriptor() throws {
        let text = text()
        let descriptor = OneElementOrManyChartDescriptor(graph: text.portionGraph, locale: english).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(text.elements(.eachPortion).count == 6)
        #expect(descriptor.series.first?.dataPoints.count == 24)
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(yAxis.range == 0 ... 60)
        #expect(yAxis.valueDescriptionProvider(57) == "57 orders")
        #expect(plain(descriptor.summary ?? "") == "Every half hour from 6:00 AM to 6:00 PM: 588 orders in total. "
            + "Most: 8:00 AM, 57 orders. Fewest: 4:00 PM, 8 orders. Busiest part of the day: Morning rush, 148 orders.")
    }

    // MARK: The view model

    @Test("Given each choice, when its code is shown, then the snippets are the ones for that choice and all exist")
    func snippets() throws {
        let store = try SnippetStore()
        let model = OneElementOrManyViewModel()
        var shown: [OneElementOrManyChoice: [String]] = [:]
        for choice in OneElementOrManyChoice.allCases {
            model.choice = choice
            shown[choice] = model.snippets.map(\.name)
        }

        #expect(shown[.eachMark] == ["one-element-or-many-each-mark", "one-element-or-many-descriptor"])
        #expect(shown[.eachPortion] == ["one-element-or-many-each-portion", "one-element-or-many-descriptor"])
        #expect(shown[.wholeChart] == ["one-element-or-many-whole-chart"])
        #expect(OneElementOrManyViewModel.allSnippets.allSatisfy { store[$0.name] != nil })
    }

    @Test("Given the preview, when it is opened, then the fuller chart of the same orders is shown")
    func openFullChart() {
        let model = OneElementOrManyViewModel()
        model.choice = .wholeChart
        model.openFullChart()

        #expect(model.choice == .eachPortion)
    }

    @Test("Given no data for any choice, when the picker is shown, then it is disabled")
    func pickerDisabledWithNothingToDraw() {
        #expect(!OneElementOrManyViewModel(data: empty).hasAnythingToDraw(locale: english))
        #expect(OneElementOrManyViewModel().hasAnythingToDraw(locale: english))
    }

    @Test("Given orders that fall in no part of the day, when the portions would be drawn, then a placeholder shows and nothing is spoken")
    func ordersOutsideEveryPortion() {
        let text = text(OneElementOrManyData(periods: []))

        #expect(text.portions.isEmpty)
        #expect(!text.drawsChart(.eachPortion))
        #expect(text.elements(.eachPortion).isEmpty)
        #expect(text.audioGraph(.eachPortion) == nil)
        #expect(text.headline(.eachPortion) == "No orders fall in a named part of the day.")
        #expect(text.drawsChart(.wholeChart))
    }
}
