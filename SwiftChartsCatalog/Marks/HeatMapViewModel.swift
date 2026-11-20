import Accessibility
import Charts
import Foundation
import Observation

/// Which heat map the screen draws.
nonisolated enum HeatMapVersion: String, CaseIterable, Identifiable {
    /// A category on each axis: time of day across, weekday down.
    case categories = "Categories"
    /// A number on each axis, binned: people queuing across, wait up.
    case binned = "Binned numbers"

    var id: Self {
        self
    }
}

/// One cell of the two-dimensional histogram: a bin on each axis and the orders that fall in both.
nonisolated struct HeatMapBinnedCell: Identifiable {
    let id: String
    let queue: ChartBinRange<Int>
    let wait: ChartBinRange<Int>
    let orders: Int
}

/// The orders binned on both axes, with the boundaries the bins were cut at.
nonisolated struct HeatMapBinnedOrders {
    /// How wide a bin is: people queuing, and seconds of wait.
    static let queueBinSize = 2
    static let waitBinSize = 50

    /// One cell for every pair of bins, column by column, empty ones included.
    let cells: [HeatMapBinnedCell]
    /// The bin boundaries on each axis, and the range they cover: the scale's domain.
    let queueThresholds: [Int]
    let waitThresholds: [Int]
    let queueDomain: ClosedRange<Int>
    let waitDomain: ClosedRange<Int>

    init(orders: [OrderWait]) {
        guard let queueRange = Self.range(covering: orders.map(\.queueLength), binSize: Self.queueBinSize),
              let waitRange = Self.range(covering: orders.map(\.waitSeconds), binSize: Self.waitBinSize)
        else {
            cells = []
            queueThresholds = []
            waitThresholds = []
            queueDomain = 0 ... 0
            waitDomain = 0 ... 0
            return
        }
        // snippet:heat-map-binning
        let queueBins = NumberBins(size: Self.queueBinSize, range: queueRange)
        let waitBins = NumberBins(size: Self.waitBinSize, range: waitRange)
        // index(for:) says which bin a value belongs to; the grouping is ordinary Swift. It gives `count`,
        // one past the last bin, for a value on the range's top (read on iOS 27): each range here ends a
        // whole bin above the largest value, so none sits there.
        let grouped = Dictionary(grouping: orders) {
            [queueBins.index(for: $0.queueLength), waitBins.index(for: $0.waitSeconds)]
        }
        // A cell for every pair of bins, the empty ones too, or the grid has holes.
        cells = queueBins.indices.flatMap { column in
            waitBins.indices.map { row in
                HeatMapBinnedCell(
                    id: "\(column)-\(row)", queue: queueBins[column], wait: waitBins[row],
                    orders: grouped[[column, row]]?.count ?? 0
                )
            }
        }
        // end
        queueThresholds = queueBins.thresholds
        waitThresholds = waitBins.thresholds
        queueDomain = queueRange
        waitDomain = waitRange
    }

    /// The boundaries an axis labels: all of them, or, when the text is very large, the ones that are
    /// multiples of twice the bin size. Chosen by value, not by position in the list, so the labels are
    /// the round ones (100, 200, 300) wherever the first bin happens to start.
    static func axisValues(_ thresholds: [Int], binSize: Int, sparse: Bool) -> [Int] {
        guard sparse, binSize > 0 else { return thresholds }
        return thresholds.filter { $0.isMultiple(of: binSize * 2) }
    }

    /// Whole bins that cover every value, ending above the largest so no value sits on the last boundary.
    static func range(covering values: [Int], binSize: Int) -> ClosedRange<Int>? {
        guard let lowest = values.min(), let highest = values.max(), binSize > 0 else { return nil }
        let firstBin = Int((Double(lowest) / Double(binSize)).rounded(.down))
        let lastBin = Int((Double(highest) / Double(binSize)).rounded(.down))
        return firstBin * binSize ... (lastBin + 1) * binSize
    }
}

