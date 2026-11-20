import Accessibility
import Charts
import Spatial
import SwiftUI

/// "3D scatter": `PointMark(x:y:z:)` coloured by origin, with the symbol, size and material modifiers,
/// and a legend the screen draws itself, since a 3D chart draws none.
struct Scatter3DScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: Scatter3DViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, beans: [BeanTasting] = CafeData.beanTastings) {
        self.screen = screen
        _viewModel = State(initialValue: Scatter3DViewModel(beans: beans))
    }

    /// Whether this device can draw the chart at all; the controls are disabled when it cannot.
    private var canDraw3D: Bool {
        if #available(iOS 26, *) { true } else { false }
    }

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean tastings, scored 0 to 10",
            message: summary.headline,
            explanation: """
            PointMark(x:y:z:) places each sample at its acidity, body and sweetness. In 3D, foregroundStyle(by:) \
            draws no legend and ignores a colour scale, so each origin's colour comes from a table the key under the \
            chart is drawn from too. Drag the chart to turn it; symbol, symbolSize, metalness and roughness change \
            only how each point looks, and fully metallic, smooth points mirror a plain, mostly dark scene, so they \
            draw dark with bright highlights.
            """,
            snippets: viewModel.snippets
        ) {
            Scatter3DPanel(viewModel: viewModel, summary: summary)
        } controls: {
            Scatter3DControls(viewModel: viewModel, locale: locale)
                .disabled(!viewModel.hasData || !canDraw3D)
        }
        // Which shape each origin gets is part of what the chart says, so a change is said aloud.
        .onChange(of: viewModel.shapeChoice) {
            AccessibilityNotification.Announcement(viewModel.shapeChangeAnnouncement(locale: locale)).post()
        }
    }
}

/// The chart and its legend, a placeholder when there is no data, or a note on systems before iOS 26.
struct Scatter3DPanel: View {
    let viewModel: Scatter3DViewModel
    let summary: Scatter3DSummary

    var body: some View {
        if !viewModel.hasData {
            ContentUnavailableView(
                "No tastings yet",
                systemImage: "cube",
                description: Text("Each bean sample appears here at its acidity, body and sweetness.")
            )
        } else {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                // snippet:3d-scatter-gate
                if #available(iOS 26, *) {
                    Scatter3DChart(
                        beans: viewModel.beans, origins: viewModel.origins, shapes: viewModel.shapes,
                        symbolSize: viewModel.symbolSize, metalness: viewModel.metalness,
                        roughness: viewModel.roughness, summary: summary
                    )
                } else {
                    // Before iOS 26 there is no Chart3D: say what is missing rather than show nothing.
                    Scatter3DUnavailableView()
                }
                // end
                Scatter3DLegend(origins: viewModel.origins, symbolNames: viewModel.legendSymbolNames)
            }
        }
    }
}

// snippet:3d-scatter-chart
@available(iOS 26, *)
struct Scatter3DChart: View {
    let beans: [BeanTasting]
    let origins: [String]
    /// The solid for each origin, in origin order.
    let shapes: [BeanOriginSolid]
    let symbolSize: Double
    let metalness: Double
    let roughness: Double
    let summary: Scatter3DSummary
    /// Opens turned a little from the front, where acidity against body separates the origins.
    @State private var pose = Chart3DPose(azimuth: .degrees(20), inclination: .degrees(7))
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Chart3D(beans) { bean in
            PointMark(
                x: .value(Scatter3DWording.acidity, bean.acidity),
                y: .value(Scatter3DWording.body, bean.body),
                z: .value(Scatter3DWording.sweetness, bean.sweetness)
            )
            // A fixed colour from the app's table of bean origins, not foregroundStyle(by:): in 3D the encoding
            // draws no legend and ignores chartForegroundStyleScale (seen on iOS 27), so the chart has no colour
            // scale, and only a colour set per point can match the legend drawn from the same table.
            .foregroundStyle(BeanOriginStyle.colour(for: bean.origin))
            .symbol(shape(for: bean.origin).chartSymbol)
            .symbolSize(symbolSize)
            .metalness(metalness)
            .roughness(roughness)
        }
        .chart3DPose($pose)
        .chartXAxisLabel(Scatter3DWording.acidity)
        .chartYAxisLabel(Scatter3DWording.body)
        .chartZAxisLabel(Scatter3DWording.sweetness)
        // Scores run from 0 to 10, so that is every axis's domain; the range makes the chart a cube.
        .chartXScale(domain: Scatter3DWording.scoreRange, range: -0.5 ... 0.5)
        .chartYScale(domain: Scatter3DWording.scoreRange, range: -0.5 ... 0.5)
        .chartZScale(domain: Scatter3DWording.scoreRange, range: -0.5 ... 0.5)
        // end
        // Square, so the cube is sized by the panel's width too: in the panel's taller frame at the largest
        // text sizes it otherwise overflowed both sides and lost its axis titles.
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .accessibilityRepresentation {
            Scatter3DAccessibleChart(summary: summary)
        }
        .accessibilityIdentifier("press-target")
        // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
        // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The pose is
        // this view's state, outside the identity, so it survives.
        .id(colorScheme)
    }

    private func shape(for origin: String) -> BeanOriginSolid {
        guard let index = origins.firstIndex(of: origin), shapes.indices.contains(index) else {
            return BeanOriginStyle.solid(for: origin)
        }
        return shapes[index]
    }
}

