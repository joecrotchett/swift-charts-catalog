import Accessibility
import Charts
import SwiftUI

/// "Linked charts": two charts bound to one selection, with a band behind the selected day in each chart
/// that recorded it, and the shared x domain that puts the same day at the same place in each.
struct LinkedChartsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = LinkedChartsViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day at two cafés",
            message: summary.headline,
            reservedMessage: summary.reservedHeadline,
            explanation: """
            Both charts bind chartXSelection to the same value, so touching and holding either one selects the \
            same day in both, and a band is drawn behind that day in each chart that recorded it. Given one x \
            domain, the day falls at the same place in both. Left to choose its own, the Station café's chart \
            starts at its first record, a week later, and puts the days elsewhere.
            """,
            snippets: viewModel.snippets
        ) {
            LinkedChartsPair(viewModel: viewModel, summary: summary)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Let each chart choose its own x domain", isShowingMistake: $viewModel.isShowingOwnDomains)
                    .disabled(viewModel.isEmpty)
            }
        }
        .onChange(of: viewModel.isShowingOwnDomains) {
            AccessibilityNotification.Announcement(viewModel.changeAnnouncement(locale: locale)).post()
        }
    }
}

/// Both charts, one above the other, in the scaffold's single chart slot; a placeholder when neither café
/// sold anything.
struct LinkedChartsPair: View {
    @Bindable var viewModel: LinkedChartsViewModel
    let summary: LinkedChartsSummary

    var body: some View {
        if viewModel.isEmpty {
            ContentUnavailableView(
                "No sales recorded",
                systemImage: "cup.and.saucer",
                description: Text("Each café's daily cups appear here, one chart per café.")
            )
        } else {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                ForEach(viewModel.stores) { store in
                    LinkedChartsCafeChart(
                        store: store,
                        viewModel: viewModel,
                        summary: summary,
                        selection: $viewModel.rawSelection
                    )
                }
            }
        }
    }
}

/// One café's chart under its name, or a line saying it sold nothing.
struct LinkedChartsCafeChart: View {
    let store: StoreSales
    let viewModel: LinkedChartsViewModel
    let summary: LinkedChartsSummary
    @Binding var selection: Date?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer date labels at the largest text sizes, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 14 : 7
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(store.store)
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
                // Read before the chart's bars, so VoiceOver says whose days they are first.
                .accessibilitySortPriority(1)
            if viewModel.hasCups(store) {
                // snippet:linked-charts-shared-selection
                Chart {
                    // Declared first, so the band sits behind the bars.
                    if let day = viewModel.bandDay(for: store) {
                        LinkedChartsSelectedDayBand(day: day)
                    }
                    ForEach(store.days) { day in
                        Plot {
                            BarMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            // The café's one colour, as on every screen that draws the cafés.
                            .foregroundStyle(CafeSeriesStyle.colour(for: store.store))
                        }
                        .accessibilityLabel(summary.fullDayText(day.day))
                        .accessibilityValue(summary.elementValue(for: store, day: day))
                    }
                }
                // Every chart binds the same value: a finger in one selects the day in all of them, and
                // each draws the band where it has a bar that day.
                .chartXSelection(value: $selection)
                // end
                .chartYScale(domain: 0 ... viewModel.highestCups)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(
                            format: Date.FormatStyle(locale: summary.locale, timeZone: CafeData.calendar.timeZone)
                                .month(.abbreviated).day()
                        )
                    }
                }
                .linkedChartsXDomain(viewModel.xDomain)
                .accessibilityChartDescriptor(LinkedChartsDescriptor(store: store, summary: summary))
                // The descriptor's words change with the domain while the bars' ids do not.
                .id(viewModel.isShowingOwnDomains)
            } else {
                Text("No cups recorded at \(store.store).")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        // A container, so the title's sort priority puts it ahead of this chart's bars and no further.
        .accessibilityElement(children: .contain)
    }
}

// snippet:linked-charts-band
/// A band behind the selected day's bar, written once and drawn in each linked chart that recorded the day.
struct LinkedChartsSelectedDayBand: ChartContent {
    let day: Date

    var body: some ChartContent {
        RectangleMark(
            x: .value(LinkedChartsWording.selectedDay, day, unit: .day, calendar: CafeData.calendar),
            width: .ratio(1)
        )
        .foregroundStyle(Color.gray.opacity(LinkedChartsStyle.bandOpacity))
        // It only marks the selection; the bars already describe the day.
        .accessibilityHidden(true)
    }
}

// end

extension View {
    /// The shared x domain, or, in the mistake, none: each chart then infers its domain from its own days.
    @ViewBuilder
    func linkedChartsXDomain(_ domain: ClosedRange<Date>?) -> some View {
        if let domain {
            // snippet:linked-charts-shared-domain
            // The same domain on every linked chart, from the first day either has to the end of the last,
            // so one day falls at the same place in each.
            chartXScale(domain: domain)
            // end
        } else {
            // snippet:linked-charts-own-domain
            // No chartXScale: each chart infers its x domain from its own days. The Station chart
            // starts a week later, so its days fall at other places than the Harbour chart's.
            self
            // end
        }
    }
}

private nonisolated enum LinkedChartsWording {
    /// The band's value label. Not in `CafeWording`; the band is hidden from assistive technologies.
    static let selectedDay = "Selected day"
}

private enum LinkedChartsStyle {
    static let bandOpacity = 0.25
}

/// One café's chart for the Audio Graph: dates written out, cups with their unit, and which days it is drawn on.
nonisolated struct LinkedChartsDescriptor: AXChartDescriptorRepresentable {
    let store: StoreSales
    let summary: LinkedChartsSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.day,
            categoryOrder: store.days.map { summary.dayText($0.day) }
        )
        // The y domain both charts are drawn on.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: 0 ... Double(summary.highestCups),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: store.store,
            isContinuous: false,
            dataPoints: store.days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the \(store.store) café",
            summary: summary.audioGraphSummary(for: store),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Linked charts") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/linked-charts") {
            LinkedChartsScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    let viewModel = LinkedChartsViewModel(
        top: StoreSales(store: CafeWording.harbour, days: []),
        bottom: StoreSales(store: CafeWording.station, days: [])
    )
    LinkedChartsPair(viewModel: viewModel, summary: viewModel.summary(locale: .current))
}
