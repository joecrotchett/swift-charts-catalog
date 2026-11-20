import Accessibility
import Charts
import SwiftUI

/// "Axes: the lower bound": the same toggle leaves zero off a line and off bars. The line gains its
/// detail; the bars stop telling the truth.
struct LowerBoundScreen: View {
    let screen: CatalogScreen
    @State private var model = LowerBoundViewModel()
    /// Read here and passed in, so the headline, elements and Audio Graph write numbers as the axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Where each value axis starts",
            message: model.headline(locale: locale),
            explanation: """
            Choose the lower bound from the mark. A line is read by its ups and downs, so prices far from zero \
            are clearer on an axis that starts near them: with zero left off, the same prices fill most of the \
            plot. A bar is read by its length, so it must start at zero: cut the bottom off and the shortest bar \
            shrinks to a stub. On bars, .automatic(includesZero: false) changes nothing, since a bar's own start \
            at zero stays in the domain; it takes an exact range that leaves zero out to make this mistake.
            """,
            snippets: model.snippets
        ) {
            LowerBoundCharts(model: model, locale: locale)
        } controls: {
            LowerBoundControls(model: model)
        }
        .onChange(of: model.leavesOutZero) {
            Self.announce(model.announcement(locale: locale))
        }
    }

    /// Says aloud that both charts changed, for people who cannot see it happen.
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// The two charts, each under its title, so one toggle shows what it does to each.
struct LowerBoundCharts: View {
    let model: LowerBoundViewModel
    let locale: Locale

    var body: some View {
        ChartPair(firstTitle: LowerBoundWords.lineTitle, secondTitle: LowerBoundWords.barsTitle) {
            LowerBoundLineSection(model: model, locale: locale)
        } second: {
            LowerBoundBarsSection(model: model, locale: locale)
        }
    }
}

/// The bean price: a line far from zero.
struct LowerBoundLineSection: View {
    let model: LowerBoundViewModel
    let locale: Locale

    var body: some View {
        Group {
            if model.drawsLine {
                LowerBoundLineChart(
                    prices: model.prices, domain: model.lineDomain,
                    lowest: model.lowestWeek, highest: model.highestWeek, locale: locale
                )
                .accessibilityChartDescriptor(
                    LowerBoundLineDescriptor(prices: model.prices, domain: model.lineDomain, locale: locale)
                )
                // The toggle changes the descriptor's range but no element; the Audio Graph keeps the descriptor
                // a chart was first given, so the chart takes a new identity with the toggle.
                .id(model.leavesOutZero)
            } else {
                ContentUnavailableView("No prices yet", systemImage: "chart.xyaxis.line")
            }
        }
    }
}

/// The weekly closing price, with its lowest and highest weeks labelled.
struct LowerBoundLineChart: View {
    let prices: [WeeklyPrice]
    let domain: ClosedRange<Double>
    let lowest: WeeklyPrice?
    let highest: WeeklyPrice?
    let locale: Locale
    /// Room above the top of the axis for the highest week's label, growing with the text up to a cap.
    @ScaledMetric(relativeTo: .caption2) private var labelRoom = LowerBoundMarks.labelRoom

    /// The lowest and highest weeks, once each: one week when every close is the same.
    private var labelledWeeks: [WeeklyPrice] {
        guard let lowest, let highest else { return [] }
        return lowest.week == highest.week ? [highest] : [lowest, highest]
    }

