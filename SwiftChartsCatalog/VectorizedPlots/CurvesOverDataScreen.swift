import Accessibility
import Charts
import SwiftUI

/// "Curves over data": function plots layered over the data they describe, a fitted normal curve over a
/// histogram and a trend line with its uncertainty band over a scatter, each layer switched on its own.
struct CurvesOverDataScreen: View {
    let screen: CatalogScreen
    @State private var model = CurvesOverDataViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.caption(locale: locale),
            message: model.headline(locale: locale),
            explanation: """
            A function plot shares the chart's scales with the data under it, so a curve can be drawn straight \
            over bars or points. The framework fits nothing: the model works out the normal curve's mean and \
            spread, or the line's slope and band, and the LinePlot and AreaPlot closures only evaluate them.
            """,
            snippets: model.snippets
        ) {
            CurvesOverDataChart(model: model, locale: locale)
        } controls: {
            CurvesOverDataControls(model: model, locale: locale)
        }
    }
}

/// The chart the picker chooses, or a placeholder when it would draw nothing.
struct CurvesOverDataChart: View {
    let model: CurvesOverDataViewModel
    let locale: Locale

    var body: some View {
        if let placeholder = model.placeholder {
            ContentUnavailableView(
                placeholder.title,
                systemImage: placeholder.systemImage,
                description: Text(placeholder.message)
            )
        } else {
            switch model.kind {
            case .histogram: CurvesOverDataHistogramChart(model: model, locale: locale)
            case .trend: CurvesOverDataTrendChart(model: model, locale: locale)
            }
        }
    }
}

/// Bars for the binned waits, with the fitted normal curve drawn over them.
struct CurvesOverDataHistogramChart: View {
    let model: CurvesOverDataViewModel
    let locale: Locale
    /// Room at each end of the x scale for half of a centred end label, growing with the label's text.
    @ScaledMetric(relativeTo: .caption2) private var endLabelRoom = CurvesOverDataStyle.endLabelRoom

    var body: some View {
        let fit = model.normalFit
        let waits = model.histogramXDomain
        // snippet:curves-over-data-histogram
        Chart {
            if model.drawsBars {
                ForEach(model.bins) { bin in
                    BarMark(
                        x: .value(TimeOfDayWording.wait, bin.range),
                        y: .value(CafeWording.orders, bin.orders),
                        width: .inset(1)
                    )
                    // Muted while the curve is drawn over them, so there is one focus.
                    .opacity(model.drawsCurve ? CurvesOverDataStyle.mutedBars : 1)
                }
            }
            if model.drawsCurve, let fit {
                // The closure captures the fit, a value, never self. `domain:` keeps the curve out of the
                // scale's end padding.
                LinePlot(x: TimeOfDayWording.wait, y: CurvesOverDataWording.fittedCurve, domain: waits) { [fit] wait in
                    fit.expectedOrders(atWait: wait)
                }
                .foregroundStyle(Color.primary)
            }
        }
        // Both domains fixed, and the y domain holds the curve's peak, so nothing rescales when a layer is
        // switched and nothing leaves the plot: no clipping, which would also hide the axis titles.
        // Padding at each end keeps the centred end labels, "0" and "10", inside the chart.
        .chartXScale(domain: model.histogramXDomain, range: .plotDimension(padding: endLabelRoom))
        .chartYScale(domain: model.histogramYDomain)
        // end
        .modifier(CurvesOverDataAxes(xTitle: TimeOfDayWording.waitAxisTitle, yTitle: CafeWording.orders))
        // The bars' own elements would be read with the curve between two of them, so VoiceOver hears one
        // stretch per bin instead, each spanning the plot's height so they are read in order along x.
        .accessibilityRepresentation {
            CurvesOverDataSpokenHistogram(model: model, locale: locale)
        }
        // The element text follows the layers while the bins stay the same.
        .id(model.visibleLayers)
    }
}

/// What VoiceOver reads in place of the histogram: one element per bin, valued with the drawn layers
/// there. Never drawn.
struct CurvesOverDataSpokenHistogram: View {
    let model: CurvesOverDataViewModel
    let locale: Locale

    var body: some View {
        Chart(model.bins) { bin in
            Plot {
                RectangleMark(
                    xStart: .value(TimeOfDayWording.wait, bin.range.lowerBound),
                    xEnd: .value(TimeOfDayWording.wait, bin.range.upperBound),
                    yStart: .value(CafeWording.orders, model.histogramYDomain.lowerBound),
                    yEnd: .value(CafeWording.orders, model.histogramYDomain.upperBound)
                )
            }
            .accessibilityLabel(model.binLabel(bin, locale: locale))
            .accessibilityValue(model.binValue(bin, locale: locale))
        }
        .chartXScale(domain: model.histogramXDomain)
        .chartYScale(domain: model.histogramYDomain)
        // The chart descriptor goes on the representation, which is what the Audio Graph is given.
        .accessibilityChartDescriptor(model.histogramDescriptor(locale: locale))
    }
}

/// The Harbour café's orders as points, with the fitted trend line and the band around it.
struct CurvesOverDataTrendChart: View {
    let model: CurvesOverDataViewModel
    let locale: Locale

