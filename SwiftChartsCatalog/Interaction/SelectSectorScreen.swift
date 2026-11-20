import Charts
import SwiftUI

/// "Select a sector": `chartAngleSelection(value:)` on a donut, and mapping the running-total value it reports to a sector.
struct SelectSectorScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: SelectSectorViewModel
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: SelectSectorViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink",
            message: viewModel.headline(locale: locale),
            reservedMessage: viewModel.reservedHeadline(locale: locale),
            explanation: """
            chartAngleSelection(value:) does not say which sector is under the finger. It reports a position along \
            the running total of every sector's value, from 0 at 12 o'clock round to the total. The screen adds up \
            the sectors until the total passes that value: that sector is the one selected.
            """,
            snippets: viewModel.snippets
        ) {
            SelectSectorChart(viewModel: viewModel, locale: locale)
        } controls: {
            SelectSectorControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The donut, or a placeholder when nothing has been sold.
struct SelectSectorChart: View {
    @Bindable var viewModel: SelectSectorViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasData {
            // snippet:select-a-sector-chart
            // Read the selection here, in the body. Swift Charts calls the closure below outside it, so a
            // selection read only in there does not redraw the chart when the finger moves.
            let faded = viewModel.fadedDrinks
            let labels = viewModel.labels(locale: locale)
            Chart(viewModel.slices) { slice in
                // The label and value go on a Plot around the sector: each sector is one element,
                // and VoiceOver reaches what a selection shows without a gesture.
                Plot {
                    SectorMark(
                        angle: .value(CafeWording.cups, slice.cups),
                        innerRadius: .ratio(SelectSectorStyle.innerRadius),
                        angularInset: SelectSectorStyle.angularInset
                    )
                    .cornerRadius(SelectSectorStyle.cornerRadius)
                    .foregroundStyle(by: .value(CafeWording.drink, slice.drink))
                    .opacity(faded.contains(slice.drink) ? SelectSectorStyle.fadedOpacity : 1)
                    .annotation(position: .overlay) {
                        SelectSectorLabel(text: labels[slice.drink] ?? "")
                    }
                }
                .accessibilityLabel(slice.drink)
                .accessibilityValue(viewModel.elementValue(for: slice, locale: locale))
            }
            // Reports a position along the running total while a finger is down, `nil` when it lifts.
            .chartAngleSelection(value: $viewModel.selectedValue)
            // end
            // The app's one colour per drink, so each drink matches every other screen.
            .chartForegroundStyleScale(domain: CafeDrinkStyle.domain(for: viewModel.slices.map(\.drink)), mapping: CafeDrinkStyle.colour(for:))
            .chartLegend(alignment: .center)
            // The toggle changes every sector's element text but not the data's ids: a new identity
            // makes VoiceOver read the new words.
            .id(viewModel.showsRawValue)
            .accessibilityChartDescriptor(viewModel.descriptor(locale: locale))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one sector per drink.")
            )
        }
    }
}

/// The number drawn in the middle of a sector's ring.
struct SelectSectorLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold).monospacedDigit())
            .padding(.horizontal, SelectSectorStyle.labelPadding)
            // On a material, so it reads on every sector colour, faded or not, in light and dark.
            .background(.thinMaterial, in: .capsule)
            // A narrow sector offers little width: shrink before cutting the number short.
            .lineLimit(1)
            .minimumScaleFactor(SelectSectorStyle.labelMinimumScale)
    }
}

/// The toggle that labels each sector with where it ends along the running total, and, under a finger,
/// the selected sector with the raw value instead, beside the sector it maps to.
struct SelectSectorControls: View {
    @Bindable var viewModel: SelectSectorViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            Toggle("Show the running total", isOn: $viewModel.showsRawValue)
                .disabled(!viewModel.hasData)
            Text(viewModel.showsRawValue
                ? "Each sector shows where it ends along the running total. Touch and hold the ring: the sector under your finger shows the raw value instead."
                : "Each sector shows its cups. Touch and hold the ring to select a sector.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: viewModel.showsRawValue) {
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The chart's own constants: the ring, the gap between sectors, and how far the unselected sectors fade.
private enum SelectSectorStyle {
    static let innerRadius: CGFloat = 0.618
    static let angularInset: CGFloat = 1.5
    static let cornerRadius: CGFloat = 5
    static let fadedOpacity = 0.3
    static let labelMinimumScale: CGFloat = 0.5
    static let labelPadding: CGFloat = 4
}

#Preview("Sales") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/select-a-sector") {
            SelectSectorScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    SelectSectorChart(viewModel: SelectSectorViewModel(sales: []), locale: .current)
}
