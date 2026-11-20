import Accessibility
import Foundation
import Observation
import SwiftUI

/// The state behind "Trend line": the orders, and whether the trend lines leave out `domain:`.
@Observable
final class TrendLineViewModel {
    /// The orders drawn, two numbers each.
    let orders: [OrderWait]
    /// The mistake: each line drawn across the whole x scale instead of stopping where its café's orders do.
    var isLeavingOutDomain = false

    init(orders: [OrderWait] = CafeData.orderWaits) {
        self.orders = orders
    }

    /// Everything the chart and its words are built from, for the current setting and the view's locale.
    func chartModel(locale: Locale) -> TrendLineChartModel {
        TrendLineChartModel(orders: orders, limitsToData: !isLeavingOutDomain, locale: locale)
    }

    /// The code the screen shows: the fit, the points, the line as currently drawn, and the scales.
    var snippets: [SnippetReference] {
        [
            SnippetReference(name: "trend-line-fit", title: "Fit the line in the model"),
            SnippetReference(name: "trend-line-points", title: "The points"),
            isLeavingOutDomain
                ? SnippetReference(name: "trend-line-without-domain", title: "The line, without domain: (the mistake)")
                : SnippetReference(name: "trend-line-with-domain", title: "The line, limited with domain:"),
            SnippetReference(name: "trend-line-scale", title: "An x scale wider than the data"),
        ]
    }
}

/// A straight line fitted to one café's orders by least squares: wait = intercept + slope × queue.
nonisolated struct TrendLineFit: Identifiable, Hashable {
    let store: String
    let intercept: Double
    let slope: Double
    /// The shortest and longest queue among the café's orders: where the line has data behind it.
    let queueRange: ClosedRange<Double>

    var id: String {
        store
    }

    /// The wait the line gives for a queue.
    func wait(atQueue queue: Double) -> Double {
        intercept + slope * queue
    }

    // snippet:trend-line-fit
    /// The framework does not fit the line: work out the coefficients here, and keep the range of the
    /// data, which the chart passes to the function plot as `domain:`.
    static func fitted(to orders: [OrderWait], store: String) -> TrendLineFit? {
        let points = orders.filter { $0.store == store }.map { (x: Double($0.queueLength), y: Double($0.waitSeconds)) }
        guard let lowest = points.map(\.x).min(), let highest = points.map(\.x).max(), lowest < highest else {
            return nil // A line needs at least two different queue lengths.
        }
        let count = Double(points.count)
        let meanX = points.map(\.x).reduce(0, +) / count
        let meanY = points.map(\.y).reduce(0, +) / count
        let covariance = points.map { ($0.x - meanX) * ($0.y - meanY) }.reduce(0, +)
        let variance = points.map { ($0.x - meanX) * ($0.x - meanX) }.reduce(0, +)
        let slope = covariance / variance
        return TrendLineFit(store: store, intercept: meanY - slope * meanX, slope: slope, queueRange: lowest ... highest)
    }
    // end
}

/// One stretch of the x axis as VoiceOver hears it: one queue length, what is drawn there, in words.
nonisolated struct TrendLinePortion: Identifiable, Hashable {
    let queue: Int
    let start: Double
    let end: Double
    let label: String
    let value: String

    var id: Int {
        queue
    }
}

