import Accessibility
import Charts
import SwiftUI

/// "Colour: separation": a single stacked bar and a donut of the same drinks, with a thin gap between
/// neighbouring segments, and the mistake of letting them touch.
struct ColourSeparationScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ColourSeparationViewModel
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales) {
        self.screen = screen
        _viewModel = State(initialValue: ColourSeparationViewModel(sales: sales))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation(locale: locale),
            snippets: viewModel.snippets
        ) {
            ColourSeparationCharts(viewModel: viewModel, locale: locale)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Let the segments touch", isShowingMistake: $viewModel.isTouching)
                    // Nothing to restyle while the placeholder shows.
                    .disabled(!viewModel.hasChart)
            }
        }
    }
}

/// Both charts, sharing one colour scale, or a placeholder when nothing has been sold.
struct ColourSeparationCharts: View {
    let viewModel: ColourSeparationViewModel
    let locale: Locale

    var body: some View {
        if viewModel.hasChart {
            VStack(spacing: Layout.sectionSpacing) {
                ColourSeparationBar(viewModel: viewModel, locale: locale)
                ColourSeparationDonut(viewModel: viewModel, locale: locale)
            }
            // On the stack, the scale reaches both charts: each drink has one colour in the bar and the ring,
            // the app's own (separation, not hue, is this screen's subject).
            .chartForegroundStyleScale(domain: viewModel.drinkNames, mapping: CafeDrinkStyle.colour(for:))
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, as one bar and as a donut.")
            )
        }
    }
}

/// Every drink end to end in one horizontal bar, each segment clipped to leave a gap.
struct ColourSeparationBar: View {
    let viewModel: ColourSeparationViewModel
    let locale: Locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        // snippet:colour-separation-bar
        Chart(viewModel.shares) { share in
            Plot {
                BarMark(x: .value(CafeWording.cups, share.cups))
                    .foregroundStyle(by: .value(CafeWording.drink, share.drink))
                    // A name on every segment wide enough to hold it, so colour is not the only key there.
                    .annotation(position: .overlay) {
                        ColourSeparationSegmentLabel(drink: share.drink)
                    }
                    // Inset on every side: two neighbours leave a strip of background twice as wide.
                    .clipShape(Rectangle().inset(by: viewModel.gapEachSide))
            }
            .accessibilityLabel(share.drink)
            .accessibilityValue(summary.elementValue(for: share))
        }
        .chartXAxis(.hidden)
        // end
        // The donut's legend, right below, names the same colours for both charts.
        .chartLegend(.hidden)
        .frame(height: ColourSeparationMetrics.barHeight)
        .accessibilityChartDescriptor(ColourSeparationDescriptor(form: .bar, summary: summary))
        .id(viewModel.chartIdentity)
    }
}

/// A drink's name on its segment, or nothing where the segment is too narrow (or too short, at the largest text
/// sizes) for it: an overlay is offered the segment's size.
struct ColourSeparationSegmentLabel: View {
    let drink: String

    var body: some View {
        ViewThatFits {
            Text(drink)
                .font(.caption.weight(.semibold))
                // Dark on every colour of the palette: white fell below 4.5:1 on the lighter ones.
                .foregroundStyle(Color.black)
                .lineLimit(1)
                .fixedSize()
            Color.clear
                .frame(width: 0, height: 0)
        }
    }
}

/// The same drinks as a donut, the sectors separated by an angular inset, the best seller in the hole.
struct ColourSeparationDonut: View {
    let viewModel: ColourSeparationViewModel
    let locale: Locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        // snippet:colour-separation-donut
        Chart(viewModel.shares) { share in
            Plot {
                SectorMark(
                    angle: .value(CafeWording.cups, share.cups),
                    innerRadius: .ratio(ColourSeparationMetrics.innerRadiusRatio),
                    // Points off each side of every sector: 1.5 leaves a 3-point gap, 0 lets them touch.
                    angularInset: viewModel.gapEachSide
                )
                .foregroundStyle(by: .value(CafeWording.drink, share.drink))
            }
            .accessibilityLabel(share.drink)
            .accessibilityValue(summary.elementValue(for: share))
        }
        // end
        .chartLegend(alignment: .center, spacing: ColourSeparationMetrics.legendSpacing)
        .chartBackground { proxy in
            GeometryReader { geometry in
                if let anchor = proxy.plotFrame {
                    let frame = geometry[anchor]
                    // Kept inside the hole, so a long name (two drinks on a tie) wraps instead of running
                    // under the ring.
                    let holeWidth = min(frame.width, frame.height) * ColourSeparationMetrics.innerRadiusRatio
                    ColourSeparationCentreLabel(summary: summary)
                        .frame(maxWidth: holeWidth * ColourSeparationMetrics.labelWidthRatio)
                        .position(x: frame.midX, y: frame.midY)
                }
            }
        }
        .accessibilityChartDescriptor(ColourSeparationDescriptor(form: .donut, summary: summary))
        .id(viewModel.chartIdentity)
    }
}

/// The best seller and its cups, in the donut's hole: the figure the headline names. On iOS text in a
/// `chartBackground` is read, so it is one element saying the same as it shows.
struct ColourSeparationCentreLabel: View {
    let summary: ColourSeparationSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack {
            // At the accessibility sizes three lines overflow the hole into the sectors (rendered at
            // .accessibility5). The caption goes; the name and the figure the headline names stay.
            if !dynamicTypeSize.isAccessibilitySize {
                Text("Most sold")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(summary.bestSellerNames)
                .font(.headline)
            Text(summary.bestSellerCups)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Separated") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/colour-separation") {
            ColourSeparationScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    ColourSeparationCharts(viewModel: ColourSeparationViewModel(sales: []), locale: .current)
}
