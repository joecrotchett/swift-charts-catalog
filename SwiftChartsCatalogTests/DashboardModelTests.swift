import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DashboardModelTests {
    private let locale = Locale(identifier: "en_US")
    private let noMochaDay = CafeData.day(CafeData.dashboardNoMochaOffset)

    // MARK: The data agrees with the catalog

    @Test("Given the dashboard's data, when the four weeks are totalled per café, then they equal storeSales")
    func cafeTotalsAgreeWithStoreSales() {
        let model = DashboardModel()
        for store in CafeData.storeSales {
            #expect(model.cups(store: store.store) == store.days.map(\.cups).reduce(0, +))
        }
        #expect(model.selectionTotal == 11216)
    }

    @Test("Given the dashboard's data, when it is read, then it has 28 days, both cafés and the three drinks in the shared order")
    func sharedOrders() {
        let model = DashboardModel()
        #expect(model.days.count == 28)
        #expect(model.stores == CafeSeriesStyle.stores)
        #expect(model.drinks == CafeDrinkStyle.drinks)
    }

    @Test("Given the dashboard's data, when the domains are worked out, then every position scale of cups a day shares 0 to 300")
    func sharedDomains() {
        let model = DashboardModel()
        #expect(model.cupsDomain == 0 ... 300)
        #expect(model.periodDrinkDomain == 0 ... 7000)
        // The drink mix for one day draws cups a day too, so it takes the same domain.
        model.selectDay(noMochaDay)
        #expect(model.drinkMixDomain == model.cupsDomain)
        // The domain does not move with the breakdown or the selection.
        model.breakdown = .drink
        model.selectDrink("Mocha")
        #expect(model.cupsDomain == 0 ... 300)
    }

    @Test("Given each breakdown and drink, when the heat map's colour domain is worked out, then it spans the averages shown, rounded out to 10")
    func heatDomains() {
        let model = DashboardModel()
        // Café rows: 165.5 (Station, Sunday) to 250.5 (Harbour, Saturday).
        #expect(model.heatDomain == 160 ... 260)
        #expect(model.weekdaySubtitle(locale: locale) == "Average cups by weekday and café. Shades from 160 to 260 cups.")
        model.selectDrink("Mocha")
        // Café rows of mocha alone: 24 to 59.
        #expect(model.heatDomain == 20 ... 60)
        #expect(model.weekdaySubtitle(locale: locale) == "Average cups by weekday and café, Mocha only. Shades from 20 to 60 cups.")
        model.breakdown = .drink
        // Drink rows: 75.25 (Mocha, Sunday) to 207.5 (Latte, Wednesday), whatever drink is selected.
        #expect(model.heatDomain == 70 ... 210)
        let cells = model.heatCells
        #expect(cells.allSatisfy { model.heatDomain.contains($0.averageCups) })
    }

    @Test("Given data where every average is the same, when the heat map's colour domain is worked out, then it still spans one step")
    func heatDomainOfEqualValues() {
        let sales = (0 ..< 7).map(CafeData.day).flatMap { day in
            CafeDrinkStyle.drinks.map { DashboardSale(day: day, store: CafeWording.harbour, drink: $0, cups: 10) }
        }
        let model = DashboardModel(sales: sales)
        #expect(model.heatDomain == 30 ... 40)
    }

    // MARK: No selection

    @Test("Given no selection, when the summary is read, then it covers the four weeks")
    func summaryWithNoSelection() {
        let model = DashboardModel()
        let summary = model.summary(locale: locale)
        #expect(summary.caption == "Cups")
        #expect(summary.totalText == "11,216 cups")
        #expect(summary.period == "March 1 to March 28")
        #expect(summary.change == "Select a day to compare it with a week earlier.")
        #expect(summary.busiestCafe == "Harbour, 5,726 cups")
        #expect(summary.busiestDrink == "Latte, 5,558 cups")
    }

    @Test("Given no selection, when the headline is read, then it states the total, the busiest café and the busiest drink")
    func headlineWithNoSelection() {
        let model = DashboardModel()
        #expect(model.headline(locale: locale) == """
        From March 1 to March 28, Harbour and Station sold 11,216 cups. Harbour sold the most: 5,726 cups. \
        Latte was the busiest drink: 5,558 cups.
        """)
    }

    @Test("Given no selection, when the drink mix is read, then it holds the four weeks' totals per drink on the four-week domain")
    func drinkMixWithNoSelection() {
        let model = DashboardModel()
        #expect(model.drinkBars == [
            DashboardDrinkBar(drink: "Latte", cups: 5558),
            DashboardDrinkBar(drink: "Tea", cups: 3234),
            DashboardDrinkBar(drink: "Mocha", cups: 2424),
        ])
        #expect(model.drinkMixDomain == model.periodDrinkDomain)
        #expect(model.emphasisedDrinks == ["Latte", "Tea", "Mocha"])
        #expect(model.selectedWeekday == nil)
    }

    // MARK: A selected day

    @Test("Given a selected day, when the summary is read, then it gives that day and its change on the same weekday a week earlier")
    func summaryForADay() {
        let model = DashboardModel()
        model.selectDay(noMochaDay)
        let summary = model.summary(locale: locale)
        #expect(summary.totalText == "396 cups")
        #expect(summary.period == "Tuesday, March 17")
        #expect(summary.change == "28 cups more than Tuesday, March 10.")
        #expect(model.selectedWeekday == "Tue")
        #expect(model.drinkMixDomain == model.cupsDomain)
        #expect(model.drinkBars.map(\.cups) == [234, 106, 56])
    }

    @Test("Given a day in the first week, when the summary is read, then it says there is no day a week earlier")
    func firstWeekHasNoComparison() {
        let model = DashboardModel()
        model.selectDay(CafeData.day(3))
        #expect(model.weekEarlierChange == nil)
        #expect(model.summary(locale: locale).change == "No day a week earlier in the data.")
    }

    @Test("Given a raw position with a time of day, when it is selected, then the day containing it is selected")
    func rawPositionSnapsToItsDay() throws {
        let model = DashboardModel()
        let afternoon = try #require(CafeData.calendar.date(byAdding: .hour, value: 15, to: noMochaDay))
        model.selectDay(afternoon)
        #expect(model.selectedDay == noMochaDay)
    }

    @Test("Given a selected day, when a day outside the data is selected, then the selection clears")
    func dayOutsideTheDataClears() {
        let model = DashboardModel()
        model.selectDay(noMochaDay)
        model.selectDay(CafeData.day(40))
        #expect(model.selectedDay == nil)
        model.selectDay(noMochaDay)
        model.selectDay(CafeData.day(-1))
        #expect(model.selectedDay == nil)
    }

    // MARK: A selected drink

    @Test("Given a selected drink, when the summary and headline are read, then they count that drink alone")
    func summaryForADrink() {
        let model = DashboardModel()
        model.selectDrink("Mocha")
        let summary = model.summary(locale: locale)
        #expect(summary.caption == "Cups of Mocha")
        #expect(summary.totalText == "2,424 cups")
        #expect(summary.busiestCafe == "Station, 1,442 cups")
        // The row stays while a drink is selected, comparing every drink as the drink mix does,
        // so the card keeps its height and the charts below it do not move.
        #expect(summary.busiestDrink == "Latte, 5,558 cups")
        #expect(model.headline(locale: locale) == """
        From March 1 to March 28, Harbour and Station sold 2,424 cups of Mocha. Station sold the most: 1,442 cups.
        """)
    }

    @Test("Given a selected drink, when the drink mix is read, then every drink is still drawn and only the selected one is emphasised")
    func drinkMixEmphasisesTheSelectedDrink() {
        let model = DashboardModel()
        model.selectDrink("Tea")
        #expect(model.drinkBars.count == 3)
        #expect(model.emphasisedDrinks == ["Tea"])
    }

    @Test("Given a selected drink, when a drink outside the data is selected, then the selection clears")
    func unknownDrinkClears() {
        let model = DashboardModel()
        model.selectDrink("Tea")
        model.selectDrink("Cocoa")
        #expect(model.selectedDrink == nil)
    }

    // MARK: A day and a drink

    @Test("Given the day Harbour sold no mocha, when Mocha and that day are selected, then the text names Station and says Harbour sold none")
    func harbourDayWithNoMocha() {
        let model = DashboardModel()
        model.selectDay(noMochaDay)
        model.selectDrink("Mocha")
        let summary = model.summary(locale: locale)
        #expect(summary.totalText == "56 cups")
        #expect(summary.busiestCafe == "Station, 56 cups")
        #expect(summary.change == "29 cups fewer than Tuesday, March 10.")
        #expect(model.headline(locale: locale) == """
        On Tuesday, March 17, Harbour and Station sold 56 cups of Mocha. Station sold the most: 56 cups. Harbour sold none.
        """)
        let point = model.dayPoints.first { $0.day == noMochaDay }
        #expect(point?.values == [
            DashboardSeriesValue(series: "Harbour", cups: 0),
            DashboardSeriesValue(series: "Station", cups: 56),
        ])
    }

    @Test("Given a day and a drink, when the selection is cleared, then both are cleared and the headline covers the four weeks")
    func clearingTheSelection() {
        let model = DashboardModel()
        model.selectDay(noMochaDay)
        model.selectDrink("Latte")
        #expect(model.hasSelection)
        model.clearSelection()
        #expect(!model.hasSelection)
        #expect(model.headline(locale: locale).hasPrefix("From March 1 to March 28"))
    }

    @Test("Given a selection, when the summary is read, then its figures are the sums of what the panels draw")
    func summaryAgreesWithPanels() {
        let model = DashboardModel()
        let wednesday = CafeData.day(17)
        model.selectDay(wednesday)
        // March 18: 426 cups, drawn as Latte 215 + Tea 114 + Mocha 97 in the drink mix,
        // and Harbour 210 + Station 216 on the per-day chart.
        #expect(model.selectionTotal == 426)
        #expect(model.drinkBars.map(\.cups).reduce(0, +) == model.selectionTotal)
        let day = model.dayPoints.first { $0.day == wednesday }
        #expect(day?.values.map(\.cups).reduce(0, +) == model.selectionTotal)
        model.breakdown = .drink
        let drinks = model.dayPoints.first { $0.day == wednesday }
        #expect(drinks?.values.map(\.cups) == model.drinkBars.map(\.cups))
        // With a drink selected the café lines count that drink, and they sum to the summary's total.
        model.breakdown = .cafe
        model.selectDrink("Tea")
        let tea = model.dayPoints.first { $0.day == wednesday }
        #expect(tea?.values.map(\.cups).reduce(0, +) == model.summary(locale: locale).total)
        #expect(model.summary(locale: locale).total == model.drinkBars.first { $0.drink == "Tea" }?.cups)
    }

    @Test("Given cafés and drinks that tie, when the summary and headline are read, then every one sharing the top is named")
    func ties() {
        let day = CafeData.day(0)
        let sales = [
            DashboardSale(day: day, store: CafeWording.harbour, drink: "Latte", cups: 60),
            DashboardSale(day: day, store: CafeWording.harbour, drink: "Tea", cups: 60),
            DashboardSale(day: day, store: CafeWording.harbour, drink: "Mocha", cups: 0),
            DashboardSale(day: day, store: CafeWording.station, drink: "Latte", cups: 40),
            DashboardSale(day: day, store: CafeWording.station, drink: "Tea", cups: 40),
            DashboardSale(day: day, store: CafeWording.station, drink: "Mocha", cups: 40),
        ]
        let model = DashboardModel(sales: sales)
        let summary = model.summary(locale: locale)
        #expect(summary.busiestCafe == "Harbour and Station, 120 cups each")
        #expect(summary.busiestDrink == "Latte and Tea, 100 cups each")
        #expect(model.headline(locale: locale) == """
        From March 1 to March 1, Harbour and Station sold 240 cups. Harbour and Station sold the same: 120 cups each. \
        Latte and Tea sold the same: 100 cups each.
        """)
    }

    @Test("Given a selected day and drink, when the elements are read, then the selected day, bar and heat cells say selected")
    func selectionIsSpoken() {
        let model = DashboardModel()
        let wednesday = CafeData.day(17)
        let point = model.dayPoints[17]
        #expect(model.dayPointValue(point, locale: locale) == "Harbour, 210 cups; Station, 216 cups")
        model.selectDay(wednesday)
        model.selectDrink("Mocha")
        #expect(model.dayPointValue(model.dayPoints[17], locale: locale) == "Harbour, 37 cups; Station, 60 cups; selected")
        #expect(model.dayPointValue(model.dayPoints[16], locale: locale) == "Harbour, 0 cups; Station, 56 cups")
        let mocha = model.drinkBars[2]
        #expect(model.drinkBarValue(mocha, locale: locale) == "97 cups, selected")
        #expect(model.drinkBarValue(model.drinkBars[0], locale: locale) == "215 cups")
        let cells = model.heatCells
        let selected = cells.filter { model.heatCellValue($0, locale: locale).hasSuffix(", selected") }
        #expect(selected.map(\.weekday) == ["Wed", "Wed"])
        // With drinks as rows, the selected drink's row says it too, and is the row outlined.
        model.breakdown = .drink
        #expect(model.selectedHeatRow == "Mocha")
        let drinkRows = model.heatCells.filter { model.heatCellValue($0, locale: locale).hasSuffix(", selected") }
        #expect(drinkRows.count == 3 + 7 - 1)
    }

    // MARK: Breakdown

    @Test("Given the café breakdown, when the per-day series are read, then there is one per café, counted for the selected drink")
    func cafeBreakdown() {
        let model = DashboardModel()
        model.selectDrink("Tea")
        #expect(model.seriesNames == ["Harbour", "Station"])
        #expect(model.emphasisedSeries == ["Harbour", "Station"])
        #expect(model.cupsPerDaySubtitle() == "By café, Tea only")
        let firstDay = model.dayPoints[0]
        #expect(firstDay.values.map(\.cups) == [
            model.cups(store: "Harbour", drink: "Tea", day: firstDay.day),
            model.cups(store: "Station", drink: "Tea", day: firstDay.day),
        ])
        #expect(model.heatCells.count == 14)
    }

    @Test("Given the drink breakdown, when the per-day series are read, then there is one per drink at both cafés, the selected one emphasised")
    func drinkBreakdown() {
        let model = DashboardModel()
        model.breakdown = .drink
        model.selectDrink("Mocha")
        #expect(model.seriesNames == ["Latte", "Tea", "Mocha"])
        #expect(model.emphasisedSeries == ["Mocha"])
        #expect(model.cupsPerDaySubtitle() == "By drink")
        #expect(model.selectedHeatRow == "Mocha")
        let total = model.dayPoints.flatMap(\.values).map(\.cups).reduce(0, +)
        #expect(total == 11216)
        #expect(model.heatCells.count == 21)
    }

    @Test("Given each breakdown, when the per-day chart's identity is read, then it changes with the breakdown and the drink, not the day")
    func identities() {
        let model = DashboardModel()
        let cafe = model.cupsPerDayIdentity
        model.selectDay(noMochaDay)
        #expect(model.cupsPerDayIdentity == cafe)
        model.breakdown = .drink
        #expect(model.cupsPerDayIdentity != cafe)
        let drinkMix = model.drinkMixIdentity
        model.selectDay(nil)
        #expect(model.drinkMixIdentity != drinkMix)
    }

    // MARK: Weekday rhythm

    @Test("Given the café breakdown, when the weekday cells are read, then each is the average of that weekday's four days")
    func weekdayAverages() {
        let model = DashboardModel()
        let tuesdays = model.days.filter { model.weekdayIndex(of: $0) == 1 }
        #expect(tuesdays.count == 4)
        let expected = Double(tuesdays.map { model.cups(store: "Harbour", day: $0) }.reduce(0, +)) / 4
        let cell = model.heatCells.first { $0.weekday == "Tue" && $0.series == "Harbour" }
        #expect(cell?.averageCups == expected)
        #expect(model.weekdayName("Tue", locale: locale) == "Tuesday")
        if let cell {
            #expect(model.heatCellLabel(cell, locale: locale) == "Tuesday, Harbour")
            #expect(model.heatCellValue(cell, locale: locale) == "\(CafeWording.cups(cell.roundedCups, locale: locale)) on average")
        }
    }

    // MARK: Element text and announcements

    @Test("Given the café breakdown, when a day's element is read, then it names the day and each café with its cups")
    func dayElementText() {
        let model = DashboardModel()
        let point = model.dayPoints[CafeData.dashboardNoMochaOffset]
        #expect(model.dayPointLabel(point, locale: locale) == "Tuesday, March 17")
        #expect(model.dayPointValue(point, locale: locale) == "Harbour, 194 cups; Station, 202 cups")
    }

    @Test("Given each change, when it is announced, then the sentence says what changed and then the headline")
    func announcements() {
        let model = DashboardModel()
        model.selectDay(noMochaDay)
        #expect(model.announcement(for: .day, locale: locale).hasPrefix("Showing Tuesday, March 17. On Tuesday, March 17,"))
        model.selectDrink("Mocha")
        #expect(model.announcement(for: .drink, locale: locale).hasPrefix("Showing Mocha only. On Tuesday"))
        model.breakdown = .drink
        #expect(model.announcement(for: .breakdown, locale: locale).hasPrefix("Cups per day by drink. On Tuesday"))
        model.clearSelection()
        #expect(model.announcement(for: .clear, locale: locale).hasPrefix("Showing every day and every drink. From March 1"))
        #expect(model.announcement(for: .day, locale: locale).hasPrefix("Showing every day. From March 1"))
        #expect(model.announcement(for: .drink, locale: locale).hasPrefix("Showing every drink. From March 1"))
    }

    @Test("Given a day and a drink, when the selection is cleared, then one change is recorded, so one announcement is posted")
    func clearIsOneAction() {
        let model = DashboardModel()
        model.selectDay(noMochaDay)
        #expect(model.lastSelectionChange == .day)
        model.selectDrink("Mocha")
        #expect(model.lastSelectionChange == .drink)
        let count = model.selectionChangeCount
        model.clearSelection()
        #expect(model.selectionChangeCount == count + 1)
        #expect(model.lastSelectionChange == .clear)
        // Choosing what is already chosen, or clearing nothing, changes nothing and says nothing.
        model.clearSelection()
        model.selectDay(nil)
        model.selectDrink(nil)
        #expect(model.selectionChangeCount == count + 1)
    }

    @Test("Given every selection, when the longest headline is worked out, then no headline is longer, and it is not changed by the selection")
    func longestHeadline() {
        let model = DashboardModel()
        let longest = model.longestHeadline(locale: locale)
        model.selectDay(noMochaDay)
        model.selectDrink("Mocha")
        #expect(model.headline(locale: locale).count <= longest.count)
        #expect(model.longestHeadline(locale: locale) == longest)
        model.clearSelection()
        #expect(model.headline(locale: locale).count <= longest.count)
    }

    // MARK: Empty and zero

    @Test("Given no data, when the model is read, then the headline says so and the domains keep one step")
    func emptyData() {
        let model = DashboardModel(sales: [])
        #expect(model.isEmpty)
        #expect(model.headline(locale: locale) == "There are no sales to show.")
        #expect(model.cupsDomain == 0 ... 50)
        #expect(model.summary(locale: locale).busiestCafe == "None sold")
    }

    @Test("Given a day of zeros at every café, when the headline is read, then it names no busiest café")
    func allZeroDay() {
        let day = CafeData.day(0)
        let sales = ["Harbour", "Station"].flatMap { store in
            CafeDrinkStyle.drinks.map { DashboardSale(day: day, store: store, drink: $0, cups: 0) }
        }
        let model = DashboardModel(sales: sales)
        #expect(model.headline(locale: locale) == "From March 1 to March 1, Harbour and Station sold 0 cups.")
        #expect(model.summary(locale: locale).busiestDrink == "None sold")
        #expect(model.summary(locale: locale).busiestCafe == "None sold")
    }
}
