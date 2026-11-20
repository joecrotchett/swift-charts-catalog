import Accessibility
import Charts
import SwiftUI

/// "Colour: never colour alone": two cafés told apart by colour only, then by colour and a second cue
/// (a shape on points, a label on stacked bars), with a greyscale switch to prove the difference.
struct ColourAloneScreen: View {
    let screen: CatalogScreen
    @State private var model = ColourAloneViewModel()
    /// Read here and passed in, so the headline, elements and Audio Graph write numbers as the axes do.
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.caption(locale: locale),
            message: model.headline(locale: locale),
            explanation: model.explanation(isAccessibilitySize: dynamicTypeSize.isAccessibilitySize),
            snippets: model.snippets
        ) {
            ColourAloneChart(model: model, locale: locale)
        } controls: {
            ColourAloneControls(model: model)
        }
        .onChange(of: model.form) {
            Self.announce(model.announcement(after: .form, locale: locale))
        }
        .onChange(of: model.showsSecondCue) {
            Self.announce(model.announcement(after: .secondCue, locale: locale))
        }
    }

    /// Says aloud that the chart changed, for people who cannot see it happen.
    static func announce(_ message: String) {
        AccessibilityNotification.Announcement(message).post()
    }
}

/// Sizes that belong to this screen's marks.
private enum ColourAloneStyle {
    /// Large enough that a circle and a cross are told apart at a glance.
    static let pointSize: CGFloat = 60
    /// The strip of empty space between neighbouring segments.
    static let segmentGap: CGFloat = 1
    /// How far a segment's label may shrink before it is cut off.
    static let labelMinimumScale: CGFloat = 0.6
    /// The largest size a segment's label grows to: beyond it the name no longer fits on a bar.
    static let labelLargestSize = DynamicTypeSize.xLarge
    /// Days between date labels: every week, or every fortnight at the accessibility sizes.
    static let daysPerLabel = 7
    static let daysPerLabelAccessibility = 14
    /// The text on a segment: dark, since white measured below 4.5:1 on the purple and on the red.
    static let labelColour = Color.black
}

/// The chart for the current form, or a placeholder when it has nothing to draw.
struct ColourAloneChart: View {
    let model: ColourAloneViewModel
    let locale: Locale

    var body: some View {
        switch model.form {
        case .points:
            if model.drawsPoints {
                ColourAlonePointsChart(model: model, locale: locale)
                    // snippet:colour-never-colour-alone-greyscale
                    // Drains the colour from everything the chart draws, legend included.
                    .grayscale(model.showsGreyscale ? 1 : 0)
                    // end
                    .accessibilityChartDescriptor(model.pointDescriptor(locale: locale))
            } else {
                ContentUnavailableView(
                    "No sales yet", systemImage: "circle.grid.cross",
                    description: Text("Each café's cups a day appear here as points.")
                )
            }
        case .stackedBars:
            if model.drawsBars {
                ColourAloneBarsChart(model: model, locale: locale)
                    .grayscale(model.showsGreyscale ? 1 : 0)
                    .accessibilityChartDescriptor(model.barDescriptor(locale: locale))
            } else {
                ContentUnavailableView(
                    "No cups sold", systemImage: "chart.bar",
                    description: Text("Each café's cups a week appear here as stacked bars.")
                )
            }
        }
    }
}

