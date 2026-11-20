import Accessibility
import Charts
import SwiftUI

/// "Dynamic Type": what a chart has to do as text grows, on a chart with a date axis and a legend and on
/// horizontal bars, following the device's text size or one forced on the chart alone, and a mistake
/// toggle that drops every adjustment.
struct DynamicTypeChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = DynamicTypeChartViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let words = viewModel.words(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: words.caption(for: viewModel.kind),
            message: words.headline(for: viewModel.kind),
            explanation: """
            The framework's axis labels and legend grow with Dynamic Type, but nothing else about the chart \
            does: the same number of labels has to fit, the legend wraps from XXX Large up but still clips or \
            drops a name and takes its extra lines from the plot, and a fixed height leaves less of it for the \
            marks. So the date axis asks for fewer labels and then shorter ones as the text grows, the legend \
            is the app's own and wraps whole names below the chart, and each chart's \
            height grows with its text, which keeps the bars' names readable above their rows. To hear the \
            chart, turn VoiceOver on, swipe through it, and use the rotor's Audio Graph: Describe chart, \
            then Play Audio Graph.
            """,
            snippets: viewModel.snippets
        ) {
            DynamicTypeChartPanelContent(viewModel: viewModel, words: words)
                // At "This device's size" nothing is forced, so the chart follows the device's own text size.
                .chartEnvironment(viewModel.chartEnvironment)
        } controls: {
            DynamicTypeChartControls(viewModel: viewModel, words: words)
        }
    }
}

/// The controls: the text size forced on the chart, which chart, and the mistake.
private struct DynamicTypeChartControls: View {
    @Bindable var viewModel: DynamicTypeChartViewModel
    let words: DynamicTypeChartWords
    /// The device's own size, which the chart follows when nothing is forced on it.
    @Environment(\.dynamicTypeSize) private var deviceSize

