import Accessibility
import Charts
import SwiftUI

/// "Surface plot": a `SurfacePlot` of a function in a `Chart3D`, in its height-based, normal-based and
/// gradient styles.
struct SurfacePlot3DScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = SurfacePlot3DViewModel()
    @Environment(\.locale) private var locale

    private var isChartAvailable: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: viewModel.function.formula,
            message: viewModel.headline(locale: locale, isChartAvailable: isChartAvailable),
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            SurfacePlot3DChartSlot(viewModel: viewModel, locale: locale)
        } controls: {
            SurfacePlot3DControls(viewModel: viewModel)
                // With the placeholder showing there is nothing for the controls to change.
                .disabled(!isChartAvailable)
        }
        // A new function is new data: say what changed, then the headline. A new style only restyles,
        // and the picker speaks its own value.
        .onChange(of: viewModel.function) {
            AccessibilityNotification.Announcement(viewModel.functionChangeAnnouncement(locale: locale)).post()
        }
    }
}

/// The chart on iOS 26 and later, and on earlier systems a placeholder saying what is missing.
struct SurfacePlot3DChartSlot: View {
    let viewModel: SurfacePlot3DViewModel
    let locale: Locale

    var body: some View {
        // snippet:surface-plot-gate
        if #available(iOS 26, *) {
            SurfacePlot3DChart(
                function: viewModel.function, style: viewModel.style, viewpoint: viewModel.viewpoint,
                locale: locale, poseChanged: viewModel.poseChanged(toMatch:)
            )
        } else {
            ContentUnavailableView(
                "Needs iOS 26",
                systemImage: "cube.transparent",
                description: Text("3D charts and SurfacePlot arrived in iOS 26. On this system the surface cannot be drawn.")
            )
        }
        // end
    }
}

/// The 3D chart: one surface over x and z from -2 to 2, y from -1 to 1, opened at an angle that shows its shape.
@available(iOS 26, *)
struct SurfacePlot3DChart: View {
    let function: SurfacePlot3DFunction
    let style: SurfacePlot3DStyle
    let viewpoint: SurfacePlot3DViewpoint?
    let locale: Locale
    let poseChanged: (SurfacePlot3DViewpoint?) -> Void
    @Environment(\.colorScheme) private var colorScheme
    /// Opens on the viewpoint the control shows (at first, turned and tilted so the peaks and troughs stand
    /// apart); it updates as people turn the chart, and when the control chooses a view.
    @State private var pose: Chart3DPose

    init(
        function: SurfacePlot3DFunction, style: SurfacePlot3DStyle, viewpoint: SurfacePlot3DViewpoint?,
        locale: Locale, poseChanged: @escaping (SurfacePlot3DViewpoint?) -> Void
    ) {
        self.function = function
        self.style = style
        self.viewpoint = viewpoint
        self.locale = locale
        self.poseChanged = poseChanged
        _pose = State(initialValue: (viewpoint ?? .angle).pose)
    }

    var body: some View {
        // snippet:surface-plot-chart
        Chart3D {
            // The closure is @Sendable: it captures the function, a plain value, never self.
            SurfacePlot(x: "x", y: "y", z: "z") { [function] x, z in
                function.value(x: x, z: z)
            }
            .surfacePlot3DStyle(style)
        }
        .chart3DPose($pose)
        // The domain is the region plotted; the range makes the chart a cube centred in its view.
        .chartXScale(domain: SurfacePlot3DWording.planeDomain, range: SurfacePlot3DGeometry.box)
        .chartYScale(domain: SurfacePlot3DWording.heightDomain, range: SurfacePlot3DGeometry.box)
        .chartZScale(domain: SurfacePlot3DWording.planeDomain, range: SurfacePlot3DGeometry.box)
        // end
        // The control chooses a view; a drag turns the chart, and the control then shows no view.
        .onChange(of: viewpoint) { _, chosen in
            if let chosen, pose != chosen.pose {
                withAnimation { pose = chosen.pose }
            }
        }
        .onChange(of: pose) { _, newPose in
            poseChanged(SurfacePlot3DViewpoint.allCases.first { $0.pose == newPose })
        }
        // A Chart3D gives assistive technologies nothing, so the chart is one element with a label,
        // a value and an Audio Graph of its own. A new function gives it a new identity, so neither
        // VoiceOver nor the Audio Graph keeps the old words.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(SurfacePlot3DWording.elementLabel(for: function, locale: locale))
        .accessibilityValue(SurfacePlot3DWording.elementValue(for: function, locale: locale))
        .accessibilityChartDescriptor(SurfacePlot3DChartDescriptor(function: function, locale: locale))
        .accessibilityIdentifier("press-target")
        .id(function)
        // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
        // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The pose is
        // this view's state, outside the identity, so it survives.
        .id(colorScheme)
    }
}

