import CoreGraphics
import Foundation
import Observation

// MARK: Words

/// Words this screen needs that `CafeWording` does not have, kept here so the shared file is not edited.
nonisolated enum KeyPathsWording {
    static let timeOfDay = TimeOfDayWording.timeOfDay
    static let waitAxisTitle = TimeOfDayWording.waitAxisTitle
    static let wait = TimeOfDayWording.wait
    static let orderSize = "Order size"
    static let minutesPerCup = "Minutes a cup"
    static let shift = "Shift"

    /// "1 minute", "11.2 minutes", with at most one decimal place.
    static func minutes(_ amount: Double, locale: Locale) -> String {
        TimeOfDayWording.minutes(amount, locale: locale)
    }

    /// "1 hour", "6.5 hours", with at most one decimal place.
    static func hours(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 1))) hour](inflect: true)",
            locale: locale
        ).characters)
    }

    /// A time of the sample day, written in UTC, the time zone the sample dates were made in: "8:04 AM".
    static func time(_ date: Date, locale: Locale) -> String {
        TimeOfDayWording.time(date, locale: locale)
    }

    /// Hours since midnight on the sample day, for a date of that day.
    static func hours(since date: Date) -> Double {
        date.timeIntervalSince(CafeData.firstDay) / 3600
    }

    /// The order sizes as categories, "1 cup" to "4 cups". Written in English whatever the view's locale,
    /// because they are data, the same in every legend: the digits 1 to 4 do not change between the
    /// locales the app shows.
    static func orderSize(cups: Int) -> String {
        CafeWording.cups(cups, locale: CafeWording.listLocale)
    }
}

// MARK: Plotted values

/// One order as the point plot reads it. Every property a key path points at is stored, worked out once
/// here, so the plot never runs a getter per point.
nonisolated struct KeyPathsOrder: Identifiable, Hashable {
    let id: Int
    let drink: String
    let time: Date
    /// The same moment as hours since midnight, for the spoken stretches of the day.
    let hour: Double
    let waitMinutes: Double
    let cups: Double
    let orderSize: String
    let minutesPerCup: Double
    /// From `KeyPathsOrderOpacity.lowest` to 1, rising with the property it is named after.
    let waitOpacity: CGFloat
    let minutesPerCupOpacity: CGFloat
    let cupsOpacity: CGFloat

    /// Turns orders into points, scaling each opacity across the whole collection.
    static func make(from orders: [CafeOrder]) -> [KeyPathsOrder] {
        let waits = Range(orders.map(\.waitMinutes))
        let perCup = Range(orders.map(\.minutesPerCup))
        let cups = Range(orders.map { Double($0.cups) })
        let dayStart = CafeData.time(0)
        return orders.map { order in
            let time = dayStart.addingTimeInterval(order.hour * 3600)
            let size = KeyPathsWording.orderSize(cups: order.cups)
            return KeyPathsOrder(
                id: order.id,
                drink: order.drink,
                time: time,
                hour: order.hour,
                waitMinutes: order.waitMinutes,
                cups: Double(order.cups),
                orderSize: size,
                minutesPerCup: order.minutesPerCup,
                waitOpacity: waits.opacity(of: order.waitMinutes),
                minutesPerCupOpacity: perCup.opacity(of: order.minutesPerCup),
                cupsOpacity: cups.opacity(of: Double(order.cups))
            )
        }
    }

    /// The lowest and highest of some values, to scale an opacity between.
    private struct Range {
        let lowest: Double
        let highest: Double

        init(_ values: [Double]) {
            lowest = values.min() ?? 0
            highest = values.max() ?? 0
        }

        func opacity(of value: Double) -> CGFloat {
            guard highest > lowest else { return 1 }
            let fraction = (value - lowest) / (highest - lowest)
            return KeyPathsOrderOpacity.lowest + (1 - KeyPathsOrderOpacity.lowest) * fraction
        }
    }
}

