import Accessibility
import Charts
import SwiftUI

/// "Heat map": rectangles on two category axes coloured by a number, and the two-dimensional
/// histogram, the same form on two number axes with binned values.
struct HeatMapScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: HeatMapViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, viewModel: HeatMapViewModel = HeatMapViewModel()) {
        self.screen = screen
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            HeatMapChart(viewModel: viewModel)
        } controls: {
            HeatMapControls(viewModel: viewModel)
        }
        // Another version is other data on other scales: said aloud, for people who cannot see it change.
        .onChange(of: viewModel.version) {
            AccessibilityNotification.Announcement(viewModel.versionAnnouncement(locale: locale)).post()
        }
        // The mistake redraws the axes, and in the binned version the scales: said aloud too.
        // The cell size slider only restyles the cells and speaks its own value, so it is not.
        .onChange(of: viewModel.leavesDefaults) {
            AccessibilityNotification.Announcement(viewModel.defaultsAnnouncement(locale: locale)).post()
        }
    }
}

/// The version picker, the cell size and the mistake.
struct HeatMapControls: View {
    @Bindable var viewModel: HeatMapViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Axes", selection: $viewModel.version) {
                ForEach(HeatMapVersion.allCases) { version in
                    Text(version.rawValue).tag(version)
                }
            }
            LabeledSlider(
                title: "Cell size",
                value: $viewModel.cellRatio,
                range: HeatMapViewModel.cellRatioRange,
                step: HeatMapViewModel.cellRatioStep,
                valueText: viewModel.cellSizeText(locale: locale),
                spokenValue: viewModel.spokenCellSize(locale: locale)
            )
            .disabled(viewModel.leavesDefaults)
            MistakeToggle(title: "Leave the defaults", isShowingMistake: $viewModel.leavesDefaults)
        }
    }
}

/// The heat map for the current settings, or a placeholder when there are no orders to show.
struct HeatMapChart: View {
    let viewModel: HeatMapViewModel
    @Environment(\.locale) private var locale

    var body: some View {
        let grid = viewModel.grid(locale: locale)
        let descriptor = HeatMapChartDescriptor(grid: grid, leavesDefaults: viewModel.leavesDefaults, locale: locale)
        if grid.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "square.grid.3x3",
                description: Text("Orders appear here as a grid of cells, each coloured by how many it holds.")
            )
        } else {
            switch (viewModel.version, viewModel.leavesDefaults) {
            case (.categories, false):
                HeatMapCategoryChart(cells: viewModel.hourlyOrders, cellRatio: viewModel.cellRatio)
                    .accessibilityChartDescriptor(descriptor)
            case (.categories, true):
                HeatMapDefaultsChart(cells: viewModel.hourlyOrders)
                    .accessibilityChartDescriptor(descriptor)
            case (.binned, false):
                HeatMapBinnedChart(binned: viewModel.binned, cellRatio: viewModel.cellRatio)
                    .accessibilityChartDescriptor(descriptor)
            case (.binned, true):
                HeatMapBinnedDefaultsChart(binned: viewModel.binned)
                    .accessibilityChartDescriptor(descriptor)
            }
        }
    }
}

/// A category on each axis: one cell per weekday and slot, coloured by its orders.
struct HeatMapCategoryChart: View {
    let cells: [HourlyOrders]
    /// The share of its band a cell fills, across and down.
    let cellRatio: Double
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // snippet:heat-map-categories
        Chart(cells) { cell in
            // A Plot around each cell makes it one element: "8 am, Tuesday, 80 orders".
            Plot {
                RectangleMark(
                    x: .value(CafeWording.slot, cell.slot),
                    y: .value(CafeWording.weekday, cell.weekday),
                    // A ratio of the band. 1 makes the cells touch; the default is 70%.
                    width: .ratio(cellRatio),
                    height: .ratio(cellRatio)
                )
                // A number as colour: one gradient, and a gradient legend.
                .foregroundStyle(by: .value(CafeWording.orders, cell.orders))
            }
            .accessibilityLabel(HeatMapWording.slotCell(slot: cell.slot, weekday: cell.weekday))
            .accessibilityValue(HeatMapWording.orders(cell.orders, locale: locale))
        }
        // Row labels outside the plot, so the cells get the whole row.
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading)
        }
        // end
        .chartXAxis {
            // At the accessibility text sizes a slot's name is wider than its column: turn it.
            if dynamicTypeSize.isAccessibilitySize {
                AxisMarks {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(orientation: .vertical)
                }
            } else {
                AxisMarks()
            }
        }
    }
}

