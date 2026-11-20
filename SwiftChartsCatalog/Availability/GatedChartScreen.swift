import Accessibility
import Charts
import SwiftUI

/// "Gating with a fallback": a 3D chart on iOS 26, the 2D chart people on iOS 18 see instead, and a toggle
/// that draws the fallback on a system too new to reach it.
struct GatedChartScreen: View {
    let screen: CatalogScreen
    @State private var model = GatedChartViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean tastings by origin",
            message: model.summary(locale: locale).headline,
            explanation: """
            Chart3D exists from iOS 26 and this app supports iOS 18, so the 3D chart lives in a view marked \
            @available(iOS 26, *), reached through if #available. Systems that fail the check get the same \
            data as a 2D scatter plot of acidity against body, which says that sweetness, the third score, is missing.
            """
        ) {
            GatedChartContent(model: model, locale: locale)
        } controls: {
            ControlsSection {
                Toggle("Simulate older OS", isOn: $model.simulatesOlderOS)
                    .disabled(!model.canSimulateOlderOS)
                GatedChartAngleButtons(model: model)
                    .disabled(!model.canChooseAngle)
                Text(model.status)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            GatedChartWhatTheToggleProves()
            GatedChartOlderTargets()
        }
        .onChange(of: model.simulatesOlderOS) {
            // The toggle swaps the kind of chart: say so, then the headline.
            AccessibilityNotification.Announcement(model.announcement(locale: locale)).post()
        }
    }
}

/// The chart the system can draw, or a placeholder when there are no samples.
struct GatedChartContent: View {
    let model: GatedChartViewModel
    let locale: Locale

    var body: some View {
        if !model.hasData {
            ContentUnavailableView(
                "No bean samples",
                systemImage: "leaf",
                description: Text("Tasting scores appear here, one point per sample.")
            )
        } else {
            // snippet:gating-with-a-fallback-gate
            // The check is the app's. `model.branch` adds this screen's "Simulate older OS" toggle;
            // an app has only the check.
            if #available(iOS 26, *), model.branch == .chart3D {
                GatedChart3DView(model: model, locale: locale)
            } else {
                // iOS 18 to 25: the same data in 2D, saying what is missing.
                GatedChartFallbackView(beans: model.beans, locale: locale)
            }
            // end
        }
    }
}

// snippet:gating-with-a-fallback-chart3d
/// The 3D chart. The view is marked iOS 26, and so is anything of a 3D type: a `Chart3DPose` held by a view
/// that iOS 18 can load would not compile. The model keeps the angle as plain numbers instead.
@available(iOS 26, *)
struct GatedChart3DView: View {
    let model: GatedChartViewModel
    let locale: Locale
    @Environment(\.colorScheme) private var colorScheme

    /// The pose made from the model's angles; a drag writes back into them.
    private var pose: Binding<Chart3DPose> {
        Binding(
            get: { Chart3DPose(azimuth: .degrees(model.azimuthDegrees), inclination: .degrees(model.inclinationDegrees)) },
            set: { newPose in
                model.azimuthDegrees = newPose.azimuth.degrees
                model.inclinationDegrees = newPose.inclination.degrees
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Chart3D(model.beans) { bean in
                PointMark(
                    x: .value(GatedChartWording.acidity, bean.acidity),
                    y: .value(GatedChartWording.body, bean.body),
                    z: .value(GatedChartWording.sweetness, bean.sweetness)
                )
                // 3D draws no legend: colour and solid come from the table the key below reads.
                .foregroundStyle(BeanOriginStyle.colour(for: bean.origin))
                .symbol(BeanOriginStyle.solid(for: bean.origin).chartSymbol)
                .symbolSize(GatedChartMarks.symbolSize(for: BeanOriginStyle.solid(for: bean.origin)))
            }
            .chart3DPose(pose)
            .chartXAxisLabel(GatedChartWording.acidity)
            .chartYAxisLabel(GatedChartWording.body)
            .chartZAxisLabel(GatedChartWording.sweetness)
            .chartXScale(domain: GatedChartWording.scoreRange, range: -0.5 ... 0.5)
            .chartYScale(domain: GatedChartWording.scoreRange, range: -0.5 ... 0.5)
            .chartZScale(domain: GatedChartWording.scoreRange, range: -0.5 ... 0.5)
            // A 3D axis does not label its domain's ends: mark scores inside it, on every axis.
            .chartXAxis { GatedChartMarks.axisMarks() }
            .chartYAxis { GatedChartMarks.axisMarks() }
            .chartZAxis { GatedChartMarks.axisMarks() }
            .accessibilityIdentifier("press-target")
            .modifier(GatedChart3DAccessibility(beans: model.beans, locale: locale))
            // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
            // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The
            // pose is the model's, so it survives.
            .id(colorScheme)
            GatedChartKey()
        }
    }
}

// end

// snippet:gating-with-a-fallback-accessibility
/// A `Chart3D` gives assistive technologies nothing, so it gets an undrawn 2D chart in its place: one
/// element per origin, and the Audio Graph's descriptor, with sweetness as an extra axis.
struct GatedChart3DAccessibility: ViewModifier {
    let beans: [BeanTasting]
    let locale: Locale

