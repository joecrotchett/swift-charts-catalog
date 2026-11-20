import Accessibility
import Charts
import SwiftUI

/// "Select a value": `chartXSelection(value:)`, the raw value it reports, snapping that value to the nearest
/// day, and a rule with a popover drawn as marks at the selection.
struct SelectValueScreen: View {
    let screen: CatalogScreen
    @State private var model: SelectValueViewModel
    /// Read here and passed in, so the headline, the elements, the popover and the Audio Graph write numbers
    /// and dates the way the chart's own axis does.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.harbourSales) {
        self.screen = screen
        _model = State(initialValue: SelectValueViewModel(days: days))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: SelectValueSummary.caption,
            message: model.headline(locale: locale),
            reservedMessage: model.reservedHeadline(locale: locale),
            explanation: """
            chartXSelection(value:) binds the position under the finger: on iPhone, touch and hold the plot, \
            or press and drag; lifting the finger clears the selection. \
            It reports the exact value on the axis, a date with a time of day, so the chart snaps it to the \
            nearest day before drawing a rule and a popover there. Both are marks inside the chart, so they \
            stay on the data. VoiceOver reads each day, with its cups, without a gesture.
            """,
            snippets: model.snippets
        ) {
            SelectValueChart(model: model, locale: locale)
        } controls: {
            SelectValueControls(model: model)
        }
    }
}

/// The snapping toggle. The selection clears when the finger lifts, so the toggle almost never changes
/// anything drawn while a selection exists; nothing is announced, and the switch speaks its own value.
struct SelectValueControls: View {
    @Bindable var model: SelectValueViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ControlsSection {
            Toggle("Snap to the nearest day", isOn: $model.isSnapping)
                // While the placeholder replaces the chart there is nothing for it to change.
                .disabled(model.days.isEmpty)
            Text(model.isSnapping
                ? "The rule and popover sit on the day nearest the finger."
                : "The rule and popover show the raw value the binding reports.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            if dynamicTypeSize.isAccessibilitySize {
                Text("At this text size the popover shows only the cups or the time; the headline above the chart gives the day.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A line of the Harbour café's days with a selection rule and popover, or a placeholder with no days.
struct SelectValueChart: View {
    @Bindable var model: SelectValueViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room above the plot for the popover, which draws above the plot area. Reserved at rest too, so the
    /// chart does not jump when a selection appears; it grows with the text.
    @ScaledMetric(relativeTo: .body) private var popoverRoom: CGFloat = SelectValueMetrics.popoverRoom

    private var summary: SelectValueSummary {
        model.summary(locale: locale)
    }

    /// Fewer axis labels as the text grows, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 14 : 7
    }

    var body: some View {
        if model.days.isEmpty {
            ContentUnavailableView(
                "No days of sales yet",
                systemImage: "chart.xyaxis.line",
                description: Text("Each day's cups appear here as a line you can touch to select a day.")
            )
        } else {
            Chart {
                ForEach(model.days) { day in
                    Plot {
                        LineMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: SelectValueSummary.calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                        .symbol(.circle)
                    }
                    .accessibilityLabel(summary.dayText(day.day))
                    .accessibilityValue(summary.cups(day.cups))
                }

                if let day = model.snappedDay, let raw = model.rawSelection {
                    // snippet:select-a-value-snapped-rule
                    // Drawn from the snapped day, with the same unit as the line, so it sits on a point.
                    RuleMark(x: .value(SelectValueSummary.selectedValueLabel, day.day, unit: .day, calendar: SelectValueSummary.calendar))
                        .foregroundStyle(Color.gray.opacity(SelectValueMetrics.ruleOpacity))
                        // The indicator repeats what the day's element already says.
                        .accessibilityHidden(true)
                        .zIndex(-1)
                        .annotation(
                            position: .top, spacing: 0,
                            // Slide inward at the chart's edges; draw above the plot, in the room kept for it.
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            SelectValuePopover(text: summary.snappedPopover(day: day, rawSelection: raw))
                        }
                    // end
                } else if let raw = model.unsnappedSelection {
                    // snippet:select-a-value-raw-rule
                    // The raw value, unsnapped: an instant with a time of day, usually between two points.
                    RuleMark(x: .value(SelectValueSummary.selectedValueLabel, raw))
                        .foregroundStyle(Color.gray.opacity(SelectValueMetrics.ruleOpacity))
                        .accessibilityHidden(true)
                        .zIndex(-1)
                        .annotation(position: .top, spacing: 0, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                            SelectValuePopover(text: summary.rawPopover(rawSelection: raw))
                        }
                    // end
                }
            }
            // snippet:select-a-value-binding
            // The binding is nil until the finger touches the plot, then the exact x value under it.
            .chartXSelection(value: $model.rawSelection)
            // end
            .chartXAxis {
                AxisMarks(
                    format: Date.FormatStyle(
                        locale: locale, calendar: SelectValueSummary.calendar, timeZone: SelectValueSummary.calendar.timeZone
                    ).month(.abbreviated).day(),
                    values: .stride(by: .day, count: daysPerLabel, calendar: SelectValueSummary.calendar)
                )
            }
            // One value axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartYScale(domain: SelectValueChartDescriptor.valueDomain(for: model.days))
            .accessibilityChartDescriptor(SelectValueChartDescriptor(days: model.days, locale: locale))
            .padding(.top, popoverRoom)
        }
    }
}

/// The popover above the selection rule: what is selected, its value, and where it came from.
struct SelectValuePopover: View {
    let text: SelectValuePopoverText
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // At the accessibility sizes three lines are wider than a phone's chart: one line is shown,
            // and the controls say so.
            if dynamicTypeSize.isAccessibilitySize {
                Text(text.compactValue)
                    .font(.callout.bold())
            } else {
                Text(text.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(text.value)
                    .font(.callout.bold())
                Text(text.footnote)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .fixedSize()
        .padding(SelectValueMetrics.popoverPadding)
        .background(Color.gray.opacity(SelectValueMetrics.popoverBackgroundOpacity), in: .rect(cornerRadius: SelectValueMetrics.popoverCornerRadius))
    }
}

/// Constants that belong to this chart's marks and popover.
private enum SelectValueMetrics {
    static let popoverRoom: CGFloat = 60
    static let ruleOpacity = 0.5
    static let popoverPadding: CGFloat = 6
    static let popoverCornerRadius: CGFloat = 6
    static let popoverBackgroundOpacity = 0.15
}

/// The chart for the Audio Graph: a title, a summary in actual values, written-out dates, and values in cups.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SelectValueChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let locale: Locale

    /// The value axis as drawn and as given here: 0 to the most cups, rounded up to a tidy step.
    static func valueDomain(for days: [DailySales]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.map(\.cups))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = SelectValueSummary(days: days, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.dayText($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: Self.valueDomain(for: days),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: true,
            dataPoints: days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the Harbour café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Select a value") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/select-a-value") {
            SelectValueScreen(screen: screen)
        }
    }
}

#Preview("No days") {
    SelectValueChart(model: SelectValueViewModel(days: []), locale: .current)
}