/// Either heat map as a grid of named cells: what the headline, the elements and the Audio Graph say.
nonisolated struct HeatMapGrid {
    struct Cell: Hashable {
        /// The cell's place across and down, in words.
        let column: String
        let row: String
        /// The cell's one name, used by its element, the headline and the Audio Graph's summary alike.
        /// Context first, x before y: "8 am, Tuesday", or
        /// "4 to under 6 people queuing, wait of 150 to under 200 seconds".
        let name: String
        let orders: Int
    }

    let version: HeatMapVersion
    /// The names across the x axis, in the order drawn.
    let columns: [String]
    /// The names along the y axis, one Audio Graph series each.
    let rows: [String]
    /// The cells in the order the chart draws them, which is the order VoiceOver visits them.
    let cells: [Cell]

    /// Orders by weekday and slot. The weekday is spoken in full.
    init(hourlyOrders: [HourlyOrders]) {
        version = .categories
        cells = hourlyOrders.map {
            Cell(
                column: $0.slot, row: HeatMapWording.weekdayName($0.weekday),
                name: HeatMapWording.slotCell(slot: $0.slot, weekday: $0.weekday), orders: $0.orders
            )
        }
        columns = Self.inOrder(cells.map(\.column))
        rows = Self.inOrder(cells.map(\.row))
    }

    /// The two-dimensional histogram. Each bin is named by its boundaries.
    init(binned: HeatMapBinnedOrders, locale: Locale) {
        version = .binned
        cells = binned.cells.map {
            Cell(
                column: HeatMapWording.queueBin($0.queue, locale: locale),
                row: HeatMapWording.waitBin($0.wait, locale: locale),
                name: HeatMapWording.binnedCell(queue: $0.queue, wait: $0.wait, locale: locale),
                orders: $0.orders
            )
        }
        columns = Self.inOrder(cells.map(\.column))
        rows = Self.inOrder(cells.map(\.row))
    }

    var total: Int {
        cells.map(\.orders).reduce(0, +)
    }

    /// Nothing to draw: no cells, or no orders in any of them.
    var isEmpty: Bool {
        total == 0
    }

    var most: Int {
        cells.map(\.orders).max() ?? 0
    }

    var fewest: Int {
        cells.map(\.orders).min() ?? 0
    }

    /// Every cell holding the most orders, in drawing order. More than one on a tie.
    var fullest: [Cell] {
        isEmpty ? [] : cells.filter { $0.orders == most }
    }

    /// Every cell holding the fewest orders, in drawing order.
    var emptiest: [Cell] {
        isEmpty ? [] : cells.filter { $0.orders == fewest }
    }

    /// The row's cells in column order.
    func cells(inRow row: String) -> [Cell] {
        cells.filter { $0.row == row }
    }

    private static func inOrder(_ names: [String]) -> [String] {
        var seen = Set<String>()
        return names.filter { seen.insert($0).inserted }
    }
}

/// The words this screen adds to `CafeWording`, and the counts that agree in number.
nonisolated enum HeatMapWording {
    static let categoriesCaption = "Orders by time of day and weekday"
    static let binnedCaption = "Orders by people queuing and wait"
    static let noOrders = "No orders yet."

    private static let weekdayNames = [
        "Mon": "Monday", "Tue": "Tuesday", "Wed": "Wednesday", "Thu": "Thursday",
        "Fri": "Friday", "Sat": "Saturday", "Sun": "Sunday",
    ]

    /// The weekday written out, for speech and the headline. The axis keeps the data's short form.
    static func weekdayName(_ short: String) -> String {
        weekdayNames[short] ?? short
    }

    /// A bin excludes its upper boundary: "4 to under 6 people queuing".
    static func queueBin(_ bin: ChartBinRange<Int>, locale: Locale) -> String {
        "\(number(bin.lowerBound, locale)) to under \(number(bin.upperBound, locale)) people queuing"
    }

    static func waitBin(_ bin: ChartBinRange<Int>, locale: Locale) -> String {
        "\(number(bin.lowerBound, locale)) to under \(number(bin.upperBound, locale)) seconds"
    }

    /// A category cell's one name: "8 am, Tuesday".
    static func slotCell(slot: String, weekday: String) -> String {
        "\(slot), \(weekdayName(weekday))"
    }

    /// A binned cell's one name: "4 to under 6 people queuing, wait of 150 to under 200 seconds".
    static func binnedCell(queue: ChartBinRange<Int>, wait: ChartBinRange<Int>, locale: Locale) -> String {
        "\(queueBin(queue, locale: locale)), wait of \(waitBin(wait, locale: locale))"
    }

    /// "1 order", "80 orders": the count and its noun agree, in the locale's digits.
    static func orders(_ count: Int, locale: Locale) -> String {
        CafeWording.orders(count, locale: locale)
    }

    static func slots(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) slot](inflect: true)", locale: locale).characters)
    }

    static func weekdays(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) weekday](inflect: true)", locale: locale).characters)
    }

    static func cells(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) cell](inflect: true)", locale: locale).characters)
    }

    private static func number(_ value: Int, _ locale: Locale) -> String {
        value.formatted(.number.locale(locale))
    }
}

