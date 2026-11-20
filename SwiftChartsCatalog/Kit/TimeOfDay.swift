import Accessibility
import Charts
import SwiftUI

// Shared by the vectorized-plot screens that draw orders across one day (CafeData.manyOrders):
// the same axis titles, clock times, spoken stretches and axis, so each says it the same way.

/// The words, times and spoken portions the three vectorized-plot screens share. They draw the same kind of
/// data (orders across one day) three ways, so each titles its axes, writes a time and says a wait the same way.
nonisolated enum TimeOfDayWording {
    /// The x axis's visible title and its `.value` label, so the spoken axis name is the one drawn.
    static let timeOfDay = "Time of day"
    /// The `.value` label for a wait.
    static let wait = "Wait"
    /// The y axis's visible title, also the descriptor's y axis title.
    static let waitAxisTitle = "Wait (minutes)"
    /// The y axis's title at `.accessibility4` and up, where the full one meets the top label.
    static let waitAxisShortTitle = "Wait (min)"
    /// The hours the orders fall between, which every x scale covers.
    static let dayHours: ClosedRange<Double> = 6 ... 18

    /// A wait with at most one decimal place, agreeing in number: "1 minute", "11.3 minutes".
    static func minutes(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 1))) minute](inflect: true)",
            locale: locale
        ).characters)
    }

    /// The moment `hour` hours after midnight on the sample day, in the data's UTC calendar.
    static func date(hour: Double) -> Date {
        CafeData.firstDay.addingTimeInterval((hour * 3600).rounded(.down))
    }

    /// A clock time in the locale's own form, in the data's calendar so the device's time zone cannot shift it:
    /// "8:15 AM" in the United States, "08:15" in Britain. Never a forced 24-hour clock.
    static func time(_ date: Date, locale: Locale) -> String {
        date.formatted(Date.FormatStyle(
            date: .omitted, time: .shortened, locale: locale,
            calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone
        ))
    }

    /// `time(_:locale:)` for hours since midnight. "" for an hour that is not finite.
    static func time(hour: Double, locale: Locale) -> String {
        guard hour.isFinite, abs(hour) < 1000 else { return "" }
        return time(date(hour: hour), locale: locale)
    }

    /// The format of an hour's axis label: "6 AM" in the United States, in the data's calendar.
    static func hourFormat(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone).hour()
    }

    /// An axis label for hours since midnight: "6 AM", "12 PM".
    static func hourLabel(hour: Double, locale: Locale) -> String {
        guard hour.isFinite, abs(hour) < 1000 else { return "" }
        return date(hour: hour).formatted(hourFormat(locale: locale))
    }

    /// The hours an x axis labels: every three, or every six at the accessibility text sizes.
    static func labelledHours(accessibilitySize: Bool) -> [Double] {
        Array(stride(from: dayHours.lowerBound, through: dayHours.upperBound, by: accessibilitySize ? 6 : 3))
    }
}

