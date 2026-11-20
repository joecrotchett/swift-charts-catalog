import Accessibility
import Charts
import SwiftUI

/// "Design with real data": points, a line and bars on smooth invented days, then on the days as really
/// traded (closed Mondays at zero, a day with no record, a festival far above the rest), and on only zeros.
struct RealDataScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: RealDataViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and dates alike.
    @Environment(\.locale) private var locale

    init(
        screen: CatalogScreen,
        inventedDays: [DailySales] = CafeData.thirtyDays,
        realDays: [DailySales] = CafeData.thirtyDaysReal
    ) {
        self.screen = screen
        _viewModel = State(initialValue: RealDataViewModel(inventedDays: inventedDays, realDays: realDays))
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption(locale: locale),
            message: summary.headline,
            explanation: """
            Smooth invented days flatter every mark. Real days bring zeros, a day with no record and an outlier: \
            a line draws two long strokes for every day of 0 and runs straight across the missing day, while bars \
            keep each day separate and leave a zero as an empty slot. Try only zeros as well: points and a line \
            still draw at zero, but bars of 0 have no height, so they get a placeholder.
            """,
            snippets: viewModel.snippets
        ) {
            RealDataChart(days: viewModel.days, mark: viewModel.mark, locale: locale)
                .id(viewModel.chartIdentity)
        } controls: {
            RealDataControls(viewModel: viewModel, lookFor: summary.lookFor)
        }
        // Each control changes what is drawn: say what changed, then the new headline.
        .onChange(of: viewModel.isRealData) {
            AccessibilityNotification.Announcement(viewModel.dataAnnouncement(locale: locale)).post()
        }
        .onChange(of: viewModel.isOnlyZeros) {
            AccessibilityNotification.Announcement(viewModel.zerosAnnouncement(locale: locale)).post()
        }
        .onChange(of: viewModel.mark) {
            AccessibilityNotification.Announcement(viewModel.markAnnouncement(locale: locale)).post()
        }
    }
}

/// The data toggle, the mark, the zeros toggle, and what to look for in the chart as drawn.
struct RealDataControls: View {
    @Bindable var viewModel: RealDataViewModel
    let lookFor: String

    var body: some View {
        ControlsSection {
            Toggle("Real data", isOn: $viewModel.isRealData)
                .disabled(viewModel.isDataToggleDisabled)
            LabeledSegmentedPicker(title: "Mark", selection: $viewModel.mark) {
                ForEach(RealDataMark.allCases) { mark in
                    Text(mark.title).tag(mark)
                }
            }
            Toggle("Only zeros", isOn: $viewModel.isOnlyZeros)
            if viewModel.isShowingMistake {
                Label("The line on real data is the mistake, shown on purpose.", systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.orange)
            }
            Text(lookFor)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The days as the chosen mark, or a placeholder when the mark would draw nothing.
struct RealDataChart: View {
    let days: [DailySales]
    let mark: RealDataMark
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room at each end of the x axis, so the label centred on the last grid line ("Mar 29") is drawn whole
    /// instead of being left out (`axes.md`, on the label at the trailing edge).
    @ScaledMetric(relativeTo: .caption2) private var edgeLabelRoom = RealDataStyle.edgeLabelRoom

    private var summary: RealDataSummary {
        RealDataSummary(days: days, mark: mark, locale: locale)
    }

    private var dayStyle: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
    }

    /// A label every week, or every fortnight at the largest text sizes so the labels do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 14 : 7
    }

    var body: some View {
        // Bars of 0 have no height, so a chart of zeros would be bare axes: show why instead.
        if summary.showsPlaceholder {
            ContentUnavailableView(
                summary.placeholderTitle,
                systemImage: "cup.and.saucer",
                description: Text(summary.placeholderDescription)
            )
        } else {
            Chart {
                ForEach(days) { day in
                    Plot {
                        switch mark {
                        case .points:
                            // A clear band the full height of the plot gives every day's element the same top
                            // edge, so VoiceOver reads the days in date order rather than by the height of their points.
                            RectangleMark(x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar))
                                .foregroundStyle(.clear)
                            // snippet:design-with-real-data-points
                            // A day of 0 is a dot on the zero line; a day with no record has no dot.
                            PointMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                        // end
                        case .line:
                            // snippet:design-with-real-data-line
                            // One series: every day joins the next recorded one, across a missing day too,
                            // and each day of 0 is a drop to the baseline and a climb back.
                            LineMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                        // end
                        case .bars:
                            // snippet:design-with-real-data-bars
                            // Each day is its own bar; a day of 0 is an empty slot, as is a day with no record.
                            BarMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            // end
                        }
                    }
                    // Context first, the date written out in the data's time zone; then the value with its unit.
                    .accessibilityLabel(summary.dayName(day.day))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }
            }
            // One domain for the drawn scale and the descriptor, at least 50 so zeros still have an axis.
            .chartYScale(domain: summary.cupsAxis)
            .chartXScale(range: .plotDimension(padding: min(edgeLabelRoom, RealDataStyle.edgeLabelRoomLimit)))
            .chartXAxis {
                // Each label centred on its grid line, so the last one has room and is drawn.
                AxisMarks(preset: .aligned, values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    // The day alone at the largest sizes, where centred "Mar 15" labels ran into each other;
                    // the caption names the month.
                    AxisValueLabel(format: dynamicTypeSize >= .accessibility3 ? dayStyle.day() : dayStyle.month(.abbreviated).day())
                }
            }
            .accessibilityChartDescriptor(RealDataChartDescriptor(days: days, mark: mark, locale: locale))
        }
    }
}

/// Constants that belong to this chart alone.
private enum RealDataStyle {
    static let edgeLabelRoom: CGFloat = 12
    /// The most room it grows to: at the accessibility sizes the labels are day numbers, and room scaled with
    /// the text narrowed the plot until the labels ran into each other.
    static let edgeLabelRoomLimit: CGFloat = 16
}

/// The chart for the Audio Graph: written-out days, cups with their unit, and the awkward days in the summary.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct RealDataChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let mark: RealDataMark
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = RealDataSummary(days: days, mark: mark, locale: locale)
        let locale = locale
        let names = days.map { summary.dayName($0.day) }
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: names)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsAxis,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            // Only the line is one connected shape; points and bars are separate days.
            isContinuous: mark == .line,
            dataPoints: zip(names, days).map { name, day in AXDataPoint(x: name, y: Double(day.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the Harbour café, March 2026",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Real data") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/design-with-real-data") {
            RealDataScreen(screen: screen)
        }
    }
}

#Preview("Only zeros as points") {
    RealDataChart(days: CafeData.thirtyDaysReal.map { DailySales(day: $0.day, cups: 0) }, mark: .points, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