/// What the chart says in words: its headline and the summary the Audio Graph speaks.
nonisolated struct HeatMapSummary {
    let grid: HeatMapGrid
    /// Whether the chart is drawn with the framework's defaults, the mistake.
    var leavesDefaults = false
    let locale: Locale

    /// The chart's message, with the figure of the cell at the top of the colour scale. True on a tie and with no orders.
    var headline: String {
        guard let first = grid.fullest.first else { return HeatMapWording.noOrders }
        let orders = HeatMapWording.orders(first.orders, locale: locale)
        let tied = grid.fullest.count
        switch grid.version {
        case .categories:
            guard tied == 1 else {
                return "\(HeatMapWording.slots(tied, locale: locale)) tie as the busiest, with \(orders) each."
            }
            return "\(first.column) on \(first.row) is the busiest slot: \(orders)."
        case .binned:
            guard tied == 1 else {
                return "\(HeatMapWording.cells(tied, locale: locale)) tie as the fullest, with \(orders) each."
            }
            return "The fullest cell holds \(orders): \(first.name)."
        }
    }

    /// Actual values only: how big the grid is, its total, and where the most and the fewest are.
    var audioGraphSummary: String {
        guard let most = grid.fullest.first, let fewest = grid.emptiest.first else { return HeatMapWording.noOrders }
        let size = switch grid.version {
        case .categories:
            "\(HeatMapWording.slots(grid.columns.count, locale: locale)) on each of \(HeatMapWording.weekdays(grid.rows.count, locale: locale))"
        case .binned:
            "\(HeatMapWording.cells(grid.cells.count, locale: locale))"
        }
        let summary = "\(size), \(HeatMapWording.orders(grid.total, locale: locale)) in total. "
            + "Most: \(place(grid.fullest)), \(HeatMapWording.orders(most.orders, locale: locale)). "
            + "Fewest: \(place(grid.emptiest)), \(HeatMapWording.orders(fewest.orders, locale: locale))."
        return leavesDefaults ? "\(summary) \(defaultsNote)" : summary
    }

    /// How the mistake is drawn, for people who cannot see it.
    var defaultsNote: String {
        switch grid.version {
        case .categories:
            "Drawn with the chart's defaults: each cell is a short strip under its weekday's name, with gaps between cells."
        case .binned:
            "Drawn with the chart's defaults: each cell fills 70% of its bins, and both scales start at zero and run past the bins."
        }
    }

    /// One cell by name, several by their number.
    private func place(_ cells: [HeatMapGrid.Cell]) -> String {
        guard cells.count == 1, let cell = cells.first else {
            return grid.version == .categories
                ? HeatMapWording.slots(cells.count, locale: locale)
                : HeatMapWording.cells(cells.count, locale: locale)
        }
        return cell.name
    }
}

