import Foundation
@testable import SwiftChartsCatalog
import Testing

struct CafeDataTests {
    @Test("Given the large order set, when the same count is asked for twice, then the orders are the same and the earlier ones do not depend on the count")
    func manyOrdersAreDeterministic() {
        let first = CafeData.manyOrders(count: 5000)

        #expect(first == CafeData.manyOrders(count: 5000))
        #expect(Array(CafeData.manyOrders(count: 20000).prefix(5000)) == first)
        #expect(Set(first.map(\.id)).count == first.count)
    }

    @Test("Given the large order set, when a count outside its range is asked for, then it gives none below zero and at most the maximum above")
    func manyOrdersAreBounded() {
        #expect(CafeData.manyOrders(count: -1).isEmpty)
        #expect(CafeData.manyOrders(count: CafeData.manyOrdersMaximum + 1).count == CafeData.manyOrdersMaximum)
    }

    @Test("Given the large order set, when it is read, then every value is in range, every drink appears, and the drinks are not already grouped")
    func manyOrdersAreUsable() {
        let orders = CafeData.manyOrders(count: 2000)

        #expect(orders.allSatisfy { (6 ..< 18).contains($0.hour) && (1 ... 4).contains($0.cups) && $0.waitMinutes >= 0.5 })
        #expect(Set(orders.map(\.drink)) == Set(CafeData.manyOrderDrinks))
        let changes = zip(orders, orders.dropFirst()).count(where: { $0.drink != $1.drink })
        #expect(changes > orders.count / 2)
    }

    @Test("Given an order, when its stored minutes per cup is read, then it equals the wait divided by the cups")
    func minutesPerCupIsStoredCorrectly() {
        for order in CafeData.manyOrders(count: 500) {
            #expect(abs(order.minutesPerCup - order.waitMinutes / Double(order.cups)) < 1e-12)
        }
    }

    @Test("Given the drink sales, when they are read, then there are several, each with a name and a positive count, and no name repeats")
    func drinkSalesAreUsable() {
        let sales = CafeData.drinkSales

        #expect(sales.count >= 3)
        #expect(sales.allSatisfy { !$0.drink.isEmpty && $0.cups > 0 })
        #expect(Set(sales.map(\.id)).count == sales.count)
    }

    @Test("Given the sample calendar, when a day offset is asked for, then it is that many days after 1 March 2026 in UTC")
    func daysAreFixed() {
        let components = CafeData.calendar.dateComponents([.year, .month, .day, .hour], from: CafeData.day(31))

        #expect(components.year == 2026)
        #expect(components.month == 4)
        #expect(components.day == 1)
        #expect(components.hour == 0)
    }

    @Test("Given the two cafés' daily sales, when they are read, then each has the same 28 consecutive days and positive counts")
    func storeSalesAlign() {
        let stores = CafeData.storeSales

        #expect(stores.map(\.store) == ["Harbour", "Station"])
        for store in stores {
            #expect(store.days.count == 28)
            #expect(store.days.allSatisfy { $0.cups > 0 })
            #expect(store.days.map(\.day) == (0 ..< 28).map(CafeData.day))
        }
        #expect(CafeData.harbourSales == stores[0].days)
    }

    @Test("Given the drink orders, when they are grouped, then every drink has the same three sizes in the same order and ids are unique")
    func drinkOrdersAreComplete() {
        let orders = CafeData.drinkOrders
        let byDrink = Dictionary(grouping: orders, by: \.drink)

        #expect(byDrink.count == 3)
        #expect(byDrink.values.allSatisfy { $0.map(\.size) == ["Small", "Medium", "Large"] })
        #expect(Set(orders.map(\.id)).count == orders.count)
    }

