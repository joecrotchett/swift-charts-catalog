import Accessibility
import Charts
import SwiftUI

/// "Axes: fixed or dynamic range": a percentage on a fixed 0 to 100 axis and a count whose axis follows
/// the largest value, across a quiet and a busy day. The mistake swaps the two choices.
struct AxisRangeScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = AxisRangeViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Seats and cups, \(viewModel.period.dayName)",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation(locale: locale),
            snippets: viewModel.snippets
        ) {
            AxisRangeCharts(viewModel: viewModel, locale: locale)
        } controls: {
            AxisRangeControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.period) { announce(.period) }
        .onChange(of: viewModel.isSwapped) { announce(.swap) }
    }

    private func announce(_ change: AxisRangeChange) {
        announceAxisRangeChange(viewModel.announcement(after: change, locale: locale))
    }
}

/// Says aloud that the charts changed, for people who cannot see it happen.
@MainActor
func announceAxisRangeChange(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// The period switch and the mistake.
struct AxisRangeControls: View {
    @Bindable var viewModel: AxisRangeViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Day", selection: $viewModel.period) {
                ForEach(AxisRangePeriod.allCases) { period in
                    Text(period.dayName).tag(period)
                }
            }
            MistakeToggle(title: "Swap fixed and dynamic", isShowingMistake: $viewModel.isSwapped.animation())
                // With neither chart drawn, the swap would change and announce nothing that is shown.
                .disabled(!viewModel.hasSeats && !viewModel.hasCups)
        }
    }
}

/// The two charts side by side, or one above the other at the accessibility text sizes.
struct AxisRangeCharts: View {
    let viewModel: AxisRangeViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.sectionSpacing))
            : AnyLayout(HStackLayout(alignment: .top, spacing: Layout.sectionSpacing))
        layout {
            AxisRangeChartColumn(heading: AxisRangeWording.seatsHeading) {
                AxisRangeSeatsChart(viewModel: viewModel, locale: locale)
            }
            AxisRangeChartColumn(heading: viewModel.cupsHeading) {
                AxisRangeCupsChart(viewModel: viewModel, locale: locale)
            }
        }
    }
}

/// A chart under a short heading that names its measure and unit.
struct AxisRangeChartColumn<Content: View>: View {
    let heading: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(heading)
                .font(.subheadline.weight(.semibold))
                // Two lines kept for both headings, so the two plots start at the same height.
                .lineLimit(2, reservesSpace: true)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

/// The percentage of seats filled each hour, on the axis the view model chooses.
struct AxisRangeSeatsChart: View {
    let viewModel: AxisRangeViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room above the top label, which is centred on the top of the domain, growing with the text.
    @ScaledMetric(relativeTo: .caption2) private var topLabelRoom = AxisRangeStyle.topLabelRoom

    var body: some View {
        if viewModel.hasSeats {
            let axis = viewModel.seatsAxis
            // snippet:axes-fixed-or-dynamic-range-seats-chart
            Chart(viewModel.readings) { reading in
                Plot {
                    LineMark(
                        x: .value(AxisRangeWording.hour, reading.start),
                        y: .value(AxisRangeWording.seatsFilled, reading.percent)
                    )
                }
                .accessibilityLabel(AxisRangeViewModel.time(reading.start, locale: locale))
                .accessibilityValue(AxisRangeViewModel.percent(Double(reading.percent), locale: locale))
            }
            // The range comes from the meaning of the measure: 0 to 100 for a percentage.
            .chartYScale(domain: axis.domain, range: .plotDimension(endPadding: min(topLabelRoom, AxisRangeStyle.topLabelRoomCap)))
            .chartYAxis {
                AxisMarks(values: axis.labels(thinned: dynamicTypeSize.isAccessibilitySize)) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let percent = value.as(Double.self) {
                            Text(AxisRangeViewModel.percent(percent, locale: locale))
                        }
                    }
                }
            }
            // end
            .chartXAxis {
                AxisMarks(values: AxisRangeStyle.labelledHours(accessibilitySize: dynamicTypeSize.isAccessibilitySize)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: TimeOfDayWording.hourFormat(locale: locale))
                }
            }
            .accessibilityChartDescriptor(viewModel.seatsDescriptor(locale: locale))
            // The hours are the same on both days, so the marks keep their ids, and the Audio Graph keeps the
            // descriptor the chart was first given. A new identity for every state that changes the descriptor
            // (the day and the swap) makes VoiceOver and the Audio Graph read what is drawn.
            .id(viewModel.chartIdentity)
        } else {
            ContentUnavailableView(
                "No readings",
                systemImage: "chair",
                description: Text("Seats filled each hour appear here.")
            )
        }
    }
}

/// Cups on each day of the period, on the axis the view model chooses.
struct AxisRangeCupsChart: View {
    let viewModel: AxisRangeViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var topLabelRoom = AxisRangeStyle.topLabelRoom

    var body: some View {
        if viewModel.hasCups {
            let axis = viewModel.cupsAxis
            // snippet:axes-fixed-or-dynamic-range-cups-chart
            Chart(viewModel.cupsDays) { day in
                Plot {
                    BarMark(
                        x: .value(CafeWording.day, AxisRangeViewModel.shortDay(day.day, locale: locale)),
                        y: .value(CafeWording.cups, day.cups)
                    )
                }
                .accessibilityLabel("\(viewModel.period.dayName), \(AxisRangeViewModel.longDay(day.day, locale: locale))")
                .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
            }
            .foregroundStyle(AxisRangeStyle.cupsColour)
            // A count has no top of its own: the domain follows the largest value in the period.
            .chartYScale(domain: axis.domain, range: .plotDimension(endPadding: min(topLabelRoom, AxisRangeStyle.topLabelRoomCap)))
            .chartYAxis {
                AxisMarks(values: axis.labels(thinned: dynamicTypeSize.isAccessibilitySize))
            }
            // end
            .accessibilityChartDescriptor(viewModel.cupsDescriptor(locale: locale))
            // The swap changes the descriptor's range but no element: without a new identity the Audio Graph
            // keeps the range it was first given.
            .id(viewModel.chartIdentity)
        } else {
            ContentUnavailableView(
                "No cups",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold on each \(viewModel.period.dayName) appear here.")
            )
        }
    }
}

/// Constants that belong to this screen's charts.
enum AxisRangeStyle {
    /// Room above the top value label at the default text size, so it is not cut in half.
    static let topLabelRoom: CGFloat = 8
    /// The most room the top label is given, so the plot is not squeezed at the largest sizes.
    static let topLabelRoomCap: CGFloat = 20
    /// The count is a different kind of data from the percentage, so it has its own colour: teal, which is neither
    /// café's colour (blue and orange in `CafeSeriesStyle`), so the bars are not taken for the Station café's.
    static let cupsColour = Color.teal

    /// The hours the seats chart labels: every four from 7 am, or every six at the accessibility sizes.
    static func labelledHours(accessibilitySize: Bool) -> [Date] {
        stride(from: 7, through: 15, by: accessibilitySize ? 6 : 4).map { CafeData.time($0) }
    }
}

#Preview("Fixed and dynamic") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/axes-fixed-or-dynamic-range") {
            AxisRangeScreen(screen: screen)
        }
    }
}

#Preview("No data") {
    AxisRangeCharts(viewModel: AxisRangeViewModel(seatsFilled: [], sales: []), locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
