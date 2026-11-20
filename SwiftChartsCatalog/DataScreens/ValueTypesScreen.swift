import Accessibility
import Charts
import SwiftUI

/// "Value types shape the chart": the same week plotted with the day as a String, a number and a Date.
struct ValueTypesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ValueTypesViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DailySales] = Array(CafeData.harbourSales.prefix(7))) {
        self.screen = screen
        _viewModel = State(initialValue: ValueTypesViewModel(sales: sales))
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day at the Harbour café",
            message: summary.headline,
            explanation: """
            The days and cups are the same each time; only the type of the x value changes. \
            A String makes one band per distinct value, in data order. A number makes a continuous number \
            scale, which starts at zero by default, and a Date makes a date scale, here cut into days in \
            the data's own calendar.
            """,
            snippets: viewModel.snippets
        ) {
            ValueTypesChart(days: summary.days, xType: viewModel.xType, locale: locale)
        } controls: {
            ValueTypesControls(xType: $viewModel.xType)
        }
        .onChange(of: viewModel.xType) {
            // The scale changed under the same marks: say so, then the headline.
            AccessibilityNotification.Announcement(viewModel.summary(locale: locale).announcement).post()
        }
    }
}

/// The picker for the type of the x value.
struct ValueTypesControls: View {
    @Binding var xType: ValueTypesXType

    var body: some View {
        ControlsSection {
            // Not animated: a band, a number and a date are different scales, not new values on one.
            LabeledSegmentedPicker(title: "Type of the day on x", selection: $xType) {
                ForEach(ValueTypesXType.allCases) { type in
                    Text(type.title).tag(type)
                }
            }
        }
    }
}

/// One point per day, at a position given by the chosen type of value, or a placeholder with no days.
struct ValueTypesChart: View {
    let days: [ValueTypesDay]
    let xType: ValueTypesXType
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room after the last day for a label that would otherwise run past the plot, growing with the text.
    @ScaledMetric(relativeTo: .caption) private var endLabelRoom = ValueTypesChartMetrics.endLabelRoom

    /// Fewer date labels as the text grows, so they do not collide.
    private var daysPerLabel: Int {
        ValueTypesSummary.daysPerDateLabel(at: dynamicTypeSize)
    }

    /// Date labels in the view's locale and the data's time zone: "Mar 7", or "7" at the largest sizes.
    private var dateLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
        return ValueTypesSummary.dateLabelsNameMonth(at: dynamicTypeSize) ? style.month(.abbreviated).day() : style.day()
    }

    /// The room kept after the last day: for the number axis's last label, centred on its line at the
    /// plot's edge, and for a "Mar 7" that no longer fits inside its own day.
    private var trailingRoom: CGFloat {
        switch xType {
        case .string: 0
        case .number: endLabelRoom
        case .date: daysPerLabel > 1 && ValueTypesSummary.dateLabelsNameMonth(at: dynamicTypeSize) ? endLabelRoom : 0
        }
    }

    var body: some View {
        if days.isEmpty {
            ContentUnavailableView(
                "No days to show",
                systemImage: "calendar",
                description: Text("Each day's cups appear here, one point per day.")
            )
        } else {
            let summary = ValueTypesSummary(days: days, xType: xType, locale: locale)
            Chart(days) { day in
                Plot {
                    // A clear band the full height of the plot at the day: every element then has the same top,
                    // so VoiceOver and Switch Control visit the days in order along x, not by their cups.
                    ValueTypesBand(day: day, xType: xType)
                    switch xType {
                    case .string:
                        // snippet:value-types-string
                        // A String: one band per distinct name, in the order the data gives them.
                        PointMark(
                            x: .value(CafeWording.day, day.name),
                            y: .value(CafeWording.cups, day.cups)
                        )
                    // end
                    case .number:
                        // snippet:value-types-number
                        // An Int: a continuous number scale, which includes zero by default.
                        PointMark(
                            x: .value(CafeWording.day, day.number),
                            y: .value(CafeWording.cups, day.cups)
                        )
                    // end
                    case .date:
                        // snippet:value-types-date
                        // A Date: a date scale. The unit makes the point stand for the whole day, cut in
                        // the calendar the data was made in (UTC), not the device's.
                        PointMark(
                            x: .value(CafeWording.day, day.date, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                        // end
                    }
                }
                .accessibilityLabel(summary.spokenDay(day))
                .accessibilityValue(summary.spokenCups(day))
            }
            .chartXAxis {
                switch xType {
                case .string:
                    AxisMarks()
                case .number:
                    // A mark at each day's number, so the day the headline names is labelled: the
                    // default marks would choose round numbers (0, 2, 4, 6) and could leave it out.
                    // Centred on its line (.aligned), so the last day's label has room at the plot's edge.
                    AxisMarks(preset: .aligned, values: summary.numberAxisValues)
                case .date:
                    // snippet:value-types-date-axis
                    // The axis is told the data's calendar too, or it marks and labels days in the device's.
                    AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(
                            format: dateLabelFormat,
                            // Centred under its day only when every day is labelled: with a longer
                            // stride it would sit between two days.
                            centered: daysPerLabel == 1
                        )
                    }
                    // end
                }
            }
            .valueTypesXScale(xType, numberDomain: summary.numberDomain, trailingRoom: trailingRoom)
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.cupsDomain)
            .accessibilityChartDescriptor(ValueTypesChartDescriptor(days: days, xType: xType, locale: locale))
        }
    }
}

