import Charts
import SwiftUI

/// "Calendar heat map": a date on both axes, weeks as rows and weekdays as columns, tiles shaded by value.
struct CalendarHeatMapScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = CalendarHeatMapViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = viewModel.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: summary.caption,
            message: summary.headline,
            explanation: summary.explanation,
            snippets: viewModel.snippets
        ) {
            CalendarHeatMapChart(summary: summary)
        } controls: {
            ControlsSection {
                MistakeToggle(
                    title: "Plot each day's own date on x",
                    isShowingMistake: $viewModel.isShowingMistake.animation(.easeInOut)
                )
                Toggle("Show what VoiceOver reads", isOn: $viewModel.isShowingSpokenText)
                if viewModel.isShowingSpokenText {
                    CalendarHeatMapSpokenText(summary: summary)
                }
            }
        }
        .onChange(of: viewModel.isShowingMistake) {
            // The scale changes under the reader: say what changed, then what the chart now shows.
            AccessibilityNotification.Announcement(viewModel.summary(locale: locale).announcement).post()
        }
    }
}

/// Sizes and colours that belong to this chart's marks.
private enum CalendarHeatMapMetrics {
    /// Taken off each edge of a tile: an even two-point gap between neighbours.
    static let tileInset: CGFloat = 1
    static let tileCornerRadius: CGFloat = 4
    /// Between a tile's edge and the label inside it.
    static let labelInset: CGFloat = 3
    /// The staircase has a column per day; it labels one in every fourteen. At the accessibility text
    /// sizes a fortnight's labels run into each other, and at twenty-eight days the third label starts
    /// too near the trailing edge to fit, so there it labels one in every thirty-five.
    static let staircaseLabelStride = 14
    static let staircaseLabelStrideLargeText = 35
    /// The two ends of the colour range. Both are dark enough for a white day number: the pale end
    /// is about 4.9:1 against white, the deep end about 12:1.
    static let paleBlue = Color(red: 0.22, green: 0.46, blue: 0.66)
    static let deepBlue = Color(red: 0.05, green: 0.2, blue: 0.45)
    /// In-tile labels stop growing here: a tile's width does not grow with the text.
    static let largestLabelSize = DynamicTypeSize.xxLarge
    /// From this text size the automatic legend's numbers run into each other, so the screen draws its own.
    static let ownLegendSize = DynamicTypeSize.xxLarge
    static let legendBarHeight: CGFloat = 10
    static let legendCornerRadius: CGFloat = 2
}

/// The calendar, or a placeholder when there are no days to draw.
struct CalendarHeatMapChart: View {
    let summary: CalendarHeatMapSummary
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Dates are written in the data's time zone and the view's locale.
    private var dateStyle: Date.FormatStyle {
        Date.FormatStyle(locale: summary.locale, timeZone: summary.calendar.timeZone)
    }

    /// Low values recede toward the background in either appearance.
    private var colours: [Color] {
        colorScheme == .dark
            ? [CalendarHeatMapMetrics.deepBlue, CalendarHeatMapMetrics.paleBlue]
            : [CalendarHeatMapMetrics.paleBlue, CalendarHeatMapMetrics.deepBlue]
    }

    var body: some View {
        if summary.days.isEmpty {
            ContentUnavailableView(
                "No days recorded",
                systemImage: "calendar",
                description: Text("Cups sold each day appear here, one tile per day.")
            )
        } else {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                chart
                if usesOwnLegend {
                    CalendarHeatMapLegend(colours: colours)
                }
            }
        }
    }

    /// At large text sizes the automatic legend's numbers collide; a legend in words takes its place.
    private var usesOwnLegend: Bool {
        dynamicTypeSize >= CalendarHeatMapMetrics.ownLegendSize
    }

    /// How many days apart the staircase's date labels are.
    private var staircaseLabelStride: Int {
        dynamicTypeSize.isAccessibilitySize
            ? CalendarHeatMapMetrics.staircaseLabelStrideLargeText
            : CalendarHeatMapMetrics.staircaseLabelStride
    }

    private var chart: some View {
        Group {
            Chart(summary.days) { day in
                // The summary decides the date on x: the weekday's column, or in the mistake the
                // day's own date. In the staircase a tile is a few points wide and holds no text.
                CalendarHeatMapTile(
                    day: day, column: summary.xDate(for: day.day), columnName: summary.xValueName,
                    calendar: summary.calendar, dateStyle: dateStyle,
                    isFirstOfMonth: summary.isFirstOfMonth(day.day), showsLabels: !summary.isStaircase
                )
            }
            .chartXAxis {
                if summary.isStaircase {
                    // A column per day: the columns are dates now, not weekdays.
                    AxisMarks(
                        position: .top,
                        values: .stride(by: .day, count: staircaseLabelStride, calendar: summary.calendar)
                    ) { _ in
                        AxisTick()
                        AxisValueLabel(format: dateStyle.month(.abbreviated).day())
                    }
                } else {
                    AxisMarks(position: .top, values: .stride(by: .day, calendar: summary.calendar)) { _ in
                        // All seven names are needed, so at the largest text sizes each is cut to a letter.
                        AxisValueLabel(
                            format: dateStyle.weekday(dynamicTypeSize.isAccessibilitySize ? .narrow : .abbreviated),
                            centered: true
                        )
                    }
                }
            }
            // The day numbers in the tiles say which week a row is.
            .chartYAxis(.hidden)
            .chartLegend(usesOwnLegend ? .hidden : .automatic)
            // The automatic range starts near white, where the white day numbers would vanish.
            .chartForegroundStyleScale(range: Gradient(colors: colours))
            // snippet:calendar-heat-map-elements
            .chartPlotStyle { plotArea in
                // Every column would otherwise be one accessibility element summarising its days.
                // Replaced here, on the plot area, the new elements lie over the tiles.
                plotArea.accessibilityChildren {
                    CalendarHeatMapElements(rows: summary.elementRows)
                }
            }
            // end
            // A calendar grid gets no Audio Graph of its own.
            .accessibilityChartDescriptor(CalendarHeatMapDescriptor(summary: summary))
        }
    }
}

