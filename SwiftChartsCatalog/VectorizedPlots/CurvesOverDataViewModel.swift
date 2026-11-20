import Accessibility
import Charts
import Foundation
import Observation
import SwiftUI

/// The two charts the screen draws: a histogram with a fitted curve, and a scatter with a trend and its band.
nonisolated enum CurvesOverDataKind: String, CaseIterable, Identifiable, Hashable {
    case histogram
    case trend

    var id: String {
        rawValue
    }

    /// The picker's segment.
    var title: String {
        switch self {
        case .histogram: "Histogram"
        case .trend: "Trend"
        }
    }

    /// Said when the picker switches to this chart.
    var spokenName: String {
        switch self {
        case .histogram: "Histogram with a fitted curve"
        case .trend: "Scatter with a trend line"
        }
    }

    /// The layers this chart draws, in the order they are stacked from the back.
    var layers: [CurvesOverDataLayer] {
        switch self {
        case .histogram: [.bars, .curve]
        case .trend: [.band, .points, .trend]
        }
    }
}

/// One layer of either chart, each with its own toggle.
nonisolated enum CurvesOverDataLayer: String, CaseIterable, Identifiable, Hashable {
    case bars
    case curve
    case points
    case band
    case trend

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .bars: "Bars"
        case .curve: "Fitted curve"
        case .points: "Points"
        case .band: "Uncertainty band"
        case .trend: "Trend line"
        }
    }
}

/// Words this screen needs that `CafeWording` does not have: the names of the curves, used as the function
/// plots' labels, in the elements and in the descriptor.
nonisolated enum CurvesOverDataWording {
    static let fittedCurve = "Fitted curve"
    static let trend = "Trend"
    static let bandLow = "Band low"
    static let bandHigh = "Band high"
    static let normalCurve = "Fitted normal curve"
}

/// One bin of the histogram: the waits it covers and how many orders fall in it.
nonisolated struct CurvesOverDataBin: Identifiable {
    let range: ChartBinRange<Double>
    let orders: Int

    var id: Double {
        range.lowerBound
    }

    var middle: Double {
        (range.lowerBound + range.upperBound) / 2
    }
}

// snippet:curves-over-data-normal-fit
/// The normal curve fitted to the waits, on the histogram's scale: the framework fits nothing, so the
/// model works out the mean and spread once and the function plot only evaluates the curve.
nonisolated struct CurvesOverDataNormalFit: Equatable {
    let mean: Double
    let deviation: Double
    /// The order count times the bin width, so the curve gives orders per bin, the bars' own unit.
    let scale: Double

    /// `nil` when the waits have no spread to fit.
    init?(waits: [Double], binWidth: Double) {
        guard waits.count > 1, binWidth > 0 else { return nil }
        let count = Double(waits.count)
        let mean = waits.reduce(0, +) / count
        let variance = waits.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / count
        guard variance > 0 else { return nil }
        self.mean = mean
        deviation = variance.squareRoot()
        scale = count * binWidth
    }

    /// How many orders a bin centred on `wait` would hold if the waits were exactly normal.
    func expectedOrders(atWait wait: Double) -> Double {
        let z = (wait - mean) / deviation
        return scale / (deviation * (2 * Double.pi).squareRoot()) * exp(-z * z / 2)
    }

    /// The curve's height at its peak, which is at the mean.
    var peakOrders: Double {
        expectedOrders(atWait: mean)
    }
}

// end

