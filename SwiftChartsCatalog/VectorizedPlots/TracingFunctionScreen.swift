import Accessibility
import Charts
import SwiftUI

/// "Tracing and drawing a function": a held press and drag reads the coordinates of any point on a
/// function plot, and the curve is drawn in by growing its `domain:` every frame.
struct TracingFunctionScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = TracingFunctionViewModel()
    /// Read here and passed in, so the headline, the label on the point and what VoiceOver hears
    /// write numbers the same way.
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TracingFunctionDrawIn(viewModel: viewModel) { drawnTo in
            CatalogScreenScaffold(
                screen: screen,
                caption: "A cup of coffee cooling",
                message: viewModel.message(drawnTo: drawnTo, locale: locale),
                reservedMessage: viewModel.reservedMessage(locale: locale),
                explanation: """
                LinePlot draws a function rather than data: its closure gives the temperature for any minute. \
                chartXSelection reports the minute under the finger, and a PointMark at that minute and the \
                function's value there marks the point on the curve. A domain: whose upper end grows every frame, \
                inside a TimelineView, draws the curve in while the scales stay fixed.
                """,
                snippets: TracingFunctionViewModel.snippets
            ) {
                TracingFunctionChart(viewModel: viewModel, drawnTo: drawnTo, locale: locale)
            } controls: {
                TracingFunctionControls(isReduceMotionOn: reduceMotion, replay: replay)
            }
        }
        .onAppear {
            // Under Reduce Motion the curve is shown whole: drawing it in is motion for its own sake.
            if !reduceMotion { viewModel.startDrawing(at: .now) }
        }
        .onChange(of: reduceMotion) { _, isOn in
            if isOn { viewModel.showWholeCurve() }
        }
        .task(id: viewModel.drawStart) {
            // Stops the timeline once the draw-in is over.
            guard let start = viewModel.drawStart else { return }
            try? await Task.sleep(for: .seconds(TracingFunctionViewModel.drawSeconds))
            guard !Task.isCancelled else { return }
            viewModel.finishDrawing(startedAt: start)
        }
    }

    private func replay() {
        viewModel.startDrawing(at: .now)
        AccessibilityNotification.Announcement(viewModel.replayAnnouncement(locale: locale)).post()
    }
}

/// Redraws its content every frame while the curve is being drawn in, passing how far the curve reaches.
struct TracingFunctionDrawIn<Content: View>: View {
    let viewModel: TracingFunctionViewModel
    @ViewBuilder let content: (Double) -> Content

    var body: some View {
        // snippet:tracing-and-drawing-a-function-draw-in
        // Ticks every frame while the curve is drawn in, and stops when it is whole.
        TimelineView(.animation(paused: !viewModel.isDrawing)) { context in
            content(viewModel.drawnTo(at: context.date))
        }
        // end
    }
}

/// Sizes that belong to this chart's marks.
private enum TracingFunctionStyle {
    static let pointSize: CGFloat = 80
    static let labelPadding: CGFloat = 4
    static let labelCornerRadius: CGFloat = 4
}

/// The curve, drawn as far as `drawnTo`, with the selected point and its coordinates.
struct TracingFunctionChart: View {
    @Bindable var viewModel: TracingFunctionViewModel
    /// The upper end of the plot's domain, in minutes.
    let drawnTo: Double
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// At the accessibility sizes the coordinates go on two lines, so the label fits across the plot.
    private var isLargeText: Bool {
        dynamicTypeSize.isAccessibilitySize
    }

    /// At the two largest sizes even a title at the leading edge reaches the "100" label: the titles get shorter.
    private var isLargestText: Bool {
        dynamicTypeSize >= .accessibility4
    }

