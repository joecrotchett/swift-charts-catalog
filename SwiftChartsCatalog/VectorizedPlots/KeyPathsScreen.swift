import Accessibility
import Charts
import SwiftUI

/// "Key paths": `.value("Label", \.property)` inside a plot, an interval from two key paths, and the
/// key-path modifiers that read each element's colour, shape, size and opacity from the element.
struct KeyPathsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = KeyPathsViewModel()
    /// Read here and passed in, so the headline, the spoken text and the Audio Graph write numbers and
    /// times the way the chart's own axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.caption,
            message: viewModel.headline,
            explanation: """
            Inside a plot, .value takes a key path instead of a value: .value("Wait", \\.waitMinutes) reads that \
            property from every element of the collection, and an interval is one parameter with two key paths, \
            \\.start and \\.end. The key-path modifiers, such as foregroundStyle(by:), symbolSize(by:) and \
            opacity(_:), read each element's styling the same way, so the choices below only swap one key path \
            for another.
            """,
            snippets: viewModel.snippets
        ) {
            KeyPathsChart(viewModel: viewModel)
        } controls: {
            KeyPathsControls(viewModel: viewModel)
        }
        .onChange(of: locale, initial: true) { viewModel.update(locale: locale) }
        // Each of these changes what the marks stand for, so it is said aloud, then the headline.
        // Leaving out the size scale's range only restyles the points, and the toggle speaks its own state.
        .onChange(of: viewModel.example) { KeyPathsAnnouncer.announce(viewModel.exampleAnnouncement()) }
        .onChange(of: viewModel.colour) { KeyPathsAnnouncer.announce(viewModel.colourAnnouncement()) }
        .onChange(of: viewModel.size) { KeyPathsAnnouncer.announce(viewModel.sizeAnnouncement()) }
        .onChange(of: viewModel.opacity) { KeyPathsAnnouncer.announce(viewModel.opacityAnnouncement()) }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
enum KeyPathsAnnouncer {
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// Constants that belong to this screen's marks.
private enum KeyPathsMarks {
    /// The smallest and largest point, in square points of area.
    static let sizeRange: ClosedRange<CGFloat> = 10 ... 120
    static let cornerRadius: CGFloat = 4
    /// The part of the day the sample orders and shifts fall in.
    static let dayDomain = CafeData.time(6) ... CafeData.time(18)
}

/// The chart for the current example, or a placeholder when it has nothing to draw.
struct KeyPathsChart: View {
    let viewModel: KeyPathsViewModel

    var body: some View {
        if viewModel.isEmpty {
            ContentUnavailableView(
                viewModel.headline,
                systemImage: viewModel.example == .orders ? "cup.and.saucer" : "calendar",
                description: Text(viewModel.example == .orders
                    ? "Each order appears here as a point, by when it was placed and how long it took."
                    : "Each shift appears here as a bar from its start to its end.")
            )
        } else {
            switch viewModel.example {
            case .orders:
                KeyPathsOrdersChart(
                    orders: viewModel.orders, colour: viewModel.colour, size: viewModel.size,
                    opacity: viewModel.opacity, leavesOutSizeScale: viewModel.leavesOutSizeScale,
                    locale: viewModel.locale
                )
                // A new colour gives the chart new elements: a new identity, so VoiceOver does not keep the old.
                .id(viewModel.colour)
            case .shifts:
                KeyPathsShiftsChart(shifts: viewModel.shifts, locale: viewModel.locale)
            }
        }
    }
}

/// The point plot, with or without the range of sizes.
struct KeyPathsOrdersChart: View {
    let orders: [KeyPathsOrder]
    let colour: KeyPathsColour
    let size: KeyPathsSize
    let opacity: KeyPathsOpacity
    let leavesOutSizeScale: Bool
    let locale: Locale

    var body: some View {
        if leavesOutSizeScale {
            // snippet:key-paths-no-size-scale
            // symbolSize(by:) with no chartSymbolSizeScale(range:): the framework's default range of sizes.
            KeyPathsPointPlotChart(orders: orders, colour: colour, size: size, opacity: opacity, locale: locale)
            // end
        } else {
            // snippet:key-paths-size-scale
            KeyPathsPointPlotChart(orders: orders, colour: colour, size: size, opacity: opacity, locale: locale)
                .chartSymbolSizeScale(range: KeyPathsMarks.sizeRange)
            // end
        }
    }
}

/// One `PointPlot` for every order, each style read from the order through a key path.
struct KeyPathsPointPlotChart: View {
    let orders: [KeyPathsOrder]
    let colour: KeyPathsColour
    let size: KeyPathsSize
    let opacity: KeyPathsOpacity
    let locale: Locale

