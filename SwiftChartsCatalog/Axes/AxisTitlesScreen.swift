import Accessibility
import Charts
import SwiftUI

/// "Axis titles": `chartXAxisLabel` and `chartYAxisLabel` naming each axis and its unit, moved with
/// `position:` and `alignment:`.
struct AxisTitlesScreen: View {
    let screen: CatalogScreen
    var orders = CafeData.orderWaits
    @State private var model = AxisTitlesViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var deviceTextSize

    var body: some View {
        let textSize = model.effectiveTextSize(device: deviceTextSize)
        let wording = model.drawnWording(at: textSize)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Queue and wait, per order",
            message: AxisTitlesSummary(orders: orders, locale: locale).headline,
            explanation: """
            chartXAxisLabel and chartYAxisLabel give each axis a title naming what it measures and its unit, \
            so the numbers along the axis can stay bare. position: picks the side of the plot a title sits on, \
            and alignment: where along that side it lines up.
            """,
            snippets: model.snippets
        ) {
            AxisTitlesChart(
                orders: orders,
                xTitle: wording.xTitle,
                yTitle: wording.yTitle,
                xPosition: model.xPosition.annotationPosition,
                yPosition: model.yPosition.annotationPosition,
                alignment: model.alignment.alignment,
                locale: locale
            )
            .chartEnvironment(model.chartEnvironment)
        } controls: {
            AxisTitlesControls(model: model, wordingNote: model.wordingNote(at: textSize))
        }
    }
}

/// The pickers: each title's position, their alignment, their wording, and the chart's text size.
struct AxisTitlesControls: View {
    @Bindable var model: AxisTitlesViewModel
    /// Why the long titles are not drawn, when they are chosen and the text size rules them out.
    let wordingNote: String?

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "X title position", selection: $model.xPosition) {
                ForEach(AxisTitlesXPosition.allCases) { Text($0.rawValue).tag($0) }
            }
            LabeledSegmentedPicker(title: "Y title position", selection: $model.yPosition) {
                ForEach(AxisTitlesYPosition.allCases) { Text($0.rawValue).tag($0) }
            }
            LabeledSegmentedPicker(title: "Alignment of both titles", selection: $model.alignment) {
                ForEach(AxisTitlesAlignment.allCases) { Text($0.rawValue).tag($0) }
            }
            LabeledSegmentedPicker(title: "Titles", selection: $model.wording) {
                ForEach(AxisTitlesWording.allCases) { Text($0.rawValue).tag($0) }
            }
            if let wordingNote {
                Text(wordingNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            LabeledMenuPicker(title: "Chart text size", selection: $model.textSize) {
                ForEach(AxisTitlesTextSize.allCases) { Text($0.rawValue).tag($0) }
            }
        }
    }
}

/// One point per order, queue against wait, with a title on each axis; or a placeholder with no orders.
struct AxisTitlesChart: View {
    let orders: [OrderWait]
    let xTitle: String
    let yTitle: String
    let xPosition: AnnotationPosition
    let yPosition: AnnotationPosition
    let alignment: Alignment?
    let locale: Locale
    /// The chart's own text size: the one the text size picker forces, or the device's.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var maxWait: Int {
        orders.map(\.waitSeconds).max() ?? 0
    }

    /// One café's orders, then the other's, each by queue length: the order VoiceOver walks them in.
    private var ordered: [OrderWait] {
        orders.sorted { ($0.store, $0.queueLength, $0.id) < ($1.store, $1.queueLength, $1.id) }
    }

    var body: some View {
        if orders.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "person.3",
                description: Text("Each order appears here as a point: the queue when it was placed, and the wait.")
            )
        } else {
            // snippet:axis-titles-titles
            Chart(ordered) { order in
                Plot {
                    // A clear band the full height of the plot at the order's queue: every element then has the
                    // same top, so the orders are visited along the queue axis, not by their waits.
                    RectangleMark(x: .value(CafeWording.queueAxisTitle, order.queueLength), width: .fixed(1))
                        .foregroundStyle(.clear)
                    PointMark(
                        x: .value(CafeWording.queueAxisTitle, order.queueLength),
                        y: .value(CafeWording.waitAxisTitle, order.waitSeconds)
                    )
                    .foregroundStyle(by: .value(CafeWording.store, order.store))
                    .symbol(by: .value(CafeWording.store, order.store))
                }
                .accessibilityLabel("\(order.store), \(CafeWording.people(order.queueLength, locale: locale)) queuing")
                .accessibilityValue(CafeWording.seconds(order.waitSeconds, locale: locale))
            }
            // Each title names what its axis measures and the unit, so the tick labels stay bare numbers.
            // With no position or alignment, each title goes where the framework puts it by default.
            .chartXAxisLabel(xTitle, position: xPosition, alignment: alignment)
            .chartYAxisLabel(yTitle, position: yPosition, alignment: alignment)
            // end
            // At the accessibility sizes the top value label would sit under a title above the plot, so the
            // labels stop a step below the top of the scale, which is pinned where the framework puts it.
            .chartYScale(domain: 0 ... AxisTitlesYValues.top(maxWait: maxWait))
            // The queue axis worked out once, for the chart and the descriptor (11 people → 0 to 15).
            .chartXScale(domain: AxisTitlesChartDescriptor.queueDomain(for: ordered))
            .chartYAxis {
                if let values = AxisTitlesYValues.values(maxWait: maxWait, at: dynamicTypeSize) {
                    AxisMarks(values: values)
                } else {
                    AxisMarks()
                }
            }
            // Both cafés, in a fixed order, so each keeps its colour and symbol whatever order the data is in.
            .chartForegroundStyleScale(domain: AxisTitlesWords.cafes, mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale(domain: AxisTitlesWords.cafes, mapping: CafeSeriesStyle.symbol(for:))
            .accessibilityChartDescriptor(
                AxisTitlesChartDescriptor(orders: ordered, xTitle: xTitle, yTitle: yTitle, locale: locale)
            )
        }
    }
}

