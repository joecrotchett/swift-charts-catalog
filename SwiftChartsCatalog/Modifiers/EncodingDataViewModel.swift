import Foundation
import Observation

/// The mark characteristic that carries the café: what the reader picks on the Encoding data screen.
nonisolated enum EncodingDataCharacteristic: String, CaseIterable, Identifiable {
    case colour
    case position
    case symbol
    case symbolSize
    case lineStyle

    var id: String {
        rawValue
    }

    /// The picker's words.
    var title: String {
        switch self {
        case .colour: "Colour"
        case .position: "Position"
        case .symbol: "Symbol"
        case .symbolSize: "Symbol size"
        case .lineStyle: "Line style"
        }
    }

    /// The modifier that encodes the café this way.
    var modifier: String {
        switch self {
        case .colour: "foregroundStyle(by:)"
        case .position: "position(by:)"
        case .symbol: "symbol(by:)"
        case .symbolSize: "symbolSize(by:)"
        case .lineStyle: "lineStyle(by:)"
        }
    }

    /// The mark drawn for this characteristic. Position applies to bars, symbol size to points;
    /// the other three are shown on lines.
    var mark: EncodingDataMark {
        switch self {
        case .colour, .symbol, .lineStyle: .line
        case .position: .bar
        case .symbolSize: .point
        }
    }

    /// The snippet showing this characteristic's chart.
    var snippet: SnippetReference {
        SnippetReference(name: "encoding-data-\(snippetSuffix)", title: modifier)
    }

    private var snippetSuffix: String {
        switch self {
        case .colour: "colour"
        case .position: "position"
        case .symbol: "symbol"
        case .symbolSize: "symbol-size"
        case .lineStyle: "line-style"
        }
    }

    /// The sentence announced when the reader switches to this characteristic, before the headline.
    var changeSentence: String {
        switch self {
        case .colour: "The café is now shown by colour, on two lines."
        case .position: "The café is now shown by position, as bars side by side."
        case .symbol: "The café is now shown by symbol, on two lines."
        case .symbolSize: "The café is now shown by symbol size, as points."
        case .lineStyle: "The café is now shown by line style, on two lines."
        }
    }

    /// What this modifier does to the chart and its legend: the screen's explanation for this setting.
    var explanation: String {
        switch self {
        case .colour:
            """
            foregroundStyle(by:) gives each café a colour and adds a legend of colour swatches; on lines it also \
            keeps the two cafés apart. Colour alone fails anyone who cannot tell the colours apart, so with \
            Differentiate Without Colour turned on this chart adds a symbol to each line as well.
            """
        case .position:
            """
            position(by:) places the cafés' bars side by side within each day instead of stacking them. It is the \
            one by: modifier that adds no legend, so nothing on the chart names the bars: here the leading bar of each \
            pair is Harbour, the left one in a left-to-right layout and the right one in right-to-left. A grouped \
            bar chart pairs it with foregroundStyle(by:) on the same property.
            """
        case .symbol:
            """
            symbol(by:) gives each café its own point shape, draws it at every point of a line and keeps the two \
            lines apart; the legend shows the shapes. It takes a category, and is usually paired with \
            foregroundStyle(by:) so the cafés differ in two ways.
            """
        case .symbolSize:
            """
            symbolSize(by:) draws each café's points at a different size, and the legend shows the sizes. It sizes \
            symbols, so this setting draws points instead of lines; chartSymbolSizeScale chooses the sizes. Size \
            reads as "more", so it suits a quantity better than a name.
            """
        case .lineStyle:
            """
            lineStyle(by:) gives each café its own dash pattern, solid then dashed, and keeps the two lines apart; \
            the legend shows a sample of each. It only changes lines and rules, and works without colour.
            """
        }
    }
}

/// The kind of mark a characteristic is drawn on.
nonisolated enum EncodingDataMark: Equatable {
    case line
    case bar
    case point

    /// Whether the Audio Graph should hear one connected shape per café.
    var isContinuous: Bool {
        self == .line
    }

    /// Whether the marks grow from zero, so a chart of only zeros is shown as a placeholder.
    var growsFromZero: Bool {
        self == .bar
    }
}

/// The state of the Encoding data screen: the week shown and which characteristic carries the café.
@Observable
final class EncodingDataViewModel {
    /// The cafés' first week.
    let stores: [StoreSales]
    var characteristic: EncodingDataCharacteristic = .colour

    init(stores: [StoreSales] = EncodingDataViewModel.firstWeek, characteristic: EncodingDataCharacteristic = .colour) {
        self.stores = stores
        self.characteristic = characteristic
    }

    /// Both cafés, cut to their first seven days: few enough for grouped bars to read on a phone.
    nonisolated static let firstWeek: [StoreSales] = CafeData.storeSales.map {
        StoreSales(store: $0.store, days: Array($0.days.prefix(7)))
    }

    func summary(locale: Locale) -> EncodingDataSummary {
        EncodingDataSummary(stores: stores, locale: locale)
    }

    var explanation: String {
        characteristic.explanation
    }

    /// The code for the current setting.
    var snippets: [SnippetReference] {
        [characteristic.snippet]
    }

