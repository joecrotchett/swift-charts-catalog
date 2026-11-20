import Accessibility
import Charts
import Spatial
import SwiftUI

/// "Scales and axes in 3D": a domain, a range and axis marks on each of a 3D chart's three axes.
struct Axes3DScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = Axes3DViewModel()
    /// The locale every count and score is written in, read here and passed down.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean samples, scored 0 to 10",
            message: viewModel.headline(locale: locale),
            explanation: """
            Each axis of a Chart3D has its own scale: chartXScale, chartYScale and chartZScale take a domain in \
            data values and a range of −0.5 to 0.5, so the chart stays a cube whatever the domains. A 3D axis \
            never labels its domain's ends, so the axis marks list even scores inside each domain. Move a \
            domain's start up and the cube zooms in on what is left; the app leaves out samples outside a domain, \
            which a 3D chart would draw beyond its cube. \
            The framework places the axis titles itself, and at some angles a title runs into a label. \
            With VoiceOver, swipe to the chart for one element per origin, and use the rotor's Audio Graph \
            (Describe chart, Play Audio Graph).
            """
        ) {
            Axes3DChartPanelContent(viewModel: viewModel, locale: locale)
        } controls: {
            Axes3DControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The chart and its key, or what older systems see instead.
struct Axes3DChartPanelContent: View {
    let viewModel: Axes3DViewModel
    let locale: Locale

    var body: some View {
        if viewModel.beansInside.isEmpty {
            ContentUnavailableView(
                viewModel.beans.isEmpty ? "No samples" : "No samples inside these domains",
                systemImage: "cube",
                description: Text(viewModel.beans.isEmpty
                    ? "Bean samples appear here, one point each."
                    : "Move a domain's start down to bring samples back into the cube.")
            )
        } else {
            VStack(spacing: Layout.itemSpacing) {
                // snippet:scales-and-axes-in-3d-availability
                if #available(iOS 26, *) {
                    Axes3DChart(viewModel: viewModel, locale: locale)
                } else {
                    ContentUnavailableView(
                        "3D charts need iOS 26",
                        systemImage: "cube",
                        description: Text("Chart3D, with its z axis and scale, arrived in iOS 26.")
                    )
                }
                // end
                Axes3DKey(origins: viewModel.originGroupsInOriginOrder.map(\.origin))
            }
        }
    }
}

/// The marks' constants: the cube every axis maps onto, and a point's size for each solid.
private enum Axes3DMarks {
    /// The range of every axis: the box's extent, the same on all three, so the chart is a cube.
    static let cube: ClosedRange<CGFloat> = -0.5 ... 0.5
    /// A sphere's size is its radius and a cube's its edge (`chart3d.md`), so the sphere takes half
    /// the number to look the same size. The skill does not say what a cone's size measures; it takes
    /// the cube's.
    static func size(for solid: BeanOriginSolid) -> CGFloat {
        solid == .sphere ? 0.02 : 0.04
    }
}

/// The 3D chart, with each axis's domain, range and marks set. Everything 3D lives in this type,
/// so the app's iOS 18 target compiles.
@available(iOS 26, *)
struct Axes3DChart: View {
    @Bindable var viewModel: Axes3DViewModel
    let locale: Locale
    @Environment(\.colorScheme) private var colorScheme

    /// The pose as the chart takes it, read from and written back to the view model's plain angles.
    private var pose: Binding<Chart3DPose> {
        Binding(
            get: {
                Chart3DPose(
                    azimuth: .degrees(viewModel.azimuthDegrees),
                    inclination: .degrees(viewModel.inclinationDegrees)
                )
            },
            set: { newPose in
                viewModel.azimuthDegrees = newPose.azimuth.degrees
                viewModel.inclinationDegrees = newPose.inclination.degrees
            }
        )
    }

