import Accessibility
import Charts
import SwiftUI

/// "Keeping a large plot fast": thousands of orders in one `PointPlot`, with the three pieces of advice Apple
/// gives for a large plot each turned on and off, and what one render on the simulator measured: none of them
/// made a measurable difference; the number of points did. Every setting draws the same orders; the automatic
/// domains change the axis and colours, and the sort changes which drink is drawn on top.
struct LargePlotScreen: View {
    let screen: CatalogScreen
    @State private var model = LargePlotViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Orders across one day",
            message: model.headline(locale: locale),
            explanation: """
            Apple's advice for a large plot is to read stored properties through key paths, sort the data by the \
            property that sets the style, and state the scale domains. In a single render on the iOS simulator \
            none of the three made a measurable difference: what costs time is the number of points. One render \
            says nothing about live updates, scrolling or a device, so measure your own chart before promising \
            speed. Stating the domains is worth it for the picture: the wait axis ends at 10 and each drink keeps \
            its colour in every setting. The time axis runs from 6 AM to 6 PM, and every setting draws the same orders.
            """,
            snippets: LargePlotSnippets.references(
                readsStoredProperties: model.readsStoredProperties,
                sortsByDrink: model.sortsByDrink,
                setsScaleDomains: model.setsScaleDomains
            )
        ) {
            LargePlotChart(
                orders: model.orders,
                readsStoredProperties: model.readsStoredProperties,
                setsScaleDomains: model.setsScaleDomains,
                locale: locale
            )
            .accessibilityRepresentation {
                LargePlotSpokenChart(
                    portions: model.portions, setsScaleDomains: model.setsScaleDomains, locale: locale
                )
                .accessibilityChartDescriptor(LargePlotChartDescriptor(
                    orders: model.generatedOrders, setsScaleDomains: model.setsScaleDomains, locale: locale
                ))
                // New words for the same stretches: a new identity, or VoiceOver keeps reading the old ones.
                .id(LargePlotSpokenIdentity(count: model.count, setsScaleDomains: model.setsScaleDomains))
            }
        } controls: {
            LargePlotControls(model: model, locale: locale)
        }
    }
}

/// What makes the spoken chart's words change: the orders, and the y range the descriptor gives.
struct LargePlotSpokenIdentity: Hashable {
    let count: Int
    let setsScaleDomains: Bool
}

// MARK: - The chart

/// The drawn chart, one variant per setting. It takes plain values and no view model, so a probe can render
/// each variant on its own: `LargePlotChart(orders:readsStoredProperties:setsScaleDomains:locale:)`, with the
/// orders passed sorted (`LargePlotViewModel.sortedByDrink(_:)`) or as generated (`CafeData.manyOrders(count:)`).
struct LargePlotChart: View {
    let orders: [CafeOrder]
    let readsStoredProperties: Bool
    let setsScaleDomains: Bool
    let locale: Locale
    /// The chart's colours in palette order, read from the chart so the legend's swatches are the drawn ones.
    /// Held in an object that only the legend reads: as `@State` read here, writing it once the chart had drawn
    /// drew all the points a second time, which doubled the first render (343 ms against 179 at 20,000 points
    /// on the simulator).
    @State private var palette = LargePlotPalette()

    /// The drinks in the colour scale's order: stated, the listed order; automatic, the order they first appear.
    private var legendDrinks: [String] {
        setsScaleDomains ? LargePlotScales.drinks : LargePlotViewModel.firstAppearance(in: orders)
    }

    var body: some View {
        if orders.isEmpty {
            ContentUnavailableView(
                "No orders",
                systemImage: "cup.and.saucer",
                description: Text("Orders appear here, one point each, across the day.")
            )
        } else {
            // snippet:keeping-a-large-plot-fast-plot
            // One plot for every order. The y key path is the setting: stored or computed.
            let waitPerCup = readsStoredProperties
                ? \CafeOrder.minutesPerCup
                : \CafeOrder.largePlotComputedMinutesPerCup
            Chart {
                PointPlot(
                    orders,
                    x: .value(TimeOfDayWording.timeOfDay, \.hour),
                    y: .value(LargePlotWording.waitPerCup, waitPerCup)
                )
                // Key-path modifiers first, then plain values.
                .foregroundStyle(by: .value(CafeWording.drink, \.drink))
                .symbolSize(LargePlotStyle.symbolArea)
            }
            // end
            .modifier(LargePlotDomains(isStated: setsScaleDomains))
            .timeOfDayAxis(locale: locale)
            .modifier(LargePlotYAxisTitle())
            // The framework's legend cuts "Mocha" short at the largest text sizes: this one wraps.
            .chartLegend(position: .bottom, alignment: .leading) {
                LargePlotPaletteLegend(drinks: legendDrinks, palette: palette)
            }
            .chartOverlay { proxy in
                // Only the palette comes from the chart. Its drink order does not: after the data is reordered
                // on screen the drawn colours change, but `foregroundStyleDomain` kept the old order.
                Color.clear
                    .onAppear { palette.styles = LargePlotLegendEntry.palette(from: proxy) }
            }
        }
    }
}