    /// No data, or only zeros on bars, which would be axes with nothing standing on them.
    var showsPlaceholder: Bool {
        let summary = summary(locale: CafeWording.listLocale)
        return summary.isEmpty || (summary.isAllZero && characteristic.mark.growsFromZero)
    }

    /// What VoiceOver says after the picker changes: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        "\(characteristic.changeSentence) \(summary(locale: locale).headline)"
    }
}

/// What the chart says in words, worked out from the data: the headline, the element text and the
/// Audio Graph's summary.
nonisolated struct EncodingDataSummary {
    let stores: [StoreSales]
    /// The locale every number and date is written in. It has no default: the view passes its environment's.
    let locale: Locale

    var isEmpty: Bool {
        stores.allSatisfy(\.days.isEmpty)
    }

    var isAllZero: Bool {
        stores.allSatisfy { $0.days.allSatisfy { $0.cups == 0 } }
    }

    /// The days in order, from the first café that has any.
    var days: [Date] {
        stores.first { !$0.days.isEmpty }?.days.map(\.day) ?? []
    }

    /// For each café in data order, the days on which it sold strictly more than every other café.
    var daysLed: [(store: String, count: Int)] {
        stores.map { store in
            let count = days.count(where: { day in
                guard let cups = cups(store.store, on: day) else { return false }
                return stores.allSatisfy { other in
                    other.store == store.store || (self.cups(other.store, on: day) ?? 0) < cups
                }
            })
            return (store.store, count)
        }
    }

    /// The days on which two or more cafés shared the highest figure.
    var tiedDays: Int {
        days.count - daysLed.map(\.count).reduce(0, +)
    }

    /// The chart's message: which café sold more on how many days. True on ties, zeros and no data.
    var headline: String {
        if isEmpty { return "No sales to show." }
        if isAllZero { return "Neither café sold a cup this week." }
        let leaders = daysLed.filter { $0.count > 0 }.sorted { $0.count > $1.count }
        let tie = tiedDays > 0 ? "the same on \(CafeWording.days(tiedDays, locale: locale))" : nil
        guard let first = leaders.first else {
            return "The cafés sold \(tie ?? "the same every day")."
        }
        var parts = ["\(first.store) sold more on \(CafeWording.days(first.count, locale: locale))"]
        parts += leaders.dropFirst().map { "\($0.store) on \(CafeWording.days($0.count, locale: locale))" }
        if let tie { parts.append("both \(tie)") }
        return parts.joined(separator: ", ") + "."
    }

    /// The Audio Graph's summary: actual values for each café, then the headline.
    var audioGraphSummary: String {
        guard !isEmpty else { return headline }
        let perStore = stores.map { store in
            let total = store.days.map(\.cups).reduce(0, +)
            guard let best = store.days.max(by: { $0.cups < $1.cups }) else { return "\(store.store): no days." }
            return "\(store.store): \(CafeWording.cups(total, locale: locale)) in total, "
                + "highest \(CafeWording.cups(best.cups, locale: locale)) on \(dayName(best.day))."
        }
        return "\(CafeWording.days(days.count, locale: locale)), \(CafeWording.cafes(stores.count, locale: locale)). "
            + perStore.joined(separator: " ") + " " + headline
    }

    func cups(_ store: String, on day: Date) -> Int? {
        stores.first { $0.store == store }?.days.first { $0.day == day }?.cups
    }

    /// The days drawn, from the first to the last, in the view's locale and the data's time zone:
    /// "March 1 – 7" in English (US), "1 – 7 March" in English (UK), with thin spaces round the dash. Nil when there are no days.
    var dateRange: String? {
        guard let first = days.first, let last = days.last else { return nil }
        let style = Date.IntervalFormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
            .month(.wide).day()
        return (first ..< max(first, last)).formatted(style)
    }

    /// The chart's caption, with the days drawn.
    var caption: String {
        dateRange.map { "Cups sold each day, \($0)" } ?? "Cups sold each day"
    }

    /// The Audio Graph's title, with the days drawn.
    var descriptorTitle: String {
        let title = "Cups sold each day at the Harbour and Station cafés"
        return dateRange.map { "\(title), \($0)" } ?? title
    }

    /// "Sunday, March 1": written out, in the data's own time zone so it names the day that is drawn.
    func dayName(_ day: Date) -> String {
        day.formatted(Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.wide).month(.wide).day())
    }

    /// The accessibility label of one mark: the day, then the café, as the other charts of the two cafés' days
    /// word it. The elements are visited day by day, so the day leads.
    func elementLabel(store: String, day: Date) -> String {
        "\(dayName(day)), \(store)"
    }

    /// The cups axis as drawn, from zero to the busiest day rounded up to the axis step (219 → 300): the chart's
    /// scale and the descriptor's range.
    var valueDomain: ClosedRange<Double> {
        ChartAxis.valueDomain(for: stores.flatMap(\.days).map(\.cups))
    }

    /// The accessibility value of one mark: the cups, agreeing in number.
    func elementValue(cups: Int) -> String {
        CafeWording.cups(cups, locale: locale)
    }
}
