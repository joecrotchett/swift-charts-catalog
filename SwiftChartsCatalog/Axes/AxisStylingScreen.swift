import Accessibility
import Charts
import SwiftUI

/// "Styling axis marks": the stroke and colour of grid lines, the length of ticks, and the font and
/// orientation of labels, each set on the axis mark inside an `AxisMarks` closure.
struct AxisStylingScreen: View {
    let screen: CatalogScreen
    var sales = CafeData.drinkSales
    @State private var viewModel = AxisStylingViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers the
    /// way the chart's own axis does.
    @Environment(\.locale) private var locale
    /// Above a size the drink names overlap unless they are turned, so the chart turns them itself.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: AxisStylingSummary(sales: sales, locale: locale).headline,
            explanation: """
            Each part of an axis is an axis mark, and each takes its own styling. AxisGridLine and AxisTick take \
            a StrokeStyle, AxisTick a length, and AxisValueLabel an orientation; all three take foregroundStyle \
            and font. Listing them in an AxisMarks closure replaces the default parts, so every part the axis \
            should keep is listed too.
            """,
            snippets: viewModel.snippets(at: dynamicTypeSize)
        ) {
            AxisStylingChart(sales: sales, locale: locale, style: viewModel.style.drawn(at: dynamicTypeSize))
        } controls: {
            AxisStylingControls(
                style: $viewModel.style,
                namesMustBeVertical: AxisStylingStyle.namesMustBeVertical(at: dynamicTypeSize)
            )
        }
    }
}

/// One toggle per axis-mark property. Each restyles an axis and says its own state, and none changes
/// the data or the headline, so none posts an announcement.
struct AxisStylingControls: View {
    @Binding var style: AxisStylingStyle
    /// At large text sizes the names are turned whatever the toggle says, so the toggle is shown on and
    /// cannot be turned off, with the reason beneath it.
    var namesMustBeVertical = false

    var body: some View {
        ControlsSection {
            Toggle("Dashed grid lines", isOn: $style.dashedGridLines)
            Toggle("Orange grid lines", isOn: $style.orangeGridLines)
            Toggle("Longer ticks", isOn: $style.longTicks)
            Toggle("Bold drink names", isOn: $style.boldLabels)
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Toggle("Vertical drink names", isOn: namesMustBeVertical ? .constant(true) : $style.verticalLabels)
                    .disabled(namesMustBeVertical)
                if namesMustBeVertical {
                    Text("At this text size the drink names are always vertical, or they would overlap.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// Strokes and sizes that belong to this chart's axis marks.
private enum AxisStylingMetrics {
    /// One point wide, two on and four off.
    static let dashedStroke = StrokeStyle(lineWidth: 1, dash: [2, 4])
    static let longTickLength: CGFloat = 12
    /// From the plot's edge to the label: the tick's length and a small gap after it.
    static let longTickLabelSpacing: CGFloat = longTickLength + 3
}

/// One bar per drink, with axes styled by the toggles, or a placeholder when nothing has been sold.
struct AxisStylingChart: View {
    let sales: [DrinkSales]
    let locale: Locale
    let style: AxisStylingStyle

    var body: some View {
        if AxisStylingSummary(sales: sales, locale: locale).hasSales {
            Chart(sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, item.drink),
                        y: .value(CafeWording.cups, item.cups)
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            .chartYAxis {
                // A closure draws only what it lists, so the grid line, tick and label are all listed.
                AxisMarks { _ in
                    if style.dashedGridLines, style.orangeGridLines {
                        // snippet:axis-styling-grid-dashed-orange
                        AxisGridLine(stroke: AxisStylingMetrics.dashedStroke)
                            .foregroundStyle(Color.orange)
                        // end
                    } else if style.dashedGridLines {
                        // snippet:axis-styling-grid-dashed
                        AxisGridLine(stroke: AxisStylingMetrics.dashedStroke)
                        // end
                    } else if style.orangeGridLines {
                        // snippet:axis-styling-grid-orange
                        AxisGridLine()
                            .foregroundStyle(Color.orange)
                        // end
                    } else {
                        // snippet:axis-styling-grid-default
                        AxisGridLine()
                        // end
                    }
                    if style.longTicks {
                        // snippet:axis-styling-tick-long
                        AxisTick(length: AxisStylingMetrics.longTickLength)
                        // A longer tick does not move the label: without the spacing it runs through it.
                        AxisValueLabel(horizontalSpacing: AxisStylingMetrics.longTickLabelSpacing)
                        // end
                    } else {
                        // snippet:axis-styling-tick-default
                        AxisTick()
                        AxisValueLabel()
                        // end
                    }
                }
            }
            .chartXAxis {
                // A category axis has grid lines and labels by default, and no ticks.
                AxisMarks { _ in
                    AxisGridLine()
                    if style.boldLabels, style.verticalLabels {
                        // snippet:axis-styling-label-bold-vertical
                        AxisValueLabel(orientation: .vertical)
                            .font(.caption.bold())
                        // end
                    } else if style.boldLabels {
                        // snippet:axis-styling-label-bold
                        AxisValueLabel()
                            .font(.caption.bold())
                        // end
                    } else if style.verticalLabels {
                        // snippet:axis-styling-label-vertical
                        AxisValueLabel(orientation: .vertical)
                        // end
                    } else {
                        // snippet:axis-styling-label-default
                        AxisValueLabel()
                        // end
                    }
                }
            }
            // One value axis for the chart and the descriptor: the most cups, rounded up to the axis step.
            .chartYScale(domain: ChartAxis.valueDomain(for: sales.map(\.cups)))
            .accessibilityChartDescriptor(AxisStylingChartDescriptor(sales: sales, locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        }
    }
}

#Preview("Default axes") {
    NavigationStack {
        AxisStylingScreen(
            screen: Catalog.screen(id: "axes/styling-axis-marks") ?? CatalogScreen(
                id: "axes/styling-axis-marks", title: "Styling axis marks", summary: "", apiSince: "16.0",
                skillReferences: ["axes.md"]
            )
        )
    }
}

#Preview("Every style on") {
    AxisStylingChart(
        sales: CafeData.drinkSales, locale: .current,
        style: AxisStylingStyle(
            dashedGridLines: true, orangeGridLines: true, longTicks: true, boldLabels: true, verticalLabels: true
        )
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("Largest text") {
    NavigationStack {
        AxisStylingScreen(
            screen: Catalog.screen(id: "axes/styling-axis-marks") ?? CatalogScreen(
                id: "axes/styling-axis-marks", title: "Styling axis marks", summary: "", apiSince: "16.0",
                skillReferences: ["axes.md"]
            )
        )
    }
    .environment(\.dynamicTypeSize, .accessibility3)
}

#Preview("No sales") {
    AxisStylingChart(sales: [], locale: .current, style: AxisStylingStyle())
}
