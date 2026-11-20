import Foundation
import Observation
import SwiftUI

/// The three ways an axis can be told which values to mark.
enum ChoosingAxisValuesMode: String, CaseIterable, Identifiable, Hashable {
    case automatic
    case stride
    case exact

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .automatic: "Automatic"
        case .stride: "Stride"
        case .exact: "Exact"
        }
    }
}

/// The axis values in effect: the mode with its one setting. The chart reports what it drew against
/// this, so a report from an earlier setting is never mistaken for the current one.
enum ChoosingAxisValuesChoice: Hashable {
    case automatic(desiredCount: Int)
    case stride(by: Int)
    case exact([Int])
}

/// One axis value as the chart drew it: which of how many, and the number it marks.
struct ChoosingAxisValuesReading: Hashable {
    let choice: ChoosingAxisValuesChoice
    let index: Int
    let count: Int
    let value: Double
}

/// Words this screen needs that `CafeWording` does not have.
nonisolated enum ChoosingAxisValuesWording {
    /// "1 value", "5 values".
    static func values(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) value](inflect: true)", locale: locale).characters)
    }

    /// "0, 100, 200 and 300", each number written in the locale, joined the English way.
    static func numbers(_ values: [Double], locale: Locale) -> String {
        CafeWording.list(values.map { $0.formatted(.number.locale(locale)) })
    }
}

/// The state of "Choosing axis values": which way the y axis's values are chosen, the setting for
/// that way, and what the chart reports it actually drew.
@Observable
final class ChoosingAxisValuesViewModel {
    static let countRange = 1 ... 10
    static let strides = [25, 50, 100]
    /// The exact values: 300 lies above every drink, so it widens the scale.
    static let exactValues = [0, 100, 200, 300]

    let sales: [DrinkSales]

    var mode: ChoosingAxisValuesMode = .automatic {
        didSet { if mode != oldValue { awaitDrawing() } }
    }

    /// Not announced when it changes: the stepper speaks the setting and the headline as its value instead
    /// (`stepperSpokenValue`), so a run of steps is not a run of announcements.
    var desiredCount = 4

    var stride = 50 {
        didSet { if stride != oldValue { awaitDrawing() } }
    }

    /// The setting whose drawing is still to be announced, once the chart reports what it drew.
    private(set) var pendingAnnouncement: ChoosingAxisValuesChoice?
    /// Announces the pending setting once its count is known, in case a label the framework dropped
    /// never reports and the drawing is never complete.
    @ObservationIgnored private var fallbackTask: Task<Void, Never>?
    /// How long after the first report for a new setting the fallback announcement waits.
    private let fallbackDelay: Duration
    /// The axis values reported for each setting, by index.
    private var readings: [ChoosingAxisValuesChoice: [Int: ChoosingAxisValuesReading]] = [:]
    /// The y domain the chart reports for one setting.
    private var reportedDomain: (choice: ChoosingAxisValuesChoice, domain: ClosedRange<Double>)?
    private let announce: @MainActor (String) -> Void

    init(
        sales: [DrinkSales] = CafeData.drinkSales,
        fallbackDelay: Duration = .milliseconds(500),
        announce: @escaping @MainActor (String) -> Void = ChoosingAxisValuesViewModel.post
    ) {
        self.sales = sales
        self.fallbackDelay = fallbackDelay
        self.announce = announce
    }

    /// Says aloud that the chart changed, for people who cannot see it happen.
    static func post(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }

    var choice: ChoosingAxisValuesChoice {
        switch mode {
        case .automatic: .automatic(desiredCount: desiredCount)
        case .stride: .stride(by: stride)
        case .exact: .exact(Self.exactValues)
        }
    }

    /// Nothing sold, or only zeros, is no chart: bars of zero draw nothing.
    var hasData: Bool {
        sales.contains { $0.cups > 0 }
    }

    /// Every drink that sold the most, in data order.
    var tallest: [DrinkSales] {
        guard let most = sales.map(\.cups).max(), most > 0 else { return [] }
        return sales.filter { $0.cups == most }
    }

    var tallestCups: Int {
        tallest.first?.cups ?? 0
    }

    // MARK: What the chart drew

    /// How many values the axis drew for the current setting, once the chart has said.
    var actualCount: Int? {
        readings[choice]?.values.first?.count
    }

    /// The values the axis drew for the current setting, in order, once every one has been reported.
    var drawnValues: [Double]? {
        guard let current = readings[choice], let count = current.values.first?.count,
              current.count == count else { return nil }
        return (0 ..< count).compactMap { current[$0]?.value }
    }

    /// The y domain as drawn: the one the chart reports, or until then the data and any exact values.
    var domain: ClosedRange<Double> {
        if let reportedDomain, reportedDomain.choice == choice {
            return reportedDomain.domain
        }
        let exactTop = mode == .exact ? Self.exactValues.max() ?? 0 : 0
        return 0 ... Double(max(tallestCups, exactTop))
    }

    /// Called by each axis label as it is drawn.
    func record(_ reading: ChoosingAxisValuesReading, locale: Locale) {
        // A new count for the same setting (the chart was resized) replaces what that setting drew.
        if readings[reading.choice]?.values.contains(where: { $0.count != reading.count }) == true {
            readings[reading.choice] = [:]
        }
        readings[reading.choice, default: [:]][reading.index] = reading
        if pendingAnnouncement == reading.choice, fallbackTask == nil {
            fallbackTask = Task { [weak self, fallbackDelay] in
                try? await Task.sleep(for: fallbackDelay)
                guard !Task.isCancelled else { return }
                self?.announcePending(locale: locale)
            }
        }
        announceIfDrawn(locale: locale)
    }

