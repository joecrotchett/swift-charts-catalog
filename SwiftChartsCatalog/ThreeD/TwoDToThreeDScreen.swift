import Accessibility
import Charts
import Spatial
import SwiftUI

/// "From 2D to 3D": three 2D scatter plots of the same bean tastings, then the one 3D chart that holds all three.
struct TwoDToThreeDScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: TwoDToThreeDViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers the way the axes do.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, beans: [BeanTasting] = CafeData.beanTastings, chart: TwoDToThreeDChart = .acidityBody) {
        self.screen = screen
        let model = TwoDToThreeDViewModel(beans: beans)
        model.chart = chart
        _viewModel = State(initialValue: model)
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean tastings, each score from 0 to 10",
            message: summary.headline(for: viewModel.chart),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            TwoDToThreeDPanel(viewModel: viewModel, locale: locale)
        } controls: {
            TwoDToThreeDControls(viewModel: viewModel, locale: locale)
        }
        .onChange(of: viewModel.chart) { _, chart in
            // A different chart is a change to what is drawn: say what changed, then the headline.
            AccessibilityNotification.Announcement(summary.announcement(for: chart)).post()
        }
    }
}

/// The chart panel's content: a placeholder with no data, otherwise the chart chosen and the legend.
struct TwoDToThreeDPanel: View {
    let viewModel: TwoDToThreeDViewModel
    let locale: Locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        if viewModel.isEmpty {
            ContentUnavailableView(
                "No tastings yet",
                systemImage: "cup.and.saucer",
                description: Text("Each sample's acidity, body and sweetness appear here, one point per sample.")
            )
        } else {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                if viewModel.chart == .threeD {
                    TwoDToThreeDThreeDSlot(viewModel: viewModel, locale: locale)
                } else {
                    TwoDToThreeDScatter(summary: summary, chart: viewModel.chart)
                }
                TwoDToThreeDLegend(origins: summary.origins, isThreeD: viewModel.chart == .threeD)
            }
        }
    }
}

/// Where the 3D chart goes: behind the availability check, with a fallback that says what is missing.
struct TwoDToThreeDThreeDSlot: View {
    let viewModel: TwoDToThreeDViewModel
    let locale: Locale

    var body: some View {
        // snippet:from-2d-to-3d-gate
        // Chart3D and Chart3DPose are iOS 26. The app runs on iOS 18, so the 3D chart, and the pose
        // it keeps as state, live in a view marked @available, reached only through this check.
        if #available(iOS 26, *) {
            TwoDToThreeDChart3DView(
                beans: viewModel.beans, viewpoint: viewModel.viewpoint, opening: viewModel.openingViewpoint,
                locale: locale, poseChanged: viewModel.poseChanged(toMatch:)
            )
        } else {
            ContentUnavailableView(
                "3D charts need iOS 26",
                systemImage: "cube",
                description: Text("The three 2D charts show the same scores, two at a time.")
            )
        }
        // end
    }
}

