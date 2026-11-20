import Accessibility
import Charts
import SwiftUI

/// "Symbol and size scales": `chartSymbolScale` chooses the shape each value gets, and
/// `chartSymbolSizeScale(range:)` the areas a number maps to.
struct SymbolSizeScalesScreen: View {
    let screen: CatalogScreen
    var slots = CafeData.hourlyOrders
    @State private var model = SymbolSizeScalesViewModel()
    /// Read here and passed in, so the headline, elements and Audio Graph write numbers in it.
    @Environment(\.locale) private var locale

    var body: some View {
        let headline = SymbolSizeScalesSummary(slots: slots, locale: locale).headline
        CatalogScreenScaffold(
            screen: screen,
            caption: "Orders by weekday and time of day",
            message: headline,
            explanation: """
            chartSymbolScale chooses the shape each value gets: a filled circle for Monday to Friday and the \
            picked shape for the weekend, in the order the legend lists them. chartSymbolSizeScale(range:) sets \
            the areas, in square points, for zero orders and for the most orders: the size scale starts at zero, \
            so any slot with orders draws larger than the low end. Without it the default range is too large \
            for a chart this dense.
            """,
            snippets: model.snippets
        ) {
            SymbolSizeScalesChart(
                slots: slots, weekendShape: model.weekendShape, sizeRange: model.sizeRange, locale: locale
            )
        } controls: {
            SymbolSizeScalesControls(model: model, locale: locale)
        }
        .onChange(of: model.weekendShape) {
            SymbolSizeScalesAnnouncer.announce(model.shapeAnnouncement(headline: headline))
        }
        .onChange(of: model.usesDefaultRange) {
            SymbolSizeScalesAnnouncer.announce(model.rangeAnnouncement(headline: headline, locale: locale))
        }
    }
}

/// The weekend's shape picker, the two size sliders and the default-range mistake.
struct SymbolSizeScalesControls: View {
    @Bindable var model: SymbolSizeScalesViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Weekend shape", selection: $model.weekendShape) {
                ForEach(SymbolSizeScalesShape.allCases) { shape in
                    Text(shape.rawValue).tag(shape)
                }
            }
            LabeledSlider(
                title: "Smallest symbol", value: $model.smallestArea,
                range: SymbolSizeScalesViewModel.smallestAreaRange, step: 4,
                valueText: model.smallestAreaText(locale: locale),
                spokenValue: model.smallestAreaSpoken(locale: locale)
            )
            .disabled(model.usesDefaultRange)
            LabeledSlider(
                title: "Largest symbol", value: $model.largestArea,
                range: SymbolSizeScalesViewModel.largestAreaRange, step: 20,
                valueText: model.largestAreaText(locale: locale),
                spokenValue: model.largestAreaSpoken(locale: locale)
            )
            .disabled(model.usesDefaultRange)
            MistakeToggle(title: "Leave the size range at its default", isShowingMistake: $model.usesDefaultRange)
        }
    }
}

/// One point per slot, its shape from the part of the week and its size from the orders,
/// or a placeholder when there is no data.
struct SymbolSizeScalesChart: View {
    let slots: [HourlyOrders]
    let weekendShape: SymbolSizeScalesShape
    /// The size scale's range in square points, or `nil` to draw the default range (the mistake).
    let sizeRange: ClosedRange<Double>?
    let locale: Locale