/// A clear band the full height of the plot at one day, on whichever kind of x the day is given as.
struct ValueTypesBand: ChartContent {
    let day: ValueTypesDay
    let xType: ValueTypesXType

    var body: some ChartContent {
        switch xType {
        case .string:
            RectangleMark(x: .value(CafeWording.day, day.name), width: .fixed(1))
                .foregroundStyle(.clear)
        case .number:
            RectangleMark(x: .value(CafeWording.day, day.number), width: .fixed(1))
                .foregroundStyle(.clear)
        case .date:
            RectangleMark(x: .value(CafeWording.day, day.date, unit: .day, calendar: CafeData.calendar), width: .fixed(1))
                .foregroundStyle(.clear)
        }
    }
}

extension View {
    /// The x scale: room after the last day for its label, and for the number type the domain the descriptor
    /// is given too.
    @ViewBuilder
    func valueTypesXScale(_ xType: ValueTypesXType, numberDomain: ClosedRange<Double>, trailingRoom: CGFloat) -> some View {
        if xType == .number {
            chartXScale(domain: numberDomain, range: .plotDimension(endPadding: trailingRoom))
        } else {
            chartXScale(range: .plotDimension(endPadding: trailingRoom))
        }
    }
}

/// Constants that belong to this chart's axis.
private enum ValueTypesChartMetrics {
    /// Points kept free after the last day at the default text size: about half the width of a label.
    static let endLabelRoom: CGFloat = 18
}

#Preview("Value types") {
    NavigationStack {
        if let screen = Catalog.screen(id: "data/value-types-shape-the-chart") {
            ValueTypesScreen(screen: screen)
        } else {
            ValueTypesScreen(screen: CatalogScreen(
                id: "data/value-types-shape-the-chart", title: "Value types shape the chart", summary: "",
                apiSince: "16.0", skillReferences: ["data.md"], snippets: ValueTypesXType.string.snippets
            ))
        }
    }
}

#Preview("Each type") {
    let days = ValueTypesDay.days(from: Array(CafeData.harbourSales.prefix(7)), locale: Locale(identifier: "en_US"))
    ScrollView {
        ForEach(ValueTypesXType.allCases) { type in
            ChartPanel {
                ValueTypesChart(days: days, xType: type, locale: Locale(identifier: "en_US"))
            }
        }
    }
}

#Preview("No days") {
    ValueTypesChart(days: [], xType: .string, locale: .current)
}