@available(iOS 26, *)
extension Chart3DContent {
    /// The style the picker chose: one line of code each.
    @Chart3DContentBuilder
    func surfacePlot3DStyle(_ style: SurfacePlot3DStyle) -> some Chart3DContent {
        switch style {
        case .heightBased:
            // snippet:surface-plot-height-based
            // Colours by y, which makes the shape easier to read: the default to reach for.
            foregroundStyle(.heightBased)
        // end
        case .normalBased:
            // snippet:surface-plot-normal-based
            // Colours by the direction each part of the surface faces.
            foregroundStyle(.normalBased)
        // end
        case .gradient:
            // snippet:surface-plot-gradient
            // Any gradient, or a plain colour; its colours do not follow y.
            foregroundStyle(EllipticalGradient(colors: [.red, .orange, .yellow, .green, .blue]))
            // end
        }
    }
}

@available(iOS 26, *)
extension SurfacePlot3DViewpoint {
    /// The pose for each view. Front looks along z (x across, y up) and side along x (z across, rising to the
    /// right, as `.left` shows it; `.right` runs z the other way). Above looks down on the colours.
    var pose: Chart3DPose {
        switch self {
        case .angle: Chart3DPose(
                azimuth: .degrees(SurfacePlot3DGeometry.azimuthDegrees),
                inclination: .degrees(SurfacePlot3DGeometry.inclinationDegrees)
            )
        case .front: .front
        case .side: .left
        case .above: .top
        }
    }
}

/// The style, function and view pickers.
struct SurfacePlot3DControls: View {
    @Bindable var viewModel: SurfacePlot3DViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Style", selection: $viewModel.style) {
                ForEach(SurfacePlot3DStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            LabeledSegmentedPicker(title: "Function", selection: $viewModel.function) {
                ForEach(SurfacePlot3DFunction.allCases) { function in
                    Text(function.title).tag(function)
                }
            }
            // Turning only changes where the surface is seen from, so the picker speaks its own value and
            // nothing is announced. A drag to no view in particular leaves no segment chosen.
            LabeledSegmentedPicker(title: "View", selection: $viewModel.viewpoint) {
                ForEach(SurfacePlot3DViewpoint.allCases) { viewpoint in
                    Text(viewpoint.title).tag(Optional(viewpoint))
                }
            }
        }
    }
}

/// The surface for the Audio Graph: one series per row of the surface at a fixed z, each running along x.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct SurfacePlot3DChartDescriptor: AXChartDescriptorRepresentable {
    let function: SurfacePlot3DFunction
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let function = function
        let xAxis = AXNumericDataAxisDescriptor(
            title: "x", range: SurfacePlot3DWording.planeDomain, gridlinePositions: []
        ) { SurfacePlot3DWording.spokenValue($0, axis: "x", locale: locale) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: "y", range: SurfacePlot3DWording.heightDomain, gridlinePositions: []
        ) { SurfacePlot3DWording.spokenValue($0, axis: "y", locale: locale) }
        // The third axis, as every other 3D screen gives one: each row's z is also in its points.
        let zAxis = AXNumericDataAxisDescriptor(
            title: "z", range: SurfacePlot3DWording.planeDomain, gridlinePositions: []
        ) { SurfacePlot3DWording.spokenValue($0, axis: "z", locale: locale) }
        let series = SurfacePlot3DWording.rowZValues(for: function).map { z in
            AXDataSeriesDescriptor(
                name: SurfacePlot3DWording.rowName(z: z, locale: locale),
                isContinuous: true,
                dataPoints: SurfacePlot3DWording.rowXValues(for: function).map { x in
                    AXDataPoint(x: x, y: function.value(x: x, z: z), additionalValues: [.number(z)])
                }
            )
        }
        return AXChartDescriptor(
            title: SurfacePlot3DWording.descriptorTitle(for: function),
            summary: SurfacePlot3DWording.headline(for: function, locale: locale),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [zAxis],
            series: series
        )
    }
}

/// The opening pose, in degrees, and the box.
private nonisolated enum SurfacePlot3DGeometry {
    static let azimuthDegrees = 30.0
    static let inclinationDegrees = 20.0
    /// The extent of every axis in the chart's box, so it is a cube centred in its view.
    static let box: ClosedRange<CGFloat> = -0.5 ... 0.5
}

#Preview {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/surface-plot") {
            SurfacePlot3DScreen(screen: screen)
        }
    }
}