/// The mistake: the same marks with no size and the default axis.
struct HeatMapDefaultsChart: View {
    let cells: [HourlyOrders]
    @Environment(\.locale) private var locale

    var body: some View {
        // snippet:heat-map-defaults
        Chart(cells) { cell in
            Plot {
                // No width or height: each cell is 70% of its band.
                RectangleMark(
                    x: .value(CafeWording.slot, cell.slot),
                    y: .value(CafeWording.weekday, cell.weekday)
                )
                .foregroundStyle(by: .value(CafeWording.orders, cell.orders))
            }
            .accessibilityLabel(HeatMapWording.slotCell(slot: cell.slot, weekday: cell.weekday))
            .accessibilityValue(HeatMapWording.orders(cell.orders, locale: locale))
        }
        // No chartYAxis: the weekday names are drawn inside the plot, above each row,
        // and the cells get what is left.
        // end
    }
}

/// A number on each axis, binned: one cell per pair of bins, coloured by the orders counted into it.
struct HeatMapBinnedChart: View {
    let binned: HeatMapBinnedOrders
    /// The share of its bin a cell fills, across and up.
    let cellRatio: Double
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // Fewer labels at the accessibility text sizes, still on bin boundaries.
        let sparse = dynamicTypeSize.isAccessibilitySize
        // snippet:heat-map-binned
        Chart(binned.cells) { cell in
            Plot {
                RectangleMark(
                    // A bin as the value: the cell spans it on a continuous number axis.
                    x: .value(CafeWording.queueAxisTitle, cell.queue),
                    y: .value(CafeWording.waitAxisTitle, cell.wait),
                    width: .ratio(cellRatio),
                    height: .ratio(cellRatio)
                )
                .foregroundStyle(by: .value(CafeWording.orders, cell.orders))
            }
            .accessibilityLabel(HeatMapWording.binnedCell(queue: cell.queue, wait: cell.wait, locale: locale))
            .accessibilityValue(HeatMapWording.orders(cell.orders, locale: locale))
        }
        // The scales cover the bins and nothing more: a number scale would otherwise start at zero.
        .chartXScale(domain: binned.queueDomain)
        .chartYScale(domain: binned.waitDomain)
        // Labels and grid lines at the bin boundaries, not at the round numbers the axis would pick.
        .chartXAxis {
            AxisMarks(values: HeatMapBinnedOrders.axisValues(
                binned.queueThresholds, binSize: HeatMapBinnedOrders.queueBinSize, sparse: sparse
            ))
        }
        .chartYAxis {
            AxisMarks(values: HeatMapBinnedOrders.axisValues(
                binned.waitThresholds, binSize: HeatMapBinnedOrders.waitBinSize, sparse: sparse
            ))
        }
        // end
        .chartXAxisLabel(CafeWording.queueAxisTitle)
        .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
    }
}

/// The binned cells with nothing else set.
struct HeatMapBinnedDefaultsChart: View {
    let binned: HeatMapBinnedOrders
    @Environment(\.locale) private var locale

    var body: some View {
        // snippet:heat-map-binned-defaults
        Chart(binned.cells) { cell in
            Plot {
                RectangleMark(
                    x: .value(CafeWording.queueAxisTitle, cell.queue),
                    y: .value(CafeWording.waitAxisTitle, cell.wait)
                )
                .foregroundStyle(by: .value(CafeWording.orders, cell.orders))
            }
            .accessibilityLabel(HeatMapWording.binnedCell(queue: cell.queue, wait: cell.wait, locale: locale))
            .accessibilityValue(HeatMapWording.orders(cell.orders, locale: locale))
        }
        // end
        .chartXAxisLabel(CafeWording.queueAxisTitle)
        .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
    }
}

#Preview("Categories") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/heat-map") {
            HeatMapScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    HeatMapChart(viewModel: HeatMapViewModel(hourlyOrders: [], orderWaits: []))
}
