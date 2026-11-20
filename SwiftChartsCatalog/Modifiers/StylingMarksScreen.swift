import Accessibility
import Charts
import SwiftUI

/// "Styling marks": a fixed colour, one highlighted element, opacity, corner radius, line style,
/// shadow and blur, each on a toggle so they can be combined.
struct StylingMarksScreen: View {
    let screen: CatalogScreen
    @State private var model = StylingMarksViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups a day in the first week: Harbour as bars, Station as a line",
            message: model.headline(locale: locale),
            explanation: """
            Styling modifiers change how marks look, not what they show: foregroundStyle paints a fixed colour \
            and adds no legend, opacity fades, cornerRadius rounds the two corners at a bar's top and leaves the two \
            on the baseline square, lineStyle sets a line's \
            stroke, and shadow and blur, from iOS 16.4, lift or soften a mark. However the toggles are combined, \
            the data, the scale and the headline stay the same. To emphasise one element, colour it and fade the rest.
            """,
            snippets: model.snippets
        ) {
            StylingMarksChart(model: model, locale: locale)
        } controls: {
            StylingMarksControls(model: model)
        }
    }
}

/// The week's bars and line, or a placeholder when neither café sold anything.
struct StylingMarksChart: View {
    let model: StylingMarksViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room after the last day for the line's label, growing with the text.
    @ScaledMetric(relativeTo: .caption) private var labelRoom = StylingMarksStyle.labelRoom

    /// Every day labelled, or every third day from xxxLarge up, where the room kept for the line's
    /// label leaves too little width for every day's name (a render at xxxLarge cut "Wed" short).
    private var daysPerLabel: Int {
        dynamicTypeSize >= .xxxLarge ? 3 : 1
    }

    /// Every day, or every third day at the largest text sizes.
    private var labelledDays: [Date] {
        stride(from: 0, to: model.days.count, by: daysPerLabel).map { model.days[$0].day }
    }

    var body: some View {
        if model.hasNoSales {
            ContentUnavailableView(
                "No sales this week",
                systemImage: "cup.and.saucer",
                description: Text("Each day's cups appear here: Harbour as bars, Station as a line.")
            )
        } else {
            // snippet:styling-marks-chart
            Chart {
                ForEach(model.days) { day in
                    // One element per day, holding both cafés.
                    Plot {
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.harbour)
                        )
                        .stylingMarksBarColour(
                            usesFixedColour: model.usesFixedColour, isHighlighted: model.isHighlighted(day)
                        )
                        .stylingMarksOpacity(model.fadesBars && !model.isHighlighted(day))
                        .stylingMarksCornerRadius(model.roundsCorners)
                        .stylingMarksBlur(model.blursBars)

                        LineMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                            y: .value(CafeWording.cups, day.station),
                            series: .value(CafeWording.store, CafeWording.station)
                        )
                        // The line keeps its own colour in every state, so it never vanishes into the bars.
                        .foregroundStyle(StylingMarksStyle.lineColour)
                        .stylingMarksLineStyle(model.dashesLine)
                        .stylingMarksShadow(model.shadowsLine)
                        // Each day's bar is drawn after the line segment that reaches it, so without
                        // this the line passes behind the taller bars.
                        .zIndex(StylingMarksStyle.lineLayer)
                    }
                    .accessibilityLabel(model.spokenDay(day.day, locale: locale))
                    .accessibilityValue(model.accessibilityValue(for: day, locale: locale))
                }
                if let last = model.days.last {
                    // The line named at its last point. That point lies over the last day's bar, so the
                    // label hangs on an empty bar of the same day, width and height as the point: placed
                    // after it, the label starts where the bar ends.
                    BarMark(
                        x: .value(CafeWording.day, last.day, unit: .day, calendar: CafeData.calendar),
                        yStart: .value(CafeWording.cups, last.station),
                        yEnd: .value(CafeWording.cups, last.station)
                    )
                    .foregroundStyle(.clear)
                    .annotation(position: .trailing, spacing: StylingMarksStyle.labelSpacing) {
                        Text(CafeWording.station)
                            .font(.caption)
                            .foregroundStyle(StylingMarksStyle.lineColour)
                            // Grows no further than the room kept for it, so the plot keeps its width.
                            .dynamicTypeSize(...StylingMarksStyle.largestLabelSize)
                    }
                    // The days' elements already name Station and its cups.
                    .accessibilityHidden(true)
                }
            }
            // Room after the last day for the line's label. The domain is given exactly, from the first
            // day's start to the last day's end: with padding alone the scale widened it by days.
            .chartXScale(
                domain: model.dayDomain,
                range: .plotDimension(endPadding: min(labelRoom, StylingMarksStyle.largestLabelRoom))
            )
            // end
            .chartXAxis {
                // The data's own days, not a stride: the room left for the label would otherwise be
                // marked as days the chart does not have.
                AxisMarks(values: labelledDays) {
                    AxisGridLine()
                    AxisTick()
                    // Centred only when every day is labelled; the format is given the view's locale
                    // and the data's time zone.
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).weekday(.abbreviated),
                        centered: daysPerLabel == 1
                    )
                }
            }
            // One value axis for the chart and the descriptor.
            .chartYScale(domain: StylingMarksChartDescriptor.valueDomain(for: model.days))
            // The highlight changes what the busiest day's element says without changing its id.
            .id(model.highlightsBusiestDay)
            .accessibilityChartDescriptor(
                StylingMarksChartDescriptor(
                    days: model.days,
                    dayNames: model.days.map { model.spokenDay($0.day, locale: locale) },
                    summary: model.audioGraphSummary(locale: locale),
                    locale: locale
                )
            )
        }
    }
}

