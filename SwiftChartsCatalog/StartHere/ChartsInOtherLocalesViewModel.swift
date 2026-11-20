import Foundation
import Observation
import SwiftUI

/// The locales the screen can force on its chart. The app itself stays in English.
enum ChartLocaleChoice: String, CaseIterable, Identifiable {
    case device
    case german
    case french
    case japanese
    case arabic
    case hebrew

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .device: "Device"
        case .german: "German (Germany)"
        case .french: "French (France)"
        case .japanese: "Japanese (Japan)"
        case .arabic: "Arabic (Egypt)"
        case .hebrew: "Hebrew (Israel)"
        }
    }

    /// `nil` follows the device.
    var locale: Locale? {
        switch self {
        case .device: nil
        case .german: Locale(identifier: "de_DE")
        case .french: Locale(identifier: "fr_FR")
        case .japanese: Locale(identifier: "ja_JP")
        case .arabic: Locale(identifier: "ar_EG")
        case .hebrew: Locale(identifier: "he_IL")
        }
    }
}

/// One café's cups sold so far, day by day: each day's `cups` is the total up to and including that day.
nonisolated struct CafeRunningTotals: Identifiable, Hashable {
    let store: String
    let days: [DailySales]

    var id: String {
        store
    }

    /// Adds up a café's daily sales.
    init(sales: StoreSales) {
        store = sales.store
        var total = 0
        days = sales.days.map { day in
            total += day.cups
            return DailySales(day: day.day, cups: total)
        }
    }

    var finalTotal: Int {
        days.last?.cups ?? 0
    }

    /// The days in runs of seven, the stretch one accessibility element describes.
    var weeks: [RunningWeek] {
        stride(from: 0, to: days.count, by: RunningWeek.length).map { start in
            RunningWeek(store: store, days: Array(days[start ..< min(start + RunningWeek.length, days.count)]))
        }
    }
}

/// Up to seven days of one café's running total.
nonisolated struct RunningWeek: Identifiable, Hashable {
    static let length = 7

    let store: String
    let days: [DailySales]

    var id: String {
        "\(store)-\(days.first?.day.timeIntervalSinceReferenceDate ?? 0)"
    }
}

/// What the chart says in words. Everything here is formatted for a locale that is passed in,
/// so the same sentence can be written for any reader.
nonisolated struct RunningTotalsSummary {
    let cafes: [CafeRunningTotals]
    var locale: Locale = .current

    /// The cups axis as drawn: from zero to the highest running total rounded up to the axis step (0 to 6,000 for
    /// 5,726). The chart's scale and the descriptor's range, so the Audio Graph reads the ends the chart draws.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: cafes.map(\.finalTotal))
    }

    /// False with no cafés, no days, or nothing sold: the chart shows a placeholder.
    var hasData: Bool {
        cafes.contains { $0.finalTotal > 0 }
    }

    /// Every café with the highest total on the last day, in data order.
    var leaders: [CafeRunningTotals] {
        guard hasData, let most = cafes.map(\.finalTotal).max() else { return [] }
        return cafes.filter { $0.finalTotal == most }
    }

    /// The chart's message. It carries no figure, because the chart writes its figures in the locale under test.
    var headline: String {
        guard !leaders.isEmpty else { return "No cups sold yet." }
        if leaders.count > 1, leaders.count == cafes.count {
            return "\(names(leaders)) ended the period level."
        }
        return "\(names(leaders)) ended the period with the most cups sold."
    }

    /// Actual values only: the period, then each café's total on the last day.
    var audioGraphSummary: String {
        guard hasData, let first = cafes.first?.days.first?.day, let last = cafes.first?.days.last?.day else {
            return "No cups sold yet."
        }
        let totals = cafes.map { "\($0.store) \(cupsText($0.finalTotal))" }.formatted(.list(type: .and).locale(locale))
        return "Running totals from \(dayText(first)) to \(dayText(last)). On the last day: \(totals)."
    }

    func names(_ cafes: [CafeRunningTotals]) -> String {
        cafes.map(\.store).formatted(.list(type: .and).locale(locale))
    }

    /// A count with its unit, agreeing in number: "1 cup", "5,726 cups".
    func cupsText(_ cups: Int) -> String {
        let number = cups.formatted(.number.locale(locale))
        return cups == 1 ? "\(number) cup" : "\(number) cups"
    }

    /// A day written out, in the time zone the data was counted in: "March 1".
    func dayText(_ day: Date) -> String {
        day.formatted(
            Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
                .month(.wide).day()
        )
    }

    /// What VoiceOver calls one week of one café's line: the café, then the days.
    func weekLabel(_ week: RunningWeek) -> String {
        guard let first = week.days.first?.day, let last = week.days.last?.day else { return week.store }
        return first == last ? "\(week.store), \(dayText(first))" : "\(week.store), \(dayText(first)) to \(dayText(last))"
    }

    /// The running total at the start and the end of the week, with its unit.
    func weekValue(_ week: RunningWeek) -> String {
        guard let first = week.days.first?.cups, let last = week.days.last?.cups else { return "" }
        return "Running total from \(cupsText(first)) to \(cupsText(last))"
    }
}

