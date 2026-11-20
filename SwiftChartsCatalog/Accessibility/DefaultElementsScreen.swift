import Charts
import SwiftUI

/// "What you get for free" under Accessibility: six charts with no accessibility code, and what VoiceOver
/// and the Audio Graph get from each, as read on iOS 27 in the simulator.
struct DefaultElementsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = DefaultElementsViewModel()
    /// Read here and passed in, so the headline and the spoken text write numbers as the chart does.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.chartCase.caption,
            message: viewModel.headline(locale: locale),
            explanation: """
            None of these charts has any accessibility code. Swift Charts makes one VoiceOver element per position \
            along x and summarises the marks that share it; on a number or date axis it merges neighbours into \
            stretches. The Audio Graph gets the .value labels as axis titles, under the title "Chart".
            """,
            snippets: viewModel.snippets
        ) {
            DefaultElementsChart(viewModel: viewModel)
        } controls: {
            ControlsSection {
                LabeledMenuPicker(title: "Chart", selection: $viewModel.chartCase) {
                    ForEach(DefaultElementsCase.allCases) { chartCase in
                        Text(chartCase.title).tag(chartCase)
                    }
                }
            }
            // A placeholder has nothing to read, so the spoken panels go with the chart.
            if viewModel.hasMarks, let spoken = viewModel.spokenText(locale: locale) {
                DefaultElementsReadElements(elements: spoken.elements)
                DefaultElementsReadAudioGraph(audioGraph: spoken.audioGraph)
                DefaultElementsWhatIsMissing(text: spoken.realChartAdds)
            }
            DefaultElementsHowToHear()
        }
        .onChange(of: viewModel.chartCase) {
            // The picker changes the data and the kind of mark, so the change is said, not only drawn.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The chart for the chosen case, or a placeholder when it has nothing to draw.
struct DefaultElementsChart: View {
    let viewModel: DefaultElementsViewModel

    var body: some View {
        if viewModel.hasMarks {
            switch viewModel.chartCase {
            case .oneMark: DefaultElementsOneMarkChart(sales: viewModel.data.drinkSales)
            case .stacked: DefaultElementsStackedChart(orders: viewModel.data.drinkOrders)
            case .grouped: DefaultElementsGroupedChart(orders: viewModel.data.drinkOrders)
            case .severalSeries: DefaultElementsSeveralSeriesChart(stores: viewModel.data.week)
            case .denseLine: DefaultElementsDenseLineChart(readings: viewModel.data.readings)
            case .monthOfDays: DefaultElementsMonthChart(days: viewModel.data.month)
            }
        } else {
            ContentUnavailableView(
                "Nothing to draw",
                systemImage: "chart.bar",
                description: Text("This chart appears here when it has data.")
            )
        }
    }
}

// MARK: The six charts, with no accessibility code

struct DefaultElementsOneMarkChart: View {
    let sales: [DrinkSales]

    var body: some View {
        // snippet:default-elements-one-mark
        // One bar per drink, and no accessibility code: each bar is one element, its label the drink
        // and its value the bare number.
        Chart(sales) { item in
            BarMark(
                x: .value(CafeWording.drink, item.drink),
                y: .value(CafeWording.cupsAxisTitle, item.cups)
            )
        }
        // end
    }
}

struct DefaultElementsStackedChart: View {
    let orders: [DrinkOrder]

    var body: some View {
        // snippet:default-elements-stacked
        // Three sizes stacked at each drink: one element per drink, read as the stack's total.
        Chart(orders) { order in
            BarMark(
                x: .value(CafeWording.drink, order.drink),
                y: .value(CafeWording.cupsAxisTitle, order.cups)
            )
            .foregroundStyle(by: .value(CafeWording.size, order.size))
        }
        // end
        // The app's sizes, as on every screen that draws them. Colour only: the elements are the framework's own.
        .chartForegroundStyleScale(domain: CafeSizeStyle.sizes, mapping: CafeSizeStyle.colour(for:))
    }
}

struct DefaultElementsGroupedChart: View {
    let orders: [DrinkOrder]

    var body: some View {
        // snippet:default-elements-grouped
        // The same bars side by side: still one element per drink, read as its total, exactly as stacked.
        Chart(orders) { order in
            BarMark(
                x: .value(CafeWording.drink, order.drink),
                y: .value(CafeWording.cupsAxisTitle, order.cups)
            )
            .foregroundStyle(by: .value(CafeWording.size, order.size))
            .position(by: .value(CafeWording.size, order.size), axis: .horizontal)
        }
        // end
        .chartForegroundStyleScale(domain: CafeSizeStyle.sizes, mapping: CafeSizeStyle.colour(for:))
    }
}

struct DefaultElementsSeveralSeriesChart: View {
    let stores: [StoreSales]

    var body: some View {
        // snippet:default-elements-several-series
        // Two lines over seven days: one element per day, read as a range of dates and the first café's
        // value to the second's. The days are already midnight in the device's calendar, which is the
        // calendar the axis and the elements use when none is given.
        Chart(stores) { store in
            ForEach(store.days) { day in
                LineMark(
                    x: .value(CafeWording.day, day.day, unit: .day),
                    y: .value(CafeWording.cupsAxisTitle, day.cups)
                )
            }
            .foregroundStyle(by: .value(CafeWording.store, store.store))
            .symbol(by: .value(CafeWording.store, store.store))
        }
        // end
        // Each café in its colour and shape on every screen that draws the two.
        .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
        .chartSymbolScale(mapping: CafeSeriesStyle.symbol(for:))
    }
}

struct DefaultElementsDenseLineChart: View {
    let readings: [DefaultElementsQueueReading]

    var body: some View {
        // snippet:default-elements-dense-line
        // 330 readings on a number axis: the framework merges neighbours into stretches of the axis.
        // `series:` breaks only the drawn line at the missing hour: the elements and the Audio Graph
        // still get one unbroken series.
        Chart(readings) { reading in
            LineMark(
                x: .value(DefaultElementsWording.hour, reading.hour),
                y: .value(CafeWording.queueAxisTitle, reading.people),
                series: .value(DefaultElementsWording.partOfDay, reading.partOfDay)
            )
        }
        // end
        .chartXScale(domain: .automatic(includesZero: false))
    }
}

struct DefaultElementsMonthChart: View {
    let days: [DailySales]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // snippet:default-elements-month-of-days
        // Thirty bars at days: a date axis, so neighbouring days are merged into shared elements.
        Chart(days) { day in
            BarMark(
                x: .value(CafeWording.day, day.day, unit: .day),
                y: .value(CafeWording.cupsAxisTitle, day.cups)
            )
        }
        // end
        // Not part of the concept: at the accessibility sizes the default weekly labels ("Mar 1") are cut
        // to "Ma…", so there each week is labelled by its day of the month alone. The axis is not an
        // element, so this changes nothing VoiceOver or the Audio Graph gets.
        .chartXAxis {
            if dynamicTypeSize.isAccessibilitySize {
                AxisMarks(values: .stride(by: .weekOfYear)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: .dateTime.day())
                }
            } else {
                AxisMarks()
            }
        }
    }
}