    var body: some View {
        // snippet:scales-and-axes-in-3d-chart
        Chart3D(viewModel.beansInside) { bean in
            PointMark(
                x: .value(Axes3DAxis.acidity.title, bean.acidity),
                y: .value(Axes3DAxis.body.title, bean.body),
                z: .value(Axes3DAxis.sweetness.title, bean.sweetness)
            )
            .symbol(BeanOriginStyle.solid(for: bean.origin).chartSymbol)
            .symbolSize(Axes3DMarks.size(for: BeanOriginStyle.solid(for: bean.origin)))
            // In 3D, foregroundStyle(by:) draws no legend: colour each point from the table the key reads.
            .foregroundStyle(BeanOriginStyle.colour(for: bean.origin))
        }
        .chartXAxisLabel(Axes3DAxis.acidity.title)
        .chartYAxisLabel(Axes3DAxis.body.title)
        .chartZAxisLabel(Axes3DAxis.sweetness.title)
        // The domain is in data values; the range is the box's extent, the same on every axis.
        .chartXScale(domain: viewModel.domain(for: .acidity), range: Axes3DMarks.cube)
        .chartYScale(domain: viewModel.domain(for: .body), range: Axes3DMarks.cube)
        .chartZScale(domain: viewModel.domain(for: .sweetness), range: Axes3DMarks.cube)
        // A 3D axis does not label its domain's ends: mark values inside it.
        .chartXAxis { axisMarks(viewModel.markedValues(for: .acidity)) }
        .chartYAxis { axisMarks(viewModel.markedValues(for: .body)) }
        .chartZAxis { axisMarks(viewModel.markedValues(for: .sweetness)) }
        .chart3DPose(pose)
        // end
        // Capped at the compact chart height: the panel grows with the text size, and a taller Chart3D
        // draws a larger cube whose axis titles run off the sides.
        .frame(maxHeight: Layout.chartHeightCompact)
        .accessibilityIdentifier("press-target")
        // A Chart3D gives assistive technologies nothing: they get an undrawn 2D chart instead,
        // one labelled Plot per origin, with the descriptor inside it.
        .accessibilityRepresentation {
            Axes3DRepresentation(viewModel: viewModel, locale: locale)
        }
        // The descriptor and elements change with the domains while the samples' ids may not.
        .id(viewModel.chartIdentity)
        // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
        // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The pose is
        // the view model's, so it survives.
        .id(colorScheme)
    }

    /// The same marks on every axis: tick, grid line and a label written in the view's locale.
    @AxisContentBuilder
    private func axisMarks(_ values: [Double]) -> some AxisContent {
        AxisMarks(values: values) {
            AxisTick()
            AxisGridLine()
            AxisValueLabel(format: FloatingPointFormatStyle<Double>.number.locale(locale))
        }
    }
}

/// What assistive technologies get in place of the 3D chart: acidity across and body up, one element
/// per origin, and the Audio Graph with sweetness as a third axis.
struct Axes3DRepresentation: View {
    let viewModel: Axes3DViewModel
    let locale: Locale

    var body: some View {
        Chart(viewModel.originGroups) { group in
            Plot {
                ForEach(group.beans) { bean in
                    PointMark(
                        x: .value(Axes3DAxis.acidity.title, bean.acidity),
                        y: .value(Axes3DAxis.body.title, bean.body)
                    )
                }
            }
            .accessibilityLabel(viewModel.elementLabel(for: group))
            .accessibilityValue(viewModel.elementValue(for: group, locale: locale))
        }
        .chartXScale(domain: viewModel.domain(for: .acidity))
        .chartYScale(domain: viewModel.domain(for: .body))
        .accessibilityChartDescriptor(Axes3DChartDescriptor(viewModel: viewModel, locale: locale))
    }
}