/// The faintest a point is drawn, so the lowest value is still visible.
nonisolated enum KeyPathsOrderOpacity {
    static let lowest: CGFloat = 0.2
}

/// One shift as the interval plot reads it, with what VoiceOver says for it stored.
nonisolated struct KeyPathsShift: Identifiable, Hashable {
    let id: Int
    let barista: String
    let start: Date
    let end: Date
    /// The name, then from start to end and how long: read from the accessibility representation.
    let spokenLabel: String
    let spokenValue: String

    var startHour: Double {
        KeyPathsWording.hours(since: start)
    }

    var endHour: Double {
        KeyPathsWording.hours(since: end)
    }

    var hours: Double {
        end.timeIntervalSince(start) / 3600
    }

    static func make(from shifts: [Shift], locale: Locale) -> [KeyPathsShift] {
        shifts.map { shift in
            let hours = shift.end.timeIntervalSince(shift.start) / 3600
            return KeyPathsShift(
                id: shift.id,
                barista: shift.barista,
                start: shift.start,
                end: shift.end,
                spokenLabel: shift.barista,
                spokenValue: "\(KeyPathsWording.time(shift.start, locale: locale)) to "
                    + "\(KeyPathsWording.time(shift.end, locale: locale)), \(KeyPathsWording.hours(hours, locale: locale))"
            )
        }
    }
}

// MARK: Choices

/// Which example the chart shows.
nonisolated enum KeyPathsExample: String, CaseIterable, Identifiable {
    case orders = "Orders"
    case shifts = "Shifts"

    var id: Self {
        self
    }
}

/// A property of an order that a style can show. Order size is the number of cups as a category,
/// so it is the same field as cups.
nonisolated enum KeyPathsField {
    case drink
    case cups
    case minutesPerCup
    case wait

    /// The field as a sentence names it: "cups".
    var words: String {
        switch self {
        case .drink: "drink"
        case .cups: "cups"
        case .minutesPerCup: "minutes a cup"
        case .wait: "wait"
        }
    }
}

/// The property that drives each point's colour and shape.
nonisolated enum KeyPathsColour: String, CaseIterable, Identifiable {
    case drink
    case orderSize

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .drink: CafeWording.drink
        case .orderSize: KeyPathsWording.orderSize
        }
    }

    // snippet:key-paths-colour-choices
    var keyPath: KeyPath<KeyPathsOrder, String> {
        switch self {
        case .drink: \.drink
        case .orderSize: \.orderSize
        }
    }

    // end

    var field: KeyPathsField {
        switch self {
        case .drink: .drink
        case .orderSize: .cups
        }
    }

    /// Every value the colour can take, in legend order.
    var domain: [String] {
        switch self {
        case .drink: CafeData.manyOrderDrinks
        case .orderSize: (1 ... 4).map { KeyPathsWording.orderSize(cups: $0) }
        }
    }
}

/// The property that drives each point's size.
nonisolated enum KeyPathsSize: String, CaseIterable, Identifiable {
    case cups
    case minutesPerCup

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .cups: CafeWording.cups
        case .minutesPerCup: KeyPathsWording.minutesPerCup
        }
    }

    // snippet:key-paths-size-choices
    var keyPath: KeyPath<KeyPathsOrder, Double> {
        switch self {
        case .cups: \.cups
        case .minutesPerCup: \.minutesPerCup
        }
    }

    // end

    var field: KeyPathsField {
        switch self {
        case .cups: .cups
        case .minutesPerCup: .minutesPerCup
        }
    }
}

