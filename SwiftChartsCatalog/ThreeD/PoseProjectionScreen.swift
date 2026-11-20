import Accessibility
import Charts
import SwiftUI

/// "Pose and projection": the same bean tastings seen from the angle that shows the clusters and from the
/// angle that shows the trend, and drawn orthographic or in perspective.
struct PoseProjectionScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = PoseProjectionViewModel()
    @Environment(\.locale) private var locale

    /// Whether this system can draw a 3D chart. Below iOS 26 a placeholder replaces it, and the controls
    /// that would change it are disabled.
    private var drawsChart: Bool {
        if #available(iOS 26.0, *) { true } else { false }
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean tastings, scored 0 to 10",
            message: drawsChart ? viewModel.headline(locale: locale) : "3D charts need iOS 26.",
            reservedMessage: viewModel.reservedHeadline(locale: locale),
            explanation: """
            A 3D chart shows two scores at a time when seen straight on, so the angle it opens at decides what \
            people see first. From the front these beans fall into three clusters by origin; from the side the \
            same points line up, because sweetness rises with body. Drag the chart to turn it: the sliders follow.
            """,
            snippets: viewModel.snippets
        ) {
            PoseProjectionChartArea(viewModel: viewModel, locale: locale)
        } controls: {
            PoseProjectionControls(viewModel: viewModel, locale: locale)
                .disabled(!drawsChart)
        }
    }
}

/// The chart and its key, or on an older system a placeholder saying what is missing.
struct PoseProjectionChartArea: View {
    let viewModel: PoseProjectionViewModel
    let locale: Locale

    var body: some View {
        // snippet:pose-and-projection-gate
        // Chart3D and Chart3DPose are iOS 26. The app runs on iOS 18, so the chart, and the pose it keeps
        // as state, live in a view marked @available, reached only through this check.
        if #available(iOS 26, *) {
            PoseProjectionChart(viewModel: viewModel, locale: locale)
        } else {
            PoseProjectionUnavailable()
        }
        // end
    }
}

/// What people on iOS 18 to 25 see in place of the chart.
struct PoseProjectionUnavailable: View {
    var body: some View {
        ContentUnavailableView(
            "3D charts need iOS 26",
            systemImage: "cube.transparent",
            description: Text("This chart turns in three dimensions with Chart3D, which arrived in iOS 26. On this system the screen shows its code only.")
        )
    }
}

/// Constants that belong to this chart's marks.
private enum PoseProjectionMetrics {
    /// The 3D symbol size, as a fraction of the chart's box.
    static let symbolSize: CGFloat = 0.04
    /// The edge of the chart's box, as `chart3d.md` sets every axis: a cube centred in the view.
    static let boxRange: ClosedRange<CGFloat> = -0.5 ... 0.5
    static let axisValues: [Double] = [0, 2, 4, 6, 8, 10]
}

/// The 3D chart. Its pose and the view model's angles are kept the same both ways: a slider or preset
/// sets the pose, and a drag that rotates the chart writes the pose's angles back to the sliders.
@available(iOS 26, *)
struct PoseProjectionChart: View {
    let viewModel: PoseProjectionViewModel
    let locale: Locale
    @State private var pose: Chart3DPose

    init(viewModel: PoseProjectionViewModel, locale: Locale) {
        self.viewModel = viewModel
        self.locale = locale
        _pose = State(initialValue: Chart3DPose(
            azimuth: .degrees(viewModel.azimuth), inclination: .degrees(viewModel.inclination)
        ))
    }