    var body: some View {
        Chart {
            // snippet:key-paths-point-plot
            PointPlot(
                orders,
                x: .value(KeyPathsWording.timeOfDay, \.time),
                y: .value(KeyPathsWording.wait, \.waitMinutes)
            )
            // Each key-path modifier reads its value from every order.
            .foregroundStyle(by: .value(colour.title, colour.keyPath))
            .symbol(by: .value(colour.title, colour.keyPath))
            .symbolSize(by: .value(size.title, size.keyPath))
            .opacity(opacity.keyPath)
            // end
        }
        // Every colour and shape is known in advance: say so, and the legend keeps one order.
        .keyPathsColourScale(colour)
        .chartSymbolScale(domain: colour.domain)
        .keyPathsHourAxis(locale: locale)
        // One wait axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
        .chartYScale(domain: KeyPathsOrdersDescriptor.waitDomain(for: orders))
        .waitAxisTitle()
        // snippet:key-paths-spoken-orders
        // The plot's key-path accessibilityLabel and accessibilityValue are not read, and its own elements
        // give no units, so VoiceOver gets labelled stretches of the day in place of the drawn points.
        .accessibilityRepresentation {
            TimeOfDaySpokenChart(
                portions: KeyPathsOrdersSummary(orders: orders, locale: locale).portions(colour: colour),
                locale: locale
            )
            .accessibilityChartDescriptor(KeyPathsOrdersDescriptor(orders: orders, colour: colour, locale: locale))
        }
        // end
    }
}

/// One `RectanglePlot` for every shift, each bar running between two key paths.
struct KeyPathsShiftsChart: View {
    let shifts: [KeyPathsShift]
    let locale: Locale

    var body: some View {
        Chart {
            // snippet:key-paths-interval
            RectanglePlot(
                shifts,
                // One parameter, two key paths: each bar runs from the shift's start to its end.
                x: .value(KeyPathsWording.timeOfDay, \.start, \.end),
                y: .value(CafeWording.barista, \.barista)
            )
            .cornerRadius(KeyPathsMarks.cornerRadius)
            // end
        }
        .keyPathsHourAxis(locale: locale)
        // snippet:key-paths-spoken-shifts
        // The plot's own elements read each bar as the hour around its middle, and its key-path labels are
        // not read, so VoiceOver gets one labelled mark per shift: the name, then start to end and length.
        .accessibilityRepresentation {
            Chart {
                ForEach(shifts) { shift in
                    Plot {
                        RectangleMark(
                            xStart: .value(KeyPathsWording.timeOfDay, shift.startHour),
                            xEnd: .value(KeyPathsWording.timeOfDay, shift.endHour),
                            y: .value(CafeWording.barista, shift.barista)
                        )
                    }
                    .accessibilityLabel(shift.spokenLabel)
                    .accessibilityValue(shift.spokenValue)
                }
            }
            .chartXScale(domain: TimeOfDayWording.dayHours)
            .accessibilityChartDescriptor(KeyPathsShiftsDescriptor(shifts: shifts, locale: locale))
        }
        // end
    }
}

/// The time-of-day axis both charts share, on dates: the same hours, labels and title as the other
/// vectorized-plot screens' `TimeOfDayAxis`, in UTC, the time zone the sample day was made in.
private struct KeyPathsHourAxis: ViewModifier {
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption2) private var endLabelRoom = TimeOfDayStyle.endLabelRoom

    func body(content: Content) -> some View {
        content
            .chartXScale(domain: KeyPathsMarks.dayDomain, range: .plotDimension(padding: endLabelRoom))
            .chartXAxis {
                AxisMarks(
                    preset: .aligned,
                    values: TimeOfDayWording.labelledHours(accessibilitySize: dynamicTypeSize.isAccessibilitySize)
                        .map(TimeOfDayWording.date(hour:))
                ) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: TimeOfDayWording.hourFormat(locale: locale))
                }
            }
            .chartXAxisLabel(KeyPathsWording.timeOfDay)
    }
}

private extension View {
    func keyPathsHourAxis(locale: Locale) -> some View {
        modifier(KeyPathsHourAxis(locale: locale))
    }

    /// The colour scale for the property that drives colour: the drinks in the app's one colour per drink, as on
    /// every screen that draws them; the order sizes (one to four cups), which are ordered, in the app's size hue
    /// in four steps of lightness, one cup lightest against the background and four cups heaviest.
    @ViewBuilder
    func keyPathsColourScale(_ colour: KeyPathsColour) -> some View {
        switch colour {
        case .drink:
            chartForegroundStyleScale(domain: colour.domain, mapping: CafeDrinkStyle.colour(for:))
        case .orderSize:
            chartForegroundStyleScale(domain: colour.domain) { CafeSizeStyle.colour(for: $0, in: colour.domain) }
        }
    }
}

/// Which example, which property drives colour, size and opacity, and the size-scale mistake.
struct KeyPathsControls: View {
    @Bindable var viewModel: KeyPathsViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Example", selection: $viewModel.example) {
                ForEach(KeyPathsExample.allCases) { Text($0.rawValue).tag($0) }
            }
            KeyPathsFootnote(text: viewModel.spokenNote)
            if viewModel.showsEncodingControls {
                KeyPathsEncodingControls(viewModel: viewModel)
                    .disabled(viewModel.isEmpty)
            }
        }
    }
}