    @Test("Given the monthly summaries, when they are read, then there are six consecutive months, each with low below average below high")
    func monthlySummariesAreOrdered() {
        let months = CafeData.monthlySummaries

        #expect(months.count == 6)
        #expect(months.map(\.month) == (0 ..< 6).map(CafeData.month))
        #expect(months.allSatisfy { $0.lowestDay < $0.averageDay && $0.averageDay < $0.highestDay })
    }

    @Test("Given the monthly summaries, when March is compared with the Harbour café's 28 days, then its lowest, highest and rounded average are theirs")
    func marchAgreesWithTheDailyData() throws {
        let march = try #require(CafeData.monthlySummaries.first)
        let cups = CafeData.harbourSales.map(\.cups)
        let average = Double(cups.reduce(0, +)) / Double(cups.count)

        #expect(march.lowestDay == cups.min())
        #expect(march.highestDay == cups.max())
        #expect(march.averageDay == Int(average.rounded()))
        let figures = [march.lowestDay, march.highestDay, march.averageDay]
        #expect(figures == [152, 282, 205])
    }

    @Test("Given the monthly summaries, when April to August are read, then each keeps its difference from March")
    func laterMonthsFollowMarch() {
        let months = CafeData.monthlySummaries

        #expect(months.map(\.lowestDay) == [152, 160, 165, 174, 171, 163])
        #expect(months.map(\.highestDay) == [282, 297, 314, 336, 347, 320])
        #expect(months.map(\.averageDay) == [205, 218, 230, 246, 253, 235])
    }

    @Test("Given the quarterly changes, when they are read, then both cafés have all four quarters and there are rises and falls")
    func quarterlyChangesDiverge() {
        let changes = CafeData.quarterlyChanges

        #expect(changes.count == 8)
        #expect(Set(changes.map(\.id)).count == 8)
        #expect(changes.contains { $0.change < 0 })
        #expect(changes.contains { $0.change > 0 })
    }

    @Test("Given the order waits, when they are read, then each café has twenty orders with positive waits and unique ids")
    func orderWaits() {
        let waits = CafeData.orderWaits
        #expect(Set(waits.map(\.id)).count == 40)
        #expect(waits.count { $0.store == "Harbour" } == 20)
        #expect(waits.count { $0.store == "Station" } == 20)
        #expect(waits.allSatisfy { $0.waitSeconds > 0 && $0.queueLength >= 0 })
        #expect(Set(waits.map(\.queueLength)).count > 6)
    }

    @Test("Given the hourly orders, when they are read, then every weekday has every slot once and orders are positive")
    func hourlyOrders() {
        let orders = CafeData.hourlyOrders
        #expect(orders.count == CafeData.weekdays.count * CafeData.slots.count)
        #expect(Set(orders.map(\.id)).count == orders.count)
        #expect(orders.allSatisfy { $0.orders > 0 })
    }

    @Test("Given the ten weeks, when they are read, then there are seventy consecutive days starting on a Sunday")
    func tenWeeks() {
        let days = CafeData.tenWeeks
        #expect(days.count == 70)
        #expect(CafeData.calendar.component(.weekday, from: days[0].day) == 1)
        #expect(zip(days, days.dropFirst()).allSatisfy { CafeData.calendar.dateComponents([.day], from: $0.day, to: $1.day).day == 1 })
    }

    @Test("Given the ten weeks and the Harbour café's four, when March is compared, then the first 28 days are the same days")
    func tenWeeksStartWithHarbourSales() {
        #expect(Array(CafeData.tenWeeks.prefix(28)) == CafeData.harbourSales)
        #expect(CafeData.tenWeeks[0].cups == 190)
    }

    @Test("Given the shifts, when they are read, then each ends after it starts and one barista has two")
    func shifts() {
        let shifts = CafeData.shifts
        #expect(shifts.allSatisfy { $0.end > $0.start })
        #expect(shifts.count { $0.barista == "Mia" } == 2)
        #expect(Set(shifts.map(\.id)).count == shifts.count)
    }

