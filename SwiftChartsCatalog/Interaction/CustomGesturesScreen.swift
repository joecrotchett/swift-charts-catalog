import Accessibility
import Charts
import SwiftUI

/// "Custom gestures": replacing the chart's selection gesture with a tap through `chartGesture` and
/// `ChartProxy.selectXValue(at:)`, beside a tap in `chartOverlay` that converts the position itself.
struct CustomGesturesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: CustomGesturesViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DailySales] = CafeData.harbourSales) {
        self.screen = screen
        _viewModel = State(initialValue: CustomGesturesViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: CustomGesturesWording.caption,
            message: viewModel.headline(locale: locale),
            reservedMessage: viewModel.reservedHeadline(locale: locale),
            explanation: """
            chartXSelection brings its own gesture: on iOS, touch and hold. chartGesture replaces that gesture; \
            here a tap calls the proxy's selectXValue(at:), and the date arrives through the same binding, so the \
            band and the headline are written once. A tap on a clear view in chartOverlay instead converts the \
            position itself with value(atX:) and sets the selection directly: the way to select on iOS 16, or to \
            handle anything that is not selection. On iOS 17 and later, prefer chartGesture for selection.
            """,
            snippets: viewModel.mode.snippets
        ) {
            CustomGesturesChart(viewModel: viewModel, locale: locale)
        } controls: {
            CustomGesturesControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The words the screen shares between what is shown and what is spoken.
private enum CustomGesturesWording {
    static let caption = "Cups sold each day at the \(CafeWording.harbour) café"
    static let selectedDay = "Selected day"
}

/// The name of the chart's own coordinate space, in which the tap and the plot's origin are both measured.
private enum CustomGesturesSpace {
    static let chart = "custom-gestures-chart"
}

/// The mode picker and what to do in the mode chosen.
private struct CustomGesturesControls: View {
    @Bindable var viewModel: CustomGesturesViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Gesture", selection: modeSelection) {
                ForEach(CustomGesturesMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            // With nothing drawn there is nothing to select, and nothing to say how to select it.
            .disabled(!viewModel.hasData)
            if viewModel.hasData {
                Text(viewModel.mode.instruction)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Changing the mode clears a selection; when that changes the headline, it is said aloud.
    private var modeSelection: Binding<CustomGesturesMode> {
        Binding {
            viewModel.mode
        } set: { mode in
            let hadSelection = viewModel.selectedDay != nil
            viewModel.mode = mode
            if let message = viewModel.modeChangeAnnouncement(clearedSelection: hadSelection, locale: locale) {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }
}

/// The bars, the band behind the selected day, and the gesture for the current mode.
private struct CustomGesturesChart: View {
    let viewModel: CustomGesturesViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer date labels at the accessibility text sizes, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility1 ? 14 : 7
    }

    var body: some View {
        if viewModel.hasData {
            // Read here, in the body, so a change of selection redraws the band.
            let selectedDay = viewModel.selectedDay
            let calendar = viewModel.calendar
            Chart {
                // snippet:custom-gestures-band
                if let selectedDay {
                    // Declared first, so it sits behind the bars. Decoration: the bar already describes the day.
                    RectangleMark(
                        x: .value(CustomGesturesWording.selectedDay, selectedDay.day, unit: .day, calendar: calendar),
                        width: .ratio(1)
                    )
                    .foregroundStyle(Color.gray.opacity(CustomGesturesStyle.bandOpacity))
                    .accessibilityHidden(true)
                }
                // end
                ForEach(viewModel.sales) { day in
                    Plot {
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                    }
                    .accessibilityLabel(viewModel.spokenDay(day.day, locale: locale))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                            .month(.abbreviated).day()
                    )
                }
            }
            // One value axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartYScale(domain: CustomGesturesChartDescriptor.valueDomain(for: viewModel.sales))
            .modifier(CustomGesturesSelection(viewModel: viewModel))
            .accessibilityChartDescriptor(CustomGesturesChartDescriptor(
                sales: viewModel.sales,
                summary: viewModel.audioGraphSummary(locale: locale),
                categories: viewModel.sales.map { viewModel.spokenDay($0.day, locale: locale) },
                locale: locale
            ))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        }
    }
}

/// Constants that belong to this chart's marks.
private enum CustomGesturesStyle {
    static let bandOpacity = 0.25
}

/// Puts the gesture for the current mode on the chart. Each branch is a different chart: the built-in
/// gesture, the built-in selection driven by a tap, or no selection modifier and a tap in an overlay.
private struct CustomGesturesSelection: ViewModifier {
    @Bindable var viewModel: CustomGesturesViewModel

    func body(content: Content) -> some View {
        switch viewModel.mode {
        case .builtInDrag:
            // snippet:custom-gestures-built-in
            content
                // The framework's gesture: on iOS, touch and hold, then drag. Lifting the finger sets it back to nil.
                .chartXSelection(value: $viewModel.rawSelection)
        // end
        case .tapToSelect:
            // snippet:custom-gestures-tap
            content
                .chartXSelection(value: $viewModel.rawSelection)
                // Replaces the built-in gesture. The date still arrives through the binding above.
                .chartGesture { proxy in
                    SpatialTapGesture(coordinateSpace: .named(CustomGesturesSpace.chart))
                        .onEnded { tap in
                            // selectXValue(at:) measures from the plot area, as value(atX:) does, so the tap,
                            // measured in the chart's space, has the plot's origin taken off first.
                            if let position = CustomGesturesViewModel.plotPosition(
                                of: tap.location, plotOrigin: viewModel.plotOrigin, plotSize: proxy.plotSize
                            ) {
                                proxy.selectXValue(at: position.x)
                            } else {
                                viewModel.clearSelection()
                            }
                        }
                }
                // end
                // snippet:custom-gestures-plot-origin
                .chartBackground { proxy in
                    GeometryReader { geometry in
                        // The plot's corner in the chart's space: zero in left to right, where the value
                        // axis is on the trailing edge, and the axis's width in right to left.
                        let reader = geometry.frame(in: .named(CustomGesturesSpace.chart))
                        let plot = proxy.plotFrame.map { geometry[$0] } ?? .zero
                        let origin = CGPoint(x: reader.minX + plot.minX, y: reader.minY + plot.minY)
                        Color.clear
                            .onChange(of: origin, initial: true) { viewModel.plotOrigin = origin }
                    }
                }
                .coordinateSpace(.named(CustomGesturesSpace.chart))
        // end
        case .overlay:
            // snippet:custom-gestures-overlay
            content
                .chartOverlay { proxy in
                    GeometryReader { geometry in
                        // Clear but hit-testable, over the whole chart.
                        Rectangle().fill(.clear).contentShape(Rectangle())
                            .gesture(
                                SpatialTapGesture()
                                    .onEnded { tap in
                                        guard let plotFrame = proxy.plotFrame else { return }
                                        let plot = geometry[plotFrame]
                                        // Take off the plot's origin, and reject a tap outside the plot:
                                        // a date scale would still answer, with a date beyond the data.
                                        if let position = CustomGesturesViewModel.plotPosition(
                                            of: tap.location, plotOrigin: plot.origin, plotSize: plot.size
                                        ) {
                                            viewModel.rawSelection = proxy.value(atX: position.x, as: Date.self)
                                        } else {
                                            viewModel.clearSelection()
                                        }
                                    }
                            )
                            // Not an element: the bars beneath carry the values.
                            .accessibilityHidden(true)
                    }
                }
            // end
        }
    }
}

/// The chart for the Audio Graph: written-out days, cups with their unit, one series of separate bars.
nonisolated struct CustomGesturesChartDescriptor: AXChartDescriptorRepresentable {
    let sales: [DailySales]
    let summary: String
    /// Each day written out, in data order.
    let categories: [String]
    let locale: Locale

    /// The value axis as drawn and as given here: 0 to the most cups, rounded up to a tidy step.
    static func valueDomain(for sales: [DailySales]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: categories)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: Self.valueDomain(for: sales),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: zip(categories, sales).map { AXDataPoint(x: $0, y: Double($1.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold each day at the \(CafeWording.harbour) café",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Custom gestures") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/custom-gestures") {
            CustomGesturesScreen(screen: screen)
        }
    }
}

#Preview("Right to left") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/custom-gestures") {
            CustomGesturesScreen(screen: screen)
        }
    }
    .environment(\.layoutDirection, .rightToLeft)
}

#Preview("No sales") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/custom-gestures") {
            CustomGesturesScreen(screen: screen, sales: [])
        }
    }
}
