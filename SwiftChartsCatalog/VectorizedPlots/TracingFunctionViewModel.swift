import Accessibility
import Foundation
import Observation
import SwiftUI

/// A cup of coffee cooling towards the room's temperature (Newton's law of cooling): the function the
/// screen plots. A plain value, so a function plot's `@Sendable` closure can capture it.
nonisolated struct TracingFunctionCooling: Equatable {
    /// Degrees Celsius when poured.
    var pouredAt = 90.0
    /// Degrees Celsius of the room, which the coffee approaches and never reaches.
    var room = 20.0
    /// Minutes for the gap to the room's temperature to shrink by a factor of e.
    var timeConstant = 25.0

    /// The coffee's temperature, in degrees Celsius, the given number of minutes after pouring.
    func temperature(at minute: Double) -> Double {
        room + (pouredAt - room) * exp(-minute / timeConstant)
    }
}

/// The words this screen needs that `CafeWording` does not have: the function's axes and its units.
nonisolated enum TracingFunctionWording {
    /// The labels the function plot and the point on it give their values: VoiceOver names the axes with them.
    static let minutes = "Minutes"
    static let temperature = "Temperature"
    /// The axis titles, which carry the units.
    static let minutesAxisTitle = "Minutes after pouring"
    static let temperatureAxisTitle = "Temperature (°C)"
    /// The titles at the two largest text sizes, where the long ones run into the top value label and past the chart.
    static let minutesAxisTitleShort = "Minutes"
    static let temperatureAxisTitleShort = "°C"

    /// "1 minute", "60 minutes".
    static func minutes(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) minute](inflect: true)", locale: locale).characters)
    }

    /// Spoken: "1 degree Celsius", "26 degrees Celsius". Rounded to a whole degree.
    static func degrees(_ value: Double, locale: Locale) -> String {
        guard value.isFinite, let count = Int(exactly: value.rounded()) else { return "" }
        return String(AttributedString(localized: "^[\(count) degree](inflect: true) Celsius", locale: locale).characters)
    }

    /// Written: "26 °C", with a no-break space so the number and its unit stay on one line. Rounded to a whole degree.
    static func celsius(_ value: Double, locale: Locale) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0)).locale(locale)))\u{00A0}°C"
    }

    /// A whole number in the locale: "12".
    static func number(_ value: Double, locale: Locale) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(locale))
    }
}

/// One stretch of the curve, read by VoiceOver as one element.
nonisolated struct TracingFunctionPortion: Identifiable, Equatable {
    let start: Double
    let end: Double
    let startTemperature: Double
    let endTemperature: Double

    var id: Double {
        start
    }

    /// Context first: the stretch of time. "0 to 5 minutes".
    func label(locale: Locale) -> String {
        guard let end = Int(exactly: end.rounded()) else { return "" }
        return "\(TracingFunctionWording.number(start, locale: locale)) to \(TracingFunctionWording.minutes(end, locale: locale))"
    }

    /// Then the values, with their unit written out.
    func value(locale: Locale) -> String {
        "starts at \(TracingFunctionWording.degrees(startTemperature, locale: locale)), "
            + "ends at \(TracingFunctionWording.degrees(endTemperature, locale: locale))"
    }
}

/// The state of "Tracing and drawing a function": the selection along the curve, and the draw-in.
@Observable
final class TracingFunctionViewModel {
    /// The x scale, in minutes after pouring. It stays fixed while the curve is drawn in.
    nonisolated static let minuteDomain: ClosedRange<Double> = 0 ... 60
    /// The y scale, in degrees Celsius. Fixed, so the axis does not move as the curve grows.
    nonisolated static let temperatureDomain: ClosedRange<Double> = 0 ... 100
    /// How long the draw-in takes.
    static let drawSeconds = 3.0
    /// Minutes in each stretch VoiceOver reads as one element.
    nonisolated static let minutesPerPortion = 5.0

    static let chartSnippet = SnippetReference(name: "tracing-and-drawing-a-function-chart", title: "The curve, traced")
    static let snapSnippet = SnippetReference(name: "tracing-and-drawing-a-function-snap", title: "Snapping the selection")
    static let drawInSnippet = SnippetReference(name: "tracing-and-drawing-a-function-draw-in", title: "Redrawing every frame")
    static let reachSnippet = SnippetReference(name: "tracing-and-drawing-a-function-reach", title: "How far the domain reaches")
    static let snippets = [chartSnippet, snapSnippet, drawInSnippet, reachSnippet]

    let cooling: TracingFunctionCooling

    /// The x under the finger, exactly as `chartXSelection` reports it. `nil` when nothing is selected.
    var rawSelectedMinute: Double?

