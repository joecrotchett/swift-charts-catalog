import Accessibility
import Foundation
import Observation
import SwiftUI

/// The state behind "Sector": the three settings that take a pie to a donut, and the words that go with the chart.
@Observable
final class SectorMarkViewModel {
    /// The hole, as a fraction of the outer radius. Zero is a pie.
    var innerRadiusRatio = 0.0
    /// Points taken off each side of every sector. It starts small, not at zero: a thin gap separates neighbouring
    /// sectors by more than colour (`marks.md`: Apple's examples use 1 and 1.5).
    var angularInset = 1.5
    /// Points of rounding on every sector's corners, small for the same reason.
    var cornerRadius = 2.0

    let sales: [DrinkSales]

    static let innerRadiusRange = 0.0 ... 0.7
    static let innerRadiusStep = 0.05
    static let angularInsetRange = 0.0 ... 4.0
    static let angularInsetStep = 0.5
    static let cornerRadiusRange = 0.0 ... 12.0
    static let cornerRadiusStep = 1.0

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        self.sales = sales
    }

    /// The sectors and the chart's words, with numbers written for a locale.
    func summary(locale: Locale) -> SectorSalesSummary {
        SectorSalesSummary(sales: sales, locale: locale)
    }

    /// Nothing set: the mark is drawn from its angle alone.
    var isPlainPie: Bool {
        innerRadiusRatio == 0 && angularInset == 0 && cornerRadius == 0
    }

    /// The code behind the chart as it is drawn now: the bare mark, or the mark with its three settings.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "sector-order", title: "Largest first"),
            isPlainPie
                ? SnippetReference(name: "sector-pie", title: "A pie: the angle alone")
                : SnippetReference(name: "sector-shaped", title: "Inner radius, angular inset, corner radius"),
        ]
    }

    /// The hole's size as shown beside its slider: "60%".
    var innerRadiusText: String {
        innerRadiusRatio.formatted(.percent.precision(.fractionLength(0)))
    }

    var innerRadiusSpokenText: String {
        innerRadiusRatio == 0 ? "No hole, a pie" : "\(innerRadiusText) of the outer radius"
    }

    var angularInsetText: String {
        Self.pointsText(angularInset)
    }

    /// The inset with its unit written out and agreeing in number: "1 point", "1.5 points".
    func angularInsetSpokenText(locale: Locale) -> String {
        CafeWording.points(angularInset, locale: locale)
    }

    var cornerRadiusText: String {
        Self.pointsText(cornerRadius)
    }

    func cornerRadiusSpokenText(locale: Locale) -> String {
        CafeWording.points(cornerRadius, locale: locale)
    }

    /// What the chart now is, said once when a slider is let go: the sliders change its shape, which is only seen.
    func shapeAnnouncement(locale: Locale) -> String {
        guard !summary(locale: locale).slices.isEmpty else { return "No sales to draw." }
        guard !isPlainPie else { return "A pie." }
        let gap = angularInset * 2
        // "3 point gaps": the length describes the gaps, so "point" does not take the number.
        let gaps = gap == 0
            ? "no gaps"
            : "\(gap.formatted(.number.precision(.fractionLength(0 ... 1)).locale(locale))) point gaps"
        let corners = cornerRadius == 0 ? "square corners" : "corners \(cornerRadiusSpokenText(locale: locale))"
        guard innerRadiusRatio > 0 else { return "Pie: \(gaps), \(corners)." }
        return "Donut: hole \(innerRadiusText) of the radius, \(gaps), \(corners)."
    }

    /// A length beside its slider: "1.5 pt".
    static func pointsText(_ points: Double) -> String {
        "\(points.formatted(.number.precision(.fractionLength(0 ... 1)))) pt"
    }
}

