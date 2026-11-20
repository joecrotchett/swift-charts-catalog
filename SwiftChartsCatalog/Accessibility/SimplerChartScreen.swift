import Accessibility
import Charts
import SwiftUI

/// "A simpler chart for VoiceOver": `accessibilityRepresentation` gives assistive technologies one bar
/// per drink, with its total and its sizes in words, in place of the stacked chart that is drawn.
struct SimplerChartScreen: View {
    let screen: CatalogScreen
    @State private var viewModel: SimplerChartViewModel
    /// Read here and passed in, so the headline, the elements and the descriptor write numbers alike.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, orders: [DrinkOrder] = CafeData.drinkOrders) {
        self.screen = screen
        _viewModel = State(initialValue: SimplerChartViewModel(orders: orders))
    }

    var body: some View {
        let speech = viewModel.speech(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold today, by drink and size",
            message: speech.headline,
            explanation: """
            The chart is drawn stacked, but VoiceOver and the Audio Graph can be given a different chart. \
            accessibilityRepresentation puts a simpler one in its place for assistive technologies only: one bar per \
            drink, its total as the value and its sizes in words. The chart descriptor goes inside the \
            representation too: one left on the drawn chart is lost, and the Audio Graph plays the representation's \
            defaults instead.
            """,
            snippets: viewModel.snippets
        ) {
            SimplerChartChart(speech: speech, usesRepresentation: viewModel.usesRepresentation)
        } controls: {
            SimplerChartControls(viewModel: viewModel, speech: speech)
            SimplerChartPrediction(
                elements: viewModel.elements(locale: locale),
                audioGraph: viewModel.audioGraph(locale: locale),
                isEmpty: speech.isEmpty
            )
            SimplerChartRoutes()
        }
    }
}

/// The toggle, which changes only what assistive technologies get; the drawn chart stays the same.
struct SimplerChartControls: View {
    @Bindable var viewModel: SimplerChartViewModel
    let speech: SimplerChartSpeech

    var body: some View {
        ControlsSection {
            Toggle("Give VoiceOver a simpler chart", isOn: $viewModel.usesRepresentation)
                // No chart to describe while the placeholder shows.
                .disabled(speech.isEmpty)
            Text(viewModel.usesRepresentation
                ? "On: one bar per drink, its total and its sizes in words."
                : "Off: the stacked chart as drawn, one element per drink with its total.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .onChange(of: viewModel.usesRepresentation) { _, usesRepresentation in
            // The chart VoiceOver hears changes kind, though nothing redraws: say so, then the headline.
            AccessibilityNotification.Announcement(speech.announcement(usesRepresentation: usesRepresentation)).post()
        }
    }
}

/// The stacked chart, with or without the simpler one for assistive technologies; a placeholder with no cups.
struct SimplerChartChart: View {
    let speech: SimplerChartSpeech
    let usesRepresentation: Bool

    var body: some View {
        if speech.isEmpty {
            ContentUnavailableView(
                "No cups sold yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold today appear here, one stacked bar per drink.")
            )
        } else if usesRepresentation {
            // snippet:simpler-chart-representation
            SimplerChartStackedBars(speech: speech)
                // Assistive technologies get this chart in place of the drawn one: one bar per drink,
                // so each label and value is read, and the Audio Graph plays the totals. A descriptor
                // on the drawn chart, outside this closure, is lost (read on iOS).
                .accessibilityRepresentation {
                    Chart(speech.totals) { total in
                        Plot {
                            BarMark(
                                x: .value(CafeWording.drink, total.drink),
                                y: .value(CafeWording.cupsAxisTitle, total.cups)
                            )
                        }
                        .accessibilityLabel(total.drink)
                        .accessibilityValue(speech.representationValue(total))
                    }
                    .chartYScale(domain: 0 ... speech.valueAxisTop)
                    // The descriptor goes here, on the representation's chart.
                    .accessibilityChartDescriptor(SimplerChartTotalsDescriptor(speech: speech))
                }
            // end
        } else {
            // snippet:simpler-chart-stacked
            SimplerChartStackedBars(speech: speech)
                // No representation: VoiceOver reads each stack as its total, and the Audio Graph
                // plays one series per size.
                .accessibilityChartDescriptor(SimplerChartStackedDescriptor(speech: speech))
            // end
        }
    }
}

