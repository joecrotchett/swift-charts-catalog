import Accessibility
import Charts
import SwiftUI

/// "Function plots": a function drawn as a line, the area between two functions, a parametric curve,
/// and true proportions with axes through the origin, chosen from a small catalog of examples.
struct FunctionPlotsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = FunctionPlotsViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.example.title,
            message: summary.headline,
            explanation: """
            LinePlot draws a function from a closure: give it the x and y labels and a function of x, and it \
            draws the curve across the chart's x scale, with no data at all. AreaPlot fills between two functions, \
            and LinePlot with t and a domain draws a parametric curve. The scale domains are the window onto the \
            function. For the parametric curve an aspect ratio on the plot area keeps a unit as long on both axes, \
            so a circle is drawn round; the other examples fill the plot, and their units differ across and up.
            """,
            snippets: viewModel.snippets
        ) {
            FunctionPlotsChart(example: viewModel.example, summary: summary)
                .id(viewModel.chartIdentity)
        } controls: {
            FunctionPlotsControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The function picker and the two sliders that set the window.
private struct FunctionPlotsControls: View {
    @Bindable var viewModel: FunctionPlotsViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledMenuPicker(title: "Function", selection: Binding(
                get: { viewModel.example },
                set: { newExample in
                    let message = viewModel.select(newExample, locale: locale)
                    AccessibilityNotification.Announcement(message).post()
                }
            )) {
                ForEach(FunctionPlotsExample.allCases) { example in
                    Text(example.title).tag(example)
                }
            }
            LabeledSlider(
                title: "Visible x",
                value: $viewModel.halfWidth,
                range: viewModel.example.halfWidthRange,
                step: FunctionPlotsStyle.sliderStep,
                valueText: viewModel.xSliderText(locale: locale),
                spokenValue: viewModel.xSliderSpokenValue(locale: locale)
            )
            LabeledSlider(
                title: "Visible y",
                value: $viewModel.halfHeight,
                range: viewModel.example.halfHeightRange,
                step: FunctionPlotsStyle.sliderStep,
                valueText: viewModel.ySliderText(locale: locale),
                spokenValue: viewModel.ySliderSpokenValue(locale: locale)
            )
        }
    }
}

/// The chart: axes through the origin, the chosen curve, and the window onto it.
struct FunctionPlotsChart: View {
    let example: FunctionPlotsExample
    /// The window, the scales' domains and the plot's proportions, with the words for all of them.
    let summary: FunctionPlotsSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer axis labels at the accessibility text sizes, so they do not run into each other.
    private var axisLabelCount: Int {
        dynamicTypeSize.isAccessibilitySize ? FunctionPlotsStyle.axisLabelsLarge : FunctionPlotsStyle.axisLabels
    }

    var body: some View {
        let curves = summary.spokenCurves
        Chart {
            FunctionPlotsOriginAxes()
            switch example.kind {
            case .line:
                FunctionPlotsLine(example: example, spoken: curves.first)
            case .area:
                FunctionPlotsArea(spoken: curves)
            case .parametric:
                FunctionPlotsParametric(example: example, spoken: curves.first)
            }
        }
        // snippet:function-plots-domain
        // The scale domains are the window onto the function, with a small margin past each end: the
        // curve is drawn across the x scale.
        .chartXScale(domain: summary.xScaleDomain)
        .chartYScale(domain: summary.yScaleDomain)
        // Number labels on x sit after their grid lines by default, which leaves the window's trailing end
        // unlabelled; .aligned centres each label on its line, so both ends are labelled.
        .chartXAxis { AxisMarks(preset: .aligned, values: .automatic(desiredCount: axisLabelCount)) }
        // end
        .chartYAxis { AxisMarks(values: .automatic(desiredCount: axisLabelCount)) }
        // snippet:function-plots-proportions
        .chartPlotStyle { plotArea in
            if let plotAspectRatio = summary.plotAspectRatio {
                // One unit on x is as long as one unit on y: the plot's shape follows the two domains.
                plotArea
                    .aspectRatio(plotAspectRatio, contentMode: .fit)
                    .clipped()
            } else {
                plotArea.clipped()
            }
        }
        // end
        .accessibilityChartDescriptor(FunctionPlotsChartDescriptor(summary: summary))
        // A plot narrower than the panel stays centred in it, rather than shrinking the panel.
        .frame(maxWidth: .infinity)
    }
}

