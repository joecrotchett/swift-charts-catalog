import Accessibility
import Charts
import SwiftUI

/// "Diverging bar": signed values growing left and right from zero, named beside the bars.
struct DivergingBarScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = DivergingBarViewModel()
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        @Bindable var viewModel = viewModel
        CatalogScreenScaffold(
            screen: screen,
            caption: "Change in cups against last month",
            message: viewModel.summary(locale: locale).headline,
            // The labels are laid out differently at the accessibility text sizes, and the text says so.
            explanation: viewModel.explanation(labelsAboveBars: dynamicTypeSize.isAccessibilitySize),
            // See Code shows the row that is drawn: the large-text row at those sizes.
            snippets: viewModel.snippets(labelsAboveBars: dynamicTypeSize.isAccessibilitySize)
        ) {
            DivergingBarChart(changes: viewModel.drawnChanges)
        } controls: {
            ControlsSection {
                // The same drinks in a new order: the bars animate to their new rows.
                Toggle("Sort by change", isOn: $viewModel.isSorted.animation(.easeInOut))
            }
        }
        .onChange(of: viewModel.isSorted) {
            // The order of the chart's data changed: say so, for people who cannot see it happen.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// Which way a drink's sales went. The raw values are the words the colour scale is keyed by.
nonisolated enum DivergingBarDirection: String, Plottable {
    case fewer = "Fewer cups"
    case more = "More cups"

    init(change: Int) {
        self = change >= 0 ? .more : .fewer
    }
}

/// Constants that belong to this chart's marks.
private enum DivergingBarMetrics {
    /// The gap between a bar and the name or number beside it.
    static let annotationSpacing: CGFloat = 6
    /// The gap between a bar and the label above it, at the accessibility text sizes.
    static let labelAboveSpacing: CGFloat = 2
    /// The share of its row a bar takes when its label sits above it.
    static let barHeightUnderLabel = 0.4
    /// Room above the first row for its label at the default text size; scaled with the text.
    static let labelRoom: CGFloat = 8
    /// About how many axis values to mark when the labels are at an accessibility text size.
    static let largeTextAxisValueCount = 3
}

// snippet:diverging-bar-marks
/// One row of a diverging bar chart: a bar from zero, its name at its base and its signed value at its end.
struct DivergingBarRow: ChartContent {
    let item: DrinkChange
    /// A signed whole number in the view's locale: "+212", "-305".
    let signedFormat: IntegerFormatStyle<Int>

    var body: some ChartContent {
        // A bar grows from zero toward its value: left when negative, right when positive.
        BarMark(
            x: .value(CafeWording.changeAxisTitle, item.change),
            y: .value(CafeWording.drink, item.drink)
        )
        // Side and sign already show the direction; colour is a second cue.
        .foregroundStyle(by: .value("Direction", DivergingBarDirection(change: item.change)))
        // The name sits at the bar's base, on the side the bar does not occupy.
        .annotation(
            position: item.change >= 0 ? .leading : .trailing,
            alignment: .center,
            spacing: DivergingBarMetrics.annotationSpacing
        ) {
            Text(item.drink).font(.caption)
        }
        // The signed value sits beyond the bar's end. When the longest bar reaches the plot's edge the
        // scale is extended to make room, so the number stays outside its bar; fitting it to the plot
        // or the chart would slide grey text onto the bar's colour.
        .annotation(
            position: item.change >= 0 ? .trailing : .leading,
            alignment: .center,
            spacing: DivergingBarMetrics.annotationSpacing,
            overflowResolution: .init(x: .padScale, y: .disabled)
        ) {
            Text(item.change, format: signedFormat)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// end

// snippet:diverging-bar-large-text
/// The same row at the accessibility text sizes, where a name and a number no longer fit on either
/// side of a bar: a thinner bar with both above it, starting from the zero line.
struct DivergingBarLargeTextRow: ChartContent {
    let item: DrinkChange
    let signedFormat: IntegerFormatStyle<Int>

    var body: some ChartContent {
        BarMark(
            x: .value(CafeWording.changeAxisTitle, item.change),
            y: .value(CafeWording.drink, item.drink),
            height: .ratio(DivergingBarMetrics.barHeightUnderLabel)
        )
        .foregroundStyle(by: .value("Direction", DivergingBarDirection(change: item.change)))
        // Above the bar, lined up with the zero line and running toward the bar's side.
        // Where it would cross the chart's edge it slides inward; above the bar it covers nothing.
        .annotation(
            position: .top,
            alignment: item.change >= 0 ? .leading : .trailing,
            spacing: DivergingBarMetrics.labelAboveSpacing,
            overflowResolution: .init(x: .fit(to: .chart), y: .automatic)
        ) {
            HStack(alignment: .firstTextBaseline, spacing: DivergingBarMetrics.annotationSpacing) {
                Text(item.drink)
                Text(item.change, format: signedFormat).foregroundStyle(.secondary)
            }
            .font(.caption)
            .lineLimit(1)
        }
    }
}

// end

/// One bar per drink growing from zero, or a placeholder when there is nothing to draw.
struct DivergingBarChart: View {
    /// In the order to draw them, top to bottom.
    let changes: [DrinkChange]
    @Environment(\.locale) private var locale
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room above the first row for its label, when labels sit above the bars. It grows with the text.
    @ScaledMetric(relativeTo: .caption) private var labelRoom = DivergingBarMetrics.labelRoom

    /// A signed whole number in the view's locale: "+212", "-305", and a bare "0".
    private var signedFormat: IntegerFormatStyle<Int> {
        IntegerFormatStyle<Int>.number.sign(strategy: .always(includingZero: false)).locale(locale)
    }

    /// Says what each side means. The x axis runs from the right in a right-to-left layout, so the
    /// words swap sides with it. At the accessibility text sizes one line does not fit, so it is two.
    private var axisTitle: String {
        let (left, right) = layoutDirection == .rightToLeft ? ("more cups", "fewer cups") : ("fewer cups", "more cups")
        return dynamicTypeSize.isAccessibilitySize
            ? "← \(left)\n\(right) →"
            : "← \(left) · \(CafeWording.changeAxisTitle) · \(right) →"
    }

    var body: some View {
        let summary = DivergingBarSummary(changes: changes, locale: locale)
        // Bars grow from zero, so rows of zero would draw axes with no bars.
        if !summary.hasBars {
            ContentUnavailableView(
                "No changes yet",
                systemImage: "arrow.left.arrow.right",
                description: Text("Each drink's change in cups against last month appears here, one bar per drink.")
            )
        } else {
            Chart(changes) { item in
                // The Plot carries the words VoiceOver reads: annotations are not read.
                Plot {
                    if dynamicTypeSize.isAccessibilitySize {
                        DivergingBarLargeTextRow(item: item, signedFormat: signedFormat)
                    } else {
                        DivergingBarRow(item: item, signedFormat: signedFormat)
                    }
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(summary.valueText(item.change))
            }
            // snippet:diverging-bar-axes
            // Names are annotations beside each bar; a y axis would repeat them far from the bars.
            .chartYAxis(.hidden)
            .chartXAxis {
                // Fewer values at the accessibility text sizes, so the signed labels do not collide.
                AxisMarks(
                    position: .top,
                    values: dynamicTypeSize.isAccessibilitySize
                        ? .automatic(desiredCount: DivergingBarMetrics.largeTextAxisValueCount)
                        : .automatic
                ) {
                    AxisGridLine()
                    // An explicit format carries its own locale, so it is given the view's.
                    AxisValueLabel(format: signedFormat)
                }
            }
            // The axis title says what each direction means, so the colours need no legend.
            .chartXAxisLabel(position: .top, alignment: .center) {
                Text(axisTitle).multilineTextAlignment(.center)
            }
            .chartForegroundStyleScale([
                DivergingBarDirection.fewer: Color.orange,
                DivergingBarDirection.more: Color.blue,
            ])
            .chartLegend(.hidden)
            // end
            // One change axis for the chart and the descriptor.
            .chartXScale(domain: summary.valueDomain)
            // A label above the first bar would otherwise sit on the axis labels.
            .chartYScale(range: .plotDimension(
                startPadding: dynamicTypeSize.isAccessibilitySize ? labelRoom : 0, endPadding: 0
            ))
            .accessibilityChartDescriptor(DivergingBarChartDescriptor(changes: changes, locale: locale))
        }
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes, and changes said with unit and direction.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct DivergingBarChartDescriptor: AXChartDescriptorRepresentable {
    /// In the order they are drawn.
    let changes: [DrinkChange]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = DivergingBarSummary(changes: changes, locale: locale)
        // Categories go on the descriptor's x axis whichever way the chart is drawn.
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: changes.map(\.drink)
        )
        // The drawn scale, through zero.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.changeAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value.rounded(), locale: locale) { count, _ in summary.valueText(count) } }
        let series = AXDataSeriesDescriptor(
            name: "Change against last month",
            isContinuous: false,
            dataPoints: changes.map { AXDataPoint(x: $0.drink, y: Double($0.change)) }
        )
        return AXChartDescriptor(
            title: "Change in cups against last month, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Diverging bar") {
    NavigationStack {
        DivergingBarScreen(
            screen: CatalogScreen(
                id: "marks/diverging-bar", title: "Diverging bar", summary: "", apiSince: "16.0",
                skillReferences: ["gallery/diverging-bar.md"]
            )
        )
    }
}

#Preview("Large text") {
    DivergingBarChart(changes: CafeData.drinkChanges)
        .environment(\.dynamicTypeSize, .accessibility3)
        .padding()
}

#Preview("Nothing changed") {
    DivergingBarChart(changes: [DrinkChange(drink: "Latte", change: 0), DrinkChange(drink: "Tea", change: 0)])
}
