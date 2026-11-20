import Accessibility
import Charts
import SwiftUI

/// "A surface through the points": a plane fitted to the bean tastings, drawn in the same `Chart3D` as the
/// samples it was fitted to. Sweetness is fitted from acidity and body.
struct FittedSurfaceScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: FittedSurfaceViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, tastings: [BeanTasting] = CafeData.beanTastings) {
        self.screen = screen
        _viewModel = State(initialValue: FittedSurfaceViewModel(tastings: tastings))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean tastings, scored 0 to 10",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation(locale: locale)
        ) {
            FittedSurfaceChartArea(viewModel: viewModel, locale: locale)
        } controls: {
            FittedSurfaceControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The chart and its key, or a placeholder.
private struct FittedSurfaceChartArea: View {
    let viewModel: FittedSurfaceViewModel
    let locale: Locale

    var body: some View {
        if !viewModel.hasData {
            ContentUnavailableView(
                "No bean samples",
                systemImage: "cube.transparent",
                description: Text("Tasting scores appear here, with the plane fitted to them.")
            )
        } else {
            VStack(spacing: Layout.itemSpacing) {
                // snippet:a-surface-through-the-points-gate
                if #available(iOS 26, *) {
                    FittedSurfaceChart3D(viewModel: viewModel, locale: locale)
                } else {
                    ContentUnavailableView(
                        "Needs iOS 26",
                        systemImage: "cube",
                        description: Text("Chart3D and SurfacePlot arrived in iOS 26. On this system the plane and its samples cannot be drawn.")
                    )
                }
                // end
                FittedSurfaceKey(drawsPlane: viewModel.drawsPlane, origins: viewModel.originsInOriginOrder)
            }
        }
    }
}

/// The samples and the fitted plane. Everything of a 3D type lives here, behind the iOS 26 check.
@available(iOS 26, *)
private struct FittedSurfaceChart3D: View {
    let viewModel: FittedSurfaceViewModel
    let locale: Locale
    @Environment(\.colorScheme) private var colorScheme

    /// The pose as the chart takes it, read from and written back to the view model's plain angles, so a
    /// dragged angle survives the chart's new identity when the plane is toggled.
    private var pose: Binding<Chart3DPose> {
        Binding(
            get: {
                Chart3DPose(azimuth: .degrees(viewModel.azimuthDegrees), inclination: .degrees(viewModel.inclinationDegrees))
            },
            set: { newPose in
                viewModel.azimuthDegrees = newPose.azimuth.degrees
                viewModel.inclinationDegrees = newPose.inclination.degrees
            }
        )
    }

    var body: some View {
        let plane = viewModel.drawsPlane ? viewModel.plane : nil
        // snippet:a-surface-through-the-points-chart
        Chart3D {
            ForEach(viewModel.tastings) { tasting in
                let solid = BeanOriginStyle.solid(for: tasting.origin)
                PointMark(
                    x: .value(FittedSurfaceWording.acidity, tasting.acidity),
                    y: .value(FittedSurfaceWording.sweetness, tasting.sweetness),
                    z: .value(FittedSurfaceWording.body, tasting.body)
                )
                // No legend in 3D: each point takes its origin's colour and solid from the table the key reads.
                .foregroundStyle(BeanOriginStyle.colour(for: tasting.origin))
                .symbol(solid.chartSymbol)
                .symbolSize(FittedSurfaceMarks.size(for: solid))
            }
            if let plane {
                // y = f(x, z): sweetness from acidity and body. The closure captures the plane, not the view model.
                SurfacePlot(
                    x: FittedSurfaceWording.acidity,
                    y: FittedSurfaceWording.sweetness,
                    z: FittedSurfaceWording.body
                ) { [plane] acidity, body in
                    FittedSurfaceViewModel.drawnSweetness(plane, acidity: acidity, body: body)
                }
                .foregroundStyle(.gray)
            }
        }
        .chart3DPose(pose)
        .chartXAxisLabel(FittedSurfaceWording.acidity)
        .chartYAxisLabel(FittedSurfaceWording.sweetness)
        .chartZAxisLabel(FittedSurfaceWording.body)
        // The domains are in scores; the range makes the chart a cube centred in its view.
        .chartXScale(domain: viewModel.acidityDomain, range: -0.5 ... 0.5)
        .chartYScale(domain: viewModel.sweetnessDomain, range: -0.5 ... 0.5)
        .chartZScale(domain: viewModel.bodyDomain, range: -0.5 ... 0.5)
        // A 3D axis does not label its domain's ends: mark whole scores inside it. The headline names
        // only these values.
        .chartXAxis { Self.axisMarks(viewModel.acidityMarks) }
        .chartYAxis { Self.axisMarks(viewModel.sweetnessMarks) }
        .chartZAxis { Self.axisMarks(viewModel.bodyMarks) }
        // end
        // Capped at the compact chart height: the panel grows with the text size, and a taller Chart3D
        // draws a larger cube whose axis titles run off the sides.
        .frame(maxHeight: Layout.chartHeightCompact)
        .accessibilityIdentifier("press-target")
        // A Chart3D gives assistive technologies nothing, so they get this undrawn 2D chart in its place.
        .accessibilityRepresentation {
            FittedSurfaceAccessibleChart(viewModel: viewModel, locale: locale)
        }
        // The descriptor and the elements change with the plane: a new identity, or the old ones are kept.
        .id(viewModel.drawsPlane)
        // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
        // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The pose is
        // the view model's, so it survives.
        .id(colorScheme)
    }