    var body: some View {
        if slots.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "cup.and.saucer",
                description: Text("Orders appear here, one symbol per weekday and time of day.")
            )
        } else {
            Group {
                if let sizeRange {
                    let range = CGFloat(sizeRange.lowerBound) ... CGFloat(sizeRange.upperBound)
                    // snippet:symbol-size-scales-scales
                    Chart(slots) { slot in
                        SymbolSizeScalesPoint(slot: slot, locale: locale)
                    }
                    // Which shape each part of the week gets, in legend order.
                    .chartSymbolScale([
                        SymbolSizeScalesDayType.weekday: AnyChartSymbolShape(.circle),
                        SymbolSizeScalesDayType.weekend: weekendShape.symbol,
                    ])
                    // The areas, in square points, for zero orders and for the most: the domain starts at zero.
                    .chartSymbolSizeScale(range: range)
                    // end
                    // The weekday names outside the plot, where the first column of symbols cannot cover them.
                    .chartYAxis { AxisMarks(preset: .aligned, position: .leading) }
                } else {
                    // snippet:symbol-size-scales-default-range
                    Chart(slots) { slot in
                        SymbolSizeScalesPoint(slot: slot, locale: locale)
                    }
                    .chartSymbolScale([
                        SymbolSizeScalesDayType.weekday: AnyChartSymbolShape(.circle),
                        SymbolSizeScalesDayType.weekend: weekendShape.symbol,
                    ])
                    // No chartSymbolSizeScale(range:): the default range is too large for this chart,
                    // so neighbouring symbols run into each other.
                    // end
                    .chartYAxis { AxisMarks(preset: .aligned, position: .leading) }
                }
            }
            .accessibilityChartDescriptor(
                SymbolSizeScalesDescriptor(slots: slots, weekendShape: weekendShape, sizeRange: sizeRange, locale: locale)
            )
        }
    }
}

/// One slot's point. The Plot makes it one accessibility element with its own label and value.
struct SymbolSizeScalesPoint: ChartContent {
    let slot: HourlyOrders
    let locale: Locale

    var body: some ChartContent {
        // snippet:symbol-size-scales-marks
        Plot {
            PointMark(
                x: .value(CafeWording.slot, slot.slot),
                y: .value(CafeWording.weekday, slot.weekday)
            )
            // A category picks the shape; a number picks the size. The scales decide which.
            .symbol(by: .value(SymbolSizeScalesWording.dayType, SymbolSizeScalesDayType(weekday: slot.weekday)))
            .symbolSize(by: .value(CafeWording.orders, slot.orders))
        }
        // end
        .accessibilityLabel("\(SymbolSizeScalesWording.fullName(slot.weekday)), \(slot.slot)")
        .accessibilityValue(CafeWording.orders(slot.orders, locale: locale))
    }
}

// snippet:symbol-size-scales-shapes
extension SymbolSizeScalesShape {
    /// Filled and outlined symbols are different types, so the scale's shapes are type-erased.
    nonisolated var symbol: AnyChartSymbolShape {
        switch self {
        case .square: AnyChartSymbolShape(.square)
        case .diamond: AnyChartSymbolShape(.diamond)
        case .triangle: AnyChartSymbolShape(.triangle)
        case .outline: AnyChartSymbolShape(.circle.strokeBorder(lineWidth: 2))
        }
    }
}

// end

/// The chart for the Audio Graph: one series per weekday over the times of day, and a summary that
/// says which shape each part of the week has and the range of sizes drawn.
nonisolated struct SymbolSizeScalesDescriptor: AXChartDescriptorRepresentable {
    let slots: [HourlyOrders]
    let weekendShape: SymbolSizeScalesShape
    let sizeRange: ClosedRange<Double>?
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = SymbolSizeScalesSummary(slots: slots, locale: locale)
        let locale = locale
        let times = unique(slots.map(\.slot))
        let weekdays = unique(slots.map(\.weekday))
        let series = weekdays.map { weekday in
            AXDataSeriesDescriptor(
                name: SymbolSizeScalesWording.fullName(weekday),
                isContinuous: false,
                dataPoints: slots.filter { $0.weekday == weekday }.map { AXDataPoint(x: $0.slot, y: Double($0.orders)) }
            )
        }
        return AXChartDescriptor(
            title: "Orders by weekday and time of day",
            summary: summary.audioGraphSummary(weekendShape: weekendShape, sizeRange: sizeRange),
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.slot, categoryOrder: times),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.orders,
                range: 0 ... Double(summary.mostOrders),
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale, as: CafeWording.orders(_:locale:)) },
            additionalAxes: [],
            series: series
        )
    }

    /// The values in the order they first appear.
    private func unique(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
enum SymbolSizeScalesAnnouncer {
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/symbol-and-size-scales") {
            SymbolSizeScalesScreen(screen: screen)
        }
    }
}

#Preview("Default range") {
    SymbolSizeScalesChart(slots: CafeData.hourlyOrders, weekendShape: .outline, sizeRange: nil, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No orders") {
    SymbolSizeScalesChart(slots: [], weekendShape: .diamond, sizeRange: 16 ... 300, locale: .current)
}
