import Accessibility
import Charts
import SwiftUI

/// "Symbol shapes": the eight built-in shapes, their outlines, and a custom `ChartSymbolShape`.
struct SymbolShapesScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = SymbolShapesViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Wait for an order, by queue",
            message: summary.headline,
            explanation: """
            A point's symbol is a ChartSymbolShape. Eight are built in, strokeBorder turns one into an outline, \
            and a Shape of your own becomes one by saying in perceptualUnitRect how much of the symbol's square \
            it should fill to look the size of the others. The picker sets the shape of the last café in the legend; \
            the other keeps a circle, or takes a square when the circle is picked, so the cafés never differ by colour alone.
            """,
            snippets: viewModel.snippets
        ) {
            SymbolShapesChart(
                cafes: viewModel.cafes,
                summary: summary,
                symbols: CafeSymbolScale(
                    pickedCafe: viewModel.pickedCafe,
                    picked: viewModel.shape,
                    reference: viewModel.referenceShape,
                    isOutlined: viewModel.isOutlined,
                    unitScale: viewModel.unitScale
                )
            )
        } controls: {
            SymbolShapesControls(viewModel: viewModel)
        }
        // The shapes changing is only seen, so it is also said.
        .onChange(of: viewModel.symbolDescription) { _, description in
            AccessibilityNotification.Announcement(description).post()
        }
    }
}

/// Sizes that belong to this chart's marks.
private nonisolated enum SymbolMetrics {
    /// The area of each symbol, in square points.
    static let symbolArea: CGFloat = 80
    static let outlineWidth: CGFloat = 2
    /// Keeps the symbols at the shortest and longest queue inside the plot.
    static let plotPadding: CGFloat = 10
    /// How wide the cup's base is, as a fraction of its rim.
    static let cupBaseRatio: CGFloat = 0.55
}

/// A scatter plot of orders, one symbol shape per café, or a placeholder when there are no orders.
struct SymbolShapesChart: View {
    let cafes: [CafeOrders]
    let summary: OrderWaitSummary
    let symbols: CafeSymbolScale

    /// The queue axis: from zero to the longest queue, not to the next round number past it.
    /// When every queue is zero it still needs some width, so it never ends below one.
    nonisolated static func queueDomain(for cafes: [CafeOrders]) -> ClosedRange<Int> {
        0 ... max(cafes.flatMap(\.orders).map(\.queueLength).max() ?? 0, 1)
    }

    var body: some View {
        if cafes.isEmpty {
            ContentUnavailableView(
                "No orders yet",
                systemImage: "cup.and.saucer",
                description: Text("Each order appears here as a point: the queue when it was placed and the wait that followed.")
            )
        } else {
            // snippet:symbol-shapes-chart
            Chart {
                ForEach(cafes) { cafe in
                    ForEach(cafe.portions) { portion in
                        // One accessibility element per stretch of the queue axis, not one per point.
                        Plot {
                            // A clear band the full height of the plot over the stretch: every element then has
                            // the same top, so they are visited along the queue axis, not by the highest wait.
                            RectangleMark(
                                xStart: .value("Queue", portion.shortestQueue),
                                xEnd: .value("Queue", portion.longestQueue)
                            )
                            .foregroundStyle(.clear)
                            ForEach(portion.orders) { order in
                                PointMark(
                                    x: .value("Queue", order.queueLength),
                                    y: .value("Wait", order.waitSeconds)
                                )
                            }
                        }
                        .accessibilityLabel(portion.accessibilityLabel(locale: summary.locale))
                        .accessibilityValue(portion.accessibilityValue(locale: summary.locale))
                    }
                    // Colour and shape together: the shape is what still tells the cafés apart without colour.
                    .foregroundStyle(by: .value("Café", cafe.name))
                    .symbol(by: .value("Café", cafe.name))
                }
                .symbolSize(SymbolMetrics.symbolArea)
            }
            // Which shape each café gets. The legend draws the same shapes.
            .chartSymbolScale(domain: cafes.map(\.name)) { cafe in
                symbols.symbol(for: cafe)
            }
            // end
            // Each café in its colour on every screen that draws the two; the shapes are this screen's own.
            .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
            .chartXScale(domain: Self.queueDomain(for: cafes), range: .plotDimension(padding: SymbolMetrics.plotPadding))
            .chartXAxisLabel(CafeWording.queueAxisTitle)
            .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
            // One wait axis for the chart and the descriptor.
            .chartYScale(domain: summary.waitDomain)
            .accessibilityChartDescriptor(OrderWaitChartDescriptor(cafes: cafes, summary: summary))
        }
    }
}

/// The symbol scale's mapping: the picked shape for one café and the reference shape for the others.
nonisolated struct CafeSymbolScale {
    let pickedCafe: String
    let picked: SymbolChoice
    let reference: SymbolChoice
    let isOutlined: Bool
    let unitScale: Double

    /// Filled, outlined and custom symbols are different types, so the one that is returned is erased.
    func symbol(for cafe: String) -> AnyChartSymbolShape {
        let choice = cafe == pickedCafe ? picked : reference
        if let builtIn = choice.builtInShape {
            return isOutlined ? outlined(builtIn) : AnyChartSymbolShape(builtIn)
        }
        let cup = CupSymbol(unitScale: unitScale)
        return isOutlined ? outlined(cup) : AnyChartSymbolShape(cup)
    }

    // snippet:symbol-shapes-outlined
    /// `strokeBorder` draws a built-in shape as an outline, which keeps overlapping points readable.
    func outlined(_ shape: BasicChartSymbolShape) -> AnyChartSymbolShape {
        AnyChartSymbolShape(shape.strokeBorder(lineWidth: SymbolMetrics.outlineWidth))
    }

    // end

    // snippet:symbol-shapes-custom-outlined
    /// The cup is an `InsettableShape`, so it has `strokeBorder` as the built-in shapes do.
    func outlined(_ cup: CupSymbol) -> AnyChartSymbolShape {
        AnyChartSymbolShape(cup.strokeBorder(lineWidth: SymbolMetrics.outlineWidth))
    }
    // end
}