/// Two cafés' days as points: colour alone, or colour and shape.
struct ColourAlonePointsChart: View {
    let model: ColourAloneViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Chart {
            ForEach(model.pointWeeks) { week in
                // One element per week holding both cafés, so a listener is not walked through 56 points, and
                // the two cafés of a week, which share one band, are always read in the same order.
                Plot {
                    // A clear band the full height of the plot gives every week's element the same top,
                    // so VoiceOver reads the weeks in order and not by the height of their points.
                    RectangleMark(
                        xStart: .value(CafeWording.day, week.firstDay, unit: .day, calendar: CafeData.calendar),
                        xEnd: .value(CafeWording.day, week.lastDay, unit: .day, calendar: CafeData.calendar)
                    )
                    .foregroundStyle(.clear)
                    ForEach(week.portions) { portion in
                        ColourAlonePortionPoints(portion: portion, showsSecondCue: model.showsSecondCue)
                    }
                }
                .accessibilityLabel(model.weekLabel(week, locale: locale))
                .accessibilityValue(model.weekValue(week, locale: locale))
            }
        }
        // snippet:colour-never-colour-alone-equal-weight
        // Two hues of about the same lightness: neither café looks more important, and greyscale
        // shows honestly that colour was the only difference.
        .chartForegroundStyleScale([
            CafeWording.harbour: Color.purple, CafeWording.station: Color.red,
        ])
        // end
        // The shapes the explanation names, set rather than left to the automatic order.
        .chartSymbolScale([CafeWording.harbour: BasicChartSymbolShape.circle, CafeWording.station: .cross])
        .chartYScale(domain: model.pointAxis)
        .chartXAxis {
            // Fewer labels, and the day alone, at the accessibility sizes, so they do not collide or truncate.
            AxisMarks(values: .stride(
                by: .day,
                count: dynamicTypeSize.isAccessibilitySize ? ColourAloneStyle.daysPerLabelAccessibility : ColourAloneStyle.daysPerLabel,
                calendar: CafeData.calendar
            )) { _ in
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: dayLabelFormat)
            }
        }
    }

    /// "Mar 1", or "1" at the accessibility sizes, in the data's time zone.
    private var dayLabelFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, calendar: CafeData.calendar, timeZone: CafeData.calendar.timeZone)
        return dynamicTypeSize.isAccessibilitySize ? style.day() : style.month(.abbreviated).day()
    }
}

/// One café's points in one week: colour alone, or colour and shape.
struct ColourAlonePortionPoints: ChartContent {
    let portion: ColourAlonePortion
    let showsSecondCue: Bool

    var body: some ChartContent {
        ForEach(portion.days) { day in
            if showsSecondCue {
                // snippet:colour-never-colour-alone-points-colour-and-shape
                PointMark(
                    x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value(CafeWording.cupsAxisTitle, day.cups)
                )
                // Colour and shape encode the same café, so the series differ without colour.
                .foregroundStyle(by: .value(CafeWording.store, portion.store))
                .symbol(by: .value(CafeWording.store, portion.store))
                .symbolSize(ColourAloneStyle.pointSize)
                // end
            } else {
                // snippet:colour-never-colour-alone-points-colour-only
                PointMark(
                    x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value(CafeWording.cupsAxisTitle, day.cups)
                )
                // The mistake: colour is the only difference between the cafés.
                .foregroundStyle(by: .value(CafeWording.store, portion.store))
                .symbolSize(ColourAloneStyle.pointSize)
                // end
            }
        }
    }
}

/// Two cafés' weeks as stacked bars: colour alone, or colour and a direct label on each segment.
struct ColourAloneBarsChart: View {
    let model: ColourAloneViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Chart(model.weeks) { week in
            Plot {
                if model.showsSecondCue {
                    // snippet:colour-never-colour-alone-bars-labelled
                    BarMark(
                        x: .value(CafeWording.week, week.week),
                        y: .value(CafeWording.cupsAxisTitle, week.cups)
                    )
                    .foregroundStyle(by: .value(CafeWording.store, week.store))
                    // A bar has no symbol shape: the second cue is the café's name, written on its segment.
                    .annotation(position: .overlay) {
                        ColourAloneSegmentLabel(store: week.store, cups: week.cups)
                    }
                    .clipShape(Rectangle().inset(by: ColourAloneStyle.segmentGap))
                    // end
                } else {
                    // snippet:colour-never-colour-alone-bars-colour-only
                    BarMark(
                        x: .value(CafeWording.week, week.week),
                        y: .value(CafeWording.cupsAxisTitle, week.cups)
                    )
                    // The mistake: every segment is the same rectangle, and only colour names the café.
                    .foregroundStyle(by: .value(CafeWording.store, week.store))
                    .annotation(position: .overlay) {
                        ColourAloneSegmentLabel(store: nil, cups: week.cups)
                    }
                    .clipShape(Rectangle().inset(by: ColourAloneStyle.segmentGap))
                    // end
                }
            }
            .accessibilityLabel(model.segmentLabel(week))
            .accessibilityValue(model.segmentValue(week, locale: locale))
        }
        .chartForegroundStyleScale([
            CafeWording.harbour: Color.purple, CafeWording.station: Color.red,
        ])
        // Direct labels make the legend redundant; without them it is the only key.
        .chartLegend(model.showsSecondCue ? .hidden : .automatic)
        .chartYScale(domain: model.barAxis)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisTick()
                // "Week 1" truncates at the accessibility sizes; there the week's number stands alone.
                AxisValueLabel {
                    if let week = value.as(String.self) {
                        Text(dynamicTypeSize.isAccessibilitySize ? ColourAloneViewModel.weekNumber(week) : week)
                    }
                }
            }
        }
    }
}