/// The property that drives each point's opacity.
nonisolated enum KeyPathsOpacity: String, CaseIterable, Identifiable {
    case wait
    case minutesPerCup
    case cups

    var id: Self {
        self
    }

    var title: String {
        switch self {
        case .wait: KeyPathsWording.wait
        case .minutesPerCup: KeyPathsWording.minutesPerCup
        case .cups: CafeWording.cups
        }
    }

    // snippet:key-paths-opacity-choices
    /// A key path to a stored `CGFloat` from 0 to 1, worked out once per order.
    var keyPath: KeyPath<KeyPathsOrder, CGFloat> {
        switch self {
        case .wait: \.waitOpacity
        case .minutesPerCup: \.minutesPerCupOpacity
        case .cups: \.cupsOpacity
        }
    }

    // end

    var field: KeyPathsField {
        switch self {
        case .wait: .wait
        case .minutesPerCup: .minutesPerCup
        case .cups: .cups
        }
    }
}

// MARK: What the chart says

/// The orders chart in words: its headline and the Audio Graph's summary.
nonisolated struct KeyPathsOrdersSummary {
    let orders: [KeyPathsOrder]
    let locale: Locale

    /// Every order that waited the longest, in data order.
    var longestWaits: [KeyPathsOrder] {
        guard let longest = orders.map(\.waitMinutes).max() else { return [] }
        return orders.filter { $0.waitMinutes == longest }
    }

    var headline: String {
        guard let longest = longestWaits.first else { return "No orders yet today." }
        let count = CafeWording.orders(orders.count, locale: locale)
        let wait = KeyPathsWording.minutes(longest.waitMinutes, locale: locale)
        if longestWaits.count > 1 {
            return "Of \(count), the longest wait was \(wait), shared by \(CafeWording.orders(longestWaits.count, locale: locale))."
        }
        return "Of \(count), the longest wait was \(wait): "
            + "\(CafeWording.cups(Int(longest.cups), locale: locale)) of \(longest.drink) at \(KeyPathsWording.time(longest.time, locale: locale))."
    }

    /// The day in stretches as VoiceOver reads it, each counting its orders by the colour's values.
    func portions(colour: KeyPathsColour) -> [TimeOfDayPortion] {
        TimeOfDayPortion.make(
            orders, hour: \.hour, wait: \.waitMinutes,
            category: { $0[keyPath: colour.keyPath] }, categoryOrder: colour.domain
        )
    }

    /// Actual values only: how many, over what time, the range of waits, and how many in each colour.
    func audioGraphSummary(colour: KeyPathsColour) -> String {
        guard let first = orders.map(\.time).min(), let last = orders.map(\.time).max(),
              let shortest = orders.map(\.waitMinutes).min(), let longest = orders.map(\.waitMinutes).max()
        else { return "No orders yet today." }
        let counts = colour.domain.map { value in
            "\(value), \(CafeWording.orders(orders.count(where: { $0[keyPath: colour.keyPath] == value }), locale: locale))"
        }
        return "\(CafeWording.orders(orders.count, locale: locale)) from \(KeyPathsWording.time(first, locale: locale)) "
            + "to \(KeyPathsWording.time(last, locale: locale)). "
            + "Waits from \(KeyPathsWording.minutes(shortest, locale: locale)) to \(KeyPathsWording.minutes(longest, locale: locale)). "
            + "By \(colour.title.lowercased()): \(counts.joined(separator: "; "))."
    }
}