/// The colours and sizes that belong to this chart's marks.
private enum StylingMarksStyle {
    static let barColour = Color.teal
    /// A colour that adapts: dark in Light Mode, light in Dark Mode.
    static let lineColour = Color.primary
    static let highlightColour = Color.orange
    static let fadedOpacity = 0.35
    static let cornerRadius: CGFloat = 6
    static let lineWidth: CGFloat = 3
    static let dash: [CGFloat] = [8, 5]
    static let shadowRadius: CGFloat = 4
    static let shadowOffset: CGFloat = 3
    static let blurRadius: CGFloat = 1.5
    /// Above the bars' default of 0.
    static let lineLayer = 1.0
    /// Room after the last day for "Station" at the caption size, and its gap from the bar.
    static let labelRoom: CGFloat = 52
    /// The label stops growing at this size; the caption names both cafés at every size.
    static let largestLabelSize = DynamicTypeSize.xxxLarge
    /// The room "Station" needs at `largestLabelSize`.
    static let largestLabelRoom: CGFloat = 72
    static let labelSpacing: CGFloat = 4
}

/// Each styling modifier, applied only while its toggle is on, so that off means the modifier is not there.
extension ChartContent {
    // snippet:styling-marks-colour
    /// A fixed colour for the bars, and a second one for the bar to emphasise. A fixed style makes no
    /// legend. With neither, the bar keeps the chart's default blue.
    @ChartContentBuilder
    func stylingMarksBarColour(usesFixedColour: Bool, isHighlighted: Bool) -> some ChartContent {
        if isHighlighted {
            foregroundStyle(StylingMarksStyle.highlightColour)
        } else if usesFixedColour {
            foregroundStyle(StylingMarksStyle.barColour)
        } else {
            self
        }
    }

    // end

    // snippet:styling-marks-opacity
    /// Fades the mark; the caller leaves a highlighted bar at full strength.
    @ChartContentBuilder
    func stylingMarksOpacity(_ isOn: Bool) -> some ChartContent {
        if isOn {
            opacity(StylingMarksStyle.fadedOpacity)
        } else {
            self
        }
    }

    // end

    // snippet:styling-marks-corner-radius
    /// Rounds the two corners at the top of each bar to the radius given; the two on the baseline stay square.
    @ChartContentBuilder
    func stylingMarksCornerRadius(_ isOn: Bool) -> some ChartContent {
        if isOn {
            cornerRadius(StylingMarksStyle.cornerRadius)
        } else {
            self
        }
    }

