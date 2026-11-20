import Accessibility
import Foundation
import Observation
import SwiftUI

/// One sector of the donut: a drink, its cups, and the stretch of the running total it covers.
/// `chartAngleSelection` reports a position along that running total, so these stretches are what
/// a reported value is matched against.
nonisolated struct SelectSectorSlice: Identifiable, Hashable {
    let drink: String
    let cups: Int
    /// Where this sector starts along the running total: the sum of every sector before it.
    let start: Int
    /// Where it ends: `start + cups`, which is also where the next sector starts.
    var end: Int {
        start + cups
    }

    var id: String {
        drink
    }
}

nonisolated enum SelectSectorMapping {
    /// The sectors in drawing order, largest first (ties keep their data order), each with its running range.
    /// Drinks with no cups are left out: a sector's value must be positive, and an empty range could never be selected.
    static func slices(from sales: [DrinkSales]) -> [SelectSectorSlice] {
        let ordered = sales.enumerated()
            .filter { $0.element.cups > 0 }
            .sorted { lhs, rhs in
                lhs.element.cups != rhs.element.cups ? lhs.element.cups > rhs.element.cups : lhs.offset < rhs.offset
            }
            .map(\.element)
        var runningTotal = 0
        return ordered.map { sale in
            defer { runningTotal += sale.cups }
            return SelectSectorSlice(drink: sale.drink, cups: sale.cups, start: runningTotal)
        }
    }

    // snippet:select-a-sector-mapping
    /// `chartAngleSelection` reports a position along the running total of every sector's value, not the
    /// sector touched. Each sector covers its own stretch, from where the one before it ends up to (not
    /// including) where it ends; the last also takes the total itself, which is where it ends at 12 o'clock.
    /// Below zero, past the total or not a number: no sector.
    static func slice(at value: Double, in slices: [SelectSectorSlice]) -> SelectSectorSlice? {
        guard let last = slices.last, value >= 0, value <= Double(last.end) else { return nil }
        return slices.first { value < Double($0.end) } ?? last
    }
    // end
}

/// The state and words of "Select a sector": the donut's sectors, the angle selection as a plain number,
/// and whether the running total is shown beside the sector it maps to.
@Observable
final class SelectSectorViewModel {
    let slices: [SelectSectorSlice]
    /// The value `chartAngleSelection` reports while a finger is down: a position along the running total.
    var selectedValue: Double?
    /// Whether the labels show the running total (and, while selecting, the raw selected value) instead of each drink's cups.
    var showsRawValue = false

    init(sales: [DrinkSales] = CafeData.drinkSales) {
        slices = SelectSectorMapping.slices(from: sales)
    }

    var total: Int {
        slices.last?.end ?? 0
    }

    /// Nothing sold draws no sectors, so the screen shows a placeholder.
    var hasData: Bool {
        total > 0
    }

    /// The sector the selected value falls in, or `nil` with no selection or a value outside the total.
    var selectedSlice: SelectSectorSlice? {
        guard let selectedValue else { return nil }
        return SelectSectorMapping.slice(at: selectedValue, in: slices)
    }

    /// While a sector is selected, the others are faded; at rest every sector is at full colour.
    func isFaded(_ slice: SelectSectorSlice) -> Bool {
        guard let selectedSlice else { return false }
        return selectedSlice.id != slice.id
    }

    /// The drinks drawn faded, as one plain value the chart's body reads.
    var fadedDrinks: Set<String> {
        Set(slices.filter { isFaded($0) }.map(\.drink))
    }

    /// Each sector's label, by drink, as one plain value the chart's body reads.
    func labels(locale: Locale) -> [String: String] {
        Dictionary(slices.map { ($0.drink, label(for: $0, locale: locale)) }) { first, _ in first }
    }

    var snippets: [SnippetReference] {
        var names = [
            SnippetReference(name: "select-a-sector-chart", title: "Select by angle"),
            SnippetReference(name: "select-a-sector-mapping", title: "Map the value to a sector"),
        ]
        if showsRawValue {
            names.append(SnippetReference(name: "select-a-sector-raw-label", title: "Label the raw value"))
        }
        return names
    }

    // MARK: Words

