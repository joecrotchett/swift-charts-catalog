import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct ModifierOrderTests {
    private let english = Locale(identifier: "en_US")

    private func order(_ id: Int, _ drink: String, hour: Double, wait: Double) -> CafeOrder {
        CafeOrder(id: id, drink: drink, hour: hour, cups: 1, waitMinutes: wait)
    }

    @Test("Given a new screen, when it opens, then it shows the right order with 400 orders and the right snippet")
    func startsRight() {
        let viewModel = ModifierOrderViewModel()

        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.orders.count == 400)
        #expect(viewModel.snippets.map(\.name) == ["modifier-order-right"])
        #expect(!viewModel.showsPlaceholder)
    }

    @Test("Given the mistake, when it is shown, then the wrong snippet comes first and the fix after")
    func mistakeSnippets() {
        let viewModel = ModifierOrderViewModel()
        viewModel.isShowingMistake = true

        #expect(viewModel.snippets.map(\.name) == ["modifier-order-wrong", "modifier-order-right"])
        #expect(viewModel.headline(locale: english) == ModifierOrderCompilerError.headline)
    }

    @Test("Given the built app, when the snippets are looked up, then each exists and shows its order")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let right = try #require(store["modifier-order-right"])
        let wrong = try #require(store["modifier-order-wrong"])

        let rightKeyPath = try #require(right.code.range(of: ".foregroundStyle(by:"))
        let rightPlain = try #require(right.code.range(of: ".opacity(0.6)"))
        #expect(rightKeyPath.lowerBound < rightPlain.lowerBound)
        let wrongKeyPath = try #require(wrong.code.range(of: ".foregroundStyle(by:"))
        let wrongPlain = try #require(wrong.code.range(of: ".opacity(0.6)"))
        #expect(wrongPlain.lowerBound < wrongKeyPath.lowerBound)
        // Each drink is a colour and a shape, in both orders.
        #expect(right.code.contains(".symbol(by: .value(CafeWording.drink, \\.drink))"))
        #expect(wrong.code.contains(".symbol(by: .value(CafeWording.drink, \\.drink))"))
        #expect(!right.code.contains(".symbol(.square)"))
        // The wrong snippet shows both errors the build gave.
        for message in ["no exact matches in call to instance method 'symbolSize'", "(aka 'KeyPath<CafeOrder, CGFloat>')"] {
            #expect(wrong.code.contains(message))
        }
        #expect(right.file == "VectorizedPlots/ModifierOrderScreen.swift")
        #expect(wrong.file == "VectorizedPlots/ModifierOrderScreen.swift")
    }

    @Test("Given the generated orders, when the view model groups them, then they run drink by drink in the scale's order")
    func groupedByDrink() {
        let viewModel = ModifierOrderViewModel()
        let drinks = viewModel.orders.map(\.drink)
        var runs: [String] = []
        for drink in drinks where runs.last != drink {
            runs.append(drink)
        }

        #expect(runs == CafeData.manyOrderDrinks)
    }

    @Test("Given a few orders, when the headline is written, then it gives the count and the longest wait")
    func headline() {
        let viewModel = ModifierOrderViewModel(orders: [
            order(0, "Tea", hour: 8, wait: 3.24),
            order(1, "Latte", hour: 12.5, wait: 9.81),
        ])

        #expect(viewModel.headline(locale: english) == "Of 2 orders, the longest wait was 9.8 minutes.")
    }

    @Test("Given one order of one minute, when the headline is written, then both counts agree in number")
    func headlineSingular() {
        let viewModel = ModifierOrderViewModel(orders: [order(0, "Tea", hour: 7, wait: 1)])

        #expect(viewModel.headline(locale: english) == "Of 1 order, the longest wait was 1 minute.")
    }

    @Test("Given no orders, when the screen opens, then it shows a placeholder and a headline that is true")
    func empty() {
        let viewModel = ModifierOrderViewModel(orders: [])

        #expect(viewModel.showsPlaceholder)
        #expect(viewModel.headline(locale: english) == "No orders yet.")
        #expect(viewModel.summary(locale: english).audioGraphSummary == "No orders yet.")
    }

    @Test("Given a German locale, when the headline is written, then the number takes a decimal comma")
    func germanLocale() {
        let viewModel = ModifierOrderViewModel(orders: [order(0, "Tea", hour: 8, wait: 9.81)])

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")).contains("9,8"))
    }

    @Test("Given each state, when it changes, then the announcement says what changed and then the headline")
    func announcements() {
        let viewModel = ModifierOrderViewModel(orders: [order(0, "Tea", hour: 8, wait: 4)])
        viewModel.isShowingMistake = true
        #expect(viewModel.announcement(locale: english)
            == "Showing the wrong order. The chart is replaced by the compiler error. \(ModifierOrderCompilerError.headline)")

        viewModel.isShowingMistake = false
        #expect(viewModel.announcement(locale: english)
            == "Showing the right order. The chart is drawn. Of 1 order, the longest wait was 4 minutes.")
    }

    @Test("Given an hour, when it is said, then it is the locale's own clock time, never a forced 24-hour clock")
    func clockTime() {
        #expect(ModifierOrderWording.clockTime(8.5, locale: english) == "8:30\u{202F}AM")
        #expect(ModifierOrderWording.clockTime(18, locale: english) == "6:00\u{202F}PM")
        #expect(ModifierOrderWording.clockTime(6.05, locale: english) == "6:03\u{202F}AM")
        #expect(ModifierOrderWording.clockTime(18, locale: Locale(identifier: "en_GB")) == "18:00")
        #expect(ModifierOrderWording.clockTime(.nan, locale: english) == "")
    }

    @Test("Given orders, when VoiceOver's stretches are made, then each counts its orders by drink")
    func spokenPortions() throws {
        let summary = ModifierOrderSummary(orders: [order(0, "Tea", hour: 6.2, wait: 3), order(1, "Mocha", hour: 7, wait: 5)], locale: english)
        let first = try #require(summary.portions.first)

        #expect(summary.portions.count == 6)
        #expect(first.value(locale: english)
            == "2 orders, waits from 3 minutes to 5 minutes, median 4 minutes; Latte 0, Tea 1, Mocha 1, and Espresso 0")
    }

    @Test("Given the orders, when the y domain is worked out, then it runs from zero to the longest wait rounded up")
    func waitDomain() {
        let summary = ModifierOrderSummary(orders: [order(0, "Tea", hour: 8, wait: 9.2)], locale: english)

        #expect(summary.waitDomain == 0 ... 10)
        #expect(ModifierOrderSummary(orders: [], locale: english).waitDomain == 0 ... 1)
    }

    @Test("Given a few orders, when the descriptor is made, then it names the axes, a series per drink and the values")
    func descriptor() throws {
        let orders = [
            order(0, "Latte", hour: 8, wait: 6.5),
            order(1, "Tea", hour: 12.5, wait: 9.8),
            order(2, "Tea", hour: 15, wait: 2),
        ]
        let descriptor = ModifierOrderChartDescriptor(orders: orders, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Wait against time of day, by drink")
        #expect(descriptor.summary
            == "3 orders, between 6:00\u{202F}AM and 6:00\u{202F}PM. Shortest wait 2 minutes, longest 9.8 minutes at 12:30\u{202F}PM.")
        #expect(descriptor.series.map(\.name) == ["Latte", "Tea"])
        #expect(descriptor.series.map(\.dataPoints.count) == [1, 2])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.title == "Time of day")
        #expect(xAxis.range == 6 ... 18)
        #expect(xAxis.valueDescriptionProvider(8.5) == "8:30\u{202F}AM")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Wait (minutes)")
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(1) == "1 minute")
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
    }

    @Test("Given the compiler errors, when they are read, then they are the two the build gave, with the Xcode version")
    func compilerError() {
        #expect(ModifierOrderCompilerError.messages == [
            "error: no exact matches in call to instance method 'symbolSize'",
            "error: cannot convert value of type 'Double' to expected argument type "
                + "'KeyPath<PointPlot<VectorizedPointPlotContent<[CafeOrder]>>.DataElement, CGFloat>' (aka 'KeyPath<CafeOrder, CGFloat>')",
        ])
        #expect(ModifierOrderCompilerError.xcodeVersion == "Xcode 27.0 (27A266a)")
    }
}
