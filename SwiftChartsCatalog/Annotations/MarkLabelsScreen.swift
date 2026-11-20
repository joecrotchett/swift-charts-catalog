import Accessibility
import Charts
import SwiftUI

/// "Labelling a mark": `annotation` puts each bar's value beside it or on it. The position picks the side,
/// and the alignment the spot along that side.
struct MarkLabelsScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = MarkLabelsViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers as the chart does.
    @Environment(\.locale) private var locale
    /// The notes beside the chart say what large text gives up, so they follow the size the chart is drawn at.
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: viewModel.summary.headline(locale: locale),
            explanation: """
            annotation(position:alignment:) attaches a view to a mark, and the chart keeps it there as the data \
            and the size change. The position says which side of the bar the label goes on, or overlay for on \
            top of it; the alignment says where along that side, or where inside the bar. The label is not read \
            by VoiceOver, so each bar carries its value as its accessibility value too.
            """,
            snippets: viewModel.snippets
        ) {
            MarkLabelsChart(
                sales: viewModel.sales,
                position: viewModel.position,
                alignment: viewModel.alignment,
                descriptor: viewModel.descriptor(locale: locale),
                locale: locale
            )
        } controls: {
            MarkLabelsControls(viewModel: viewModel, isAccessibilityTextSize: dynamicTypeSize.isAccessibilitySize)
        }
        .onChange(of: viewModel.position) { old, _ in
            if let message = viewModel.announcement(from: old, locale: locale) {
                MarkLabelsAnnouncer.announce(message)
            }
        }
    }
}

/// The pickers for where the label goes, and the notes that are true only for some positions.
private struct MarkLabelsControls: View {
    @Bindable var viewModel: MarkLabelsViewModel
    let isAccessibilityTextSize: Bool

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Label", selection: $viewModel.placement) {
                ForEach(MarkLabelsPlacement.allCases) { Text($0.title).tag($0) }
            }
            LabeledMenuPicker(title: "Position", selection: $viewModel.position) {
                ForEach(MarkLabelsPosition.allCases) { Text($0.title).tag($0) }
            }
            LabeledMenuPicker(title: "Alignment", selection: $viewModel.alignment) {
                ForEach(MarkLabelsAlignment.allCases) { Text($0.title).tag($0) }
            }
            ForEach(viewModel.notes(isAccessibilityTextSize: isAccessibilityTextSize), id: \.self) { note in
                Label(note, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .disabled(!viewModel.hasData)
    }
}

/// One bar per drink with its value as an annotation, or a placeholder when nothing has been sold.
/// The bars come in the order given: the view model ranks them, most cups first.
struct MarkLabelsChart: View {
    let sales: [DrinkSales]
    let position: MarkLabelsPosition
    let alignment: MarkLabelsAlignment
    let descriptor: MarkLabelsChartDescriptor
    let locale: Locale

    var body: some View {
        if MarkLabelsSummary(sales: sales).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one labelled bar per drink.")
            )
        } else {
            // snippet:labelling-a-mark-annotation
            Chart(sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.drink, item.drink),
                        y: .value(CafeWording.cups, item.cups),
                        // Half the band, so a label at a side position has room beside its bar.
                        width: .ratio(MarkLabelsMetrics.barWidthRatio)
                    )
                    // position: which side of the bar, or .overlay for on it.
                    // alignment: where along that side, or where inside the bar.
                    .annotation(position: position.annotationPosition, alignment: alignment.alignment) {
                        MarkLabelsValueLabel(cups: item.cups, isInside: position.isInside)
                    }
                }
                // The label is not an accessibility element, so the bar says its value itself.
                .accessibilityLabel(item.drink)
                .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
            }
            // end
            .markLabelsValueScale(descriptor.valueDomain, isAutomatic: descriptor.startsBelowZero)
            .accessibilityChartDescriptor(descriptor)
            // The descriptor's summary changes with the position: a new identity, so the Audio Graph reads it again.
            .id(descriptor.startsBelowZero)
        }
    }
}