// snippet:curves-over-data-line-fit
/// A least-squares line through the points, and the band where a new order's wait is expected to fall:
/// the 95% prediction band, t standard errors of a prediction either side, about 95 in 100 orders.
/// Worked out in the model; the function plots only evaluate it.
nonisolated struct CurvesOverDataLineFit: Equatable {
    let intercept: Double
    let slope: Double
    /// The spread of the points about the line, from the residuals.
    let residualDeviation: Double
    let count: Int
    let meanX: Double
    let sumOfSquaresX: Double

    /// `nil` with fewer than three points, or when every point has the same x.
    init?(points: [(x: Double, y: Double)]) {
        guard points.count > 2 else { return nil }
        let count = Double(points.count)
        let meanX = points.map(\.x).reduce(0, +) / count
        let meanY = points.map(\.y).reduce(0, +) / count
        let sumOfSquaresX = points.map { ($0.x - meanX) * ($0.x - meanX) }.reduce(0, +)
        guard sumOfSquaresX > 0 else { return nil }
        let slope = points.map { ($0.x - meanX) * ($0.y - meanY) }.reduce(0, +) / sumOfSquaresX
        let intercept = meanY - slope * meanX
        let residuals = points.map { $0.y - (intercept + slope * $0.x) }
        self.intercept = intercept
        self.slope = slope
        residualDeviation = (residuals.map { $0 * $0 }.reduce(0, +) / (count - 2)).squareRoot()
        self.count = points.count
        self.meanX = meanX
        self.sumOfSquaresX = sumOfSquaresX
    }

    func trend(at x: Double) -> Double {
        intercept + slope * x
    }

    /// Half the band's height at `x`: narrowest at the mean of x, wider towards the ends.
    func margin(at x: Double) -> Double {
        let spread = 1 + 1 / Double(count) + (x - meanX) * (x - meanX) / sumOfSquaresX
        return Self.t95(degreesOfFreedom: count - 2) * residualDeviation * spread.squareRoot()
    }

    /// Student's t for a two-sided 95% interval. With few points the normal 1.96 draws the band too narrow:
    /// 20 points leave 18 degrees of freedom, and t is 2.101. Between table rows the smaller degrees of
    /// freedom is used, which errs wide.
    static func t95(degreesOfFreedom: Int) -> Double {
        let table: [(degreesOfFreedom: Int, t: Double)] = [
            (1, 12.706), (2, 4.303), (3, 3.182), (4, 2.776), (5, 2.571), (6, 2.447), (7, 2.365), (8, 2.306),
            (9, 2.262), (10, 2.228), (11, 2.201), (12, 2.179), (13, 2.160), (14, 2.145), (15, 2.131),
            (16, 2.120), (17, 2.110), (18, 2.101), (19, 2.093), (20, 2.086), (21, 2.080), (22, 2.074),
            (23, 2.069), (24, 2.064), (25, 2.060), (26, 2.056), (27, 2.052), (28, 2.048), (29, 2.045),
            (30, 2.042), (40, 2.021), (60, 2.000), (120, 1.980),
        ]
        guard degreesOfFreedom >= 1 else { return .nan }
        if degreesOfFreedom > 120 { return 1.96 }
        return table.last { $0.degreesOfFreedom <= degreesOfFreedom }?.t ?? 1.96
    }
}

// end

/// The orders at one queue length, as VoiceOver hears one stretch of the trend chart. The stretch reaches
/// halfway to the next queue length that has orders, so the stretches cover the x axis between them.
nonisolated struct CurvesOverDataQueuePortion: Identifiable, Hashable {
    let queue: Int
    let waits: [Int]
    let start: Double
    let end: Double

    var id: Int {
        queue
    }
}

/// What the chart shows in place of itself when nothing is drawn.
nonisolated struct CurvesOverDataPlaceholder: Equatable {
    let title: String
    let systemImage: String
    let message: String
}

/// The state and words of "Curves over data": which chart, which layers, the fits, the headline and
/// what assistive technologies hear.
@Observable
final class CurvesOverDataViewModel {
    /// How many generated orders the histogram bins.
    static let defaultOrderCount = 2000

    var kind: CurvesOverDataKind = .histogram
    private(set) var visibleLayers: Set<CurvesOverDataLayer> = Set(CurvesOverDataLayer.allCases)

    // The histogram's data, worked out once.
    let orderCount: Int
    let bins: [CurvesOverDataBin]
    let normalFit: CurvesOverDataNormalFit?
    let histogramXDomain: ClosedRange<Double>
    let histogramYDomain: ClosedRange<Double>

    // The trend chart's data, worked out once.
    let waits: [OrderWait]
    let lineFit: CurvesOverDataLineFit?
    /// The queue lengths the orders span, so the trend and band stop where the points do.
    let queueRange: ClosedRange<Double>
    let trendXDomain: ClosedRange<Double>
    let trendYDomain: ClosedRange<Double>

