import Accessibility
import Charts
import SwiftUI

/// "Encoding data": the five `by:` modifiers, each carrying the same two cafés, one at a time.
struct EncodingDataScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = EncodingDataViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.summary(locale: locale).caption,
            message: viewModel.summary(locale: locale).headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            EncodingDataChart(viewModel: viewModel, locale: locale)
        } controls: {
            EncodingDataControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.characteristic) {
            // The scale and often the kind of mark change, so say so, then the headline.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The picker for which characteristic carries the café.
struct EncodingDataControls: View {
    @Bindable var viewModel: EncodingDataViewModel

    var body: some View {
        ControlsSection {
            LabeledMenuPicker(title: "Café shown by", selection: $viewModel.characteristic) {
                ForEach(EncodingDataCharacteristic.allCases) { characteristic in
                    Text(characteristic.title).tag(characteristic)
                }
            }
        }
    }
}

/// The chart for the current characteristic, or a placeholder when there is nothing to draw.
struct EncodingDataChart: View {
    let viewModel: EncodingDataViewModel
    let locale: Locale

    var body: some View {
        if viewModel.showsPlaceholder {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each café's cups for the week appear here.")
            )
        } else {
            let summary = viewModel.summary(locale: locale)
            Group {
                switch viewModel.characteristic {
                case .colour: EncodingDataColourChart(stores: viewModel.stores, summary: summary)
                case .position: EncodingDataPositionChart(stores: viewModel.stores, summary: summary)
                case .symbol: EncodingDataSymbolChart(stores: viewModel.stores, summary: summary)
                case .symbolSize: EncodingDataSymbolSizeChart(stores: viewModel.stores, summary: summary)
                case .lineStyle: EncodingDataLineStyleChart(stores: viewModel.stores, summary: summary)
                }
            }
            .encodingDataDayAxis(locale: locale)
            // One value axis for every encoding and for the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(EncodingDataChartDescriptor(
                stores: viewModel.stores, mark: viewModel.characteristic.mark, locale: locale
            ))
        }
    }
}

/// Every café, in a fixed order, so each keeps its colour, shape, size or dash.
private let encodingDataCafes = [CafeWording.harbour, CafeWording.station]

/// The x value every mark shares: the whole day, cut in the UTC calendar the data was made in.
private func encodingDataDay(_ day: DailySales) -> PlottableValue<Date> {
    .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar)
}

private enum EncodingDataMetrics {
    /// The two point sizes, in square points of area: different enough to tell apart at a glance.
    static let smallPoint: CGFloat = 30
    static let largePoint: CGFloat = 150
}

/// Colour carries the café, on lines.
struct EncodingDataColourChart: View {
    let stores: [StoreSales]
    let summary: EncodingDataSummary
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    var body: some View {
        // snippet:encoding-data-colour
        Chart {
            ForEach(stores) { store in
                ForEach(store.days) { day in
                    Plot {
                        LineMark(x: encodingDataDay(day), y: .value(CafeWording.cups, day.cups))
                    }
                    .accessibilityLabel(summary.elementLabel(store: store.store, day: day.day))
                    .accessibilityValue(summary.elementValue(cups: day.cups))
                }
                .foregroundStyle(by: .value(CafeWording.store, store.store))
                // encodingDataSymbol(by:if:) is a helper defined in this file: symbol(by:) while the condition holds.
                // Never colour alone when the person has asked for more: add a shape too.
                .encodingDataSymbol(by: .value(CafeWording.store, store.store), if: differentiateWithoutColor)
            }
        }
        .chartForegroundStyleScale(domain: encodingDataCafes, mapping: CafeSeriesStyle.colour(for:))
        // end
    }
}

/// Position carries the café: bars side by side within each day.
struct EncodingDataPositionChart: View {
    let stores: [StoreSales]
    let summary: EncodingDataSummary

    var body: some View {
        // snippet:encoding-data-position
        Chart {
            ForEach(stores) { store in
                ForEach(store.days) { day in
                    Plot {
                        BarMark(x: encodingDataDay(day), y: .value(CafeWording.cups, day.cups))
                    }
                    .accessibilityLabel(summary.elementLabel(store: store.store, day: day.day))
                    .accessibilityValue(summary.elementValue(cups: day.cups))
                }
                // Side by side instead of stacked. No legend: nothing here names the bars.
                .position(by: .value(CafeWording.store, store.store), axis: .horizontal)
            }
        }
        // end
    }
}

