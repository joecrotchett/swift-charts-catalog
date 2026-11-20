import Accessibility
import Charts
import SwiftUI

/// "Undefined values": a function plot that returns `.nan` where its formula gives a number but the curve
/// must not be drawn, poles the plot breaks at by itself, and a plot area clipped so a curve that leaves
/// the y scale stays inside it.
struct UndefinedValuesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = UndefinedValuesViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Graph of \(viewModel.function.name)",
            message: viewModel.summary(locale: locale).headline,
            explanation: """
            A function plot asks its closure for y at many x values across the x scale. Return .nan where the \
            formula still gives a number but the curve must not be drawn, as outside the range a fit was made \
            from: the line stops there. A pole needs nothing: the plot never asks for y at x = 0 and breaks 1/x \
            by itself, and the log of a negative is already NaN. A curve that runs past the y scale's domain is \
            not cut off at the plot's edge unless the plot area is clipped.
            """,
            snippets: viewModel.snippets
        ) {
            UndefinedValuesChart(function: viewModel.function, isClipped: viewModel.isClipped, locale: locale)
                .id(viewModel.chartIdentity)
        } controls: {
            UndefinedValuesControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The function graphed in a fixed window, clipped to the plot area unless the mistake is showing.
struct UndefinedValuesChart: View {
    let function: UndefinedValuesFunction
    let isClipped: Bool
    let locale: Locale

    var body: some View {
        let summary = UndefinedValuesSummary(function: function, isClipped: isClipped, locale: locale)
        // snippet:undefined-values-chart
        Chart {
            // The closure is @Sendable: it captures the function, a value, never self.
            Plot {
                LinePlot(x: "x", y: "y") { [function] x in
                    function.y(at: x)
                }
            }
            // A labelled Plot around a function plot is one element with this label and value.
            .accessibilityLabel(function.spokenTitle)
            .accessibilityValue(summary.elementValue)
        }
        // The window onto the function. Without an x domain it would be drawn from -10 to 10. The padding
        // keeps room at each end for the x axis's end labels.
        .chartXScale(domain: UndefinedValuesWindow.xDomain, range: .plotDimension(padding: UndefinedValuesStyle.xEndPadding))
        .chartYScale(domain: UndefinedValuesWindow.yDomain)
        // Near a pole, and past the fit's top, the curve runs past the y domain; clipping keeps it inside
        // the plot area.
        .chartPlotStyle { plotArea in
            if isClipped {
                plotArea.clipped()
            } else {
                plotArea
            }
        }
        // end
        // The x labels centred on their grid lines, so both ends of the window are labelled.
        .chartXAxis {
            AxisMarks(preset: .aligned)
        }
        // Every whole number labelled, so the edges the headline names, y = 3 and y = -3, can be read.
        .chartYAxis {
            AxisMarks(values: UndefinedValuesWindow.yAxisValues)
        }
        .accessibilityChartDescriptor(UndefinedValuesChartDescriptor(summary: summary))
    }
}

/// The function choice and the mistake toggle, each announcing the change it makes.
struct UndefinedValuesControls: View {
    @Bindable var viewModel: UndefinedValuesViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Function", selection: $viewModel.function) {
                ForEach(UndefinedValuesFunction.allCases) { function in
                    Text(function.title)
                        .accessibilityLabel(function.spokenTitle)
                        .tag(function)
                }
            }
            MistakeToggle(title: "Leave the plot area unclipped", isShowingMistake: $viewModel.isShowingUnclipped)
        }
        .onChange(of: viewModel.function) {
            announceUndefinedValuesChange(viewModel.functionAnnouncement(locale: locale))
        }
        .onChange(of: viewModel.isShowingUnclipped) {
            announceUndefinedValuesChange(viewModel.clippingAnnouncement(locale: locale))
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
@MainActor
private func announceUndefinedValuesChange(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// The Audio Graph: both axes numeric, one series per unbroken piece of the curve, so a break is heard
/// as the end of one series and not drawn over by a line across it.
nonisolated struct UndefinedValuesChartDescriptor: AXChartDescriptorRepresentable {
    let summary: UndefinedValuesSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let format: @Sendable (Double) -> String = { value in
            value.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale))
        }
        return AXChartDescriptor(
            title: "Graph of \(summary.function.name)",
            summary: summary.audioGraphSummary,
            xAxis: AXNumericDataAxisDescriptor(
                title: "x", range: UndefinedValuesWindow.xDomain, gridlinePositions: []
            ) { $0.isFinite ? "x = \(format($0))" : "" },
            yAxis: AXNumericDataAxisDescriptor(
                title: "y", range: summary.describedYRange, gridlinePositions: []
            ) { $0.isFinite ? "y = \(format($0))" : "" },
            additionalAxes: [],
            series: summary.branches.map { branch in
                AXDataSeriesDescriptor(
                    name: branch.name,
                    isContinuous: true,
                    dataPoints: branch.points.map { AXDataPoint(x: $0.x, y: $0.y) }
                )
            }
        )
    }
}

/// Sizes that belong to this chart.
enum UndefinedValuesStyle {
    /// Points kept free at each end of the x scale: half the widest end label, "-4", and a little more.
    static let xEndPadding: CGFloat = 12
}

#Preview("Undefined values") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/undefined-values") {
            UndefinedValuesScreen(screen: screen)
        }
    }
}

#Preview("The fit, clipped") {
    UndefinedValuesChart(function: .fit, isClipped: true, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("Unclipped tangent") {
    UndefinedValuesChart(function: .tangent, isClipped: false, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