extension View {
    /// The value axis: the descriptor's domain, so the Audio Graph's top is the drawn one; left automatic for the
    /// labels under the bars, where the chart growing its scale below zero to fit them is what the screen shows.
    @ViewBuilder
    func markLabelsValueScale(_ domain: ClosedRange<Double>, isAutomatic: Bool) -> some View {
        if isAutomatic {
            self
        } else {
            chartYScale(domain: domain)
        }
    }
}

/// The value written beside or on a bar.
private struct MarkLabelsValueLabel: View {
    let cups: Int
    let isInside: Bool

    var body: some View {
        if isInside {
            // snippet:labelling-a-mark-label-inside
            // On the bar: a colour that reads against the bar's fill, and room from its ends.
            // The overlay is offered the bar's width: one line, so a value too wide for the bar is cut short,
            // not broken digit by digit.
            Text(cups, format: .number)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.vertical, MarkLabelsMetrics.insidePadding)
            // end
        } else {
            // snippet:labelling-a-mark-label-outside
            // Beside the bar: quieter than the bar it describes.
            Text(cups, format: .number)
                .font(.caption)
                .foregroundStyle(.secondary)
            // end
        }
    }
}

/// Constants that belong to this chart's labels.
private enum MarkLabelsMetrics {
    /// Space between a label drawn inside a bar and the bar's ends.
    static let insidePadding: CGFloat = 4
    /// The bar's width as a fraction of its band.
    static let barWidthRatio: Double = 0.5
}

extension MarkLabelsPosition {
    /// The framework's position for this case.
    var annotationPosition: AnnotationPosition {
        switch self {
        case .automatic: .automatic
        case .top: .top
        case .bottom: .bottom
        case .leading: .leading
        case .trailing: .trailing
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        case .overlay: .overlay
        }
    }
}

extension MarkLabelsAlignment {
    /// SwiftUI's alignment for this case.
    var alignment: Alignment {
        switch self {
        case .center: .center
        case .leading: .leading
        case .trailing: .trailing
        case .top: .top
        case .bottom: .bottom
        case .topLeading: .topLeading
        case .topTrailing: .topTrailing
        case .bottomLeading: .bottomLeading
        case .bottomTrailing: .bottomTrailing
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
enum MarkLabelsAnnouncer {
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes, and values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct MarkLabelsChartDescriptor: AXChartDescriptorRepresentable {
    /// In the order the bars are drawn.
    let sales: [DrinkSales]
    /// The labels are under the bars, and the chart has extended the y scale below zero to fit them.
    let startsBelowZero: Bool
    let locale: Locale

    /// The value axis the chart is given (above or inside the bars): 0 to the most cups, rounded up to a tidy step.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: sales.map(\.cups))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: sales.map(\.drink))
        // The drawn axis: from zero, or (labels under the bars) from below zero by an amount the chart chose to
        // fit them, which cannot be read here; the summary says so. The top is the same either way.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: sales.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today, by drink",
            summary: MarkLabelsSummary(sales: sales).audioGraphSummary(locale: locale, startsBelowZero: startsBelowZero),
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Labelling a mark") {
    NavigationStack {
        if let screen = Catalog.screen(id: "annotations/labelling-a-mark") {
            MarkLabelsScreen(screen: screen)
        }
    }
}

#Preview("Inside, at the top") {
    let viewModel = MarkLabelsViewModel()
    MarkLabelsChart(
        sales: viewModel.sales,
        position: .overlay,
        alignment: .top,
        descriptor: viewModel.descriptor(locale: .current),
        locale: .current
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}

#Preview("No sales") {
    let viewModel = MarkLabelsViewModel(sales: [])
    MarkLabelsChart(
        sales: [],
        position: .top,
        alignment: .center,
        descriptor: viewModel.descriptor(locale: .current),
        locale: .current
    )
}
