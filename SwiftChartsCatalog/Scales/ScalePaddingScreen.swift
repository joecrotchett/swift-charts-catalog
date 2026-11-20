import Accessibility
import Charts
import SwiftUI

/// "Scale padding": `chartXScale(range: .plotDimension(...))` keeps points free at the ends of the
/// x scale, so the first and last days' points and labels are not drawn against the plot's edges.
struct ScalePaddingScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ScalePaddingViewModel
    /// The locale the screen's words are written in, read here and passed in.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, viewModel: ScalePaddingViewModel = ScalePaddingViewModel()) {
        self.screen = screen
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day at the \(CafeWording.harbour) café",
            message: viewModel.summary(locale: locale).headline,
            explanation: """
            A position scale's range is the stretch of the plot its values map onto. \
            chartXScale(range: .plotDimension(padding:)) keeps that many points free at both ends, so the first \
            and last days' points, and the labels centred under them, can sit inside the chart; startPadding and \
            endPadding set each end on its own. The data and the domain stay the same: only where they are drawn changes.
            """,
            snippets: viewModel.snippets
        ) {
            ScalePaddingChart(
                days: viewModel.days,
                startPadding: viewModel.startPadding,
                endPadding: viewModel.endPadding,
                form: viewModel.form,
                locale: locale
            )
        } controls: {
            ScalePaddingControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The two sliders: the padding at the start and at the end of the x scale's range.
struct ScalePaddingControls: View {
    @Bindable var viewModel: ScalePaddingViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSlider(
                title: "Start padding",
                value: $viewModel.startPadding,
                range: ScalePaddingViewModel.paddingRange,
                step: ScalePaddingViewModel.paddingStep,
                valueText: viewModel.paddingText(viewModel.startPadding, locale: locale),
                spokenValue: viewModel.spokenPadding(viewModel.startPadding, locale: locale)
            )
            LabeledSlider(
                title: "End padding",
                value: $viewModel.endPadding,
                range: ScalePaddingViewModel.paddingRange,
                step: ScalePaddingViewModel.paddingStep,
                valueText: viewModel.paddingText(viewModel.endPadding, locale: locale),
                spokenValue: viewModel.spokenPadding(viewModel.endPadding, locale: locale)
            )
        }
    }
}

/// A week of cups as a line with a point on each day, its x scale padded as the sliders say,
/// or a placeholder when there are no days.
struct ScalePaddingChart: View {
    let days: [DailySales]
    let startPadding: Double
    let endPadding: Double
    let form: ScalePaddingForm
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer day labels at the accessibility text sizes, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility1 ? 2 : 1
    }

    /// The x scale's range for the current padding, written in the form the sliders call for.
    private var xRange: PlotDimensionScaleRange {
        switch form {
        case .none:
            // snippet:scale-padding-none
            // The whole width of the plot, nothing kept free: the first and last points sit on its edges.
            .plotDimension
        // end
        case .bothEnds:
            // snippet:scale-padding-both-ends
            // The same number of points kept free at both ends of the scale.
            .plotDimension(padding: startPadding)
        // end
        case .eachEnd:
            // snippet:scale-padding-each-end
            // Each end of the scale padded on its own; a padding left out is 0.
            .plotDimension(startPadding: startPadding, endPadding: endPadding)
            // end
        }
    }

    var body: some View {
        if days.isEmpty {
            ContentUnavailableView(
                "No days yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, as a line with a point on each day.")
            )
        } else {
            let summary = ScalePaddingSummary(days: days, locale: locale)
            // snippet:scale-padding-chart
            Chart(days) { day in
                // One labelled Plot per day: the line is still drawn as one line.
                Plot {
                    LineMark(
                        x: .value(CafeWording.day, day.day),
                        y: .value(CafeWording.cups, day.cups)
                    )
                    .symbol(.circle)
                }
                .accessibilityLabel(summary.dayText(day.day))
                .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
            }
            // The range is the stretch of the plot the days map onto; padding keeps points free at its ends.
            .chartXScale(range: xRange)
            .chartXAxis {
                // Labels centred on their grid lines, so the first and last days are labelled too;
                // the padding is what keeps those two labels inside the chart.
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.abbreviated)
                    )
                }
            }
            // end
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(ScalePaddingChartDescriptor(days: days, locale: locale))
        }
    }
}

#Preview("Scale padding") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/scale-padding") {
            ScalePaddingScreen(screen: screen)
        }
    }
}

#Preview("Padded at each end") {
    ScalePaddingChart(
        days: Array(CafeData.harbourSales.prefix(7)), startPadding: 8, endPadding: 24, form: .eachEnd, locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No days") {
    ScalePaddingChart(days: [], startPadding: 0, endPadding: 0, form: .none, locale: .current)
}
