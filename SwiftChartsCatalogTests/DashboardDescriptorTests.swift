import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DashboardDescriptorTests {
    private let locale = Locale(identifier: "en_US")

    @Test("Given the café breakdown, when the per-day descriptor is made, then it has a continuous series per café over 28 written-out days")
    func cupsPerDayByCafe() throws {
        let descriptor = DashboardModel().cupsPerDayDescriptor(locale: locale).makeChartDescriptor()
        #expect(descriptor.title == "Cups per day by café")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        let continuous = descriptor.series.map(\.isContinuous)
        #expect(continuous == [true, true])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 28 })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.summary?.hasPrefix("28 days, March 1 to March 28. Harbour: 5,726 cups in all") == true)
    }

    @Test("Given the drink breakdown and a drink, when the per-day descriptor is made, then it names each drink and keeps the shared range")
    func cupsPerDayByDrink() throws {
        let model = DashboardModel()
        model.breakdown = .drink
        model.selectDrink("Mocha")
        let descriptor = model.cupsPerDayDescriptor(locale: locale).makeChartDescriptor()
        #expect(descriptor.title == "Cups per day by drink")
        #expect(descriptor.series.map(\.name) == ["Latte", "Tea", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 300)
    }

    @Test("Given the café breakdown and a drink, when the per-day descriptor is made, then its title says the drink")
    func cupsPerDayForADrink() {
        let model = DashboardModel()
        model.selectDrink("Tea")
        #expect(model.cupsPerDayDescriptor(locale: locale).makeChartDescriptor().title == "Cups per day by café, Tea only")
    }

    @Test("Given a selected day, when the drink mix descriptor is made, then it gives that day's totals as separate bars")
    func drinkMixForADay() throws {
        let model = DashboardModel()
        model.selectDay(CafeData.day(CafeData.dashboardNoMochaOffset))
        let descriptor = model.drinkMixDescriptor(locale: locale).makeChartDescriptor()
        #expect(descriptor.title == "Cups by drink, Tuesday, March 17")
        #expect(descriptor.summary == "Latte, 234 cups; Tea, 106 cups; Mocha, 56 cups.")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.isContinuous == false)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        // Cups a day, as on the per-day chart: the same domain.
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == model.cupsDomain)
    }

    @Test("Given no day, when the drink mix descriptor is made, then it covers the four weeks on their own range")
    func drinkMixForTheFourWeeks() throws {
        let descriptor = DashboardModel().drinkMixDescriptor(locale: locale).makeChartDescriptor()
        #expect(descriptor.title == "Cups by drink, March 1 to March 28")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 7000)
    }

    @Test("Given each breakdown, when the weekday descriptor is made, then it has one row series over the seven weekdays")
    func weekdayRhythm() throws {
        let model = DashboardModel()
        let byCafe = model.weekdayDescriptor(locale: locale).makeChartDescriptor()
        #expect(byCafe.title == "Average cups by weekday and café")
        #expect(byCafe.series.map(\.name) == ["Harbour", "Station"])
        #expect(byCafe.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 7 })
        let xAxis = try #require(byCafe.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Monday")
        #expect(xAxis.categoryOrder.last == "Sunday")
        // The colour scale's domain, which the legend shows.
        let yAxis = try #require(byCafe.yAxis)
        #expect(yAxis.range == 160 ... 260)
        #expect(byCafe.summary == "Harbour busiest on Saturday, 251 cups on average. Station busiest on Wednesday, 213 cups on average.")

        model.breakdown = .drink
        let byDrink = model.weekdayDescriptor(locale: locale).makeChartDescriptor()
        #expect(byDrink.title == "Average cups by weekday and drink")
        #expect(byDrink.series.map(\.name) == ["Latte", "Tea", "Mocha"])
        #expect(try #require(byDrink.yAxis).range == model.heatDomain)
    }

    @Test("Given Latte by café, when the weekday descriptor is made, then every weekday that rounds to the top is named")
    func weekdayTies() {
        let model = DashboardModel()
        model.selectDrink("Latte")
        // Harbour's Tuesday is 105.0 and its Wednesday and Friday 104.5: all are said as 105.
        let summary = model.weekdayDescriptor(locale: locale).makeChartDescriptor().summary
        #expect(summary?.hasPrefix("Harbour busiest on Tuesday, Wednesday, and Friday, 105 cups on average.") == true)
    }

    @Test("Given days that share the top, when the per-day descriptor is made, then every one is named")
    func cupsPerDayTies() {
        let sales = (0 ..< 3).map(CafeData.day).enumerated().flatMap { index, day in
            CafeDrinkStyle.drinks.map { DashboardSale(day: day, store: CafeWording.harbour, drink: $0, cups: index == 1 ? 5 : 10) }
        }
        let summary = DashboardModel(sales: sales).cupsPerDayDescriptor(locale: locale).makeChartDescriptor().summary
        #expect(summary == "3 days, March 1 to March 3. Harbour: 75 cups in all, highest 30 cups on Sunday, March 1 and Tuesday, March 3.")
    }
}