/// The wait and drink domains: stated, or left to the framework.
struct LargePlotDomains: ViewModifier {
    let isStated: Bool

    func body(content: Content) -> some View {
        if isStated {
            // snippet:keeping-a-large-plot-fast-domains
            // The bounds and the drinks are known, so say them: the axis ends at 10 and each drink keeps its
            // colour whatever order the data comes in. The render time did not change measurably.
            content
                .chartYScale(domain: LargePlotScales.waitPerCupDomain)
                .chartForegroundStyleScale(domain: LargePlotScales.drinks)
            // end
        } else {
            // snippet:keeping-a-large-plot-fast-automatic
            // Automatic: the axis ends where the framework rounds the longest wait to, and each drink takes its
            // colour in the order it first appears in the data, so sorting the data changes the colours.
            content
            // end
        }
    }
}

/// The y axis's title above the plot at its leading edge, shorter at the largest text sizes.
struct LargePlotYAxisTitle: ViewModifier {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.chartYAxisLabel(
            dynamicTypeSize >= .accessibility4
                ? LargePlotWording.shortWaitPerCupAxisTitle
                : LargePlotWording.waitPerCupAxisTitle,
            position: .top,
            alignment: .leading
        )
    }
}

/// Constants for this chart's marks and legend.
enum LargePlotStyle {
    /// A small symbol's area in square points, for a dense scatter.
    static let symbolArea: CGFloat = 4
    /// The legend's swatch diameter and the gaps around its entries, at the default text size.
    static let legendSwatch: CGFloat = 8
    static let legendSwatchGap: CGFloat = 4
    static let legendEntryGap: CGFloat = 12
    static let legendRowGap: CGFloat = 4
}

// MARK: - The legend

/// One drink in the legend and the colour the chart gave it.
struct LargePlotLegendEntry: Identifiable {
    let drink: String
    let style: AnyShapeStyle

    var id: String {
        drink
    }

    /// The chart's colours in the order it hands them out, whichever drink holds each.
    static func palette(from proxy: ChartProxy) -> [AnyShapeStyle] {
        proxy.foregroundStyleDomain(dataType: String.self).compactMap { proxy.foregroundStyle(for: $0) }
    }

    /// Each drink with the colour at its place in the scale's order.
    static func entries(drinks: [String], palette: [AnyShapeStyle]) -> [LargePlotLegendEntry] {
        drinks.enumerated().map { index, drink in
            LargePlotLegendEntry(drink: drink, style: index < palette.count ? palette[index] : AnyShapeStyle(.gray))
        }
    }
}

/// The chart's colours, written by the chart's overlay and read only by the legend, so that writing them redraws
/// the legend and not the plot.
@Observable
final class LargePlotPalette {
    var styles: [AnyShapeStyle] = []
}

/// The legend with the chart's colours: reads the palette in its own body, so only it redraws when they arrive.
struct LargePlotPaletteLegend: View {
    let drinks: [String]
    let palette: LargePlotPalette

    var body: some View {
        LargePlotLegend(entries: LargePlotLegendEntry.entries(drinks: drinks, palette: palette.styles))
    }
}

/// A legend like the framework's, a circle and a name per drink, that wraps onto more rows rather than cutting
/// a name short at the largest text sizes.
struct LargePlotLegend: View {
    let entries: [LargePlotLegendEntry]
    @ScaledMetric(relativeTo: .caption) private var swatch = LargePlotStyle.legendSwatch
    @ScaledMetric(relativeTo: .caption) private var swatchGap = LargePlotStyle.legendSwatchGap
    @ScaledMetric(relativeTo: .caption) private var entryGap = LargePlotStyle.legendEntryGap

    var body: some View {
        LargePlotWrappingLayout(spacing: entryGap, rowSpacing: LargePlotStyle.legendRowGap) {
            ForEach(entries) { entry in
                HStack(spacing: swatchGap) {
                    Circle()
                        .fill(entry.style)
                        .frame(width: swatch, height: swatch)
                    Text(entry.drink)
                        .font(.caption)
                        // `Color.secondary`: a bare `.secondary` in the legend slot took the tint.
                        .foregroundStyle(Color.secondary)
                }
            }
        }
    }
}