    var body: some View {
        ControlsSection {
            LabeledContent {
                Picker("Text size", selection: $viewModel.textSize) {
                    ForEach(DynamicTypeChartTextSize.allCases) { size in
                        Text(size.title).tag(size)
                    }
                }
                .pickerStyle(.menu)
            } label: {
                // The picker already speaks "Text size": the row's visible title is not read twice.
                Text("Text size")
                    .accessibilityHidden(true)
            }
            // With nothing drawn there is nothing for a text size or the mistake to change.
            .disabled(viewModel.isEmpty)
            LabeledSegmentedPicker(title: "Chart", selection: $viewModel.kind) {
                ForEach(DynamicTypeChartKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            MistakeToggle(title: "Leave out the adjustments", isShowingMistake: $viewModel.isShowingMistake)
                .disabled(viewModel.isEmpty)
            if viewModel.isShowingMistake, !viewModel.isEmpty {
                Text(DynamicTypeChartMistakeNote.text(
                    for: viewModel.kind,
                    size: viewModel.textSize.dynamicTypeSize ?? deviceSize
                ))
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .onChange(of: viewModel.kind) {
            // A different chart: say so, then its headline. The text size and the mistake restyle
            // the same data and speak their own values, so they are not announced.
            AccessibilityNotification.Announcement(words.announcement(for: viewModel.kind)).post()
        }
    }
}

/// What is wrong with the chart while the mistake is shown, in words true at the text size in effect.
enum DynamicTypeChartMistakeNote {
    static func text(for kind: DynamicTypeChartKind, size: DynamicTypeSize) -> String {
        // Below Accessibility 1 the default size's choices still fit, so the mistake draws nothing wrong.
        let notYet = size < .accessibility1
            ? "At this text size nothing goes wrong yet: choose Accessibility 1 or larger to see the mistake. "
            : ""
        return notYet + problem(for: kind)
    }

    private static func problem(for kind: DynamicTypeChartKind) -> String {
        switch kind {
        case .dates:
            "A label every week, the framework's legend and a fixed height, as chosen for the default size. "
                + "At the larger accessibility sizes the weekly labels no longer fit and are cut to \"Ma…\" or "
                + "\"…\", the legend wraps but cuts off or drops a name, and the labels and legend take their height "
                + "from the plot until the bars are a strip and the value labels overlap."
        case .bars:
            "The chart keeps the panel's fixed height. The drink names sit inside the plot above each bar and "
                + "take their height from the rows, so as they grow the bars shrink to thin strips under them, "
                + "and the value labels run into each other."
        }
    }
}

/// The chart in the panel. The panel's height follows the device's text size, not the size forced on
/// the chart, so a chart that grows with its text scrolls inside it.
private struct DynamicTypeChartPanelContent: View {
    let viewModel: DynamicTypeChartViewModel
    let words: DynamicTypeChartWords

    var body: some View {
        if viewModel.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                // The headline above already says nothing sold; this says what will appear.
                description: Text(words.placeholderDescription(for: viewModel.kind))
            )
        } else {
            ScrollView {
                switch viewModel.kind {
                case .dates:
                    DynamicTypeChartDatesChart(words: words, isShowingMistake: viewModel.isShowingMistake)
                case .bars:
                    DynamicTypeChartBarsChart(words: words, isShowingMistake: viewModel.isShowingMistake)
                }
            }
            .scrollBounceBehavior(.basedOnSize)
        }
    }
}

/// Sizes that belong to these charts' marks and legend.
private enum DynamicTypeChartMetrics {
    /// The height the date labels take at the default size.
    static let dateLabelAllowance: CGFloat = 24
    /// Room above the top value, so the top label, centred on it, is not cut off by the chart's frame.
    static let topLabelRoom: CGFloat = 8
    /// The height the framework's legend takes at the default size, inside a fixed-height chart.
    static let legendAllowance: CGFloat = 24
    /// The height one bar's name takes above it at the default size.
    static let barNameAllowance: CGFloat = 20
    static let legendSwatchSize: CGFloat = 8
    static let legendEntrySpacing: CGFloat = 12
    /// The empty strip between neighbouring segments of a stack.
    static let segmentGap: CGFloat = 0.5
}

/// Each drink's colour, the app's own (`CafeDrinkStyle`): one source for the chart's colour scale and for the legend
/// drawn beside it.
enum DynamicTypeChartDrinkColours {
    static func colour(for drink: String) -> Color {
        CafeDrinkStyle.colour(for: drink)
    }
}

/// The panel's height in this size class: the height a chart that does not grow keeps.
private struct DynamicTypeChartPanelHeight {
    let sizeClass: UserInterfaceSizeClass?

    var value: CGFloat {
        sizeClass == .regular ? Layout.chartHeightRegular : Layout.chartHeightCompact
    }
}

/// The Harbour café's cups a day, stacked by drink, over a date axis, with a legend.
struct DynamicTypeChartDatesChart: View {
    let words: DynamicTypeChartWords
    let isShowingMistake: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // snippet:dynamic-type-height
    /// The room the date labels take, scaled with the text size in effect on the chart.
    @ScaledMetric(relativeTo: .caption) private var labelAllowance = DynamicTypeChartMetrics.dateLabelAllowance
    /// Half the top value label grows with the text, so the room kept above it grows too.
    @ScaledMetric(relativeTo: .caption) private var topLabelRoom = DynamicTypeChartMetrics.topLabelRoom

    /// The chart's height without its legend, which sits below it and takes the height it needs: the
    /// plot keeps the height it has at the default size, and the date labels get however much they grew.
    private var chartHeight: CGFloat {
        let fixed = DynamicTypeChartPanelHeight(sizeClass: horizontalSizeClass).value
        let grows = !isShowingMistake || DynamicTypeChartUnadjusted.growsWithText
        let withoutLegend = fixed - DynamicTypeChartMetrics.legendAllowance
        return grows ? withoutLegend + labelAllowance - DynamicTypeChartMetrics.dateLabelAllowance : fixed
    }

    // end

    private var dateLabels: DynamicTypeChartDateLabels {
        isShowingMistake ? DynamicTypeChartUnadjusted.dateLabels : .forSize(dynamicTypeSize)
    }

    private var valueLabels: [Double]? {
        isShowingMistake
            ? DynamicTypeChartUnadjusted.valueLabels
            : DynamicTypeChartValueLabels.values(for: dynamicTypeSize, domain: words.dateValueDomain)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            // snippet:dynamic-type-dates-chart
            Chart {
                ForEach(words.weeks) { week in
                    // One element per week. The clear band is the full height of the plot, so VoiceOver
                    // meets the weeks in date order whatever their bars' heights.
                    Plot {
                        RectangleMark(
                            xStart: .value(CafeWording.day, week.start),
                            xEnd: .value(CafeWording.day, week.endOfLastDay)
                        )
                        .foregroundStyle(.clear)
                        ForEach(week.rows) { row in
                            BarMark(
                                x: .value(CafeWording.day, row.day, unit: .day, calendar: CafeData.calendar),
                                y: .value(CafeWording.cups, row.cups)
                            )
                            .foregroundStyle(by: .value(CafeWording.drink, row.drink))
                            // A strip of empty space between neighbouring segments.
                            .clipShape(Rectangle().inset(by: DynamicTypeChartMetrics.segmentGap))
                        }
                    }
                    .accessibilityLabel(words.weekLabel(week))
                    .accessibilityValue(words.weekValue(week))
                }
            }
            .chartForegroundStyleScale(domain: words.stackedDrinks) { DynamicTypeChartDrinkColours.colour(for: $0) }
            // The domain ends on the top label's value: padding the range keeps that label whole.
            .chartYScale(domain: words.dateValueDomain, range: .plotDimension(endPadding: topLabelRoom))
            .chartXAxis {
                // An exact list is drawn in full, so the list itself is thinned as the text grows.
                AxisMarks(values: dateLabels.labelledDays(of: words.days)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: dateLabels.format(locale: words.locale))
                }
            }
            .chartYAxis {
                if let valueLabels {
                    AxisMarks(values: valueLabels)
                } else {
                    AxisMarks()
                }
            }
            // The framework's legend wraps, but at the accessibility sizes it clips or drops a name and
            // takes its lines from the plot: in its place, the app's own, below, which wraps whole names.
            .chartLegend(isShowingMistake ? DynamicTypeChartUnadjusted.legend : .hidden)
            // end
            .accessibilityChartDescriptor(DynamicTypeChartDatesDescriptor(words: words))
            .frame(height: chartHeight)
            if !isShowingMistake {
                DynamicTypeChartLegend(drinks: words.stackedDrinks)
            }
        }
    }
}

