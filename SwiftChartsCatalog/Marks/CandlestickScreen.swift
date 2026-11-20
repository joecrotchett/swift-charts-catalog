import Accessibility
import Charts
import SwiftUI

/// "Candlestick": a custom mark type built from a rule and a rectangle, coloured by the caller.
struct CandlestickScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = CandlestickViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: CandlestickSummary.chartTitle,
            message: viewModel.summary(locale: locale).headline,
            explanation: viewModel.explanation,
            snippets: viewModel.snippets
        ) {
            CandlestickChart(prices: viewModel.prices, setsColourInside: viewModel.setsColourInside)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Set the colour inside the mark", isShowingMistake: $viewModel.setsColourInside)
            }
        }
        .onChange(of: viewModel.setsColourInside) {
            // The candles change colour without moving: say so for people who cannot see it happen.
            AccessibilityNotification.Announcement(viewModel.announcement(locale: locale)).post()
        }
    }
}

/// The sizes and colours that belong to this chart's marks.
private enum CandlestickStyle {
    static let wickWidth: CGFloat = 1
    /// The body's share of its week, so neighbouring bodies never touch.
    static let bodyRatio: CGFloat = 0.6
    static let symbolSpacing: CGFloat = 2
    static let largestSymbolSize = DynamicTypeSize.xxxLarge
    /// Weeks between two labels on the date axis: fewer labels once the text is large.
    static let weeksPerLabel = 4
    static let weeksPerLabelLargeText = 6

    /// Not green and red: which of those means a gain differs between countries, and the pair is
    /// the hardest to tell apart without full colour vision.
    static func colour(for direction: CandlestickDirection) -> Color {
        switch direction {
        case .rose: .blue
        case .fell: .orange
        case .unchanged: .secondary
        }
    }
}

// snippet:candlestick-mark
/// One candle: a thin wick from low to high and a wider body from open to close.
/// A custom mark built from two of the framework's, taking plottable values as they do.
struct CandlestickMark<X: Plottable, Y: Plottable>: ChartContent {
    let x: PlottableValue<X>
    let low: PlottableValue<Y>
    let high: PlottableValue<Y>
    let open: PlottableValue<Y>
    let close: PlottableValue<Y>

    var body: some ChartContent {
        // The Plot makes the two marks one unit, so a label given to a candle describes the whole candle.
        Plot {
            // A clear band the full height of the plot: every candle's element then has the same top, so
            // VoiceOver and Switch Control visit the weeks in order along x, not by the height of their highs.
            // Clear is the only style the type sets, and only on this band: the wick and body take the caller's.
            // (Hidden with opacity(0) instead, the band was left out of the element's frame: read on iOS.)
            RectangleMark(x: x, width: .ratio(CandlestickStyle.bodyRatio))
                .foregroundStyle(.clear)
            RuleMark(x: x, yStart: low, yEnd: high)
                .lineStyle(StrokeStyle(lineWidth: CandlestickStyle.wickWidth))
            RectangleMark(x: x, yStart: open, yEnd: close, width: .ratio(CandlestickStyle.bodyRatio))
        }
        // No foregroundStyle here: whatever the type leaves unset, the caller can set.
    }
}

// end

// snippet:candlestick-mark-mistake
/// The mistake: the same candle, but the type chooses its colour.
struct CandlestickSelfColouredMark<X: Plottable, Y: Plottable>: ChartContent {
    let x: PlottableValue<X>
    let low: PlottableValue<Y>
    let high: PlottableValue<Y>
    let open: PlottableValue<Y>
    let close: PlottableValue<Y>

    var body: some ChartContent {
        Plot {
            // The same clear band as the right candle, so the elements are in week order in both.
            RectangleMark(x: x, width: .ratio(CandlestickStyle.bodyRatio))
                .foregroundStyle(.clear)
            RuleMark(x: x, yStart: low, yEnd: high)
                .lineStyle(StrokeStyle(lineWidth: CandlestickStyle.wickWidth))
            RectangleMark(x: x, yStart: open, yEnd: close, width: .ratio(CandlestickStyle.bodyRatio))
        }
        // A style set inside the type wins over the same style applied to the type from outside,
        // so no caller can colour this candle by direction.
        .foregroundStyle(Color.gray)
    }
}

// end

