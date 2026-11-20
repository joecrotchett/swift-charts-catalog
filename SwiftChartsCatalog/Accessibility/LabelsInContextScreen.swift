import Charts
import SwiftUI

/// "Labels that give context": what VoiceOver reads for a bar on a date axis with no labels, against a
/// label and value written on a `Plot` around it.
struct LabelsInContextScreen: View {
    let screen: CatalogScreen
    @State private var model = LabelsInContextViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers and
    /// dates the same way.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: model.summary(locale: locale).caption,
            message: model.summary(locale: locale).headline,
            explanation: """
            With no accessibility code, VoiceOver reads a bar as its x value and then its y value. On a date axis \
            the x value is a range of date-times, written in the time zone of the calendar given to the value (the \
            device's if none), and the y value is a bare number. \
            A label and value on a Plot around the bar say what it is instead: the day written out, in the time zone \
            it was counted in, then the count with its unit.
            """,
            snippets: model.snippets
        ) {
            LabelsInContextChart(
                days: model.days, style: model.style, dataCalendar: model.dataCalendar, locale: locale
            )
        } controls: {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                ControlsSection {
                    MistakeToggle(title: "Use the framework's default labels", isShowingMistake: $model.isShowingDefault)
                        // With no bars there is nothing for the labels to change.
                        .disabled(model.isEmpty)
                }
                LabelsInContextSpokenPanel(
                    style: model.style,
                    isChartDrawn: !model.isEmpty,
                    lines: model.spokenLines(locale: locale),
                    shortfalls: model.shortfalls(locale: locale)
                )
            }
        }
    }
}

/// A week of bars on a date axis, with the framework's description or the app's own.
struct LabelsInContextChart: View {
    let days: [DailySales]
    let style: LabelsInContextStyle
    let dataCalendar: Calendar
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room above the plot for the busiest day's figure, growing with the text, since the figure is left
    /// to draw past the plot's top rather than slide down over its bar.
    @ScaledMetric(relativeTo: .caption) private var figureRoom = LabelsInContextMarks.figureRoom

    private var summary: LabelsInContextSummary {
        LabelsInContextSummary(days: days, dataCalendar: dataCalendar, locale: locale)
    }

    /// "Sun" under each bar; at the accessibility sizes, where seven of those do not fit, "S".
    private var weekdayFormat: Date.FormatStyle {
        let style = Date.FormatStyle(locale: locale, timeZone: dataCalendar.timeZone)
        return dynamicTypeSize >= .accessibility1 ? style.weekday(.narrow) : style.weekday(.abbreviated)
    }

    var body: some View {
        if summary.total == 0 {
            ContentUnavailableView(
                "No sales this week",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        } else {
            Group {
                switch style {
                case .written:
                    // snippet:labels-in-context-written
                    Chart(days) { day in
                        // A label and value on a Plot around the bar replace what the framework says.
                        Plot {
                            BarMark(
                                x: .value(CafeWording.day, day.day, unit: .day, calendar: dataCalendar),
                                y: .value(CafeWording.cups, day.cups)
                            )
                            .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                                LabelsInContextBusiestFigure(day: day, summary: summary)
                            }
                        }
                        // "Sunday, March 1", then "190 cups".
                        .accessibilityLabel(
                            LabelsInContextSpokenText.writtenLabel(for: day.day, dataCalendar: dataCalendar, locale: locale)
                        )
                        .accessibilityValue(LabelsInContextSpokenText.writtenValue(cups: day.cups, locale: locale))
                    }
                // end
                case .framework:
                    // snippet:labels-in-context-default
                    // No accessibility code: VoiceOver reads each bar as
                    // "Mar 1, 2026 at 12 AM to Mar 2, 2026 at 12 AM, 190": in the time zone of the calendar
                    // given to the value (the device's if none).
                    Chart(days) { day in
                        BarMark(
                            x: .value(CafeWording.day, day.day, unit: .day, calendar: dataCalendar),
                            y: .value(CafeWording.cups, day.cups)
                        )
                        .annotation(position: .top, overflowResolution: .init(x: .fit(to: .plot), y: .disabled)) {
                            LabelsInContextBusiestFigure(day: day, summary: summary)
                        }
                    }
                    // end
                }
            }
            .chartYScale(domain: 0 ... summary.valueAxisTop)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: 1, calendar: dataCalendar)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: weekdayFormat, centered: true)
                }
            }
            .padding(.top, figureRoom)
            // The labels change while the data's ids do not: a new identity makes VoiceOver read the new words.
            .id(style)
            .accessibilityChartDescriptor(
                LabelsInContextChartDescriptor(days: days, dataCalendar: dataCalendar, locale: locale)
            )
        }
    }
}

/// Constants that belong to this chart's marks.
private enum LabelsInContextMarks {
    /// The figure's height at the default text size, scaled with the text.
    static let figureRoom: CGFloat = 12
}

/// The busiest day's figure above its bar, so the headline's number can be found in the chart.
/// Annotation views are not read; the bar's own value carries the number for VoiceOver.
struct LabelsInContextBusiestFigure: View {
    let day: DailySales
    let summary: LabelsInContextSummary

    var body: some View {
        if summary.busiestDays.contains(day) {
            Text(day.cups, format: .number.locale(summary.locale))
                .font(.caption.bold())
                .foregroundStyle(.secondary)
        }
    }
}

/// What VoiceOver reads for each bar in the current state, and what is wrong with the default.
struct LabelsInContextSpokenPanel: View {
    let style: LabelsInContextStyle
    /// `false` while the placeholder shows: no bars, no lines, and no Audio Graph to speak of.
    let isChartDrawn: Bool
    let lines: [LabelsInContextSpokenLine]
    let shortfalls: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("What VoiceOver reads")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            if isChartDrawn {
                Text(LabelsInContextSpokenText.source(for: style))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Text(LabelsInContextSpokenText.nothingDrawn)
                    .font(.callout)
            }
            ForEach(lines) { line in
                Text("\u{201C}\(line.spoken)\u{201D}")
                    .font(.callout.monospaced())
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !shortfalls.isEmpty {
                LabelsInContextShortfallList(shortfalls: shortfalls)
            }
            if isChartDrawn {
                Text(LabelsInContextSpokenText.audioGraphNote)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Text(LabelsInContextSpokenText.howToHear)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// What is wrong with the framework's description, said on screen.
struct LabelsInContextShortfallList: View {
    let shortfalls: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("What is wrong with it")
                .font(.subheadline.bold())
                .accessibilityAddTraits(.isHeader)
            ForEach(shortfalls, id: \.self) { item in
                // The text in the primary colour, for contrast; orange marks the icon only.
                Label {
                    Text(item)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote)
            }
        }
    }
}

#Preview("Written labels") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/labels-that-give-context") {
            LabelsInContextScreen(screen: screen)
        }
    }
}

#Preview("Framework's labels") {
    LabelsInContextSpokenPanel(
        style: .framework,
        isChartDrawn: true,
        lines: LabelsInContextViewModel().days.map {
            LabelsInContextSpokenText.line(for: $0, style: .framework, dataCalendar: CafeData.calendar, locale: .current)
        },
        shortfalls: ["No unit: the value is the bare number \u{201C}190\u{201D}."]
    )
    .padding()
}

#Preview("No sales") {
    LabelsInContextChart(days: [], style: .written, dataCalendar: CafeData.calendar, locale: .current)
}