    var body: some View {
        let fit = model.lineFit
        let queues = model.queueRange
        // snippet:curves-over-data-trend
        Chart {
            if model.drawsBand, let fit {
                // Declared first, so the band sits behind the points and the line.
                AreaPlot(
                    x: CafeWording.queueAxisTitle,
                    yStart: CurvesOverDataWording.bandLow,
                    yEnd: CurvesOverDataWording.bandHigh,
                    domain: queues
                ) { [fit] queue in
                    let centre = fit.trend(at: queue)
                    let margin = fit.margin(at: queue)
                    return (yStart: centre - margin, yEnd: centre + margin)
                }
                .foregroundStyle(Color.primary)
                .opacity(CurvesOverDataStyle.bandOpacity)
            }
            if model.drawsPoints {
                PointPlot(
                    model.waits,
                    x: .value(CafeWording.queueAxisTitle, \.queueLength),
                    y: .value(TimeOfDayWording.wait, \.waitSeconds)
                )
            }
            if model.drawsTrend, let fit {
                // Stops where the points do: the fit says nothing beyond the data.
                LinePlot(x: CafeWording.queueAxisTitle, y: CurvesOverDataWording.trend, domain: queues) { [fit] queue in
                    fit.trend(at: queue)
                }
                .foregroundStyle(Color.primary)
            }
        }
        // The y domain holds the band's top, so nothing leaves the plot and it needs no clipping.
        .chartXScale(domain: model.trendXDomain)
        .chartYScale(domain: model.trendYDomain)
        // end
        .modifier(CurvesOverDataAxes(xTitle: CafeWording.queueAxisTitle, yTitle: CafeWording.waitAxisTitle))
        // A plot's own elements have no units, so VoiceOver hears one stretch per queue length with orders
        // instead, each spanning the plot's height so they are read in order along x.
        .accessibilityRepresentation {
            CurvesOverDataSpokenTrend(model: model, locale: locale)
        }
        .id(model.visibleLayers)
    }
}

/// What VoiceOver reads in place of the trend chart: one element per queue length with orders, valued with
/// the waits, the trend and the band there for the layers drawn. Never drawn.
struct CurvesOverDataSpokenTrend: View {
    let model: CurvesOverDataViewModel
    let locale: Locale

    var body: some View {
        Chart(model.queuePortions) { portion in
            Plot {
                RectangleMark(
                    xStart: .value(CafeWording.queueAxisTitle, portion.start),
                    xEnd: .value(CafeWording.queueAxisTitle, portion.end),
                    yStart: .value(TimeOfDayWording.wait, model.trendYDomain.lowerBound),
                    yEnd: .value(TimeOfDayWording.wait, model.trendYDomain.upperBound)
                )
            }
            .accessibilityLabel(model.portionLabel(portion, locale: locale))
            .accessibilityValue(model.portionValue(portion, locale: locale))
        }
        .chartXScale(domain: model.trendXDomain)
        .chartYScale(domain: model.trendYDomain)
        // The chart descriptor goes on the representation, which is what the Audio Graph is given.
        .accessibilityChartDescriptor(model.trendDescriptor(locale: locale))
    }
}

/// The chart picker and a toggle per layer of the chart shown.
struct CurvesOverDataControls: View {
    @Bindable var model: CurvesOverDataViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Chart", selection: $model.kind) {
                ForEach(CurvesOverDataKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            ForEach(model.kind.layers) { layer in
                Toggle(layer.title, isOn: Binding(
                    get: { model.isShowing(layer) },
                    set: { isOn in
                        model.setShowing(layer, isOn)
                        curvesOverDataAnnounce(model.layerAnnouncement(for: layer, locale: locale))
                    }
                ))
                .disabled(!model.hasData)
            }
        }
        .onChange(of: model.kind) {
            curvesOverDataAnnounce(model.kindAnnouncement(locale: locale))
        }
    }
}

/// Both charts' axes: labels centred on their grid lines, their titles, the y title above the plot at its
/// leading edge so it never meets the top label, and fewer labels on each axis at the accessibility text
/// sizes, where the usual number collide.
struct CurvesOverDataAxes: ViewModifier {
    let xTitle: String
    let yTitle: String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        let isLarge = dynamicTypeSize.isAccessibilitySize
        content
            .chartXAxis {
                // Centred on their grid lines, so the scale's ends are labelled too.
                AxisMarks(preset: .aligned, values: .automatic(desiredCount: isLarge ? 3 : 5))
            }
            .chartYAxis {
                AxisMarks(values: .automatic(desiredCount: isLarge ? 2 : 5))
            }
            .chartXAxisLabel(xTitle)
            .chartYAxisLabel(yTitle, position: .top, alignment: .leading)
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
@MainActor
private func curvesOverDataAnnounce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// Constants that belong to this screen's marks.
private enum CurvesOverDataStyle {
    /// The bars' opacity while the curve is drawn over them.
    static let mutedBars = 0.45
    static let bandOpacity = 0.18
    /// Room at each end of the histogram's x scale, at the default text size: half the end label "10" and a
    /// gap, so it stays inside the chart and clear of the trailing y axis's "0".
    static let endLabelRoom: CGFloat = 10
}

#Preview("Histogram") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/curves-over-data") {
            CurvesOverDataScreen(screen: screen)
        }
    }
}

#Preview("Trend") {
    let model = CurvesOverDataViewModel()
    model.kind = .trend
    return CurvesOverDataChart(model: model, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No orders") {
    CurvesOverDataChart(model: CurvesOverDataViewModel(orders: [], waits: []), locale: .current)
}