    var body: some View {
        VStack(spacing: Layout.itemSpacing) {
            PoseProjectionPlot3D(tastings: viewModel.tastings, projection: viewModel.projection, pose: $pose)
                // snippet:pose-and-projection-sync
                // A drag turns the chart and changes the bound pose: read its angles back into the sliders.
                .onChange(of: pose) { _, newPose in
                    viewModel.chartReported(PoseProjectionAngles(
                        azimuth: newPose.azimuth.degrees, inclination: newPose.inclination.degrees
                    ))
                }
                // A slider or preset changed the angles: turn the chart, unless it already shows them.
                .onChange(of: viewModel.angles) { _, angles in
                    let shown = PoseProjectionAngles(azimuth: pose.azimuth.degrees, inclination: pose.inclination.degrees)
                    if viewModel.chartNeedsPose(currently: shown) {
                        pose = Chart3DPose(azimuth: .degrees(angles.azimuth), inclination: .degrees(angles.inclination))
                    }
                }
                // end
                .accessibilityIdentifier("press-target")
                // A Chart3D gives assistive technologies nothing: no elements and no Audio Graph. They get
                // this 2D chart in its place, one element per origin, and the descriptor inside it.
                .accessibilityRepresentation {
                    PoseProjectionRepresentation(viewModel: viewModel, locale: locale)
                }

            PoseProjectionKey(origins: viewModel.facts.clusters.map(\.origin))
        }
    }
}

/// The tastings in three dimensions, at the bound pose and in the chosen projection.
@available(iOS 26, *)
struct PoseProjectionPlot3D: View {
    let tastings: [BeanTasting]
    let projection: PoseProjectionProjection
    @Binding var pose: Chart3DPose
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        chart
            .chartXAxisLabel(PoseProjectionWording.acidity)
            .chartYAxisLabel(PoseProjectionWording.body)
            .chartZAxisLabel(PoseProjectionWording.sweetness)
            // Scores run from 0 to 10 on every axis, so the box is the same whichever way it is turned.
            .chartXScale(domain: PoseProjectionDescriptor.scoreRange, range: PoseProjectionMetrics.boxRange)
            .chartYScale(domain: PoseProjectionDescriptor.scoreRange, range: PoseProjectionMetrics.boxRange)
            .chartZScale(domain: PoseProjectionDescriptor.scoreRange, range: PoseProjectionMetrics.boxRange)
            .chartXAxis { AxisMarks(values: PoseProjectionMetrics.axisValues) }
            .chartYAxis { AxisMarks(values: PoseProjectionMetrics.axisValues) }
            .chartZAxis { AxisMarks(values: PoseProjectionMetrics.axisValues) }
            // The pose is bound from the view above, so a new identity keeps the reader's rotation.
            // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
            // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them.
            .id(colorScheme)
    }

    private var chart: some View {
        // snippet:pose-and-projection-chart
        Chart3D(tastings) { tasting in
            PointMark(
                x: .value(PoseProjectionWording.acidity, tasting.acidity),
                y: .value(PoseProjectionWording.body, tasting.body),
                z: .value(PoseProjectionWording.sweetness, tasting.sweetness)
            )
            // A colour and solid per origin from the app's one table, which the key reads too: in a
            // Chart3D the colour scale modifier is not applied, and `foregroundStyle(by:)` draws no legend.
            .foregroundStyle(BeanOriginStyle.colour(for: tasting.origin))
            .symbol(BeanOriginStyle.solid(for: tasting.origin).chartSymbol)
            .symbolSize(PoseProjectionMetrics.symbolSize)
        }
        // The pose is bound: setting it turns the chart, and a drag on the chart updates it.
        .chart3DPose($pose)
        .poseProjectionCamera(projection)
        // end
    }
}

@available(iOS 26, *)
extension View {
    /// The camera projection the picker chose.
    @ViewBuilder
    func poseProjectionCamera(_ projection: PoseProjectionProjection) -> some View {
        switch projection {
        case .orthographic:
            // snippet:pose-and-projection-orthographic
            // The default: depth does not change a point's size.
            chart3DCameraProjection(.orthographic)
        // end
        case .perspective:
            // snippet:pose-and-projection-perspective
            // Farther points smaller, parallel edges converging.
            chart3DCameraProjection(.perspective)
            // end
        }
    }
}

/// What assistive technologies get in place of the 3D chart: the chart as it opens, from the front (acidity
/// across, body up), one element per origin, each lying over that origin's span of acidity, so they are read
/// along the acidity axis; and the chart descriptor, on the same axes.
struct PoseProjectionRepresentation: View {
    let viewModel: PoseProjectionViewModel
    let locale: Locale