    init(
        orders: [CafeOrder] = CafeData.manyOrders(count: CurvesOverDataViewModel.defaultOrderCount),
        waits: [OrderWait] = CafeData.orderWaits.filter { $0.store == CafeWording.harbour }
    ) {
        let minutes = orders.map(\.waitMinutes)
        let bins = Self.makeBins(minutes)
        let binWidth = bins.first.map { $0.range.upperBound - $0.range.lowerBound } ?? 0
        let normalFit = CurvesOverDataNormalFit(waits: minutes, binWidth: binWidth)
        orderCount = orders.count
        self.bins = bins
        self.normalFit = normalFit
        if let first = bins.first, let last = bins.last {
            histogramXDomain = first.range.lowerBound ... last.range.upperBound
        } else {
            histogramXDomain = 0 ... 1
        }
        let tallest = max(Double(bins.map(\.orders).max() ?? 0), normalFit?.peakOrders ?? 0)
        histogramYDomain = 0 ... Self.roundedUp(tallest)

        self.waits = waits
        let points = waits.map { (x: Double($0.queueLength), y: Double($0.waitSeconds)) }
        let lineFit = CurvesOverDataLineFit(points: points)
        self.lineFit = lineFit
        let queues = waits.map(\.queueLength)
        let lowestQueue = Double(queues.min() ?? 0)
        let highestQueue = Double(queues.max() ?? 0)
        queueRange = lowestQueue ... highestQueue
        // Half a queue length of room at each end, so the end points are not cut in half by the clipped plot.
        trendXDomain = (lowestQueue - 0.5) ... (highestQueue + 0.5)
        let bandTop = lineFit.map { fit in
            [lowestQueue, highestQueue].map { fit.trend(at: $0) + fit.margin(at: $0) }.max() ?? 0
        } ?? 0
        trendYDomain = 0 ... Self.roundedUp(max(Double(waits.map(\.waitSeconds).max() ?? 0), bandTop))
    }

    // MARK: Layers

    func isShowing(_ layer: CurvesOverDataLayer) -> Bool {
        visibleLayers.contains(layer)
    }

    func setShowing(_ layer: CurvesOverDataLayer, _ isShowing: Bool) {
        if isShowing {
            visibleLayers.insert(layer)
        } else {
            visibleLayers.remove(layer)
        }
    }

    var drawsBars: Bool {
        draws(.bars, in: visibleLayers)
    }

    var drawsCurve: Bool {
        draws(.curve, in: visibleLayers)
    }

    var drawsPoints: Bool {
        draws(.points, in: visibleLayers)
    }

    var drawsBand: Bool {
        draws(.band, in: visibleLayers)
    }

    var drawsTrend: Bool {
        draws(.trend, in: visibleLayers)
    }

    /// Whether a layer is on and has something to draw.
    private func draws(_ layer: CurvesOverDataLayer, in layers: Set<CurvesOverDataLayer>) -> Bool {
        guard layers.contains(layer) else { return false }
        switch layer {
        case .bars: return !bins.isEmpty
        case .curve: return normalFit != nil
        case .points: return !waits.isEmpty
        case .band, .trend: return lineFit != nil
        }
    }

    /// Whether the current chart has any data at all. Its toggles are disabled while it has none.
    var hasData: Bool {
        switch kind {
        case .histogram: !bins.isEmpty
        case .trend: !waits.isEmpty
        }
    }

    /// What replaces the chart when it would draw nothing, or `nil` when it draws something.
    var placeholder: CurvesOverDataPlaceholder? {
        if !hasData {
            return CurvesOverDataPlaceholder(
                title: "No orders",
                systemImage: "cup.and.saucer",
                message: "Orders appear here once there are some to chart."
            )
        }
        if kind.layers.contains(where: { draws($0, in: visibleLayers) }) { return nil }
        return CurvesOverDataPlaceholder(
            title: "Nothing drawn",
            systemImage: "square.3.layers.3d.slash",
            message: "Turn on a layer below to draw it."
        )
    }

    /// The code the See Code sheet shows for the current chart.
    var snippets: [SnippetReference] {
        switch kind {
        case .histogram:
            [
                SnippetReference(name: "curves-over-data-histogram", title: "A fitted curve over a histogram"),
                SnippetReference(name: "curves-over-data-normal-fit", title: "Fitting the curve in the model"),
            ]
        case .trend:
            [
                SnippetReference(name: "curves-over-data-trend", title: "A band and a trend line over points"),
                SnippetReference(name: "curves-over-data-line-fit", title: "Fitting the line and its band"),
            ]
        }
    }

