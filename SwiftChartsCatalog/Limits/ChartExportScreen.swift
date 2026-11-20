import Accessibility
import Charts
import SwiftUI
import UIKit

/// "Exporting an image": `ImageRenderer` on a chart, and the routes a scrolling chart and a 3D chart need.
struct ChartExportScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = ChartExportViewModel()
    @Environment(\.locale) private var locale
    @Environment(\.displayScale) private var displayScale
    /// The window this screen is shown in, read when the window capture runs.
    @State private var sceneAnchor = ChartExportSceneAnchor()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: CafeWording.harbourDaysCaption(locale: locale),
            message: viewModel.headline(locale: locale),
            reservedMessage: viewModel.reservedHeadline(locale: locale),
            explanation: """
            ImageRenderer draws a SwiftUI view into an image, and a plain chart comes out as it is drawn on screen. \
            A scrolling chart comes out with its value axis and grid lines but no bars and no dates: export a static \
            twin, the same marks without the scrolling modifiers and with the x domain fixed to the window in view. \
            A Chart3D comes out as a placeholder: draw it in a window with drawHierarchy, or export a 2D twin of the \
            same data.
            """,
            snippets: ChartExportViewModel.snippets
        ) {
            ChartExportLiveChart(viewModel: viewModel, locale: locale)
        } controls: {
            ChartExportControls(viewModel: viewModel, locale: locale, displayScale: displayScale, sceneAnchor: sceneAnchor)
                .background(ChartExportSceneReader(anchor: sceneAnchor))
            ChartExportResults(results: viewModel.results, isExporting: viewModel.isExporting)
        }
    }
}

// MARK: The chart

/// The bars of a run of days, each one accessibility element, with the busiest days' figures written above them.
struct ChartExportBars: ChartContent {
    let days: [DailySales]
    /// The days whose figure is written above the bar: the busiest in view.
    let labelled: Set<Date>
    let words: ChartExportBarWords

    var body: some ChartContent {
        ForEach(days) { day in
            Plot {
                if labelled.contains(day.day) {
                    bar(day)
                        // The figure the headline names; annotation views are not read, the Plot's value is.
                        // Kept inside the plot: at the largest text sizes it otherwise ran under the value axis.
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .fit(to: .plot))) {
                            Text(day.cups, format: .number)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                } else {
                    bar(day)
                }
            }
            .accessibilityLabel(words.label(day))
            .accessibilityValue(words.value(day))
        }
        .foregroundStyle(.blue)
    }

    private func bar(_ day: DailySales) -> BarMark {
        BarMark(
            x: .value(CafeWording.day, day.day, unit: .day, calendar: words.calendar),
            y: .value(CafeWording.cups, day.cups)
        )
    }
}

/// The axes the live chart and its static twin share: a label under every day (fewer at large text sizes),
/// written in the data's time zone, the month as the x title, and cups on y.
struct ChartExportAxes: ViewModifier {
    let calendar: Calendar
    let locale: Locale
    let cupsAxis: ClosedRange<Double>
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var daysPerLabel: Int {
        dynamicTypeSize >= .accessibility3 ? 2 : 1
    }

    func body(content: Content) -> some View {
        content
            .chartYScale(domain: cupsAxis)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: calendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    // Centred only when every day is labelled.
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).day(),
                        centered: daysPerLabel == 1
                    )
                }
            }
    }
}

/// The chart on screen: four weeks of bars, a week at a time, scrolling sideways.
struct ChartExportLiveChart: View {
    @Bindable var viewModel: ChartExportViewModel
    let locale: Locale
    /// The chart's width once laid out. View-local: it only rebuilds the chart.
    @State private var width: CGFloat = 0

    var body: some View {
        if viewModel.hasData {
            ChartExportScrollingChart(
                days: viewModel.days,
                labelled: Set(viewModel.busiestInView.map(\.day)),
                domain: viewModel.fullDomain,
                cupsAxis: viewModel.cupsAxis,
                words: viewModel.barWords(locale: locale),
                scrollStart: $viewModel.scrollStart
            )
            // Opened on iPhone, the chart is first laid out at another width, and kept its scroll offset in
            // points when the width settled: it drew March 3 to 9 while the position said March 22. A new
            // chart at each width starts again from the bound position.
            .id(width)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        } else {
            ContentUnavailableView(
                "No days to show",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, a week at a time.")
            )
        }
    }
}