/// Axis lines through the origin, as mathematicians draw them. Decoration, so hidden from VoiceOver.
struct FunctionPlotsOriginAxes: ChartContent {
    var body: some ChartContent {
        // snippet:function-plots-origin-axes
        // Declared first, so the curve is drawn over them. The labels match the curve's, so the axes
        // keep the names "x" and "y".
        RuleMark(x: .value("x", 0))
            .foregroundStyle(Color.secondary)
            .accessibilityHidden(true)
        RuleMark(y: .value("y", 0))
            .foregroundStyle(Color.secondary)
            .accessibilityHidden(true)
        // end
    }
}

/// One function of x, drawn as a line.
struct FunctionPlotsLine: ChartContent {
    let example: FunctionPlotsExample
    let spoken: FunctionPlotsSummary.SpokenCurve?

    var body: some ChartContent {
        // snippet:function-plots-line
        // A labelled Plot around the function makes the curve one element with these words.
        Plot {
            // The closure is @Sendable: it captures the example, a value, not self.
            LinePlot(x: "x", y: "y") { [example] x in
                example.y(at: x)
            }
        }
        .accessibilityLabel(spoken?.label ?? example.spokenEquation)
        .accessibilityValue(spoken?.value ?? "")
        // end
    }
}

/// The area between y = x and y = x² − 1, with each function drawn and named as a line.
struct FunctionPlotsArea: ChartContent {
    let spoken: [FunctionPlotsSummary.SpokenCurve]

    var body: some ChartContent {
        // snippet:function-plots-area
        // The closure returns both ends of the area at each x.
        AreaPlot(x: "x", yStart: "y", yEnd: "y") { x in
            (yStart: FunctionPlotsExample.lowerBound(at: x), yEnd: FunctionPlotsExample.upperBound(at: x))
        }
        .foregroundStyle(Color.secondary)
        .opacity(FunctionPlotsStyle.areaOpacity)
        // The area repeats the two lines' values, so VoiceOver hears the lines alone.
        .accessibilityHidden(true)

        Plot {
            LinePlot(x: "x", y: "y") { x in FunctionPlotsExample.lowerBound(at: x) }
                .foregroundStyle(by: .value("Function", FunctionPlotsExample.lowerBoundName))
                .lineStyle(by: .value("Function", FunctionPlotsExample.lowerBoundName))
        }
        .accessibilityLabel(spoken.first?.label ?? FunctionPlotsExample.lowerBoundSpoken)
        .accessibilityValue(spoken.first?.value ?? "")

        Plot {
            LinePlot(x: "x", y: "y") { x in FunctionPlotsExample.upperBound(at: x) }
                .foregroundStyle(by: .value("Function", FunctionPlotsExample.upperBoundName))
                .lineStyle(by: .value("Function", FunctionPlotsExample.upperBoundName))
        }
        .accessibilityLabel(spoken.last?.label ?? FunctionPlotsExample.upperBoundSpoken)
        .accessibilityValue(spoken.last?.value ?? "")
        // end
    }
}

/// A curve whose x and y are both functions of t.
struct FunctionPlotsParametric: ChartContent {
    let example: FunctionPlotsExample
    let spoken: FunctionPlotsSummary.SpokenCurve?

    var body: some ChartContent {
        // snippet:function-plots-parametric
        Plot {
            // The closure takes t and returns both coordinates; the domain of t is required.
            LinePlot(x: "x", y: "y", t: "t", domain: example.tDomain) { [example] t in
                example.point(at: t)
            }
        }
        .accessibilityLabel(spoken?.label ?? example.spokenEquation)
        .accessibilityValue(spoken?.value ?? "")
        // end
    }
}

/// Constants that belong to this chart's marks and controls.
enum FunctionPlotsStyle {
    static let areaOpacity = 0.3
    static let sliderStep = 0.25
    static let axisLabels = 5
    static let axisLabelsLarge = 3
}

#Preview("Sine wave") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/function-plots") {
            FunctionPlotsScreen(screen: screen)
        }
    }
}

#Preview("Each example") {
    ScrollView {
        ForEach(FunctionPlotsExample.allCases) { example in
            let summary = FunctionPlotsSummary(
                example: example, halfWidth: example.defaultHalfWidth, halfHeight: example.defaultHalfHeight,
                locale: .current
            )
            FunctionPlotsChart(example: example, summary: summary)
                .frame(height: Layout.chartHeightCompact)
                .padding()
        }
    }
}