/// What the shading measures, in words: for text sizes at which the automatic legend's numbers collide.
/// Its colours are the ones handed to the chart's colour scale.
struct CalendarHeatMapLegend: View {
    let colours: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            LinearGradient(colors: colours, startPoint: .leading, endPoint: .trailing)
                .frame(height: CalendarHeatMapMetrics.legendBarHeight)
                .clipShape(.rect(cornerRadius: CalendarHeatMapMetrics.legendCornerRadius))
            ViewThatFits {
                HStack {
                    Text("Fewer cups")
                    Spacer()
                    Text("More cups")
                }
                HStack {
                    Text("Fewer")
                    Spacer()
                    Text("More")
                }
            }
            .lineLimit(1)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        // The automatic legend is not an accessibility element either: the elements carry the values.
        .accessibilityHidden(true)
    }
}

// snippet:calendar-heat-map-tile
/// One day of the calendar: a rectangle with a date on both axes, shaded by the day's cups.
struct CalendarHeatMapTile: ChartContent {
    let day: DailySales
    /// The date that decides the column.
    let column: Date
    /// What that date is: a weekday while weekdays are columns, the day itself in the staircase.
    let columnName: String
    /// The calendar the days were recorded in, so a day is cut where the data cut it.
    let calendar: Calendar
    let dateStyle: Date.FormatStyle
    let isFirstOfMonth: Bool
    /// False in the staircase, where a tile is a few points wide and holds no text.
    let showsLabels: Bool

    var body: some ChartContent {
        RectangleMark(
            x: .value(columnName, column, unit: .day, calendar: calendar),
            // The real date, as a whole week: one row per week. Dates on y run downward.
            y: .value(CafeWording.week, day.day, unit: .weekOfYear, calendar: calendar),
            width: .inset(CalendarHeatMapMetrics.tileInset),
            height: .inset(CalendarHeatMapMetrics.tileInset)
        )
        .foregroundStyle(by: .value(CafeWording.cups, day.cups))
        .cornerRadius(CalendarHeatMapMetrics.tileCornerRadius)
        .annotation(
            position: .overlay, alignment: .bottomTrailing, spacing: CalendarHeatMapMetrics.labelInset
        ) {
            if showsLabels {
                // The first of a month carries the month's name in place of its "1". The text is
                // formatted here, not by Text, which would write the date in the device's time zone.
                Text(day.day.formatted(isFirstOfMonth ? dateStyle.month(.abbreviated) : dateStyle.day()))
                    .fontWeight(isFirstOfMonth ? .bold : .regular)
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    // A tile's width does not grow with the text, so its label stops growing here.
                    .dynamicTypeSize(...CalendarHeatMapMetrics.largestLabelSize)
            }
        }
    }
}

// end

/// The accessibility elements that replace the plot area's own: one square per tile position, laid
/// out as the tiles are drawn and never drawn themselves. Positions with no day are hidden.
struct CalendarHeatMapElements: View {
    let rows: [[CalendarHeatMapElement?]]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(rows.indices, id: \.self) { row in
                HStack(spacing: 0) {
                    ForEach(rows[row].indices, id: \.self) { column in
                        let element = rows[row][column]
                        Rectangle()
                            .accessibilityLabel(Text(element?.label ?? ""))
                            .accessibilityValue(Text(element?.value ?? ""))
                            // Headings let VoiceOver jump from month to month.
                            .accessibilityAddTraits(element?.isHeading == true ? .isHeader : [])
                            .accessibilityHidden(element == nil)
                    }
                }
            }
        }
    }
}

/// The first elements written out, so a sighted reader can see what VoiceOver is given.
struct CalendarHeatMapSpokenText: View {
    let summary: CalendarHeatMapSummary

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            ForEach(summary.spokenPreview, id: \.self) { line in
                Text(line)
            }
            Text(summary.spokenFootnote)
                .foregroundStyle(.secondary)
                .padding(.top, Layout.tightSpacing)
        }
        .font(.footnote)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private let calendarHeatMapPreviewScreen = CatalogScreen(
    id: "marks/calendar-heat-map", title: "Calendar heat map", summary: "", apiSince: "16.0",
    skillReferences: ["gallery/calendar.md"],
    snippets: [SnippetReference(name: "calendar-heat-map-tile", title: "A tile with a date on both axes")]
)

#Preview("Calendar") {
    NavigationStack {
        CalendarHeatMapScreen(screen: calendarHeatMapPreviewScreen)
    }
}

#Preview("Staircase") {
    CalendarHeatMapChart(
        summary: CalendarHeatMapSummary(
            days: CafeData.tenWeeks, calendar: CafeData.calendar, isStaircase: true, locale: .current
        )
    )
    .padding()
}

#Preview("No days") {
    CalendarHeatMapChart(
        summary: CalendarHeatMapSummary(days: [], calendar: CafeData.calendar, isStaircase: false, locale: .current)
    )
}
