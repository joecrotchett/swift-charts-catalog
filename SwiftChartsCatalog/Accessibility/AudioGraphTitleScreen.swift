import Accessibility
import Charts
import SwiftUI

/// "Audio Graph title and summary": the Audio Graph the framework makes by itself, titled "Chart" with
/// bare values and dates as seconds, beside the same chart given a chart descriptor.
struct AudioGraphTitleScreen: View {
    let screen: CatalogScreen
    @State private var model = AudioGraphTitleViewModel()
    /// Read here and passed in, so the headline, the elements and the descriptor write numbers and dates
    /// the way the chart's own axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day, \(CafeWording.harbour) café",
            message: model.words(locale: locale).headline,
            explanation: """
            With no code, a chart's Audio Graph is titled "Chart", has no summary, and gives each point as a \
            bare number: on a date axis each date is handed over as seconds since 2001, and no value has a unit. \
            A chart descriptor, a type conforming to AXChartDescriptorRepresentable attached with \
            accessibilityChartDescriptor, replaces all of it, and the Audio Graph then gets exactly the \
            descriptor: a title, a summary in actual values, axis titles, written-out dates, and values said \
            with their unit.
            """,
            snippets: model.snippets
        ) {
            AudioGraphTitleChartPanel(model: model, locale: locale)
        } controls: {
            ControlsSection {
                MistakeToggle(title: "Leave out the chart descriptor", isShowingMistake: $model.isShowingDefault)
                    .disabled(model.showsPlaceholder)
            }
            AudioGraphTitleDataPanel(
                heading: "Default Audio Graph",
                source: "Read on iOS 27 (simulator). How a value of 1,000 or more is grouped is a prediction.",
                isAttached: model.isShowingDefault,
                note: """
                What is wrong with it: the title says nothing about the chart, there is no summary, and each \
                day is a number of seconds and a bare value, with no written date and no unit.
                """,
                rows: model.defaultRows(locale: locale)
            )
            AudioGraphTitleDataPanel(
                heading: "With the chart descriptor",
                source: "Generated from this screen's chart descriptor. Read on iOS 27 (simulator): the Audio Graph gets exactly this.",
                isAttached: !model.isShowingDefault,
                note: """
                The descriptor's axes are titled \(AudioGraphTitleWords.descriptorDateAxisTitle) and \
                \(AudioGraphTitleWords.descriptorCupsAxisTitle), while the chart's .value labels are \
                \(CafeWording.day) and \(CafeWording.cups): the names Describe chart uses tell you which \
                source VoiceOver read.
                """,
                rows: model.descriptorRows(locale: locale)
            )
            AudioGraphTitleListenHint()
        }
    }
}

/// The chart with or without its descriptor, or a placeholder when nothing was sold.
struct AudioGraphTitleChartPanel: View {
    let model: AudioGraphTitleViewModel
    let locale: Locale

    var body: some View {
        let words = model.words(locale: locale)
        if model.showsPlaceholder {
            ContentUnavailableView(
                "No cups sold",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold each day appear here, one bar per day.")
            )
        } else if model.isShowingDefault {
            // snippet:audio-graph-title-default
            // No descriptor: the Audio Graph gets the framework's default, titled "Chart", with no summary,
            // and each day as a bare number. The elements are still labelled, so they stay honest.
            AudioGraphTitleChart(days: model.days, words: words)
            // end
        } else {
            // snippet:audio-graph-title-attach
            AudioGraphTitleChart(days: model.days, words: words)
                // Replaces everything the Audio Graph is given; the elements are unchanged.
                .accessibilityChartDescriptor(model.descriptor(locale: locale))
            // end
        }
    }
}

/// A week of daily cups: one bar per day on a date axis, each labelled with its date and its cups.
struct AudioGraphTitleChart: View {
    let days: [DailySales]
    let words: AudioGraphTitleWords
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// Fewer axis labels as the text grows, so they do not collide.
    private var daysPerLabel: Int {
        dynamicTypeSize >= .xxLarge ? 2 : 1
    }

    /// At the largest sizes "Mar 3" is cut short even every other day, so the day alone is written.
    private var labelStyle: Date.FormatStyle {
        dynamicTypeSize >= .accessibility1 ? words.axisDayOnlyStyle : words.axisDayStyle
    }

    var body: some View {
        // snippet:audio-graph-title-chart
        Chart(days) { day in
            // The day was recorded in UTC: the data's calendar cuts it, so the bar is drawn on that day.
            Plot {
                BarMark(
                    x: .value(CafeWording.day, day.day, unit: .day, calendar: CafeData.calendar),
                    y: .value(CafeWording.cups, day.cups)
                )
            }
            // The label and value go on a Plot: "Sunday, March 1, 190 cups", not a range of date-times.
            .accessibilityLabel(words.elementLabel(day))
            .accessibilityValue(words.elementValue(day))
        }
        // The one value scale, also the descriptor's y range: the Audio Graph's axis is the drawn axis.
        .chartYScale(domain: words.yDomain)
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: CafeData.calendar)) {
                AxisGridLine()
                AxisTick()
                AxisValueLabel(format: labelStyle, centered: daysPerLabel == 1)
            }
        }
        // end
    }
}

// snippet:audio-graph-title-descriptor
/// The chart for the Audio Graph: a title, a summary, axis titles, written-out dates, values with their unit.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct AudioGraphTitleDescriptor: AXChartDescriptorRepresentable {
    let words: AudioGraphTitleWords

    func makeChartDescriptor() -> AXChartDescriptor {
        let words = words
        // A date axis has no descriptor type: the dates are categories, written out in the data's time zone.
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: AudioGraphTitleWords.descriptorDateAxisTitle,
            categoryOrder: words.days.map { words.dayName($0.day) }
        )
        // The chart's own scale, from the same value: each value said with its unit, agreeing in number.
        let yAxis = AXNumericDataAxisDescriptor(
            title: AudioGraphTitleWords.descriptorCupsAxisTitle,
            range: words.yDomain,
            gridlinePositions: []
        ) { value in words.valueDescription(value) }
        let series = AXDataSeriesDescriptor(
            name: CafeWording.harbour,
            isContinuous: false, // A bar per day: separate totals.
            dataPoints: words.days.map { AXDataPoint(x: words.dayName($0.day), y: Double($0.cups)) }
        )
        return AXChartDescriptor(
            title: AudioGraphTitleWords.descriptorTitle,
            summary: words.descriptorSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// end

/// One set of Audio Graph data written out, with where it came from and whether the chart carries it now.
struct AudioGraphTitleDataPanel: View {
    let heading: String
    let source: String
    let isAttached: Bool
    let note: String
    let rows: [AudioGraphTitleRow]

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text(heading)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(source)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if isAttached {
                    Label("The chart carries this now", systemImage: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(.tint)
                }
            }
            ForEach(rows) { row in
                VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                    Text(row.part)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(row.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            }
            Text(note)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// How to hear the result on a device.
struct AudioGraphTitleListenHint: View {
    var body: some View {
        Label {
            Text("""
            To hear it on a device: turn VoiceOver on and swipe through the chart, one day at a time. Then turn \
            the rotor to Audio Graph and choose Describe chart for the title, summary and axes, or Play Audio \
            Graph to hear the values as tones. Switch the toggle and listen again.
            """)
        } icon: {
            Image(systemName: "speaker.wave.2")
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

#Preview("Descriptor") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/audio-graph-title-and-summary") {
            AudioGraphTitleScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    AudioGraphTitleChartPanel(model: AudioGraphTitleViewModel(days: []), locale: .current)
}
