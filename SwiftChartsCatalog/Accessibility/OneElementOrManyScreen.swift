import Accessibility
import Charts
import SwiftUI

/// "One element or many": how much of a chart one accessibility element covers, chosen by the chart's purpose.
struct OneElementOrManyScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: OneElementOrManyViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and times
    /// the way the chart's own axes do.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, data: OneElementOrManyData = OneElementOrManyData()) {
        self.screen = screen
        _viewModel = State(initialValue: OneElementOrManyViewModel(data: data))
    }

    var body: some View {
        let text = viewModel.text(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: OneElementOrManyStyle.caption(viewModel.choice),
            message: text.headline(viewModel.choice),
            explanation: """
            How much of a chart one accessibility element covers depends on what the chart is for. \
            For exact values per item, one element per mark; for the overall shape, one per meaningful portion, \
            each summarised with units; for a small preview, one element for the whole chart, which also removes its Audio Graph.
            """,
            snippets: viewModel.snippets
        ) {
            OneElementOrManyChart(viewModel: viewModel, text: text, locale: locale)
        } controls: {
            ControlsSection {
                LabeledSegmentedPicker(title: "One element covers", selection: $viewModel.choice) {
                    ForEach(OneElementOrManyChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                .disabled(!viewModel.hasAnythingToDraw(locale: locale))
            }
            OneElementOrManySpokenSection(choice: viewModel.choice, text: text)
        }
        // A different chart, with different elements, is drawn: say so, then the headline.
        .onChange(of: viewModel.choice) { _, choice in
            OneElementOrManyStyle.announce(text.announcement(choice))
        }
    }
}

/// The chart for the current choice, or a placeholder when it has nothing to draw.
struct OneElementOrManyChart: View {
    let viewModel: OneElementOrManyViewModel
    let text: OneElementOrManySpokenText
    let locale: Locale

    var body: some View {
        if !text.drawsChart(viewModel.choice), viewModel.choice == .eachPortion, text.ordersTotal > 0 {
            ContentUnavailableView(
                "No parts of the day",
                systemImage: "clock",
                description: Text("Orders are grouped here by the named parts of the day, and none of them holds an order.")
            )
        } else if !text.drawsChart(viewModel.choice) {
            ContentUnavailableView(
                viewModel.choice == .eachMark ? "No cups sold yet" : "No orders yet",
                systemImage: "cup.and.saucer",
                description: Text(viewModel.choice == .eachMark
                    ? "Cups sold today appear here, one bar per drink."
                    : "Orders appear here, half hour by half hour.")
            )
        } else {
            switch viewModel.choice {
            case .eachMark: OneElementOrManyMarkChart(text: text, locale: locale)
            case .eachPortion: OneElementOrManyPortionChart(text: text, locale: locale)
            case .wholeChart: OneElementOrManyPreview(text: text, open: viewModel.openFullChart)
            }
        }
    }
}

/// Exact values per item: one element per bar.
struct OneElementOrManyMarkChart: View {
    let text: OneElementOrManySpokenText
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // snippet:one-element-or-many-each-mark
        Chart(text.drinks) { sale in
            // One labelled Plot per bar: each bar is one element, read with its exact value and its unit.
            Plot {
                BarMark(
                    x: .value(CafeWording.drink, sale.drink),
                    y: .value(CafeWording.cupsAxisTitle, sale.cups)
                )
            }
            .accessibilityLabel(text.markLabel(sale))
            .accessibilityValue(text.markValue(sale))
        }
        // One domain for the drawn scale and the descriptor's range.
        .chartYScale(domain: 0 ... text.cupsTop)
        .accessibilityChartDescriptor(OneElementOrManyChartDescriptor(graph: text.markGraph, locale: locale))
        // end
        // At the accessibility sizes the drink names are cut to a letter and an ellipsis: turn them upright.
        .chartXAxis {
            AxisMarks { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(orientation: dynamicTypeSize.isAccessibilitySize ? .vertical : .horizontal)
            }
        }
    }
}