    // end

    // snippet:styling-marks-line-style
    /// The StrokeStyle replaces the line's default width and caps, so it sets all of them.
    @ChartContentBuilder
    func stylingMarksLineStyle(_ isOn: Bool) -> some ChartContent {
        if isOn {
            lineStyle(StrokeStyle(
                lineWidth: StylingMarksStyle.lineWidth, lineCap: .round, lineJoin: .round, dash: StylingMarksStyle.dash
            ))
        } else {
            self
        }
    }

    // end

    // snippet:styling-marks-shadow
    /// A drop shadow in the framework's default colour. iOS 16.4: no check on an iOS 18 target.
    @ChartContentBuilder
    func stylingMarksShadow(_ isOn: Bool) -> some ChartContent {
        if isOn {
            shadow(radius: StylingMarksStyle.shadowRadius, y: StylingMarksStyle.shadowOffset)
        } else {
            self
        }
    }

    // end

    // snippet:styling-marks-blur
    /// A Gaussian blur. iOS 16.4: no check on an iOS 18 target.
    @ChartContentBuilder
    func stylingMarksBlur(_ isOn: Bool) -> some ChartContent {
        if isOn {
            blur(radius: StylingMarksStyle.blurRadius)
        } else {
            self
        }
    }
    // end
}

/// A toggle for each modifier, so they can be combined.
struct StylingMarksControls: View {
    @Bindable var model: StylingMarksViewModel

    var body: some View {
        ControlsSection {
            Toggle("Fixed colour on the bars", isOn: $model.usesFixedColour)
            Toggle("Highlight the busiest day", isOn: $model.highlightsBusiestDay)
            Toggle("Fade the bars (opacity)", isOn: $model.fadesBars)
            Toggle("Round the bars (corner radius)", isOn: $model.roundsCorners)
            Toggle("Dash the line (line style)", isOn: $model.dashesLine)
            Toggle("Shadow on the line", isOn: $model.shadowsLine)
            Toggle("Blur the bars", isOn: $model.blursBars)
        }
    }
}

/// The chart for the Audio Graph: one series per café over the written-out days, values with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct StylingMarksChartDescriptor: AXChartDescriptorRepresentable {
    let days: [StylingMarksDay]
    /// Each day written out, in the same order as `days`.
    let dayNames: [String]
    let summary: String
    let locale: Locale

    /// The cups axis as drawn, from zero to the busiest day at either café rounded up to the axis step (219 →
    /// 300): the chart's scale and the descriptor's range.
    static func valueDomain(for days: [StylingMarksDay]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: days.flatMap { [$0.harbour, $0.station] })
    }

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let points = Array(zip(dayNames, days))
        return AXChartDescriptor(
            title: "Cups a day at the Harbour and Station cafés",
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: CafeWording.day, categoryOrder: dayNames),
            // The bars grow from zero, so the drawn scale does too.
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle, range: Self.valueDomain(for: days), gridlinePositions: []
            ) {
                CafeWording.count($0, locale: locale)
            },
            additionalAxes: [],
            series: [
                AXDataSeriesDescriptor(
                    name: CafeWording.harbour, isContinuous: false,
                    dataPoints: points.map { AXDataPoint(x: $0.0, y: Double($0.1.harbour)) }
                ),
                AXDataSeriesDescriptor(
                    name: CafeWording.station, isContinuous: true,
                    dataPoints: points.map { AXDataPoint(x: $0.0, y: Double($0.1.station)) }
                ),
            ]
        )
    }
}

#Preview("Styling marks") {
    NavigationStack {
        StylingMarksScreen(screen: CatalogScreen(
            id: "mark-modifiers/styling-marks", title: "Styling marks", summary: "", apiSince: "16.0",
            skillReferences: ["mark-modifiers.md"]
        ))
    }
}

#Preview("No sales") {
    StylingMarksChart(model: StylingMarksViewModel(harbour: [], station: []), locale: .current)
}
