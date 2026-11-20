import Accessibility
import Charts
import SwiftUI

/// "Axes: density and weight": how much axis a chart's job needs. Many heavy grid lines against a few
/// quiet ones, and short value labels that leave the width to the plot.
struct AxisDensityScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: AxisDensityViewModel
    /// Read here and passed in, so the headline, the elements and the descriptor write numbers as the axis does.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.thirtyDays) {
        self.screen = screen
        _viewModel = State(initialValue: AxisDensityViewModel(days: days))
    }

    var body: some View {
        AxisDensityContent(screen: screen, viewModel: viewModel, locale: locale)
    }
}

/// The screen's scaffold, chart and controls, for a view model that already exists.
struct AxisDensityContent: View {
    let screen: CatalogScreen
    @Bindable var viewModel: AxisDensityViewModel
    let locale: Locale

    var body: some View {
        let totals = viewModel.totals(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: totals.caption,
            message: totals.headline,
            explanation: totals.explanation,
            snippets: viewModel.snippets
        ) {
            AxisDensityChart(
                totals: totals,
                requestedCount: viewModel.requestedCount,
                isHeavy: viewModel.isHeavy,
                valueFormat: viewModel.valueFormat(locale: locale),
                onPlotWidth: { viewModel.plotWidth = $0 }
            )
        } controls: {
            AxisDensityControls(viewModel: viewModel, locale: locale, isEnabled: totals.hasData)
        }
    }
}

/// The count stepper, the weight toggle, the label length picker and the measured plot width.
struct AxisDensityControls: View {
    @Bindable var viewModel: AxisDensityViewModel
    let locale: Locale
    let isEnabled: Bool

    var body: some View {
        ControlsSection {
            Stepper(viewModel.countText(locale: locale), value: $viewModel.requestedCount, in: AxisDensityViewModel.countRange)
            Toggle("Heavy grid lines and labels", isOn: $viewModel.isHeavy)
            LabeledSegmentedPicker(title: "Value labels", selection: $viewModel.labelLength) {
                ForEach(AxisDensityLabelLength.allCases) { length in
                    Text(length.title).tag(length)
                }
            }
            if let width = viewModel.plotWidthText(locale: locale) {
                Text(width)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!isEnabled)
    }
}

/// The running total as a line, with its end value written beside the last point, or a placeholder.
struct AxisDensityChart: View {
    let totals: AxisDensityTotals
    let requestedCount: Int
    let isHeavy: Bool
    let valueFormat: IntegerFormatStyle<Int>
    /// Called with the plot area's width whenever it changes.
    var onPlotWidth: (Double) -> Void = { _ in }
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// A label every week, or every two at the accessibility text sizes, where a week's label no longer fits.
    private var daysPerDateLabel: Int {
        dynamicTypeSize.isAccessibilitySize ? 14 : 7
    }