// snippet:charts-in-other-locales-mistake-strings
/// The mistake: text and numbers put together by hand. Each result is a finished string,
/// so it reads the same in every locale: English month names, Latin digits, no grouping.
nonisolated enum BakedLabels {
    static let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

    static func day(_ date: Date) -> String {
        let parts = CafeData.calendar.dateComponents([.month, .day], from: date)
        guard let month = parts.month, let day = parts.day, months.indices.contains(month - 1) else { return "" }
        return "\(months[month - 1]) \(day)"
    }

    static func cups(_ cups: Int) -> String {
        "\(cups)"
    }

    static func total(stores: [String], cups: Int) -> String {
        "\(stores.joined(separator: " and ")): \(cups) cups"
    }
}

// end

/// The state of "Charts in other locales": the locale and direction forced on the chart, and whether
/// its labels are the hand-made strings that cannot adapt.
@Observable
final class ChartsInOtherLocalesViewModel {
    var localeChoice: ChartLocaleChoice = .device
    var isRightToLeft = false
    var isShowingMistake = false
    let cafes: [CafeRunningTotals]

    init(stores: [StoreSales] = CafeData.storeSales) {
        cafes = stores.map(CafeRunningTotals.init)
    }

    /// What the chart alone is drawn under. The rest of the screen follows the device.
    var environment: ChartEnvironment {
        ChartEnvironment(locale: localeChoice.locale, layoutDirection: isRightToLeft ? .rightToLeft : nil)
    }

    var headline: String {
        RunningTotalsSummary(cafes: cafes).headline
    }

    /// How the chart is being shown, for the Audio Graph's summary and the announcement of a change.
    var displayDescription: String {
        let formats = localeChoice == .device ? "the device's formats" : "\(localeChoice.title) formats"
        let direction = isRightToLeft ? "laid out right to left" : "in the device's layout direction"
        let labels = isShowingMistake
            ? " Its axis labels and end label are fixed English strings that ignore the locale."
            : ""
        return "Shown in \(formats), \(direction).\(labels)"
    }

    var snippets: [SnippetReference] {
        if isShowingMistake {
            [
                SnippetReference(name: "charts-in-other-locales-mistake-strings", title: "The mistake: strings made by hand"),
                SnippetReference(name: "charts-in-other-locales-mistake-x-axis", title: "The mistake: a string for each date"),
                SnippetReference(name: "charts-in-other-locales-mistake-y-axis", title: "The mistake: a string for each number"),
                SnippetReference(name: "charts-in-other-locales-mistake-annotation", title: "The mistake: a string in the annotation"),
            ]
        } else {
            [
                SnippetReference(name: "charts-in-other-locales-marks", title: "Values go in as dates and numbers"),
                SnippetReference(name: "charts-in-other-locales-x-axis", title: "Date labels from a format style"),
                SnippetReference(name: "charts-in-other-locales-y-axis", title: "Number labels: the default axis"),
                SnippetReference(name: "charts-in-other-locales-annotation", title: "A formatted value in an annotation"),
            ]
        }
    }
}