/// The heat map for the Audio Graph, which a heat map does not get on its own: one series per row,
/// each over the columns, with the orders as the value.
nonisolated struct HeatMapChartDescriptor: AXChartDescriptorRepresentable {
    let grid: HeatMapGrid
    var leavesDefaults = false
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = HeatMapSummary(grid: grid, leavesDefaults: leavesDefaults, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: grid.version == .categories ? CafeWording.slot : CafeWording.queueAxisTitle,
            categoryOrder: grid.columns
        )
        // From zero, as the colour scale and its legend are.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.orders,
            range: 0 ... Double(grid.most),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: HeatMapWording.orders) }
        let series = grid.rows.map { row in
            AXDataSeriesDescriptor(
                name: grid.version == .categories ? row : "Wait of \(row)",
                isContinuous: false,
                dataPoints: grid.cells(inRow: row).map { AXDataPoint(x: $0.column, y: Double($0.orders)) }
            )
        }
        return AXChartDescriptor(
            title: grid.version == .categories ? HeatMapWording.categoriesCaption : HeatMapWording.binnedCaption,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

/// The state of the "Heat map" screen: which version, how much of its band a cell fills, and the mistake.
@Observable
final class HeatMapViewModel {
    /// How much of its band a cell may fill.
    static let cellRatioRange = 0.5 ... 1.0
    static let cellRatioStep = 0.05

    var version = HeatMapVersion.categories
    /// The share of its band, or of its bin, each cell fills. 1 makes neighbours touch.
    var cellRatio = 1.0
    /// The mistake: no cell size and the default axis.
    var leavesDefaults = false

    let hourlyOrders: [HourlyOrders]
    let binned: HeatMapBinnedOrders

    init(hourlyOrders: [HourlyOrders] = CafeData.hourlyOrders, orderWaits: [OrderWait] = CafeData.orderWaits) {
        self.hourlyOrders = hourlyOrders
        binned = HeatMapBinnedOrders(orders: orderWaits)
    }

    func grid(locale: Locale) -> HeatMapGrid {
        switch version {
        case .categories: HeatMapGrid(hourlyOrders: hourlyOrders)
        case .binned: HeatMapGrid(binned: binned, locale: locale)
        }
    }

    var caption: String {
        switch version {
        case .categories: HeatMapWording.categoriesCaption
        case .binned: HeatMapWording.binnedCaption
        }
    }

    func headline(locale: Locale) -> String {
        HeatMapSummary(grid: grid(locale: locale), leavesDefaults: leavesDefaults, locale: locale).headline
    }

    var explanation: String {
        switch (version, leavesDefaults) {
        case (.categories, false):
            """
            A heat map is a RectangleMark with a category on each axis, coloured by a number with \
            foregroundStyle(by:), which also adds the gradient legend. Its width and height are a ratio of the \
            band, 1 making the cells touch, and the weekday names are moved outside the plot so the cells get \
            the whole row.
            """
        case (.categories, true):
            """
            The same marks with nothing else set. The framework draws the weekday names inside the plot, above \
            each row, and a rectangle 70% of its band wide in the height the name leaves, so the grid becomes \
            rows of strips. A heat map always sets its cell size and moves its row labels outside.
            """
        case (.binned, false):
            """
            With numbers on both axes there are no bands, so each axis is cut into bins with NumberBins and \
            every order is counted into a pair of them: a two-dimensional histogram. Each cell takes its two \
            bins as its x and y values and spans them, and its colour is the count. The axes are number axes, \
            given the bin boundaries as the values to mark.
            """
        case (.binned, true):
            """
            The same binned cells with nothing else set. Each cell is 70% of its bins wide and high, both \
            number scales start at zero and run on past the last bin, and the axes are labelled at round \
            numbers chosen without regard to the bins. A binned heat map sets its cell size, both scale \
            domains and the values its axes mark.
            """
        }
    }

    /// The code behind the chart as it is now drawn.
    var snippets: [SnippetReference] {
        switch (version, leavesDefaults) {
        case (.categories, false):
            [SnippetReference(name: "heat-map-categories", title: "A heat map of two categories")]
        case (.categories, true):
            [SnippetReference(name: "heat-map-defaults", title: "The mistake: left at its defaults")]
        case (.binned, false):
            [
                SnippetReference(name: "heat-map-binning", title: "Binning on two axes"),
                SnippetReference(name: "heat-map-binned", title: "A heat map of binned numbers"),
            ]
        case (.binned, true):
            [
                SnippetReference(name: "heat-map-binning", title: "Binning on two axes"),
                SnippetReference(name: "heat-map-binned-defaults", title: "The mistake: left at its defaults"),
            ]
        }
    }

    /// The cell size beside the slider. The defaults ignore the slider, and say so.
    func cellSizeText(locale: Locale) -> String {
        leavesDefaults ? "Default" : cellRatio.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    func spokenCellSize(locale: Locale) -> String {
        guard !leavesDefaults else { return "The chart's default" }
        let share = cellSizeText(locale: locale)
        return version == .categories ? "\(share) of its band" : "\(share) of its bin"
    }

    /// What to say aloud when the version changes: what changed, then the headline.
    func versionAnnouncement(locale: Locale) -> String {
        let change = switch version {
        case .categories: "Now a heat map of two categories."
        case .binned: "Now a heat map of binned numbers."
        }
        return "\(change) \(headline(locale: locale))"
    }

    /// What to say aloud when the mistake is switched: it moves the axis labels, and the binned scales.
    func defaultsAnnouncement(locale: Locale) -> String {
        let change = leavesDefaults
            ? "Now drawn with the chart's defaults."
            : "Now drawn with its cell size and axes set."
        return "\(change) \(headline(locale: locale))"
    }
}