/// What the chart says in words: its headline and the summary the Audio Graph speaks.
nonisolated struct AxisTitlesSummary {
    let orders: [OrderWait]
    let locale: Locale

    /// The longest wait, and every order that had it.
    var longestWaits: [OrderWait] {
        guard let longest = orders.map(\.waitSeconds).max() else { return [] }
        return orders.filter { $0.waitSeconds == longest }
    }

    /// "11 people", or "10 people and 11 people" when the longest wait came at more than one queue length.
    private var queuesAtLongestWait: String {
        let queues = Set(longestWaits.map(\.queueLength)).sorted()
        return CafeWording.list(queues.map { CafeWording.people($0, locale: locale) })
    }

    /// The message in a sentence, with a figure that can be found in the chart: the highest point.
    var headline: String {
        guard let longest = longestWaits.first?.waitSeconds else { return "No orders yet." }
        return "The longest wait, \(CafeWording.seconds(longest, locale: locale)), came with \(queuesAtLongestWait) queuing."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let longest = longestWaits.first?.waitSeconds,
              let shortest = orders.map(\.waitSeconds).min(),
              let shortestQueue = orders.map(\.queueLength).min(),
              let longestQueue = orders.map(\.queueLength).max()
        else { return "No orders yet." }
        let cafes = Set(orders.map(\.store)).count
        return "\(CafeWording.orders(orders.count, locale: locale)) at \(CafeWording.cafes(cafes, locale: locale)). "
            + "Queues from \(shortestQueue.formatted(.number.locale(locale))) to "
            + "\(CafeWording.people(longestQueue, locale: locale)), "
            + "waits from \(shortestWaitText(shortest)) to \(CafeWording.seconds(longest, locale: locale)). "
            + "The longest wait came with \(queuesAtLongestWait) queuing."
    }

    private func shortestWaitText(_ seconds: Int) -> String {
        seconds.formatted(.number.locale(locale))
    }
}

/// The chart for the Audio Graph: both axes numbers, titled as drawn, one series per café.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct AxisTitlesChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [OrderWait]
    let xTitle: String
    let yTitle: String
    let locale: Locale

    /// The queue axis as drawn, from zero to the longest queue rounded up to the axis step.
    static func queueDomain(for orders: [OrderWait]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.queueLength))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let summary = AxisTitlesSummary(orders: orders, locale: locale)
        // Both scales as drawn: the queue axis's rounded top, and the wait axis pinned to the hundred above the
        // longest wait.
        let xAxis = AXNumericDataAxisDescriptor(
            title: xTitle,
            range: Self.queueDomain(for: orders),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.people(_:locale:)) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: yTitle,
            range: 0 ... Double(AxisTitlesYValues.top(maxWait: orders.map(\.waitSeconds).max() ?? 0)),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.seconds(_:locale:)) }
        var stores: [String] = []
        for order in orders where !stores.contains(order.store) {
            stores.append(order.store)
        }
        let series = stores.map { store in
            AXDataSeriesDescriptor(
                name: store,
                isContinuous: false,
                dataPoints: orders.filter { $0.store == store }.map {
                    AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds))
                }
            )
        }
        return AXChartDescriptor(
            title: "Queue length and wait for each order, by café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }

    /// The Titles picker changes the axis titles after the descriptor is made, so the one already made is
    /// given the new titles, and everything else a fresh descriptor would have.
    func updateChartDescriptor(_ descriptor: AXChartDescriptor) {
        let fresh = makeChartDescriptor()
        descriptor.title = fresh.title
        descriptor.summary = fresh.summary
        descriptor.xAxis = fresh.xAxis
        descriptor.yAxis = fresh.yAxis
        descriptor.series = fresh.series
    }
}

#Preview("Orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "axes/axis-titles") {
            AxisTitlesScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    AxisTitlesChart(
        orders: [], xTitle: CafeWording.queueAxisTitle, yTitle: CafeWording.waitAxisTitle,
        xPosition: .automatic, yPosition: .automatic, alignment: nil, locale: .current
    )
}
