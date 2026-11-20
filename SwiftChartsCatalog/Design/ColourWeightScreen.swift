import Accessibility
import Charts
import SwiftUI

/// "Colour: weight and meaning": two cafés in colours of equal weight, with names nobody mixes up,
/// and the mistake beside it, a dark colour next to a vivid one.
struct ColourWeightScreen: View {
    let screen: CatalogScreen
    @State private var model = ColourWeightViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and days
    /// the way the chart's axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.caption(locale: locale),
            message: model.headline(locale: locale),
            explanation: """
            Each café's colour is set on purpose: Harbour takes the sea's blue, and Station the orange furthest \
            from it, two names nobody mixes up. Red and green are left out here, since both are often read as \
            good or bad news, which two cafés are not. The two colours come out the same grey, so neither line looks more important: \
            the dot after each name in the legend is that colour in greyscale, and the two dots match. Turn on \
            the mistake and Station's bright orange sits beside Harbour's navy: the two dots are then far apart, \
            a dark grey for the navy and a light grey for the orange, and one line outweighs the other. In Dark \
            Mode the navy is lifted just enough to show on the dark panel, and its dot is still much darker.
            """,
            snippets: model.snippets
        ) {
            ColourWeightChart(model: model, locale: locale)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Colours of unequal weight", isShowingMistake: $model.isShowingUnequalWeight)
                    .disabled(!model.hasData)
            }
        }
        .onChange(of: model.isShowingUnequalWeight) {
            // Which colour each café gets is part of what the chart says, so the change is announced.
            AccessibilityNotification.Announcement(model.changeAnnouncement(locale: locale)).post()
        }
    }
}

/// Both cafés as lines with points, coloured by the current palette, or a placeholder with no days.
struct ColourWeightChart: View {
    let model: ColourWeightViewModel
    let locale: Locale

    var body: some View {
        if model.hasData {
            ColourWeightLines(model: model, locale: locale)
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each café's daily cups appear here as a line.")
            )
        }
    }
}

/// The chart itself.
struct ColourWeightLines: View {
    let model: ColourWeightViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// "Mar 8", or the day alone at the accessibility sizes, where "Mar 8" no longer fits a week's width.
    private var dayLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, calendar: model.calendar, timeZone: model.calendar.timeZone)
        return dynamicTypeSize.isAccessibilitySize ? style.day() : style.month(.abbreviated).day()
    }

    var body: some View {
        let palette = model.palette
        let calendar = model.calendar
        // snippet:colour-weight-and-meaning-chart
        Chart {
            ForEach(model.stores) { store in
                ForEach(store.days) { day in
                    LineMark(
                        x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar),
                        y: .value(CafeWording.cups, day.cups)
                    )
                }
                .foregroundStyle(by: .value(CafeWording.store, store.store))
                .lineStyle(StrokeStyle(lineWidth: ColourWeightMarks.lineWidth, lineCap: .round, lineJoin: .round))
                // The points below carry the values; the lines would only repeat them.
                .accessibilityHidden(true)
            }
            ForEach(model.days) { day in
                // One element per day, holding both cafés' points. The clear band the full height of the plot
                // gives every day the same top edge, so VoiceOver reads the days in date order.
                Plot {
                    RectangleMark(xStart: .value(CafeWording.day, day.date), xEnd: .value(CafeWording.day, day.end))
                        .foregroundStyle(.clear)
                    ForEach(day.readings) { reading in
                        PointMark(
                            x: .value(CafeWording.day, day.date, unit: .day, calendar: calendar),
                            y: .value(CafeWording.cups, reading.cups)
                        )
                        // Colour and shape together, so the cafés differ without colour too.
                        .foregroundStyle(by: .value(CafeWording.store, reading.store))
                        .symbol(by: .value(CafeWording.store, reading.store))
                        // Above the higher café's point and below the lower one's, away from the other line.
                        // On the sample's last day each line also comes in from the side away from its label.
                        .annotation(position: day.isLowest(reading) ? .bottom : .top, spacing: ColourWeightMarks.labelSpacing) {
                            // The last day's figures are the headline's, so they are written on the chart.
                            if day.isLast {
                                Text(reading.cups, format: .number.locale(locale))
                                    .font(.caption.bold())
                                    .foregroundStyle(Color.primary)
                            }
                        }
                    }
                }
                .accessibilityLabel(model.dayName(day.date, locale: locale))
                .accessibilityValue(model.dayValue(day, locale: locale))
            }
        }
        // One mapping from café to colour; the legend below reads the same one.
        .chartForegroundStyleScale(domain: model.storeNames) { palette.colour(for: $0) }
        .chartSymbolScale(domain: model.storeNames) { CafeSeriesStyle.symbol(for: $0) }
        // end
        .chartYScale(domain: model.cupsAxis)
        .chartXAxis {
            // Every seventh day of the data, given exactly: a stride ran on to a day 29 the data does not have.
            AxisMarks(values: model.labelledDays) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: dayLabelFormat)
            }
        }
        .chartYAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) {
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartLegend(position: .bottom, alignment: .leading) {
            ColourWeightLegend(model: model)
        }
        .accessibilityChartDescriptor(ColourWeightDescriptor(
            stores: model.stores, days: model.days, cupsAxis: model.cupsAxis,
            dayNames: model.days.map { model.dayName($0.date, locale: locale) }, locale: locale
        ))
    }
}

