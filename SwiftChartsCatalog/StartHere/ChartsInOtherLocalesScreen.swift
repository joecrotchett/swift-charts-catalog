import Accessibility
import Charts
import SwiftUI

/// "Charts in other locales": what a chart formats for the locale and direction by itself,
/// and what the app has to write so that it can follow.
struct ChartsInOtherLocalesScreen: View {
    let screen: CatalogScreen
    @State private var model = ChartsInOtherLocalesViewModel()
    /// The device's locale: what VoiceOver hears stays in the reader's formats, whatever the chart is drawn in.
    @Environment(\.locale) private var deviceLocale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold so far in March",
            message: model.headline,
            explanation: """
            A default axis writes its labels for the locale the chart is drawn in: digits, separators, month names \
            and their order. What the app writes has to be able to follow: an axis format is a format style given \
            the environment's locale, an annotation is Text with a formatted value inside it, and titles and .value \
            labels are text that can be translated. Right to left, the chart mirrors: days run from the right, and \
            the value axis and the legend swap sides.
            """,
            snippets: model.snippets
        ) {
            RunningTotalsChart(
                cafes: model.cafes,
                showsBakedLabels: model.isShowingMistake,
                accessibilityLocale: deviceLocale,
                displayDescription: model.displayDescription
            )
            .chartEnvironment(model.environment)
        } controls: {
            ControlsSection {
                LabeledMenuPicker(title: "Locale", selection: $model.localeChoice) {
                    ForEach(ChartLocaleChoice.allCases) { choice in
                        Text(choice.title).tag(choice)
                    }
                }
                Toggle("Right-to-left layout", isOn: $model.isRightToLeft)
                MistakeToggle(title: "Bake the labels into strings", isShowingMistake: $model.isShowingMistake)
            }
        }
        // The axes are redrawn by every control, so each one is announced, not only seen.
        .onChange(of: model.displayDescription) { _, description in
            AccessibilityNotification.Announcement("Chart redrawn. \(description)").post()
        }
    }
}

/// Two cafés' running totals as lines, or a placeholder when nothing has been sold.
struct RunningTotalsChart: View {
    let cafes: [CafeRunningTotals]
    var showsBakedLabels = false
    var accessibilityLocale: Locale = .current
    var displayDescription = ""
    /// The locale the chart is drawn in, which a screen may have forced on it.
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// One line of the end label's text, growing with the text size.
    @ScaledMetric(relativeTo: .caption) private var labelLineHeight = EndLabelMetrics.lineHeight

    /// Room kept free above the highest value for the end label: one line, or two at the accessibility sizes,
    /// where the label wraps; capped, so the plot is not squeezed at the largest sizes.
    private var endLabelRoom: CGFloat {
        let lines: CGFloat = dynamicTypeSize.isAccessibilitySize ? 2 : 1
        return min(labelLineHeight * lines, EndLabelMetrics.largestRoom)
    }

    /// Fewer date labels as the text grows, so they are not cut short.
    private var daysPerLabel: Int {
        if dynamicTypeSize >= .accessibility3 { return DateAxis.month }
        if dynamicTypeSize >= .xxLarge { return DateAxis.fortnight }
        return DateAxis.week
    }

    var body: some View {
        let summary = RunningTotalsSummary(cafes: cafes, locale: accessibilityLocale)
        if summary.hasData {
            Chart {
                ForEach(cafes) { cafe in
                    // One accessibility element per week of each line: 56 separate days would be 56 stops.
                    ForEach(cafe.weeks) { week in
                        Plot {
                            ForEach(week.days) { day in
                                // snippet:charts-in-other-locales-marks
                                // The chart is given the date and the number themselves, never text made from them,
                                // so it can write its own labels for whatever locale it is drawn in.
                                LineMark(
                                    x: .value("Day", day.day, unit: .day, calendar: CafeData.calendar),
                                    y: .value("Cups", day.cups)
                                )
                                // end
                            }
                        }
                        .accessibilityLabel(summary.weekLabel(week))
                        .accessibilityValue(summary.weekValue(week))
                    }
                    .foregroundStyle(by: .value("Café", cafe.store))
                    .lineStyle(by: .value("Café", cafe.store))
                }
                // Cafés that end level end at one point, so they share one label that names them all.
                if let leader = summary.leaders.first, let last = leader.days.last {
                    // A point of no size at the leading line's end, for the label to hang on.
                    PointMark(
                        x: .value("Day", last.day, unit: .day, calendar: CafeData.calendar),
                        y: .value("Cups", last.cups)
                    )
                    .symbolSize(0)
                    .accessibilityHidden(true)
                    // The scale is fixed (below), so the label sits in the room kept above the highest value, and
                    // slides inward from the trailing edge instead of running off it.
                    .annotation(
                        position: .top, alignment: .trailing,
                        overflowResolution: .init(x: .fit(to: .plot), y: .disabled)
                    ) {
                        EndLabel(stores: summary.leaders.map(\.store), cups: last.cups, isBaked: showsBakedLabels)
                    }
                }
            }
            // Each café in its colour on every screen that draws the two.
            .chartForegroundStyleScale(mapping: CafeSeriesStyle.colour(for:))
            // One value axis for the chart and the Audio Graph, with room above it for the end label.
            .chartYScale(domain: summary.valueDomain, range: .plotDimension(endPadding: endLabelRoom))
            .chartXAxis {
                if showsBakedLabels {
                    // snippet:charts-in-other-locales-mistake-x-axis
                    AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) { value in
                        AxisGridLine()
                        AxisTick()
                        if let day = value.as(Date.self) {
                            // A finished string: "Mar 8" in German, in Japanese and in Arabic.
                            AxisValueLabel(BakedLabels.day(day))
                        }
                    }
                    // end
                } else {
                    // snippet:charts-in-other-locales-x-axis
                    // The format style says which parts to show; the locale decides their words and order.
                    // A style made here knows only the device's locale, so it is handed the environment's:
                    // `locale` is `@Environment(\.locale)`. The grid lines, ticks and labels stay the default ones.
                    AxisMarks(
                        format: Date.FormatStyle(locale: locale, timeZone: CafeData.calendar.timeZone).month().day(),
                        values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)
                    )
                    // end
                }
            }
            .chartYAxis {
                if showsBakedLabels {
                    // snippet:charts-in-other-locales-mistake-y-axis
                    AxisMarks { value in
                        AxisGridLine()
                        if let cups = value.as(Int.self) {
                            // "5000": Latin digits and no grouping separator, wherever it is read.
                            AxisValueLabel(BakedLabels.cups(cups))
                        }
                    }
                    // end
                } else {
                    // snippet:charts-in-other-locales-y-axis
                    // The default axis formats its numbers for the locale. Nothing to write.
                    AxisMarks()
                    // end
                }
            }
            // The app's own words: a string literal here is a key that can be translated.
            .yAxisTitle("Cups sold so far", short: CafeWording.cupsAxisTitle)
            .accessibilityChartDescriptor(
                RunningTotalsChartDescriptor(cafes: cafes, locale: accessibilityLocale, displayDescription: displayDescription)
            )
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Each café's cups sold so far appear here as a line.")
            )
        }
    }
}