    /// Called by the chart with the y domain it drew.
    func recordDomain(_ values: [Double], for choice: ChoosingAxisValuesChoice) {
        guard let lower = values.min(), let upper = values.max() else { return }
        reportedDomain = (choice, lower ... upper)
    }

    /// A control changed what is drawn: announce it once the chart reports.
    private func awaitDrawing() {
        fallbackTask?.cancel()
        fallbackTask = nil
        pendingAnnouncement = choice
    }

    private func announceIfDrawn(locale: Locale) {
        guard drawnValues != nil else { return }
        announcePending(locale: locale)
    }

    /// Announces the pending setting if it is the current one and its count is known, whether or not
    /// every label has reported.
    private func announcePending(locale: Locale) {
        guard let pending = pendingAnnouncement, pending == choice, actualCount != nil else { return }
        pendingAnnouncement = nil
        fallbackTask?.cancel()
        fallbackTask = nil
        announce("\(changeSentence(locale: locale)) \(headline(locale: locale))")
    }

    // MARK: Words

    /// What the setting now is, for the announcement: what changed, before the headline.
    func changeSentence(locale: Locale) -> String {
        switch choice {
        case let .automatic(desiredCount):
            "Axis values: about \(ChoosingAxisValuesWording.values(desiredCount, locale: locale))."
        case let .stride(by: step):
            "Axis values: one every \(CafeWording.cups(step, locale: locale))."
        case let .exact(values):
            "Axis values: exactly \(ChoosingAxisValuesWording.numbers(values.map(Double.init), locale: locale))."
        }
    }

    /// The chart's message, true for the setting and for what the axis drew.
    func headline(locale: Locale) -> String {
        guard hasData else { return "No cups sold yet today." }
        // The count is known from the first label that reports; the span only once every one has.
        let count = drawnValues?.count ?? actualCount
        let span = drawnValues.flatMap { values -> String? in
            guard let first = values.first, let last = values.last else { return nil }
            let firstText = first.formatted(.number.locale(locale))
            return first == last ? ", at \(firstText)" : ", from \(firstText) to \(last.formatted(.number.locale(locale)))"
        } ?? ""
        switch choice {
        case let .automatic(desiredCount):
            let asked = "Asked for about \(ChoosingAxisValuesWording.values(desiredCount, locale: locale))"
            guard let count else { return "\(asked)." }
            return "\(asked); the axis drew \(count.formatted(.number.locale(locale)))\(span)."
        case let .stride(by: step):
            let every = "A value every \(CafeWording.cups(step, locale: locale))"
            guard let count else { return "\(every)." }
            return "\(every): \(ChoosingAxisValuesWording.values(count, locale: locale))\(span)."
        case let .exact(values):
            let exactly = "Exactly \(ChoosingAxisValuesWording.numbers(values.map(Double.init), locale: locale))"
            guard let top = values.max(), top > tallestCups else { return "\(exactly)." }
            let names = CafeWording.list(tallest.map(\.drink))
            return "\(exactly): \(top.formatted(.number.locale(locale))) stretches the axis above \(names), the tallest bar."
        }
    }

    /// The stepper's text: the count asked for against the count drawn.
    func countComparison(locale: Locale) -> String {
        let asked = "Asked for \(desiredCount.formatted(.number.locale(locale)))"
        guard mode == .automatic, let actualCount else { return asked }
        return "\(asked), drew \(actualCount.formatted(.number.locale(locale)))"
    }

    /// What the stepper speaks as its value: the setting, then the headline, in place of an announcement
    /// on every step. "Asked for 4, drew 5. Asked for about 4 values; the axis drew 5, from 0 to 200."
    func stepperSpokenValue(locale: Locale) -> String {
        // The headline already gives the count asked for and the count drawn.
        headline(locale: locale)
    }

    /// The summary the Audio Graph speaks: actual values, and the axis values drawn.
    func audioGraphSummary(locale: Locale) -> String {
        guard hasData, let fewest = sales.map(\.cups).min() else { return "No cups sold yet today." }
        let slowest = sales.filter { $0.cups == fewest }.map(\.drink)
        var summary = "\(CafeWording.drinks(sales.count, locale: locale)). "
            + "Most: \(CafeWording.list(tallest.map(\.drink))), \(CafeWording.cups(tallestCups, locale: locale)). "
            + "Fewest: \(CafeWording.list(slowest)), \(CafeWording.cups(fewest, locale: locale))."
        if let drawnValues {
            summary += " Axis values: \(ChoosingAxisValuesWording.numbers(drawnValues, locale: locale))."
        }
        return summary
    }

    /// The code the Code view shows for the current setting.
    var snippets: [SnippetReference] {
        let mode = switch self.mode {
        case .automatic: SnippetReference(name: "choosing-axis-values-automatic", title: "About this many: .automatic(desiredCount:)")
        case .stride: SnippetReference(name: "choosing-axis-values-stride", title: "Every multiple: .stride(by:)")
        case .exact: SnippetReference(name: "choosing-axis-values-exact", title: "Exactly these, widening the scale: an array")
        }
        return [
            SnippetReference(name: "choosing-axis-values-chart", title: "The chart and its y axis"),
            mode,
            SnippetReference(name: "choosing-axis-values-drawn", title: "How many were drawn: AxisValue.count"),
        ]
    }
}