/// The chart for the Audio Graph: acidity on x, body on y, sweetness as an additional axis, one series
/// per origin, each axis's range the drawn domain.
nonisolated struct Axes3DChartDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let domains: [Axes3DAxis: ClosedRange<Double>]
    let groups: [Axes3DOriginGroup]
    let locale: Locale

    @MainActor
    init(viewModel: Axes3DViewModel, locale: Locale) {
        title = "Bean samples by acidity, body and sweetness"
        summary = viewModel.audioGraphSummary(locale: locale)
        domains = Dictionary(uniqueKeysWithValues: Axes3DAxis.allCases.map { ($0, viewModel.domain(for: $0)) })
        groups = viewModel.originGroupsInOriginOrder
        self.locale = locale
    }

    func axis(_ axis: Axes3DAxis) -> AXNumericDataAxisDescriptor {
        let locale = locale
        return AXNumericDataAxisDescriptor(
            title: axis.title,
            range: domains[axis] ?? 0 ... Axes3DViewModel.scoreTop,
            gridlinePositions: []
        ) { value in
            value.isFinite ? "\(Axes3DViewModel.score(value, locale: locale)) out of 10" : ""
        }
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: axis(.acidity),
            yAxis: axis(.body),
            additionalAxes: [axis(.sweetness)],
            series: groups.map { group in
                AXDataSeriesDescriptor(
                    name: group.origin,
                    isContinuous: false,
                    dataPoints: group.beans.map { bean in
                        AXDataPoint(x: bean.acidity, y: bean.body, additionalValues: [.number(bean.sweetness)])
                    }
                )
            }
        )
    }
}

/// The key the 3D chart cannot draw: each origin's colour and solid, from the same table the points use,
/// in the order VoiceOver reads the origins. It wraps onto one line per origin when the text is too large
/// for one row.
struct Axes3DKey: View {
    let origins: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Layout.sectionSpacing) { Axes3DKeyEntries(origins: origins) }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) { Axes3DKeyEntries(origins: origins) }
        }
        .font(.caption)
        // Its full height, so the panel's fixed height squeezes the chart, not the key's wrapped lines.
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Axes3DKeyEntries: View {
    let origins: [String]

    var body: some View {
        ForEach(origins, id: \.self) { origin in
            Label {
                Text("\(origin), \(BeanOriginStyle.solid(for: origin).pluralName)")
            } icon: {
                Image(systemName: BeanOriginStyle.solid(for: origin).symbolName)
                    .foregroundStyle(BeanOriginStyle.colour(for: origin))
            }
        }
    }
}

/// One domain slider per axis, then buttons that turn the chart for anyone who cannot drag it.
struct Axes3DControls: View {
    @Bindable var viewModel: Axes3DViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            ForEach(Axes3DAxis.allCases, id: \.self) { axis in
                LabeledSlider(
                    title: viewModel.sliderTitle(for: axis),
                    value: Binding(get: { viewModel.start(for: axis) }, set: { viewModel.setStart($0, for: axis) }),
                    range: Axes3DViewModel.startRange,
                    step: 1,
                    valueText: viewModel.domainText(for: axis, locale: locale),
                    spokenValue: viewModel.sliderSpokenValue(for: axis, locale: locale)
                )
            }
            Axes3DViewpointButtons(viewModel: viewModel)
        }
    }
}

struct Axes3DViewpointButtons: View {
    let viewModel: Axes3DViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("View from")
                .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack { Axes3DViewpointButtonRow(viewModel: viewModel) }
                VStack(alignment: .leading) { Axes3DViewpointButtonRow(viewModel: viewModel) }
            }
        }
    }
}

struct Axes3DViewpointButtonRow: View {
    let viewModel: Axes3DViewModel

    var body: some View {
        ForEach(Axes3DViewpoint.allCases, id: \.self) { viewpoint in
            Button(viewpoint.title) { viewModel.show(viewpoint) }
                .buttonStyle(.bordered)
                .accessibilityLabel("\(viewpoint.title) view")
                .accessibilityHint(viewpoint.spokenHint)
        }
    }
}

#Preview("Scales and axes in 3D") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/scales-and-axes-in-3d") {
            Axes3DScreen(screen: screen)
        }
    }
}

#Preview("No samples") {
    Axes3DChartPanelContent(viewModel: Axes3DViewModel(beans: []), locale: .current)
}