    /// The raw value as a whole number, rounded down. The sector boundaries are whole numbers, so the
    /// rounded-down value is always in the same sector as the value itself (163.9 is written 163, not 164).
    func rawValueText(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0)).rounded(rule: .down).locale(locale))
    }

    // snippet:select-a-sector-raw-label
    /// The text drawn on each sector. With the raw value shown, a sector shows where it ends along the running
    /// total, and the selected sector shows the raw value instead, so the value is seen beside the sector it maps to.
    func label(for slice: SelectSectorSlice, locale: Locale) -> String {
        guard showsRawValue else { return slice.cups.formatted(.number.locale(locale)) }
        if let selectedValue, selectedSlice?.id == slice.id {
            return rawValueText(selectedValue, locale: locale)
        }
        return slice.end.formatted(.number.locale(locale))
    }

    // end

    /// The headline, for the current selection and setting. Every figure in it is drawn on a sector.
    func headline(locale: Locale) -> String {
        guard hasData else { return "No cups sold yet today." }
        if let selectedValue, let slice = selectedSlice {
            return selectionHeadline(slice: slice, value: selectedValue, locale: locale)
        }
        return restingHeadline(locale: locale)
    }

    /// The longest headline a selection can write, so the headline keeps one height while a finger moves.
    func reservedHeadline(locale: Locale) -> String {
        let candidates = [restingHeadline(locale: locale)] + slices.map { slice in
            selectionHeadline(slice: slice, value: Double(slice.end), locale: locale)
        }
        return candidates.max { $0.count < $1.count } ?? ""
    }

    /// "Tea sold the most: 164 cups." The largest sector comes first, so with the running totals shown its
    /// label is still its cups.
    private func restingHeadline(locale: Locale) -> String {
        guard let most = slices.first?.cups else { return "No cups sold yet today." }
        let names = CafeWording.list(slices.filter { $0.cups == most }.map(\.drink))
        return "\(names) sold the most: \(CafeWording.cups(most, locale: locale))."
    }

    private func selectionHeadline(slice: SelectSectorSlice, value: Double, locale: Locale) -> String {
        guard showsRawValue else {
            return "\(slice.drink): \(CafeWording.cups(slice.cups, locale: locale))."
        }
        let raw = rawValueText(value, locale: locale)
        guard let index = slices.firstIndex(of: slice), index > 0 else {
            return "Raw value \(raw) lands in \(slice.drink), the first sector."
        }
        let previous = slices[index - 1]
        return "Raw value \(raw) lands in \(slice.drink), past \(previous.drink)’s \(previous.end.formatted(.number.locale(locale)))."
    }

    /// What VoiceOver reads for a sector: its cups, and with the raw value shown, the stretch of the running total
    /// it covers. This is how everything a selection reveals is reached without a gesture.
    func elementValue(for slice: SelectSectorSlice, locale: Locale) -> String {
        let cups = CafeWording.cups(slice.cups, locale: locale)
        guard showsRawValue else { return cups }
        return "\(cups), running total \(slice.start.formatted(.number.locale(locale))) to \(slice.end.formatted(.number.locale(locale)))"
    }

    /// Said when the toggle changes the labels on every sector, then the headline.
    func announcement(locale: Locale) -> String {
        let change = showsRawValue
            ? "Sectors now show where each ends along the running total."
            : "Sectors now show each drink’s cups."
        return "\(change) \(headline(locale: locale))"
    }

    func descriptor(locale: Locale) -> SelectSectorChartDescriptor {
        SelectSectorChartDescriptor(slices: slices, locale: locale)
    }
}

/// The donut for the Audio Graph, which a donut does not get without one: the drinks as categories, cups as values.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct SelectSectorChartDescriptor: AXChartDescriptorRepresentable {
    let slices: [SelectSectorSlice]
    let locale: Locale

    var title: String {
        "Cups sold today at the \(CafeWording.harbour) café, by drink, as a donut"
    }

    var summary: String {
        guard let most = slices.first?.cups, let fewest = slices.last?.cups else { return "No cups sold yet today." }
        let total = slices.last?.end ?? 0
        let summary = "\(CafeWording.drinks(slices.count, locale: locale)), \(CafeWording.cups(total, locale: locale)) in total. "
            + "Most: \(drinks(selling: most)), \(CafeWording.cups(most, locale: locale))."
        // One sector, or every sector the same: the fewest would only repeat the most.
        guard fewest < most else { return summary }
        return summary + " Fewest: \(drinks(selling: fewest)), \(CafeWording.cups(fewest, locale: locale))."
    }

    /// Every drink that sold this many cups, named as the headline names a tie: "Latte and Tea".
    private func drinks(selling cups: Int) -> String {
        CafeWording.list(slices.filter { $0.cups == cups }.map(\.drink))
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(title: CafeWording.drink, categoryOrder: slices.map(\.drink))
        let yAxis = AXNumericDataAxisDescriptor(
            title: CafeWording.cupsAxisTitle,
            // A donut's value range runs from 0 to the total, of which each sector is a share.
            range: 0 ... Double(max(slices.last?.end ?? 0, 1)),
            gridlinePositions: []
        ) { value in CafeWording.count(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false,
            dataPoints: slices.map { AXDataPoint(x: $0.drink, y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