/// One of the three 2D scatter plots: two scores, one point per sample, the origins told apart by colour and shape.
struct TwoDToThreeDScatter: View {
    let summary: TwoDToThreeDSummary
    let chart: TwoDToThreeDChart
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // snippet:from-2d-to-3d-scatter
        Chart {
            ForEach(summary.clusters, id: \.origin) { cluster in
                TwoDToThreeDOriginPoints(
                    cluster: cluster, beans: summary.beans(from: cluster.origin), chart: chart, summary: summary
                )
            }
        }
        .chartXAxisLabel(chart.xScore.name)
        .yAxisTitle(chart.yScore.name)
        // Scores run from 0 to 10 whatever the data, so every chart shares that one domain.
        .chartXScale(domain: TwoDToThreeDScore.domain)
        .chartYScale(domain: TwoDToThreeDScore.domain)
        // end
        // Each origin's colour and symbol come from the app's one table for the bean origins.
        .chartForegroundStyleScale(domain: summary.origins, mapping: BeanOriginStyle.colour(for:))
        .chartSymbolScale(domain: summary.origins, mapping: BeanOriginStyle.chartSymbol(for:))
        // The screen draws one legend for all four charts, since the 3D chart draws none.
        .chartLegend(.hidden)
        .chartXAxis { scoreAxis }
        .chartYAxis { scoreAxis }
        .accessibilityChartDescriptor(TwoDToThreeDDescriptor(beans: summary.beans, chart: chart, locale: summary.locale))
        // The origins' ids stay the same from one pair to the next, so a new identity makes VoiceOver and the
        // Audio Graph read the new element text and descriptor.
        .id(chart)
    }

    /// A grid line at every whole score, with fewer labels as the text grows. Both axes share it.
    @AxisContentBuilder private var scoreAxis: some AxisContent {
        let labelled = TwoDToThreeDAxis.labelledValues(at: dynamicTypeSize)
        AxisMarks(values: TwoDToThreeDAxis.gridValues) { value in
            AxisGridLine()
            AxisTick()
            if let score = value.as(Double.self), labelled.contains(score) {
                AxisValueLabel()
            }
        }
    }
}

// snippet:from-2d-to-3d-elements
/// One origin's points in one labelled Plot: one accessibility element per origin, since the chart is about
/// where the clusters lie, not each sample. The 3D chart gives assistive technologies nothing, so its
/// accessibilityRepresentation is a 2D chart of these same elements, each carrying all three scores.
struct TwoDToThreeDOriginPoints: ChartContent {
    let cluster: TwoDToThreeDCluster
    let beans: [BeanTasting]
    let chart: TwoDToThreeDChart
    let summary: TwoDToThreeDSummary

    var body: some ChartContent {
        Plot {
            ForEach(beans) { bean in
                PointMark(
                    x: .value(chart.xScore.name, chart.xScore.value(of: bean)),
                    y: .value(chart.yScore.name, chart.yScore.value(of: bean))
                )
            }
            .foregroundStyle(by: .value(TwoDToThreeDWording.origin, cluster.origin))
            .symbol(by: .value(TwoDToThreeDWording.origin, cluster.origin))
        }
        .accessibilityLabel(summary.elementLabel(for: cluster))
        .accessibilityValue(summary.elementValue(for: cluster, chart: chart))
    }
}

// end

/// The 3D chart: acidity across, body up, sweetness in depth.
@available(iOS 26, *)
struct TwoDToThreeDChart3DView: View {
    let beans: [BeanTasting]
    let viewpoint: TwoDToThreeDViewpoint?
    let locale: Locale
    let poseChanged: (TwoDToThreeDViewpoint?) -> Void
    @Environment(\.colorScheme) private var colorScheme
    /// The angle the chart is seen from. It changes as people drag the chart, and when the viewpoint control does.
    /// It starts at the viewpoint the control shows, so the two agree after a visit to a 2D chart.
    @State private var pose: Chart3DPose

    init(
        beans: [BeanTasting], viewpoint: TwoDToThreeDViewpoint?, opening: TwoDToThreeDViewpoint, locale: Locale,
        poseChanged: @escaping (TwoDToThreeDViewpoint?) -> Void
    ) {
        self.beans = beans
        self.viewpoint = viewpoint
        self.locale = locale
        self.poseChanged = poseChanged
        _pose = State(initialValue: Self.openingPose(for: opening))
    }

    /// The pose the view is made with: the viewpoint the control shows.
    static func openingPose(for viewpoint: TwoDToThreeDViewpoint) -> Chart3DPose {
        viewpoint.pose
    }