    var body: some View {
        // snippet:axes-the-lower-bound-line
        Chart {
            ForEach(prices) { price in
                Plot {
                    LineMark(x: .value(CafeWording.week, price.week), y: .value(CafeWording.priceAxisTitle, price.close))
                }
                .accessibilityLabel(LowerBoundWords.weekName(price.week, locale: locale))
                .accessibilityValue("\(LowerBoundWords.price(price.close, locale: locale)) \(CafeWording.perKilogram)")
            }
            // The lowest and highest closes are written on the line, so the headline's figures can be found.
            ForEach(labelledWeeks, id: \.week) { price in
                PointMark(x: .value(CafeWording.week, price.week), y: .value(CafeWording.priceAxisTitle, price.close))
                    .symbolSize(LowerBoundMarks.labelledPointSize)
                    .accessibilityHidden(true)
                    .annotation(position: price.week == highest?.week ? .top : .bottom) {
                        Text(LowerBoundWords.price(price.close, locale: locale))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
        }
        // A line is read by its ups and downs: with zero left out, the prices fill the plot.
        // The padding above the domain keeps the highest week's label inside the plot.
        .chartYScale(domain: domain, range: .plotDimension(endPadding: min(labelRoom, LowerBoundMarks.labelRoomCap)))
        // end
        .chartXAxis {
            AxisMarks(values: .stride(by: .weekOfYear, count: LowerBoundMarks.weeksPerLabel, calendar: CafeData.calendar)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month(.abbreviated).day())
            }
        }
    }
}

/// Cups by drink: bars that must start at zero.
struct LowerBoundBarsSection: View {
    let model: LowerBoundViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            // While the bars are drawn wrong a badge over them says so: shortened where the long one does not fit.
            if model.isShowingMistake {
                ViewThatFits(in: .horizontal) {
                    LowerBoundMistakeBadge(text: LowerBoundWords.mistakeBadge)
                    LowerBoundMistakeBadge(text: LowerBoundWords.mistakeBadgeShort)
                }
                .font(.caption)
            }
            if model.drawsBars {
                LowerBoundBarChart(sales: model.sales, domain: model.barDomain, locale: locale)
                    .accessibilityChartDescriptor(
                        LowerBoundBarsDescriptor(sales: model.sales, domain: model.barDomain, locale: locale)
                    )
                    .id(model.leavesOutZero)
            } else {
                ContentUnavailableView("No cups sold yet", systemImage: "cup.and.saucer")
            }
        }
    }
}

/// The badge over the bars while they are drawn wrong: the words in the primary colour for contrast, the
/// warning colour on the icon alone, as the kit's mistake note does.
struct LowerBoundMistakeBadge: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
                .foregroundStyle(.primary)
        } icon: {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// One bar per drink, each with its cups written above it.
struct LowerBoundBarChart: View {
    let sales: [DrinkSales]
    let domain: ClosedRange<Double>
    let locale: Locale
    /// Room above the top of the axis for the tallest bar's label, growing with the text up to a cap.
    @ScaledMetric(relativeTo: .caption2) private var labelRoom = LowerBoundMarks.labelRoom
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        // snippet:axes-the-lower-bound-bars
        Chart(sales) { item in
            Plot {
                BarMark(x: .value(CafeWording.drink, item.drink), y: .value(CafeWording.cupsAxisTitle, item.cups))
                    .annotation(position: .top) {
                        Text(item.cups, format: .number.locale(locale))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
            }
            .accessibilityLabel(item.drink)
            .accessibilityValue(CafeWording.cups(item.cups, locale: locale))
        }
        // A bar is read by its length, so its axis starts at zero. A domain that leaves zero out
        // draws each bar from below the plot: clip it, or the bars run over the drink names.
        // The padding above the domain keeps the tallest bar's label inside the clipped plot.
        .chartYScale(domain: domain, range: .plotDimension(endPadding: min(labelRoom, LowerBoundMarks.labelRoomCap)))
        .chartPlotStyle { $0.clipped() }
        // end
        .chartYAxis {
            // At the accessibility sizes the plot is short and the labels would collide: keep the two ends,
            // so the axis still says where it starts.
            if dynamicTypeSize.isAccessibilitySize {
                AxisMarks(values: [domain.lowerBound, domain.upperBound]) {
                    AxisGridLine()
                    AxisValueLabel()
                }
            } else {
                AxisMarks()
            }
        }
    }
}

/// The toggle, and the note that marks the bars' case as the mistake.
struct LowerBoundControls: View {
    @Bindable var model: LowerBoundViewModel

    var body: some View {
        ControlsSection {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Toggle(LowerBoundWords.toggleTitle, isOn: $model.leavesOutZero)
                    .disabled(!model.isToggleEnabled)
                if model.isShowingMistake {
                    Label(LowerBoundWords.mistakeNote, systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

/// Sizes that belong to this chart's marks alone.
private enum LowerBoundMarks {
    /// The dots on the lowest and highest weeks, in square points.
    static let labelledPointSize: CGFloat = 24
    /// Four weeks between date labels: three labels across twelve weeks.
    static let weeksPerLabel = 4
    /// The space kept above the bars' axis for a value label, at the default text size.
    static let labelRoom: CGFloat = 18
    /// The most room kept for a value label, so the plot is not squeezed at the largest text sizes.
    static let labelRoomCap: CGFloat = 36
}

#Preview("From zero") {
    NavigationStack {
        LowerBoundScreen(screen: CatalogScreen(
            id: "design/axes-the-lower-bound", title: "Axes: the lower bound", summary: "", apiSince: "16.0",
            skillReferences: ["design.md", "scales.md"]
        ))
    }
}

#Preview("No data") {
    LowerBoundCharts(model: LowerBoundViewModel(prices: [], sales: []), locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}