// snippet:dynamic-type-legend
/// A legend that wraps: entries run across and start a new line when the next one does not fit.
/// Its colours come from the same table as the chart's colour scale.
private struct DynamicTypeChartLegend: View {
    let drinks: [String]
    @ScaledMetric(relativeTo: .caption) private var swatchSize = DynamicTypeChartMetrics.legendSwatchSize

    var body: some View {
        DynamicTypeChartFlowLayout(spacing: DynamicTypeChartMetrics.legendEntrySpacing, lineSpacing: Layout.tightSpacing) {
            ForEach(drinks, id: \.self) { drink in
                Label {
                    Text(drink)
                } icon: {
                    Circle()
                        .fill(DynamicTypeChartDrinkColours.colour(for: drink))
                        .frame(width: swatchSize, height: swatchSize)
                }
                .labelStyle(DynamicTypeChartLegendEntryStyle())
            }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        // The framework's legend is not an element either: the drinks are named in each week's value
        // and in the Audio Graph.
        .accessibilityHidden(true)
    }
}

// end

/// A swatch beside its name, close together, centred on the line.
private struct DynamicTypeChartLegendEntryStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Layout.tightSpacing) {
            configuration.icon
            configuration.title
        }
    }
}

/// Lays its views out in lines, left to right, starting a new line when the next view does not fit.
private struct DynamicTypeChartFlowLayout: SwiftUI.Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
        let frames = frames(for: subviews, width: proposal.width ?? .infinity)
        let width = frames.map(\.maxX).max() ?? 0
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout Void) {
        for (subview, frame) in zip(subviews, frames(for: subviews, width: bounds.width)) {
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(frame.size)
            )
        }
    }

    private func frames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        var frames: [CGRect] = []
        var origin = CGPoint.zero
        var lineHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(ProposedViewSize(width: width, height: nil))
            if origin.x > 0, origin.x + size.width > width {
                origin = CGPoint(x: 0, y: origin.y + lineHeight + lineSpacing)
                lineHeight = 0
            }
            frames.append(CGRect(origin: origin, size: CGSize(width: min(size.width, width), height: size.height)))
            origin.x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }
        return frames
    }
}

/// Today's cups by drink as horizontal bars, each name inside the plot above its bar.
struct DynamicTypeChartBarsChart: View {
    let words: DynamicTypeChartWords
    let isShowingMistake: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    // snippet:dynamic-type-bar-height
    /// The height a name takes above its bar, scaled with the text size in effect on the chart.
    @ScaledMetric(relativeTo: .caption) private var nameAllowance = DynamicTypeChartMetrics.barNameAllowance

    /// The panel's height at the default size, plus however much each row's name, and the axis's
    /// labels, have grown: the bars keep their thickness.
    private var height: CGFloat {
        let fixed = DynamicTypeChartPanelHeight(sizeClass: horizontalSizeClass).value
        let grows = !isShowingMistake || DynamicTypeChartUnadjusted.growsWithText
        let growth = (nameAllowance - DynamicTypeChartMetrics.barNameAllowance) * CGFloat(words.drinks.count + 1)
        return grows ? fixed + growth : fixed
    }

    // end

    private var valueLabels: [Double]? {
        isShowingMistake
            ? DynamicTypeChartUnadjusted.valueLabels
            : DynamicTypeChartValueLabels.values(for: dynamicTypeSize, domain: words.barValueDomain)
    }

    var body: some View {
        // snippet:dynamic-type-bars-chart
        Chart(words.drinks) { drink in
            Plot {
                BarMark(x: .value(CafeWording.cups, drink.cups), y: .value(CafeWording.drink, drink.drink))
            }
            .accessibilityLabel(words.barLabel(drink))
            .accessibilityValue(words.barValue(drink))
        }
        .chartXScale(domain: words.barValueDomain)
        .chartXAxis {
            if let valueLabels {
                AxisMarks(values: valueLabels)
            } else {
                AxisMarks()
            }
        }
        // The names stay inside the plot, where they have the chart's whole width; the chart grows
        // taller instead, so each row keeps room for its bar.
        .frame(height: height)
        // end
        .accessibilityChartDescriptor(DynamicTypeChartBarsDescriptor(words: words))
    }
}

#Preview("Screen") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/dynamic-type") {
            DynamicTypeChartScreen(screen: screen)
        }
    }
}

#Preview("Dates at Accessibility 5") {
    DynamicTypeChartDatesChart(
        words: DynamicTypeChartViewModel().words(locale: .current),
        isShowingMistake: false
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}

#Preview("Bars, the mistake, at Accessibility 5") {
    DynamicTypeChartBarsChart(
        words: DynamicTypeChartViewModel().words(locale: .current),
        isShowingMistake: true
    )
    .padding()
    .environment(\.dynamicTypeSize, .accessibility5)
}