/// The three pickers that swap one key path for another, and the size-scale mistake.
struct KeyPathsEncodingControls: View {
    @Bindable var viewModel: KeyPathsViewModel

    var body: some View {
        LabeledMenuPicker(title: "Colour and shape", selection: $viewModel.colour) {
            ForEach(KeyPathsColour.allCases) { Text($0.title).tag($0) }
        }
        LabeledMenuPicker(title: "Size", selection: $viewModel.size) {
            ForEach(KeyPathsSize.allCases) { Text($0.title).tag($0) }
        }
        LabeledMenuPicker(title: "Opacity", selection: $viewModel.opacity) {
            ForEach(KeyPathsOpacity.allCases) { Text($0.title).tag($0) }
        }
        // What the legends leave out, right after the pickers that change it.
        KeyPathsFootnote(text: viewModel.encodingNote)
        MistakeToggle(title: "Leave out the size scale's range", isShowingMistake: $viewModel.leavesOutSizeScale)
    }
}

/// A line of secondary text among the controls.
struct KeyPathsFootnote: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: Audio Graph

/// The orders for the Audio Graph: time of day against wait, one series per value of the colour.
nonisolated struct KeyPathsOrdersDescriptor: AXChartDescriptorRepresentable {
    let orders: [KeyPathsOrder]
    let colour: KeyPathsColour
    let locale: Locale

    /// The wait axis as drawn and as given here: 0 to the longest wait, rounded up to a tidy step.
    static func waitDomain(for orders: [KeyPathsOrder]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: orders.map(\.waitMinutes))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let dayStart = CafeData.time(0)
        // The drawn x scale's domain, so the Audio Graph's axis is the one on screen.
        let xAxis = AXNumericDataAxisDescriptor(
            title: KeyPathsWording.timeOfDay,
            range: TimeOfDayWording.dayHours,
            gridlinePositions: []
        ) { hour in
            hour.isFinite ? KeyPathsWording.time(dayStart.addingTimeInterval(hour * 3600), locale: locale) : ""
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: KeyPathsWording.waitAxisTitle,
            range: Self.waitDomain(for: orders),
            gridlinePositions: []
        ) { minutes in
            minutes.isFinite ? KeyPathsWording.minutes(minutes, locale: locale) : ""
        }
        let series = colour.domain.map { value in
            AXDataSeriesDescriptor(
                name: value,
                isContinuous: false,
                dataPoints: orders
                    .filter { $0[keyPath: colour.keyPath] == value }
                    .sorted { $0.time < $1.time }
                    .map { AXDataPoint(x: $0.time.timeIntervalSince(dayStart) / 3600, y: $0.waitMinutes) }
            )
        }
        return AXChartDescriptor(
            title: "Wait for each order by time of day, by \(colour.title.lowercased())",
            summary: KeyPathsOrdersSummary(orders: orders, locale: locale).audioGraphSummary(colour: colour),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

/// The shifts for the Audio Graph: one category per shift, with a series for starts and one for ends.
nonisolated struct KeyPathsShiftsDescriptor: AXChartDescriptorRepresentable {
    let shifts: [KeyPathsShift]
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let dayStart = CafeData.time(0)
        let summary = KeyPathsShiftsSummary(shifts: shifts, locale: locale)
        let categories = summary.categories
        let starts = shifts.map { $0.start.timeIntervalSince(dayStart) / 3600 }
        let ends = shifts.map { $0.end.timeIntervalSince(dayStart) / 3600 }
        // The drawn time axis, 6 am to 6 pm, not the shifts' own extent.
        let yAxis = AXNumericDataAxisDescriptor(
            title: KeyPathsWording.timeOfDay,
            range: TimeOfDayWording.dayHours,
            gridlinePositions: []
        ) { hour in
            hour.isFinite ? KeyPathsWording.time(dayStart.addingTimeInterval(hour * 3600), locale: locale) : ""
        }
        return AXChartDescriptor(
            title: "Shifts on the first day",
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: KeyPathsWording.shift, categoryOrder: categories),
            yAxis: yAxis,
            additionalAxes: [],
            series: [
                AXDataSeriesDescriptor(
                    name: CafeWording.shiftStart, isContinuous: false,
                    dataPoints: zip(categories, starts).map { AXDataPoint(x: $0, y: $1) }
                ),
                AXDataSeriesDescriptor(
                    name: CafeWording.shiftEnd, isContinuous: false,
                    dataPoints: zip(categories, ends).map { AXDataPoint(x: $0, y: $1) }
                ),
            ]
        )
    }
}

#Preview("Orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/key-paths") {
            KeyPathsScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    KeyPathsChart(viewModel: KeyPathsViewModel(orders: []))
}
