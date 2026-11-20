import Foundation

/// The words used for the sample data, so two screens that draw the same data say the same thing:
/// axis titles, series names and the names of values. Use these in `.value(...)` labels, axis
/// titles, accessibility text and chart descriptors instead of writing the words again.
nonisolated enum CafeWording {
    // Cups
    static let cups = "Cups"
    static let cupsAxisTitle = "Cups"
    static let day = "Day"
    static let month = "Month"
    static let drink = "Drink"
    static let size = "Size"
    static let store = "Café"
    static let harbour = "Harbour"
    static let station = "Station"

    // Orders: queue and wait
    static let queueAxisTitle = "People queuing"
    static let waitAxisTitle = "Wait (seconds)"
    /// The wait axis's drawn title at `.accessibility4` and up (`yAxisTitle(_:short:)`), where the full one meets
    /// the top label. The descriptor keeps the full title.
    static let waitAxisShortTitle = "Wait (s)"

    // Orders by weekday and slot
    static let weekday = "Weekday"
    static let slot = "Time of day"
    static let orders = "Orders"

    // Shifts
    static let barista = "Barista"
    static let shiftStart = "Start"
    static let shiftEnd = "End"

    // Visits by age group
    static let ageGroup = "Age group"
    static let visits = "Visits"

    // Bean price
    static let week = "Week"
    static let priceAxisTitle = "Price ($ per kg)"
    /// The price axis's drawn title at `.accessibility4` and up.
    static let priceAxisShortTitle = "$ per kg"
    /// The price's unit written out, for what is spoken: the axis title's "per kg" is not read as words.
    static let perKilogram = "per kilogram"

    /// Change against last month
    static let changeAxisTitle = "Change in cups"

    // The chain
    static let yearlyCupsAxisTitle = "Cups a year"
    static let yearlyChangeAxisTitle = "Change on last year (cups)"

    // Bean tastings
    static let acidity = "Acidity"
    static let body = "Body"
    static let sweetness = "Sweetness"
    static let origin = "Origin"

    // Airflow
    static let acrossAxisTitle = "Across the room (m)"
    static let intoAxisTitle = "Into the room (m)"
    /// The into-the-room axis's drawn title at `.accessibility4` and up.
    static let intoAxisShortTitle = "In (m)"
    static let speedTitle = "Air speed (m/s)"

    // MARK: Captions for the daily data sets

    // Two daily series both start on Sunday 1 March at the Harbour café, with different figures on purpose:
    // `harbourSales` is the café's recorded four weeks, which most screens draw, and `thirtyDays` is the invented
    // month the design screens start from (174 cups on March 1, against 190 recorded). Their captions say which is
    // which, so a reader moving between screens is not shown two Marches under one name.

    /// The caption for `CafeData.harbourSales` (and the days it shares with `tenWeeks`):
    /// "Cups sold each day at the Harbour café, March 1 – 28, 2026".
    static func harbourDaysCaption(locale: Locale) -> String {
        harbourDaysCaption(from: CafeData.harbourSales.first?.day, to: CafeData.harbourSales.last?.day, locale: locale)
    }

    /// The caption for a run of the Harbour café's days, such as the first week or fortnight of `harbourSales`:
    /// "Cups sold each day at the Harbour café, March 1 – 14, 2026". Without both days (no data), the caption
    /// without dates.
    static func harbourDaysCaption(from first: Date?, to last: Date?, locale: Locale) -> String {
        let title = "Cups sold each day at the \(harbour) café"
        guard let first, let last else { return title }
        return "\(title), \(dayRange(first, last, locale: locale))"
    }

    /// The caption for `CafeData.monthlySummaries`, each month's lowest, average and highest day:
    /// "Cups a day at the Harbour café, by month".
    static let monthlyRangesCaption = "Cups a day at the \(harbour) café, by month"

    /// The caption for `CafeData.thirtyDays`, the invented month: "Invented sample: cups a day at the Harbour café,
    /// March 2026". `thirtyDaysReal` is the same month as traded, and its screens say so beside the chart.
    static func inventedDaysCaption(locale: Locale) -> String {
        "Invented sample: cups a day at the \(harbour) café, \(CafeData.firstDay.formatted(monthYear(locale: locale)))"
    }

    /// "March 1 – 28, 2026", in the data's calendar so the device's time zone cannot shift it.
    static func dayRange(_ first: Date, _ last: Date, locale: Locale) -> String {
        (first ..< max(first, last)).formatted(Date.IntervalFormatStyle(
            date: .long, time: .omitted, locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone
        ))
    }

    /// "March 2026", in the data's calendar.
    static func monthYear(locale: Locale) -> Date.FormatStyle {
        Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone).month(.wide).year()
    }

    // MARK: Counts that agree in number

    // One function per noun, so every screen writes "1 cup" and "36 cups" the same way: the inflected
    // string resolves the agreement, and the locale it is passed writes the number. Never a hand-written
    // `count == 1 ? ... : ...`.

    /// "1 cup", "1,200 cups".
    static func cups(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) cup](inflect: true)", locale: locale).characters)
    }

    /// "1 order", "40 orders".
    static func orders(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) order](inflect: true)", locale: locale).characters)
    }

    /// "1 drink", "6 drinks".
    static func drinks(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) drink](inflect: true)", locale: locale).characters)
    }

    /// "1 month", "6 months".
    static func months(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) month](inflect: true)", locale: locale).characters)
    }

    /// "1 second", "180 seconds".
    static func seconds(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) second](inflect: true)", locale: locale).characters)
    }

    /// An average or other measured time, with at most one decimal place: "1 second", "136.7 seconds".
    static func seconds(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 1))) second](inflect: true)",
            locale: locale
        ).characters)
    }

    /// "1 person", "9 people".
    static func people(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) person](inflect: true)", locale: locale).characters)
    }

    /// An average queue, with at most one decimal place: "1 person", "5.5 people".
    static func people(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 1))) person](inflect: true)",
            locale: locale
        ).characters)
    }

    /// "1 day", "28 days".
    static func days(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) day](inflect: true)", locale: locale).characters)
    }

    /// "1 week", "10 weeks".
    static func weeks(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) week](inflect: true)", locale: locale).characters)
    }

    /// "1 café", "2 cafés".
    static func cafes(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) café](inflect: true)", locale: locale).characters)
    }

    /// "1 visit", "1,480 visits".
    static func visits(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) visit](inflect: true)", locale: locale).characters)
    }

    /// "1 shift", "5 shifts".
    static func shifts(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) shift](inflect: true)", locale: locale).characters)
    }

    /// "1 bar", "12 bars".
    static func bars(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) bar](inflect: true)", locale: locale).characters)
    }

    /// "1 bin", "8 bins".
    static func bins(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) bin](inflect: true)", locale: locale).characters)
    }

    /// "1 size", "3 sizes".
    static func sizes(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) size](inflect: true)", locale: locale).characters)
    }

    /// A length on screen set by a slider, with at most one decimal place: "1 point", "0.5 points".
    static func points(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 1))) point](inflect: true)",
            locale: locale
        ).characters)
    }

    // MARK: Numbers the accessibility system chooses

    /// A count for a chart descriptor's value description: "12 cups", or "" for a value that is not finite.
    /// The accessibility system calls a value description with numbers the app does not choose, and
    /// `Int(_:)` traps on one that is not finite or will not fit, so the conversion happens here, once.
    /// A finite value is cut toward zero, as `Int(_:)` cuts it, so the words are the ones `Int(value)` gave.
    /// `words` writes the count; it defaults to cups, and is given the locale it should write in.
    static func count(
        _ value: Double,
        locale: Locale,
        as words: (Int, Locale) -> String = cups(_:locale:)
    ) -> String {
        guard value.isFinite, let count = Int(exactly: value.rounded(.towardZero)) else { return "" }
        return words(count, locale)
    }

    // MARK: Lists of names

    /// The app's sentences are English, so a list inside one is joined the English way whatever the
    /// view's locale: "Harbour and Station", never "Harbour und Station". Numbers and dates still take
    /// the view's locale; only the conjunction is fixed.
    static let listLocale = Locale(identifier: "en")

    /// "Harbour", "Harbour and Station", "Tea, Latte, and Mocha".
    static func list(_ names: [String]) -> String {
        names.formatted(.list(type: .and).locale(listLocale))
    }
}
