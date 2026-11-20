import Accessibility
import Charts
import SwiftUI

/// "Overflow": what a label at the chart's edge does under each overflow strategy, chosen per axis.
struct AnnotationOverflowScreen: View {
    let screen: CatalogScreen
    @State private var model: AnnotationOverflowViewModel
    /// The locale the screen's words are written in, read here and passed in.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.harbourSales) {
        self.screen = screen
        _model = State(initialValue: AnnotationOverflowViewModel(days: days))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.caption(locale: locale),
            message: model.headline(locale: locale),
            explanation: """
            An annotation is centred on its mark, so at the chart's edge part of it has nowhere to go. \
            overflowResolution takes a strategy for each axis: disabled leaves the label where it is, fit to plot \
            and fit to chart slide it inward to stay inside that boundary, and pad scale extends the scale until \
            it fits over its mark. Move the label to the first or last day to see each one work.
            """,
            snippets: model.snippets
        ) {
            AnnotationOverflowChart(model: model, locale: locale)
        } controls: {
            AnnotationOverflowControls(model: model, locale: locale)
        }
        .onChange(of: model.labelledDay) { old, _ in announce(.labelledDay(from: old)) }
        .onChange(of: model.xStrategy) { old, _ in announce(.strategy(.x, from: old)) }
        .onChange(of: model.yStrategy) { old, _ in announce(.strategy(.y, from: old)) }
    }

    /// A change that alters the headline is announced; one that leaves it as it was posts nothing.
    private func announce(_ change: AnnotationOverflowChange) {
        guard let message = model.announcement(for: change, locale: locale) else { return }
        AccessibilityNotification.Announcement(message).post()
    }
}

/// Constants that belong to this chart's label.
private enum AnnotationOverflowMetrics {
    static let labelHorizontalPadding: CGFloat = 6
    static let labelVerticalPadding: CGFloat = 2
    static let labelCornerRadius: CGFloat = 4
    static let labelledSymbolSize: CGFloat = 60
}

/// The line of daily cups with one labelled point, or a placeholder when there is no data.
struct AnnotationOverflowChart: View {
    let model: AnnotationOverflowViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The label's size as drawn, for the room a disabled strategy needs around the chart.
    @State private var labelSize = CGSize.zero

    var body: some View {
        if let labelled = model.labelled {
            Chart {
                ForEach(model.days) { day in
                    // One element per day, read as "Saturday, March 28, 282 cups".
                    Plot {
                        LineMark(x: .value(CafeWording.day, day.day), y: .value(CafeWording.cups, day.cups))
                    }
                    .accessibilityLabel(model.spokenDay(day, locale: locale))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }
                // snippet:overflow-annotation
                PointMark(x: .value(CafeWording.day, labelled.day), y: .value(CafeWording.cups, labelled.cups))
                    .symbolSize(AnnotationOverflowMetrics.labelledSymbolSize)
                    // The line's element for this day already says it; the point would repeat it.
                    .accessibilityHidden(true)
                    .annotation(
                        position: .top,
                        // One strategy for each axis: what happens when the label would cross that edge.
                        overflowResolution: AnnotationOverflowResolution(x: model.xStrategy.strategy, y: model.yStrategy.strategy)
                    ) {
                        AnnotationOverflowLabel(
                            day: model.shortDay(labelled, locale: locale),
                            cups: CafeWording.cups(labelled.cups, locale: locale)
                        )
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { labelSize = $0 }
                    }
                // end
            }
            .chartXAxis {
                // Exact days from the data, so a padded scale does not move the labels off the weeks,
                // and fewer of them as the text grows. The labels are written in UTC, as the days were counted.
                AxisMarks(values: model.axisDays(at: dynamicTypeSize)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: model.axisFormat(at: dynamicTypeSize, locale: locale))
                }
            }
            .annotationOverflowValueScale(model.valueDomain, isAutomatic: model.leavesValueScaleAutomatic)
            .accessibilityChartDescriptor(AnnotationOverflowDescriptor(model: model, locale: locale))
            // The descriptor's range follows the y strategy: a new identity, so the Audio Graph reads it again.
            .id(model.leavesValueScaleAutomatic)
            // A disabled strategy leaves the label past the chart's edge: keep that room free, outside the
            // chart, so the label does not cover the headline or leave the panel.
            .padding(model.reservedRoom(for: labelSize))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, with one day labelled.")
            )
        }
    }
}