// MARK: What the screen says about the chart

/// A panel in the controls' style, with a title read as a heading.
struct DefaultElementsPanel<Content: View>: View {
    let title: String
    var subtitle: String?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// The elements VoiceOver reads, in order, as read on iOS.
struct DefaultElementsReadElements: View {
    let elements: [DefaultElementsSpokenElement]
    @Environment(\.locale) private var locale

    var body: some View {
        DefaultElementsPanel(
            title: "What VoiceOver reads",
            subtitle: "Read on iOS 27 (simulator): \(DefaultElementsWording.elements(elements.count, locale: locale)), label then value."
        ) {
            ForEach(Array(elements.enumerated()), id: \.offset) { _, element in
                VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                    Text(element.label)
                        .font(.subheadline.weight(.semibold))
                    if !element.value.isEmpty {
                        Text(element.value)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityElement(children: .combine)
            }
        }
    }
}

/// What the default Audio Graph is given, as read on iOS.
struct DefaultElementsReadAudioGraph: View {
    let audioGraph: DefaultElementsAudioGraph

    var body: some View {
        DefaultElementsPanel(title: "What the Audio Graph gets", subtitle: "Read on iOS 27 (simulator).") {
            LabeledContent("Title", value: audioGraph.title)
            LabeledContent("Summary", value: audioGraph.summary)
            LabeledContent("X axis", value: audioGraph.xAxis)
            LabeledContent("Y axis", value: audioGraph.yAxis)
            LabeledContent("Series", value: audioGraph.series)
            LabeledContent("Points", value: audioGraph.points)
        }
        .font(.subheadline)
    }
}

/// What this default chart leaves out, and the screens that add it.
struct DefaultElementsWhatIsMissing: View {
    let text: String

    var body: some View {
        DefaultElementsPanel(title: "What a real chart adds") {
            Text("This chart deliberately has no accessibility code and no chart descriptor. \(text)")
                .font(.subheadline)
        }
    }
}

/// How to hear the chart on a device.
struct DefaultElementsHowToHear: View {
    var body: some View {
        DefaultElementsPanel(title: "Hear it on a device") {
            Text("""
            Turn on VoiceOver, touch the chart, then swipe right to move from element to element. \
            For the Audio Graph, keep the chart focused, turn the rotor to Audio Graph, and choose \
            Describe chart, Chart Details or Play Audio Graph.
            """)
            .font(.subheadline)
        }
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/what-you-get-for-free") {
            DefaultElementsScreen(screen: screen)
        }
    }
}

#Preview("No data") {
    DefaultElementsChart(viewModel: DefaultElementsViewModel(
        data: DefaultElementsData(drinkSales: [], drinkOrders: [], week: [], readings: [], month: [])
    ))
    .frame(height: Layout.chartHeightCompact)
}
