import Foundation

/// One value axis for a chart and its chart descriptor: the extent is worked out once from the data and passed to
/// both, so the Audio Graph plays and reads the ends the chart draws.
///
/// An automatic value scale rounds its ends to tidy numbers (0 to 300 for data up to 219) that a screen cannot read
/// back without a `ChartProxy`, so a descriptor given the data's own maximum says "219 cups" at the top of an axis
/// drawn to 300. The skill's rule (`audio-graph.md`): "set the value axis's domain yourself with `chartYScale(domain:)`
/// ... and give the descriptor that same range". This type gives that one range.
///
/// The step is chosen the way the automatic axis was seen to choose it, so a screen that adopts this draws the axis
/// it drew before: the smallest of 1, 2 or 5 times a power of ten that splits the span into at most four steps
/// (164 → step 50, top 200; 219 → step 100, top 300; 11 → step 5, top 15). Pass `step:` to choose your own.
///
/// Adopting it, for a bar chart from zero (the chart's `Chart` and its descriptor take the same value):
/// ```swift
/// let domain = ChartAxis.valueDomain(for: sales.map(\.cups))       // 0 ... 200 for data up to 164
/// Chart(sales) { ... }
///     .chartYScale(domain: domain)                                 // or chartXScale for horizontal bars
///     .accessibilityChartDescriptor(MyDescriptor(sales: sales, valueRange: domain))
/// // in the descriptor: AXNumericDataAxisDescriptor(title: ..., range: valueRange, ...)
/// ```
/// For a line that sits far from zero, `ChartAxis.valueDomain(for: cups, includesZero: false)` (152 to 219 → 140 ... 220).
/// A screen that changes its domain on purpose (a "fixed or dynamic" toggle) passes each mode's domain the same way.
/// Never empty: no data, or only zeros, gives `0 ... 1`.
nonisolated enum ChartAxis {
    /// How many steps the automatic axis splits a span into, at most.
    static let maximumSteps = 4.0

    /// A tidy step for a span of values: the smallest of 1, 2 or 5 times a power of ten that splits it into at
    /// most `maximumSteps` steps. 1 for a span that is zero, negative or not finite.
    static func step(forSpan span: Double) -> Double {
        guard span.isFinite, span > 0 else { return 1 }
        let raw = span / maximumSteps
        let magnitude = pow(10, log10(raw).rounded(.down))
        for multiple in [1.0, 2, 5, 10] where multiple * magnitude >= raw * (1 - 1e-9) {
            return multiple * magnitude
        }
        return 10 * magnitude
    }

    /// The value axis's extent: from zero (or the lowest value rounded down to the step, when the data dips below
    /// zero or `includesZero` is false) to the highest value rounded up to the step.
    static func valueDomain(
        for values: some Sequence<Double>, step: Double? = nil, includesZero: Bool = true
    ) -> ClosedRange<Double> {
        let ownStep = step.flatMap { $0 > 0 && $0.isFinite ? $0 : nil }
        let finite = values.filter(\.isFinite)
        guard let lowest = finite.min(), let highest = finite.max() else { return 0 ... (ownStep ?? 1) }
        let low = includesZero ? min(0, lowest) : lowest
        let high = includesZero ? max(0, highest) : highest
        // Only zeros: nothing to scale to, so one step from zero.
        if low == 0, high == 0 { return 0 ... (ownStep ?? 1) }
        // A single value off zero still needs a span: take the step from the value's own size.
        let span = high > low ? high - low : max(abs(high), 1)
        let step = ownStep ?? Self.step(forSpan: span)
        let bottom = (low / step).rounded(.down) * step
        var top = (high / step).rounded(.up) * step
        if top <= bottom { top = bottom + step }
        return bottom ... top
    }

    /// `valueDomain(for:step:includesZero:)` for whole numbers, such as cups.
    static func valueDomain(
        for values: some Sequence<Int>, step: Double? = nil, includesZero: Bool = true
    ) -> ClosedRange<Double> {
        valueDomain(for: values.map(Double.init), step: step, includesZero: includesZero)
    }

    /// The top of the value axis from zero: the highest value rounded up to the step. `valueDomain(for:)`'s upper bound.
    static func roundedTop(for values: some Sequence<Double>, step: Double? = nil) -> Double {
        valueDomain(for: values, step: step).upperBound
    }

    /// `roundedTop(for:step:)` for whole numbers.
    static func roundedTop(for values: some Sequence<Int>, step: Double? = nil) -> Double {
        valueDomain(for: values, step: step).upperBound
    }
}
