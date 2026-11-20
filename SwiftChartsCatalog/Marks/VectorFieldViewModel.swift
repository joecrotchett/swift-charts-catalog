import Foundation
import Observation

/// The fields the picker offers: the café's measured airflow, and two computed over the same spots.
nonisolated enum VectorFieldKind: String, CaseIterable, Identifiable {
    case measured
    case circling
    case draught

    var id: Self {
        self
    }

    /// The picker's segment.
    var title: String {
        switch self {
        case .measured: "Measured"
        case .circling: "Circling"
        case .draught: "From the door"
        }
    }

    /// What the chart is showing, for the announcement and the Audio Graph's title.
    var name: String {
        switch self {
        case .measured: "the measured airflow"
        case .circling: "air circling the middle of the room"
        case .draught: "a draught spreading from the door"
        }
    }
}

/// The two fields this screen adds to the sample data. Each keeps the measured readings' spots and
/// replaces their direction and speed.
nonisolated enum VectorFieldData {
    /// How much faster the circling air moves for each metre from the middle, in metres a second.
    static let circlingSpeedPerMetre = 0.15
    /// The draught's speed one metre from the door, in metres a second.
    static let draughtSpeedAtOneMetre = 1.2

    static func readings(for kind: VectorFieldKind, measured: [Airflow]) -> [Airflow] {
        switch kind {
        case .measured: measured
        case .circling: circling(over: measured)
        case .draught: draught(over: measured)
        }
    }

    // snippet:vector-field-circling
    /// Air turning clockwise round the middle of the grid, faster the further out it is.
    static func circling(over grid: [Airflow]) -> [Airflow] {
        guard !grid.isEmpty else { return [] }
        let middleX = grid.map(\.x).reduce(0, +) / Double(grid.count)
        let middleY = grid.map(\.y).reduce(0, +) / Double(grid.count)
        return grid.map { spot in
            let across = spot.x - middleX
            let into = spot.y - middleY
            // A quarter turn clockwise from the line that runs out from the middle to the spot.
            return Airflow(
                id: spot.id, x: spot.x, y: spot.y,
                direction: degreesClockwiseFromUp(across: into, into: -across),
                speed: hundredths(hypot(across, into) * circlingSpeedPerMetre)
            )
        }
    }

    /// The angle the chart turns an arrow by: 0 is up the y axis, 90 along the x axis.
    static func degreesClockwiseFromUp(across: Double, into: Double) -> Double {
        guard across != 0 || into != 0 else { return 0 }
        let degrees = (atan2(across, into) * 180 / .pi).rounded()
        return degrees < 0 ? degrees + 360 : degrees
    }

    // end

    // snippet:vector-field-draught
    /// Air spreading out from the door, which is where both axes start, and slowing as it goes.
    static func draught(over grid: [Airflow]) -> [Airflow] {
        grid.map { spot in
            let distance = hypot(spot.x, spot.y)
            return Airflow(
                id: spot.id, x: spot.x, y: spot.y,
                direction: degreesClockwiseFromUp(across: spot.x, into: spot.y),
                speed: distance > 0 ? hundredths(draughtSpeedAtOneMetre / distance) : 0
            )
        }
    }

    // end

    static func hundredths(_ value: Double) -> Double {
        (value * 100).rounded() / 100
    }
}

/// The floor the readings cover, worked out from where they were taken: each reading stands for the
/// square of floor around it, so the room runs half a step past the outermost readings.
nonisolated struct VectorFieldRoom: Equatable {
    let across: ClosedRange<Double>
    let into: ClosedRange<Double>
    /// The distance between neighbouring readings, in metres.
    let step: Double

    init(readings: [Airflow]) {
        let columns = Set(readings.map(\.x)).sorted()
        let rows = Set(readings.map(\.y)).sorted()
        let gaps = zip(columns, columns.dropFirst()).map { $1 - $0 } + zip(rows, rows.dropFirst()).map { $1 - $0 }
        let step = gaps.min() ?? 1
        self.step = step
        across = (columns.first ?? 0) - step / 2 ... (columns.last ?? 0) + step / 2
        into = (rows.first ?? 0) - step / 2 ... (rows.last ?? 0) + step / 2
    }

    /// Width over depth, so a metre is the same length on both axes.
    var aspectRatio: Double {
        (across.upperBound - across.lowerBound) / (into.upperBound - into.lowerBound)
    }
}