    // MARK: Headline

    func caption(locale: Locale) -> String {
        switch kind {
        case .histogram: "Waits for \(CafeWording.orders(orderCount, locale: locale))"
        case .trend: "\(CafeWording.harbour) café: wait against queue"
        }
    }

    /// The chart's message, true of what is drawn now.
    func headline(locale: Locale) -> String {
        headline(for: kind, layers: visibleLayers, locale: locale)
    }

    private func headline(for kind: CurvesOverDataKind, layers: Set<CurvesOverDataLayer>, locale: Locale) -> String {
        switch kind {
        case .histogram: histogramHeadline(layers: layers, locale: locale)
        case .trend: trendHeadline(layers: layers, locale: locale)
        }
    }

    private static let layersOff = "Every layer is off: turn one on to draw it."

    private func histogramHeadline(layers: Set<CurvesOverDataLayer>, locale: Locale) -> String {
        guard !bins.isEmpty else { return "No orders to chart." }
        var sentences: [String] = []
        if draws(.bars, in: layers) {
            let most = bins.map(\.orders).max() ?? 0
            let tallest = bins.filter { $0.orders == most }
            let names = CafeWording.list(tallest.map { binLabel($0, locale: locale) })
            let share = "\(most.formatted(.number.locale(locale))) of \(CafeWording.orders(orderCount, locale: locale))"
            sentences.append(tallest.count == 1
                ? "The most common wait was \(names): \(share)."
                : "The most common waits were \(names): \(share) each.")
        }
        if draws(.curve, in: layers), let normalFit {
            let peak = TimeOfDayWording.minutes(normalFit.mean, locale: locale)
            sentences.append(draws(.bars, in: layers)
                ? "The fitted curve peaks at \(peak)."
                : "The fitted normal curve peaks at a wait of \(peak).")
        }
        if !sentences.isEmpty { return sentences.joined(separator: " ") }
        if layers.contains(.curve) { return "Every order waited the same time, so there is no curve to fit." }
        return Self.layersOff
    }

    private func trendHeadline(layers: Set<CurvesOverDataLayer>, locale: Locale) -> String {
        guard !waits.isEmpty else { return "No orders to chart." }
        let low = queueRange.lowerBound
        let high = queueRange.upperBound
        if draws(.trend, in: layers), let lineFit {
            var sentence = "The trend runs from \(seconds(lineFit.trend(at: low), locale: locale)) at "
                + "\(queuing(low, locale: locale)) to \(seconds(lineFit.trend(at: high), locale: locale)) at "
                + "\(queuing(high, locale: locale))."
            if draws(.band, in: layers) {
                sentence += " The band reaches \(seconds(lineFit.margin(at: lineFit.meanX), locale: locale)) "
                    + "either side of it at its narrowest."
            }
            return sentence
        }
        if draws(.band, in: layers), let lineFit {
            return "The band runs from \(bandText(at: low, fit: lineFit, locale: locale)) at "
                + "\(queuing(low, locale: locale)), and from \(bandText(at: high, fit: lineFit, locale: locale)) at "
                + "\(queuing(high, locale: locale))."
        }
        if draws(.points, in: layers) {
            let shortest = waits.map(\.waitSeconds).min() ?? 0
            let longest = waits.map(\.waitSeconds).max() ?? 0
            return "\(CafeWording.orders(waits.count, locale: locale)) waited "
                + "\(shortest.formatted(.number.locale(locale))) to \(CafeWording.seconds(longest, locale: locale)), "
                + "with \(low.formatted(.number.locale(locale))) to \(queuing(high, locale: locale))."
        }
        if layers.contains(.trend) || layers.contains(.band) {
            return "Every order had the same queue, so there is no line to fit."
        }
        return Self.layersOff
    }

    /// Said when a layer's toggle changes: what changed, then the headline.
    func layerAnnouncement(for layer: CurvesOverDataLayer, locale: Locale) -> String {
        "\(layer.title) \(isShowing(layer) ? "shown" : "hidden"). \(headline(locale: locale))"
    }