/// Lays its subviews out in rows from the leading edge, starting a new row when the next one would not fit.
struct LargePlotWrappingLayout: SwiftUI.Layout {
    let spacing: CGFloat
    let rowSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let frames = frames(for: subviews, width: proposal.width ?? .infinity)
        let width = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        for (subview, frame) in zip(subviews, frames(for: subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + rowHeight + rowSpacing)
                rowHeight = 0
            }
            frames.append(CGRect(origin: origin, size: size))
            origin.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return frames
    }
}

// MARK: - What VoiceOver reads

/// What VoiceOver reads in place of the plot: one element per two hours of the day, each spanning the plot's
/// height so they are read along x, labelled with clock times and valued with counts and waits per cup.
struct LargePlotSpokenChart: View {
    let portions: [TimeOfDayPortion]
    let setsScaleDomains: Bool
    let locale: Locale

    var body: some View {
        Chart {
            ForEach(portions) { portion in
                Plot {
                    RectangleMark(
                        xStart: .value(TimeOfDayWording.timeOfDay, portion.start),
                        xEnd: .value(TimeOfDayWording.timeOfDay, portion.end),
                        yStart: .value(LargePlotWording.waitPerCup, LargePlotScales.waitPerCupDomain.lowerBound),
                        yEnd: .value(LargePlotWording.waitPerCup, LargePlotScales.waitPerCupDomain.upperBound)
                    )
                }
                .accessibilityLabel(portion.label(locale: locale))
                .accessibilityValue(LargePlotViewModel.spokenValue(of: portion, locale: locale))
            }
        }
        .chartYScale(domain: LargePlotScales.waitPerCupDomain)
        .timeOfDayAxis(locale: locale)
    }
}