    var body: some View {
        let summary = TwoDToThreeDSummary(beans: beans, locale: locale)
        // snippet:from-2d-to-3d-chart3d
        // Chart becomes Chart3D.
        Chart3D(beans) { bean in
            PointMark(
                x: .value(TwoDToThreeDWording.acidity, bean.acidity),
                y: .value(TwoDToThreeDWording.body, bean.body),
                // Each PointMark gains a z.
                z: .value(TwoDToThreeDWording.sweetness, bean.sweetness)
            )
            // Seen on iOS: with foregroundStyle(by:), Chart3D did not take the colours of a
            // chartForegroundStyleScale mapping, and it draws no legend; and 3D has no symbol(by:).
            // So each origin's colour and solid are set per point, from the table the legend reads.
            .foregroundStyle(BeanOriginStyle.colour(for: bean.origin))
            .symbol(BeanOriginStyle.solid(for: bean.origin).chartSymbol)
            // Left to themselves, cubes and cones drew far smaller than spheres.
            .symbolSize(TwoDToThreeDMetrics.solidSize)
        }
        .chartXAxisLabel(TwoDToThreeDWording.acidity)
        .chartYAxisLabel(TwoDToThreeDWording.body)
        // The z axis gets a label.
        .chartZAxisLabel(TwoDToThreeDWording.sweetness)
        // The domain is in scores; the range of -0.5 ... 0.5 makes the chart a cube centred in its view.
        .chartXScale(domain: TwoDToThreeDScore.domain, range: -0.5 ... 0.5)
        .chartYScale(domain: TwoDToThreeDScore.domain, range: -0.5 ... 0.5)
        .chartZScale(domain: TwoDToThreeDScore.domain, range: -0.5 ... 0.5)
        // end
        // snippet:from-2d-to-3d-pose
        .chart3DPose($pose)
        // The control sets the pose; a drag changes it. What goes back to the model is the viewpoint the
        // pose now matches, or none, so the control shows no face once the chart has been turned by hand.
        .onChange(of: viewpoint) { _, chosen in
            if let chosen, pose != chosen.pose {
                withAnimation { pose = chosen.pose }
            }
        }
        .onChange(of: pose) { _, newPose in
            poseChanged(TwoDToThreeDViewpoint.allCases.first { $0.pose == newPose })
        }
        // end
        .accessibilityIdentifier("press-target")
        // A Chart3D gives assistive technologies no elements and no Audio Graph, so they get a 2D chart of the
        // same samples instead, never drawn, with the descriptor inside it.
        .accessibilityRepresentation {
            Chart {
                ForEach(summary.clusters, id: \.origin) { cluster in
                    TwoDToThreeDOriginPoints(
                        cluster: cluster, beans: summary.beans(from: cluster.origin), chart: .threeD, summary: summary
                    )
                }
            }
            .chartXScale(domain: TwoDToThreeDScore.domain)
            .chartYScale(domain: TwoDToThreeDScore.domain)
            .accessibilityChartDescriptor(TwoDToThreeDDescriptor(beans: beans, chart: .threeD, locale: locale))
            .accessibilityIdentifier("press-target")
        }
        // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
        // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The pose is
        // this view's state, outside the identity, so it survives.
        .id(colorScheme)
    }
}

@available(iOS 26, *)
extension TwoDToThreeDViewpoint {
    /// The pose for each viewpoint. Front looks along z, so acidity runs across and body up, as in the first
    /// 2D chart; read on iOS, the left side has sweetness rising to the right, and the view from
    /// below has acidity across and sweetness up the screen; `.right` and `.top` show them reversed.
    var pose: Chart3DPose {
        switch self {
        case .angle: Chart3DPose(azimuth: .degrees(TwoDToThreeDMetrics.openingAzimuth), inclination: .degrees(TwoDToThreeDMetrics.openingInclination))
        case .front: .front
        case .side: .left
        case .below: .bottom
        }
    }
}

/// The constants that belong to this screen's charts.
private nonisolated enum TwoDToThreeDMetrics {
    /// The opening pose: turned and tilted enough that the three clusters stand apart and the rise of
    /// sweetness with body shows, rather than one face seen straight on.
    static let openingAzimuth: Double = 35
    static let openingInclination: Double = 20
    /// The size of each 3D solid, in the chart's own units, where the cube is 1 across.
    static let solidSize: CGFloat = 0.035
}

