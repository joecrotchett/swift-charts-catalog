import Foundation
import Observation

/// The state of the "Population pyramid" screen: the visits it draws and what it says about them.
/// The screen has no controls, so the state is the data alone.
@Observable
final class PopulationPyramidViewModel {
    /// The snippets the screen passes to its Code view, in order. The screen has no controls, so they never change.
    let snippets = [
        SnippetReference(name: "population-pyramid-bars", title: "Back-to-back bars from negated values"),
        SnippetReference(name: "population-pyramid-axes", title: "Axis labels without the sign"),
    ]

    let summary: PopulationPyramidSummary

    init(visits: [AgeGroupVisits] = CafeData.ageGroupVisits, ageGroups: [String] = CafeData.ageGroups) {
        summary = PopulationPyramidSummary(visits: visits, ageGroups: ageGroups)
    }
}

/// What the pyramid draws and says in words: its rows, which café is negated, the headline, and the
/// text assistive technologies get.
nonisolated struct PopulationPyramidSummary {
    let visits: [AgeGroupVisits]
    /// The age groups from youngest to oldest.
    let ageGroups: [String]

    /// The cafés in the order the data first names them. The first is the side drawn from negated values.
    var stores: [String] {
        var seen: [String] = []
        for item in visits where !seen.contains(item.store) {
            seen.append(item.store)
        }
        return seen
    }

    /// The café whose values are negated, so its bars grow the other way from zero.
    var negatedStore: String? {
        stores.first
    }

    /// The age groups in the order their rows are drawn, top to bottom: oldest first, so the youngest
    /// is at the bottom of the pyramid. VoiceOver's elements and the Audio Graph's categories both use it.
    var drawnAgeGroups: [String] {
        Array(ageGroups.reversed())
    }

    /// The rows in the order they are drawn and read: oldest group first, and within a group the
    /// cafés in their own order.
    var rows: [AgeGroupVisits] {
        let drawnGroups = drawnAgeGroups
        let storeOrder = stores
        func position(_ value: String, in order: [String]) -> Int {
            order.firstIndex(of: value) ?? order.count
        }
        return visits.sorted { first, second in
            let groups = (position(first.ageGroup, in: drawnGroups), position(second.ageGroup, in: drawnGroups))
            if groups.0 != groups.1 { return groups.0 < groups.1 }
            return position(first.store, in: storeOrder) < position(second.store, in: storeOrder)
        }
    }

    /// The value a row is plotted at: its visits, negated for the first café.
    func plottedVisits(_ item: AgeGroupVisits) -> Int {
        item.store == negatedStore ? -item.visits : item.visits
    }

    func total(for store: String) -> Int {
        visits.filter { $0.store == store }.map(\.visits).reduce(0, +)
    }

    /// No rows, or only zeros: bars that grow from zero would draw nothing.
    var isEmpty: Bool {
        visits.allSatisfy { $0.visits <= 0 }
    }

    /// The largest number of visits in any one bar.
    var largestVisits: Int {
        max(visits.map(\.visits).max() ?? 0, 0)
    }

    /// The largest bar on either side, rounded up to the axis step (1,620 → 2,000): how far each side of the axis
    /// reaches, and the descriptor's range of visits.
    var visitsTop: Double {
        ChartAxis.roundedTop(for: visits.map(\.visits))
    }

    /// The value axis as drawn: the same reach on both sides of zero, so a bar on the left and one on the right
    /// of the same length are the same number of visits.
    var visitsDomain: ClosedRange<Double> {
        -visitsTop ... visitsTop
    }

    /// The age groups that visited a café the most, youngest first, and how often. Nil when nobody visited it.
    func busiest(for store: String) -> (groups: [String], visits: Int)? {
        let own = visits.filter { $0.store == store }
        guard let most = own.map(\.visits).max(), most > 0 else { return nil }
        let groups = own.filter { $0.visits == most }.map(\.ageGroup)
        let ordered = ageGroups.filter(groups.contains) + groups.filter { !ageGroups.contains($0) }
        return (ordered, most)
    }

    /// "Harbour was visited most by 30 to 44 (1,480 visits), Station by 18 to 29 (1,620 visits)", naming
    /// each café that had visits. Each figure is the longest bar on one side of the chart.
    private func peaks(locale: Locale) -> String {
        let parts = stores.compactMap { store -> (store: String, detail: String)? in
            guard let peak = busiest(for: store) else { return nil }
            let names = CafeWording.list(peak.groups)
            return (store, "by \(names) (\(CafeWording.visits(peak.visits, locale: locale)))")
        }
        return parts.enumerated().map { index, part in
            index == 0 ? "\(part.store) was visited most \(part.detail)" : "\(part.store) \(part.detail)"
        }
        .joined(separator: ", ")
    }

    /// The chart's message in a sentence, true when nobody visited and when groups tie.
    func headline(locale: Locale) -> String {
        guard !isEmpty else { return Self.emptyHeadline }
        return peaks(locale: locale) + "."
    }

    /// The Audio Graph's summary: actual values only.
    func audioGraphSummary(locale: Locale) -> String {
        guard !isEmpty else { return Self.emptyHeadline }
        let groups = String(AttributedString(localized: "^[\(ageGroups.count) age group](inflect: true)", locale: locale).characters)
        let totals = stores.map { "\($0), \(CafeWording.visits(total(for: $0), locale: locale)) in total" }
        return "\(groups) at \(CafeWording.list(stores)). "
            + totals.joined(separator: ". ") + ". " + peaks(locale: locale) + "."
    }

    /// What a bar is: its age group, then its café.
    func elementLabel(_ item: AgeGroupVisits) -> String {
        "\(item.ageGroup), \(item.store)"
    }

    /// What a bar shows: its real number of visits, never the negated one.
    func elementValue(_ item: AgeGroupVisits, locale: Locale) -> String {
        CafeWording.visits(item.visits, locale: locale)
    }

    static let emptyHeadline = "No visits recorded this month."
}
