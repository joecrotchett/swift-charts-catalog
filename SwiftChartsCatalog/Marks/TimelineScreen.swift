import Accessibility
import Charts
import SwiftUI

/// "Timeline": interval bars per row (a Gantt chart), and the thin-rule version of the same form.
struct TimelineScreen: View {
    let screen: CatalogScreen
    @State private var model = TimelineViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Today's shifts",
            message: model.headline(locale: locale),
            explanation: """
            A timeline gives every mark an interval on x, a start and an end, and a row on y. A row holds as many \
            marks as it has intervals, so a barista with a split shift gets two. BarMark and RuleMark take the same \
            three values; the rule is the lighter version. Row names are drawn inside the plot by default, above \
            each row, and an axis preset moves them outside.
            """,
            snippets: model.snippets
        ) {
            TimelineChart(
                shifts: model.shifts, markStyle: model.markStyle, labelPlacement: model.labelPlacement,
                calendar: model.calendar
            )
        } controls: {
            ControlsSection {
                LabeledSegmentedPicker(title: "Mark", selection: $model.markStyle) {
                    ForEach(TimelineMarkStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                LabeledSegmentedPicker(title: "Row labels", selection: $model.labelPlacement) {
                    ForEach(TimelineLabelPlacement.allCases) { placement in
                        Text(placement.title).tag(placement)
                    }
                }
            }
        }
        // The mark picker changes the kind of mark, so it says what changed and then what the chart shows.
        // The row-label picker changes neither data, scale nor mark, and speaks its own value: it says no more.
        .onChange(of: model.markStyle) {
            AccessibilityNotification.Announcement(model.markStyleAnnouncement(locale: locale)).post()
        }
    }
}

/// Sizes that belong to this chart's marks and axis.
private enum TimelineMetrics {
    /// The thickness of a rule. Its round cap reaches half of this past each end.
    static let ruleWidth: CGFloat = 6
    /// A time label every three hours, and every six at the accessibility text sizes.
    static let hoursPerLabel = 3
    static let hoursPerLabelLargeText = 6
}

/// One bar or rule per shift, a row per barista, or a placeholder when there are no shifts.
struct TimelineChart: View {
    let shifts: [Shift]
    let markStyle: TimelineMarkStyle
    let labelPlacement: TimelineLabelPlacement
    /// The calendar the shift times were made in. The axis and every spoken time use its time zone.
    var calendar = CafeData.calendar
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var hoursPerLabel: Int {
        dynamicTypeSize.isAccessibilitySize ? TimelineMetrics.hoursPerLabelLargeText : TimelineMetrics.hoursPerLabel
    }

    var body: some View {
        let summary = TimelineSummary(shifts: shifts, calendar: calendar, locale: locale)
        if summary.shifts.isEmpty {
            ContentUnavailableView(
                "No shifts scheduled",
                systemImage: "calendar",
                description: Text("Today's shifts appear here, one row per barista.")
            )
        } else {
            Chart(summary.shifts) { shift in
                // The name and the times go on a Plot around the mark. Without it a row is one element
                // that says only the barista's name.
                Plot {
                    switch markStyle {
                    case .bars:
                        // snippet:timeline-bars
                        // An interval on x and a row on y. One mark per shift:
                        // a barista with two shifts gets two bars in one row.
                        BarMark(
                            xStart: .value(CafeWording.shiftStart, shift.start),
                            xEnd: .value(CafeWording.shiftEnd, shift.end),
                            y: .value(CafeWording.barista, shift.barista)
                        )
                    // end
                    case .rules:
                        // snippet:timeline-rules
                        // The same three values on a rule. The style replaces the rule's default
                        // width and cap, so it sets both.
                        RuleMark(
                            xStart: .value(CafeWording.shiftStart, shift.start),
                            xEnd: .value(CafeWording.shiftEnd, shift.end),
                            y: .value(CafeWording.barista, shift.barista)
                        )
                        .lineStyle(StrokeStyle(lineWidth: TimelineMetrics.ruleWidth, lineCap: .round))
                        // end
                    }
                }
                .accessibilityLabel(shift.barista)
                .accessibilityValue(summary.spokenValue(of: shift))
            }
            // A round cap reaches half the rule's width past its ends, and the first shift starts at the
            // edge of the scale. The room is kept for both marks, so the scale does not move between them.
            .chartXScale(range: .plotDimension(padding: TimelineMetrics.ruleWidth / 2))
            .chartXAxis {
                // The times were made in UTC. The default axis would label them in the device's time zone.
                AxisMarks(values: .stride(by: .hour, count: hoursPerLabel, calendar: calendar)) { value in
                    AxisGridLine()
                    AxisTick()
                    // A time label sits after its grid line, and the last line is at the plot's edge, where
                    // there is no room after it: that label is drawn before its line instead.
                    let isLast = value.index == value.count - 1
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, timeZone: calendar.timeZone).hour(),
                        anchor: isLast ? .topTrailing : nil,
                        collisionResolution: .greedy(priority: isLast ? 1 : 0)
                    )
                }
            }
            .chartYAxis {
                switch labelPlacement {
                case .inside:
                    // snippet:timeline-labels-inside
                    // The default for categories on y: each name inside the plot, above its row.
                    AxisMarks()
                // end
                case .outside:
                    // snippet:timeline-labels-outside
                    // Names outside the plot, on the leading edge, each centred on its row.
                    AxisMarks(preset: .aligned, position: .leading)
                    // end
                }
            }
            .accessibilityChartDescriptor(TimelineChartDescriptor(summary: summary))
        }
    }
}

/// The timeline for the Audio Graph, which a timeline does not get by itself: one category per shift,
/// and two series over them, when each shift starts and when it ends.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct TimelineChartDescriptor: AXChartDescriptorRepresentable {
    let summary: TimelineSummary

    static let title = "Today's shifts, by barista"

    func makeChartDescriptor() -> AXChartDescriptor {
        let names = summary.shiftNames
        let earliest = summary.earliestStart.map(summary.hours) ?? 0
        let latest = summary.latestEnd.map(summary.hours) ?? 0
        let summary = summary
        let xAxis = AXCategoricalDataAxisDescriptor(title: TimelineWording.shift, categoryOrder: names)
        // The range is the drawn scale: the first start to the last end.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.slot,
            range: earliest ... max(earliest, latest),
            gridlinePositions: []
        ) { hours in summary.time(atHours: hours) }
        let starts = AXDataSeriesDescriptor(
            name: CafeWording.shiftStart,
            isContinuous: false,
            dataPoints: zip(names, summary.shifts).map { AXDataPoint(x: $0, y: summary.hours($1.start)) }
        )
        let ends = AXDataSeriesDescriptor(
            name: CafeWording.shiftEnd,
            isContinuous: false,
            dataPoints: zip(names, summary.shifts).map { AXDataPoint(x: $0, y: summary.hours($1.end)) }
        )
        return AXChartDescriptor(
            title: Self.title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [starts, ends]
        )
    }
}

#Preview("Timeline") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/timeline") {
            TimelineScreen(screen: screen)
        }
    }
}

#Preview("Rules, labels inside") {
    TimelineChart(shifts: CafeData.shifts, markStyle: .rules, labelPlacement: .inside)
        .padding()
}

#Preview("No shifts") {
    TimelineChart(shifts: [], markStyle: .bars, labelPlacement: .outside)
}
