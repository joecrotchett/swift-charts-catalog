import Accessibility
import Charts
import SwiftUI

/// "Layering marks": a range bar, a tick and a rule in one chart, sharing its scales.
struct LayeringMarksScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = LayeringMarksViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: CafeWording.monthlyRangesCaption,
            message: viewModel.summary.headline,
            explanation: """
            No single mark draws this chart. Three are layered in one Chart and share its scales, so they line up \
            on their own: a faint BarMark from each month's lowest day to its highest, a RectangleMark two points \
            tall at the average day, and a RuleMark across the plot at the average of the monthly averages. \
            The bar and the tick are given the same x value, unit and width, which is what puts each tick on its bar. \
            Marks are drawn in the order they are written, so the rule comes first and the ticks sit on top of it.
            """,
            snippets: viewModel.snippets
        ) {
            LayeringMarksChart(summary: viewModel.summary)
        } controls: {
            LayeringMarksControls(layers: $viewModel.layers)
        }
        .onChange(of: viewModel.layers) {
            // The chart changes without the reader touching it, so say what it now shows.
            AccessibilityNotification.Announcement(viewModel.summary.changeAnnouncement).post()
        }
    }
}

/// A switch per layer.
struct LayeringMarksControls: View {
    @Binding var layers: LayeringMarksLayers

    var body: some View {
        ControlsSection {
            Toggle("Range bar: lowest to highest day", isOn: $layers.range)
            Toggle("Tick: average day", isOn: $layers.tick)
            Toggle("Rule: average of the months", isOn: $layers.rule)
        }
    }
}

/// The layered chart, or a placeholder when there is nothing to draw.
struct LayeringMarksChart: View {
    let summary: LayeringMarksSummary

    var body: some View {
        if !summary.hasData {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each month's lowest, highest and average day appear here.")
            )
        } else if summary.layers.isEmpty {
            ContentUnavailableView(
                "No layers",
                systemImage: "square.3.layers.3d.slash",
                description: Text("Switch a layer on to draw it.")
            )
        } else {
            LayeringMarksLayeredChart(summary: summary)
                .accessibilityChartDescriptor(LayeringMarksChartDescriptor(summary: summary))
        }
    }
}

/// The three layers in one chart.
struct LayeringMarksLayeredChart: View {
    let summary: LayeringMarksSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The share of a month's band the bar and the tick both take, so they are the same width.
    private static let bandRatio = 0.6
    private static let rangeOpacity = 0.3
    private static let tickHeight: CGFloat = 2
    private static let ruleWidth: CGFloat = 3

    /// The calendar the months were made in. Without it a device west of UTC draws each month a month early.
    private var calendar: Calendar {
        CafeData.calendar
    }

    /// Every month is labelled until the text is large enough for the labels to collide.
    private var monthsPerLabel: Int {
        dynamicTypeSize >= .accessibility1 ? 2 : 1
    }