    var body: some View {
        // Read in the body, so a change of selection redraws the marks.
        let selectedMinute = viewModel.selectedMinute(drawnTo: drawnTo)
        let cooling = viewModel.cooling
        // snippet:tracing-and-drawing-a-function-chart
        Chart {
            if drawnTo > TracingFunctionViewModel.minuteDomain.lowerBound {
                // Drawn only as far as `domain:` reaches; the x scale below stays 0 to 60.
                // The closure is @Sendable: it captures the model's values, not self.
                LinePlot(
                    x: TracingFunctionWording.minutes, y: TracingFunctionWording.temperature,
                    domain: TracingFunctionViewModel.minuteDomain.lowerBound ... drawnTo
                ) { [cooling] minute in
                    cooling.temperature(at: minute)
                }
            }
            if let selectedMinute {
                // The point on the curve at the selected minute, with its coordinates beside it.
                PointMark(
                    x: .value(TracingFunctionWording.minutes, selectedMinute),
                    y: .value(TracingFunctionWording.temperature, cooling.temperature(at: selectedMinute))
                )
                .symbolSize(TracingFunctionStyle.pointSize)
                // The point repeats what the curve says.
                .accessibilityHidden(true)
                // On the side of the point the falling curve leaves empty: above and after it on the
                // first half, below and before it on the second. Kept inside the plot.
                .annotation(
                    position: TracingFunctionViewModel.labelsBelow(selectedMinute) ? .bottomLeading : .topTrailing,
                    overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))
                ) {
                    Text(viewModel.coordinates(of: selectedMinute, locale: locale, stacked: isLargeText))
                        .font(.caption.monospacedDigit())
                        .padding(TracingFunctionStyle.labelPadding)
                        .background(Color(.systemBackground), in: .rect(cornerRadius: TracingFunctionStyle.labelCornerRadius))
                        .overlay {
                            RoundedRectangle(cornerRadius: TracingFunctionStyle.labelCornerRadius)
                                .stroke(Color.secondary)
                        }
                }
            }
        }
        .chartXScale(domain: TracingFunctionViewModel.minuteDomain)
        .chartYScale(domain: TracingFunctionViewModel.temperatureDomain)
        .chartXSelection(value: $viewModel.rawSelectedMinute)
        // end
        // Aligned, so the label at the trailing end (60) is drawn inside the chart, not dropped.
        .chartXAxis { AxisMarks(preset: .aligned) }
        .chartXAxisLabel(isLargestText ? TracingFunctionWording.minutesAxisTitleShort : TracingFunctionWording.minutesAxisTitle)
        // Above the plot at its leading edge, away from the top value label at the trailing edge.
        .chartYAxisLabel(
            isLargestText ? TracingFunctionWording.temperatureAxisTitleShort : TracingFunctionWording.temperatureAxisTitle,
            position: .top, alignment: .leading
        )
        .accessibilityRepresentation {
            TracingFunctionSpokenChart(viewModel: viewModel, drawnTo: drawnTo, locale: locale)
        }
    }
}

/// What assistive technologies get in place of the drawn chart: one element per completed five minutes
/// of the drawn curve, each the full height of the plot so they are read in order along x, and the Audio
/// Graph over the same stretch. During the draw-in an element appears only once its five minutes are
/// drawn, and then never changes, so no element's text changes from frame to frame.
struct TracingFunctionSpokenChart: View {
    let viewModel: TracingFunctionViewModel
    let drawnTo: Double
    let locale: Locale

    var body: some View {
        let temperatures = TracingFunctionViewModel.temperatureDomain
        let reach = TracingFunctionViewModel.spokenReach(drawnTo: drawnTo)
        Chart(viewModel.portions(drawnTo: reach)) { portion in
            Plot {
                RectangleMark(
                    xStart: .value(TracingFunctionWording.minutes, portion.start),
                    xEnd: .value(TracingFunctionWording.minutes, portion.end),
                    yStart: .value(TracingFunctionWording.temperature, temperatures.lowerBound),
                    yEnd: .value(TracingFunctionWording.temperature, temperatures.upperBound)
                )
            }
            .accessibilityLabel(portion.label(locale: locale))
            .accessibilityValue(portion.value(locale: locale))
        }
        .chartXScale(domain: TracingFunctionViewModel.minuteDomain)
        .chartYScale(domain: temperatures)
        .accessibilityChartDescriptor(
            TracingFunctionChartDescriptor(cooling: viewModel.cooling, locale: locale)
        )
    }
}

/// The replay button, and how to trace the curve.
struct TracingFunctionControls: View {
    let isReduceMotionOn: Bool
    let replay: () -> Void

    var body: some View {
        ControlsSection {
            Button("Replay the draw-in", systemImage: "arrow.counterclockwise", action: replay)
                .disabled(isReduceMotionOn)
            Text(isReduceMotionOn
                ? "Reduce Motion is on, so the curve is shown whole rather than drawn in."
                : "Touch and hold the chart, then drag along it to read the coordinates of any point on the curve.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/tracing-and-drawing-a-function") {
            TracingFunctionScreen(screen: screen)
        }
    }
}

#Preview("Selected at 12 minutes") {
    @Previewable @State var viewModel: TracingFunctionViewModel = {
        let model = TracingFunctionViewModel()
        model.rawSelectedMinute = 12
        return model
    }()
    TracingFunctionChart(viewModel: viewModel, drawnTo: 60, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("Partway") {
    TracingFunctionChart(viewModel: TracingFunctionViewModel(), drawnTo: 24, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
