import Accessibility
import Charts
import SwiftUI

/// "Area": `AreaMark` as the area under a line, and as a range area between two values.
struct AreaMarkScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = AreaMarkViewModel()
    /// The one locale the screen's words are written in: the headline here, and the chart reads the same value.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.summary(locale: locale).headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            AreaMarkChart(months: viewModel.months, form: viewModel.form)
        } controls: {
            ControlsSection {
                AreaMarkFormPicker(form: $viewModel.form)
            }
        }
        .onChange(of: viewModel.form) {
            // The chart redraws as a different form; say so for people who cannot see it happen.
            AccessibilityNotification.Announcement(viewModel.changeAnnouncement(locale: locale)).post()
        }
    }
}

/// The picker that switches between the two forms of `AreaMark`.
struct AreaMarkFormPicker: View {
    @Binding var form: AreaMarkForm

    var body: some View {
        LabeledSegmentedPicker(title: "Area form", selection: $form) {
            ForEach(AreaMarkForm.allCases) { form in
                Text(form.title).tag(form)
            }
        }
    }
}

/// The area chart in the form the summary is for, or a placeholder when there is nothing to draw.
struct AreaMarkChart: View {
    let months: [MonthlySummary]
    let form: AreaMarkForm
    /// The locale the month axis below is formatted with, so the labels, the elements and the Audio Graph agree.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = AreaMarkSummary(months: months, form: form, locale: locale)
        // Nothing sold is no data: zeros would draw axes with no area under a headline that is not true.
        if summary.hasData {
            Group {
                switch summary.form {
                case .basic: AverageDayAreaChart(summary: summary)
                case .range: DayRangeAreaChart(summary: summary)
                }
            }
            .modifier(MonthAxis())
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: summary.valueDomain)
            .accessibilityChartDescriptor(AreaMarkChartDescriptor(summary: summary))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each month's daily cups appear here as a filled area.")
            )
        }
    }
}

/// The area under a line: one `AreaMark` per month, filled from zero up to the month's average day.
struct AverageDayAreaChart: View {
    let summary: AreaMarkSummary

    var body: some View {
        // snippet:area-basic
        Chart(summary.months) { month in
            // The label and value go on a Plot around the mark; the marks still join into one region.
            Plot {
                AreaMark(
                    // The month is a period, cut in the calendar the data was recorded in.
                    x: .value("Month", month.month, unit: .month, calendar: CafeData.calendar),
                    // A single y value: the area fills from the baseline, zero, up to it.
                    y: .value("Average day", month.averageDay)
                )
            }
            .accessibilityLabel(summary.elementLabel(for: month))
            .accessibilityValue(summary.elementValue(for: month))
        }
        // end
    }
}

/// A range area: one `AreaMark` per month, filled between the month's quietest and busiest day.
struct DayRangeAreaChart: View {
    let summary: AreaMarkSummary

    var body: some View {
        // snippet:area-range
        Chart(summary.months) { month in
            Plot {
                AreaMark(
                    x: .value("Month", month.month, unit: .month, calendar: CafeData.calendar),
                    // Two y values: the area fills only between them, and does not reach the baseline.
                    yStart: .value("Quietest day", month.lowestDay),
                    yEnd: .value("Busiest day", month.highestDay)
                )
            }
            .accessibilityLabel(summary.elementLabel(for: month))
            .accessibilityValue(summary.elementValue(for: month))
        }
        // end
    }
}

/// One label per month, centred under its month, in the calendar and time zone of the data.
private struct MonthAxis: ViewModifier {
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.chartXAxis {
            AxisMarks(values: .stride(by: .month, count: 1, calendar: CafeData.calendar)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: monthFormat, centered: true)
            }
        }
    }

    /// "Mar" at the standard text sizes; the initial alone at the accessibility sizes, where
    /// six abbreviated names no longer fit side by side.
    private var monthFormat: Date.FormatStyle {
        Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone)
            .month(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated)
    }
}

/// The chart for the Audio Graph: a title, a summary, months written out, values said in cups,
/// and one named series per edge the form draws.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct AreaMarkChartDescriptor: AXChartDescriptorRepresentable {
    let summary: AreaMarkSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let months = summary.months
        let summary = summary
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.month,
            categoryOrder: months.map { summary.monthAndYear($0.month) }
        )
        // The drawn value axis includes zero in both forms.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: summary.locale) { count, _ in summary.cupsText(count) } }
        return AXChartDescriptor(
            title: title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }

    private var title: String {
        switch summary.form {
        case .basic: "Cups on an average day at the Harbour café, by month"
        case .range: "Cups on the quietest and busiest day at the Harbour café, by month"
        }
    }

    private var series: [AXDataSeriesDescriptor] {
        switch summary.form {
        case .basic: [series(named: "Average day", value: \.averageDay)]
        case .range: [series(named: "Quietest day", value: \.lowestDay), series(named: "Busiest day", value: \.highestDay)]
        }
    }

    private func series(named name: String, value: KeyPath<MonthlySummary, Int>) -> AXDataSeriesDescriptor {
        AXDataSeriesDescriptor(
            name: name,
            // Months are an ordered, continuous measure: time.
            isContinuous: true,
            dataPoints: summary.months.map { month in
                AXDataPoint(x: summary.monthAndYear(month.month), y: Double(month[keyPath: value]))
            }
        )
    }
}

#Preview("Area") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/area") {
            AreaMarkScreen(screen: screen)
        }
    }
}

#Preview("Range") {
    AreaMarkChart(months: CafeData.monthlySummaries, form: .range)
        .padding()
}

#Preview("No sales") {
    AreaMarkChart(months: [], form: .basic)
}