/// The shifts chart in words.
nonisolated struct KeyPathsShiftsSummary {
    let shifts: [KeyPathsShift]
    let locale: Locale

    /// Every shift that is the longest, in data order.
    var longestShifts: [KeyPathsShift] {
        guard let longest = shifts.map(\.hours).max() else { return [] }
        return shifts.filter { $0.hours == longest }
    }

    var headline: String {
        guard let longest = longestShifts.first else { return "No shifts on the rota today." }
        let count = CafeWording.shifts(shifts.count, locale: locale)
        let hours = KeyPathsWording.hours(longest.hours, locale: locale)
        if longestShifts.count > 1 {
            let names = CafeWording.list(longestShifts.map { "\($0.barista)’s" })
            return "Of \(count), the longest are \(names): \(hours) each."
        }
        return "Of \(count), the longest is \(longest.barista)’s: \(hours), "
            + "\(KeyPathsWording.time(longest.start, locale: locale)) to \(KeyPathsWording.time(longest.end, locale: locale))."
    }

    var audioGraphSummary: String {
        guard let first = shifts.map(\.start).min(), let last = shifts.map(\.end).max() else {
            return "No shifts on the rota today."
        }
        return "\(CafeWording.shifts(shifts.count, locale: locale)) from \(KeyPathsWording.time(first, locale: locale)) "
            + "to \(KeyPathsWording.time(last, locale: locale)). "
            + shifts.map(\.spokenLabelAndValue).joined(separator: "; ") + "."
    }

    /// The category each shift is described under: the barista, numbered when they work more than one shift.
    var categories: [String] {
        shifts.map { shift in
            let theirs = shifts.filter { $0.barista == shift.barista }
            guard theirs.count > 1, let index = theirs.firstIndex(of: shift) else { return shift.barista }
            return "\(shift.barista), \(KeyPathsWording.shift.lowercased()) \((index + 1).formatted(.number.locale(locale)))"
        }
    }
}

extension KeyPathsShift {
    nonisolated var spokenLabelAndValue: String {
        "\(spokenLabel), \(spokenValue)"
    }
}

// MARK: View model

/// The state of the "Key paths" screen: the example shown, which property drives colour, size and
/// opacity, and whether the size scale's range is left out.
@Observable
final class KeyPathsViewModel {
    /// A modest number of orders: enough to make a plot worth it, few enough for every point to be seen.
    static let orderCount = 400

    var example: KeyPathsExample = .orders
    var colour: KeyPathsColour = .drink
    var size: KeyPathsSize = .cups
    var opacity: KeyPathsOpacity = .wait
    /// The mistake: `symbolSize(by:)` with no `chartSymbolSizeScale(range:)`.
    var leavesOutSizeScale = false

    private(set) var locale: Locale
    /// The points, one array per colour choice, each grouped by the property that drives its colour,
    /// so the style changes as few times as possible along the collection.
    private var ordersByColour: [KeyPathsColour: [KeyPathsOrder]] = [:]
    private(set) var shifts: [KeyPathsShift] = []
    private let sourceOrders: [CafeOrder]
    private let sourceShifts: [Shift]

    init(
        orders: [CafeOrder] = CafeData.manyOrders(count: KeyPathsViewModel.orderCount),
        shifts: [Shift] = CafeData.shifts,
        locale: Locale = .current
    ) {
        sourceOrders = orders
        sourceShifts = shifts
        self.locale = locale
        rebuild()
    }

    /// Rewrites the spoken text in the view's locale. Called by the view when its locale is known or changes.
    func update(locale: Locale) {
        guard locale != self.locale else { return }
        self.locale = locale
        rebuild()
    }

    private func rebuild() {
        let points = KeyPathsOrder.make(from: sourceOrders)
        ordersByColour = Dictionary(uniqueKeysWithValues: KeyPathsColour.allCases.map { colour in
            let order = colour.domain
            let sorted = points.enumerated().sorted { lhs, rhs in
                let left = order.firstIndex(of: lhs.element[keyPath: colour.keyPath]) ?? order.count
                let right = order.firstIndex(of: rhs.element[keyPath: colour.keyPath]) ?? order.count
                return left == right ? lhs.offset < rhs.offset : left < right
            }
            return (colour, sorted.map(\.element))
        })
        shifts = KeyPathsShift.make(from: sourceShifts, locale: locale)
    }

    /// The points as plotted for the current colour choice.
    var orders: [KeyPathsOrder] {
        ordersByColour[colour] ?? []
    }

    var ordersSummary: KeyPathsOrdersSummary {
        KeyPathsOrdersSummary(orders: orders, locale: locale)
    }

    var shiftsSummary: KeyPathsShiftsSummary {
        KeyPathsShiftsSummary(shifts: shifts, locale: locale)
    }

