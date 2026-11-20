import Foundation
import Observation

/// The four ways marks that share a position can be combined.
nonisolated enum StackingMethod: String, CaseIterable, Identifiable {
    case standard, normalized, center, unstacked

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .standard: "Standard"
        case .normalized: "Normalized"
        case .center: "Center"
        case .unstacked: "Unstacked"
        }
    }
}

/// The two marks that stack.
nonisolated enum StackingMark: String, CaseIterable, Identifiable {
    case bars, areas

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .bars: "Bars"
        case .areas: "Areas"
        }
    }
}

/// One piece of a stack: a value for one series at one position.
nonisolated struct StackRow: Identifiable, Hashable {
    let category: String
    let series: String
    let value: Int

    var id: String {
        "\(category)-\(series)"
    }
}

/// The rows a chart stacks, with the words for what they are.
nonisolated struct StackingData: Hashable {
    let rows: [StackRow]
    /// What a position is, singular: "Drink".
    let categoryLabel: String
    /// What a piece of a stack is, singular: "Size".
    let seriesLabel: String
    /// What is measured: "Cups".
    let valueLabel: String
    /// Whether the values are changes, which can be falls, and not counts.
    let isChange: Bool
    /// Whether the positions are a sequence (weeks, quarters) and not unrelated things (drinks).
    /// Only then does the slope of an area between two positions mean anything.
    let isOrdered: Bool
    /// What the chart shows, and what it shows when every stack is scaled to 100%.
    let caption: String
    let normalizedCaption: String

    /// The positions, in data order.
    var categories: [String] {
        Self.unique(rows.map(\.category))
    }

    /// The series, in data order, which is the order they stack in.
    var seriesNames: [String] {
        Self.unique(rows.map(\.series))
    }

    /// Nothing to draw: no rows, or every value zero.
    var isEmpty: Bool {
        rows.allSatisfy { $0.value == 0 }
    }

    func rows(in category: String) -> [StackRow] {
        rows.filter { $0.category == category }
    }

    static func orders(_ orders: [DrinkOrder]) -> StackingData {
        StackingData(
            rows: orders.map { StackRow(category: $0.drink, series: $0.size, value: $0.cups) },
            categoryLabel: "Drink", seriesLabel: "Size", valueLabel: "Cups", isChange: false, isOrdered: false,
            caption: "Cups sold today, by drink and size", normalizedCaption: "Share of each drink's cups, by size"
        )
    }

    static let daysInWeek = 7

    /// Each café's cups in each run of seven days: positions in an order, which is what an area needs.
    static func weeks(_ stores: [StoreSales]) -> StackingData {
        let longest = stores.map(\.days.count).max() ?? 0
        let weekCount = (longest + daysInWeek - 1) / daysInWeek
        let rows = (0 ..< weekCount).flatMap { week in
            stores.map { store in
                let cups = store.days.dropFirst(week * daysInWeek).prefix(daysInWeek).map(\.cups).reduce(0, +)
                return StackRow(category: "Week \((week + 1).formatted())", series: store.store, value: cups)
            }
        }
        return StackingData(
            rows: rows, categoryLabel: "Week", seriesLabel: "Café", valueLabel: "Cups", isChange: false, isOrdered: true,
            caption: "Cups sold each week, by café", normalizedCaption: "Share of each week's cups, by café"
        )
    }

    static func changes(_ changes: [QuarterlyChange]) -> StackingData {
        StackingData(
            rows: changes.map { StackRow(category: $0.quarter, series: $0.store, value: $0.change) },
            categoryLabel: "Quarter", seriesLabel: "Café", valueLabel: "Change in cups", isChange: true, isOrdered: true,
            caption: "Change in cups on last year, by quarter and café",
            normalizedCaption: "Change in cups on last year, each quarter scaled to 100%"
        )
    }

    private static func unique(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}

/// The state of the Stacking screen: the method, the mark, the data, and whether the colour is removed.
@Observable
final class StackingViewModel {
    var method = StackingMethod.standard
    var mark = StackingMark.bars
    var usesNegativeValues = false
    var isShowingMistake = false

    private let orders: StackingData
    private let changes: StackingData
    private let weeks: StackingData

    init(
        orders: [DrinkOrder] = CafeData.drinkOrders, changes: [QuarterlyChange] = CafeData.quarterlyChanges,
        stores: [StoreSales] = CafeData.storeSales
    ) {
        self.orders = .orders(orders)
        self.changes = .changes(changes)
        weeks = .weeks(stores)
    }

    /// Bars compare separate things, so they are drawn over drinks. Areas join one position to the next,
    /// so they are drawn over weeks, which are in an order. The quarterly changes are in an order already.
    var data: StackingData {
        if usesNegativeValues { return changes }
        return mark == .areas ? weeks : orders
    }

    var explanation: String {
        let stacking = """
        Bars and areas that share a position stack on each other in data order, whether or not they are coloured. \
        foregroundStyle(by:) does not cause the stacking: it colours the pieces so they can be told apart, and adds \
        the legend. The stacking: parameter chooses how the pieces combine: from zero, as shares of 100%, around a \
        centre line, or not at all.
        """
        return mark == .areas ? "\(stacking) \(Self.areasExplanation)" : stacking
    }

    static let areasExplanation = """
    Areas want an ordered x, because an area slopes from each position to the next: these are drawn over weeks \
    or quarters, not over drinks, which are in no order.
    """

    /// The chart's words for the current settings.
    var summary: StackingSummary {
        StackingSummary(data: data, method: method, mark: mark, isShowingMistake: isShowingMistake)
    }

    /// The code behind the chart as it is drawn now.
    var snippets: [SnippetReference] {
        let chart = switch (mark, isShowingMistake) {
        case (.bars, false): SnippetReference(name: "stacking-bars", title: "Stacked bars")
        case (.areas, false): SnippetReference(name: "stacking-areas", title: "Stacked areas")
        case (.bars, true): SnippetReference(name: "stacking-mistake-bars", title: "The mistake: bars with no colour")
        case (.areas, true): SnippetReference(name: "stacking-mistake-areas", title: "The mistake: areas with no colour")
        }
        return [chart, SnippetReference(name: "stacking-method", title: "The four stacking methods")]
    }
}

/// One piece as the chart draws it: where it starts and ends on the value axis.
nonisolated struct StackSegment: Hashable {
    let row: StackRow
    let start: Double
    let end: Double

    var low: Double {
        min(start, end)
    }

    var high: Double {
        max(start, end)
    }
}

/// What the chart says in words for one setting of the controls: its caption, headline,
/// what each accessibility element says, and what the Audio Graph is given.
nonisolated struct StackingSummary: Hashable {
    let data: StackingData
    let method: StackingMethod
    let mark: StackingMark
    let isShowingMistake: Bool

    // MARK: What is drawn

    /// The pieces at one position, placed as the stacking method places them.
    func segments(in category: String) -> [StackSegment] {
        let rows = data.rows(in: category)
        let scale = method == .normalized ? normalizingScale(for: rows) : 1
        var rise = 0.0
        var fall = 0.0
        let stacked = rows.map { row in
            let value = Double(row.value) * scale
            if method == .unstacked {
                return StackSegment(row: row, start: 0, end: value)
            }
            if value >= 0 {
                rise += value
                return StackSegment(row: row, start: rise - value, end: rise)
            }
            fall += value
            return StackSegment(row: row, start: fall - value, end: fall)
        }
        guard method == .center else { return stacked }
        let shift = (rise + fall) / 2
        return stacked.map { StackSegment(row: $0.row, start: $0.start - shift, end: $0.end - shift) }
    }

    /// The factor that turns a position's values into percentages. The framework scales a stack so that
    /// its longer side, the rises or the falls, reaches 100; with no negative values that is the total.
    private func normalizingScale(for rows: [StackRow]) -> Double {
        let rises = rows.filter { $0.value > 0 }.map { Double($0.value) }.reduce(0, +)
        let falls = rows.filter { $0.value < 0 }.map { -Double($0.value) }.reduce(0, +)
        let whole = max(rises, falls)
        return whole == 0 ? 0 : Self.percentScale / whole
    }

    static let percentScale = 100.0

    var allSegments: [StackSegment] {
        data.categories.flatMap(segments(in:))
    }

    /// From the lowest to the highest point drawn at a position.
    func extent(of category: String) -> ClosedRange<Double> {
        let segments = segments(in: category)
        return (segments.map(\.low).min() ?? 0) ... (segments.map(\.high).max() ?? 0)
    }

    /// The extent of what is drawn: it always includes zero.
    var valueRange: ClosedRange<Double> {
        min(0, lowest) ... max(0, highest)
    }

    /// The value axis as drawn: `valueRange` rounded out to the axis step (a stack of 164 → 0 to 200; normalized
    /// stacks 0 to 100). The chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        // Normalized stacks are sums of shares that can land a hair past 100; rounded first, so the axis is not
        // pushed up a whole step by the error.
        let ends = [valueRange.lowerBound, valueRange.upperBound].map { ($0 * Self.endPrecision).rounded() / Self.endPrecision }
        return ChartAxis.valueDomain(for: ends)
    }

    /// The ends of the drawn values are rounded to a millionth before the axis is worked out.
    private static let endPrecision = 1_000_000.0

    private var highest: Double {
        data.categories.map { extent(of: $0).upperBound }.max() ?? 0
    }

    private var lowest: Double {
        data.categories.map { extent(of: $0).lowerBound }.min() ?? 0
    }

    private var highestCategories: [String] {
        data.categories.filter { extent(of: $0).upperBound == highest }
    }

    private var lowestCategories: [String] {
        data.categories.filter { extent(of: $0).lowerBound == lowest }
    }

    private var longestRises: [StackSegment] {
        let longest = allSegments.map(\.high).max() ?? 0
        return allSegments.filter { $0.high == longest && longest > 0 }
    }

    private var longestFalls: [StackSegment] {
        let longest = allSegments.map(\.low).min() ?? 0
        return allSegments.filter { $0.low == longest && longest < 0 }
    }

    /// The pieces with the greatest length, whichever way they point.
    private var longestPieces: [StackSegment] {
        let longest = allSegments.map { $0.high - $0.low }.max() ?? 0
        return allSegments.filter { $0.high - $0.low == longest }
    }

    /// How far a position's shorter side reaches: zero when its pieces all point one way.
    private func shorterSide(of category: String) -> Double {
        let extent = extent(of: category)
        return min(extent.upperBound, -extent.lowerBound)
    }

    // MARK: Words

    /// An amount on the value axis with its unit: "164 cups", "1 cup", or "43%" when normalized.
    func amountText(_ amount: Double) -> String {
        if method == .normalized {
            return (abs(amount) / Self.percentScale).formatted(.percent.precision(.fractionLength(0)))
        }
        return Self.cupsText(Int(abs(amount).rounded()))
    }

    /// The same amount as it is spoken: "43 percent", not "43%".
    func spokenAmountText(_ amount: Double) -> String {
        // The descriptor passes numbers the accessibility system chose, so the conversion cannot trap.
        if method == .normalized {
            return CafeWording.count(abs(amount).rounded(), locale: .current) { count, _ in "\(count.formatted()) percent" }
        }
        return CafeWording.count(abs(amount).rounded(), locale: .current) { count, _ in Self.cupsText(count) }
    }

    static func cupsText(_ cups: Int) -> String {
        cups == 1 ? "\(cups.formatted()) cup" : "\(cups.formatted()) cups"
    }

    private static func names(_ names: [String]) -> String {
        names.formatted(.list(type: .and))
    }

    private func pieceNames(_ segments: [StackSegment]) -> String {
        Self.names(segments.map { "\($0.row.series) at \($0.row.category)" })
    }

    private var pieceNoun: String {
        data.seriesLabel.lowercased()
    }

    var caption: String {
        method == .normalized ? data.normalizedCaption : data.caption
    }

    /// The chart's message for this setting. Its figure is one the chart shows as drawn.
    var headline: String {
        guard !data.isEmpty else { return Self.emptyHeadline }
        guard isShowingMistake else { return fact(namingPieces: true) }
        return "Without colour, nothing says which piece is which \(pieceNoun). \(fact(namingPieces: false))"
    }

    static let emptyHeadline = "Nothing to stack yet."

    /// What the stacking method did to this data, with a figure from the chart.
    /// Pieces are named only when the chart names them, which it does through colour.
    private func fact(namingPieces: Bool) -> String {
        switch method {
        case .standard:
            let rule = lowest < 0 ? "Rises stack up from zero and falls stack down" : "Pieces stack up from zero"
            return "\(rule): \(reachText)."
        case .normalized:
            return normalizedFact(namingPieces: namingPieces)
        case .center:
            return "Every stack is centred on zero: the widest, \(Self.names(highestCategories)), "
                + "reaches \(amountText(highest)) either side."
        case .unstacked:
            return namingPieces ? unstackedFact : "Every piece starts at zero and they overlap: \(reachText)."
        }
    }

    /// The highest and lowest points drawn, and where: "the tallest reaches 164 cups at Tea".
    private var reachText: String {
        let top = "\(amountText(highest)) at \(Self.names(highestCategories))"
        let bottom = "\(amountText(lowest)) below zero at \(Self.names(lowestCategories))"
        if lowest < 0, highest > 0 { return "the highest reaches \(top), the lowest \(bottom)" }
        return lowest < 0 ? "the lowest reaches \(bottom)" : "the tallest reaches \(top)"
    }

    private func normalizedFact(namingPieces: Bool) -> String {
        guard lowest < 0 else {
            guard namingPieces, let piece = longestPieces.first else { return "Every stack fills to 100%, whatever its total." }
            return "Every stack fills to 100%: the largest share is \(pieceNames(longestPieces)), \(amountText(piece.high - piece.low))."
        }
        let furthest = data.categories.map(shorterSide(of:)).max() ?? 0
        guard furthest > 0 else { return "Each stack is scaled so that it reaches 100%, up or down from zero." }
        let categories = data.categories.filter { shorterSide(of: $0) == furthest }
        return "Each stack is scaled so its longer side reaches 100%: the shorter side reaches furthest at "
            + "\(Self.names(categories)), \(amountText(furthest))."
    }

    private var unstackedFact: String {
        let rise = longestRises.first.map { "\(pieceNames(longestRises)), \(amountText($0.high))" }
        let fall = longestFalls.first.map { "\(pieceNames(longestFalls)), \(amountText($0.low))" }
        switch (rise, fall) {
        case let (rise?, fall?):
            return "Every piece starts at zero: the longest rise is \(rise), and the longest fall \(fall)."
        case let (rise?, nil):
            return "Every piece starts at zero: the longest is \(rise)."
        case let (nil, fall?):
            return "Every piece starts at zero: the longest fall is \(fall)."
        case (nil, nil):
            return Self.emptyHeadline
        }
    }

    /// What is said aloud when a control changes the chart: each thing that changed, then what the chart
    /// now shows. Every control that redraws the chart is in it: the method, the mark, the data and the colour.
    func announcement(after previous: StackingSummary) -> String {
        var changes: [String] = []
        if method != previous.method { changes.append("Stacking method changed to \(method.title.lowercased()).") }
        if mark != previous.mark { changes.append("Marks changed to \(mark.title.lowercased()).") }
        if data != previous.data { changes.append("The data changed.") }
        if isShowingMistake != previous.isShowingMistake {
            changes.append(isShowingMistake ? "Colour removed." : "Colour restored.")
        }
        return (changes + ["\(caption). \(headline)"]).joined(separator: " ")
    }

    // MARK: Accessibility elements

    /// A piece's length as drawn, negative when it points down.
    func signedLength(of row: StackRow) -> Double {
        guard let segment = segments(in: row.category).first(where: { $0.row == row }) else { return 0 }
        return segment.end - segment.start
    }

    /// A length on the value axis in words: with its unit, and for a change which way it went.
    func spokenValue(_ value: Double) -> String {
        // A number that is not finite has no amount to describe.
        guard value.isFinite else { return "" }
        let amount = spokenAmountText(value)
        // With the colour removed the values are where a stack ends, not what a piece changed by.
        if isShowingMistake { return value < 0 ? "\(amount) below zero" : amount }
        guard data.isChange else { return amount }
        if value == 0 { return "no change" }
        if method == .normalized {
            // The percentage is a share of the stack's longer side, not a percentage change in cups:
            // "43 percent fewer" would claim a fall of 43 percent that did not happen.
            let direction = value > 0 ? "a rise" : "a fall"
            return "\(direction), \(amount) of the \(data.categoryLabel.lowercased())'s scale"
        }
        return value > 0 ? "\(amount) more" : "\(amount) fewer"
    }

    /// What a piece's accessibility element says after its name.
    func valueText(for row: StackRow) -> String {
        spokenValue(signedLength(of: row))
    }

    /// With the colour removed a position is one element, and its pieces have no names.
    func uncolouredValueText(for category: String) -> String {
        let extent = extent(of: category)
        let count = data.rows(in: category).count
        let pieces = count == 1 ? "1 piece with no name" : "\(count.formatted()) pieces with no names"
        let reach = if extent.lowerBound < 0, extent.upperBound > 0 {
            "from \(spokenAmountText(extent.lowerBound)) below zero to \(spokenAmountText(extent.upperBound)) above"
        } else if extent.lowerBound < 0 {
            "\(spokenAmountText(extent.lowerBound)) below zero"
        } else {
            spokenAmountText(extent.upperBound)
        }
        return method == .unstacked ? "\(pieces), overlapping, reaching \(reach)" : "\(reach), in \(pieces)"
    }

    // MARK: Audio Graph

    var audioGraphTitle: String {
        let arrangement = switch method {
        case .standard: "stacked from zero"
        case .normalized where data.isChange: "each stack scaled so its longer side is 100 percent"
        case .normalized: "stacked as shares of 100 percent"
        case .center: "stacked around a centre line"
        case .unstacked: "not stacked, every piece from zero"
        }
        return "\(caption), \(arrangement)" + (isShowingMistake ? ", drawn in one colour" : "")
    }

    /// Actual values only. With the colour removed it names no piece, as the chart names none.
    var audioGraphSummary: String {
        guard !data.isEmpty else { return Self.emptyHeadline }
        let shape = "\(data.categories.count.formatted()) \(data.categoryLabel.lowercased()) positions, "
            + "\(data.seriesNames.count.formatted()) pieces at each."
        let colour = isShowingMistake ? " Drawn in one colour, so the pieces have no names." : ""
        return "\(shape)\(colour) \(fact(namingPieces: !isShowingMistake))"
    }

    var valueAxisTitle: String {
        method == .normalized ? "Percent, scaled within each \(data.categoryLabel.lowercased())" : data.valueLabel
    }

    /// The Audio Graph draws a line for a continuous series. Only areas over ordered positions are one:
    /// between two drinks there is nothing for a line to pass through.
    var isContinuous: Bool {
        mark == .areas && data.isOrdered
    }

    /// The name of the one series left when the colour is removed.
    var uncolouredSeriesName: String {
        "Every \(pieceNoun), in one colour"
    }

    /// What the Audio Graph is given with the colour removed: a value per position, in position order, at the
    /// top of what is drawn there. Where a stack reaches below zero, a second series gives the bottoms.
    var uncolouredSeries: [(name: String, values: [Double])] {
        let extents = data.categories.map(extent(of:))
        let tops = extents.map(\.upperBound)
        guard valueRange.lowerBound < 0 else { return [(uncolouredSeriesName, tops)] }
        return [
            ("Top of every stack, in one colour", tops),
            ("Bottom of every stack, in one colour", extents.map(\.lowerBound)),
        ]
    }
}
