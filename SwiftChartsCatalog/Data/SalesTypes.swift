import Foundation

/// Cups sold on one day.
nonisolated struct DailySales: Identifiable, Hashable {
    let day: Date
    let cups: Int

    var id: Date {
        day
    }
}

/// One café's daily sales.
nonisolated struct StoreSales: Identifiable, Hashable {
    let store: String
    let days: [DailySales]

    var id: String {
        store
    }
}

/// Cups of one drink sold in one size.
nonisolated struct DrinkOrder: Identifiable, Hashable {
    let drink: String
    let size: String
    let cups: Int

    var id: String {
        "\(drink)-\(size)"
    }
}

/// A month's lowest, highest and average daily cups.
nonisolated struct MonthlySummary: Identifiable, Hashable {
    let month: Date
    let lowestDay: Int
    let highestDay: Int
    let averageDay: Int

    var id: Date {
        month
    }
}

/// How one café's cups changed against the same quarter a year before. Negative when it sold fewer.
nonisolated struct QuarterlyChange: Identifiable, Hashable {
    let quarter: String
    let store: String
    let change: Int

    var id: String {
        "\(quarter)-\(store)"
    }
}

/// One order: how many people were queuing when it was placed and how long it then took, at one café.
nonisolated struct OrderWait: Identifiable, Hashable {
    let id: Int
    let store: String
    let queueLength: Int
    let waitSeconds: Int
}

/// One order in a day across the chain: when it was placed, what and how much, and how long it took.
nonisolated struct CafeOrder: Identifiable, Hashable {
    let id: Int
    let drink: String
    /// The time of day as hours since midnight, such as 8.5 for 8:30 am.
    let hour: Double
    let cups: Int
    let waitMinutes: Double
    /// The wait for each cup, worked out once here and stored, not computed whenever it is read.
    let minutesPerCup: Double

    init(id: Int, drink: String, hour: Double, cups: Int, waitMinutes: Double) {
        self.id = id
        self.drink = drink
        self.hour = hour
        self.cups = cups
        self.waitMinutes = waitMinutes
        minutesPerCup = waitMinutes / Double(max(cups, 1))
    }
}

/// A small random number generator from a fixed seed (SplitMix64), so generated sample data is the
/// same on every run.
nonisolated struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// A number from 0 up to, but not including, 1.
    mutating func nextUnit() -> Double {
        Double(next() >> 11) / Double(UInt64(1) << 53)
    }
}

/// Orders taken in one two-hour slot of one weekday.
nonisolated struct HourlyOrders: Identifiable, Hashable {
    let weekday: String
    let slot: String
    let orders: Int

    var id: String {
        "\(weekday)-\(slot)"
    }
}

/// One barista's shift on one day.
nonisolated struct Shift: Identifiable, Hashable {
    let id: Int
    let barista: String
    let start: Date
    let end: Date
}

/// The five numbers of a box plot for one café's waits, in seconds. A median or quartile can fall halfway between
/// two waits, so they are not whole numbers.
nonisolated struct WaitQuartiles: Identifiable, Hashable {
    let store: String
    let minimum: Double
    let lowerQuartile: Double
    let median: Double
    let upperQuartile: Double
    let maximum: Double

    var id: String {
        store
    }

    init(store: String, minimum: Double, lowerQuartile: Double, median: Double, upperQuartile: Double, maximum: Double) {
        self.store = store
        self.minimum = minimum
        self.lowerQuartile = lowerQuartile
        self.median = median
        self.upperQuartile = upperQuartile
        self.maximum = maximum
    }

    /// The five numbers of `waits`: the median of them all, and each quartile the median of its half (with an odd
    /// count the middle wait belongs to neither half). All zero for no waits.
    init(store: String, waits: [Double]) {
        let sorted = waits.sorted()
        let half = sorted.count / 2
        self.init(
            store: store,
            minimum: sorted.first ?? 0,
            lowerQuartile: Self.median(of: sorted.prefix(half)),
            median: Self.median(of: sorted[...]),
            upperQuartile: Self.median(of: sorted.suffix(half)),
            maximum: sorted.last ?? 0
        )
    }

    /// The middle value of sorted values, or the mean of the middle two. 0 for none.
    static func median(of sorted: ArraySlice<Double>) -> Double {
        guard !sorted.isEmpty else { return 0 }
        let middle = sorted.startIndex + sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }
}

/// Visits in a month by one age group at one café.
nonisolated struct AgeGroupVisits: Identifiable, Hashable {
    let ageGroup: String
    let store: String
    let visits: Int

    var id: String {
        "\(ageGroup)-\(store)"
    }
}

/// A week of the wholesale price of a kilogram of beans, in dollars.
nonisolated struct WeeklyPrice: Identifiable, Hashable {
    let week: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double

    var id: Date {
        week
    }
}

/// How a drink's cups changed against last month. Negative when it sold fewer.
nonisolated struct DrinkChange: Identifiable, Hashable {
    let drink: String
    let change: Int

    var id: String {
        drink
    }
}

/// The air moving past one spot on the café floor: where it is, which way it goes and how fast.
nonisolated struct Airflow: Identifiable, Hashable {
    let id: Int
    /// Metres from the door, across and into the room.
    let x: Double
    let y: Double
    /// The direction the air moves, in degrees clockwise from up.
    let direction: Double
    /// Metres a second.
    let speed: Double
}

/// Orders taken in one half hour of the first day.
nonisolated struct HalfHourOrders: Identifiable, Hashable {
    let start: Date
    let orders: Int

    var id: Date {
        start
    }
}

/// A named part of the café's day. Its length is not a calendar unit: some are an hour and a half,
/// some three and a half hours.
/// One café of the chain: what it sold in a year, and the change on the year before.
nonisolated struct ChainCafe: Identifiable, Hashable {
    let name: String
    let yearlyCups: Int
    let change: Int

    var id: String {
        name
    }
}

nonisolated struct ServicePeriod: Identifiable, Hashable {
    let name: String
    let start: Date
    let end: Date

    var id: String {
        name
    }
}

/// Cups of one drink sold in one month.
nonisolated struct MonthlyDrinkCups: Identifiable, Hashable {
    let drink: String
    let month: Date
    let cups: Int

    var id: String {
        "\(drink)-\(month.timeIntervalSinceReferenceDate)"
    }
}

/// One day's seats filled, as a percentage for each hour from 7 am.
nonisolated struct SeatsFilledDay: Identifiable, Hashable {
    let name: String
    /// The percentage of seats filled in each hour, the first starting at 7 am.
    let hours: [Int]

    var id: String {
        name
    }

    /// Each hour's start on the first day, with its percentage.
    var readings: [SeatsFilledHour] {
        hours.enumerated().map { index, percent in SeatsFilledHour(start: CafeData.time(7 + index), percent: percent) }
    }
}

/// The percentage of seats filled in the hour that starts at `start`.
nonisolated struct SeatsFilledHour: Identifiable, Hashable {
    let start: Date
    let percent: Int

    var id: Date {
        start
    }
}

/// One bean sample's tasting scores, each from 0 to 10.
nonisolated struct BeanTasting: Identifiable, Hashable {
    let id: Int
    let origin: String
    let acidity: Double
    let body: Double
    let sweetness: Double
}

/// Cups of one drink sold at one café on one day: the dashboard's data.
nonisolated struct DashboardSale: Identifiable, Hashable {
    let day: Date
    let store: String
    let drink: String
    let cups: Int

    var id: String {
        "\(store)-\(drink)-\(day.timeIntervalSinceReferenceDate)"
    }
}