/// What the sectors are and what the chart says in words: its headline, each sector's label, the Audio Graph's summary.
nonisolated struct SectorSalesSummary {
    /// The drinks that get a sector, in the order the sectors are drawn.
    let slices: [DrinkSales]
    /// The locale numbers are written in: the view's.
    let locale: Locale

    init(sales: [DrinkSales], locale: Locale) {
        self.locale = locale
        // snippet:sector-order
        // Sectors start at 12 o'clock and run clockwise in data order, so the largest goes first.
        // A sector needs a positive value: a drink with no cups has no sector. Ties keep their order.
        slices = sales.enumerated()
            .filter { $0.element.cups > 0 }
            .sorted { ($1.element.cups, $0.offset) < ($0.element.cups, $1.offset) }
            .map(\.element)
        // end
    }

    var total: Int {
        slices.map(\.cups).reduce(0, +)
    }

    /// Every drink with the most cups. More than one on a tie.
    var largest: [DrinkSales] {
        guard let most = slices.first?.cups else { return [] }
        return slices.filter { $0.cups == most }
    }

    /// Every drink with the fewest cups among those sold.
    var smallest: [DrinkSales] {
        guard let fewest = slices.last?.cups else { return [] }
        return slices.filter { $0.cups == fewest }
    }

    /// A drink's part of the total, from 0 to 1.
    func share(of slice: DrinkSales) -> Double {
        total > 0 ? Double(slice.cups) / Double(total) : 0
    }

    /// The share as a whole percentage: "30%".
    func shareText(of slice: DrinkSales) -> String {
        share(of: slice).formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    /// What VoiceOver says a sector shows: its cups with the unit, then its share.
    func spokenValue(of slice: DrinkSales) -> String {
        "\(CafeWording.cups(slice.cups, locale: locale)), \(shareText(of: slice)) of the total"
    }

    /// The chart's message. Its figure is the one written on the largest sector. True on a tie, for one drink, and for none.
    var headline: String {
        guard let most = largest.first?.cups else { return "No cups sold yet today." }
        if slices.count == 1 {
            return "\(Self.names(largest)) is the only drink sold: \(CafeWording.cups(most, locale: locale))."
        }
        if largest.count > 1 {
            return "\(Self.names(largest)) share the largest part: \(CafeWording.cups(most, locale: locale)) each."
        }
        return "\(Self.names(largest)) is the largest share: \(CafeWording.cups(most, locale: locale))."
    }

    /// Actual values only, with no judgement of them.
    var audioGraphSummary: String {
        guard let most = largest.first, let fewest = smallest.first else { return "No cups sold yet today." }
        // One drink is the whole: there is no largest or smallest share to give.
        if slices.count == 1 {
            return "\(CafeWording.drinks(slices.count, locale: locale)), \(most.drink): \(CafeWording.cups(most.cups, locale: locale)), \(shareText(of: most)) of the total."
        }
        return "\(CafeWording.drinks(slices.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Largest share: \(Self.names(largest)), \(CafeWording.cups(most.cups, locale: locale)), \(shareText(of: most)). "
            + "Smallest share: \(Self.names(smallest)), \(CafeWording.cups(fewest.cups, locale: locale)), \(shareText(of: fewest))."
    }

    /// The drinks' names as an English list, like the sentence they go in.
    static func names(_ drinks: [DrinkSales]) -> String {
        CafeWording.list(drinks.map(\.drink))
    }
}

/// The chart for the Audio Graph. A chart of sectors has none of its own: the sectors become categories.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SectorChartDescriptor: AXChartDescriptorRepresentable {
    let summary: SectorSalesSummary

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = summary.locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: CafeWording.drink,
            categoryOrder: summary.slices.map(\.drink)
        )
        // A pie's value range runs from 0 to the total, of which each sector is a share.
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            range: 0 ... Double(max(summary.slices.map(\.cups).reduce(0, +), 1)),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: summary.slices.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: "Cups sold today at the Harbour café, each drink's share",
            summary: summary.audioGraphSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