/// The text written on a segment: its cups, and with the second cue its café's name above them.
struct ColourAloneSegmentLabel: View {
    let store: String?
    let cups: Int
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 0) {
            if let store {
                // A whole name no longer fits on a bar at the accessibility sizes: there it is the initial,
                // and the explanation says which is which.
                Text(dynamicTypeSize.isAccessibilitySize ? ColourAloneViewModel.initial(of: store) : store)
                    .fontWeight(.semibold)
            }
            Text(cups, format: .number)
        }
        .font(.caption)
        .foregroundStyle(ColourAloneStyle.labelColour)
        .lineLimit(1)
        .minimumScaleFactor(ColourAloneStyle.labelMinimumScale)
        // Beyond this size the text would no longer fit on a bar; it stops growing, and the explanation says so.
        .dynamicTypeSize(...ColourAloneStyle.labelLargestSize)
    }
}

/// The form, the second cue and the greyscale check.
struct ColourAloneControls: View {
    @Bindable var model: ColourAloneViewModel

    private var drawsChart: Bool {
        model.form == .points ? model.drawsPoints : model.drawsBars
    }

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Chart", selection: $model.form) {
                ForEach(ColourAloneForm.allCases) { form in
                    Text(form.title).tag(form)
                }
            }
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Toggle(model.secondCueTitle, isOn: $model.showsSecondCue)
                if model.isShowingMistake, drawsChart {
                    Label("Colour alone: this is the mistake, shown on purpose.", systemImage: "exclamationmark.triangle.fill")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }
            // While a placeholder replaces the chart, the switches that would change what it draws are
            // disabled. The picker stays enabled: it leads to the other chart.
            .disabled(!drawsChart)
            Toggle("Show in greyscale", isOn: $model.showsGreyscale)
                .disabled(!drawsChart)
        }
    }
}

#Preview("Colour alone") {
    NavigationStack {
        if let screen = Catalog.screen(id: "design/colour-never-colour-alone") {
            ColourAloneScreen(screen: screen)
        }
    }
}

#Preview("Empty") {
    ColourAloneChart(model: ColourAloneViewModel(stores: []), locale: .current)
        .frame(height: Layout.chartHeightCompact)
}

/// The chart for the Audio Graph, made of plain values the view model works out: a title, a summary in
/// actual values, a category axis, one series per café, and counts said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ColourAloneDescriptor: AXChartDescriptorRepresentable {
    struct Series {
        let name: String
        let points: [(x: String, y: Double)]
    }

    let title: String
    let summary: String
    let xTitle: String
    let categories: [String]
    let series: [Series]
    /// The value axis as drawn: the same range is passed to `chartYScale(domain:)`.
    let range: ClosedRange<Double>
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        return AXChartDescriptor(
            title: title,
            summary: summary,
            xAxis: AXCategoricalDataAxisDescriptor(title: xTitle, categoryOrder: categories),
            yAxis: AXNumericDataAxisDescriptor(
                title: CafeWording.cupsAxisTitle, range: range, gridlinePositions: []
            ) { value in CafeWording.count(value, locale: locale) },
            additionalAxes: [],
            series: series.map { series in
                // Separate values, not a connected line: a point per day, a segment per week.
                AXDataSeriesDescriptor(
                    name: series.name,
                    isContinuous: false,
                    dataPoints: series.points.map { AXDataPoint(x: $0.x, y: $0.y) }
                )
            }
        )
    }
}