/// The overall shape: one element per part of the day, each summarising its half hours with units.
struct OneElementOrManyPortionChart: View {
    let text: OneElementOrManySpokenText
    let locale: Locale

    var body: some View {
        // snippet:one-element-or-many-each-portion
        Chart {
            ForEach(text.portions) { portion in
                // One Plot per part of the day: one element over that stretch, however many marks it holds.
                Plot {
                    // A band the full height of the plot, faint on every other part. It shows where each part
                    // starts and ends, and gives every element the same top edge, so they are read along x.
                    // On iOS 27 they were read in time order, Early to Close.
                    RectangleMark(
                        xStart: .value(TimeOfDayWording.timeOfDay, portion.startHour),
                        xEnd: .value(TimeOfDayWording.timeOfDay, portion.endHour)
                    )
                    .foregroundStyle(portion.isShaded ? OneElementOrManyStyle.band : .clear)
                    // The line is still drawn as one line through every part.
                    ForEach(portion.halfHours) { halfHour in
                        LineMark(
                            x: .value(TimeOfDayWording.timeOfDay, halfHour.hour),
                            y: .value(CafeWording.orders, halfHour.orders)
                        )
                    }
                }
                .accessibilityLabel(text.portionLabel(portion))
                .accessibilityValue(text.portionValue(portion))
            }
        }
        .chartYScale(domain: 0 ... text.ordersTop)
        // The Audio Graph still gets every half hour: labels on Plots change the elements only.
        .accessibilityChartDescriptor(OneElementOrManyChartDescriptor(graph: text.portionGraph, locale: locale))
        // end
        .timeOfDayAxis(locale: locale)
        .chartYAxisLabel(CafeWording.orders, position: .top, alignment: .leading)
    }
}

