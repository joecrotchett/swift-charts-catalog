import Accessibility
import Charts
import SwiftUI

/// "Series": what makes marks one line or several.
struct SeriesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = SeriesViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold per day, by café",
            message: viewModel.summary.headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            SeriesChart(
                stores: viewModel.stores,
                declaration: viewModel.declaration,
                isShowingMistake: viewModel.isShowingMistake
            )
        } controls: {
            SeriesControls(viewModel: viewModel)
        }
        .onChange(of: viewModel.announcement) { _, announcement in
            // The lines change without moving: say so for people who cannot see it happen.
            AccessibilityNotification.Announcement(announcement).post()
        }
    }
}

/// The picker for how the series is declared, and the switch that removes it.
struct SeriesControls: View {
    @Bindable var viewModel: SeriesViewModel

    var body: some View {
        ControlsSection {
            // A visible title, so a sighted reader is told what the picker chooses, read once by VoiceOver.
            LabeledMenuPicker(title: "Series declared with", selection: $viewModel.declaration) {
                ForEach(SeriesDeclaration.allCases) { declaration in
                    Text(declaration.title).tag(declaration)
                }
            }
            .disabled(viewModel.isShowingMistake)
            MistakeToggle(title: "Remove the series", isShowingMistake: $viewModel.isShowingMistake)
        }
    }
}

/// Two cafés' daily cups as lines, with the series declared one way, or not at all.
struct SeriesChart: View {
    let stores: [StoreSales]
    let declaration: SeriesDeclaration
    let isShowingMistake: Bool

    var body: some View {
        // No days, or only zeros, is no data: a placeholder, not an empty plot.
        if SeriesSummary(stores: stores).hasData {
            Chart {
                if isShowingMistake {
                    JoinedLines(stores: stores)
                } else if declaration == .seriesParameter {
                    SeriesParameterLines(stores: stores)
                } else if declaration == .foregroundStyle {
                    ColourEncodedLines(stores: stores)
                } else if declaration == .symbol {
                    SymbolEncodedLines(stores: stores)
                } else {
                    LineStyleEncodedLines(stores: stores)
                }
                SeriesEndLabels(stores: stores)
            }
            // Each café in its colour and shape on every screen that draws the two.
            .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
            .chartSymbolScale(mapping: CafeSeriesStyle.symbol(for:))
            // Daily cups sit far from zero, and the chart is about their change, not their size. One domain, off
            // zero, for the chart and the descriptor.
            .chartYScale(domain: SeriesSummary(stores: stores).cupsRange)
            .chartXAxis {
                // The days were counted in the data's calendar, so the axis is told too:
                // left alone, its marks and labels follow the device's calendar and time zone.
                AxisMarks(values: .stride(by: .day, count: SeriesSummary.daysPerPortion, calendar: CafeData.calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: Date.FormatStyle(timeZone: CafeData.calendar.timeZone).month().day())
                }
            }
            // In the mistake state the descriptor describes the one joined line that is drawn.
            .accessibilityChartDescriptor(SeriesChartDescriptor(stores: stores, isJoined: isShowingMistake))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold per day appear here, one line per café.")
            )
        }
    }
}

/// The `series:` parameter: the lines are told apart, and styled by hand.
struct SeriesParameterLines: ChartContent {
    let stores: [StoreSales]

    var body: some ChartContent {
        // snippet:series-parameter
        ForEach(stores) { store in
            // WeeklyElements wraps each week's marks in a labelled Plot, for VoiceOver.
            WeeklyElements(store: store) { item in
                LineMark(
                    x: .value("Day", item.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", item.cups),
                    // Marks with the same series value form one line.
                    series: .value("Café", store.store)
                )
            }
            // Styled by hand: a fixed colour is not a scale, so there is no legend.
            .foregroundStyle(CafeSeriesStyle.colour(for: store.store))
        }
        // end
    }
}

/// `foregroundStyle(by:)`: the café decides the colour, which also separates the lines.
struct ColourEncodedLines: ChartContent {
    let stores: [StoreSales]

    var body: some ChartContent {
        // snippet:series-foreground-style
        ForEach(stores) { store in
            // WeeklyElements wraps each week's marks in a labelled Plot, for VoiceOver.
            WeeklyElements(store: store) { item in
                LineMark(
                    x: .value("Day", item.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", item.cups)
                )
            }
            // Marks that share this value form one line. Each value gets a colour and a legend entry.
            .foregroundStyle(by: .value("Café", store.store))
        }
        // end
    }
}

/// `symbol(by:)`: the café decides the point shape, which also separates the lines.
struct SymbolEncodedLines: ChartContent {
    let stores: [StoreSales]