/// One candle per week, or a placeholder when there are no prices.
struct CandlestickChart: View {
    let prices: [WeeklyPrice]
    var setsColourInside = false
    /// The calendar the weeks were made in: the weeks are cut, and the axis labelled, in it.
    var calendar = CafeData.calendar
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let summary = CandlestickSummary(prices: prices, locale: locale, calendar: calendar)
        if summary.isEmpty {
            ContentUnavailableView(
                "No prices yet",
                systemImage: "chart.bar.xaxis",
                description: Text("Each week's bean price appears here as a candle: its low, high, open and close.")
            )
        } else {
            // snippet:candlestick-chart
            Chart(prices) { price in
                let direction = CandlestickDirection(price)
                candle(for: price)
                    // Styled from outside, like a built-in mark: the colour stands for a value,
                    // so it is encoded and the chart gets a legend.
                    .foregroundStyle(by: .value(CandlestickSummary.directionLabel, direction))
                    // A second cue beside colour. Its view is not read; the label below carries it.
                    .annotation(position: .top, spacing: CandlestickStyle.symbolSpacing) {
                        Image(systemName: direction.symbolName)
                            .font(.caption2)
                            // At the accessibility sizes the arrows would grow into each other.
                            .dynamicTypeSize(...CandlestickStyle.largestSymbolSize)
                            .foregroundStyle(.secondary)
                    }
                    // The mark has a Plot inside, so these describe the whole candle as one element.
                    .accessibilityLabel(summary.label(for: price))
                    .accessibilityValue(summary.value(for: price))
            }
            .chartForegroundStyleScale { (direction: CandlestickDirection) in
                CandlestickStyle.colour(for: direction)
            }
            // Prices sit far from zero; from zero the candles are squashed at the top. One domain, off zero,
            // for the chart and the Audio Graph: $10.80 to $13.20 rounded out to $10 to $14.
            .chartYScale(domain: summary.priceDomain)
            // end
            .chartXAxis {
                // The axis is told the data's calendar too, or its marks and labels follow the device.
                AxisMarks(values: .stride(by: .weekOfYear, count: weeksPerLabel, calendar: calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, calendar: calendar, timeZone: calendar.timeZone)
                            .month().day()
                    )
                }
            }
            .yAxisTitle(CafeWording.priceAxisTitle, short: CafeWording.priceAxisShortTitle)
            .accessibilityChartDescriptor(CandlestickChartDescriptor(summary: summary))
        }
    }

    private var weeksPerLabel: Int {
        dynamicTypeSize.isAccessibilitySize ? CandlestickStyle.weeksPerLabelLargeText : CandlestickStyle.weeksPerLabel
    }

    /// The candle for one week, from whichever mark type the screen is showing.
    @ChartContentBuilder
    private func candle(for price: WeeklyPrice) -> some ChartContent {
        if setsColourInside {
            // snippet:candlestick-call-mistake
            CandlestickSelfColouredMark(
                x: .value(CafeWording.week, price.week, unit: .weekOfYear, calendar: calendar),
                low: .value(CandlestickSummary.lowLabel, price.low),
                high: .value(CandlestickSummary.highLabel, price.high),
                open: .value(CandlestickSummary.openLabel, price.open),
                close: .value(CandlestickSummary.closeLabel, price.close)
            )
            // end
        } else {
            // snippet:candlestick-call
            // Called like a built-in mark. The weeks were made in UTC, so they are cut in that calendar.
            CandlestickMark(
                x: .value(CafeWording.week, price.week, unit: .weekOfYear, calendar: calendar),
                low: .value(CandlestickSummary.lowLabel, price.low),
                high: .value(CandlestickSummary.highLabel, price.high),
                open: .value(CandlestickSummary.openLabel, price.open),
                close: .value(CandlestickSummary.closeLabel, price.close)
            )
            // end
        }
    }
}

/// The chart for the Audio Graph, which a candlestick does not get on its own: the four prices of
/// each week as four named series over the same weeks.
nonisolated struct CandlestickChartDescriptor: AXChartDescriptorRepresentable {
    let summary: CandlestickSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let prices = summary.prices
        let weeks = prices.map { summary.dayText($0.week) }
        // The drawn scale does not start at zero, so neither does this: the chart's own domain.
        let range = summary.isEmpty ? nil : summary.priceDomain
        func series(_ name: String, _ value: KeyPath<WeeklyPrice, Double>) -> AXDataSeriesDescriptor {
            AXDataSeriesDescriptor(
                name: name,
                // Separate candles, not one connected line.
                isContinuous: false,
                dataPoints: zip(weeks, prices).map { AXDataPoint(x: $0, y: $1[keyPath: value]) }
            )
        }
        return AXChartDescriptor(
            title: CandlestickSummary.chartTitle,
            summary: summary.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.week, categoryOrder: weeks),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.priceAxisTitle,
                range: range ?? 0 ... 0,
                gridlinePositions: []
            ) { summary.spokenPriceText($0) },
            additionalAxes: [],
            series: summary.isEmpty ? [] : [
                series(CandlestickSummary.openLabel, \.open),
                series(CandlestickSummary.closeLabel, \.close),
                series(CandlestickSummary.lowLabel, \.low),
                series(CandlestickSummary.highLabel, \.high),
            ]
        )
    }
}

#Preview("Coloured by the caller") {
    NavigationStack {
        if let screen = Catalog.screen(id: "marks/candlestick") {
            CandlestickScreen(screen: screen)
        }
    }
}

#Preview("Colour set inside") {
    CandlestickChart(prices: CafeData.weeklyPrices, setsColourInside: true)
        .padding()
}

#Preview("No prices") {
    CandlestickChart(prices: [])
}