extension View {
    /// The value axis: the screen's own domain, so the Audio Graph's top is the drawn one; left automatic under
    /// pad scale, which can only grow a scale the chart chose itself.
    @ViewBuilder
    func annotationOverflowValueScale(_ domain: ClosedRange<Double>, isAutomatic: Bool) -> some View {
        if isAutomatic {
            self
        } else {
            chartYScale(domain: domain)
        }
    }
}

/// The label drawn above the chosen point: its day and its cups.
struct AnnotationOverflowLabel: View {
    let day: String
    let cups: String

    var body: some View {
        VStack(spacing: 0) {
            Text(day)
            Text(cups).bold()
        }
        .font(.caption)
        // Capped, so at the largest sizes the label still fits beside a point in the middle of the plot.
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .fixedSize()
        .padding(.horizontal, AnnotationOverflowMetrics.labelHorizontalPadding)
        .padding(.vertical, AnnotationOverflowMetrics.labelVerticalPadding)
        .background(Color(.systemGray5), in: .rect(cornerRadius: AnnotationOverflowMetrics.labelCornerRadius))
    }
}

/// The controls: which day is labelled, and the strategy on each axis.
struct AnnotationOverflowControls: View {
    @Bindable var model: AnnotationOverflowViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Labelled day", selection: $model.labelledDay) {
                ForEach(AnnotationOverflowLabelledDay.allCases) { day in
                    Text(day.title).tag(day)
                }
            }
            AnnotationOverflowStrategyRow(axis: .x, selection: $model.xStrategy)
            AnnotationOverflowStrategyRow(axis: .y, selection: $model.yStrategy)
            // What the strategies do to the label now: explanation, kept out of the headline.
            Text(model.effectNote(locale: locale))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        // With no data there is no label to move.
        .disabled(model.isEmpty)
    }
}

/// A menu picker for one axis's strategy, in a row with the axis's name.
struct AnnotationOverflowStrategyRow: View {
    let axis: AnnotationOverflowAxis
    @Binding var selection: AnnotationOverflowStrategy

    var body: some View {
        LabeledMenuPicker(title: axis.title, selection: $selection) {
            ForEach(AnnotationOverflowStrategy.allCases) { strategy in
                Text(strategy.title).tag(strategy)
            }
        }
    }
}

/// The chart for the Audio Graph: the month's days as categories, cups with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct AnnotationOverflowDescriptor: AXChartDescriptorRepresentable {
    let days: [DailySales]
    let valueDomain: ClosedRange<Double>
    let title: String
    let summary: String
    let dayNames: [String]
    let locale: Locale

    @MainActor
    init(model: AnnotationOverflowViewModel, locale: Locale) {
        days = model.days
        valueDomain = model.valueDomain
        title = model.audioGraphTitle(locale: locale)
        summary = model.audioGraphSummary(locale: locale)
        dayNames = model.days.map { model.spokenDay($0, locale: locale) }
        self.locale = locale
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: dayNames),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle,
                range: valueDomain,
                gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: CafeWording.harbour,
                isContinuous: true,
                dataPoints: zip(dayNames, days).map { AXDataPoint(x: $0, y: Double($1.cups)) }
            )]
        )
    }
}

#Preview("Overflow") {
    NavigationStack {
        if let screen = Catalog.screen(id: "annotations/overflow") {
            AnnotationOverflowScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    AnnotationOverflowChart(model: AnnotationOverflowViewModel(days: []), locale: .current)
}