/// The legend: each café's symbol in its colour, its name and the colour's name, then the same colour
/// in greyscale, so the reader can see whether the two weigh the same. It wraps to one café a line at
/// the accessibility text sizes.
struct ColourWeightLegend: View {
    let model: ColourWeightViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var swatchSize = ColourWeightMarks.swatchSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.tightSpacing))
            : AnyLayout(HStackLayout(spacing: Layout.sectionSpacing))
        layout {
            ForEach(model.storeNames, id: \.self) { store in
                HStack(spacing: Layout.tightSpacing) {
                    CafeSeriesStyle.symbol(for: store)
                        .fill(model.palette.colour(for: store))
                        .frame(width: swatchSize, height: swatchSize)
                    Text("\(store), \(model.palette.colourName(for: store))")
                        .font(.caption)
                        .foregroundStyle(Color.primary)
                    Circle()
                        .fill(model.palette.colour(for: store))
                        .grayscale(1)
                        .frame(width: swatchSize, height: swatchSize)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(model.legendLabel(for: store))
            }
        }
    }
}

/// The sizes that belong to this chart's marks and legend.
private enum ColourWeightMarks {
    static let lineWidth: CGFloat = 3
    static let labelSpacing: CGFloat = 2
    static let swatchSize: CGFloat = 10
}

/// The chart for the Audio Graph: both cafés as named series over the written-out days.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ColourWeightDescriptor: AXChartDescriptorRepresentable {
    let stores: [StoreSales]
    let days: [ColourWeightDay]
    let cupsAxis: ClosedRange<Double>
    /// Each day written out, in the same order as `days`.
    let dayNames: [String]
    let locale: Locale

    var title: String {
        "Cups sold each day at \(CafeWording.list(stores.map(\.store)))"
    }

    var summary: String {
        guard let first = days.first, let last = days.last,
              let firstName = dayNames.first, let lastName = dayNames.last
        else { return "No cups sold yet." }
        let perStore = stores.filter { !$0.days.isEmpty }.map { store in
            let cups = store.days.map(\.cups)
            let opening = first.readings.first { $0.store == store.store }?.cups ?? cups[0]
            let closing = last.readings.first { $0.store == store.store }?.cups ?? cups[cups.count - 1]
            return "\(store.store): first day \(CafeWording.cups(opening, locale: locale)), "
                + "last day \(CafeWording.cups(closing, locale: locale)), "
                + "highest \(CafeWording.cups(cups.max() ?? 0, locale: locale))."
        }
        return "\(CafeWording.days(days.count, locale: locale)), \(firstName) to \(lastName). "
            + perStore.joined(separator: " ")
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let names = Dictionary(uniqueKeysWithValues: zip(days.map(\.date), dayNames))
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: dayNames)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle, range: cupsAxis, gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = stores.filter { !$0.days.isEmpty }.map { store in
            AXDataSeriesDescriptor(
                name: store.store,
                isContinuous: true,
                dataPoints: store.days.map { AXDataPoint(x: names[$0.day] ?? "", y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: title, summary: summary, xAxis: xAxis, yAxis: yAxis, additionalAxes: [], series: series
        )
    }
}

#Preview("Equal weight") {
    NavigationStack {
        ColourWeightScreen(screen: CatalogScreen(
            id: "design/colour-weight-and-meaning", title: "Colour: weight and meaning", summary: "",
            apiSince: "16.0", skillReferences: ["design.md"], snippets: []
        ))
    }
}

#Preview("No sales") {
    ColourWeightChart(model: ColourWeightViewModel(stores: []), locale: .current)
}
