import Accessibility
import Charts
import SwiftUI

/// "Domain": the values a position scale covers, set automatically, exactly, without zero, reversed,
/// adjusted in a closure, and, for categories, as an array that orders them.
struct ScaleDomainScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: ScaleDomainViewModel
    /// Read here and passed in, so the headline, elements and Audio Graph write numbers as the axis does.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, sales: [DrinkSales] = CafeData.drinkSales, option: ScaleDomainOption = .automatic) {
        self.screen = screen
        _viewModel = State(initialValue: ScaleDomainViewModel(sales: sales, option: option))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today",
            message: viewModel.summary(locale: locale).headline,
            explanation: """
            A position scale's domain is the stretch of values it covers. By default it comes from the data and, \
            for numbers, includes zero; chartXScale and chartYScale can set it exactly (an exact domain can leave \
            zero out), reverse it, or edit the inferred values in a closure. A category scale's domain is an \
            array, and its order is the order of the rows: it reorders the rows only, not the data, so VoiceOver \
            still reads the bars in data order. To rank them for real, sort the data.
            """,
            snippets: viewModel.snippets
        ) {
            ScaleDomainChart(summary: viewModel.summary(locale: locale))
        } controls: {
            ScaleDomainControls(option: $viewModel.option)
        }
        .onChange(of: viewModel.option) {
            AccessibilityNotification.Announcement(viewModel.summary(locale: locale).announcement).post()
        }
    }
}

/// The domain picker, and the warning when the option chosen is the mistake.
struct ScaleDomainControls: View {
    @Binding var option: ScaleDomainOption

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Domain", selection: $option) {
                ForEach(ScaleDomainOption.allCases) { option in
                    Text(option.title).tag(option)
                }
            }
            if option.isMistake {
                Label(
                    "This is the mistake, shown on purpose: a bar's length is its value, so bars need zero.",
                    systemImage: "exclamationmark.triangle.fill"
                )
                .font(.footnote)
                .foregroundStyle(.orange)
            }
        }
    }
}

/// One bar per drink with the current domain, or a placeholder when nothing has been sold.
struct ScaleDomainChart: View {
    let summary: ScaleDomainSummary

    var body: some View {
        // Nothing sold is no data: zero-length bars would draw axes with nothing on them.
        if summary.total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one bar per drink.")
            )
        } else {
            // snippet:scale-domain-chart
            Chart(summary.sales) { item in
                Plot {
                    BarMark(
                        x: .value(CafeWording.cups, item.cups),
                        y: .value(CafeWording.drink, item.drink)
                    )
                }
                .accessibilityLabel(item.drink)
                .accessibilityValue(summary.elementValue(for: item))
            }
            // Marks are not clipped to the plot: a domain that leaves out part of a bar would draw it
            // past the plot's edge.
            .chartPlotStyle { plotArea in
                plotArea.clipped()
            }
            // end
            .modifier(ScaleDomainModifier(
                option: summary.option, zeroFreeDomain: summary.zeroFreeDomain, drinksByRank: summary.drinksByRank
            ))
            // The element text changes with the option while the ids do not: a new identity rebuilds them.
            .id(summary.option)
            .accessibilityChartDescriptor(ScaleDomainChartDescriptor(summary: summary))
        }
    }
}

/// Gives the chart the domain for one option: on the cups axis (x) or on the drinks (y).
struct ScaleDomainModifier: ViewModifier {
    let option: ScaleDomainOption
    /// The data's extent to the nearest ten, which leaves zero out, for the mistake.
    let zeroFreeDomain: ClosedRange<Int>
    /// The drinks from most cups to fewest, for the array domain.
    let drinksByRank: [String]

    func body(content: Content) -> some View {
        switch option {
        case .automatic:
            // snippet:scale-domain-automatic
            // The same as no modifier: the domain comes from the data and, for numbers, includes zero.
            content.chartXScale(domain: .automatic)
        // end
        case .exact:
            // snippet:scale-domain-exact
            // ScaleDomainSummary.exactDomain is 0 ... 300: the same scale every day, whatever today's sales.
            content.chartXScale(domain: ScaleDomainSummary.exactDomain)
        // end
        case .withoutZero:
            // snippet:scale-domain-without-zero
            // The mistake on bars: a domain that leaves zero out (here 50 ... 170 for today's sales), so no bar
            // starts at zero and every length misstates the cups. The plot is clipped, or the bars run past it.
            content.chartXScale(domain: zeroFreeDomain)
        // end
        case .reversed:
            // snippet:scale-domain-reversed
            // The axis runs the other way, so the bars grow from the other side. Meant for ranks, 1 at the top.
            content.chartXScale(domain: .automatic(reversed: true))
        // end
        case .closure:
            // snippet:scale-domain-closure
            // The closure edits the inferred domain: here it sorts the drinks by name.
            content.chartYScale(domain: .automatic(dataType: String.self) { drinks in
                drinks.sort()
            })
        // end
        case .array:
            // snippet:scale-domain-array
            // An array of categories sets the order of the rows, whatever the order of the data. It reorders the
            // rows only: VoiceOver still reads the bars in data order. To rank for real, sort the data instead.
            content.chartYScale(domain: drinksByRank)
            // end
        }
    }
}

/// The chart for the Audio Graph: the drinks in the order drawn, and the cups axis's range as drawn.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ScaleDomainChartDescriptor: AXChartDescriptorRepresentable {
    let summary: ScaleDomainSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let order = summary.drawnOrder
        let cupsByDrink = Dictionary(summary.sales.map { ($0.drink, $0.cups) }, uniquingKeysWith: +)
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: order)
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: summary.valueRange,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: order.map { AXDataPoint(x: $0, y: Double(cupsByDrink[$0] ?? 0)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the \(CafeWording.harbour) café, by drink",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

#Preview("Domain") {
    NavigationStack {
        if let screen = Catalog.screen(id: "scales/domain") {
            ScaleDomainScreen(screen: screen)
        }
    }
}

#Preview("Without zero") {
    ScaleDomainChart(summary: ScaleDomainSummary(sales: CafeData.drinkSales, option: .withoutZero, locale: .current))
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No sales") {
    ScaleDomainChart(summary: ScaleDomainSummary(sales: [], option: .automatic, locale: .current))
}
