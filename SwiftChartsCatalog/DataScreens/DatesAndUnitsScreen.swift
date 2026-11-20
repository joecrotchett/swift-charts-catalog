import Accessibility
import Charts
import SwiftUI

/// "Dates and units": `unit:` on a date value makes a bar fill its day or month.
struct DatesAndUnitsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: DatesAndUnitsViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, viewModel: DatesAndUnitsViewModel = DatesAndUnitsViewModel()) {
        self.screen = screen
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            DatesAndUnitsChart(viewModel: viewModel)
        } controls: {
            DatesAndUnitsControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.period) {
            AccessibilityNotification.Announcement(viewModel.periodChangeAnnouncement(locale: locale)).post()
        }
        .onChange(of: viewModel.isLeavingOutUnit) {
            AccessibilityNotification.Announcement(viewModel.unitChangeAnnouncement(locale: locale)).post()
        }
    }
}

/// The period picker and the mistake toggle.
struct DatesAndUnitsControls: View {
    @Bindable var viewModel: DatesAndUnitsViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Each bar is one", selection: $viewModel.period) {
                ForEach(DatesAndUnitsPeriod.allCases) { period in
                    Text(period.title).tag(period)
                }
            }
            MistakeToggle(title: "Leave out the unit", isShowingMistake: $viewModel.isLeavingOutUnit)
        }
    }
}

/// One bar per day or per month, filling its period, or narrow bars at an instant when the unit is left off.
struct DatesAndUnitsChart: View {
    let viewModel: DatesAndUnitsViewModel
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Periods per axis label: fewer labels as the text grows, so they do not collide.
    private var labelStride: Int {
        switch viewModel.period {
        case .days: dynamicTypeSize >= .accessibility3 ? 14 : 7
        // Abbreviated month names do not fit side by side from accessibility 3 (rendered at 3 and 5):
        // label every other month rather than shorten them to initials.
        case .months: dynamicTypeSize >= .accessibility3 ? 2 : 1
        }
    }

    /// Axis labels in the view's locale and the data's time zone.
    private var labelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        switch viewModel.period {
        case .days: return style.month(.abbreviated).day()
        case .months: return style.month(.abbreviated)
        }
    }

    var body: some View {
        if viewModel.hasData {
            Chart(viewModel.bars) { bar in
                Plot {
                    DatesAndUnitsMark(
                        bar: bar, period: viewModel.period, isLeavingOutUnit: viewModel.isLeavingOutUnit,
                        xTitle: viewModel.xTitle, yTitle: viewModel.yTitle
                    )
                }
                .accessibilityLabel(viewModel.barLabel(bar, locale: locale))
                .accessibilityValue(viewModel.barValue(bar, locale: locale))
                // The bar the headline names, labelled: the axis may not label its day or month. Not read
                // aloud; the bar's element says the same.
                .headlineCallout(viewModel.highestBars.contains(bar) ? viewModel.calloutText(for: bar, locale: locale) : nil)
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: viewModel.valueDomain)
            .chartXAxis {
                // snippet:dates-and-units-axis
                // The axis needs the data's calendar too, or its marks and labels follow the device.
                AxisMarks(values: .stride(by: viewModel.period.unit, count: labelStride, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    // Centred under the bar only when the bars fill their period and every one is labelled.
                    AxisValueLabel(format: labelFormat, centered: viewModel.axisLabelsCentered(stride: labelStride))
                }
                // end
            }
            .accessibilityChartDescriptor(viewModel.chartDescriptor(locale: locale))
            // Bars for days and bars for months are different things: do not animate one into the other.
            .transaction { $0.animation = nil }
            // The chart keeps the accessibility elements it made for a data element's id until that id
            // changes: switching the unit keeps every id, so without a new identity the bars would go on
            // reading their days after they are drawn at instants.
            .id(viewModel.isLeavingOutUnit)
        } else {
            ContentUnavailableView(
                "No sales in this period",
                systemImage: "calendar",
                description: Text("Cups sold appear here, one bar per day or per month.")
            )
        }
    }
}

/// The bar for one period, written the way the controls ask for.
struct DatesAndUnitsMark: ChartContent {
    let bar: DatesAndUnitsBar
    let period: DatesAndUnitsPeriod
    let isLeavingOutUnit: Bool
    let xTitle: String
    let yTitle: String

    var body: some ChartContent {
        if isLeavingOutUnit {
            // snippet:dates-and-units-no-unit
            // No unit: the date is an instant, so the bar is narrow and centred on midnight.
            BarMark(
                x: .value(xTitle, bar.date),
                y: .value(yTitle, bar.cups)
            )
            // end
        } else if period == .days {
            // snippet:dates-and-units-days
            // unit: .day plots the date as the whole day, cut in the calendar the data was made in.
            BarMark(
                x: .value(CafeWording.day, bar.date, unit: .day, calendar: CafeData.calendar),
                y: .value(CafeWording.cups, bar.cups)
            )
            // end
        } else {
            // snippet:dates-and-units-months
            // unit: .month: one bar as wide as its month.
            BarMark(
                x: .value(CafeWording.month, bar.date, unit: .month, calendar: CafeData.calendar),
                y: .value(DatesAndUnitsViewModel.averageDayTitle, bar.cups)
            )
            // end
        }
    }
}

#Preview("Days") {
    NavigationStack {
        if let screen = Catalog.screen(id: "data/dates-and-units") {
            DatesAndUnitsScreen(screen: screen)
        }
    }
}

#Preview("Months, no unit") {
    let viewModel = DatesAndUnitsViewModel()
    viewModel.period = .months
    viewModel.isLeavingOutUnit = true
    return DatesAndUnitsChart(viewModel: viewModel)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No data") {
    DatesAndUnitsChart(viewModel: DatesAndUnitsViewModel(days: [], months: []))
}