    func body(content: Content) -> some View {
        content.accessibilityRepresentation {
            Chart {
                GatedChartOriginPlots(beans: beans, locale: locale, includesSweetness: true)
            }
            .chartXScale(domain: GatedChartWording.scoreRange)
            .chartYScale(domain: GatedChartWording.scoreRange)
            .accessibilityIdentifier("press-target")
            // The descriptor goes inside the representation: one on the drawn chart is lost.
            .accessibilityChartDescriptor(GatedChartDescriptor(beans: beans, locale: locale, includesSweetness: true))
        }
    }
}

// end

// snippet:gating-with-a-fallback-fallback
/// What iOS 18 to 25 draw: acidity against body in 2D, with a line saying what is missing.
struct GatedChartFallbackView: View {
    let beans: [BeanTasting]
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Chart {
                GatedChartOriginPlots(beans: beans, locale: locale, includesSweetness: false)
            }
            .chartXScale(domain: GatedChartWording.scoreRange)
            .chartYScale(domain: GatedChartWording.scoreRange)
            .chartXAxisLabel(GatedChartWording.acidity)
            .yAxisTitle(GatedChartWording.body)
            .chartForegroundStyleScale(domain: BeanOriginStyle.origins) { BeanOriginStyle.colour(for: $0) }
            .chartSymbolScale(domain: BeanOriginStyle.origins) { BeanOriginStyle.chartSymbol(for: $0) }
            .accessibilityChartDescriptor(GatedChartDescriptor(beans: beans, locale: locale, includesSweetness: false))
            Label("Sweetness, the third score, needs iOS 26 and is not drawn.", systemImage: "cube.transparent")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

// end

/// Each origin's points, inside one labelled `Plot` so the origin is one accessibility element. Drawn by the
/// fallback; undrawn behind the 3D chart, where it supplies the elements.
struct GatedChartOriginPlots: ChartContent {
    let beans: [BeanTasting]
    let locale: Locale
    /// Whether the element text names sweetness: only where the chart draws it.
    let includesSweetness: Bool

    var body: some ChartContent {
        let summary = GatedChartSummary(beans: beans, locale: locale)
        ForEach(summary.origins, id: \.self) { origin in
            Plot {
                ForEach(summary.beans(from: origin)) { bean in
                    PointMark(
                        x: .value(GatedChartWording.acidity, bean.acidity),
                        y: .value(GatedChartWording.body, bean.body)
                    )
                    .foregroundStyle(by: .value(GatedChartWording.origin, bean.origin))
                    .symbol(by: .value(GatedChartWording.origin, bean.origin))
                }
            }
            .accessibilityLabel(summary.elementLabel(origin: origin))
            .accessibilityValue(summary.elementValue(origin: origin, includesSweetness: includesSweetness))
        }
    }
}

/// The key for the 3D chart, which draws no legend: each origin's colour and solid, from the same table the
/// points read. Hidden from VoiceOver, which hears each origin by name from the elements.
struct GatedChartKey: View {
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Layout.itemSpacing) { GatedChartKeyEntries() }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) { GatedChartKeyEntries() }
        }
        .font(.caption)
        .accessibilityHidden(true)
    }
}

struct GatedChartKeyEntries: View {
    var body: some View {
        ForEach(BeanOriginStyle.origins, id: \.self) { origin in
            let solid = BeanOriginStyle.solid(for: origin)
            Label {
                Text(origin)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: solid.symbolName)
                    .foregroundStyle(BeanOriginStyle.colour(for: origin))
            }
        }
    }
}

