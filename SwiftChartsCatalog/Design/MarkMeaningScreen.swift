import Accessibility
import Charts
import SwiftUI

/// "Marks: what each communicates": the same thirty days as bars, a line or points, each with what it makes
/// easy to see, and points added to the line with `symbol`.
struct MarkMeaningScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = MarkMeaningViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and dates
    /// the way the chart's axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption(locale: locale),
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            MarkMeaningChartPanel(viewModel: viewModel, locale: locale)
        } controls: {
            MarkMeaningControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The chart, or a placeholder when there is nothing to draw.
struct MarkMeaningChartPanel: View {
    let viewModel: MarkMeaningViewModel
    let locale: Locale

    var body: some View {
        if viewModel.showsPlaceholder {
            ContentUnavailableView(
                viewModel.placeholderTitle,
                systemImage: "cup.and.saucer",
                description: Text(viewModel.placeholderDescription)
            )
        } else {
            MarkMeaningChart(
                days: viewModel.days,
                mark: viewModel.mark,
                pointsOnLine: viewModel.showsPointsOnLine,
                cupsAxis: viewModel.cupsAxis,
                locale: locale
            )
            .accessibilityChartDescriptor(viewModel.descriptor(locale: locale))
        }
    }
}

/// One mark per day, of the kind picked. Plain values in, so the per-day closure reads no state of its own.
struct MarkMeaningChart: View {
    let days: [DailySales]
    let mark: MarkMeaningMark
    let pointsOnLine: Bool
    let cupsAxis: ClosedRange<Double>
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room at each end of the x axis, so the label centred on the last weekly grid line ("Mar 29") is drawn
    /// whole instead of being left out (`axes.md`, on the label at the trailing edge).
    @ScaledMetric(relativeTo: .caption2) private var edgeLabelRoom = MarkMeaningStyle.edgeLabelRoom
    /// Room above the highest bar or point for the label that carries its cups.
    @ScaledMetric(relativeTo: .caption) private var topLabelRoom = MarkMeaningStyle.topLabelRoom

    /// A label every week, or every fortnight at the largest text sizes, where centred day numbers a week
    /// apart ran into each other on a phone.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 14 : 7
    }

    /// The axis labels: the day alone at the largest text sizes, as narrow as a label can be.
    private var axisLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return dynamicTypeSize >= .accessibility3 ? style.day() : style.month(.abbreviated).day()
    }

    var body: some View {
        let summary = MarkMeaningSummary(days: days, locale: locale)
        Chart {
            ForEach(days) { day in
                // One labelled Plot per day: thirty elements, each read as its day and its cups, whatever the mark.
                Plot {
                    switch mark {
                    case .bars:
                        // snippet:marks-what-each-communicates-bars
                        // Bars for amounts to compare: each day its own bar, rising from zero.
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                    // end
                    case .line:
                        if pointsOnLine {
                            // snippet:marks-what-each-communicates-line-points
                            // The same line with a symbol at each day: the trend and every reading together.
                            // A symbol adds no marks, so nothing is counted twice.
                            LineMark(
                                x: .value(CafeWording.day, day.day),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            .symbol(.circle)
                            // end
                        } else {
                            // snippet:marks-what-each-communicates-line
                            // A line for change over time. No unit: its points fall on the weekly grid lines.
                            LineMark(
                                x: .value(CafeWording.day, day.day),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            // end
                        }
                    case .points:
                        // A clear band the full height of the plot gives every day's element the same top edge,
                        // so VoiceOver reads the days along x rather than by the height of their points.
                        RectangleMark(x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar))
                            .foregroundStyle(.clear)
                        // snippet:marks-what-each-communicates-points
                        // Points for single readings: each day a dot, joined to nothing.
                        PointMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                        // end
                    }
                }
                .accessibilityLabel(summary.elementLabel(day.day))
                .accessibilityValue(summary.elementValue(day.cups))
            }
            // The highest day's cups, written above its bar or point, so the headline's figure is on the chart.
            // The label hangs on a point of no size, hidden: the day's own element already says its cups.
            ForEach(summary.labelledDays(mark: mark)) { day in
                PointMark(
                    x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value(CafeWording.cups, day.cups)
                )
                .symbolSize(0)
                .accessibilityHidden(true)
                .annotation(position: .top) {
                    Text(summary.labelText(day.cups))
                        .font(.caption.weight(.semibold))
                }
            }
        }
        // From zero for every mark, so switching the mark changes nothing else; the descriptor shares it.
        .chartYScale(domain: cupsAxis, range: .plotDimension(endPadding: topLabelRoom))
        .chartXScale(range: .plotDimension(padding: min(edgeLabelRoom, MarkMeaningStyle.edgeLabelRoomLimit)))
        .chartXAxis {
            // Each label centred on its grid line, so the last one has room and is drawn.
            AxisMarks(preset: .aligned, values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: axisLabelFormat)
            }
        }
        // A different kind of mark is a different chart: no animation from one into the other, and fresh elements.
        .id("\(mark.rawValue)-\(pointsOnLine)")
    }
}

/// Constants that belong to this chart alone.
private enum MarkMeaningStyle {
    static let edgeLabelRoom: CGFloat = 12
    /// The most room it grows to: at the accessibility sizes the labels are day numbers, and room scaled with
    /// the text narrowed the plot until the labels ran into each other.
    static let edgeLabelRoomLimit: CGFloat = 16
    static let topLabelRoom: CGFloat = 16
}

/// The mark picker and the combine toggle. Each change is announced: what changed, then the headline.
struct MarkMeaningControls: View {
    @Bindable var viewModel: MarkMeaningViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Mark", selection: $viewModel.mark) {
                ForEach(MarkMeaningMark.allCases) { mark in
                    Text(mark.title).tag(mark)
                }
            }
            .disabled(viewModel.isMarkPickerDisabled)
            Toggle("Points on the line", isOn: $viewModel.pointsOnLine)
                .disabled(viewModel.isCombineToggleDisabled)
        }
        .onChange(of: viewModel.mark) {
            announce(viewModel.markChangeAnnouncement(locale: locale))
        }
        .onChange(of: viewModel.pointsOnLine) {
            // The toggle is disabled away from the line, so a change here always redraws the line.
            announce(viewModel.pointsChangeAnnouncement(locale: locale))
        }
    }

    private func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// The chart for the Audio Graph: the days written out, values with their unit, and the value axis as drawn.
/// A line is one continuous series; bars and points are separate readings.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct MarkMeaningChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let mark: MarkMeaningMark
    let cupsAxis: ClosedRange<Double>
    let locale: Locale

    var title: String {
        "Cups sold each day at the \(CafeWording.harbour) café, as \(mark.spokenName)"
    }

    var isContinuous: Bool {
        mark == .line
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = MarkMeaningSummary(days: days, locale: locale)
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: days.map { summary.dayText($0.day) }
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: isContinuous,
            dataPoints: days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Bars") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/marks-what-each-communicates") {
            MarkMeaningScreen(screen: screen)
        }
    }
}

#Preview("Points on the line") {
    MarkMeaningChartPanel(viewModel: MarkMeaningViewModel(mark: .line, pointsOnLine: true), locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No days") {
    MarkMeaningChartPanel(viewModel: MarkMeaningViewModel(days: []), locale: .current)
}