/// The chart for the Audio Graph: thousands of points are too many to play, so it gives the median wait per
/// cup of each hour, with times and minutes written out.
nonisolated struct LargePlotChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [CafeOrder]
    /// Whether the drawn y scale is the stated `0 ... 10` or automatic, from zero to the longest wait.
    let setsScaleDomains: Bool
    let locale: Locale

    /// The median of each hour's orders, at the middle of the hour; hours with no orders are left out.
    var hourlyMedians: [(hour: Double, median: Double)] {
        let day = TimeOfDayWording.dayHours
        return Array(stride(from: day.lowerBound, to: day.upperBound, by: 1)).compactMap { start in
            let isLast = start + 1 >= day.upperBound
            let waits = orders
                .filter { $0.hour >= start && ($0.hour < start + 1 || (isLast && $0.hour <= start + 1)) }
                .map(\.minutesPerCup)
                .sorted()
            return waits.isEmpty ? nil : (start + 0.5, LargePlotViewModel.median(waits))
        }
    }

    /// The y range as drawn: the stated domain, or the automatic one, which ends at a round number past the
    /// longest wait.
    var yRange: ClosedRange<Double> {
        setsScaleDomains
            ? LargePlotScales.waitPerCupDomain
            : 0 ... LargePlotScales.automaticWaitTop(longest: orders.map(\.minutesPerCup).max() ?? 0)
    }

    var summary: String {
        let waits = orders.map(\.minutesPerCup)
        guard let shortest = waits.min(), let longest = orders.max(by: { $0.minutesPerCup < $1.minutesPerCup }) else {
            return "No orders."
        }
        let drinks = LargePlotScales.drinks.map { drink in
            "\(drink) \(orders.count { $0.drink == drink }.formatted(.number.locale(locale)))"
        }
        return "\(CafeWording.orders(orders.count, locale: locale)) between "
            + "\(TimeOfDayWording.time(hour: TimeOfDayWording.dayHours.lowerBound, locale: locale)) and "
            + "\(TimeOfDayWording.time(hour: TimeOfDayWording.dayHours.upperBound, locale: locale)). "
            + "Waits per cup from \(TimeOfDayWording.minutes(shortest, locale: locale)) to "
            + "\(TimeOfDayWording.minutes(longest.minutesPerCup, locale: locale)), the longest at "
            + "\(TimeOfDayWording.time(hour: longest.hour, locale: locale)). "
            + "By drink: \(CafeWording.list(drinks)). Played as each hour's median."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXNumericDataAxisDescriptor(
            title: TimeOfDayWording.timeOfDay,
            range: TimeOfDayWording.dayHours,
            gridlinePositions: []
        ) { hour in TimeOfDayWording.time(hour: hour, locale: locale) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: LargePlotWording.waitPerCupAxisTitle,
            range: yRange,
            gridlinePositions: []
        ) { minutes in minutes.isFinite ? TimeOfDayWording.minutes(minutes, locale: locale) : "" }
        let series = AXDataSeriesDescriptor(
            name: LargePlotWording.medianSeries,
            isContinuous: false,
            dataPoints: hourlyMedians.map { AXDataPoint(x: $0.hour, y: $0.median) }
        )
        return AXChartDescriptor(
            title: "Wait per cup of each order across one day",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - Snippets

/// The snippets See Code shows: the plot, then the code behind each toggle as it is now set.
enum LargePlotSnippets {
    static let plot = SnippetReference(name: "keeping-a-large-plot-fast-plot", title: "One plot, a key path per value")
    static let computed = SnippetReference(
        name: "keeping-a-large-plot-fast-computed", title: "A computed wait per cup"
    )
    static let sorted = SnippetReference(name: "keeping-a-large-plot-fast-sorted", title: "Orders sorted by drink")
    static let unsorted = SnippetReference(name: "keeping-a-large-plot-fast-unsorted", title: "Orders as generated")
    static let domains = SnippetReference(name: "keeping-a-large-plot-fast-domains", title: "Stated domains")
    static let automatic = SnippetReference(name: "keeping-a-large-plot-fast-automatic", title: "Automatic domains")

    /// The default setting's snippets, which the catalog registers.
    static let defaults = references(readsStoredProperties: true, sortsByDrink: true, setsScaleDomains: true)

    static func references(readsStoredProperties: Bool, sortsByDrink: Bool, setsScaleDomains: Bool) -> [SnippetReference] {
        var references = [plot]
        if !readsStoredProperties { references.append(computed) }
        references.append(sortsByDrink ? sorted : unsorted)
        references.append(setsScaleDomains ? domains : automatic)
        return references
    }
}

// MARK: - Controls

/// The point count, a toggle per piece of advice, and what one render measured.
struct LargePlotControls: View {
    @Bindable var model: LargePlotViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSlider(
                title: CafeWording.orders,
                value: $model.orderCount,
                range: Double(LargePlotViewModel.smallestCount) ... Double(CafeData.manyOrdersMaximum),
                step: Double(LargePlotViewModel.countStep),
                valueText: model.countText(locale: locale),
                spokenValue: model.countSpokenValue(locale: locale)
            )
            Toggle(LargePlotAdvice.storedProperties.title, isOn: $model.readsStoredProperties)
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Toggle(LargePlotAdvice.sortedByStyle.title, isOn: $model.sortsByDrink)
                Text(model.styleChangesText(locale: locale))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Toggle(LargePlotAdvice.explicitDomains.title, isOn: $model.setsScaleDomains)
                if let note = model.domainNote {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onChange(of: model.readsStoredProperties) { announce(.storedProperties) }
        .onChange(of: model.sortsByDrink) { announce(.sortedByStyle) }
        .onChange(of: model.setsScaleDomains) { announce(.explicitDomains) }
        LargePlotTimings(
            caption: LargePlotViewModel.timingCaption(
                orderCount: LargePlotViewModel.measuredOrderCount, spread: LargePlotViewModel.spreadMilliseconds, locale: locale
            ),
            lines: LargePlotViewModel.timingLines(LargePlotViewModel.measurements, locale: locale),
            verdict: LargePlotViewModel.timingVerdict(
                LargePlotViewModel.measurements,
                orderCount: LargePlotViewModel.measuredOrderCount,
                spread: LargePlotViewModel.spreadMilliseconds,
                smallerCount: LargePlotViewModel.smallerOrderCount,
                smallerMilliseconds: LargePlotViewModel.smallerMilliseconds,
                locale: locale
            )
        )
    }

    private func announce(_ advice: LargePlotAdvice) {
        AccessibilityNotification.Announcement(model.announcement(for: advice, locale: locale)).post()
    }
}

/// The measured medians, what they vary by, and what they show. Shows nothing without measurements.
struct LargePlotTimings: View {
    let caption: String
    let lines: [String]
    let verdict: String

    var body: some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                Text(caption)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .monospacedDigit()
                }
                Text(verdict)
                    .font(.footnote)
            }
            .padding(Layout.panelPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
        }
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/keeping-a-large-plot-fast") {
            LargePlotScreen(screen: screen)
        }
    }
}

#Preview("Unsorted, computed, automatic") {
    LargePlotChart(
        orders: CafeData.manyOrders(count: 5000), readsStoredProperties: false, setsScaleDomains: false, locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No orders") {
    LargePlotChart(orders: [], readsStoredProperties: true, setsScaleDomains: true, locale: .current)
}