    /// When the current draw-in started; `nil` when the curve is drawn whole.
    private(set) var drawStart: Date?

    init(cooling: TracingFunctionCooling = TracingFunctionCooling()) {
        self.cooling = cooling
    }

    /// Whether the curve is being drawn in, so the timeline should tick.
    var isDrawing: Bool {
        drawStart != nil
    }

    /// Starts drawing the curve in from nothing.
    func startDrawing(at date: Date) {
        drawStart = date
    }

    /// Ends the draw-in that started at `start`; a later replay is left running.
    func finishDrawing(startedAt start: Date) {
        if drawStart == start { drawStart = nil }
    }

    /// Shows the curve whole at once, as under Reduce Motion.
    func showWholeCurve() {
        drawStart = nil
    }

    // snippet:tracing-and-drawing-a-function-reach
    /// The upper end of the plot's `domain:` at a moment of the draw-in: from 0 to 60 minutes
    /// over three seconds, and the whole x scale when nothing is being drawn.
    func drawnTo(at date: Date) -> Double {
        let domain = Self.minuteDomain
        guard let drawStart else { return domain.upperBound }
        let fraction = min(max(date.timeIntervalSince(drawStart) / Self.drawSeconds, 0), 1)
        return domain.lowerBound + fraction * (domain.upperBound - domain.lowerBound)
    }

    // end

    // snippet:tracing-and-drawing-a-function-snap
    /// The selection snapped to a whole minute inside the x scale, and only where the curve is drawn.
    func selectedMinute(drawnTo: Double) -> Double? {
        guard let rawSelectedMinute, rawSelectedMinute.isFinite else { return nil }
        let domain = Self.minuteDomain
        let minute = min(max(rawSelectedMinute.rounded(), domain.lowerBound), domain.upperBound)
        return minute <= drawnTo ? minute : nil
    }

    // end

    /// The point's coordinates, as the label beside it writes them: "(12 min, 63 °C)".
    /// `stacked` puts them on two lines without the brackets, for the accessibility text sizes: "12 min" over "63 °C".
    func coordinates(of minute: Double, locale: Locale, stacked: Bool = false) -> String {
        let minutes = "\(TracingFunctionWording.number(minute, locale: locale))\u{00A0}min"
        let degrees = TracingFunctionWording.celsius(cooling.temperature(at: minute), locale: locale)
        return stacked ? "\(minutes)\n\(degrees)" : "(\(minutes), \(degrees))"
    }

    /// Whether the label goes below and before the point: on the second half of the curve, where the
    /// space above and after the point is taken by the axis's end and below the curve is empty.
    nonisolated static func labelsBelow(_ minute: Double) -> Bool {
        minute > (minuteDomain.lowerBound + minuteDomain.upperBound) / 2
    }

    /// The headline: the selected point while there is one, how far the curve has reached while it is
    /// drawn in, and the whole curve's message once it is drawn. Every figure is one the chart shows.
    func message(drawnTo: Double, locale: Locale) -> String {
        if let minute = selectedMinute(drawnTo: drawnTo), let count = Int(exactly: minute) {
            if minute == Self.minuteDomain.lowerBound {
                return "When poured, the coffee is at "
                    + "\(TracingFunctionWording.celsius(cooling.temperature(at: minute), locale: locale))."
            }
            return "After \(TracingFunctionWording.minutes(count, locale: locale)), the coffee is at "
                + "\(TracingFunctionWording.celsius(cooling.temperature(at: minute), locale: locale))."
        }
        let end = Self.minuteDomain.upperBound
        if drawnTo >= end {
            return "Poured at \(TracingFunctionWording.celsius(cooling.temperature(at: Self.minuteDomain.lowerBound), locale: locale)), "
                + "the coffee is down to \(TracingFunctionWording.celsius(cooling.temperature(at: end), locale: locale)) "
                + "after \(TracingFunctionWording.minutes(Int(end), locale: locale))."
        }
        let wholeMinutes = drawnTo.rounded(.down)
        guard wholeMinutes > Self.minuteDomain.lowerBound, let count = Int(exactly: wholeMinutes) else {
            return "Drawing the curve from \(TracingFunctionWording.minutes(0, locale: locale))."
        }
        return "Drawn to \(TracingFunctionWording.minutes(count, locale: locale)) so far: down from "
            + "\(TracingFunctionWording.celsius(cooling.temperature(at: Self.minuteDomain.lowerBound), locale: locale)) to "
            + "\(TracingFunctionWording.celsius(cooling.temperature(at: wholeMinutes), locale: locale))."
    }