/// What assistive technologies get in place of the 3D chart, which gives them nothing: a 2D chart of the same
/// samples, never drawn, with one element per origin and the Audio Graph's descriptor.
struct Scatter3DAccessibleChart: View {
    let summary: Scatter3DSummary

    var body: some View {
        let text = summary.spokenText
        // snippet:3d-scatter-accessibility
        // Inside .accessibilityRepresentation { } on the Chart3D: one element per origin, since the chart
        // is for its clusters, not for sixty separate readings; the descriptor goes on this chart.
        Chart {
            ForEach(Array(summary.groups.enumerated()), id: \.element.origin) { index, group in
                Plot {
                    ForEach(group.beans) { bean in
                        PointMark(
                            x: .value(Scatter3DWording.acidity, bean.acidity),
                            y: .value(Scatter3DWording.body, bean.body)
                        )
                    }
                }
                .accessibilityLabel(text.elements[index].label)
                .accessibilityValue(text.elements[index].value)
            }
        }
        .chartXScale(domain: Scatter3DWording.scoreRange)
        .chartYScale(domain: Scatter3DWording.scoreRange)
        .accessibilityChartDescriptor(Scatter3DChartDescriptor(summary: summary))
        // end
        .accessibilityIdentifier("press-target")
    }
}

// snippet:3d-scatter-legend
/// The key for the colours (and, by origin, the shapes): a 3D chart draws no legend of its own.
/// Its colours come from `BeanOriginStyle`, the same table each point's colour is set from (the chart has
/// no colour scale). It wraps to a column when a row will not fit, so every name stays whole at the
/// largest text sizes.
struct Scatter3DLegend: View {
    let origins: [String]
    let symbolNames: [String]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Layout.sectionSpacing) {
                Scatter3DLegendEntries(origins: origins, symbolNames: symbolNames)
            }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Scatter3DLegendEntries(origins: origins, symbolNames: symbolNames)
            }
        }
        .font(.caption)
        // The elements in place of the chart already name each origin's samples.
        .accessibilityHidden(true)
    }
}

// end

struct Scatter3DLegendEntries: View {
    let origins: [String]
    let symbolNames: [String]

    var body: some View {
        ForEach(Array(origins.enumerated()), id: \.element) { index, origin in
            Label {
                Text(origin)
                    .fixedSize()
            } icon: {
                Image(systemName: symbolNames.indices.contains(index) ? symbolNames[index] : BeanOriginStyle.symbolName(for: origin))
                    .foregroundStyle(BeanOriginStyle.colour(for: origin))
            }
        }
    }
}

/// The shape menu in a `LabeledContent` row; at the accessibility text sizes the row overlapped the slider
/// below it (rendered on iOS 27), so there the title goes above the menu instead.
struct Scatter3DShapePicker: View {
    @Binding var selection: Scatter3DShapeChoice
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text("Shape")
                    .accessibilityHidden(true)
                Scatter3DShapeMenu(selection: $selection)
            }
        } else {
            // The menu's own label already says "Shape", so the row's visible title is hidden from
            // VoiceOver, which otherwise read "Shape, Shape, By origin".
            LabeledContent {
                Scatter3DShapeMenu(selection: $selection)
            } label: {
                Text("Shape")
                    .accessibilityHidden(true)
            }
        }
    }
}

struct Scatter3DShapeMenu: View {
    @Binding var selection: Scatter3DShapeChoice

    var body: some View {
        Picker("Shape", selection: $selection) {
            ForEach(Scatter3DShapeChoice.allCases) { choice in
                Text(choice.title).tag(choice)
            }
        }
        .pickerStyle(.menu)
    }
}

/// Shown before iOS 26, where there are no 3D charts.
struct Scatter3DUnavailableView: View {
    var body: some View {
        ContentUnavailableView(
            "3D charts need iOS 26",
            systemImage: "cube.transparent",
            description: Text("Chart3D, PointMark(x:y:z:) and the 3D symbol and material modifiers start in iOS 26.")
        )
    }
}

/// The shape picker and the three sliders.
struct Scatter3DControls: View {
    @Bindable var viewModel: Scatter3DViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            Scatter3DShapePicker(selection: $viewModel.shapeChoice)
            LabeledSlider(
                title: "Symbol size", value: $viewModel.symbolSize, range: Scatter3DDefaults.symbolSizeRange,
                step: Scatter3DDefaults.symbolSizeStep, valueText: viewModel.symbolSizeText(locale: locale)
            )
            LabeledSlider(
                title: "Metalness", value: $viewModel.metalness, range: 0 ... 1,
                step: Scatter3DDefaults.materialStep, valueText: viewModel.metalnessText(locale: locale)
            )
            LabeledSlider(
                title: "Roughness", value: $viewModel.roughness, range: 0 ... 1,
                step: Scatter3DDefaults.materialStep, valueText: viewModel.roughnessText(locale: locale)
            )
        }
    }
}

#Preview("Bean tastings") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/3d-scatter") {
            Scatter3DScreen(screen: screen)
        }
    }
}

#Preview("No tastings") {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/3d-scatter") {
            Scatter3DScreen(screen: screen, beans: [])
        }
    }
}