/// A small preview that opens the fuller chart: one element for the whole thing.
struct OneElementOrManyPreview: View {
    let text: OneElementOrManySpokenText
    let open: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: Layout.itemSpacing))
            : AnyLayout(HStackLayout(spacing: Layout.itemSpacing))
        // snippet:one-element-or-many-whole-chart
        Button(action: open) {
            layout {
                VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                    Text("Orders today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(CafeWording.orders(text.ordersTotal, locale: text.locale))
                        .font(.title2.weight(.semibold))
                }
                if !dynamicTypeSize.isAccessibilitySize {
                    Spacer(minLength: 0)
                }
                // Static and bare: no axes, no grid, no selection. The detail is a tap away.
                Chart(text.halfHours) { halfHour in
                    LineMark(
                        x: .value(TimeOfDayWording.timeOfDay, halfHour.hour),
                        y: .value(CafeWording.orders, halfHour.orders)
                    )
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .chartXScale(domain: TimeOfDayWording.dayHours)
                .chartYScale(domain: 0 ... text.ordersTop)
                .frame(width: OneElementOrManyStyle.previewWidth, height: OneElementOrManyStyle.previewHeight)
            }
            .padding(Layout.panelPadding)
            .background(Color(.tertiarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
        }
        .buttonStyle(.plain)
        // One succinct description for the whole thing. This also removes the chart's Audio Graph.
        .accessibilityElement(children: .ignore)
        // Ignoring the children drops the Button's trait too: give it back, or it is read as plain text.
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(text.previewLabel)
        .accessibilityValue(text.previewValue)
        // end
        .frame(maxHeight: .infinity)
    }
}

/// What the current choice gives VoiceOver and the Audio Graph, as read on iOS 27, and how to hear it.
struct OneElementOrManySpokenSection: View {
    let choice: OneElementOrManyChoice
    let text: OneElementOrManySpokenText

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("What VoiceOver reads")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("Read on the iPhone 17 simulator, iOS 27")
                .font(.caption)
                .foregroundStyle(.secondary)
            let elements = text.elements(choice)
            if elements.isEmpty {
                Text("Nothing in the chart: the placeholder is read instead.")
            }
            ForEach(elements) { element in
                OneElementOrManyElementRow(element: element)
            }
            Text("What the Audio Graph gets")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, Layout.itemSpacing)
            Text("Read on the iPhone 17 simulator, iOS 27")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text.audioGraphEffect(choice))
                .font(.subheadline)
            if let graph = text.audioGraph(choice) {
                OneElementOrManyAudioGraphRows(graph: graph, locale: text.locale)
            }
            Text(choice == .wholeChart
                ? "To hear it on a device: turn VoiceOver on and swipe to the preview. It is one stop, and the rotor offers no Audio Graph for it."
                : "To hear it on a device: turn VoiceOver on and swipe through the chart, then open the rotor's Audio Graph: Describe chart, Play Audio Graph.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, Layout.itemSpacing)
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// One element: its label, then its value, then any trait, in the order VoiceOver reads them.
struct OneElementOrManyElementRow: View {
    let element: OneElementOrManyElement

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(element.label)
                .font(.subheadline.weight(.semibold))
            Text([element.value, element.trait].compactMap(\.self).joined(separator: ". "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The chart descriptor's contents, as plain lines.
struct OneElementOrManyAudioGraphRows: View {
    let graph: OneElementOrManyAudioGraph
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            OneElementOrManyFactRow(name: "Title", fact: graph.title)
            OneElementOrManyFactRow(name: "Summary", fact: graph.summary)
            OneElementOrManyFactRow(
                name: "X axis",
                fact: "\(graph.xAxisTitle): \(categories)"
            )
            OneElementOrManyFactRow(name: "Y axis", fact: "\(graph.yAxisTitle), \(range)")
            OneElementOrManyFactRow(
                name: "Series",
                fact: "\(graph.seriesName), \(graph.isContinuous ? "continuous" : "separate points"), "
                    + "\(graph.points.count.formatted(.number.locale(locale))) values"
            )
            if let first = graph.points.first {
                OneElementOrManyFactRow(
                    name: "Values said as",
                    fact: "\(first.category), \(OneElementOrManyAudioGraph.valueDescription(first.value, unit: graph.unit, locale: locale))"
                )
            }
        }
        .font(.subheadline)
    }

    /// A few categories in full; many as the first and last, and how many.
    private var categories: String {
        guard graph.categories.count > OneElementOrManyStyle.categoriesListedInFull,
              let first = graph.categories.first, let last = graph.categories.last
        else { return CafeWording.list(graph.categories) }
        return "\(first) to \(last), \(graph.categories.count.formatted(.number.locale(locale))) in all"
    }

    private var range: String {
        "\(OneElementOrManyAudioGraph.valueDescription(graph.yRange.lowerBound, unit: graph.unit, locale: locale)) "
            + "to \(OneElementOrManyAudioGraph.valueDescription(graph.yRange.upperBound, unit: graph.unit, locale: locale))"
    }
}

/// A name and its fact, on one line that wraps.
struct OneElementOrManyFactRow: View {
    let name: String
    let fact: String

    var body: some View {
        Text("\(Text(name).fontWeight(.semibold)): \(fact)")
    }
}

/// The screen's own constants: captions, the band's colour, the preview's size, and its announcement.
enum OneElementOrManyStyle {
    /// A faint grey band behind every other part of the day. A colour, not a hierarchical style, on a mark.
    static let band = Color.gray.opacity(0.12)
    static let previewWidth: CGFloat = 120
    static let previewHeight: CGFloat = 44
    /// Beyond this many, the Audio Graph's categories are shown as the first, the last and the count.
    static let categoriesListedInFull = 6

    static func caption(_ choice: OneElementOrManyChoice) -> String {
        switch choice {
        case .eachMark: "Cups sold today, by drink"
        case .eachPortion: "Orders by half hour today"
        case .wholeChart: "A preview of today's orders"
        }
    }

    /// Says aloud that the chart changed, for people who cannot see it happen.
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Each mark") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/one-element-or-many") {
            OneElementOrManyScreen(screen: screen)
        }
    }
}

#Preview("No data") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/one-element-or-many") {
            OneElementOrManyScreen(screen: screen, data: OneElementOrManyData(drinkSales: [], halfHourOrders: [], periods: []))
        }
    }
}