    var body: some View {
        Chart {
            ForEach(viewModel.facts.clusters) { cluster in
                Plot {
                    // A clear band the full height of the plot gives every element the same top edge.
                    RectangleMark(
                        xStart: .value(PoseProjectionWording.acidity, cluster.acidity.lowerBound),
                        xEnd: .value(PoseProjectionWording.acidity, cluster.acidity.upperBound)
                    )
                    .foregroundStyle(.clear)
                    ForEach(viewModel.tastings.filter { $0.origin == cluster.origin }) { tasting in
                        PointMark(
                            x: .value(PoseProjectionWording.acidity, tasting.acidity),
                            y: .value(PoseProjectionWording.body, tasting.body)
                        )
                    }
                }
                .accessibilityLabel(viewModel.elementLabel(for: cluster, locale: locale))
                .accessibilityValue(viewModel.elementValue(for: cluster, locale: locale))
            }
        }
        .chartXScale(domain: PoseProjectionDescriptor.scoreRange)
        .chartYScale(domain: PoseProjectionDescriptor.scoreRange)
        .accessibilityIdentifier("press-target")
        .accessibilityChartDescriptor(PoseProjectionDescriptor(tastings: viewModel.tastings, locale: locale))
    }
}

/// The key the 3D chart does not draw: `foregroundStyle(by:)` makes no legend in a `Chart3D`.
/// Hidden from VoiceOver, whose elements name each origin.
struct PoseProjectionKey: View {
    let origins: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Layout.sectionSpacing) { entries }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) { entries }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }

    private var entries: some View {
        ForEach(origins, id: \.self) { origin in
            PoseProjectionKeyEntry(origin: origin)
        }
    }
}

/// One origin in the key: its shape in its colour, and its name.
struct PoseProjectionKeyEntry: View {
    let origin: String

    var body: some View {
        Label {
            Text(origin)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: BeanOriginStyle.symbolName(for: origin))
                .foregroundStyle(BeanOriginStyle.colour(for: origin))
        }
    }
}

/// The preset buttons, the two angle sliders and the projection picker.
struct PoseProjectionControls: View {
    @Bindable var viewModel: PoseProjectionViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            PoseProjectionPresetButtons(viewModel: viewModel, locale: locale)
            LabeledSlider(
                title: "Azimuth", value: $viewModel.azimuth, range: -180 ... 180, step: 5,
                valueText: viewModel.azimuthText(locale: locale),
                spokenValue: viewModel.azimuthSpokenValue(locale: locale)
            )
            LabeledSlider(
                title: "Inclination", value: $viewModel.inclination, range: -90 ... 90, step: 5,
                valueText: viewModel.inclinationText(locale: locale),
                spokenValue: viewModel.inclinationSpokenValue(locale: locale)
            )
            LabeledSegmentedPicker(title: "Projection", selection: $viewModel.projection) {
                ForEach(PoseProjectionProjection.allCases) { projection in
                    Text(projection.title).tag(projection)
                }
            }
            Text(viewModel.projection.note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// One button per preset pose. The one the chart is at is marked, for sight and for VoiceOver.
struct PoseProjectionPresetButtons: View {
    let viewModel: PoseProjectionViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("Pose")
                .accessibilityAddTraits(.isHeader)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: Layout.itemSpacing) { buttons }
                VStack(alignment: .leading, spacing: Layout.itemSpacing) { buttons }
            }
        }
    }

    private var buttons: some View {
        ForEach(PoseProjectionPreset.allCases) { preset in
            let isActive = viewModel.activePreset == preset
            Button {
                announcePoseProjectionChange(viewModel.choose(preset, locale: locale))
            } label: {
                Label(preset.title, systemImage: isActive ? "checkmark.circle.fill" : "circle")
            }
            .buttonStyle(.bordered)
            .tint(isActive ? .accentColor : .primary)
            .accessibilityLabel(preset.title)
            .accessibilityHint(preset.spokenDescription)
            .accessibilityAddTraits(isActive ? .isSelected : [])
        }
    }
}

/// Says aloud that the chart turned to a preset, for people who cannot see it happen.
@MainActor
func announcePoseProjectionChange(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

#Preview("Pose and projection") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/pose-and-projection") {
            PoseProjectionScreen(screen: screen)
        }
    }
}

#Preview("Key") {
    PoseProjectionKey(origins: CafeData.beanOrigins)
        .padding()
}