    var body: some View {
        Chart {
            if let average = summary.ruleValue {
                // snippet:layering-marks-rule
                // A value on y and nothing on x: the rule crosses the whole plot, on the same y scale.
                // Written first, so it is drawn first: a tick at nearly the same value sits on top of it
                // instead of vanishing under it (May's average, 230, against the rule's 231).
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(.blue)
                    .lineStyle(StrokeStyle(lineWidth: Self.ruleWidth))
                    .accessibilityLabel(summary.ruleName)
                    .accessibilityValue("\(LayeringMarksSummary.cupsText(average)) a day")
                // end
            }

            if summary.layers.showsMonthMarks {
                ForEach(summary.months) { month in
                    // One Plot around both marks: each month is one element that reads the values drawn for it.
                    Plot {
                        if summary.layers.range {
                            // snippet:layering-marks-range
                            // Start and end on y make the bar float from the lowest day to the highest.
                            BarMark(
                                x: .value("Month", month.month, unit: .month, calendar: calendar),
                                yStart: .value("Lowest day", month.lowestDay),
                                yEnd: .value("Highest day", month.highestDay),
                                width: .ratio(Self.bandRatio)
                            )
                            .opacity(Self.rangeOpacity)
                            // end
                        }
                        if summary.layers.tick {
                            // snippet:layering-marks-tick
                            // The same x value, unit and width as the bar, so the tick sits on it.
                            // A fixed height in points keeps it a thin line whatever the scale.
                            RectangleMark(
                                x: .value("Month", month.month, unit: .month, calendar: calendar),
                                y: .value("Average day", month.averageDay),
                                width: .ratio(Self.bandRatio),
                                height: .fixed(Self.tickHeight)
                            )
                            // end
                        }
                    }
                    .accessibilityLabel(LayeringMarksSummary.monthName(month.month))
                    .accessibilityValue(summary.accessibilityValue(for: month))
                }
                // One style for both monthly marks, greyed while the rule is the thing to look at.
                .foregroundStyle(summary.layers.rule ? Color.gray : Color.blue)
            }

            if let average = summary.ruleValue {
                // The rule's label, on a clear copy of the rule written after the bars: an annotation is drawn
                // in its mark's place, so on the rule itself the faint bars would be drawn over it.
                RuleMark(y: .value("Average", average))
                    .foregroundStyle(.clear)
                    .accessibilityHidden(true)
                    .annotation(position: .top, alignment: .leading) {
                        Text("Average: \(average, format: .number)")
                            .font(.caption.bold())
                            .foregroundStyle(.blue)
                    }
            }

            ForEach(summary.calloutMonths) { month in
                // A point of no size on the month the headline names: nothing is drawn, and the value has
                // a mark to hang on. The month's own element already reads the value.
                PointMark(
                    x: .value("Month", month.month, unit: .month, calendar: calendar),
                    y: .value("Cups", summary.calloutValue(for: month))
                )
                .symbolSize(0)
                .accessibilityHidden(true)
                // At the plot's edge the label slides sideways to stay inside it, and the scale grows to fit it above.
                .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .padScale)) {
                    Text(summary.calloutValue(for: month), format: .number)
                        .font(.caption.bold())
                }
            }
        }
        // Whichever layers are drawn, the scale reaches the highest day, so marks stay put as layers go. One
        // domain for the chart and the descriptor.
        .chartYScale(domain: summary.valueDomain)
        .chartXAxis {
            if summary.layers.showsMonthMarks {
                AxisMarks(values: .stride(by: .month, count: monthsPerLabel, calendar: calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(timeZone: calendar.timeZone).month(.abbreviated),
                        centered: true
                    )
                }
            }
        }
    }
}

/// The chart for the Audio Graph: one series for each value the drawn layers show per month.
/// The rule is not a series; the summary states it.
nonisolated struct LayeringMarksChartDescriptor: AXChartDescriptorRepresentable {
    let summary: LayeringMarksSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let layers = summary.layers
        let months = layers.showsMonthMarks ? summary.months : []
        let names = months.map { LayeringMarksSummary.monthName($0.month) }

        func series(_ name: String, _ value: (MonthlySummary) -> Int) -> AXDataSeriesDescriptor {
            AXDataSeriesDescriptor(
                name: name,
                isContinuous: false,
                dataPoints: months.map {
                    AXDataPoint(x: LayeringMarksSummary.monthName($0.month), y: Double(value($0)))
                }
            )
        }

        var allSeries: [AXDataSeriesDescriptor] = []
        if layers.range {
            allSeries.append(series("Lowest day") { $0.lowestDay })
            allSeries.append(series("Highest day") { $0.highestDay })
        }
        if layers.tick {
            allSeries.append(series("Average day") { $0.averageDay })
        }

        return AXChartDescriptor(
            title: CafeWording.monthlyRangesCaption,
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.month, categoryOrder: names),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle,
                // The drawn scale starts at zero and always reaches the highest day, rounded up.
                range: summary.valueDomain,
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: .current) { count, _ in LayeringMarksSummary.cupsText(count) } },
            additionalAxes: [],
            series: allSeries
        )
    }
}

#Preview("Layers") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/layering-marks") {
            LayeringMarksScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    LayeringMarksChart(summary: LayeringMarksSummary(months: [], layers: LayeringMarksLayers()))
}
