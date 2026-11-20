import Accessibility
import Charts
import SwiftUI

/// "Vector field": a point per reading whose symbol is an arrow turned to the reading's direction.
struct VectorFieldScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = VectorFieldViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Air moving through the café",
            message: viewModel.headline(locale: locale),
            explanation: """
            A vector field is a scatter plot whose points say which way as well as where. Each reading is a \
            PointMark, and its symbol is a view: an arrow image turned by the reading's direction and sized by \
            its speed, so a longer arrow is faster air. A metre is the same length on both axes, so an arrow \
            points across the chart the way the air moves across the room.
            """,
            snippets: viewModel.snippets
        ) {
            VectorFieldChart(readings: viewModel.readings, speedCeiling: viewModel.speedCeiling, kind: viewModel.kind)
        } controls: {
            ControlsSection {
                // The same spots with new values, so the arrows turn and grow into the new field.
                LabeledSegmentedPicker(title: "Field", selection: $viewModel.kind.animation(.easeInOut)) {
                    ForEach(VectorFieldKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
            }
        }
        .onChange(of: viewModel.kind) {
            // The picker changes the chart's data: say so, for people who cannot see the arrows turn.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The lengths that belong to this chart's arrows, in points.
private enum VectorFieldMetrics {
    /// The arrow for the slowest air that still moves, and for the fastest in any field.
    static let shortestArrow: CGFloat = 9
    static let longestArrow: CGFloat = 26
    /// The dot drawn where the air is still, which has no direction to show.
    static let stillDot: CGFloat = 5
    /// The arrows' one colour, set on the chart's symbols and on the key's, so the key draws what the
    /// chart draws. A view symbol is drawn as written and takes no colour from the chart, so it is set.
    static let arrowColour = Color.blue

    /// An arrow's length follows its speed in a straight line, from the shortest that can be read.
    /// Nil where the air is still.
    static func arrowLength(for speed: Double, ceiling: Double) -> CGFloat? {
        guard speed > 0 else { return nil }
        guard ceiling > 0 else { return shortestArrow }
        let share = min(speed / ceiling, 1)
        return shortestArrow + (longestArrow - shortestArrow) * share
    }
}

/// One arrow per reading on the café floor, or a placeholder when there are no readings.
struct VectorFieldChart: View {
    let readings: [Airflow]
    /// The speed drawn as the longest arrow.
    let speedCeiling: Double
    let kind: VectorFieldKind

    var body: some View {
        if readings.isEmpty {
            ContentUnavailableView(
                "No airflow readings",
                systemImage: "wind",
                description: Text("Readings taken on the café floor appear here, one arrow per spot.")
            )
        } else {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                VectorFieldPlot(readings: readings, speedCeiling: speedCeiling, kind: kind)
                // The arrows' lengths have no axis, so a key gives the speeds at both ends.
                VectorFieldKey(summary: VectorFieldSummary(readings: readings), speedCeiling: speedCeiling)
            }
        }
    }
}

/// The chart itself: a point per reading with an arrow as its symbol.
struct VectorFieldPlot: View {
    let readings: [Airflow]
    let speedCeiling: Double
    let kind: VectorFieldKind
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Every other grid line is labelled at the accessibility sizes, so the labels do not collide.
    private func labelStride(_ room: VectorFieldRoom) -> Double {
        dynamicTypeSize.isAccessibilitySize ? room.step * 2 : room.step
    }

    var body: some View {
        let room = VectorFieldRoom(readings: readings)
        Group {
            // snippet:vector-field-chart
            Chart(readings) { reading in
                // One element per arrow: where it is, then which way the air goes and how fast.
                Plot {
                    PointMark(
                        x: .value(CafeWording.acrossAxisTitle, reading.x),
                        y: .value(CafeWording.intoAxisTitle, reading.y)
                    )
                    // Any view can be a point's symbol. This one is turned by the data.
                    .symbol {
                        VectorFieldArrow(
                            direction: reading.direction,
                            length: arrowLength(for: reading.speed)
                        )
                        .foregroundStyle(VectorFieldMetrics.arrowColour)
                    }
                }
                .accessibilityLabel(VectorFieldSummary.position(of: reading, locale: locale))
                .accessibilityValue(VectorFieldSummary.movement(of: reading, locale: locale))
            }
            // The whole floor, so no arrow sits on the plot's edge to be cut off.
            .chartXScale(domain: room.across)
            .chartYScale(domain: room.into)
            // A metre is as long across as it is up, or the arrows would point the wrong way.
            .chartPlotStyle { plotArea in
                plotArea.aspectRatio(room.aspectRatio, contentMode: .fit)
            }
            .chartXAxis {
                // Centred on its line, so the line at the far wall is labelled too.
                AxisMarks(preset: .aligned, values: .stride(by: labelStride(room)))
            }
            .chartYAxis {
                AxisMarks(values: .stride(by: labelStride(room)))
            }
            // end
            .chartXAxisLabel(CafeWording.acrossAxisTitle)
            .yAxisTitle(CafeWording.intoAxisTitle, short: CafeWording.intoAxisShortTitle)
            .accessibilityChartDescriptor(
                VectorFieldChartDescriptor(readings: readings, speedCeiling: speedCeiling, kind: kind, locale: locale)
            )
        }
    }

    private func arrowLength(for speed: Double) -> CGFloat? {
        VectorFieldMetrics.arrowLength(for: speed, ceiling: speedCeiling)
    }
}

/// What an arrow's length means: the slowest and fastest air in the field drawn, as drawn.
struct VectorFieldKey: View {
    let summary: VectorFieldSummary
    let speedCeiling: Double
    @Environment(\.locale) private var locale

    var body: some View {
        if let slowest = summary.slowestSpeed, let fastest = summary.fastestSpeed {
            // In a row while it fits, a column at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Layout.itemSpacing) {
                    VectorFieldKeyEntries(slowest: slowest, fastest: fastest, speedCeiling: speedCeiling, locale: locale)
                }
                VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                    VectorFieldKeyEntries(slowest: slowest, fastest: fastest, speedCeiling: speedCeiling, locale: locale)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Arrow length is air speed")
            .accessibilityValue(
                "Shortest \(VectorFieldSummary.speed(slowest, locale: locale)), "
                    + "longest \(VectorFieldSummary.speed(fastest, locale: locale))"
            )
        }
    }
}

/// The key's title and its one or two arrows.
struct VectorFieldKeyEntries: View {
    let slowest: Double
    let fastest: Double
    let speedCeiling: Double
    let locale: Locale

    var body: some View {
        Text("\(CafeWording.speedTitle):")
        VectorFieldKeyEntry(speed: slowest, speedCeiling: speedCeiling, locale: locale)
        if fastest != slowest {
            VectorFieldKeyEntry(speed: fastest, speedCeiling: speedCeiling, locale: locale)
        }
    }
}

/// One arrow of the key, drawn the way the chart draws that speed, with the speed beside it.
struct VectorFieldKeyEntry: View {
    let speed: Double
    let speedCeiling: Double
    let locale: Locale

    var body: some View {
        HStack(spacing: Layout.tightSpacing) {
            VectorFieldArrow(direction: 90, length: VectorFieldMetrics.arrowLength(for: speed, ceiling: speedCeiling))
                .foregroundStyle(VectorFieldMetrics.arrowColour)
                // The image is named "Up" though it is drawn pointing right; the key's one element says it all.
                .accessibilityHidden(true)
            // The unit is in the key's title, as it is in the axes' titles.
            Text(speed > 0 ? speed.formatted(.number.precision(.fractionLength(0 ... 2)).locale(locale)) : VectorFieldSummary.stillAir)
        }
    }
}

// snippet:vector-field-arrow
/// The symbol of one point: an arrow that points up until the data turns it.
struct VectorFieldArrow: View {
    /// Degrees clockwise from up.
    let direction: Double
    /// The arrow's size in points, or nil where the air is still.
    let length: CGFloat?

    var body: some View {
        if let length {
            Image(systemName: "arrow.up")
                .font(.system(size: length, weight: .semibold))
                .rotationEffect(.degrees(direction))
        } else {
            // Still air has no direction: a dot, not an arrow pointing nowhere.
            Circle().frame(width: VectorFieldMetrics.stillDot, height: VectorFieldMetrics.stillDot)
        }
    }
}

// end

/// The field for the Audio Graph: one series per row of the grid, played by speed, with each
/// reading's direction on an axis of its own.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct VectorFieldChartDescriptor: AXChartDescriptorRepresentable {
    let readings: [Airflow]
    let speedCeiling: Double
    let kind: VectorFieldKind
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let room = VectorFieldRoom(readings: readings)
        let locale = locale
        let rows = Set(readings.map(\.y)).sorted()
        let xAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.acrossAxisTitle,
            range: room.across,
            gridlinePositions: []
        ) { "\(VectorFieldSummary.metres($0, locale: locale)) across" }
        // The arrows are drawn against a scale from still air to the fastest in any field.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.speedTitle,
            range: 0 ... max(speedCeiling, readings.map(\.speed).max() ?? 0),
            gridlinePositions: []
        ) { VectorFieldSummary.speed($0, locale: locale) }
        let directionAxis = AXNumericDataAxisDescriptor(
            title: VectorFieldSummary.directionAxisTitle,
            range: 0 ... 360,
            gridlinePositions: []
        ) { VectorFieldSummary.degrees($0, locale: locale) }
        let series = rows.map { row in
            AXDataSeriesDescriptor(
                name: "\(VectorFieldSummary.metres(row, locale: locale)) into the room",
                isContinuous: false,
                dataPoints: readings.filter { $0.y == row }.sorted { $0.x < $1.x }.map { reading in
                    AXDataPoint(x: reading.x, y: reading.speed, additionalValues: [.number(reading.direction)])
                }
            )
        }
        return AXChartDescriptor(
            title: "Air moving through the café: \(kind.name)",
            summary: VectorFieldSummary(readings: readings).audioGraphSummary(locale: locale),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [directionAxis],
            series: series
        )
    }
}

#Preview("Vector field") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/vector-field") {
            VectorFieldScreen(screen: screen)
        }
    }
}

#Preview("Right to left") {
    VectorFieldChart(readings: CafeData.airflow, speedCeiling: 1.1, kind: .measured)
        .environment(\.layoutDirection, .rightToLeft)
        .padding()
}

#Preview("No readings") {
    VectorFieldChart(readings: [], speedCeiling: 0, kind: .measured)
}