/// What the chart says in words: its headline, each element's text, and the Audio Graph's summary.
nonisolated struct VectorFieldSummary {
    let readings: [Airflow]

    /// Speeds are written to two decimal places, so two that differ by less are a tie.
    private static let tieTolerance = 0.005

    var fastestSpeed: Double? {
        readings.map(\.speed).max()
    }

    var slowestSpeed: Double? {
        readings.map(\.speed).min()
    }

    /// Every reading with the highest speed, in data order. Empty when the air is still everywhere.
    var fastest: [Airflow] {
        guard let top = fastestSpeed, top > 0 else { return [] }
        return readings.filter { abs($0.speed - top) < Self.tieTolerance }
    }

    /// Every reading with the lowest speed, in data order.
    var slowest: [Airflow] {
        guard let bottom = slowestSpeed else { return [] }
        return readings.filter { abs($0.speed - bottom) < Self.tieTolerance }
    }

    /// The chart's message in a sentence. Its figure is the speed of the longest arrow drawn.
    func headline(locale: Locale) -> String {
        guard !readings.isEmpty else { return "No airflow readings yet." }
        guard let top = fastestSpeed, let first = fastest.first else {
            return "The air is still at every spot measured."
        }
        let speed = Self.speed(top, locale: locale)
        if fastest.count == 1 {
            return "The fastest air, \(speed), is \(Self.metres(first.x, locale: locale)) across and "
                + "\(Self.metres(first.y, locale: locale)) into the room."
        }
        let spots = Self.spots(fastest.count, locale: locale)
        // Spots that share a line are named by the line, so the headline stays a sentence at the largest text
        // sizes; each spot is still named by its element and in the Audio Graph's summary.
        if fastest.allSatisfy({ $0.x == first.x }) {
            return "The fastest air, \(speed), is at \(spots), both \(Self.metres(first.x, locale: locale)) across."
        }
        if fastest.allSatisfy({ $0.y == first.y }) {
            return "The fastest air, \(speed), is at \(spots), both \(Self.metres(first.y, locale: locale)) into the room."
        }
        return "The fastest air, \(speed), is at \(spots): \(Self.spotList(fastest, locale: locale))."
    }

    /// Actual values only, and what a direction's number means.
    func audioGraphSummary(locale: Locale) -> String {
        guard !readings.isEmpty else { return "No airflow readings yet." }
        guard let top = fastestSpeed, let bottom = slowestSpeed, !fastest.isEmpty else {
            return "\(Self.readingsText(readings.count, locale: locale)). The air is still at every spot measured."
        }
        return "\(Self.readingsText(readings.count, locale: locale)). "
            + "Fastest: \(Self.speed(top, locale: locale)), \(place(of: fastest, locale: locale)). "
            + "Slowest: \(Self.speed(bottom, locale: locale)), \(place(of: slowest, locale: locale)). "
            + Self.directionConvention + " " + Self.rowsConvention
    }

    private func place(of spots: [Airflow], locale: Locale) -> String {
        guard spots.count == 1, let spot = spots.first else {
            return "at \(Self.spots(spots.count, locale: locale)): \(Self.spotList(spots, locale: locale))"
        }
        return "at \(Self.position(of: spot, locale: locale))"
    }

    // MARK: Words this screen adds to CafeWording

    static let directionAxisTitle = "Direction (degrees)"
    /// The reference a direction is measured from, as every direction in words says it.
    static let directionReference = "clockwise from straight into the room"
    static let directionConvention = "Directions are in degrees \(directionReference)."
    /// How the Audio Graph's axes differ from the drawn ones: the grid is played a row at a time, by speed.
    static let rowsConvention = "Each row into the room is played as a series across the room, its pitch the air speed."
    static let stillAir = "Still air"

    /// Where a reading was taken, x first: "5 metres across, 3 metres in".
    static func position(of reading: Airflow, locale: Locale) -> String {
        "\(metres(reading.x, locale: locale)) across, \(metres(reading.y, locale: locale)) in"
    }

    /// Which way the air goes and how fast:
    /// "Heading 62 degrees clockwise from straight into the room, 0.9 metres a second".
    static func movement(of reading: Airflow, locale: Locale) -> String {
        guard reading.speed > 0 else { return stillAir }
        return "Heading \(degrees(reading.direction, locale: locale)) \(directionReference), "
            + "\(speed(reading.speed, locale: locale))"
    }

    /// Where a reading was taken, without a comma, so several can be listed: "5 metres across by 3 metres in".
    static func spotName(of reading: Airflow, locale: Locale) -> String {
        "\(metres(reading.x, locale: locale)) across by \(metres(reading.y, locale: locale)) in"
    }

    /// Every spot named, joined the English way: "1 metre across by 1 metre in and 3 metres across by 1 metre in".
    static func spotList(_ readings: [Airflow], locale: Locale) -> String {
        CafeWording.list(readings.map { spotName(of: $0, locale: locale) })
    }

    /// "1 metre", "5 metres".
    static func metres(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 1))) metre](inflect: true)",
            locale: locale
        ).characters)
    }

    /// "1 metre a second", "0.75 metres a second".
    static func speed(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0 ... 2))) metre](inflect: true) a second",
            locale: locale
        ).characters)
    }

    /// "1 degree", "149 degrees".
    static func degrees(_ amount: Double, locale: Locale) -> String {
        String(AttributedString(
            localized: "^[\(amount, format: .number.precision(.fractionLength(0))) degree](inflect: true)",
            locale: locale
        ).characters)
    }

    /// "1 spot", "4 spots".
    static func spots(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) spot](inflect: true)", locale: locale).characters)
    }

    /// "1 reading", "20 readings".
    static func readingsText(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) reading](inflect: true)", locale: locale).characters)
    }
}