    var body: some ChartContent {
        // snippet:series-symbol
        ForEach(stores) { store in
            // WeeklyElements wraps each week's marks in a labelled Plot, for VoiceOver.
            WeeklyElements(store: store) { item in
                LineMark(
                    x: .value("Day", item.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", item.cups)
                )
            }
            // Marks that share this value form one line, with a marker at every point.
            // The legend shows each café's shape; the colour is not encoded.
            .symbol(by: .value("Café", store.store))
        }
        // end
    }
}

/// `lineStyle(by:)`: the café decides the dash pattern, which also separates the lines.
struct LineStyleEncodedLines: ChartContent {
    let stores: [StoreSales]

    var body: some ChartContent {
        // snippet:series-line-style
        ForEach(stores) { store in
            // WeeklyElements wraps each week's marks in a labelled Plot, for VoiceOver.
            WeeklyElements(store: store) { item in
                LineMark(
                    x: .value("Day", item.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", item.cups)
                )
            }
            // Marks that share this value form one line: solid, then dashed.
            // The legend shows a sample of each; the colour is not encoded.
            .lineStyle(by: .value("Café", store.store))
        }
        // end
    }
}

/// The mistake: nothing says which line a mark belongs to, so there is only one.
struct JoinedLines: ChartContent {
    let stores: [StoreSales]

    var body: some ChartContent {
        // snippet:series-mistake
        ForEach(stores) { store in
            // WeeklyElements wraps each week's marks in a labelled Plot, for VoiceOver.
            // Here each label says it is a stretch of the one joined line.
            WeeklyElements(store: store, isJoined: true) { item in
                // No series: and no by: encoding. Every LineMark in the chart joins into one line,
                // which doubles back from the end of one café's days to the start of the next.
                LineMark(
                    x: .value("Day", item.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", item.cups)
                )
            }
        }
        // end
    }
}

/// One café's marks in stretches of a week. Each stretch is one accessibility element saying the café,
/// the dates and the cups; the line is still drawn as one.
struct WeeklyElements<Marks: ChartContent>: ChartContent {
    let store: StoreSales
    /// True when the marks join every café into one line, so the label must not promise a line per café.
    var isJoined = false
    @ChartContentBuilder let marks: (DailySales) -> Marks

    var body: some ChartContent {
        ForEach(SeriesSummary(stores: [store], isJoined: isJoined).portions(of: store)) { portion in
            Plot {
                ForEach(portion.days) { day in
                    marks(day)
                }
            }
            .accessibilityLabel(portion.label)
            .accessibilityValue(portion.value)
        }
    }
}

/// Each café's name at the end of its line, so the lines are told apart by more than colour,
/// and by something when there is no legend.
struct SeriesEndLabels: ChartContent {
    let stores: [StoreSales]

    var body: some ChartContent {
        ForEach(stores) { store in
            if let last = store.days.last {
                // An invisible point to hang the name on. Hidden from assistive technologies:
                // it repeats the line's last value, and the name is in each element's label.
                PointMark(
                    x: .value("Day", last.day, unit: .day, calendar: CafeData.calendar),
                    y: .value("Cups", last.cups)
                )
                .symbolSize(0)
                .accessibilityHidden(true)
                .annotation(position: .trailing, overflowResolution: .init(x: .padScale, y: .padScale)) {
                    Text(store.store)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// The chart for the Audio Graph: a title, a summary, written-out dates, cups as the unit,
/// and one named, continuous series per café. In the mistake state it describes what is drawn
/// instead: one series that runs through every café's days in turn.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SeriesChartDescriptor: AXChartDescriptorRepresentable {
    let stores: [StoreSales]
    /// True when no series is declared and the cafés are joined into one line.
    var isJoined = false

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = SeriesSummary(stores: stores, isJoined: isJoined)
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: summary.dayNames)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.cupsRange,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in SeriesSummary.cupsText(count) } }
        return AXChartDescriptor(
            title: summary.title,
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: isJoined ? joinedSeries(summary) : separateSeries(summary)
        )
    }

    private func separateSeries(_ summary: SeriesSummary) -> [AXDataSeriesDescriptor] {
        summary.storesWithDays.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: true,
                dataPoints: store.days.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
            )
        }
    }

    /// One series, in the order the line is drawn: the first café's days, then back to the start for the next.
    private func joinedSeries(_ summary: SeriesSummary) -> [AXDataSeriesDescriptor] {
        guard !summary.joinedDays.isEmpty else { return [] }
        return [AXDataSeriesDescriptor(
            name: SeriesSummary.joinedSeriesName,
            isContinuous: true,
            dataPoints: summary.joinedDays.map { AXDataPoint(x: summary.dayName($0.day), y: Double($0.cups)) }
        )]
    }
}

#Preview("Series") {
    NavigationStack {
        if let screen = Catalog.screen(id: "composition/series") {
            SeriesScreen(screen: screen)
        }
    }
}

#Preview("The mistake") {
    SeriesChart(stores: CafeData.storeSales, declaration: .seriesParameter, isShowingMistake: true)
        .padding()
}

#Preview("No sales") {
    SeriesChart(stores: [], declaration: .foregroundStyle, isShowingMistake: false)
}