    var body: some View {
        if !totals.hasData {
            ContentUnavailableView(
                "No days recorded",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold so far appear here, one point a day.")
            )
        } else {
            Chart {
                ForEach(totals.weeks) { week in
                    // One element per week: a clear band the plot's full height gives every week the same top,
                    // so VoiceOver reads them in order; the line is still drawn as one line.
                    Plot {
                        RectangleMark(
                            xStart: .value(CafeWording.day, week.start),
                            xEnd: .value(CafeWording.day, week.end)
                        )
                        .foregroundStyle(.clear)
                        ForEach(week.days) { day in
                            LineMark(
                                x: .value(CafeWording.day, day.day),
                                y: .value(AxisDensityWording.cupsSoFar, day.cupsSoFar)
                            )
                        }
                    }
                    .accessibilityLabel(totals.label(for: week))
                    .accessibilityValue(totals.value(for: week))
                }
                if let last = totals.running.last {
                    // The headline's figure, written where the line ends, so it can be read without a grid line at it.
                    PointMark(
                        x: .value(CafeWording.day, last.day),
                        y: .value(AxisDensityWording.cupsSoFar, last.cupsSoFar)
                    )
                    .accessibilityHidden(true)
                    .annotation(
                        position: .topLeading,
                        overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))
                    ) {
                        Text(last.cupsSoFar.formatted(.number.locale(totals.locale)))
                            .font(.caption.bold())
                    }
                }
            }
            .chartYScale(domain: totals.valueDomain)
            .chartYAxis {
                if isHeavy {
                    // snippet:axes-density-and-weight-heavy
                    AxisMarks(values: .automatic(desiredCount: requestedCount)) { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: AxisDensityStyle.heavyLineWidth))
                            .foregroundStyle(Color.secondary)
                        AxisTick(stroke: StrokeStyle(lineWidth: AxisDensityStyle.heavyLineWidth))
                            .foregroundStyle(Color.secondary)
                        AxisValueLabel(format: valueFormat)
                            .foregroundStyle(Color.primary)
                    }
                    // end
                } else {
                    // snippet:axes-density-and-weight-quiet
                    // Fewer, paler grid lines, so the data stays prominent. The labels are not faded: they must stay readable.
                    AxisMarks(values: .automatic(desiredCount: requestedCount)) { _ in
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(AxisDensityStyle.quietLineOpacity))
                        // Labels stay at full secondary: at 60% of it they measured 1.96:1 on the panel.
                        AxisValueLabel(format: valueFormat)
                            .foregroundStyle(Color.secondary)
                    }
                    // end
                }
            }
            .chartXAxis {
                // The dates were made in UTC: the axis is told the calendar, or its lines follow the device.
                AxisMarks(values: .stride(by: .day, count: daysPerDateLabel, calendar: CafeData.calendar)) { _ in
                    if isHeavy {
                        AxisGridLine(stroke: StrokeStyle(lineWidth: AxisDensityStyle.heavyLineWidth))
                            .foregroundStyle(Color.secondary)
                        AxisTick(stroke: StrokeStyle(lineWidth: AxisDensityStyle.heavyLineWidth))
                            .foregroundStyle(Color.secondary)
                        AxisValueLabel(format: totals.axisDateFormat(accessibilitySize: dynamicTypeSize.isAccessibilitySize))
                            .foregroundStyle(Color.primary)
                    } else {
                        AxisGridLine()
                            .foregroundStyle(Color.secondary.opacity(AxisDensityStyle.quietLineOpacity))
                        AxisValueLabel(format: totals.axisDateFormat(accessibilitySize: dynamicTypeSize.isAccessibilitySize))
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
            .chartOverlay { proxy in
                // Reads the plot's width so the screen can show what short labels give back. Nothing is drawn.
                GeometryReader { geometry in
                    let width = proxy.plotFrame.map { Double(geometry[$0].width) } ?? 0
                    Color.clear
                        .onChange(of: width, initial: true) { _, newWidth in
                            if newWidth > 0 { onPlotWidth(newWidth) }
                        }
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .accessibilityChartDescriptor(AxisDensityChartDescriptor(totals: totals))
        }
    }
}

/// Constants that belong to this chart's axis marks.
private enum AxisDensityStyle {
    static let heavyLineWidth: CGFloat = 1
    static let quietLineOpacity = 0.2
}

#Preview("Quiet, short labels") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/axes-density-and-weight") {
            AxisDensityScreen(screen: screen)
        }
    }
}

#Preview("Heavy, full labels") {
    let viewModel = AxisDensityViewModel()
    viewModel.requestedCount = 10
    viewModel.isHeavy = true
    viewModel.labelLength = .full
    return NavigationStack {
        if let screen = Catalog.screen(id: "design/axes-density-and-weight") {
            AxisDensityContent(screen: screen, viewModel: viewModel, locale: .current)
        }
    }
}

#Preview("No days") {
    AxisDensityChart(
        totals: AxisDensityTotals(days: [], locale: .current),
        requestedCount: 3, isHeavy: false, valueFormat: .number
    )
}
