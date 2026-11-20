import Foundation

// snippet:first-chart-data
/// How many cups of one drink were sold.
nonisolated struct DrinkSales: Identifiable, Hashable {
    let drink: String
    let cups: Int

    var id: String {
        drink
    }
}

// end
