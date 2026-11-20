import Accessibility
import Charts
import SwiftUI

/// "Scale types": the same cafés on a linear, log, square-root and symmetric log x scale.
struct ScaleTypesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ScaleTypesViewModel()
    /// Read here and passed in, so the headline, the elements, the axis labels and the Audio Graph
    /// write numbers the same way.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: summary.caption,
            message: summary.headline,
            explanation: """
            A scale type is the function from a value to a position. Linear gives equal differences equal room, \
            so one large café squeezes the rest; log gives each power of ten equal room but cannot draw zero or \
            less; square root sits between the two. Symmetric log is log-like on both sides of zero, so it is \
            shown with the change on last year, which crosses zero and which a log scale cannot draw.
            """,
            snippets: viewModel.snippets
        ) {
            ScaleTypesChart(summary: summary, locale: locale)
        } controls: {
            ScaleTypesControls(kind: $viewModel.kind)
        }
        .onChange(of: viewModel.kind) {
            announceScaleTypesChange(viewModel.summary(locale: locale).announcement)
        }
    }
}

/// The scale type picker.
struct ScaleTypesControls: View {
    @Binding var kind: ScaleTypesKind

    private var animatedKind: Binding<ScaleTypesKind> {
        Binding {
            kind
        } set: { newKind in
            if kind.animatesChange(to: newKind) {
                withAnimation(.easeInOut) { kind = newKind }
            } else {
                kind = newKind
            }
        }
    }

    var body: some View {
        ControlsSection {
            // Animated only while the measure stays the same: linear, log and square root move the same
            // points to new positions, but to or from symmetric log the points stand for something else.
            LabeledMenuPicker(title: "Scale type", selection: animatedKind) {
                ForEach(ScaleTypesKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
        }
    }
}

/// Constants that belong to this chart's marks.
private enum ScaleTypesChartMetrics {
    /// Room at each end of the x scale at the default text size, so the labels centred on the first
    /// and last grid lines fit.
    static let endPadding: CGFloat = 16
}

/// One point per café on the chosen scale, or a placeholder when nothing can be drawn.
struct ScaleTypesChart: View {
    let summary: ScaleTypesSummary
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Grows with the axis labels, so the labels on the first and last grid lines stay inside the chart.
    @ScaledMetric(relativeTo: .caption) private var endPadding = ScaleTypesChartMetrics.endPadding

    var body: some View {
        if summary.points.isEmpty {
            ContentUnavailableView(
                "Nothing to draw",
                systemImage: "chart.dots.scatter",
                description: Text(summary.headline)
            )
        } else {
            // Fewer axis labels at the accessibility text sizes, so they do not collide.
            let scale = dynamicTypeSize.isAccessibilitySize ? summary.scale.thinned() : summary.scale
            let measure = summary.measure
            // snippet:scale-types-chart
            Chart {
                ForEach(summary.points) { point in
                    Plot {
                        PointMark(
                            x: .value(measure.axisTitle, point.value),
                            y: .value(CafeWording.store, point.name)
                        )
                    }
                    .accessibilityLabel(point.name)
                    .accessibilityValue(summary.spokenValue(point.value))
                }
                if summary.showsZeroLine {
                    RuleMark(x: .value(measure.axisTitle, 0))
                        .foregroundStyle(Color.secondary)
                        .accessibilityLabel("No change")
                        .accessibilityValue(CafeWording.cups(0, locale: locale))
                }
            }
            // The scale type is one parameter; the domain is fitted to what the type can draw.
            .chartXScale(
                domain: scale.domain,
                range: .plotDimension(padding: endPadding),
                type: scale.type
            )
            .chartXAxis {
                AxisMarks(
                    format: IntegerFormatStyle<Int>.number.notation(.compactName).locale(locale),
                    preset: .aligned,
                    values: scale.labelledValues
                )
                AxisMarks(values: scale.gridOnlyValues) { _ in
                    AxisGridLine()
                }
            }
            .chartXAxisLabel(measure.axisTitle)
            // end
            .chartYAxis {
                // Café names outside the plot, where points at the leading edge cannot cover them.
                AxisMarks(preset: .aligned, position: .leading)
            }
            // The element text changes with the measure while the ids stay the café names.
            .id(measure)
            .accessibilityChartDescriptor(ScaleTypesChartDescriptor(summary: summary))
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
private func announceScaleTypesChange(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// The chart for the Audio Graph. Not tied to the main actor: the accessibility system calls its
/// value description when it chooses.
nonisolated struct ScaleTypesChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ScaleTypesSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let points = summary.points
        let domain = summary.scale.domain
        let words = summary
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.store,
            categoryOrder: points.map(\.name)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: summary.measure.axisTitle,
            range: Double(domain.lowerBound) ... Double(domain.upperBound),
            gridlinePositions: []
        ) { value in
            CafeWording.count(value, locale: words.locale) { count, _ in words.spokenValue(count) }
        }
        let series = AXDataSeriesDescriptor(
            name: summary.measure.axisTitle,
            isContinuous: false,
            dataPoints: points.map { AXDataPoint(x: $0.name, y: Double($0.value)) }
        )
        return AXChartDescriptor(
            title: "\(summary.caption), on a \(summary.kind.inSentence) scale",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Scale types") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/scale-types") {
            ScaleTypesScreen(screen: screen)
        }
    }
}

#Preview("Each type") {
    ScrollView {
        ForEach(ScaleTypesKind.allCases) { kind in
            ScaleTypesChart(
                summary: ScaleTypesSummary(cafes: CafeData.chainCafes, kind: kind, locale: .current),
                locale: .current
            )
            .frame(height: Layout.chartHeightCompact)
            .padding()
        }
    }
}

#Preview("Nothing on a log scale") {
    ScaleTypesChart(
        summary: ScaleTypesSummary(
            cafes: [ChainCafe(name: "Kiosk", yearlyCups: 0, change: 0)], kind: .log, locale: .current
        ),
        locale: .current
    )
}