/// Which values the 2D axes mark.
nonisolated enum TwoDToThreeDAxis {
    /// A grid line at every whole score, so each whole number in the headline lies on one.
    static let gridValues: [Double] = Array(stride(from: 0, through: 10, by: 1))

    /// Labels at every second score, and at 0, 5 and 10 once the text is large enough to crowd them.
    static func labelledValues(at size: DynamicTypeSize) -> [Double] {
        size >= .accessibility1 ? [0, 5, 10] : [0, 2, 4, 6, 8, 10]
    }
}

/// The legend for all four charts, drawn by the screen: the 3D chart draws none, and the 2D charts hide theirs
/// so the four look the same. It wraps to a column when a row does not fit.
struct TwoDToThreeDLegend: View {
    let origins: [String]
    let isThreeD: Bool

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Layout.sectionSpacing) {
                TwoDToThreeDLegendEntries(origins: origins, isThreeD: isThreeD)
            }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                TwoDToThreeDLegendEntries(origins: origins, isThreeD: isThreeD)
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        // VoiceOver hears each origin's name in its element's label, so the legend would only repeat it.
        .accessibilityHidden(true)
    }
}

/// One entry per origin: its symbol in its colour, and its name, with the 3D solid named in 3D.
struct TwoDToThreeDLegendEntries: View {
    let origins: [String]
    let isThreeD: Bool

    var body: some View {
        ForEach(origins, id: \.self) { origin in
            Label {
                Text(isThreeD ? "\(origin), \(BeanOriginStyle.solid(for: origin).pluralName)" : origin)
            } icon: {
                Image(systemName: BeanOriginStyle.symbolName(for: origin))
                    .foregroundStyle(BeanOriginStyle.colour(for: origin))
            }
        }
    }
}

/// The picker that chooses the chart, and in 3D the control that turns it to each face.
struct TwoDToThreeDControls: View {
    @Bindable var viewModel: TwoDToThreeDViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Chart: across × up (acidity, body, sweetness)", selection: $viewModel.chart) {
                ForEach(TwoDToThreeDChart.allCases) { chart in
                    // Each segment is named in full: "A × B" alone is read "A times B".
                    Text(chart.title)
                        .accessibilityLabel(chart.spokenTitle)
                        .tag(chart)
                }
            }
            .disabled(viewModel.isEmpty)
            if viewModel.chart == .threeD {
                if #available(iOS 26, *) {
                    TwoDToThreeDViewpointPicker(viewModel: viewModel, locale: locale)
                }
            }
        }
    }
}

/// Turns the 3D chart without a drag: each face is one of the 2D charts.
struct TwoDToThreeDViewpointPicker: View {
    let viewModel: TwoDToThreeDViewModel
    let locale: Locale

    var body: some View {
        let selection = Binding<TwoDToThreeDViewpoint?>(
            get: { viewModel.viewpoint },
            set: { chosen in
                viewModel.viewpoint = chosen
                if let chosen {
                    AccessibilityNotification.Announcement(viewModel.summary(locale: locale).announcement(for: chosen)).post()
                }
            }
        )
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            LabeledSegmentedPicker(title: "Turn the 3D chart to", selection: selection) {
                ForEach(TwoDToThreeDViewpoint.allCases, id: \.self) { viewpoint in
                    Text(viewpoint.title).tag(Optional(viewpoint))
                }
            }
            .disabled(viewModel.isEmpty)
            Text(viewModel.viewpoint == nil ? "Turned by hand. Choose a face to line it up again." : "Or drag the chart to turn it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("Tastings") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/from-2d-to-3d") {
            TwoDToThreeDScreen(screen: screen)
        }
    }
}

#Preview("3D") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/from-2d-to-3d") {
            TwoDToThreeDScreen(screen: screen, chart: .threeD)
        }
    }
}

#Preview("No tastings") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/from-2d-to-3d") {
            TwoDToThreeDScreen(screen: screen, beans: [])
        }
    }
}
