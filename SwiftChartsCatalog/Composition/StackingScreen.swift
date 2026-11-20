import Accessibility
import Charts
import SwiftUI

/// "Stacking": marks that share a position stack, colour only reveals the pieces, and the four stacking methods.
struct StackingScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = StackingViewModel()

    var body: some View {
        let summary = viewModel.summary
        CatalogScreenScaffold(
            screen: screen,
            caption: summary.caption,
            message: summary.headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets,
            chart: { StackingChart(summary: summary) },
            controls: { StackingControls(viewModel: viewModel) }
        )
        // A change of method, mark, data or colour redraws the chart: say what changed and what it now shows,
        // for people who cannot see it happen. The summary holds every setting, so no control is missed.
        .onChange(of: summary) { previous, summary in
            AccessibilityNotification.Announcement(summary.announcement(after: previous)).post()
        }
    }
}

/// The method, the mark, the data, and the mistake.
struct StackingControls: View {
    @Bindable var viewModel: StackingViewModel

    var body: some View {
        ControlsSection {
            // The same pieces arranged another way: animate the change.
            LabeledMenuPicker(title: "Stacking method", selection: $viewModel.method.animation(.easeInOut)) {
                ForEach(StackingMethod.allCases) { method in
                    Text(method.title).tag(method)
                }
            }
            Picker("Mark", selection: $viewModel.mark) {
                ForEach(StackingMark.allCases) { mark in
                    Text(mark.title).tag(mark)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Mark")
            Toggle("Use data with negative values", isOn: $viewModel.usesNegativeValues)
            MistakeToggle(title: "Remove the colour", isShowingMistake: $viewModel.isShowingMistake)
        }
    }
}

/// The chart for the current settings, or a placeholder when there is nothing to stack.
struct StackingChart: View {
    let summary: StackingSummary

    var body: some View {
        if summary.data.isEmpty {
            // No rows, or only zeros: a chart would draw axes with no marks.
            ContentUnavailableView(
                "Nothing to stack",
                systemImage: "square.stack.3d.up.slash",
                description: Text("Pieces that share a position appear here, stacked.")
            )
        } else {
            switch (summary.mark, summary.isShowingMistake) {
            case (.bars, false): ColouredBarsChart(summary: summary)
            case (.areas, false): ColouredAreasChart(summary: summary)
            case (.bars, true): UncolouredBarsChart(summary: summary)
            case (.areas, true): UncolouredAreasChart(summary: summary)
            }
        }
    }
}

// snippet:stacking-method
extension StackingMethod {
    /// The value for the stacking: parameter of BarMark and AreaMark.
    var markStacking: MarkStackingMethod {
        switch self {
        // From zero, the default. Negative values stack downward from zero.
        case .standard: .standard
        // Scaled so every stack fills the same height: shares, not amounts.
        case .normalized: .normalized
        // Around a centre line: a streamgraph when the marks are areas.
        case .center: .center
        // Not stacked: every mark starts at zero and they overlap.
        case .unstacked: .unstacked
        }
    }
}

// end

/// Constants for the marks.
private enum StackingStyle {
    /// Unstacked marks overlap: faded, so none is hidden behind another.
    static let overlapOpacity = 0.5
    /// A strip of background between stacked pieces, so they differ by more than colour.
    static let segmentGap: CGFloat = 1
}

private extension StackingMethod {
    var markOpacity: Double {
        self == .unstacked ? StackingStyle.overlapOpacity : 1
    }
}

/// One bar per row. The rows that share a drink stack; the colour says which piece is which.
struct ColouredBarsChart: View {
    let summary: StackingSummary

    var body: some View {
        let data = summary.data
        let method = summary.method
        // snippet:stacking-bars
        Chart(data.rows) { row in
            // A labelled Plot makes each piece its own accessibility element.
            Plot {
                // Rows with the same x share a position, so they stack. stacking: says how.
                BarMark(
                    x: .value(data.categoryLabel, row.category),
                    y: .value(data.valueLabel, row.value),
                    stacking: method.markStacking
                )
                // This does not cause the stacking. It colours the pieces and adds the legend.
                .foregroundStyle(by: .value(data.seriesLabel, row.series))
                // A strip of space between the pieces, so they are told apart by more than colour.
                .clipShape(Rectangle().inset(by: StackingStyle.segmentGap))
                // Unstacked marks overlap, so they are faded.
                .opacity(method.markOpacity)
            }
            .accessibilityLabel("\(row.category), \(row.series)")
            .accessibilityValue(summary.valueText(for: row))
        }
        // end
        .stackingColours(data)
        .stackingAxis(summary)
        .accessibilityChartDescriptor(StackingChartDescriptor(summary: summary))
    }
}

/// One area point per row. Each series is a band resting on the one before it.
struct ColouredAreasChart: View {
    let summary: StackingSummary

    var body: some View {
        let data = summary.data
        let method = summary.method
        // snippet:stacking-areas
        Chart(data.rows) { row in
            Plot {
                // Points with the same x share a position, so the bands stack. stacking: says how.
                AreaMark(
                    x: .value(data.categoryLabel, row.category),
                    y: .value(data.valueLabel, row.value),
                    stacking: method.markStacking
                )
                // Separates the bands, colours them and adds the legend.
                .foregroundStyle(by: .value(data.seriesLabel, row.series))
                // Unstacked areas cover each other, so they are faded.
                .opacity(method.markOpacity)
            }
            .accessibilityLabel("\(row.category), \(row.series)")
            .accessibilityValue(summary.valueText(for: row))
        }
        // end
        .stackingColours(data)
        .stackingAxis(summary)
        .accessibilityChartDescriptor(StackingChartDescriptor(summary: summary))
    }
}

extension View {
    /// The colour scale: the cafés and the sizes in the colours every screen gives them, each in a fixed domain
    /// so a piece keeps its colour whatever the data holds.
    @ViewBuilder
    func stackingColours(_ data: StackingData) -> some View {
        if data.seriesLabel == CafeWording.store {
            chartForegroundStyleScale(domain: data.seriesNames, mapping: CafeSeriesStyle.colour(for:))
        } else {
            chartForegroundStyleScale(domain: data.seriesNames, mapping: CafeSizeStyle.colour(for:))
        }
    }
}

/// The mistake: the same rows with no colour. They still stack, into one bar divided by hairlines.
struct UncolouredBarsChart: View {
    let summary: StackingSummary

    var body: some View {
        let data = summary.data
        let method = summary.method
        // snippet:stacking-mistake-bars
        Chart {
            ForEach(data.categories, id: \.self) { category in
                // What is drawn is one bar per position, so one element per position.
                Plot {
                    ForEach(data.rows(in: category)) { row in
                        // No foregroundStyle(by:). The rows still stack: nothing says which piece is which.
                        BarMark(
                            x: .value(data.categoryLabel, row.category),
                            y: .value(data.valueLabel, row.value),
                            stacking: method.markStacking
                        )
                        .opacity(method.markOpacity)
                    }
                }
                .accessibilityLabel(category)
                .accessibilityValue(summary.uncolouredValueText(for: category))
            }
        }
        // end
        .stackingAxis(summary)
        .accessibilityChartDescriptor(StackingChartDescriptor(summary: summary))
    }
}

/// The mistake with areas: series: keeps the bands apart, but they are all one colour.
struct UncolouredAreasChart: View {
    let summary: StackingSummary

    var body: some View {
        let data = summary.data
        let method = summary.method
        // snippet:stacking-mistake-areas
        Chart {
            ForEach(data.categories, id: \.self) { category in
                Plot {
                    ForEach(data.rows(in: category)) { row in
                        // series: separates the regions without a colour scale or a legend.
                        // The bands still stack: nothing says which band is which.
                        AreaMark(
                            x: .value(data.categoryLabel, row.category),
                            y: .value(data.valueLabel, row.value),
                            series: .value(data.seriesLabel, row.series),
                            stacking: method.markStacking
                        )
                        .opacity(method.markOpacity)
                    }
                }
                .accessibilityLabel(category)
                .accessibilityValue(summary.uncolouredValueText(for: category))
            }
        }
        // end
        .stackingAxis(summary)
        .accessibilityChartDescriptor(StackingChartDescriptor(summary: summary))
    }
}

private extension View {
    /// A normalized chart's axis reads 0 to 100: label it as a percentage, so it is not read as a quantity.
    /// The condition is inside the one axis closure, so the chart is the same view for every method
    /// and a change of method animates.
    func stackingAxis(_ summary: StackingSummary) -> some View {
        chartYAxis {
            if summary.method == .normalized {
                AxisMarks(format: Decimal.FormatStyle.Percent.percent.scale(1))
            } else {
                AxisMarks()
            }
        }
        // One value axis for the chart and the descriptor, for every method and data set.
        .chartYScale(domain: summary.valueDomain)
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes and series, and values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct StackingChartDescriptor: AXChartDescriptorRepresentable {
    let summary: StackingSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let data = summary.data
        let summary = summary
        let xAxis = AXCategoricalDataAxisDescriptor(title: data.categoryLabel, categoryOrder: data.categories)
        let yAxis = AXNumericDataAxisDescriptor(
            title: summary.valueAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in summary.spokenValue(value) }
        return AXChartDescriptor(
            title: summary.audioGraphTitle,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }

    /// One series per colour. With the colour removed a position is one shape, as its element is: one point
    /// per position at the top of what is drawn there, and a second series for the bottoms when stacks go below zero.
    private var series: [AXDataSeriesDescriptor] {
        let data = summary.data
        let isContinuous = summary.isContinuous
        if summary.isShowingMistake {
            return summary.uncolouredSeries.map { series in
                AXDataSeriesDescriptor(
                    name: series.name, isContinuous: isContinuous,
                    dataPoints: zip(data.categories, series.values).map { AXDataPoint(x: $0, y: $1) }
                )
            }
        }
        return data.seriesNames.map { name in
            AXDataSeriesDescriptor(
                name: name, isContinuous: isContinuous, dataPoints: data.rows.filter { $0.series == name }.map(point)
            )
        }
    }

    private func point(for row: StackRow) -> AXDataPoint {
        AXDataPoint(x: row.category, y: summary.signedLength(of: row))
    }
}

#Preview("Stacking") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/stacking") {
            StackingScreen(screen: screen)
        }
    }
}

#Preview("Nothing to stack") {
    StackingChart(summary: StackingViewModel(orders: [], changes: []).summary)
}
