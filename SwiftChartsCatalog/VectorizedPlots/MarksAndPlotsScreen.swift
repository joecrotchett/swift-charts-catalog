import Charts
import SwiftUI

/// "Marks and plots": one scatter of thousands of orders, drawn by a `ForEach` of `PointMark`s or by one
/// `PointPlot`, and the rule for choosing between them.
struct MarksAndPlotsScreen: View {
    let screen: CatalogScreen
    @State private var model = MarksAndPlotsViewModel()
    /// Read here and passed in, so the headline, the controls and the Audio Graph write numbers as the axes do.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Wait for each order, by time of day",
            message: model.summary(locale: locale).headline,
            explanation: """
            A mark draws one element, so a chart of marks is a ForEach that makes a PointMark per order; a plot \
            takes the whole collection and draws it as one thing. Choose by the shape of the code, not by speed: \
            a plot takes one collection, with every point styled the same way from its properties; marks suit \
            points that need individual treatment, such as a different mark or modifier per element, or layering \
            with zIndex. VoiceOver reads both the same way, two hours at a time.
            """,
            snippets: model.snippets
        ) {
            MarksAndPlotsChart(drawing: model.drawing, orders: model.orders, locale: locale)
        } controls: {
            MarksAndPlotsControls(model: model, locale: locale)
        }
    }
}

/// The same scatter, from marks or from a plot, or a placeholder when there are no orders.
struct MarksAndPlotsChart: View {
    let drawing: MarksAndPlotsViewModel.Drawing
    let orders: [CafeOrder]
    let locale: Locale

    var body: some View {
        if orders.isEmpty {
            ContentUnavailableView(
                "No orders",
                systemImage: "cup.and.saucer",
                description: Text("Each order appears here as one point: when it was placed and how long it took.")
            )
        } else {
            Chart {
                switch drawing {
                case .marks:
                    // snippet:marks-and-plots-marks
                    // One mark per element: ForEach makes a PointMark for every order.
                    ForEach(orders) { order in
                        PointMark(
                            x: .value(MarksAndPlotsWording.timeOfDay, order.hour),
                            y: .value(MarksAndPlotsWording.wait, order.waitMinutes)
                        )
                        .symbolSize(MarksAndPlotsStyle.symbolArea)
                        .opacity(MarksAndPlotsStyle.opacity)
                    }
                // end
                case .plot:
                    // snippet:marks-and-plots-plot
                    // One plot for the whole collection: key paths in place of values.
                    PointPlot(
                        orders,
                        x: .value(MarksAndPlotsWording.timeOfDay, \.hour),
                        y: .value(MarksAndPlotsWording.wait, \.waitMinutes)
                    )
                    .symbolSize(MarksAndPlotsStyle.symbolArea)
                    .opacity(MarksAndPlotsStyle.opacity)
                    // end
                }
            }
            .timeOfDayAxis(locale: locale)
            // One wait axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartYScale(domain: MarksAndPlotsChartDescriptor.waitDomain(for: orders))
            .waitAxisTitle()
            // snippet:marks-and-plots-spoken
            // A plot's own elements carry no units, and its key-path labels are not read, so VoiceOver gets
            // a chart of labelled stretches in place of the drawn one, the same for marks and plot.
            .accessibilityRepresentation {
                TimeOfDaySpokenChart(
                    portions: TimeOfDayPortion.make(orders, hour: \.hour, wait: \.waitMinutes),
                    locale: locale
                )
                .accessibilityChartDescriptor(MarksAndPlotsChartDescriptor(orders: orders, locale: locale))
            }
            // end
            // The descriptor changes with the number of orders: a new identity, so the Audio Graph reads it again.
            .id(orders.count)
        }
    }
}

/// The two controls: how the chart is drawn, and how many orders it draws.
struct MarksAndPlotsControls: View {
    @Bindable var model: MarksAndPlotsViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Drawn with", selection: $model.drawing) {
                ForEach(MarksAndPlotsViewModel.Drawing.allCases) { drawing in
                    Text(drawing.title).tag(drawing)
                }
            }
            .disabled(model.isEmpty)
            .onChange(of: model.drawing) {
                announceMarksAndPlotsChange(model.drawingAnnouncement(locale: locale))
            }
            Text(model.drawingCaption(locale: locale))
                .font(.footnote)
                .foregroundStyle(.secondary)
            LabeledSlider(
                title: CafeWording.orders,
                value: $model.orderCount,
                range: Double(MarksAndPlotsViewModel.countRange.lowerBound) ... Double(MarksAndPlotsViewModel.countRange.upperBound),
                step: Double(MarksAndPlotsViewModel.countStep),
                valueText: model.countText(locale: locale),
                spokenValue: model.countSpokenValue(locale: locale)
            )
            Text(MarksAndPlotsViewModel.timingNote)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
@MainActor
func announceMarksAndPlotsChange(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

/// The styling both drawings share, so they draw the same chart.
private enum MarksAndPlotsStyle {
    /// Small points, so thousands of them show where orders crowd.
    static let symbolArea: CGFloat = 12
    static let opacity: Double = 0.4
}

#Preview("Marks and plots") {
    NavigationStack {
        if let screen = Catalog.screen(id: "vectorized-plots/marks-and-plots") {
            MarksAndPlotsScreen(screen: screen)
        }
    }
}

#Preview("No orders") {
    MarksAndPlotsChart(drawing: .plot, orders: [], locale: .current)
}
