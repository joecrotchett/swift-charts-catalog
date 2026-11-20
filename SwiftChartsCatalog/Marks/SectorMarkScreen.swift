import Accessibility
import Charts
import SwiftUI

/// "Sector": `SectorMark` from pie to donut, through inner radius, angular inset and corner radius.
struct SectorMarkScreen: View {
    let screen: CatalogScreen
    @State private var model = SectorMarkViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = model.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink",
            message: summary.headline,
            explanation: """
            SectorMark shows parts of a whole: each sector's angle is its value's share of the total. \
            An inner radius above zero opens the pie into a donut, an angular inset leaves a gap between \
            neighbouring sectors, and a corner radius rounds them. Keep the last two small, or the sectors' \
            shapes stop matching their values.
            """,
            snippets: model.snippets
        ) {
            SectorSalesChart(
                summary: summary,
                innerRadiusRatio: model.innerRadiusRatio,
                angularInset: model.angularInset,
                cornerRadius: model.cornerRadius,
                isPlainPie: model.isPlainPie
            )
        } controls: {
            ControlsSection {
                SectorSlider(
                    title: "Inner radius",
                    valueText: model.innerRadiusText,
                    spokenValue: model.innerRadiusSpokenText,
                    value: $model.innerRadiusRatio,
                    range: SectorMarkViewModel.innerRadiusRange,
                    step: SectorMarkViewModel.innerRadiusStep,
                    editingEnded: announceShape
                )
                SectorSlider(
                    title: "Angular inset",
                    valueText: model.angularInsetText,
                    spokenValue: model.angularInsetSpokenText(locale: locale),
                    value: $model.angularInset,
                    range: SectorMarkViewModel.angularInsetRange,
                    step: SectorMarkViewModel.angularInsetStep,
                    editingEnded: announceShape
                )
                SectorSlider(
                    title: "Corner radius",
                    valueText: model.cornerRadiusText,
                    spokenValue: model.cornerRadiusSpokenText(locale: locale),
                    value: $model.cornerRadius,
                    range: SectorMarkViewModel.cornerRadiusRange,
                    step: SectorMarkViewModel.cornerRadiusStep,
                    editingEnded: announceShape
                )
            }
        }
    }

    /// The sliders reshape the chart, which is only seen: say what it now is, once, when one is let go.
    private func announceShape() {
        AccessibilityNotification.Announcement(model.shapeAnnouncement(locale: locale)).post()
    }
}

/// Constants that belong to this chart's marks and labels.
private enum SectorStyle {
    static let legendSpacing: CGFloat = 12
    static let valueLabelHorizontalPadding: CGFloat = 5
    static let valueLabelVerticalPadding: CGFloat = 1
}

/// One sector per drink, or a placeholder when nothing has been sold.
struct SectorSalesChart: View {
    let summary: SectorSalesSummary
    let innerRadiusRatio: Double
    let angularInset: Double
    let cornerRadius: Double
    let isPlainPie: Bool

    var body: some View {
        // Nothing sold is no data: there is no whole to divide, and an empty chart draws nothing.
        if summary.slices.isEmpty {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "chart.pie",
                description: Text("Each drink's share of the cups sold today appears here.")
            )
        } else {
            Chart(summary.slices) { slice in
                // The label and value go on a Plot around the mark, so VoiceOver reads
                // "Tea, 164 cups, 30% of the total" and not the bare "Tea, 164".
                Plot {
                    if isPlainPie {
                        // snippet:sector-pie
                        // Only the angle is required. The values are normalized to the full circle:
                        // pass the raw amounts.
                        SectorMark(angle: .value("Cups", slice.cups))
                            .foregroundStyle(by: .value("Drink", slice.drink))
                        // end
                    } else {
                        // snippet:sector-shaped
                        SectorMark(
                            angle: .value("Cups", slice.cups),
                            // A fraction of the outer radius. Zero is a pie; anything larger is a donut.
                            innerRadius: .ratio(innerRadiusRatio),
                            // Points taken off each side of a sector, so the gap is twice this.
                            angularInset: angularInset
                        )
                        .cornerRadius(cornerRadius)
                        .foregroundStyle(by: .value("Drink", slice.drink))
                        // end
                    }
                }
                // The headline's figure, written on its sector. Annotation views are not read aloud,
                // so the Plot's value carries the same number.
                .annotation(position: .overlay) {
                    SectorValueLabel(cups: slice.cups)
                }
                .accessibilityLabel(slice.drink)
                .accessibilityValue(summary.spokenValue(of: slice))
            }
            // Each drink in the colour it has on every screen, listed in the chart's order, largest first.
            .chartForegroundStyleScale(
                domain: CafeDrinkStyle.domain(for: summary.slices.map(\.drink)), mapping: CafeDrinkStyle.colour(for:)
            )
            .chartLegend(alignment: .center, spacing: SectorStyle.legendSpacing)
            // A chart of sectors has no automatic Audio Graph.
            .accessibilityChartDescriptor(SectorChartDescriptor(summary: summary))
        }
    }
}

/// A sector's cups, on a chip in the system background so it reads on every sector colour in both appearances.
private struct SectorValueLabel: View {
    let cups: Int

    var body: some View {
        Text(cups, format: .number)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, SectorStyle.valueLabelHorizontalPadding)
            .padding(.vertical, SectorStyle.valueLabelVerticalPadding)
            .background(Color(.systemBackground), in: .capsule)
    }
}

/// A slider under a row that names it and shows its value.
private struct SectorSlider: View {
    let title: String
    let valueText: String
    let spokenValue: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    /// Called once when a drag of the slider ends, not on every step of it.
    let editingEnded: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            // The slider below carries the same name and value for assistive technologies.
            LabeledContent(title) {
                Text(valueText)
                    .monospacedDigit()
            }
            .accessibilityHidden(true)
            Slider(value: $value, in: range, step: step) {
                Text(title)
            } onEditingChanged: { isEditing in
                if !isEditing {
                    editingEnded()
                }
            }
            .accessibilityValue(spokenValue)
        }
    }
}

#Preview("Sector") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/sector") {
            SectorMarkScreen(screen: screen)
        }
    }
}

#Preview("Donut") {
    SectorSalesChart(
        summary: SectorSalesSummary(sales: CafeData.drinkSales, locale: .current),
        innerRadiusRatio: 0.6, angularInset: 1.5, cornerRadius: 4, isPlainPie: false
    )
    .padding()
}

#Preview("No sales") {
    SectorSalesChart(
        summary: SectorSalesSummary(sales: [], locale: .current),
        innerRadiusRatio: 0, angularInset: 0, cornerRadius: 0, isPlainPie: true
    )
}