    /// Whether the current example has nothing to draw, so a placeholder shows in its place.
    var isEmpty: Bool {
        switch example {
        case .orders: orders.isEmpty
        case .shifts: shifts.isEmpty
        }
    }

    var headline: String {
        switch example {
        case .orders: ordersSummary.headline
        case .shifts: shiftsSummary.headline
        }
    }

    var caption: String {
        switch example {
        case .orders: "Wait for each order, by time of day"
        case .shifts: "Shifts on the first day"
        }
    }

    /// What the legends do not say, under the pickers: what the size legend's numbers are, what opacity shows
    /// (it has no legend), and when two styles show the same field.
    var encodingNote: String {
        var note = "The size legend's numbers are \(size.field.words). Opacity shows \(opacity.field.words), "
            + "faintest for the lowest; it has no legend."
        let styles: [(name: String, field: KeyPathsField)] = [
            ("colour", colour.field), ("size", size.field), ("opacity", opacity.field),
        ]
        for field in [KeyPathsField.cups, .minutesPerCup] {
            let sharing = styles.filter { $0.field == field }.map(\.name)
            guard sharing.count > 1 else { continue }
            let names = CafeWording.list(sharing)
            let verb = sharing.count == 2 ? "both show" : "all show"
            let times = sharing.count == 2 ? "twice" : "three times"
            note += " \(names.prefix(1).uppercased() + names.dropFirst()) \(verb) \(field.words): one field, encoded \(times)."
        }
        return note
    }

    /// Why VoiceOver's version differs from the drawn plot, under the Example picker.
    var spokenNote: String {
        switch example {
        case .orders:
            "VoiceOver reads the orders two hours at a time, from labelled marks in an accessibility representation: "
                + "a plot's own elements give no units, and its key-path labels are not read."
        case .shifts:
            "VoiceOver reads each shift from a labelled mark in an accessibility representation: the plot's own "
                + "elements give an hour around each bar's middle, never its start and end."
        }
    }

    /// Whether the controls for colour, size and opacity apply: only to the orders, and only when drawn.
    var showsEncodingControls: Bool {
        example == .orders
    }

    // MARK: Announcements

    func exampleAnnouncement() -> String {
        switch example {
        case .orders: "Now showing each order as a point. \(headline)"
        case .shifts: "Now showing each shift as a bar from its start to its end. \(headline)"
        }
    }

    func colourAnnouncement() -> String {
        "Colour and shape now show \(colour.title.lowercased()). \(headline)"
    }

    func sizeAnnouncement() -> String {
        "Size now shows \(size.title.lowercased()). \(headline)"
    }

    func opacityAnnouncement() -> String {
        "Opacity now shows \(opacity.title.lowercased()). \(headline)"
    }

    // MARK: Snippets

    /// The snippets that describe what is drawn now.
    var snippets: [SnippetReference] {
        switch example {
        case .orders:
            [
                SnippetReference(name: "key-paths-point-plot", title: "A point plot styled from key paths"),
                leavesOutSizeScale
                    ? SnippetReference(name: "key-paths-no-size-scale", title: "No size scale: the default range")
                    : SnippetReference(name: "key-paths-size-scale", title: "The range of sizes"),
                SnippetReference(name: "key-paths-colour-choices", title: "Key paths for colour"),
                SnippetReference(name: "key-paths-size-choices", title: "Key paths for size"),
                SnippetReference(name: "key-paths-opacity-choices", title: "Key paths for opacity"),
                SnippetReference(name: "key-paths-spoken-orders", title: "What VoiceOver reads for the orders"),
            ]
        case .shifts:
            [
                SnippetReference(name: "key-paths-interval", title: "An interval from two key paths"),
                SnippetReference(name: "key-paths-spoken-shifts", title: "What VoiceOver reads for the shifts"),
            ]
        }
    }
}