    /// The longest headline the screen can show, so the headline keeps one height and the chart does not move.
    func reservedMessage(locale: Locale) -> String {
        let probe = TracingFunctionViewModel(cooling: cooling)
        var candidates = [message(drawnTo: Self.minuteDomain.upperBound, locale: locale)]
        // The draw-in's message at its widest figures, and the selection's.
        candidates.append(probe.message(drawnTo: Self.minuteDomain.upperBound - 1, locale: locale))
        candidates.append(probe.message(drawnTo: Self.minuteDomain.upperBound / 2, locale: locale))
        probe.rawSelectedMinute = Self.minuteDomain.upperBound - 1
        candidates.append(probe.message(drawnTo: Self.minuteDomain.upperBound, locale: locale))
        return candidates.max { $0.count < $1.count } ?? ""
    }

    /// How far what VoiceOver reads reaches: the end of the last whole five minutes drawn. It moves in
    /// steps of five minutes, so the elements and the Audio Graph change only when a stretch is complete.
    nonisolated static func spokenReach(drawnTo: Double) -> Double {
        let domain = minuteDomain
        let drawn = min(max(drawnTo, domain.lowerBound), domain.upperBound)
        let wholePortions = ((drawn - domain.lowerBound) / minutesPerPortion).rounded(.down)
        return domain.lowerBound + wholePortions * minutesPerPortion
    }

    /// The stretches of the drawn curve VoiceOver reads, five minutes each. Only whole stretches: one the
    /// curve has not finished is left out, so an element never changes its text while the curve grows.
    func portions(drawnTo: Double) -> [TracingFunctionPortion] {
        let domain = Self.minuteDomain
        let reach = Self.spokenReach(drawnTo: drawnTo)
        return stride(from: domain.lowerBound, to: reach, by: Self.minutesPerPortion).map { start in
            let end = start + Self.minutesPerPortion
            return TracingFunctionPortion(
                start: start, end: end,
                startTemperature: cooling.temperature(at: start), endTemperature: cooling.temperature(at: end)
            )
        }
    }

    /// Spoken when the replay starts: what changes, then the headline the chart ends on.
    func replayAnnouncement(locale: Locale) -> String {
        "Drawing the curve again over \(TracingFunctionWording.minutes(Int(Self.minuteDomain.upperBound), locale: locale)). "
            + message(drawnTo: Self.minuteDomain.upperBound, locale: locale)
    }
}

/// The Audio Graph's account of the whole curve: both axes numbers, one continuous series.
/// Built from the whole function, 0 to 60 minutes, whatever the draw-in has reached: the Audio Graph keeps the
/// descriptor it first reads for the chart, so one made partway through would describe part of the curve for good
/// (read on iOS: it described 35 of the 60 minutes). Not tied to the main actor: the accessibility system calls its
/// value descriptions when it chooses.
nonisolated struct TracingFunctionChartDescriptor: AXChartDescriptorRepresentable {
    let cooling: TracingFunctionCooling
    let locale: Locale

    /// One point a minute, over the whole curve.
    var minutes: [Double] {
        let domain = TracingFunctionViewModel.minuteDomain
        return Array(stride(from: domain.lowerBound, through: domain.upperBound, by: 1))
    }

    var summary: String {
        let domain = TracingFunctionViewModel.minuteDomain
        guard let lastCount = Int(exactly: domain.upperBound) else { return "" }
        return "Poured at \(TracingFunctionWording.degrees(cooling.temperature(at: domain.lowerBound), locale: locale)). "
            + "After \(TracingFunctionWording.minutes(lastCount, locale: locale)), "
            + "\(TracingFunctionWording.degrees(cooling.temperature(at: domain.upperBound), locale: locale))."
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXNumericDataAxisDescriptor(
            title: TracingFunctionWording.minutesAxisTitle,
            range: TracingFunctionViewModel.minuteDomain,
            gridlinePositions: []
        ) { value in
            guard value.isFinite, let count = Int(exactly: value.rounded()) else { return "" }
            return TracingFunctionWording.minutes(count, locale: locale)
        }
        let yAxis = AXNumericDataAxisDescriptor(
            title: TracingFunctionWording.temperature,
            range: TracingFunctionViewModel.temperatureDomain,
            gridlinePositions: []
        ) { value in TracingFunctionWording.degrees(value, locale: locale) }
        let series = AXDataSeriesDescriptor(
            name: TracingFunctionWording.temperature,
            isContinuous: true,
            dataPoints: minutes.map { AXDataPoint(x: $0, y: cooling.temperature(at: $0)) }
        )
        return AXChartDescriptor(
            title: "Temperature of a cup of coffee after pouring",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
