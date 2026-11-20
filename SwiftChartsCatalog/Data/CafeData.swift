import Foundation

/// The sample data every screen draws on: a small chain of cafés. The values are fixed, so a chart
/// looks the same on every launch and tests can rely on them.
nonisolated enum CafeData {
    /// A fixed calendar and time zone, so dates in the sample data do not depend on the device.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .gmt
        return calendar
    }()

    /// The first day of the sample data: 1 March 2026.
    static let firstDay: Date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)) ?? .distantPast

    /// The day `offset` days after `firstDay`.
    static func day(_ offset: Int) -> Date {
        calendar.date(byAdding: .day, value: offset, to: firstDay) ?? firstDay
    }

    /// Cups sold today, by drink, at the Harbour café.
    static let drinkSales: [DrinkSales] = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Mocha", cups: 92),
        DrinkSales(drink: "Cocoa", cups: 57),
        DrinkSales(drink: "Americano", cups: 110),
    ]

    /// The first day of the month `offset` months after March 2026.
    static func month(_ offset: Int) -> Date {
        calendar.date(byAdding: .month, value: offset, to: firstDay) ?? firstDay
    }

    /// Daily cups for a café from 1 March, four weeks unless `days` says otherwise: a base, a weekly rhythm with
    /// busier weekends, and steady growth.
    static func dailySales(base: Int, growth: Int, weekendLift: Int, days: Int = 28) -> [DailySales] {
        (0 ..< days).map { offset in
            let weekday = calendar.component(.weekday, from: day(offset))
            let isWeekend = weekday == 1 || weekday == 7
            let rhythm = [0, 6, -4, 9, -7, 3, 11][offset % 7]
            return DailySales(day: day(offset), cups: base + offset * growth + rhythm + (isWeekend ? weekendLift : 0))
        }
    }

    /// How the Harbour café's days are made, shared by `harbourSales` and `tenWeeks` so the two agree.
    private static func harbourDays(_ days: Int) -> [DailySales] {
        dailySales(base: 150, growth: 3, weekendLift: 40, days: days)
    }

    /// Daily cups at the two cafés, 1 to 28 March 2026.
    static let storeSales: [StoreSales] = [
        StoreSales(store: "Harbour", days: harbourDays(28)),
        StoreSales(store: "Station", days: dailySales(base: 190, growth: 1, weekendLift: -35)),
    ]

    /// The Harbour café's four weeks, for screens that need one series.
    static let harbourSales: [DailySales] = storeSales[0].days

    /// Cups sold today by drink and size. Every drink has every size, in the same order.
    static let drinkOrders: [DrinkOrder] = [
        DrinkOrder(drink: "Latte", size: "Small", cups: 34), DrinkOrder(drink: "Latte", size: "Medium", cups: 58),
        DrinkOrder(drink: "Latte", size: "Large", cups: 36), DrinkOrder(drink: "Tea", size: "Small", cups: 71),
        DrinkOrder(drink: "Tea", size: "Medium", cups: 62), DrinkOrder(drink: "Tea", size: "Large", cups: 31),
        DrinkOrder(drink: "Mocha", size: "Small", cups: 22), DrinkOrder(drink: "Mocha", size: "Medium", cups: 41),
        DrinkOrder(drink: "Mocha", size: "Large", cups: 29),
    ]

    /// Six months of daily lows, highs and averages at the Harbour café, March to August 2026.
    ///
    /// March is worked out from `harbourSales`, the same 28 days every other screen draws for March, so the two
    /// cannot disagree: its quietest and busiest day, and its average to the nearest whole cup, rounded as the
    /// screens round it (204.5 is 205). April to August are each March plus a fixed difference, so the shape of the
    /// six months follows March wherever March moves.
    static let monthlySummaries: [MonthlySummary] = {
        let cups = harbourSales.map(\.cups)
        let lowest = cups.min() ?? 0
        let highest = cups.max() ?? 0
        let average = cups.isEmpty ? 0 : Int((Double(cups.reduce(0, +)) / Double(cups.count)).rounded())
        // Each month's difference from March, in cups: lowest day, highest day, average day.
        let differences = [(0, 0, 0), (8, 15, 13), (13, 32, 25), (22, 54, 41), (19, 65, 48), (11, 38, 30)]
        return differences.enumerated().map { index, difference in
            MonthlySummary(
                month: month(index),
                lowestDay: lowest + difference.0,
                highestDay: highest + difference.1,
                averageDay: average + difference.2
            )
        }
    }()

    /// Change in cups against a year before, by quarter and café. Some are falls.
    static let quarterlyChanges: [QuarterlyChange] = [
        QuarterlyChange(quarter: "Q1", store: "Harbour", change: 420), QuarterlyChange(quarter: "Q1", store: "Station", change: -180),
        QuarterlyChange(quarter: "Q2", store: "Harbour", change: 610), QuarterlyChange(quarter: "Q2", store: "Station", change: -90),
        QuarterlyChange(quarter: "Q3", store: "Harbour", change: 380), QuarterlyChange(quarter: "Q3", store: "Station", change: 150),
        QuarterlyChange(quarter: "Q4", store: "Harbour", change: -120), QuarterlyChange(quarter: "Q4", store: "Station", change: 260),
    ]

    /// Forty orders, twenty at each café: the queue when the order was placed and the wait that followed.
    /// Two numbers per order, for scatter plots. Waits grow with the queue, faster at the Station café.
    static let orderWaits: [OrderWait] = (0 ..< 40).map { index in
        let isHarbour = index.isMultiple(of: 2)
        let queue = (index * 7 + 3) % 12
        // A fixed scatter around the trend, the same on every run.
        let scatter = (index * 37 + 11) % 41 - 20
        let wait = (isHarbour ? 60 + queue * 14 : 75 + queue * 22) + scatter
        return OrderWait(id: index, store: isHarbour ? "Harbour" : "Station", queueLength: queue, waitSeconds: wait)
    }

    // MARK: A large set, for vectorized plots

    /// The most orders `manyOrders(count:)` gives.
    static let manyOrdersMaximum = 20000

    /// The drinks in `manyOrders(count:)`.
    static let manyOrderDrinks = ["Latte", "Tea", "Mocha", "Espresso"]

    /// A day's worth of orders across the chain, up to `manyOrdersMaximum`, for charts of thousands
    /// of points. Generated from a fixed seed, so the same count gives the same orders on every run.
    /// The drinks come in no order, so a chart can sort them or not. Waits are longer at the
    /// morning and lunch peaks and for bigger orders.
    static func manyOrders(count: Int) -> [CafeOrder] {
        var generator = SeededGenerator(seed: 2026)
        return (0 ..< min(max(count, 0), manyOrdersMaximum)).map { index in
            let hour = 6 + 12 * generator.nextUnit()
            let cups = 1 + Int(generator.nextUnit() * 4)
            let drink = manyOrderDrinks[Int(generator.nextUnit() * Double(manyOrderDrinks.count))]
            // Busier near 8 am and 12:30 pm.
            let rush = 3 * exp(-pow(hour - 8, 2) / 2) + 2.5 * exp(-pow(hour - 12.5, 2) / 1.5)
            // The sum of three uniform numbers, centred on zero: a bell-shaped scatter.
            let scatter = (generator.nextUnit() + generator.nextUnit() + generator.nextUnit() - 1.5) * 2
            let wait = max(0.5, 2 + rush + 0.6 * Double(cups) + scatter)
            return CafeOrder(id: index, drink: drink, hour: hour, cups: cups, waitMinutes: wait)
        }
    }

    // MARK: Data for the chart forms

    static let weekdays = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    static let slots = ["6 am", "8 am", "10 am", "12 pm", "2 pm", "4 pm"]

    /// Orders by weekday and two-hour slot: busiest on weekday mornings and weekend middays.
    static let hourlyOrders: [HourlyOrders] = weekdays.enumerated().flatMap { dayIndex, weekday in
        slots.enumerated().map { slotIndex, slot in
            let isWeekend = dayIndex >= 5
            let peak = isWeekend ? 3 : 1
            let distance = abs(slotIndex - peak)
            let orders = max(4, (isWeekend ? 58 : 72) - distance * 17 + (dayIndex * 5 + slotIndex * 3) % 11)
            return HourlyOrders(weekday: weekday, slot: slot, orders: orders)
        }
    }

    /// Ten weeks of daily cups at the Harbour café, from 1 March 2026, a Sunday: `harbourSales` carried on for six
    /// more weeks, so its first 28 days are the ones every other screen draws for March.
    static let tenWeeks: [DailySales] = harbourDays(70)

    /// The time `hour` and `minute` on the first day, for shifts.
    static func time(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: firstDay) ?? firstDay
    }

    /// One day's shifts. Mia works a split shift, so her row has two bars.
    static let shifts: [Shift] = [
        Shift(id: 0, barista: "Ana", start: time(6), end: time(12)),
        Shift(id: 1, barista: "Ben", start: time(7, 30), end: time(14)),
        Shift(id: 2, barista: "Mia", start: time(6), end: time(9, 30)),
        Shift(id: 3, barista: "Mia", start: time(13), end: time(18)),
        Shift(id: 4, barista: "Tom", start: time(11), end: time(18)),
    ]

    /// Waits at each café, in seconds, as the five numbers of a box plot: worked out from `orderWaits`, so the box
    /// plot describes the same orders the scatter plots draw. Harbour: 59, 103, 143.5, 183.5, 214; Station: 74,
    /// 120.5, 178, 252.5, 309.
    static let waitQuartiles: [WaitQuartiles] = ["Harbour", "Station"].map { store in
        WaitQuartiles(store: store, waits: orderWaits.filter { $0.store == store }.map { Double($0.waitSeconds) })
    }

    static let ageGroups = ["Under 18", "18 to 29", "30 to 44", "45 to 59", "60 and over"]

    /// A month's visits by age group at each café.
    static let ageGroupVisits: [AgeGroupVisits] = zip(ageGroups, [(310, 180), (1240, 1620), (1480, 1310), (920, 640), (560, 270)])
        .flatMap { group, visits in
            [
                AgeGroupVisits(ageGroup: group, store: "Harbour", visits: visits.0),
                AgeGroupVisits(ageGroup: group, store: "Station", visits: visits.1),
            ]
        }

    /// Twelve weeks of the bean price: some weeks close higher than they opened and some lower.
    static let weeklyPrices: [WeeklyPrice] = [
        (11.2, 11.9, 11.0, 11.7), (11.7, 12.1, 11.5, 11.6), (11.6, 11.8, 10.9, 11.0), (11.0, 11.6, 10.8, 11.5),
        (11.5, 12.4, 11.4, 12.3), (12.3, 12.9, 12.0, 12.1), (12.1, 12.2, 11.3, 11.4), (11.4, 11.9, 11.2, 11.8),
        (11.8, 12.6, 11.7, 12.5), (12.5, 13.2, 12.3, 13.0), (13.0, 13.1, 12.2, 12.4), (12.4, 12.8, 12.1, 12.7),
    ].enumerated().map { index, values in
        WeeklyPrice(week: day(index * 7), open: values.0, high: values.1, low: values.2, close: values.3)
    }

    /// Change in cups against last month, by drink. Three rose and three fell.
    static let drinkChanges: [DrinkChange] = [
        DrinkChange(drink: "Latte", change: 212), DrinkChange(drink: "Tea", change: -148),
        DrinkChange(drink: "Mocha", change: 64), DrinkChange(drink: "Cocoa", change: -305),
        DrinkChange(drink: "Americano", change: 131), DrinkChange(drink: "Chai", change: -37),
    ]

    /// Air moving through the café from the door, on a grid of five by four spots.
    static let airflow: [Airflow] = (0 ..< 20).map { index in
        let column = index % 5
        let row = index / 5
        return Airflow(
            id: index, x: Double(column) * 2 + 1, y: Double(row) * 2 + 1,
            direction: Double((40 + column * 22 + row * 31) % 360), speed: 0.2 + Double((index * 7) % 10) / 10
        )
    }

    /// Orders by half hour from 6 am to 6 pm on the first day: a morning rush and a smaller lunch peak.
    static let halfHourOrders: [HalfHourOrders] = (0 ..< 24).map { index in
        let hour = 6 + index / 2, minute = index.isMultiple(of: 2) ? 0 : 30
        let morning = max(0, 46 - abs(index - 4) * 9)
        let lunch = max(0, 30 - abs(index - 12) * 8)
        return HalfHourOrders(start: time(hour, minute), orders: 8 + morning + lunch + (index * 7) % 5)
    }

    /// The café's day in named parts of different lengths, each starting and ending on a half hour.
    static let servicePeriods: [ServicePeriod] = [
        ServicePeriod(name: "Early", start: time(6), end: time(7, 30)),
        ServicePeriod(name: "Morning rush", start: time(7, 30), end: time(9)),
        ServicePeriod(name: "Late morning", start: time(9), end: time(11, 30)),
        ServicePeriod(name: "Lunch", start: time(11, 30), end: time(13, 30)),
        ServicePeriod(name: "Afternoon", start: time(13, 30), end: time(17)),
        ServicePeriod(name: "Close", start: time(17), end: time(18)),
    ]

    /// Ten cafés of a chain, from a kiosk to a flagship: yearly cups span more than three orders of
    /// magnitude, and the change on last year crosses zero, small and large on both sides.
    static let chainCafes: [ChainCafe] = [
        ChainCafe(name: "Kiosk", yearlyCups: 120, change: -40),
        ChainCafe(name: "Pier", yearlyCups: 640, change: 250),
        ChainCafe(name: "Market", yearlyCups: 2400, change: -900),
        ChainCafe(name: "Library", yearlyCups: 5800, change: 1600),
        ChainCafe(name: "Riverside", yearlyCups: 9500, change: -3200),
        ChainCafe(name: "Campus", yearlyCups: 18000, change: 7400),
        ChainCafe(name: "Station", yearlyCups: 71000, change: -12000),
        ChainCafe(name: "Harbour", yearlyCups: 74000, change: 9800),
        ChainCafe(name: "Airport", yearlyCups: 210_000, change: -38000),
        ChainCafe(name: "Central", yearlyCups: 480_000, change: 120_000),
    ]

    // MARK: Data for the design screens

    /// The drinks in `monthlyDrinkTrends`, in the order the charts show them.
    static let trendDrinks = ["Latte", "Tea", "Mocha"]

    /// Cups per drink per month at the Harbour café, March 2026 to February 2027: lattes steady,
    /// tea busiest in summer when it is iced, mocha busiest in winter.
    static let monthlyDrinkTrends: [MonthlyDrinkCups] = zip(trendDrinks, [
        [512, 528, 540, 556, 549, 561, 572, 580, 598, 611, 590, 604],
        [298, 352, 431, 520, 588, 547, 433, 342, 287, 262, 251, 270],
        [244, 198, 151, 118, 102, 121, 176, 268, 391, 472, 455, 380],
    ]).flatMap { drink, cups in
        cups.enumerated().map { index, cups in MonthlyDrinkCups(drink: drink, month: month(index), cups: cups) }
    }

    /// Thirty days of daily cups at the Harbour café from 1 March 2026, a Sunday, as invented data
    /// tends to look: a gentle weekly rhythm and steady growth, every day open.
    static let thirtyDays: [DailySales] = (0 ..< 30).map { offset in
        DailySales(day: day(offset), cups: 150 + offset * 2 + [24, 6, -4, 9, -7, 3, 18][offset % 7])
    }

    /// The day missing from `thirtyDaysReal`: the till was broken and nothing was recorded.
    static let thirtyDaysMissingOffset = 17

    /// The day of the harbour festival in `thirtyDaysReal`, far above every other day.
    static let thirtyDaysFestivalOffset = 20

    /// The same thirty days as the café really traded: closed on Mondays (zero cups), no record for
    /// the day the till was broken, and the harbour festival.
    static let thirtyDaysReal: [DailySales] = thirtyDays.enumerated().compactMap { offset, day in
        if offset == thirtyDaysMissingOffset { return nil }
        if offset % 7 == 1 { return DailySales(day: day.day, cups: 0) }
        if offset == thirtyDaysFestivalOffset { return DailySales(day: day.day, cups: day.cups * 3) }
        return day
    }

    /// The percentage of seats filled each hour from 7 am to 6 pm, on a quiet Tuesday and a busy
    /// Saturday. Every value lies between 35 and 92.
    static let seatsFilled: [SeatsFilledDay] = [
        SeatsFilledDay(name: "Tuesday", hours: [35, 48, 57, 44, 39, 52, 60, 47, 41, 38, 36, 35]),
        SeatsFilledDay(name: "Saturday", hours: [42, 61, 78, 86, 82, 90, 92, 84, 75, 70, 63, 55]),
    ]

    // MARK: Data for the 3D screens

    /// The origins in `beanTastings`, in the order the charts show them.
    static let beanOrigins = ["Ethiopia", "Colombia", "Sumatra"]

    /// Sixty bean samples, twenty from each origin, scored from 0 to 10 for acidity, body and
    /// sweetness by the café's roaster. Each origin forms its own cluster (Ethiopian beans bright
    /// and light, Sumatran heavy and mellow), and across all of them sweetness rises with body, so
    /// one view of the three scores shows the clusters and another shows the trend edge-on.
    static let beanTastings: [BeanTasting] = beanOrigins.enumerated().flatMap { originIndex, origin in
        let centres = [(acidity: 7.8, body: 3.4), (acidity: 5.6, body: 5.4), (acidity: 3.0, body: 7.6)][originIndex]
        return (0 ..< 20).map { index in
            let seed = Double(originIndex * 20 + index)
            let acidity = centres.acidity + 0.9 * sin(seed * 1.7)
            let body = centres.body + 0.9 * cos(seed * 2.3)
            let sweetness = 1.2 + 0.75 * body + 0.35 * sin(seed * 3.1)
            let rounded = { (value: Double) in (min(10, max(0, value)) * 10).rounded() / 10 }
            return BeanTasting(id: originIndex * 20 + index, origin: origin, acidity: rounded(acidity), body: rounded(body), sweetness: rounded(sweetness))
        }
    }

    // MARK: Data for the dashboard

    /// The day in `dashboardSales` when the Harbour café sold no mocha: the chocolate ran out, and those
    /// customers took lattes, so the café's total for the day is unchanged.
    static let dashboardNoMochaOffset = 16

    /// Cups of each drink at each café, 1 to 28 March 2026: `storeSales` split by drink. Each café's daily
    /// total is its `storeSales` figure, so the dashboard agrees with every screen that draws those cafés.
    /// The mix differs by café and by day: Harbour sells more tea at weekends, Station more mocha on
    /// weekdays, when commuters pass through.
    static let dashboardSales: [DashboardSale] = storeSales.flatMap { store in
        store.days.enumerated().flatMap { offset, daily in
            let weekday = calendar.component(.weekday, from: daily.day)
            let isWeekend = weekday == 1 || weekday == 7
            let isHarbour = store.store == CafeWording.harbour
            // Percent of the day's cups for tea and mocha; latte takes the rest. Station's weekday mocha is
            // 28%, not more, so that across both cafés tea stays at least 11 cups above mocha every day and
            // their lines on a per-day chart never lie on top of each other.
            let teaPercent = isHarbour ? (isWeekend ? 42 : 30) : 24
            var mochaPercent = isHarbour ? 18 : (isWeekend ? 22 : 28)
            if isHarbour, offset == dashboardNoMochaOffset { mochaPercent = 0 }
            let tea = daily.cups * teaPercent / 100
            let mocha = daily.cups * mochaPercent / 100
            let cups = [daily.cups - tea - mocha, tea, mocha]
            return zip(trendDrinks, cups).map { drink, cups in
                DashboardSale(day: daily.day, store: store.store, drink: drink, cups: cups)
            }
        }
    }
}