/// Symbol carries the café, on lines.
struct EncodingDataSymbolChart: View {
    let stores: [StoreSales]
    let summary: EncodingDataSummary

    var body: some View {
        // snippet:encoding-data-symbol
        Chart {
            ForEach(stores) { store in
                ForEach(store.days) { day in
                    Plot {
                        LineMark(x: encodingDataDay(day), y: .value(CafeWording.cups, day.cups))
                    }
                    .accessibilityLabel(summary.elementLabel(store: store.store, day: day.day))
                    .accessibilityValue(summary.elementValue(cups: day.cups))
                }
                .symbol(by: .value(CafeWording.store, store.store))
            }
        }
        .chartSymbolScale(domain: encodingDataCafes, mapping: CafeSeriesStyle.symbol(for:))
        // end
    }
}

/// Symbol size carries the café, on points.
struct EncodingDataSymbolSizeChart: View {
    let stores: [StoreSales]
    let summary: EncodingDataSummary

    var body: some View {
        // snippet:encoding-data-symbol-size
        Chart {
            ForEach(stores) { store in
                ForEach(store.days) { day in
                    Plot {
                        PointMark(x: encodingDataDay(day), y: .value(CafeWording.cups, day.cups))
                    }
                    .accessibilityLabel(summary.elementLabel(store: store.store, day: day.day))
                    .accessibilityValue(summary.elementValue(cups: day.cups))
                }
                .symbolSize(by: .value(CafeWording.store, store.store))
            }
        }
        // A size for each café, in square points; the default sizes are too large.
        .chartSymbolSizeScale([
            CafeWording.harbour: EncodingDataMetrics.smallPoint,
            CafeWording.station: EncodingDataMetrics.largePoint,
        ])
        // end
    }
}

/// Line style carries the café: a dash pattern each.
struct EncodingDataLineStyleChart: View {
    let stores: [StoreSales]
    let summary: EncodingDataSummary

    var body: some View {
        // snippet:encoding-data-line-style
        Chart {
            ForEach(stores) { store in
                ForEach(store.days) { day in
                    Plot {
                        LineMark(x: encodingDataDay(day), y: .value(CafeWording.cups, day.cups))
                    }
                    .accessibilityLabel(summary.elementLabel(store: store.store, day: day.day))
                    .accessibilityValue(summary.elementValue(cups: day.cups))
                }
                .lineStyle(by: .value(CafeWording.store, store.store))
            }
        }
        .chartLineStyleScale(domain: encodingDataCafes)
        // end
    }
}

extension ChartContent {
    /// `symbol(by:)` only while `condition` holds, so a chart can add shapes when colour is not enough.
    @ChartContentBuilder
    func encodingDataSymbol(by value: PlottableValue<String>, if condition: Bool) -> some ChartContent {
        if condition {
            symbol(by: value)
        } else {
            self
        }
    }
}

extension View {
    /// One label per day, written in the data's time zone and the view's locale, and shorter at the
    /// largest text sizes so seven of them still fit on a phone.
    func encodingDataDayAxis(locale: Locale) -> some View {
        modifier(EncodingDataDayAxis(locale: locale))
    }
}

private struct EncodingDataDayAxis: ViewModifier {
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        let format = dynamicTypeSize >= .accessibility2 ? style.weekday(.narrow) : style.weekday(.abbreviated)
        content
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    // Every day is labelled, so the label is centred under its day.
                    AxisValueLabel(format: format, centered: true)
                }
            }
    }
}

/// The chart for the Audio Graph: one series per café over the written-out days, with cups as the unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct EncodingDataChartDescriptor: AXChartDescriptorRepresentable {
    let stores: [StoreSales]
    let mark: EncodingDataMark
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = EncodingDataSummary(stores: stores, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: summary.days.map(summary.dayName)
        )
        // The chart's value axis as drawn, from zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = stores.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: mark.isContinuous,
                dataPoints: store.days.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: summary.descriptorTitle,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Encoding data") {
    NavigationStack {
        if let screen = Catalog.screen(id: "mark-modifiers/encoding-data") {
            EncodingDataScreen(screen: screen)
        }
    }
}

#Preview("Each characteristic") {
    ScrollView {
        ForEach(EncodingDataCharacteristic.allCases) { characteristic in
            ChartPanel {
                EncodingDataChart(viewModel: EncodingDataViewModel(characteristic: characteristic), locale: .current)
            }
        }
    }
}

#Preview("No sales") {
    EncodingDataChart(viewModel: EncodingDataViewModel(stores: []), locale: .current)
}