/// How many days apart the date axis is labelled.
private enum DateAxis {
    static let week = 7
    static let fortnight = 14
    static let month = 28
}

/// The end label's room above the highest value.
private enum EndLabelMetrics {
    /// One line of caption text at the default size.
    static let lineHeight: CGFloat = 16
    /// The most room kept, whatever the text size.
    static let largestRoom: CGFloat = 90
}

/// The label at the end of the leading café's line, or of every leading line when cafés end level.
struct EndLabel: View {
    let stores: [String]
    let cups: Int
    let isBaked: Bool
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // At the accessibility sizes one line is wider than the plot and runs off the screen's edge
                // ("Harbour: 5,726 cups" at the largest size): the names and the total take a line each.
                VStack(alignment: .trailing) {
                    if isBaked {
                        // The same finished strings as the mistake's one line, split where it has its colon.
                        Text(verbatim: "\(stores.joined(separator: " and ")):")
                        Text(verbatim: "\(BakedLabels.cups(cups)) cups")
                    } else {
                        Text("\(stores, format: .list(type: .and)):")
                        Text("\(cups, format: .number) cups")
                    }
                }
            } else {
                EndLabelLine(stores: stores, cups: cups, isBaked: isBaked)
            }
        }
        .font(.caption)
        .foregroundStyle(Color.secondary)
    }
}

/// The end label on one line, as the snippets show it.
private struct EndLabelLine: View {
    let stores: [String]
    let cups: Int
    let isBaked: Bool

    var body: some View {
        Group {
            if isBaked {
                // snippet:charts-in-other-locales-mistake-annotation
                // The number became text before the view saw it, so no locale can reach it.
                Text(BakedLabels.total(stores: stores, cups: cups))
                // end
            } else {
                // snippet:charts-in-other-locales-annotation
                // The number stays a number and the names stay a list until they are drawn, and the sentence
                // around them is one translatable key.
                Text("\(stores, format: .list(type: .and)): \(cups, format: .number) cups")
                // end
            }
        }
    }
}

/// The chart for the Audio Graph: a title, a summary in actual values, a named series per café,
/// dates written out and values said with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct RunningTotalsChartDescriptor: AXChartDescriptorRepresentable {
    let cafes: [CafeRunningTotals]
    var locale: Locale = .current
    /// How the chart is currently drawn, added to the summary.
    var displayDescription = ""

    func makeChartDescriptor() -> AXChartDescriptor {
        let summary = RunningTotalsSummary(cafes: cafes, locale: locale)
        let days = cafes.first?.days.map(\.day) ?? []
        return AXChartDescriptor(
            title: "Cups sold so far in March, by café",
            summary: [summary.audioGraphSummary, displayDescription].filter { !$0.isEmpty }.joined(separator: " "),
            xAxis: AXCategoricalDataAxisDescriptor(title: "Day", categoryOrder: days.map(summary.dayText)),
            yAxis: AXNumericDataAxisDescriptor(title: "Cups sold so far", range: summary.valueDomain, gridlinePositions: []) { value in
                CafeWording.count(value, locale: summary.locale) { count, _ in summary.cupsText(count) }
            },
            additionalAxes: [],
            series: cafes.map { cafe in
                AXDataSeriesDescriptor(
                    name: cafe.store,
                    isContinuous: true,
                    dataPoints: cafe.days.map { AXDataPoint(x: summary.dayText($0.day), y: Double($0.cups)) }
                )
            }
        )
    }
}

#Preview("Device") {
    NavigationStack {
        if let screen = Catalog.screen(id: "start-here/charts-in-other-locales") {
            ChartsInOtherLocalesScreen(screen: screen)
        }
    }
}

#Preview("Arabic, right to left") {
    RunningTotalsChart(cafes: CafeData.storeSales.map(CafeRunningTotals.init))
        .chartEnvironment(ChartEnvironment(locale: Locale(identifier: "ar_EG"), layoutDirection: .rightToLeft))
        .padding()
}

#Preview("No sales") {
    RunningTotalsChart(cafes: [])
}