/// The state behind the vector field screen: which field is drawn, and everything derived from it.
@Observable
final class VectorFieldViewModel {
    var kind: VectorFieldKind = .measured
    let measured: [Airflow]

    init(measured: [Airflow] = CafeData.airflow) {
        self.measured = measured
    }

    /// The readings of the field now drawn.
    var readings: [Airflow] {
        VectorFieldData.readings(for: kind, measured: measured)
    }

    var summary: VectorFieldSummary {
        VectorFieldSummary(readings: readings)
    }

    /// The fastest air in any of the fields, so an arrow of one length is one speed whichever is drawn.
    var speedCeiling: Double {
        VectorFieldKind.allCases
            .flatMap { VectorFieldData.readings(for: $0, measured: measured) }
            .map(\.speed).max() ?? 0
    }

    func headline(locale: Locale) -> String {
        summary.headline(locale: locale)
    }

    /// Spoken when the picker redraws the chart: what changed, then the headline.
    func announcement(locale: Locale) -> String {
        "Showing \(kind.name). \(headline(locale: locale))"
    }

    /// The chart's code is the same for every field; a computed field adds the code that made it.
    var snippets: [SnippetReference] {
        let chart = [
            SnippetReference(name: "vector-field-chart", title: "A point per reading, an arrow as its symbol"),
            SnippetReference(name: "vector-field-arrow", title: "The arrow: turned by direction, sized by speed"),
        ]
        switch kind {
        case .measured:
            return chart
        case .circling:
            return chart + [SnippetReference(name: "vector-field-circling", title: "The field: air circling the middle")]
        case .draught:
            return chart + [SnippetReference(name: "vector-field-draught", title: "The field: a draught from the door")]
        }
    }
}