/// What the toggle shows and what it cannot show, on screen, since the simulator runs a newer iOS.
struct GatedChartWhatTheToggleProves: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("What the toggle proves")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("""
            It draws the fallback view, with its elements and Audio Graph: a stand-in for what people on \
            iOS 18 get.
            """)
            Text("What it does not")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("""
            On iOS 26 and later the real check always passes; the toggle only overrides it. The fallback is still \
            drawn by this system's Swift Charts, not iOS 18's, and nothing here runs on iOS 18. The compiler's \
            availability errors, and a run on an iOS 18 simulator or device, are what prove the gate.
            """)
        }
        .foregroundStyle(.primary)
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// The same pattern on older deployment targets, from the skill's availability overview.
struct GatedChartOlderTargets: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("The same pattern, older targets")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("""
            Any API newer than the deployment target goes inside if #available, or in a type marked @available, \
            with a fallback that says what people on the older system see.
            """)
            Text("""
            • Target iOS 16, a donut: SectorMark is iOS 17, so iOS 16 gets bars of the same shares.
            • Target iOS 17, a large plot: plots are iOS 18, so iOS 17 gets one mark per element.
            • Target iOS 16, selection: chartXSelection is iOS 17, so iOS 16 gets chartOverlay with ChartProxy \
            and its own gesture.
            """)
            Text("State of a newer type, such as a Chart3DPose, lives in the marked type too.")
        }
        .foregroundStyle(.secondary)
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// The angle presets as buttons, so any of them can be chosen again after a drag has turned the chart.
struct GatedChartAngleButtons: View {
    let model: GatedChartViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("View the 3D chart from")
                .accessibilityHidden(true)
            ViewThatFits(in: .horizontal) {
                HStack { GatedChartAngleButtonRow(model: model) }
                VStack(alignment: .leading) { GatedChartAngleButtonRow(model: model) }
            }
        }
    }
}

struct GatedChartAngleButtonRow: View {
    let model: GatedChartViewModel

    var body: some View {
        ForEach(GatedChartAngle.allCases) { angle in
            Button(angle.title) { model.show(angle) }
                .buttonStyle(.bordered)
                .accessibilityLabel("View the 3D chart from \(angle.title)")
        }
    }
}

/// Constants that belong to this chart's marks.
private enum GatedChartMarks {
    /// The scores each 3D axis labels: inside the 0 to 10 domain, whose ends a 3D axis leaves unlabelled.
    static let markedScores: [Double] = [2, 4, 6, 8]

    @available(iOS 26, *)
    static func axisMarks() -> some AxisContent {
        AxisMarks(values: markedScores) {
            AxisTick()
            AxisGridLine()
            AxisValueLabel()
        }
    }

    /// A fraction of the box's edge, chosen so the three solids look about the same size: for a sphere the
    /// value is its radius, so it takes less than a cube's; a cone needs more, or it is barely visible.
    nonisolated static func symbolSize(for solid: BeanOriginSolid) -> Double {
        switch solid {
        case .sphere: 0.024
        case .cube, .cylinder: 0.035
        case .cone: 0.05
        }
    }
}

/// The Audio Graph for both charts: acidity on x, body on y, a series per origin, and in 3D sweetness as
/// an extra axis.
nonisolated struct GatedChartDescriptor: AXChartDescriptorRepresentable {
    let beans: [BeanTasting]
    let locale: Locale
    let includesSweetness: Bool

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = GatedChartSummary(beans: beans, locale: locale)
        let locale = locale
        let range = GatedChartWording.scoreRange
        func axis(_ title: String) -> AXNumericDataAxisDescriptor {
            AXNumericDataAxisDescriptor(title: title, range: range, gridlinePositions: []) { value in
                GatedChartWording.spokenScore(value, locale: locale)
            }
        }
        let series = summary.origins.map { origin in
            AXDataSeriesDescriptor(
                name: origin,
                isContinuous: false,
                dataPoints: summary.beans(from: origin).map { bean in
                    AXDataPoint(
                        x: bean.acidity,
                        y: bean.body,
                        additionalValues: includesSweetness ? [.number(bean.sweetness)] : []
                    )
                }
            )
        }
        let drawn = includesSweetness ? "acidity, body and sweetness" : "acidity and body"
        return AXChartDescriptor(
            title: "Bean tastings by origin: \(drawn)",
            summary: summary.audioGraphSummary(includesSweetness: includesSweetness),
            xAxis: axis(GatedChartWording.acidity),
            yAxis: axis(GatedChartWording.body),
            additionalAxes: includesSweetness ? [axis(GatedChartWording.sweetness)] : [],
            series: series
        )
    }
}

#Preview("Gating with a fallback") {
    NavigationStack {
        if let screen = Catalog.screen(id: "availability/gating-with-a-fallback") {
            GatedChartScreen(screen: screen)
        }
    }
}

#Preview("Fallback") {
    GatedChartFallbackView(beans: CafeData.beanTastings, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
