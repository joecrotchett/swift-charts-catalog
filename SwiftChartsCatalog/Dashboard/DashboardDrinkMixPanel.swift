import Charts
import SwiftUI

/// Horizontal bars per drink for the selected day, or for the four weeks, in the shared drink order.
/// A tap on a bar's row selects that drink for every panel; the other bars fade.
struct DashboardDrinkMixPanel: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.locale) private var locale

    var body: some View {
        DashboardPanel(
            title: "Drink mix",
            subtitle: "\(CafeWording.cups) by \(CafeWording.drink.lowercased()), \(model.periodText(locale: locale))"
        ) {
            let bars = model.drinkBars
            if bars.allSatisfy({ $0.cups == 0 }) {
                // Bars grow from zero, so a mix of zeros would draw axes and no bars.
                ContentUnavailableView("No sales", systemImage: "cup.and.saucer", description: Text("Cups by drink appear here."))
            } else {
                DashboardDrinkMixChart(
                    bars: bars,
                    drinks: model.drinks,
                    emphasised: model.emphasisedDrinks,
                    selectedDrink: model.selectedDrink,
                    values: bars.map { model.drinkBarValue($0, locale: locale) },
                    domain: model.drinkMixDomain,
                    descriptor: model.drinkMixDescriptor(locale: locale),
                    select: { model.selectDrink($0) }
                )
                .id(model.drinkMixIdentity)
            }
        }
    }
}

private struct DashboardDrinkMixChart: View {
    let bars: [DashboardDrinkBar]
    let drinks: [String]
    let emphasised: Set<String>
    let selectedDrink: String?
    /// What VoiceOver says for each bar, in the order of `bars`.
    let values: [String]
    let domain: ClosedRange<Double>
    let descriptor: DashboardDrinkMixDescriptor
    let select: (String?) -> Void

    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .body) private var chartHeight = DashboardLayout.chartHeight

    var body: some View {
        Chart {
            ForEach(Array(zip(bars, values)), id: \.0.id) { bar, value in
                Plot {
                    BarMark(
                        x: .value(CafeWording.cups, bar.cups),
                        y: .value(CafeWording.drink, bar.drink)
                    )
                    .foregroundStyle(by: .value(CafeWording.drink, bar.drink))
                    .opacity(emphasised.contains(bar.drink) ? 1 : DashboardLayout.fadedOpacity)
                    // The value at the end of each bar, kept inside the plot.
                    .annotation(position: .trailing, alignment: .center, overflowResolution: .init(x: .fit(to: .plot))) {
                        Text(bar.cups.formatted(.number.locale(locale)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(bar.drink)
                .accessibilityValue(value)
            }
        }
        .chartXScale(domain: domain)
        .chartForegroundStyleScale(domain: drinks, mapping: DashboardSeriesStyle.colour(for:))
        // Each bar is named by its row; the colours are the drinks' everywhere on the dashboard.
        .chartLegend(.hidden)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Color.secondary.opacity(DashboardLayout.gridLineOpacity))
                AxisValueLabel().foregroundStyle(Color.secondary)
            }
        }
        // A tap selects the drink in the row under it, and it stays selected after the finger lifts.
        .chartYSelection(value: Binding(get: { selectedDrink }, set: { select($0) }))
        .chartGesture { proxy in
            SpatialTapGesture()
                .onEnded { tap in
                    proxy.selectYValue(at: tap.location.y)
                }
        }
        .accessibilityChartDescriptor(descriptor)
        .accessibilityIdentifier("dashboard-drink-mix")
        .frame(height: chartHeight)
    }
}

#Preview {
    ScrollView {
        DashboardDrinkMixPanel()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environment(DashboardModel())
}