    /// Said when the picker switches charts.
    func kindAnnouncement(locale: Locale) -> String {
        "\(kind.spokenName). \(headline(locale: locale))"
    }

    // MARK: Words

    /// "4 to 5 minutes".
    func binLabel(_ bin: CurvesOverDataBin, locale: Locale) -> String {
        "\(bin.range.lowerBound.formatted(.number.locale(locale))) to "
            + TimeOfDayWording.minutes(bin.range.upperBound, locale: locale)
    }

    /// One bin's spoken value, for the layers drawn: "513 orders; fitted curve 515 orders".
    func binValue(_ bin: CurvesOverDataBin, locale: Locale) -> String {
        var parts: [String] = []
        if drawsBars {
            parts.append(CafeWording.orders(bin.orders, locale: locale))
        }
        if drawsCurve, let normalFit {
            let expected = normalFit.expectedOrders(atWait: bin.middle).rounded()
            parts.append("fitted curve \(CafeWording.count(expected, locale: locale, as: CafeWording.orders(_:locale:)))")
        }
        return parts.joined(separator: "; ")
    }

    /// A wait in whole seconds: "120 seconds". "" for a value that is not finite.
    func seconds(_ value: Double, locale: Locale) -> String {
        CafeWording.count(value.rounded(), locale: locale, as: CafeWording.seconds(_:locale:))
    }

    /// "0 people queuing", "1 person queuing".
    func queuing(_ queue: Double, locale: Locale) -> String {
        guard queue.isFinite else { return "" }
        return "\(CafeWording.people(queue, locale: locale)) queuing"
    }

    private func bandText(at queue: Double, fit: CurvesOverDataLineFit, locale: Locale) -> String {
        let centre = fit.trend(at: queue)
        let margin = fit.margin(at: queue)
        return "\((centre - margin).rounded().formatted(.number.locale(locale))) to \(seconds(centre + margin, locale: locale))"
    }

    // MARK: The trend chart's spoken stretches

    /// One stretch per queue length that has orders, each reaching halfway to its neighbours, so a swipe
    /// lands on orders every time and the trend and band are read where the points are.
    var queuePortions: [CurvesOverDataQueuePortion] {
        let queues = Set(waits.map(\.queueLength)).sorted()
        return queues.indices.map { index in
            let queue = queues[index]
            let start = index == 0 ? trendXDomain.lowerBound : Double(queues[index - 1] + queue) / 2
            let end = index == queues.count - 1 ? trendXDomain.upperBound : Double(queue + queues[index + 1]) / 2
            return CurvesOverDataQueuePortion(
                queue: queue,
                waits: waits.filter { $0.queueLength == queue }.map(\.waitSeconds),
                start: start,
                end: end
            )
        }
    }

    func portionLabel(_ portion: CurvesOverDataQueuePortion, locale: Locale) -> String {
        queuing(Double(portion.queue), locale: locale)
    }

    /// Context first, then each drawn layer's values at this queue length, with units.
    func portionValue(_ portion: CurvesOverDataQueuePortion, locale: Locale) -> String {
        var parts: [String] = []
        if drawsPoints, let shortest = portion.waits.min(), let longest = portion.waits.max() {
            let range = shortest == longest
                ? CafeWording.seconds(shortest, locale: locale)
                : "\(shortest.formatted(.number.locale(locale))) to \(CafeWording.seconds(longest, locale: locale))"
            parts.append("\(CafeWording.orders(portion.waits.count, locale: locale)), waits \(range)")
        }
        if drawsTrend, let lineFit {
            parts.append("trend \(seconds(lineFit.trend(at: Double(portion.queue)), locale: locale))")
        }
        if drawsBand, let lineFit {
            parts.append("band \(bandText(at: Double(portion.queue), fit: lineFit, locale: locale))")
        }
        return parts.joined(separator: "; ")
    }

    // MARK: Audio Graph

