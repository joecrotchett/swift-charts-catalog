import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct HeatMapTests {
    private let english = Locale(identifier: "en_US")

    private let hourly = [
        HourlyOrders(weekday: "Mon", slot: "6 am", orders: 12),
        HourlyOrders(weekday: "Mon", slot: "8 am", orders: 30),
        HourlyOrders(weekday: "Tue", slot: "6 am", orders: 1),
        HourlyOrders(weekday: "Tue", slot: "8 am", orders: 25),
    ]

    private let waits = [
        OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 60),
        OrderWait(id: 1, store: "Harbour", queueLength: 1, waitSeconds: 70),
        OrderWait(id: 2, store: "Station", queueLength: 1, waitSeconds: 99),
        OrderWait(id: 3, store: "Station", queueLength: 4, waitSeconds: 100),
        OrderWait(id: 4, store: "Station", queueLength: 5, waitSeconds: 160),
    ]

    // MARK: State

    @Test("Given a new screen, when nothing is changed, then it draws the category heat map with touching cells and no mistake")
    func startsOnCategories() {
        let viewModel = HeatMapViewModel()

        #expect(viewModel.version == .categories)
        #expect(viewModel.cellRatio == 1)
        #expect(!viewModel.leavesDefaults)
        #expect(viewModel.caption == "Orders by time of day and weekday")
        #expect(viewModel.hourlyOrders == CafeData.hourlyOrders)
    }

    @Test("Given each version and the mistake on or off, when the explanation is read, then every state has its own")
    func explanationFollowsState() {
        let viewModel = HeatMapViewModel()
        var explanations = Set<String>()
        for version in HeatMapVersion.allCases {
            for leavesDefaults in [false, true] {
                viewModel.version = version
                viewModel.leavesDefaults = leavesDefaults
                explanations.insert(viewModel.explanation)
            }
        }

        #expect(explanations.count == 4)
    }

    @Test("Given the binned version, when the caption is read, then it names the two numbers")
    func binnedCaption() {
        let viewModel = HeatMapViewModel()
        viewModel.version = .binned

        #expect(viewModel.caption == "Orders by people queuing and wait")
    }

    // MARK: Snippets

    @Test("Given each state, when its snippets are listed, then they are the code that draws that state")
    func snippetsFollowState() {
        let viewModel = HeatMapViewModel()
        #expect(viewModel.snippets.map(\.name) == ["heat-map-categories"])

        viewModel.leavesDefaults = true
        #expect(viewModel.snippets.map(\.name) == ["heat-map-defaults"])

        viewModel.version = .binned
        #expect(viewModel.snippets.map(\.name) == ["heat-map-binning", "heat-map-binned-defaults"])

        viewModel.leavesDefaults = false
        #expect(viewModel.snippets.map(\.name) == ["heat-map-binning", "heat-map-binned"])
    }

    @Test("Given the built app, when every state's snippets are looked up, then each exists and shows its concept")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        let categories = try #require(store["heat-map-categories"])
        #expect(categories.code.contains("width: .ratio(cellRatio)"))
        #expect(categories.code.contains("AxisMarks(preset: .aligned, position: .leading)"))
        let defaults = try #require(store["heat-map-defaults"])
        #expect(!defaults.code.contains("width:"))
        #expect(!defaults.code.contains(".chartYAxis"))
        let binning = try #require(store["heat-map-binning"])
        #expect(binning.code.contains("NumberBins(size:"))
        let binned = try #require(store["heat-map-binned"])
        #expect(binned.code.contains(".chartXScale(domain:"))
        let binnedDefaults = try #require(store["heat-map-binned-defaults"])
        #expect(!binnedDefaults.code.contains("chartXScale"))
    }

    // MARK: Binning

    @Test("Given orders, when they are binned on both axes, then there is a cell for every pair of bins and every order is counted once")
    func binsCoverEveryPair() {
        let binned = HeatMapBinnedOrders(orders: waits)

        #expect(binned.queueThresholds == [0, 2, 4, 6])
        #expect(binned.waitThresholds == [50, 100, 150, 200])
        #expect(binned.queueDomain == 0 ... 6)
        #expect(binned.waitDomain == 50 ... 200)
        #expect(binned.cells.count == 9)
        #expect(binned.cells.map(\.orders).reduce(0, +) == waits.count)
        #expect(Set(binned.cells.map(\.id)).count == 9)
    }

    @Test("Given a value on a bin boundary, when it is binned, then it belongs to the bin that starts there")
    func boundaryBelongsToUpperBin() {
        let binned = HeatMapBinnedOrders(orders: waits)

        let first = binned.cells.first { $0.queue.lowerBound == 0 && $0.wait.lowerBound == 50 }
        let boundary = binned.cells.first { $0.queue.lowerBound == 4 && $0.wait.lowerBound == 100 }
        #expect(first?.orders == 3)
        #expect(boundary?.orders == 1)
    }

    @Test("Given the café's orders, when they are binned, then the grid is six bins by six and holds all forty orders")
    func sampleDataBins() {
        let binned = HeatMapBinnedOrders(orders: CafeData.orderWaits)

        #expect(binned.queueThresholds == [0, 2, 4, 6, 8, 10, 12])
        #expect(binned.waitThresholds == [50, 100, 150, 200, 250, 300, 350])
        #expect(binned.cells.count == 36)
        #expect(binned.cells.map(\.orders).reduce(0, +) == CafeData.orderWaits.count)
    }

    @Test("Given no orders, when they are binned, then there are no cells")
    func noOrdersNoCells() {
        let binned = HeatMapBinnedOrders(orders: [])

        #expect(binned.cells.isEmpty)
        #expect(binned.queueThresholds.isEmpty)
    }

    @Test("Given bin boundaries, when the axis values are chosen, then very large text gets the boundaries that are multiples of twice the bin size")
    func sparseAxisValues() {
        #expect(HeatMapBinnedOrders.axisValues([0, 2, 4, 6, 8], binSize: 2, sparse: false) == [0, 2, 4, 6, 8])
        #expect(HeatMapBinnedOrders.axisValues([0, 2, 4, 6, 8], binSize: 2, sparse: true) == [0, 4, 8])
        // Bins that start on an odd boundary: by position these would be 50, 150, 250, 350.
        #expect(HeatMapBinnedOrders.axisValues([50, 100, 150, 200, 250, 300, 350], binSize: 50, sparse: true) == [100, 200, 300])
        #expect(HeatMapBinnedOrders.axisValues([2, 4, 6, 8, 10], binSize: 2, sparse: true) == [4, 8])
    }

    // MARK: Headline

    @Test("Given hourly orders, when the headline is written, then it names the busiest slot, its weekday in full and its orders")
    func categoryHeadline() {
        let viewModel = HeatMapViewModel(hourlyOrders: hourly, orderWaits: waits)

        #expect(viewModel.headline(locale: english) == "8 am on Monday is the busiest slot: 30 orders.")
    }

    @Test("Given the café's sample data, when the headline is written, then its figure is the largest value in the data")
    func headlineFollowsSampleData() {
        let viewModel = HeatMapViewModel()

        #expect(viewModel.headline(locale: english) == "8 am on Tuesday is the busiest slot: 80 orders.")
        viewModel.version = .binned
        #expect(
            viewModel.headline(locale: english)
                == "The fullest cell holds 7 orders: 0 to under 2 people queuing, wait of 50 to under 100 seconds."
        )
    }

    @Test("Given the mistake or another cell size, when the headline is written, then it is unchanged, because the same cells are drawn")
    func headlineHoldsUnderRestyling() {
        let viewModel = HeatMapViewModel(hourlyOrders: hourly, orderWaits: waits)
        let headline = viewModel.headline(locale: english)

        viewModel.leavesDefaults = true
        viewModel.cellRatio = 0.5
        #expect(viewModel.headline(locale: english) == headline)
    }

    @Test("Given two slots tied for the most, when the headline is written, then it counts them and stays true")
    func tiedHeadline() {
        let tied = [
            HourlyOrders(weekday: "Mon", slot: "6 am", orders: 9),
            HourlyOrders(weekday: "Mon", slot: "8 am", orders: 9),
            HourlyOrders(weekday: "Tue", slot: "6 am", orders: 1),
        ]
        let viewModel = HeatMapViewModel(hourlyOrders: tied, orderWaits: [])

        #expect(viewModel.headline(locale: english) == "2 slots tie as the busiest, with 9 orders each.")
    }

    @Test("Given binned cells tied for the most, when the headline is written, then it counts them, and one order is singular")
    func tiedBinnedHeadline() {
        let viewModel = HeatMapViewModel(hourlyOrders: [], orderWaits: [
            OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 60),
            OrderWait(id: 1, store: "Harbour", queueLength: 3, waitSeconds: 120),
        ])
        viewModel.version = .binned

        #expect(viewModel.headline(locale: english) == "2 cells tie as the fullest, with 1 order each.")
    }

    @Test("Given no orders or only zeros, when the headline and summary are written, then both say there are none, in either version")
    func emptyAndZeroSaySo() {
        let zeros = [HourlyOrders(weekday: "Mon", slot: "6 am", orders: 0), HourlyOrders(weekday: "Tue", slot: "6 am", orders: 0)]
        for viewModel in [HeatMapViewModel(hourlyOrders: [], orderWaits: []), HeatMapViewModel(hourlyOrders: zeros, orderWaits: [])] {
            for version in HeatMapVersion.allCases {
                viewModel.version = version
                let grid = viewModel.grid(locale: english)

                #expect(grid.isEmpty)
                #expect(viewModel.headline(locale: english) == "No orders yet.")
                #expect(HeatMapSummary(grid: grid, locale: english).audioGraphSummary == "No orders yet.")
            }
        }
    }

    // MARK: Words

    @Test("Given a count, when it is written, then its noun agrees with the number")
    func countsAgreeInNumber() {
        #expect(HeatMapWording.orders(1, locale: english) == "1 order")
        #expect(HeatMapWording.orders(0, locale: english) == "0 orders")
        #expect(HeatMapWording.orders(1823, locale: english) == "1,823 orders")
        #expect(HeatMapWording.slots(1, locale: english) == "1 slot")
        #expect(HeatMapWording.slots(6, locale: english) == "6 slots")
        #expect(HeatMapWording.weekdays(7, locale: english) == "7 weekdays")
        #expect(HeatMapWording.cells(1, locale: english) == "1 cell")
        #expect(HeatMapWording.cells(36, locale: english) == "36 cells")
    }

    @Test("Given another locale, when a count is written, then the number is grouped that locale's way")
    func countsTakeTheLocale() {
        #expect(HeatMapWording.orders(1823, locale: Locale(identifier: "en_IN")).hasPrefix("1,823"))
        #expect(HeatMapWording.orders(1823, locale: Locale(identifier: "de_DE")).hasPrefix("1.823"))
    }

    @Test("Given a short weekday, when it is spoken, then it is written out, and an unknown name is kept")
    func weekdaysAreWrittenOut() {
        #expect(HeatMapWording.weekdayName("Wed") == "Wednesday")
        #expect(HeatMapWording.weekdayName("Holiday") == "Holiday")
    }

    @Test("Given the grid, when a cell is named, then the column comes before the row in both versions")
    func cellNamesPutXFirst() {
        let viewModel = HeatMapViewModel(hourlyOrders: hourly, orderWaits: waits)
        #expect(viewModel.grid(locale: english).cells.first?.name == "6 am, Monday")

        viewModel.version = .binned
        #expect(viewModel.grid(locale: english).cells.first?.name == "0 to under 2 people queuing, wait of 50 to under 100 seconds")
    }

    @Test("Given the cell size, when it is shown and spoken, then it is a share of the band or bin, and the defaults say they ignore it")
    func cellSizeText() {
        let viewModel = HeatMapViewModel()
        viewModel.cellRatio = 0.9
        #expect(viewModel.cellSizeText(locale: english) == "90%")
        #expect(viewModel.spokenCellSize(locale: english) == "90% of its band")

        viewModel.version = .binned
        #expect(viewModel.spokenCellSize(locale: english) == "90% of its bin")

        viewModel.leavesDefaults = true
        #expect(viewModel.cellSizeText(locale: english) == "Default")
        #expect(viewModel.spokenCellSize(locale: english) == "The chart's default")
    }

    @Test("Given a change of version, when it is announced, then it says what changed and then the headline")
    func announcementSaysChangeThenHeadline() {
        let viewModel = HeatMapViewModel(hourlyOrders: hourly, orderWaits: waits)
        viewModel.version = .binned
        #expect(
            viewModel.versionAnnouncement(locale: english)
                == "Now a heat map of binned numbers. \(viewModel.headline(locale: english))"
        )

        viewModel.version = .categories
        #expect(
            viewModel.versionAnnouncement(locale: english)
                == "Now a heat map of two categories. 8 am on Monday is the busiest slot: 30 orders."
        )
    }

    @Test("Given the mistake switched on or off, when it is announced, then it says how the chart is now drawn and then the headline")
    func defaultsAnnouncement() {
        let viewModel = HeatMapViewModel(hourlyOrders: hourly, orderWaits: waits)
        viewModel.leavesDefaults = true
        #expect(
            viewModel.defaultsAnnouncement(locale: english)
                == "Now drawn with the chart's defaults. 8 am on Monday is the busiest slot: 30 orders."
        )

        viewModel.leavesDefaults = false
        #expect(
            viewModel.defaultsAnnouncement(locale: english)
                == "Now drawn with its cell size and axes set. 8 am on Monday is the busiest slot: 30 orders."
        )
    }

    // MARK: Audio Graph

    @Test("Given hourly orders, when the Audio Graph summary is written, then it gives the size, total, most and fewest in actual values")
    func summaryGivesActualValues() {
        let summary = HeatMapSummary(grid: HeatMapGrid(hourlyOrders: hourly), locale: english)

        #expect(
            summary.audioGraphSummary
                == "2 slots on each of 2 weekdays, 68 orders in total. Most: 8 am, Monday, 30 orders. Fewest: 6 am, Tuesday, 1 order."
        )
    }

    @Test("Given binned orders with several empty cells, when the summary is written, then the fewest are counted, not listed")
    func binnedSummaryCountsTies() {
        let grid = HeatMapGrid(binned: HeatMapBinnedOrders(orders: waits), locale: english)
        let summary = HeatMapSummary(grid: grid, locale: english)

        #expect(
            summary.audioGraphSummary
                == "9 cells, 5 orders in total. Most: 0 to under 2 people queuing, wait of 50 to under 100 seconds, 3 orders. Fewest: 6 cells, 0 orders."
        )
    }

    @Test("Given the mistake, when the summary is written, then it also says how the chart is drawn, for each version")
    func summaryDescribesTheMistake() {
        let categories = HeatMapSummary(grid: HeatMapGrid(hourlyOrders: hourly), leavesDefaults: true, locale: english)
        let binned = HeatMapSummary(
            grid: HeatMapGrid(binned: HeatMapBinnedOrders(orders: waits), locale: english), leavesDefaults: true, locale: english
        )

        #expect(categories.audioGraphSummary.hasSuffix("each cell is a short strip under its weekday's name, with gaps between cells."))
        #expect(binned.audioGraphSummary.hasSuffix("each cell fills 70% of its bins, and both scales start at zero and run past the bins."))
        #expect(!HeatMapSummary(grid: HeatMapGrid(hourlyOrders: hourly), locale: english).audioGraphSummary.contains("defaults"))
    }

    @Test("Given the category heat map, when its descriptor is made, then each weekday is a series over the slots, valued in orders from zero")
    func categoryDescriptor() {
        let descriptor = HeatMapChartDescriptor(grid: HeatMapGrid(hourlyOrders: hourly), locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Orders by time of day and weekday")
        #expect(descriptor.summary == HeatMapSummary(grid: HeatMapGrid(hourlyOrders: hourly), locale: english).audioGraphSummary)
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.title == CafeWording.slot)
        #expect(xAxis?.categoryOrder == ["6 am", "8 am"])
        #expect(descriptor.yAxis?.title == CafeWording.orders)
        #expect(descriptor.yAxis?.range == 0 ... 30)
        #expect(descriptor.yAxis?.valueDescriptionProvider(1) == "1 order")
        #expect(descriptor.yAxis?.valueDescriptionProvider(30) == "30 orders")
        #expect(descriptor.series.map(\.name) == ["Monday", "Tuesday"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 2 })
    }

    @Test("Given the binned heat map, when its descriptor is made, then each wait bin is a series over the queue bins")
    func binnedDescriptor() {
        let grid = HeatMapGrid(binned: HeatMapBinnedOrders(orders: waits), locale: english)
        let descriptor = HeatMapChartDescriptor(grid: grid, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Orders by people queuing and wait")
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.title == CafeWording.queueAxisTitle)
        #expect(xAxis?.categoryOrder == ["0 to under 2 people queuing", "2 to under 4 people queuing", "4 to under 6 people queuing"])
        #expect(descriptor.yAxis?.range == 0 ... 3)
        #expect(descriptor.series.map(\.name) == [
            "Wait of 50 to under 100 seconds", "Wait of 100 to under 150 seconds", "Wait of 150 to under 200 seconds",
        ])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 3 })
    }

    @Test("Given the largest values on a bin boundary, when they are binned, then the range runs past them and every order is counted")
    func topValueOnBoundaryCounted() {
        let orders = [
            OrderWait(id: 0, store: CafeWording.harbour, queueLength: 0, waitSeconds: 50),
            OrderWait(id: 1, store: CafeWording.harbour, queueLength: 4, waitSeconds: 200),
        ]
        let binned = HeatMapBinnedOrders(orders: orders)

        #expect(binned.queueDomain == 0 ... 6)
        #expect(binned.waitDomain == 50 ... 250)
        #expect(binned.cells.map(\.orders).reduce(0, +) == orders.count)
    }
}
