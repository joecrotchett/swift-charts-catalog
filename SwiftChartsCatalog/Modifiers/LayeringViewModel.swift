import Foundation
import Observation

/// The state of the Layering screen: the zIndex given to the Station café's bars. Harbour's bars keep
/// the default, 0, and are written second, so with Station at 0 too the written order puts Harbour in front.
@Observable
final class LayeringViewModel {
    /// The slider's range for Station's zIndex: below, equal to and above Harbour's 0.
    static let layerRange: ClosedRange<Double> = -1 ... 1
    static let layerStep: Double = 1

    /// Station's zIndex. Harbour's is never set, so it stays 0.
    var stationLayer: Double = 0

    let harbour: [DailySales]
    let station: [DailySales]

    /// The first week of both cafés' sales, so each day's two bars are wide enough to see one cover the other.
    init(
        harbour: [DailySales] = Array(CafeData.storeSales[0].days.prefix(7)),
        station: [DailySales] = Array(CafeData.storeSales[1].days.prefix(7))
    ) {
        self.harbour = harbour
        self.station = station
    }

    func summary(locale: Locale) -> LayeringSummary {
        LayeringSummary(harbour: harbour, station: station, stationLayer: stationLayer, locale: locale)
    }
}

/// What the chart says in words, worked out from what is drawn. Pure, so it can be read from any code,
/// including the chart descriptor, which the accessibility system calls when it chooses.
nonisolated struct LayeringSummary {
    let harbour: [DailySales]
    let station: [DailySales]
    let stationLayer: Double
    /// The locale every number and date is written in. No default: the view passes its environment's.
    let locale: Locale

    /// Station is drawn in front only when its zIndex is above Harbour's 0. On a tie the marks are drawn
    /// in the order they are written, and Station is written first, so it is behind.
    var stationIsInFront: Bool {
        stationLayer > 0
    }

    /// No cups at either café: a chart of zero-height bars would draw nothing.
    var isEmpty: Bool {
        (harbour + station).allSatisfy { $0.cups == 0 }
    }

    /// Station's cups on a day, or 0 when it has no row for that day.
    func stationCups(on day: Date) -> Int {
        station.first { $0.day == day }?.cups ?? 0
    }

    /// Whether Harbour's narrow bar for this day is completely covered: Station's wider bar is in front
    /// and reaches at least as high.
    func isHidden(_ day: DailySales) -> Bool {
        stationIsInFront && day.cups > 0 && stationCups(on: day.day) >= day.cups
    }

    /// Harbour's days whose bar cannot be seen, in data order.
    var hiddenDays: [DailySales] {
        harbour.filter(isHidden)
    }

    /// The number of days drawn: one position on the x axis each.
    var dayCount: Int {
        Set((harbour + station).map(\.day)).count
    }

    /// The setting as shown beside the slider: "-1", "0", "1".
    var layerText: String {
        stationLayer.formatted(.number.precision(.fractionLength(0)).locale(locale))
    }

    /// The chart's message, carrying a figure the reader can count in the chart as drawn.
    var headline: String {
        if isEmpty { return "No cups sold in the first week." }
        let days = CafeWording.days(dayCount, locale: locale)
        if stationIsInFront {
            let hidden = hiddenDays.count
            if hidden == 0 {
                return "Station is in front, and Harbour rises above it on all \(days)."
            }
            return "Station is in front: Harbour's bar is hidden on "
                + "\(hidden.formatted(.number.locale(locale))) of \(days)."
        }
        if stationLayer == 0 {
            return "Both at zIndex 0, so the written order puts Harbour in front on all \(days)."
        }
        return "Station's lower zIndex keeps Harbour in front on all \(days)."
    }

    /// What VoiceOver says for the slider: the setting, then the headline, so no announcement is needed.
    var spokenSliderValue: String {
        "\(layerText). \(headline)"
    }

    /// "Sunday, March 1", written in the data's time zone so it names the day that is drawn.
    func dayName(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day()
        )
    }

    /// The cups axis as drawn, from zero to the busiest day at either café rounded up to the axis step (219 →
    /// 300): the chart's scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: (harbour + station).map(\.cups))
    }

    /// The element's label: the day, then the café.
    func label(_ day: DailySales, store: String) -> String {
        "\(dayName(day.day)), \(store)"
    }

    /// The element's value: the cups, and for Harbour what the drawing does to its bar.
    func harbourValue(_ day: DailySales) -> String {
        let cups = CafeWording.cups(day.cups, locale: locale)
        if isHidden(day) { return "\(cups), hidden behind Station's bar" }
        if stationIsInFront, day.cups > 0 { return "\(cups), shows above Station's bar" }
        return cups
    }

    func stationValue(_ day: DailySales) -> String {
        CafeWording.cups(day.cups, locale: locale)
    }

    /// Actual values only. The headline already says which café is in front, so it is not said twice.
    var audioGraphSummary: String {
        if isEmpty { return "No cups sold in the first week." }
        return "\(CafeWording.days(dayCount, locale: locale)), \(CafeWording.cafes(2, locale: locale)). "
            + "Station's zIndex is \(layerText), Harbour's is 0. \(headline) "
            + "Harbour: \(range(harbour)). Station: \(range(station))."
    }

    /// "lowest 150 cups, highest 196 cups", or "no days" for an empty series.
    private func range(_ days: [DailySales]) -> String {
        guard let low = days.map(\.cups).min(), let high = days.map(\.cups).max() else { return "no days" }
        return "lowest \(CafeWording.cups(low, locale: locale)), highest \(CafeWording.cups(high, locale: locale))"
    }
}
