import Accessibility
import Charts
import SwiftUI

/// "Trend line": a function `LinePlot` over a `PointPlot`, fitted in the model and limited to the data
/// with `domain:`.
struct TrendLineScreen: View {
    let screen: CatalogScreen
    @State private var model = TrendLineViewModel()
    /// The locale the screen's words are written in, read here and passed in.
    @Environment(\.locale) private var locale

    var body: some View {
        let chart = model.chartModel(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Wait against queue length",
            message: chart.headline,
            explanation: """
            Swift Charts draws a function, it does not fit one: the slope and intercept of each café's line \
            are worked out in the model by least squares. A function LinePlot is drawn across the whole x scale \
            unless domain: limits it, so pass the range of the data and the line stops where the points do.
            """,
            snippets: model.snippets
        ) {
            TrendLineChart(model: chart)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Leave out domain:", isShowingMistake: $model.isLeavingOutDomain)
                    .disabled(chart.isEmpty)
            }
        }
        .onChange(of: model.isLeavingOutDomain) {
            AccessibilityNotification.Announcement(model.chartModel(locale: locale).announcement).post()
        }
    }
}

/// The orders as points and a fitted line per café, or a placeholder when there are no orders.
struct TrendLineChart: View {
    let model: TrendLineChartModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The y title, shortened at the largest sizes, where the full one meets the top value label.
    private var waitTitle: String {
        dynamicTypeSize >= .accessibility4 ? TrendLineWording.shortWaitTitle : CafeWording.waitAxisTitle
    }

    var body: some View {
        if model.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "person.3",
                description: Text("Each order appears as a point, with a line fitted through each café's orders.")
            )
        } else {
            Chart {
                // snippet:trend-line-points
                PointPlot(
                    model.orders,
                    x: .value(CafeWording.queueAxisTitle, \.queueLength),
                    y: .value(CafeWording.waitAxisTitle, \.waitSeconds)
                )
                .foregroundStyle(by: .value(CafeWording.store, \.store))
                .symbol(by: .value(CafeWording.store, \.store))
                // end
                ForEach(model.fits) { fit in
                    if model.limitsToData {
                        // snippet:trend-line-with-domain
                        // The café's own range of queues: the line stops where its points do.
                        LinePlot(
                            x: CafeWording.queueAxisTitle, y: CafeWording.waitAxisTitle, domain: fit.queueRange
                        ) { [intercept = fit.intercept, slope = fit.slope] queue in
                            intercept + slope * queue
                        }
                        .foregroundStyle(by: .value(CafeWording.store, fit.store))
                        // end
                    } else {
                        // snippet:trend-line-without-domain
                        // No domain: the line runs across the whole x scale, past the last point.
                        LinePlot(x: CafeWording.queueAxisTitle, y: CafeWording.waitAxisTitle) {
                            [intercept = fit.intercept, slope = fit.slope] queue in
                            intercept + slope * queue
                        }
                        .foregroundStyle(by: .value(CafeWording.store, fit.store))
                        // end
                    }
                }
            }
            // snippet:trend-line-scale
            // The x scale reaches past the longest queue; the y scale holds every order and both line ends.
            .chartXScale(domain: model.xDomain)
            .chartYScale(domain: model.yDomain)
            // end
            .chartForegroundStyleScale(domain: model.stores, mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale(domain: model.stores, mapping: CafeSeriesStyle.symbol(for:))
            .chartXAxis {
                // Labels centred on their grid lines, so the scale's end past the data is labelled too. The
                // last one ends at its line instead, so at the largest text sizes it stays clear of the y
                // axis's "0". Padding the scale would do it too, but the line drawn without domain: would
                // then run on into the padding, past 15.
                AxisMarks(preset: .aligned) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(anchor: value.index == value.count - 1 ? .topTrailing : nil)
                }
            }
            .chartXAxisLabel(CafeWording.queueAxisTitle)
            .chartYAxisLabel(waitTitle, position: .top, alignment: .leading)
            // A new identity when the setting changes, so VoiceOver reads the new text.
            .id(model.limitsToData)
            .accessibilityRepresentation {
                TrendLineSpokenChart(model: model)
            }
        }
    }
}

/// What assistive technologies get in place of the drawn chart: one full-height stretch per queue length
/// where something is drawn, read along x, and the chart descriptor for the Audio Graph.
struct TrendLineSpokenChart: View {
    let model: TrendLineChartModel

    var body: some View {
        Chart(model.portions) { portion in
            Plot {
                RectangleMark(
                    xStart: .value(CafeWording.queueAxisTitle, portion.start),
                    xEnd: .value(CafeWording.queueAxisTitle, portion.end),
                    yStart: .value(CafeWording.waitAxisTitle, model.yDomain.lowerBound),
                    yEnd: .value(CafeWording.waitAxisTitle, model.yDomain.upperBound)
                )
            }
            .accessibilityLabel(portion.label)
            .accessibilityValue(portion.value)
        }
        .chartXScale(domain: model.xDomain)
        .chartYScale(domain: model.yDomain)
        .id(model.limitsToData)
        .accessibilityChartDescriptor(TrendLineChartDescriptor(model: model))
    }
}

/// Words this screen needs that `CafeWording` does not have.
private enum TrendLineWording {
    static let shortWaitTitle = "Seconds"
}

#Preview("Trend lines") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/trend-line") {
            TrendLineScreen(screen: screen)
        }
    }
}

#Preview("Without domain:") {
    TrendLineChart(model: TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: false, locale: .current))
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No orders") {
    TrendLineChart(model: TrendLineChartModel(orders: [], limitsToData: true, locale: .current))
}
