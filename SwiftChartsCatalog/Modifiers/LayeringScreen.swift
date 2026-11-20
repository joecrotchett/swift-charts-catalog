import Accessibility
import Charts
import SwiftUI

/// "Layering": `zIndex` decides which of two overlapping marks is drawn in front, against the default,
/// the order the marks are written in.
struct LayeringScreen: View {
    let screen: CatalogScreen
    @State private var model = LayeringViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and
    /// dates the way the chart's axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = model.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold, first week of March",
            message: summary.headline,
            explanation: """
            Marks are drawn in the order they are written, so Harbour's narrow bars, written after Station's wide ones, \
            sit in front. zIndex changes that: every mark starts at 0, and a higher value is drawn over a lower one \
            wherever it is written. Raise Station above 0 and its wide bars cover Harbour's wherever Station sold as many cups; \
            lower it below 0 and they fall behind the grid lines too.
            """
        ) {
            LayeringChart(summary: summary)
        } controls: {
            LayeringControls(model: model, summary: summary)
        }
    }
}

/// The slider for Station's zIndex. It speaks the setting and then the headline, so moving it needs no
/// separate announcement.
struct LayeringControls: View {
    @Bindable var model: LayeringViewModel
    let summary: LayeringSummary

    var body: some View {
        ControlsSection {
            LabeledSlider(
                title: "Station's zIndex",
                value: $model.stationLayer,
                range: LayeringViewModel.layerRange,
                step: LayeringViewModel.layerStep,
                valueText: summary.layerText,
                spokenValue: summary.spokenSliderValue
            )
            Text("Harbour's bars keep the default zIndex, 0.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Bar widths for this chart only: Station wide, Harbour narrow, so the narrow bar can sit inside the wide one.
private enum LayeringBarWidth {
    static let station: MarkDimension = .ratio(0.8)
    static let harbour: MarkDimension = .ratio(0.4)
}

/// Two cafés' bars for each day, unstacked so they overlap, or a placeholder when nothing sold.
struct LayeringChart: View {
    let summary: LayeringSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The weekday fits seven times across a phone at ordinary sizes; at the accessibility sizes, the day alone.
    private var dayLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: summary.locale, timeZone: CafeData.calendar.timeZone)
        return dynamicTypeSize >= .accessibility1 ? style.day() : style.weekday(.abbreviated)
    }

    var body: some View {
        if summary.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each day's cups at the two cafés appear here, one bar each.")
            )
        } else {
            let stationLayer = summary.stationLayer
            // snippet:layering-zindex
            Chart {
                // Written first, so by default it is drawn first, behind.
                ForEach(summary.station) { day in
                    Plot {
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups),
                            width: LayeringBarWidth.station,
                            stacking: .unstacked
                        )
                    }
                    .accessibilityLabel(summary.label(day, store: CafeWording.station))
                    .accessibilityValue(summary.stationValue(day))
                }
                .foregroundStyle(by: .value(CafeWording.store, CafeWording.station))
                // Above Harbour's default of 0, Station is drawn in front, wherever it is written.
                .zIndex(stationLayer)

                // Written second, so by default it is drawn in front.
                ForEach(summary.harbour) { day in
                    Plot {
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups),
                            width: LayeringBarWidth.harbour,
                            stacking: .unstacked
                        )
                    }
                    .accessibilityLabel(summary.label(day, store: CafeWording.harbour))
                    .accessibilityValue(summary.harbourValue(day))
                }
                .foregroundStyle(by: .value(CafeWording.store, CafeWording.harbour))
            }
            // end
            .chartForegroundStyleScale(domain: [CafeWording.harbour, CafeWording.station], mapping: CafeSeriesStyle.colour(for:))
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: dayLabelFormat, centered: true)
                }
            }
            // Harbour's element values change with the order while the data's ids do not: a new identity
            // makes VoiceOver read the new words.
            .id(summary.stationIsInFront)
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(LayeringChartDescriptor(summary: summary))
        }
    }
}

/// The chart for the Audio Graph: the days written out, both cafés as series, values with their unit.
nonisolated struct LayeringChartDescriptor: AXChartDescriptorRepresentable {
    let summary: LayeringSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let days = summary.harbour.map(\.day)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map(summary.dayName)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = [
            (CafeWording.harbour, summary.harbour),
            (CafeWording.station, summary.station),
        ].map { name, days in
            AXDataSeriesDescriptor(
                name: name,
                isContinuous: false,
                dataPoints: days.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold each day of the first week of March, Harbour and Station cafés",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Layering") {
    NavigationStack {
        if let screen = Catalog.screen(id: "mark-modifiers/layering") {
            LayeringScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    LayeringChart(summary: LayeringSummary(harbour: [], station: [], stationLayer: 0, locale: .current))
}
