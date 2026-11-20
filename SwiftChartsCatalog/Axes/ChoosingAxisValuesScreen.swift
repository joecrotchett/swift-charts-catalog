import Accessibility
import Charts
import SwiftUI

/// "Choosing axis values": `.automatic(desiredCount:)`, `.stride(by:)` and an exact array on the y
/// axis, the count asked for against the count drawn, and values that widen the scale.
struct ChoosingAxisValuesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ChoosingAxisValuesViewModel
    /// Read here and passed in, so the labels, headline and descriptor write numbers one way.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: ChoosingAxisValuesViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink",
            message: viewModel.headline(locale: locale),
            explanation: """
            AxisMarks(values:) decides which values get a grid line, tick and label. \
            .automatic(desiredCount:) is a request, and the framework may draw a different number to keep \
            the values round; .stride(by:) marks every multiple; an array marks exactly those values. Every \
            value marked is added to the scale, so one beyond the data stretches the axis past the tallest bar.
            """,
            snippets: viewModel.snippets
        ) {
            ChoosingAxisValuesChart(viewModel: viewModel, locale: locale)
        } controls: {
            ChoosingAxisValuesControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// One bar per drink, with the y axis's values chosen by the view model's setting.
struct ChoosingAxisValuesChart: View {
    let viewModel: ChoosingAxisValuesViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasData {
            let choice = viewModel.choice
            // snippet:choosing-axis-values-chart
            Chart(viewModel.sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, item.drink),
                        // Plotted as Double, the type the domain and the labels are read back as.
                        y: .value(CafeWording.cups, Double(item.cups))
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // end
            .chartYAxis { yAxis }
            .chartBackground { proxy in
                // The y domain as drawn, axis values included, for the Audio Graph's range.
                let domain = proxy.yDomain(dataType: Double.self)
                // Keyed on the setting too: a new setting can leave the domain unchanged.
                Color.clear
                    .task(id: ChoosingAxisValuesDomainReport(choice: choice, domain: domain)) {
                        viewModel.recordDomain(domain, for: choice)
                    }
            }
            .accessibilityChartDescriptor(ChoosingAxisValuesDescriptor(
                sales: viewModel.sales,
                range: viewModel.domain,
                gridlines: viewModel.drawnValues ?? [],
                summary: viewModel.audioGraphSummary(locale: locale),
                locale: locale
            ))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        }
    }

    /// The y axis for the current setting. The condition sits inside the axis content, so the chart
    /// stays one chart. Each case is the whole `AxisMarks` the Code view shows for it.
    @AxisContentBuilder
    private var yAxis: some AxisContent {
        let choice = viewModel.choice
        let onDrawn: (ChoosingAxisValuesReading) -> Void = { [viewModel, locale] reading in
            viewModel.record(reading, locale: locale)
        }
        switch choice {
        case let .automatic(desiredCount):
            // snippet:choosing-axis-values-automatic
            // About this many values: the framework may draw more or fewer to keep them round.
            AxisMarks(values: .automatic(desiredCount: desiredCount)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    ChoosingAxisValuesLabel(value: value, choice: choice, locale: locale, onDrawn: onDrawn)
                }
            }
        // end
        case let .stride(by: step):
            // snippet:choosing-axis-values-stride
            // Every multiple of the step that the scale covers.
            AxisMarks(values: .stride(by: Double(step))) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    ChoosingAxisValuesLabel(value: value, choice: choice, locale: locale, onDrawn: onDrawn)
                }
            }
        // end
        case let .exact(values):
            // snippet:choosing-axis-values-exact
            // Exactly these values. They are added to the scale's domain, so 300, above every bar,
            // stretches the axis to 300.
            AxisMarks(values: values.map(Double.init)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    ChoosingAxisValuesLabel(value: value, choice: choice, locale: locale, onDrawn: onDrawn)
                }
            }
            // end
        }
    }
}

/// What the chart's background reports: the y domain drawn for one setting.
struct ChoosingAxisValuesDomainReport: Hashable {
    let choice: ChoosingAxisValuesChoice
    let domain: [Double]
}

/// An axis label that also reports what it marks, so the screen can show the count actually drawn.
struct ChoosingAxisValuesLabel: View {
    let value: AxisValue
    let choice: ChoosingAxisValuesChoice
    let locale: Locale
    let onDrawn: (ChoosingAxisValuesReading) -> Void

    var body: some View {
        if let number = value.as(Double.self) {
            // snippet:choosing-axis-values-drawn
            // value.count is how many values the axis drew; value.index is this one's place among them.
            let reading = ChoosingAxisValuesReading(choice: choice, index: value.index, count: value.count, value: number)
            Text(number, format: .number.locale(locale))
                .task(id: reading) { onDrawn(reading) }
            // end
        }
    }
}

/// The controls: how the values are chosen, then the one setting for that way.
struct ChoosingAxisValuesControls: View {
    @Bindable var viewModel: ChoosingAxisValuesViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Axis values", selection: $viewModel.mode) {
                ForEach(ChoosingAxisValuesMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            switch viewModel.mode {
            case .automatic:
                // The setting, then the headline: spoken on each step instead of an announcement.
                LabeledStepper(
                    title: "Values asked for", value: $viewModel.desiredCount, in: ChoosingAxisValuesViewModel.countRange,
                    valueText: viewModel.countComparison(locale: locale),
                    spokenValue: viewModel.stepperSpokenValue(locale: locale)
                )
            case .stride:
                LabeledSegmentedPicker(title: "A value every", selection: $viewModel.stride) {
                    ForEach(ChoosingAxisValuesViewModel.strides, id: \.self) { step in
                        Text(CafeWording.cups(step, locale: locale)).tag(step)
                    }
                }
            case .exact:
                Text("Values: \(ChoosingAxisValuesWording.numbers(ChoosingAxisValuesViewModel.exactValues.map(Double.init), locale: locale))")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The chart for the Audio Graph: drinks on x, cups on y over the domain as drawn.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ChoosingAxisValuesDescriptor: AXChartDescriptorRepresentable {
    let sales: [DrinkSales]
    /// The y domain the chart drew, axis values included.
    let range: ClosedRange<Double>
    /// The axis values drawn, as the descriptor's grid lines.
    let gridlines: [Double]
    let summary: String
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink))
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: range,
            gridlinePositions: gridlines
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, by drink",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Axis values") {
    NavigationStack {
        if let screen = Catalog.screen(id: "axes/choosing-axis-values") {
            ChoosingAxisValuesScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    ChoosingAxisValuesChart(viewModel: ChoosingAxisValuesViewModel(sales: []), locale: .current)
}