/// The scrolling chart, as on screen and as the first export route hands it to `ImageRenderer`.
struct ChartExportScrollingChart: View {
    let days: [DailySales]
    let labelled: Set<Date>
    /// Every day, whole: the scale the visible window moves along.
    let domain: ClosedRange<Date>
    let cupsAxis: ClosedRange<Double>
    let words: ChartExportBarWords
    @Binding var scrollStart: Date

    var body: some View {
        let calendar = words.calendar
        // snippet:exporting-an-image-scrolling
        Chart {
            ChartExportBars(days: days, labelled: labelled, words: words)
        }
        // The whole four weeks; the visible domain is a window onto it.
        .chartXScale(domain: domain)
        .chartScrollableAxes(.horizontal)
        .chartXVisibleDomain(length: ChartExportViewModel.visibleSeconds)
        // Rest on midnight in the data's calendar and time zone (UTC), so whole days.
        .chartScrollTargetBehavior(.valueAligned(
            matching: DateComponents(calendar: calendar, timeZone: calendar.timeZone, hour: 0),
            majorAlignment: .page
        ))
        .chartScrollPosition(x: $scrollStart)
        // end
        .modifier(ChartExportAxes(calendar: calendar, locale: words.locale, cupsAxis: cupsAxis))
        // No axis titles. Seen on iOS 27.0: on screen a scrolling chart drew its y title cut to its first
        // letters and no x title, and in ImageRenderer neither. The caption gives the unit and the headline the dates.
        // A descriptor on the scrolling chart never reached the Audio Graph (it got the default "Chart"), so
        // assistive technologies get a chart of every day that does not scroll, with the descriptor inside it.
        .accessibilityRepresentation {
            ChartExportAccessibleChart(days: days, domain: domain, cupsAxis: cupsAxis, words: words)
        }
    }
}

/// What VoiceOver and the Audio Graph get in place of the scrolling chart: the same bars, every day at once,
/// on the same scales, and the descriptor. Never drawn.
struct ChartExportAccessibleChart: View {
    let days: [DailySales]
    let domain: ClosedRange<Date>
    let cupsAxis: ClosedRange<Double>
    let words: ChartExportBarWords

    var body: some View {
        Chart {
            ChartExportBars(days: days, labelled: [], words: words)
        }
        .chartXScale(domain: domain)
        .chartYScale(domain: cupsAxis)
        // Inside the representation: one left on the drawn chart is lost (`accessibility.md`).
        .accessibilityChartDescriptor(ChartExportChartDescriptor(
            days: days, calendar: words.calendar, cupsAxis: cupsAxis, locale: words.locale
        ))
    }
}

/// The week in view as a chart that does not scroll: what an export draws in place of the scrolling chart.
struct ChartExportStaticTwin: View {
    let days: [DailySales]
    let window: ClosedRange<Date>
    let labelled: Set<Date>
    let cupsAxis: ClosedRange<Double>
    let words: ChartExportBarWords
    /// The x axis title, "March 2026".
    let monthTitle: String

    var body: some View {
        // snippet:exporting-an-image-static-twin
        // The same bars with no scrolling modifiers, only the days in view, and the x domain fixed to the
        // window the scrolling chart shows, widened to whole days so no bar is cut.
        Chart {
            ChartExportBars(days: days, labelled: labelled, words: words)
        }
        .chartXScale(domain: window)
        // end
        .modifier(ChartExportAxes(calendar: words.calendar, locale: words.locale, cupsAxis: cupsAxis))
        .chartXAxisLabel(monthTitle)
        .chartYAxisLabel(CafeWording.cupsAxisTitle, position: .top, alignment: .leading)
    }
}