/// The chart as drawn, in both states: a bar per drink, stacked by size.
struct SimplerChartStackedBars: View {
    let speech: SimplerChartSpeech
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Room above the top value, growing with the text, so its label, centred on it, stays inside the panel.
    @ScaledMetric(relativeTo: .caption) private var topLabelRoom = SimplerChartMetrics.topLabelRoom

    var body: some View {
        Chart(speech.orders) { order in
            BarMark(
                x: .value(CafeWording.drink, order.drink),
                y: .value(CafeWording.cupsAxisTitle, order.cups)
            )
            .foregroundStyle(by: .value(CafeWording.size, order.size))
            // A strip of space between neighbouring segments.
            .clipShape(Rectangle().inset(by: SimplerChartMetrics.segmentGap))
        }
        // The sizes in the data's order, so the legend reads in the order the segments stack.
        // The app's sizes, one sage hue from light to heavy, as on every screen that draws them.
        .chartForegroundStyleScale(domain: speech.sizes, mapping: CafeSizeStyle.colour(for:))
        .chartYScale(domain: 0 ... speech.valueAxisTop, range: .plotDimension(endPadding: topLabelRoom))
        .chartXAxis {
            if dynamicTypeSize.isAccessibilitySize {
                // At the accessibility sizes a name no longer fits its band and is cut ("Mo…"): turned
                // vertical, it has the plot's height to run along.
                // The default category axis draws grid lines and labels, no ticks (`axes.md`).
                AxisMarks { _ in
                    AxisGridLine()
                    AxisValueLabel(orientation: .vertical)
                }
            } else {
                AxisMarks()
            }
        }
    }
}

/// What VoiceOver reads and what the Audio Graph gets, in the current state, as read on iOS; the empty
/// state, which was not read, stays a prediction.
struct SimplerChartPrediction: View {
    let elements: [SimplerChartElement]
    let audioGraph: SimplerChartAudioGraph
    let isEmpty: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("What assistive technologies get")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            if isEmpty {
                Label("Predicted from the framework's defaults and this screen's code, not read from the device.",
                      systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("No chart is drawn, so there are no chart elements and no Audio Graph: VoiceOver reads the placeholder.")
            } else {
                Label("Read on the iPhone 17 simulator, iOS 27.0.", systemImage: "checkmark.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Text("VoiceOver reads, one element at a time")
                    .font(.subheadline.weight(.semibold))
                ForEach(elements) { element in
                    Text(element.spoken)
                }
                Text("The Audio Graph gets")
                    .font(.subheadline.weight(.semibold))
                Text("Title: \(audioGraph.title)")
                Text("Summary: \(audioGraph.summary)")
                Text("x axis: \(audioGraph.xAxisTitle), \(CafeWording.list(audioGraph.categories))")
                Text("y axis: \(audioGraph.yAxisTitle), \(audioGraph.yAxisRange)")
                ForEach(audioGraph.series, id: \.self) { series in
                    Text("Series \(series)")
                }
            }
            Text("To hear it on a device: turn VoiceOver on, swipe through the chart, then open the rotor's Audio Graph and choose Describe chart or Play Audio Graph.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// When to replace the chart for assistive technologies, and when to label its segments instead.
struct SimplerChartRoutes: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("Which route suits")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)
            Text("A labelled Plot around each segment, as on the Labels that are not read screen, keeps the drawn chart and makes every segment a stop: right when each size's figure is what people come for.")
            Text("A representation replaces the whole chart for assistive technologies: right when the total per drink is the point and nine stops would bury it. The sizes are not lost; each bar says them in words.")
            Text("Put the chart descriptor inside the representation, on its chart. Read on iOS, a descriptor left on the drawn chart is lost: the Audio Graph falls back to the representation chart's defaults, titled only \"Chart\", with bare numbers.")
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// Constants that belong to this chart's marks.
private enum SimplerChartMetrics {
    static let segmentGap: CGFloat = 1
    static let topLabelRoom: CGFloat = 8
}

#Preview("Orders") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/a-simpler-chart-for-voiceover") {
            SimplerChartScreen(screen: screen)
        }
    }
}

#Preview("No cups") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/a-simpler-chart-for-voiceover") {
            SimplerChartScreen(screen: screen, orders: [])
        }
    }
}
