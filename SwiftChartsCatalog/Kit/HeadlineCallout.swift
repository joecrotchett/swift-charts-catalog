import Charts
import SwiftUI

/// The label written over the mark a chart's headline names ("Mar 14: 240"), for a chart whose axis may not label
/// that day, month or bin, so the headline's figure can be found on the chart.
///
/// It sits above the mark, kept inside the plot across (`x: .fit(to: .plot)`) and allowed past its top
/// (`y: .disabled`), so it is never moved down over the mark it names. It adds nothing for assistive technologies:
/// the mark's own element already reads the value. Adopting it, on the mark or `Plot` the headline names (pass `nil`
/// for every other one), or on a point of no size placed on the mark:
/// ```swift
/// Plot { BarMark(...) }
///     .headlineCallout(isNamed ? "Mar 14: 240" : nil)
///
/// PointMark(x: ..., y: ...)
///     .symbolSize(0)
///     .accessibilityHidden(true)
///     .headlineCallout("Mar 28: 282")
/// ```
extension ChartContent {
    func headlineCallout(_ text: String?) -> some ChartContent {
        annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
            if let text {
                Text(text)
                    .font(.caption.bold())
            }
        }
    }
}

#Preview {
    Chart(CafeData.harbourSales.prefix(14)) { day in
        Plot {
            BarMark(
                x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                y: .value(CafeWording.cups, day.cups)
            )
        }
        .headlineCallout(day.day == CafeData.day(13) ? "Mar 14: \(day.cups)" : nil)
    }
    .frame(height: Layout.chartHeightCompact)
    .padding()
}