    @AxisContentBuilder
    private static func axisMarks(_ values: [Double]) -> some AxisContent {
        AxisMarks(values: values) {
            AxisTick()
            AxisGridLine()
            AxisValueLabel()
        }
    }
}

/// Sizes of the 3D solids, as a fraction of the box's edge. A sphere's size is its radius, so it takes half.
private enum FittedSurfaceMarks {
    static let sphere = 0.018
    static let cube = 0.034
    static let cone = 0.04

    static func size(for solid: BeanOriginSolid) -> Double {
        switch solid {
        case .sphere: sphere
        case .cube, .cylinder: cube
        case .cone: cone
        }
    }
}

// snippet:a-surface-through-the-points-accessibility
/// What assistive technologies get instead of the 3D chart: one element per origin, one for the plane
/// when it is drawn, and the chart descriptor, which has to sit inside the representation.
private struct FittedSurfaceAccessibleChart: View {
    let viewModel: FittedSurfaceViewModel
    let locale: Locale

    var body: some View {
        let spoken = viewModel.spokenText(locale: locale)
        Chart {
            // Declared in the order VoiceOver reads them: the plane, then the origins left to right.
            if spoken.drawsPlane, let plane = viewModel.plane {
                let meanBody = viewModel.tastings.map(\.body).reduce(0, +) / Double(max(1, viewModel.tastings.count))
                Plot {
                    ForEach([viewModel.acidityDomain.lowerBound, viewModel.acidityDomain.upperBound], id: \.self) { acidity in
                        LineMark(
                            x: .value(FittedSurfaceWording.acidity, acidity),
                            y: .value(FittedSurfaceWording.sweetness, plane.sweetness(acidity: acidity, body: meanBody))
                        )
                    }
                }
                .accessibilityLabel(spoken.planeLabel)
                .accessibilityValue(spoken.planeValue)
            }
            ForEach(spoken.originsInReadOrder, id: \.self) { origin in
                Plot {
                    ForEach(viewModel.tastings.filter { $0.origin == origin }) { tasting in
                        PointMark(
                            x: .value(FittedSurfaceWording.acidity, tasting.acidity),
                            y: .value(FittedSurfaceWording.sweetness, tasting.sweetness)
                        )
                    }
                }
                .accessibilityLabel(spoken.originLabel(origin))
                .accessibilityValue(spoken.originValue(origin))
            }
        }
        .chartXScale(domain: viewModel.acidityDomain)
        .chartYScale(domain: viewModel.sweetnessDomain)
        .accessibilityChartDescriptor(FittedSurfaceDescriptor(
            spoken: spoken,
            acidityDomain: viewModel.acidityDomain,
            bodyDomain: viewModel.bodyDomain,
            sweetnessDomain: viewModel.sweetnessDomain
        ))
    }
}