/// One stretch of the day as VoiceOver hears it: what a plot's own elements cannot say, with units and
/// clock times. Each is one labelled element in the chart's accessibility representation.
nonisolated struct TimeOfDayPortion: Identifiable, Hashable {
    /// How many hours one element describes.
    static let hours = 2.0

    /// Where the stretch starts, in hours since midnight.
    let start: Double
    /// The waits of the orders placed in it.
    let waits: [Double]
    /// How many orders of each category it holds, in legend order, when the chart encodes a category.
    let categoryCounts: [CategoryCount]

    struct CategoryCount: Hashable {
        let name: String
        let count: Int
    }

    var id: Double {
        start
    }

    var end: Double {
        start + Self.hours
    }

    /// Context first: "6:00 AM to 8:00 AM".
    func label(locale: Locale) -> String {
        "\(TimeOfDayWording.time(hour: start, locale: locale)) to \(TimeOfDayWording.time(hour: end, locale: locale))"
    }

    /// Actual values with their units: "382 orders, waits from 1.2 minutes to 9.5 minutes, median 4.1 minutes".
    /// With a category: "...; Latte 95, Tea 90, Mocha 100 and Espresso 97".
    func value(locale: Locale) -> String {
        let sorted = waits.sorted()
        guard let shortest = sorted.first, let longest = sorted.last else { return "No orders." }
        let middle = sorted.count / 2
        let median = sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
        var words = "\(CafeWording.orders(waits.count, locale: locale)), waits from "
            + "\(TimeOfDayWording.minutes(shortest, locale: locale)) to \(TimeOfDayWording.minutes(longest, locale: locale)), "
            + "median \(TimeOfDayWording.minutes(median, locale: locale))"
        if !categoryCounts.isEmpty {
            words += "; " + CafeWording.list(categoryCounts.map { "\($0.name) \($0.count.formatted(.number.locale(locale)))" })
        }
        return words
    }

    /// The day in stretches of `hours`, each holding the items whose hour falls in it; the last includes 6 pm.
    static func make<Item>(
        _ items: [Item],
        hour: (Item) -> Double,
        wait: (Item) -> Double,
        category: ((Item) -> String)? = nil,
        categoryOrder: [String] = []
    ) -> [TimeOfDayPortion] {
        let day = TimeOfDayWording.dayHours
        return Array(stride(from: day.lowerBound, to: day.upperBound, by: hours)).map { start in
            let isLast = start + hours >= day.upperBound
            let inside = items.filter {
                let itemHour = hour($0)
                return itemHour >= start && (itemHour < start + hours || (isLast && itemHour <= start + hours))
            }
            let counts = category.map { category in
                categoryOrder.map { name in CategoryCount(name: name, count: inside.count { category($0) == name }) }
            } ?? []
            return TimeOfDayPortion(start: start, waits: inside.map(wait), categoryCounts: counts)
        }
    }
}

/// What VoiceOver reads in place of a chart of orders by time of day: one element per stretch of the day,
/// labelled with its clock times and valued with its counts and waits in minutes. Never drawn.
/// Each element spans the plot's height, so VoiceOver moves through them left to right.
struct TimeOfDaySpokenChart: View {
    let portions: [TimeOfDayPortion]
    let locale: Locale

    var body: some View {
        Chart {
            ForEach(portions) { portion in
                Plot {
                    RectangleMark(
                        xStart: .value(TimeOfDayWording.timeOfDay, portion.start),
                        xEnd: .value(TimeOfDayWording.timeOfDay, portion.end),
                        yStart: .value(TimeOfDayWording.wait, 0),
                        yEnd: .value(TimeOfDayWording.wait, 1)
                    )
                }
                .accessibilityLabel(portion.label(locale: locale))
                .accessibilityValue(portion.value(locale: locale))
            }
        }
        .chartXScale(domain: TimeOfDayWording.dayHours)
        .timeOfDayAxis(locale: locale)
    }
}

/// The time-of-day x axis the screens with hours on x share: a scale from 6 am to 6 pm, clock-time labels
/// every three hours (every six at the accessibility text sizes), each centred on its line so 6 PM is
/// labelled too, and the axis title.
struct TimeOfDayAxis: ViewModifier {
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room at each end of the x scale for half of a centred end label, growing with the label's text.
    @ScaledMetric(relativeTo: .caption2) private var endLabelRoom = TimeOfDayStyle.endLabelRoom

    func body(content: Content) -> some View {
        content
            .chartXScale(domain: TimeOfDayWording.dayHours, range: .plotDimension(padding: endLabelRoom))
            .chartXAxis {
                AxisMarks(
                    preset: .aligned,
                    values: TimeOfDayWording.labelledHours(accessibilitySize: dynamicTypeSize.isAccessibilitySize)
                ) { value in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel {
                        if let hour = value.as(Double.self) {
                            Text(TimeOfDayWording.hourLabel(hour: hour, locale: locale))
                        }
                    }
                }
            }
            .chartXAxisLabel(TimeOfDayWording.timeOfDay)
    }
}

extension View {
    func timeOfDayAxis(locale: Locale) -> some View {
        modifier(TimeOfDayAxis(locale: locale))
    }

    /// The wait axis's title, above the plot at its leading edge (the kit's `yAxisTitle`). At the default
    /// trailing edge it sits over the y axis's top label, and at the largest text sizes the two run into each other.
    func waitAxisTitle() -> some View {
        yAxisTitle(TimeOfDayWording.waitAxisTitle, short: TimeOfDayWording.waitAxisShortTitle)
    }
}

/// Spacing the time-of-day charts share.
enum TimeOfDayStyle {
    /// Room at each end of the x scale for the centred first and last labels, at the default text size.
    static let endLabelRoom: CGFloat = 14
}
