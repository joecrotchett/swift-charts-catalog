import Accessibility
import Charts
import SwiftUI

/// "What you get for free": a chart with nothing configured, and a name for each default it shows.
struct WhatYouGetForFreeScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = WhatYouGetForFreeViewModel()

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: viewModel.summary.headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            FreeDefaultsChart(orders: viewModel.orders, mark: viewModel.mark)
        } controls: {
            ControlsSection {
                Picker("Mark", selection: $viewModel.mark) {
                    ForEach(FreeDefaultsMark.allCases) { mark in
                        Text(mark.rawValue).tag(mark)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("Mark")
            }
            FreeDefaultsList(defaults: viewModel.defaults)
        }
        .onChange(of: viewModel.mark) {
            // The marks and the value scale both change: say so, for people who cannot see it happen.
            AccessibilityNotification.Announcement(viewModel.changeAnnouncement).post()
        }
    }
}

/// The uncustomised chart: marks, the data they plot, and no chart modifier at all.
struct FreeDefaultsChart: View {
    let orders: [DrinkOrder]
    let mark: FreeDefaultsMark

    var body: some View {
        // Nothing sold is no data: zeros would draw axes with no marks under a headline that is not true.
        if FreeDefaultsSummary(orders: orders).total == 0 {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, by drink and size.")
            )
        } else {
            Group {
                switch mark {
                case .bars:
                    // snippet:what-you-get-for-free-bars
                    // No axis, scale or legend modifier anywhere: everything but the marks is a default.
                    Chart(orders) { order in
                        // The Plot carries the words VoiceOver reads for this one segment.
                        Plot {
                            BarMark(
                                x: .value("Drink", order.drink),
                                y: .value("Cups", order.cups)
                            )
                            // Encoding the size as colour is what adds the colours and the legend.
                            .foregroundStyle(by: .value("Size", order.size))
                        }
                        .accessibilityLabel("\(order.drink), \(order.size)")
                        .accessibilityValue(Text("^[\(order.cups) cup](inflect: true)"))
                    }
                // end
                case .lines:
                    // snippet:what-you-get-for-free-lines
                    // No axis, scale or legend modifier anywhere: everything but the marks is a default.
                    Chart(orders) { order in
                        // The Plot carries the words VoiceOver reads for this one point.
                        Plot {
                            LineMark(
                                x: .value("Drink", order.drink),
                                y: .value("Cups", order.cups)
                            )
                            // Encoding the size as colour separates the lines and adds the legend.
                            .foregroundStyle(by: .value("Size", order.size))
                            // A shape as well, so the sizes can be told apart without colour.
                            .symbol(by: .value("Size", order.size))
                        }
                        .accessibilityLabel("\(order.drink), \(order.size)")
                        .accessibilityValue(Text("^[\(order.cups) cup](inflect: true)"))
                    }
                // end
                case .points:
                    // snippet:what-you-get-for-free-points
                    // No axis, scale or legend modifier anywhere: everything but the marks is a default.
                    Chart(orders) { order in
                        // The Plot carries the words VoiceOver reads for this one point.
                        Plot {
                            PointMark(
                                x: .value("Drink", order.drink),
                                y: .value("Cups", order.cups)
                            )
                            // Encoding the size as colour is what adds the colours and the legend.
                            .foregroundStyle(by: .value("Size", order.size))
                            // A shape as well, so the sizes can be told apart without colour.
                            .symbol(by: .value("Size", order.size))
                        }
                        .accessibilityLabel("\(order.drink), \(order.size)")
                        .accessibilityValue(Text("^[\(order.cups) cup](inflect: true)"))
                    }
                    // end
                }
            }
            .accessibilityChartDescriptor(FreeDefaultsChartDescriptor(orders: orders, isStacked: mark.stacksValues))
        }
    }
}

/// The defaults on show, each named, with what would change it.
struct FreeDefaultsList: View {
    let defaults: [FreeDefault]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("The defaults you are looking at")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            ForEach(defaults) { item in
                FreeDefaultRow(item: item)
            }
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// One default: its name, what it is on this chart, and the code that changes it.
struct FreeDefaultRow: View {
    let item: FreeDefault

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(item.name)
                .font(.subheadline.weight(.semibold))
            Text(item.detail)
                .font(.subheadline)
            Text("To change it: \(item.change)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// The chart for the Audio Graph: a title, a summary, named axes, one named series per size,
/// and values said with their unit. Not tied to the main actor: the accessibility system calls
/// its value description when it chooses.
nonisolated struct FreeDefaultsChartDescriptor: AXChartDescriptorRepresentable {
    let orders: [DrinkOrder]
    /// True for stacked bars, whose value scale reaches the tallest stack; false for lines and points.
    let isStacked: Bool

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = FreeDefaultsSummary(orders: orders, isStacked: isStacked)
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: summary.drinks
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // The drawn scale: up to the tallest stack for bars, the largest single value otherwise, rounded up.
            range: summary.valueDomain,
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: .current) { count, _ in FreeDefaultsSummary.cupsText(count) } }
        let series = summary.sizes.map { size in
            AXDataSeriesDescriptor(
                name: size,
                // Drinks are separate categories, whichever mark draws them: never a continuous measure.
                isContinuous: false,
                dataPoints: orders.filter { $0.size == size }.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
            )
        }
        return AXChartDescriptor(
            title: "Cups sold today, by drink and size",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: series
        )
    }
}

#Preview("Defaults") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/what-you-get-for-free") {
            WhatYouGetForFreeScreen(screen: screen)
        }
    }
}

#Preview("Lines") {
    FreeDefaultsChart(orders: CafeData.drinkOrders, mark: .lines)
        .padding()
}

#Preview("No sales") {
    FreeDefaultsChart(orders: [], mark: .bars)
}