/// The chart as plain values: the orders, the fitted lines, the scales, and every sentence about them.
nonisolated struct TrendLineChartModel {
    let orders: [OrderWait]
    /// Whether each line is limited to its café's orders with `domain:`.
    let limitsToData: Bool
    let locale: Locale

    /// How far the x scale reaches past the longest queue, so a line without `domain:` visibly runs on.
    private static let queuesPastData = 4
    /// The y scale's top is rounded up to a multiple of this.
    private static let waitStep = 100.0

    /// The cafés, in a fixed order, so each keeps its colour and symbol.
    let stores = [CafeWording.harbour, CafeWording.station]

    var isEmpty: Bool {
        orders.isEmpty
    }

    /// One fitted line per café that has orders at two queue lengths or more.
    var fits: [TrendLineFit] {
        stores.compactMap { TrendLineFit.fitted(to: orders, store: $0) }
    }

    /// From no queue to a few people past the longest one, so the scale reaches beyond the data.
    var xDomain: ClosedRange<Double> {
        0 ... Double((orders.map(\.queueLength).max() ?? 0) + Self.queuesPastData)
    }

    /// From zero to a round number above every order and every line at both ends of the x scale, so the
    /// scale is the same with or without `domain:` and no line leaves the plot.
    var yDomain: ClosedRange<Double> {
        let lineEnds = fits.flatMap { [$0.wait(atQueue: xDomain.lowerBound), $0.wait(atQueue: xDomain.upperBound)] }
        let values = orders.map { Double($0.waitSeconds) } + lineEnds
        let lowest = min(0, values.min() ?? 0)
        let highest = max(Self.waitStep, values.max() ?? 0)
        return (lowest / Self.waitStep).rounded(.down) * Self.waitStep ... (highest / Self.waitStep).rounded(.up) * Self.waitStep
    }

    /// Where a line is drawn: its café's queues with `domain:`, the whole x scale without it.
    func drawnRange(of fit: TrendLineFit) -> ClosedRange<Double> {
        limitsToData ? fit.queueRange : xDomain
    }

    // MARK: Words

    /// The chart's message, true of what is drawn in the current setting.
    var headline: String {
        headline(limitsToData: limitsToData)
    }

    private func headline(limitsToData: Bool) -> String {
        guard !orders.isEmpty else { return "No orders yet, so there is nothing to fit a line to." }
        let fits = fits
        guard !fits.isEmpty else { return "Too few queue lengths at either café to fit a trend line." }
        if limitsToData {
            let spans = fits.map { "\($0.store) \(queueSpan($0.queueRange))" }
            return "Each trend line stops where its café's orders do: \(CafeWording.list(spans))."
        }
        let names = CafeWording.list(fits.map(\.store))
        let lines = fits.count == 1 ? "\(names) line runs" : "\(names) lines run"
        let longest = orders.map(\.queueLength).max() ?? 0
        return "Without domain:, the \(lines) on to \(CafeWording.people(Int(xDomain.upperBound), locale: locale)), "
            + "though no order had a queue longer than \(longest.formatted(.number.locale(locale)))."
    }

    /// What VoiceOver says when the toggle changes the chart: what changed, then the headline.
    var announcement: String {
        let change = limitsToData
            ? "Trend lines limited to the data with domain:."
            : "Trend lines no longer limited with domain:."
        return "\(change) \(headline)"
    }

    /// "1 to 11 people".
    func queueSpan(_ range: ClosedRange<Double>) -> String {
        "\(Int(range.lowerBound).formatted(.number.locale(locale))) to \(CafeWording.people(Int(range.upperBound), locale: locale))"
    }

    /// One stretch of the x axis per queue length where something is drawn: the orders there and each
    /// line's wait there, if the line is drawn at that queue.
    var portions: [TrendLinePortion] {
        let fits = fits
        return (Int(xDomain.lowerBound) ... Int(xDomain.upperBound)).compactMap { queue in
            var parts: [String] = []
            for store in stores {
                let waits = orders.filter { $0.store == store && $0.queueLength == queue }.map(\.waitSeconds).sorted()
                guard !waits.isEmpty else { continue }
                let spoken = waits.map { CafeWording.seconds($0, locale: locale) }
                parts.append("\(store): \(CafeWording.orders(waits.count, locale: locale)), \(CafeWording.list(spoken))")
            }
            for fit in fits where drawnRange(of: fit).contains(Double(queue)) {
                parts.append("\(fit.store) trend line \(CafeWording.seconds(fit.wait(atQueue: Double(queue)).rounded(), locale: locale))")
            }
            guard !parts.isEmpty else { return nil }
            return TrendLinePortion(
                queue: queue,
                start: max(xDomain.lowerBound, Double(queue) - 0.5),
                end: min(xDomain.upperBound, Double(queue) + 0.5),
                label: "\(CafeWording.people(queue, locale: locale)) queuing",
                value: parts.joined(separator: ". ")
            )
        }
    }

    /// The Audio Graph's summary, in actual values.
    var audioGraphSummary: String {
        guard !orders.isEmpty else { return headline }
        var sentences = ["\(CafeWording.orders(orders.count, locale: locale)) at \(CafeWording.cafes(stores.count, locale: locale))."]
        for fit in fits {
            let range = drawnRange(of: fit)
            let lowWait = CafeWording.seconds(fit.wait(atQueue: range.lowerBound).rounded(), locale: locale)
            let highWait = CafeWording.seconds(fit.wait(atQueue: range.upperBound).rounded(), locale: locale)
            let perPerson = CafeWording.seconds(fit.slope, locale: locale)
            sentences.append(
                "\(fit.store) trend line from \(queueSpan(range)), \(lowWait) to \(highWait), \(perPerson) more for each person."
            )
        }
        return sentences.joined(separator: " ")
    }
}

/// The chart for the Audio Graph: both axes numeric, each café's orders as points, and each trend line
/// as it is drawn. Not tied to the main actor: the accessibility system calls its value descriptions.
nonisolated struct TrendLineChartDescriptor: AXChartDescriptorRepresentable {
    let model: TrendLineChartModel

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = model.locale
        let orderSeries = model.stores.map { store in
            AXDataSeriesDescriptor(
                name: store,
                isContinuous: false,
                dataPoints: model.orders.filter { $0.store == store }
                    .map { AXDataPoint(x: Double($0.queueLength), y: Double($0.waitSeconds)) }
            )
        }
        let lineSeries = model.fits.map { fit in
            let range = model.drawnRange(of: fit)
            var queues = Array(stride(from: range.lowerBound, through: range.upperBound, by: 1))
            if queues.last != range.upperBound { queues.append(range.upperBound) }
            return AXDataSeriesDescriptor(
                name: "\(fit.store) trend line",
                isContinuous: true,
                dataPoints: queues.map { AXDataPoint(x: $0, y: fit.wait(atQueue: $0)) }
            )
        }
        return AXChartDescriptor(
            title: "Wait against queue length at two cafés, with a trend line for each",
            summary: model.audioGraphSummary,
            xAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.queueAxisTitle, range: model.xDomain, gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale, as: CafeWording.people(_:locale:)) },
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.waitAxisTitle, range: model.yDomain, gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale, as: CafeWording.seconds(_:locale:)) },
            additionalAxes: [],
            series: orderSeries + lineSeries
        )
    }
}
