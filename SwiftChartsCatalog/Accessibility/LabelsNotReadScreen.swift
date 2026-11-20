import Accessibility
import Charts
import SwiftUI

/// "Labels that are not read": the same label and value on every segment of a stacked bar chart, written
/// on the bare marks (ignored, the framework's summary of each bar is read) or on a `Plot` around each
/// mark (read, one element per segment).
struct LabelsNotReadScreen: View {
    let screen: CatalogScreen
    @State private var model: LabelsNotReadViewModel
    /// The locale every count is written in, read here and passed in.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, orders: [DrinkOrder] = CafeData.drinkOrders) {
        self.screen = screen
        _model = State(initialValue: LabelsNotReadViewModel(orders: orders))
    }

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold by drink and size",
            message: model.headline(locale: locale),
            explanation: """
            Every segment carries the same label and value in both settings. On a bare BarMark that shares its \
            bar with other segments, VoiceOver ignores them and reads the framework's summary of the whole bar. \
            Wrapped in a Plot, each segment becomes an element of its own, read by exactly the words written.
            """,
            snippets: model.snippets
        ) {
            LabelsNotReadChart(model: model, locale: locale)
        } controls: {
            ControlsSection {
                MistakeToggle(
                    title: "Put the labels on the bare segments",
                    isShowingMistake: Binding(
                        get: { model.isShowingMistake },
                        set: { newValue in
                            model.isShowingMistake = newValue
                            labelsNotReadAnnounce(model.changeAnnouncement(locale: locale))
                        }
                    )
                )
                .disabled(model.isEmpty)
                LabelsNotReadSpokenList(model: model, locale: locale)
                LabelsNotReadHearingNote()
            }
        }
    }
}

/// The stacked bars, their segment labels on the bare marks or on a `Plot`, or a placeholder.
struct LabelsNotReadChart: View {
    let model: LabelsNotReadViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if model.isEmpty {
            ContentUnavailableView(
                "No cups sold yet",
                systemImage: "cup.and.saucer",
                description: Text("Cups sold appear here, one bar per drink, one segment per size.")
            )
        } else {
            Chart(model.drawnOrders) { order in
                if model.isShowingMistake {
                    // snippet:labels-not-read-bare
                    // The mistake: the label is on a bare mark that shares its bar with others,
                    // so VoiceOver ignores it and reads "Latte, total 128, 3 Sizes".
                    BarMark(
                        x: .value(CafeWording.drink, order.drink),
                        y: .value(CafeWording.cupsAxisTitle, order.cups)
                    )
                    .foregroundStyle(by: .value(CafeWording.size, order.size))
                    .clipShape(Rectangle().inset(by: LabelsNotReadStyle.segmentGap))
                    .accessibilityLabel(LabelsNotReadText.elementLabel(order))
                    .accessibilityValue(LabelsNotReadText.elementValue(order, locale: locale))
                    // end
                } else {
                    // snippet:labels-not-read-plot
                    // The same label on a Plot around the mark: each segment is one element,
                    // read as "Latte, Small, 34 cups".
                    Plot {
                        BarMark(
                            x: .value(CafeWording.drink, order.drink),
                            y: .value(CafeWording.cupsAxisTitle, order.cups)
                        )
                        .foregroundStyle(by: .value(CafeWording.size, order.size))
                        .clipShape(Rectangle().inset(by: LabelsNotReadStyle.segmentGap))
                    }
                    .accessibilityLabel(LabelsNotReadText.elementLabel(order))
                    .accessibilityValue(LabelsNotReadText.elementValue(order, locale: locale))
                    // end
                }
            }
            .chartYScale(domain: 0 ... model.valueDomainTop)
            // The app's sizes, one sage hue from light to heavy, as on every screen that draws them.
            .chartForegroundStyleScale(domain: CafeSizeStyle.sizes, mapping: CafeSizeStyle.colour(for:))
            // At the accessibility sizes the drink names are cut to a letter and an ellipsis: turn them upright.
            .chartXAxis {
                AxisMarks { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(orientation: dynamicTypeSize.isAccessibilitySize ? .vertical : .horizontal)
                }
            }
            // snippet:labels-not-read-identity
            // The data's ids do not change when the labels move, so give the chart a new identity,
            // or VoiceOver keeps the elements it made for the other setting.
            .id(model.isShowingMistake)
            // end
            .accessibilityChartDescriptor(model.chartDescriptor(locale: locale))
        }
    }
}

/// Constants for this chart's marks.
private enum LabelsNotReadStyle {
    /// A strip of empty space between neighbouring segments, so each can be seen.
    static let segmentGap: CGFloat = 1
}

/// What VoiceOver reads for the chart as drawn now, and, in the mistake, what is wrong.
struct LabelsNotReadSpokenList: View {
    let model: LabelsNotReadViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text("What VoiceOver reads")
                .font(.subheadline.weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(model.isShowingMistake
                ? "Read on the iPhone 17 simulator, iOS 27: one element per bar, in drink order."
                : "Read on the iPhone 17 simulator, iOS 27: bar by bar, each from the bottom segment up.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            ForEach(model.predictedElements(locale: locale), id: \.self) { element in
                Text(element.spoken)
                    .font(.callout.monospaced())
            }
            if model.isShowingMistake, !model.isEmpty {
                // The text in the primary colour, for contrast; orange marks the icon only.
                Label {
                    Text("""
                    What is wrong: the labels ("\(model.drawnOrders.first.map(LabelsNotReadText.elementLabel) ?? "")" \
                    and the rest) are written but never heard. A stacked bar is one element, so the framework reads \
                    its own total and count instead, and a listener cannot learn any one size's cups.
                    """)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote)
            }
        }
    }
}

/// How to hear the chart on a device.
struct LabelsNotReadHearingNote: View {
    var body: some View {
        Text("""
        To hear it: turn VoiceOver on, swipe through the chart in each setting, then use the rotor's Audio Graph \
        (Describe chart, Play Audio Graph). The Audio Graph is the same in both: labels never reach it.
        """)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
}

/// Says aloud that the chart's elements changed, for people who cannot see it happen.
@MainActor
private func labelsNotReadAnnounce(_ message: String) {
    // iOS 17.0+, below the app's iOS 18 deployment target, so no availability check.
    AccessibilityNotification.Announcement(message).post()
}

#Preview("Labels on a Plot") {
    NavigationStack {
        if let screen = Catalog.screen(id: "accessibility/labels-that-are-not-read") {
            LabelsNotReadScreen(screen: screen)
        }
    }
}

#Preview("No data") {
    LabelsNotReadChart(model: LabelsNotReadViewModel(orders: []), locale: .current)
        .frame(height: Layout.chartHeightCompact)
}