    @Test("Given the wait quartiles, when they are read, then each café's five numbers are in order")
    func waitQuartiles() {
        #expect(CafeData.waitQuartiles.count == 2)
        #expect(CafeData.waitQuartiles.allSatisfy {
            $0.minimum < $0.lowerQuartile && $0.lowerQuartile < $0.median
                && $0.median < $0.upperQuartile && $0.upperQuartile < $0.maximum
        })
    }

    @Test("Given the forty order waits, when the box plot's numbers are read, then they are worked out from those orders")
    func waitQuartilesComeFromOrderWaits() throws {
        for quartiles in CafeData.waitQuartiles {
            let waits = CafeData.orderWaits.filter { $0.store == quartiles.store }.map { Double($0.waitSeconds) }.sorted()
            #expect(quartiles.minimum == waits.first)
            #expect(quartiles.maximum == waits.last)
            #expect(quartiles.median == (waits[9] + waits[10]) / 2)
            #expect(quartiles.lowerQuartile == (waits[4] + waits[5]) / 2)
            #expect(quartiles.upperQuartile == (waits[14] + waits[15]) / 2)
        }
        let station = try #require(CafeData.waitQuartiles.last)
        #expect([station.minimum, station.lowerQuartile, station.median, station.upperQuartile, station.maximum] == [74, 120.5, 178, 252.5, 309])
    }

    @Test("Given an odd number of waits, or none, when the five numbers are worked out, then the middle wait is the median and belongs to neither half")
    func quartilesOfOddAndEmpty() {
        let odd = WaitQuartiles(store: "A", waits: [5, 1, 3, 9, 7])
        #expect([odd.minimum, odd.lowerQuartile, odd.median, odd.upperQuartile, odd.maximum] == [1, 2, 5, 8, 9])
        let none = WaitQuartiles(store: "A", waits: [])
        #expect(none.maximum == 0 && none.median == 0)
    }

    @Test("Given the visits by age group, when they are read, then both cafés have every group")
    func ageGroupVisits() {
        let visits = CafeData.ageGroupVisits
        #expect(visits.count == CafeData.ageGroups.count * 2)
        #expect(Set(visits.map(\.id)).count == visits.count)
        #expect(visits.allSatisfy { $0.visits > 0 })
    }

    @Test("Given the weekly prices, when they are read, then each week's open and close lie within its low and high, with rises and falls")
    func weeklyPrices() {
        let prices = CafeData.weeklyPrices
        #expect(prices.count == 12)
        #expect(prices.allSatisfy { $0.low <= min($0.open, $0.close) && max($0.open, $0.close) <= $0.high })
        #expect(prices.contains { $0.close > $0.open })
        #expect(prices.contains { $0.close < $0.open })
    }

    @Test("Given the drink changes, when they are read, then there are rises and falls and no drink twice")
    func drinkChanges() {
        let changes = CafeData.drinkChanges
        #expect(Set(changes.map(\.drink)).count == changes.count)
        #expect(changes.contains { $0.change > 0 })
        #expect(changes.contains { $0.change < 0 })
    }

    @Test("Given the airflow, when it is read, then there are twenty spots with directions within a turn and positive speeds")
    func airflow() {
        let airflow = CafeData.airflow
        #expect(airflow.count == 20)
        #expect(airflow.allSatisfy { (0 ..< 360).contains($0.direction) && $0.speed > 0 })
    }

    @Test("Given the half-hour orders, when they are read, then there are twenty-four consecutive half hours from 6 am with orders")
    func halfHourOrders() {
        let slots = CafeData.halfHourOrders
        #expect(slots.count == 24)
        #expect(slots.first?.start == CafeData.time(6))
        #expect(zip(slots, slots.dropFirst()).allSatisfy { $1.start.timeIntervalSince($0.start) == 1800 })
        #expect(slots.allSatisfy { $0.orders > 0 })
    }

    @Test("Given the service periods, when they are read, then they cover 6 am to 6 pm without gaps, on half hours, in uneven lengths")
    func servicePeriods() {
        let periods = CafeData.servicePeriods
        #expect(periods.first?.start == CafeData.time(6))
        #expect(periods.last?.end == CafeData.time(18))
        #expect(zip(periods, periods.dropFirst()).allSatisfy { $0.end == $1.start })
        #expect(periods.allSatisfy { Int($0.end.timeIntervalSince($0.start)).isMultiple(of: 1800) })
        #expect(Set(periods.map { $0.end.timeIntervalSince($0.start) }).count > 2)
    }

    @Test("Given the chain, when it is read, then ten cafés span more than three orders of magnitude and the change crosses zero on both sides")
    func chainCafes() {
        let cafes = CafeData.chainCafes
        #expect(cafes.count == 10)
        #expect(Set(cafes.map(\.name)).count == cafes.count)
        let cups = cafes.map(\.yearlyCups)
        #expect((cups.min() ?? 0) > 0)
        #expect(Double(cups.max() ?? 0) / Double(cups.min() ?? 1) > 1000)
        #expect(cafes.contains { $0.change < -10000 } && cafes.contains { $0.change > 10000 })
        #expect(cafes.contains { abs($0.change) < 100 })
    }

    @Test("Given the monthly drink trends, when they are read, then each drink has twelve months in order and every count is positive")
    func monthlyDrinkTrendsAreUsable() {
        for drink in CafeData.trendDrinks {
            let months = CafeData.monthlyDrinkTrends.filter { $0.drink == drink }
            #expect(months.count == 12)
            #expect(months.map(\.month) == (0 ..< 12).map(CafeData.month))
            #expect(months.allSatisfy { $0.cups > 0 })
        }
        #expect(Set(CafeData.monthlyDrinkTrends.map(\.id)).count == CafeData.monthlyDrinkTrends.count)
    }

    @Test("Given the thirty days and their real twin, when they are compared, then the real days have zero Mondays, one day missing and one festival day far above the rest")
    func realThirtyDaysDifferFromInvented() {
        let invented = CafeData.thirtyDays
        let real = CafeData.thirtyDaysReal
        #expect(invented.count == 30)
        #expect(invented.allSatisfy { $0.cups > 0 })
        #expect(real.count == 29)
        #expect(!real.contains { $0.day == CafeData.day(CafeData.thirtyDaysMissingOffset) })
        let mondays = real.filter { CafeData.calendar.component(.weekday, from: $0.day) == 2 }
        #expect(!mondays.isEmpty && mondays.allSatisfy { $0.cups == 0 })
        let festival = real.first { $0.day == CafeData.day(CafeData.thirtyDaysFestivalOffset) }
        let others = real.filter { $0.day != festival?.day }.map(\.cups)
        #expect((festival?.cups ?? 0) > 2 * (others.max() ?? 0))
    }

    @Test("Given the seats filled, when they are read, then each day has twelve hourly percentages between 35 and 92 starting at 7 am")
    func seatsFilledAreUsable() {
        for day in CafeData.seatsFilled {
            #expect(day.readings.count == 12)
            #expect(day.readings.first?.start == CafeData.time(7))
            #expect(day.hours.allSatisfy { (35 ... 92).contains($0) })
        }
        let all = CafeData.seatsFilled.flatMap(\.hours)
        #expect(all.min() == 35 && all.max() == 92)
    }

    @Test("Given the bean tastings, when they are read, then each origin has twenty samples, every score is from 0 to 10, and the origins sit apart in acidity and body")
    func beanTastingsAreUsable() {
        let tastings = CafeData.beanTastings
        #expect(tastings.count == 60)
        #expect(Set(tastings.map(\.id)).count == 60)
        #expect(tastings.allSatisfy { [$0.acidity, $0.body, $0.sweetness].allSatisfy { (0 ... 10).contains($0) } })
        let mean = { (origin: String, value: (BeanTasting) -> Double) -> Double in
            let samples = tastings.filter { $0.origin == origin }
            return samples.map(value).reduce(0, +) / Double(samples.count)
        }
        for origin in CafeData.beanOrigins {
            #expect(tastings.count { $0.origin == origin } == 20)
        }
        #expect(mean("Ethiopia", \.acidity) > mean("Colombia", \.acidity) + 1.5)
        #expect(mean("Colombia", \.acidity) > mean("Sumatra", \.acidity) + 1.5)
        #expect(mean("Sumatra", \.body) > mean("Colombia", \.body) + 1.5)
    }

    @Test("Given the bean tastings, when sweetness is compared with body, then it rises with body across all samples")
    func beanSweetnessRisesWithBody() {
        let tastings = CafeData.beanTastings
        let meanBody = tastings.map(\.body).reduce(0, +) / 60
        let meanSweet = tastings.map(\.sweetness).reduce(0, +) / 60
        let covariance = tastings.map { ($0.body - meanBody) * ($0.sweetness - meanSweet) }.reduce(0, +)
        let bodySpread = tastings.map { pow($0.body - meanBody, 2) }.reduce(0, +)
        let sweetSpread = tastings.map { pow($0.sweetness - meanSweet, 2) }.reduce(0, +)
        #expect(covariance / (bodySpread * sweetSpread).squareRoot() > 0.9)
    }

    // MARK: The dashboard's data

    @Test("Given the dashboard's sales, when each café's day is summed, then it equals that café's storeSales figure")
    func dashboardTotalsAgreeWithStoreSales() {
        for store in CafeData.storeSales {
            for daily in store.days {
                let cups = CafeData.dashboardSales.filter { $0.store == store.store && $0.day == daily.day }
                #expect(cups.count == CafeData.trendDrinks.count)
                #expect(cups.map(\.cups).reduce(0, +) == daily.cups)
            }
        }
    }

    @Test("Given the dashboard's sales, when they are read, then every record is unique, no count is negative, and only the chocolate day has no mocha")
    func dashboardSalesAreUsable() {
        let sales = CafeData.dashboardSales
        #expect(sales.count == 2 * 28 * 3)
        #expect(Set(sales.map(\.id)).count == sales.count)
        #expect(sales.allSatisfy { $0.cups >= 0 })
        let empty = sales.filter { $0.cups == 0 }
        #expect(empty.count == 1)
        #expect(empty.first?.store == CafeWording.harbour)
        #expect(empty.first?.drink == "Mocha")
        #expect(empty.first?.day == CafeData.day(CafeData.dashboardNoMochaOffset))
    }

    @Test("Given the dashboard's sales, when the mix is compared, then Harbour sells more tea than Station and Station more mocha than Harbour")
    func dashboardMixDiffersByCafe() {
        func total(_ store: String, _ drink: String) -> Int {
            CafeData.dashboardSales.filter { $0.store == store && $0.drink == drink }.map(\.cups).reduce(0, +)
        }
        #expect(total(CafeWording.harbour, "Tea") > total(CafeWording.station, "Tea"))
        #expect(total(CafeWording.station, "Mocha") > total(CafeWording.harbour, "Mocha"))
    }

    @Test("Given the dashboard's sales, when each day's drinks are totalled across both cafés, then latte leads tea and tea leads mocha by at least 10 cups")
    func dashboardDrinkLinesStayApart() {
        for daily in CafeData.storeSales[0].days {
            let cups = CafeData.trendDrinks.map { drink in
                CafeData.dashboardSales.filter { $0.day == daily.day && $0.drink == drink }.map(\.cups).reduce(0, +)
            }
            #expect(cups[0] > cups[1])
            // Closer than this, the tea and mocha lines of a per-day chart lie on top of each other.
            #expect(cups[1] - cups[2] >= 10)
        }
    }
}