/// The scrolling chart for the Audio Graph: every day of the four weeks, with its date written out and cups as the unit.
nonisolated struct ChartExportChartDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let calendar: Calendar
    /// The value axis as drawn: the chart sets the same domain.
    let cupsAxis: ClosedRange<Double>
    let locale: Locale

    func dayName(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone).month(.wide).day())
    }

    var summary: String {
        guard let first = days.first, let last = days.last,
              let lowest = days.min(by: { $0.cups < $1.cups }), let highest = days.max(by: { $0.cups < $1.cups })
        else { return "No days." }
        return "\(CafeWording.days(days.count, locale: locale)), \(dayName(first.day)) to \(dayName(last.day)). "
            + "Fewest: \(CafeWording.cups(lowest.cups, locale: locale)) on \(dayName(lowest.day)). "
            + "Most: \(CafeWording.cups(highest.cups, locale: locale)) on \(dayName(highest.day))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: days.map { dayName($0.day) })
        let yAxis = AXNumericDataAxisDescriptor(title: CafeWording.cupsAxisTitle, range: cupsAxis, gridlinePositions: []) { value in
            CafeWording.count(value, locale: locale)
        }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: days.map { AXDataPoint(x: dayName($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups a day at the Harbour café",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: The bean charts, drawn only to be exported

/// The 3D chart the 3D routes export: 60 bean samples, one solid and colour per origin.
@available(iOS 26, *)
struct ChartExportBeans3D: View {
    let beans: [BeanTasting]

    var body: some View {
        Chart3D(beans) { bean in
            PointMark(
                x: .value(ChartExportWording.acidity, bean.acidity),
                y: .value(ChartExportWording.body, bean.body),
                z: .value(ChartExportWording.sweetness, bean.sweetness)
            )
            .symbol(BeanOriginStyle.solid(for: bean.origin).chartSymbol)
            .symbolSize(ChartExportBeanSize.size(for: BeanOriginStyle.solid(for: bean.origin)))
            // No legend in 3D: colours come from the one table the 2D twin's legend reads.
            .foregroundStyle(BeanOriginStyle.colour(for: bean.origin))
        }
        .chartXAxisLabel(ChartExportWording.acidity)
        .chartYAxisLabel(ChartExportWording.body)
        .chartZAxisLabel(ChartExportWording.sweetness)
        .chartXScale(domain: 0 ... 10, range: -0.5 ... 0.5)
        .chartYScale(domain: 0 ... 10, range: -0.5 ... 0.5)
        .chartZScale(domain: 0 ... 10, range: -0.5 ... 0.5)
        .accessibilityIdentifier("press-target")
    }
}

/// Sizes that look alike for the three solids (`chart3d.md`: sphere 0.57, cube 1, cone 1.75 times the cube's value).
nonisolated enum ChartExportBeanSize {
    static let cube = 0.04

    static func size(for solid: BeanOriginSolid) -> Double {
        switch solid {
        case .sphere: cube * 0.57
        case .cube, .cylinder: cube
        case .cone: cube * 1.75
        }
    }
}

/// The 2D twin of the 3D chart: acidity across, body up, which is the pose that separates the origins.
struct ChartExportBeansFlat: View {
    let beans: [BeanTasting]

    var body: some View {
        Chart(beans) { bean in
            PointMark(
                x: .value(ChartExportWording.acidity, bean.acidity),
                y: .value(ChartExportWording.body, bean.body)
            )
            .foregroundStyle(by: .value(ChartExportWording.origin, bean.origin))
            .symbol(by: .value(ChartExportWording.origin, bean.origin))
        }
        .chartForegroundStyleScale(domain: BeanOriginStyle.origins) { BeanOriginStyle.colour(for: $0) }
        .chartSymbolScale(domain: BeanOriginStyle.origins) { BeanOriginStyle.chartSymbol(for: $0) }
        .chartXScale(domain: 0 ... 10)
        .chartYScale(domain: 0 ... 10)
        .chartXAxisLabel(ChartExportWording.acidity)
        .chartYAxisLabel(ChartExportWording.body, position: .top, alignment: .leading)
    }
}

// MARK: Exporting

/// The two ways the screen turns a view into an image. Neither writes a file: the image stays in memory.
@MainActor
enum ChartExportRenderer {
    /// The size every export is drawn at, in points.
    static let size = CGSize(width: 340, height: 240)

    // snippet:exporting-an-image-renderer
    /// Draws a chart into an image with `ImageRenderer`, at the screen's scale. The renderer takes none of
    /// the screen's environment, so the locale is passed in and set on the card.
    static func render(_ chart: some View, size: CGSize, scale: CGFloat, locale: Locale) -> UIImage? {
        let renderer = ImageRenderer(content: ChartExportCard(size: size, locale: locale) { chart })
        renderer.scale = scale
        return renderer.uiImage
    }

    // end

    // snippet:exporting-an-image-window-capture
    /// Draws a view hosted in a window of this app with `drawHierarchy`: the route a `Chart3D` needs,
    /// since `ImageRenderer` draws it as a placeholder. The window is made in the scene of the screen that
    /// asked, and sits behind that screen's own window.
    static func captureInWindow(_ chart: some View, size: CGSize, locale: Locale, in scene: UIWindowScene) async -> UIImage? {
        let host = UIHostingController(rootView: ChartExportCard(size: size, locale: locale) { chart })
        host.safeAreaRegions = []
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(origin: .zero, size: size)
        window.windowLevel = UIWindow.Level(rawValue: UIWindow.Level.normal.rawValue - 1)
        window.rootViewController = host
        window.isHidden = false
        defer { window.isHidden = true }
        // Let the 3D content draw before it is captured.
        try? await Task.sleep(for: ChartExportTiming.settle)
        let format = UIGraphicsImageRendererFormat(for: scene.traitCollection)
        return UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
    }

    // end

    /// Every route, in order. The 3D routes run only where `Chart3D` exists.
    static func exportAll(
        viewModel: ChartExportViewModel, locale: Locale, scale: CGFloat, scene: UIWindowScene?
    ) async -> [ChartExportResult] {
        let labelled = Set(viewModel.busiestInView.map(\.day))
        let words = viewModel.barWords(locale: locale)
        let scrolling = ChartExportScrollingChart(
            days: viewModel.days, labelled: labelled, domain: viewModel.fullDomain, cupsAxis: viewModel.cupsAxis,
            words: words, scrollStart: .constant(viewModel.scrollStart)
        )
        let twin = ChartExportStaticTwin(
            days: viewModel.daysInView, window: viewModel.twinDomain, labelled: labelled,
            cupsAxis: viewModel.cupsAxis, words: words, monthTitle: viewModel.monthTitle(locale: locale)
        )
        var results = [
            ChartExportResult(route: .scrollingChart, outcome: outcome(render(scrolling, size: size, scale: scale, locale: locale))),
            ChartExportResult(route: .staticTwin, outcome: outcome(render(twin, size: size, scale: scale, locale: locale))),
        ]
        // snippet:exporting-an-image-3d-routes
        if #available(iOS 26, *) {
            let chart3D = ChartExportBeans3D(beans: CafeData.beanTastings)
            results.append(ChartExportResult(route: .chart3DRenderer, outcome: outcome(render(chart3D, size: size, scale: scale, locale: locale))))
            if let scene {
                let captured = await captureInWindow(chart3D, size: size, locale: locale, in: scene)
                results.append(ChartExportResult(route: .chart3DWindow, outcome: outcome(captured)))
            } else {
                results.append(ChartExportResult(route: .chart3DWindow, outcome: .failed))
            }
        } else {
            let reason = "Chart3D needs iOS 26. This system has no 3D chart to export."
            results.append(ChartExportResult(route: .chart3DRenderer, outcome: .unavailable(reason)))
            results.append(ChartExportResult(route: .chart3DWindow, outcome: .unavailable(reason)))
        }
        // end
        let flat = ChartExportBeansFlat(beans: CafeData.beanTastings)
        results.append(ChartExportResult(route: .flatTwin3D, outcome: outcome(render(flat, size: size, scale: scale, locale: locale))))
        return results
    }

    private static func outcome(_ image: UIImage?) -> ChartExportOutcome {
        image.map { .image($0) } ?? .failed
    }
}

/// How long the window capture waits for a 3D chart to draw.
enum ChartExportTiming {
    static let settle = Duration.milliseconds(600)
}

/// The card every export is drawn on: a fixed size, padding and a light background, so an image reads on its own,
/// in the screen's locale, which `ImageRenderer` would not otherwise use.
struct ChartExportCard<Content: View>: View {
    let size: CGSize
    let locale: Locale
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(Layout.panelPadding)
            .frame(width: size.width, height: size.height)
            .background(.white)
            .environment(\.colorScheme, .light)
            .environment(\.locale, locale)
    }
}

/// Holds the view the export controls sit on, so the window capture can read the scene it is shown in
/// when it runs, rather than remember one.
final class ChartExportSceneAnchor {
    weak var view: UIView?

    var scene: UIWindowScene? {
        view?.window?.windowScene
    }
}

/// An empty view placed behind the controls, which hands itself to the anchor.
struct ChartExportSceneReader: UIViewRepresentable {
    let anchor: ChartExportSceneAnchor

    func makeUIView(context _: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        anchor.view = view
        return view
    }

    func updateUIView(_ view: UIView, context _: Context) {
        anchor.view = view
    }
}

// MARK: Controls and results

/// The export button.
struct ChartExportControls: View {
    let viewModel: ChartExportViewModel
    let locale: Locale
    let displayScale: CGFloat
    let sceneAnchor: ChartExportSceneAnchor

    var body: some View {
        ControlsSection {
            HStack(spacing: Layout.itemSpacing) {
                Button("Export", systemImage: "square.and.arrow.down") {
                    Task { await export() }
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.hasData || viewModel.isExporting)
                if viewModel.isExporting {
                    ProgressView()
                }
            }
            Text("Tries every route on the week in view and on a 3D chart of bean scores, and shows each image below.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func export() async {
        viewModel.beginExport()
        let results = await ChartExportRenderer.exportAll(
            viewModel: viewModel, locale: locale, scale: displayScale, scene: sceneAnchor.scene
        )
        viewModel.finishExport(results)
        AccessibilityNotification.Announcement(viewModel.exportAnnouncement(locale: locale)).post()
    }
}

/// One tile per route: what it does, the image it made, and what it made when the screen was built.
struct ChartExportResults: View {
    let results: [ChartExportResult]
    let isExporting: Bool

    var body: some View {
        if !results.isEmpty {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                ForEach(results) { result in
                    ChartExportResultTile(result: result)
                }
            }
        } else if !isExporting {
            Text("Press Export to see what each route makes.")
                .foregroundStyle(.secondary)
        }
    }
}

struct ChartExportResultTile: View {
    let result: ChartExportResult

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text(result.route.title)
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text(result.route.method)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            switch result.outcome {
            case let .image(image):
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(.rect(cornerRadius: Layout.badgeCornerRadius))
                    .overlay {
                        RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                            .strokeBorder(Color(.separator))
                    }
                    .accessibilityLabel(result.imageDescription)
                Text(result.route.seenWhenBuilt)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                if result.route.givesTheChart {
                    // snippet:exporting-an-image-share
                    ShareLink(
                        item: Image(uiImage: image),
                        preview: SharePreview(result.route.title, image: Image(uiImage: image))
                    )
                    // end
                }
            case let .unavailable(reason):
                Text(reason)
                    .font(.footnote)
            case .failed:
                Text(result.imageDescription)
                    .font(.footnote)
            }
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

#Preview("Exporting an image") {
    NavigationStack {
        if let screen = Catalog.screen(id: "limits-and-escape-hatches/exporting-an-image") {
            ChartExportScreen(screen: screen)
        }
    }
}

#Preview("No days") {
    ChartExportLiveChart(viewModel: ChartExportViewModel(days: []), locale: .current)
        .frame(height: Layout.chartHeightCompact)
}