/// The Audio Graph: acidity on x, sweetness on y, body as an additional axis, the plane when it is drawn,
/// sampled where it is drawn at every whole point of acidity and body, then one series per origin, in the
/// order VoiceOver reads the elements.
nonisolated struct FittedSurfaceDescriptor: AXChartDescriptorRepresentable {
    let spoken: FittedSurfaceSpokenText
    let acidityDomain: ClosedRange<Double>
    let bodyDomain: ClosedRange<Double>
    let sweetnessDomain: ClosedRange<Double>

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = spoken.locale
        func axis(_ title: String, _ range: ClosedRange<Double>) -> AXNumericDataAxisDescriptor {
            // "7.8 out of 10", as on the other bean screens: the scale is 0 to 10 though an axis may show less of it.
            AXNumericDataAxisDescriptor(title: title, range: range, gridlinePositions: []) { value in
                value.isFinite ? "\(FittedSurfaceWording.score(value, locale: locale)) out of 10" : ""
            }
        }
        var series: [AXDataSeriesDescriptor] = []
        if spoken.drawsPlane, let plane = spoken.plane {
            // The height the chart draws, so a point where the plane leaves 0 to 10 is not described.
            let grid = Self.wholePoints(acidityDomain).flatMap { acidity in
                Self.wholePoints(bodyDomain).compactMap { body -> AXDataPoint? in
                    let height = FittedSurfaceViewModel.drawnSweetness(plane, acidity: acidity, body: body)
                    return height.isNaN ? nil : AXDataPoint(x: acidity, y: height, additionalValues: [.number(body)])
                }
            }
            series.append(AXDataSeriesDescriptor(name: FittedSurfaceWording.fittedPlane, isContinuous: false, dataPoints: grid))
        }
        series += spoken.originsInOriginOrder.map { origin in
            AXDataSeriesDescriptor(
                name: origin,
                isContinuous: false,
                dataPoints: spoken.tastings.filter { $0.origin == origin }.map {
                    AXDataPoint(x: $0.acidity, y: $0.sweetness, additionalValues: [.number($0.body)])
                }
            )
        }
        return AXChartDescriptor(
            title: spoken.drawsPlane ? "Bean tastings with a plane fitted to them" : "Bean tastings",
            summary: spoken.summary,
            xAxis: axis(FittedSurfaceWording.acidity, acidityDomain),
            yAxis: axis(FittedSurfaceWording.sweetness, sweetnessDomain),
            additionalAxes: [axis(FittedSurfaceWording.body, bodyDomain)],
            series: series
        )
    }

    /// Every whole number in the range: where the plane is sampled.
    static func wholePoints(_ range: ClosedRange<Double>) -> [Double] {
        Array(stride(from: range.lowerBound.rounded(.up), through: range.upperBound, by: 1))
    }
}

// end

/// The key the 3D chart cannot draw itself: the plane and each origin's colour and solid, in the order
/// VoiceOver reads them. A row while it fits, a column when the text is too large for one row.
private struct FittedSurfaceKey: View {
    let drawsPlane: Bool
    let origins: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Layout.sectionSpacing) { FittedSurfaceKeyEntries(drawsPlane: drawsPlane, origins: origins) }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                FittedSurfaceKeyEntries(drawsPlane: drawsPlane, origins: origins)
            }
        }
        .font(.caption)
        // Its full height, so the panel's fixed height squeezes the chart, not the key's wrapped lines.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct FittedSurfaceKeyEntries: View {
    let drawsPlane: Bool
    let origins: [String]

    var body: some View {
        if drawsPlane {
            Label {
                Text(FittedSurfaceWording.fittedPlane)
            } icon: {
                Image(systemName: "square.fill")
                    .foregroundStyle(Color.gray)
            }
        }
        ForEach(origins, id: \.self) { origin in
            Label {
                Text("\(origin), \(BeanOriginStyle.solid(for: origin).pluralName)")
            } icon: {
                Image(systemName: BeanOriginStyle.symbolName(for: origin))
                    .foregroundStyle(BeanOriginStyle.colour(for: origin))
            }
        }
    }
}

/// The plane's switch, and preset angles for anyone who cannot drag to rotate the chart.
private struct FittedSurfaceControls: View {
    @Bindable var viewModel: FittedSurfaceViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            Toggle("Show the fitted plane", isOn: $viewModel.showsSurface)
                .disabled(viewModel.plane == nil)
            FittedSurfacePoseButtons(viewModel: viewModel)
                .disabled(!viewModel.hasData)
        }
        .onChange(of: viewModel.showsSurface) {
            // A change to what is drawn is announced: what changed, then the headline.
            AccessibilityNotification.Announcement(viewModel.changeAnnouncement(locale: locale)).post()
        }
    }
}

/// "View from" and the presets: in a row while they fit, in a column at accessibility text sizes.
private struct FittedSurfacePoseButtons: View {
    let viewModel: FittedSurfaceViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("View from")
                .accessibilityHidden(true)
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading) { FittedSurfacePoseButtonRow(viewModel: viewModel) }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack { FittedSurfacePoseButtonRow(viewModel: viewModel) }
                    VStack(alignment: .leading) { FittedSurfacePoseButtonRow(viewModel: viewModel) }
                }
            }
        }
    }
}

private struct FittedSurfacePoseButtonRow: View {
    let viewModel: FittedSurfaceViewModel

    var body: some View {
        ForEach(FittedSurfacePosePreset.allCases) { preset in
            Button(preset.title) { viewModel.choose(preset) }
                .buttonStyle(.bordered)
                .accessibilityLabel("View from \(preset.title)")
        }
    }
}

#Preview("Fitted plane") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/a-surface-through-the-points") {
            FittedSurfaceScreen(screen: screen)
        }
    }
}

#Preview("No samples") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/a-surface-through-the-points") {
            FittedSurfaceScreen(screen: screen, tastings: [])
        }
    }
}