nonisolated extension SymbolChoice {
    // snippet:symbol-shapes-built-in
    /// The eight shapes Swift Charts provides. The custom shape is not one of them.
    var builtInShape: BasicChartSymbolShape? {
        switch self {
        case .circle: .circle
        case .square: .square
        case .triangle: .triangle
        case .diamond: .diamond
        case .pentagon: .pentagon
        case .plus: .plus
        case .cross: .cross
        case .asterisk: .asterisk
        case .custom: nil
        }
    }
    // end
}

// snippet:symbol-shapes-custom
/// A symbol the framework does not provide: a cup, wider at the rim than at the base.
nonisolated struct CupSymbol: ChartSymbolShape, InsettableShape {
    /// The side of `perceptualUnitRect`, as a fraction of the unit square.
    var unitScale: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let box = rect.insetBy(dx: inset, dy: inset)
        let halfBase = box.width * SymbolMetrics.cupBaseRatio / 2
        var path = Path()
        path.move(to: CGPoint(x: box.minX, y: box.minY))
        path.addLine(to: CGPoint(x: box.maxX, y: box.minY))
        path.addLine(to: CGPoint(x: box.midX + halfBase, y: box.maxY))
        path.addLine(to: CGPoint(x: box.midX - halfBase, y: box.maxY))
        path.closeSubpath()
        return path
    }

    /// What `strokeBorder` needs: the same shape, drawn smaller by the given amount.
    func inset(by amount: CGFloat) -> CupSymbol {
        CupSymbol(unitScale: unitScale, inset: inset + amount)
    }

    /// The part of the unit square the shape is drawn in. A shape that fills its square looks bigger
    /// than a circle of the same symbol size, so it is given less of it.
    var perceptualUnitRect: CGRect {
        CGRect(x: 0.5 - unitScale / 2, y: 0.5 - unitScale / 2, width: unitScale, height: unitScale)
    }
}

// end

/// The shape picker, the outline switch, and the slider for the custom shape's unit rect.
struct SymbolShapesControls: View {
    @Bindable var viewModel: SymbolShapesViewModel

    var body: some View {
        ControlsSection {
            // The kit's menu picker: its title is read once, with the shape as its value.
            LabeledMenuPicker(
                title: viewModel.hasOrders ? "\(viewModel.pickedCafe)'s symbol" : "Symbol", selection: $viewModel.shape
            ) {
                ForEach(SymbolChoice.allCases) { choice in
                    Text(choice.title).tag(choice)
                }
            }
            Toggle("Outlined", isOn: $viewModel.isOutlined)
            UnitRectSlider(viewModel: viewModel)
        }
    }
}

/// The slider for the side of the custom shape's `perceptualUnitRect`, with its value and what it does.
struct UnitRectSlider: View {
    @Bindable var viewModel: SymbolShapesViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            LabeledContent("Custom shape's unit rect", value: viewModel.unitScaleText)
                .accessibilityHidden(true)
            Slider(
                value: $viewModel.unitScale,
                in: SymbolShapesViewModel.unitScaleRange,
                step: SymbolShapesViewModel.unitScaleStep
            ) {
                Text("Custom shape's unit rect")
            }
            .accessibilityValue(viewModel.unitScaleText)
            .disabled(!viewModel.isUnitScaleEditable)
            Text(viewModel.unitScaleNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The chart for the Audio Graph: a number on both axes, and a named series per café.
/// Not tied to the main actor: the accessibility system calls its value descriptions when it chooses.
nonisolated struct OrderWaitChartDescriptor: AXChartDescriptorRepresentable {
    let cafes: [CafeOrders]
    let summary: OrderWaitSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        // Both drawn scales: the queue axis ends at the longest queue (the chart's own domain), the wait axis at
        // its rounded top.
        let queueDomain = SymbolShapesChart.queueDomain(for: cafes)
        let xAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.queueAxisTitle,
            range: Double(queueDomain.lowerBound) ... Double(queueDomain.upperBound),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.people) }
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.waitAxisTitle,
            range: summary.waitDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale, as: CafeWording.seconds) }
        let series = cafes.map { cafe in
            AXDataSeriesDescriptor(
                name: cafe.name,
                isContinuous: false,
                dataPoints: cafe.orders.map { AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds)) }
            )
        }
        return AXChartDescriptor(
            title: "Wait for an order against the queue when it was placed, by café",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Symbol shapes") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/symbol-shapes") {
            SymbolShapesScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    SymbolShapesChart(
        cafes: [],
        summary: OrderWaitSummary(orders: [], locale: .current),
        symbols: CafeSymbolScale(pickedCafe: "", picked: .square, reference: .circle, isOutlined: false, unitScale: 0.75)
    )
}