    func histogramDescriptor(locale: Locale) -> CurvesOverDataHistogramDescriptor {
        CurvesOverDataHistogramDescriptor(
            title: "Waits for \(CafeWording.orders(orderCount, locale: locale)), in minutes",
            summary: histogramSummary(locale: locale),
            categories: bins.map { binLabel($0, locale: locale) },
            orders: drawsBars ? bins.map(\.orders) : nil,
            curve: drawsCurve ? normalFit.map { fit in bins.map { fit.expectedOrders(atWait: $0.middle) } } : nil,
            yDomain: histogramYDomain,
            locale: locale
        )
    }

    /// Actual values only, for the layers drawn.
    func histogramSummary(locale: Locale) -> String {
        guard let first = bins.first, let last = bins.last else { return "No orders to chart." }
        var sentences = [
            "\(CafeWording.orders(orderCount, locale: locale)) in \(CafeWording.bins(bins.count, locale: locale)), "
                + "from \(first.range.lowerBound.formatted(.number.locale(locale))) to "
                + "\(TimeOfDayWording.minutes(last.range.upperBound, locale: locale)).",
        ]
        if drawsBars {
            let most = bins.map(\.orders).max() ?? 0
            let names = CafeWording.list(bins.filter { $0.orders == most }.map { binLabel($0, locale: locale) })
            sentences.append("Tallest: \(names), \(CafeWording.orders(most, locale: locale)).")
        }
        if drawsCurve, let normalFit {
            sentences.append("Fitted normal curve: mean \(TimeOfDayWording.minutes(normalFit.mean, locale: locale)), "
                + "standard deviation \(TimeOfDayWording.minutes(normalFit.deviation, locale: locale)).")
        }
        return sentences.joined(separator: " ")
    }

    func trendDescriptor(locale: Locale) -> CurvesOverDataTrendDescriptor {
        // The continuous series are sampled at every whole queue length the line spans.
        let queues = Array(stride(from: queueRange.lowerBound, through: queueRange.upperBound, by: 1))
        return CurvesOverDataTrendDescriptor(
            title: "Wait against people queuing at the \(CafeWording.harbour) café",
            summary: trendSummary(locale: locale),
            points: drawsPoints ? waits.map { (x: Double($0.queueLength), y: Double($0.waitSeconds)) } : nil,
            trend: drawsTrend ? lineFit.map { fit in queues.map { (x: $0, y: fit.trend(at: $0)) } } : nil,
            band: drawsBand ? lineFit.map { fit in
                queues.map { (x: $0, low: fit.trend(at: $0) - fit.margin(at: $0), high: fit.trend(at: $0) + fit.margin(at: $0)) }
            } : nil,
            xDomain: trendXDomain,
            yDomain: trendYDomain,
            locale: locale
        )
    }

    /// Actual values only, for the layers drawn.
    func trendSummary(locale: Locale) -> String {
        guard !waits.isEmpty else { return "No orders to chart." }
        var sentences: [String] = []
        if drawsPoints {
            let shortest = waits.map(\.waitSeconds).min() ?? 0
            let longest = waits.map(\.waitSeconds).max() ?? 0
            sentences.append("\(CafeWording.orders(waits.count, locale: locale)), "
                + "\(queueRange.lowerBound.formatted(.number.locale(locale))) to \(queuing(queueRange.upperBound, locale: locale)), "
                + "waits \(shortest.formatted(.number.locale(locale))) to \(CafeWording.seconds(longest, locale: locale)).")
        }
        if drawsTrend, let lineFit {
            sentences.append("Trend: \(seconds(lineFit.trend(at: queueRange.lowerBound), locale: locale)) at "
                + "\(queuing(queueRange.lowerBound, locale: locale)), "
                + "\(seconds(lineFit.slope, locale: locale)) more for each person.")
        }
        if drawsBand, let lineFit {
            sentences.append("Band: where about 95 in 100 waits are expected, "
                + "\(seconds(lineFit.margin(at: lineFit.meanX), locale: locale)) either side of the trend at its narrowest.")
        }
        return sentences.joined(separator: " ")
    }

    // MARK: Helpers

    /// `NumberBins` gives no bins when every value is the same, so that case gets a range of its own.
    private static func makeBins(_ values: [Double]) -> [CurvesOverDataBin] {
        guard let lowest = values.min(), let highest = values.max() else { return [] }
        let bins = lowest == highest
            ? NumberBins(range: lowest ... lowest + 1, desiredCount: 1)
            : NumberBins(data: values, desiredCount: 12)
        // index(for:) gives `count`, one past the last bin, for a value equal to the top of the range
        // (read on iOS 27): clamp it into the last bin, or the longest wait is not counted.
        let grouped = Dictionary(grouping: values) { min(bins.index(for: $0), bins.count - 1) }
        return bins.indices.map { index in
            CurvesOverDataBin(range: bins[index], orders: grouped[index]?.count ?? 0)
        }
    }

    /// A scale top a little above `value`, rounded up to a multiple of ten; 1 when there is nothing to show.
    private static func roundedUp(_ value: Double) -> Double {
        guard value > 0, value.isFinite else { return 1 }
        return (value * 1.08 / 10).rounded(.up) * 10
    }
}

/// The histogram for the Audio Graph: bins as categories, orders per bin, and the curve's value at each bin's
/// middle as a second series when it is drawn. Not tied to the main actor: the accessibility system calls
/// its value description when it chooses.
nonisolated struct CurvesOverDataHistogramDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let categories: [String]
    /// Orders per bin, when the bars are drawn.
    let orders: [Int]?
    /// The fitted curve at each bin's middle, when it is drawn.
    let curve: [Double]?
    let yDomain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        var series: [AXDataSeriesDescriptor] = []
        if let orders {
            series.append(AXDataSeriesDescriptor(
                name: CafeWording.orders,
                isContinuous: false,
                dataPoints: zip(categories, orders).map { AXDataPoint(x: $0, y: Double($1)) }
            ))
        }
        if let curve {
            series.append(AXDataSeriesDescriptor(
                name: CurvesOverDataWording.fittedCurve,
                isContinuous: true,
                dataPoints: zip(categories, curve).map { AXDataPoint(x: $0, y: $1) }
            ))
        }
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: TimeOfDayWording.waitAxisTitle, categoryOrder: categories),
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.orders, range: yDomain, gridlinePositions: []) { value in
                CafeWording.count(value.rounded(), locale: locale, as: CafeWording.orders(_:locale:))
            },
            additionalAxes: [],
            series: series
        )
    }
}

/// The scatter for the Audio Graph: both axes numeric, the orders as points, the trend and the band's two
/// edges as continuous series at each queue length, each only when it is drawn.
nonisolated struct CurvesOverDataTrendDescriptor: AXChartDescriptorRepresentable {
    let title: String
    let summary: String
    let points: [(x: Double, y: Double)]?
    let trend: [(x: Double, y: Double)]?
    let band: [(x: Double, low: Double, high: Double)]?
    let xDomain: ClosedRange<Double>
    let yDomain: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        var series: [AXDataSeriesDescriptor] = []
        if let points {
            series.append(AXDataSeriesDescriptor(
                name: CafeWording.orders, isContinuous: false,
                dataPoints: points.map { AXDataPoint(x: $0.x, y: $0.y) }
            ))
        }
        if let trend {
            series.append(AXDataSeriesDescriptor(
                name: CurvesOverDataWording.trend, isContinuous: true,
                dataPoints: trend.map { AXDataPoint(x: $0.x, y: $0.y) }
            ))
        }
        if let band {
            series.append(AXDataSeriesDescriptor(
                name: CurvesOverDataWording.bandLow, isContinuous: true,
                dataPoints: band.map { AXDataPoint(x: $0.x, y: $0.low) }
            ))
            series.append(AXDataSeriesDescriptor(
                name: CurvesOverDataWording.bandHigh, isContinuous: true,
                dataPoints: band.map { AXDataPoint(x: $0.x, y: $0.high) }
            ))
        }
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXNumericDataAxisDescriptor(title: CafeWording.queueAxisTitle, range: xDomain, gridlinePositions: []) { value in
                guard value.isFinite else { return "" }
                return "\(CafeWording.people(value, locale: locale)) queuing"
            },
            yAxis: AXNumericDataAxisDescriptor(title: CafeWording.waitAxisTitle, range: yDomain, gridlinePositions: []) { value in
                CafeWording.count(value.rounded(), locale: locale, as: CafeWording.seconds(_:locale:))
            },
            additionalAxes: [],
            series: series
        )
    }
}
