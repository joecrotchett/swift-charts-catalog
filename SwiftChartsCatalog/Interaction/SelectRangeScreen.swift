import Accessibility
import Charts
import SwiftUI
import UIKit

/// "Select a range": `chartXSelection(range:)` drawn as two rules under one annotation, beside the
/// iOS 16 technique of a drag gesture in an overlay drawn as a rectangle mark.
struct SelectRangeScreen: View {
    let screen: CatalogScreen
    @State private var model = SelectRangeViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day, \(CafeWording.harbour) café",
            message: model.headline(locale: locale),
            reservedMessage: model.reservedHeadline(locale: locale),
            explanation: """
            chartXSelection(range:) reports a range of the x axis with two fingers on the plot; the chart draws \
            it as two rules grouped in a Plot, so one annotation spans them. By hand is the iOS 16 technique, a \
            gesture in chartOverlay: touch and hold, then drag; it converts where the press was held and where \
            the finger is through the chart proxy, and a RectangleMark shades the days between. On iOS 17 and \
            later, a gesture of your own drives the chart's selection instead, through chartGesture and the \
            proxy's selectXRange(from:to:), so one binding holds the range. Both snap the range to whole days \
            before it is drawn or totalled.
            """,
            snippets: model.snippets
        ) {
            SelectRangeChart(model: model, locale: locale)
        } controls: {
            SelectRangeControls(model: model)
        }
        .onChange(of: model.technique) {
            if let message = model.techniqueAnnouncement(locale: locale) {
                AccessibilityNotification.Announcement(message).post()
            }
        }
    }
}

/// The picker that chooses the technique, disabled while the placeholder replaces the chart, and, by hand,
/// the button that clears the range, which stays after the finger lifts.
struct SelectRangeControls: View {
    @Bindable var model: SelectRangeViewModel

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Selection", selection: $model.technique) {
                ForEach(SelectRangeTechnique.allCases) { technique in
                    Text(technique.rawValue).tag(technique)
                }
            }
            .disabled(!model.hasData)
            if model.technique == .byHand {
                Button("Clear range") {
                    model.clearSelection()
                }
                .disabled(!model.canClearRange)
            }
        }
    }
}

/// Sizes that belong to this chart's marks and its selection label.
private enum SelectRangeMetrics {
    /// How far the rules reach above the plot to meet the label.
    static let ruleReach: CGFloat = 10
    static let labelPadding: CGFloat = 6
    /// The same corner and background as Select a value's popover, which draws the same data.
    static let labelCornerRadius: CGFloat = 6
    /// Room kept above the plot for the label at the default text size; it scales with the text.
    static let labelRoom: CGFloat = 62
    static let ruleOpacity = 0.4
    static let bandOpacity = 0.2
    static let labelBackgroundOpacity = 0.15
    /// How long a finger must rest before a drag by hand selects, so a swipe still scrolls the page.
    static let holdBeforeDrag = 0.25
}

/// The line of daily cups, the selection drawn by the technique in use, or a placeholder with no data.
struct SelectRangeChart: View {
    let model: SelectRangeViewModel
    let locale: Locale
    /// The space above the plot for the label, which draws above it with vertical overflow disabled.
    @ScaledMetric(relativeTo: .callout) private var labelRoom = SelectRangeMetrics.labelRoom
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if !model.hasData {
            ContentUnavailableView(
                "No sales to show",
                systemImage: "cup.and.saucer",
                description: Text("Daily cups appear here as a line, ready to select a range of days.")
            )
        } else {
            Chart {
                ForEach(model.days) { day in
                    // One element per day, labelled with the date written out and the cups with their unit.
                    Plot {
                        LineMark(
                            x: .value(CafeWording.day, day.day),
                            y: .value(CafeWording.cups, day.cups)
                        )
                        .symbol(.circle)
                    }
                    .accessibilityLabel(model.elementLabel(for: day, locale: locale))
                    .accessibilityValue(CafeWording.cups(day.cups, locale: locale))
                }

                if let selection = model.selection,
                   let dates = model.rangeText(locale: locale, compact: dynamicTypeSize.isAccessibilitySize),
                   let total = model.totalText(locale: locale)
                {
                    if model.technique == .builtIn {
                        // snippet:select-a-range-built-in-marks
                        // Two rules in one Plot, so one annotation spans them both.
                        Plot {
                            RuleMark(x: .value("Range start", selection.firstDay))
                            RuleMark(x: .value("Range end", selection.lastDay))
                        }
                        .foregroundStyle(Color.gray.opacity(SelectRangeMetrics.ruleOpacity))
                        // The indicator repeats what the day elements already say.
                        .accessibilityHidden(true)
                        .offset(yStart: -SelectRangeMetrics.ruleReach)
                        .zIndex(-1)
                        .annotation(
                            position: .top, spacing: 0,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) { context in
                            // At least as wide as the distance between the rules.
                            SelectRangeLabel(dates: dates, total: total)
                                .frame(minWidth: max(context.targetSize.width, 0), alignment: .leading)
                                .fixedSize()
                        }
                        // end
                    } else if let band = model.band {
                        // snippet:select-a-range-by-hand-mark
                        // The selection is a mark, so it stays aligned with the data.
                        RectangleMark(
                            xStart: .value("Selection start", band.lowerBound),
                            xEnd: .value("Selection end", band.upperBound)
                        )
                        .foregroundStyle(Color.gray.opacity(SelectRangeMetrics.bandOpacity))
                        .accessibilityHidden(true)
                        .zIndex(-1)
                        .annotation(
                            position: .top, spacing: 0,
                            overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                        ) {
                            SelectRangeLabel(dates: dates, total: total)
                                .fixedSize()
                        }
                        // end
                    }
                }
            }
            // One value axis from zero, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartYScale(domain: SelectRangeChartDescriptor.valueDomain(for: model.days))
            .chartXAxis {
                // Weekly labels at midnight in the data's calendar; the line has no unit, so its
                // points fall on these grid lines.
                AxisMarks(
                    format: Date.FormatStyle(locale: locale, calendar: model.calendar, timeZone: model.calendar.timeZone)
                        .month().day(),
                    // Fortnightly from accessibility3 up, where weekly labels truncate to "Mar…".
                    values: .stride(
                        by: .day, count: dynamicTypeSize >= .accessibility3 ? 14 : 7, calendar: model.calendar
                    )
                )
            }
            // snippet:select-a-range-built-in-modifier
            // The modifier only reports the range; the marks above draw it.
            .chartXSelection(range: Binding(
                get: { model.rawRange },
                set: { model.builtInRangeChanged($0) }
            ))
            // end
            // snippet:select-a-range-by-hand-gesture
            .chartOverlay { proxy in
                GeometryReader { geometry in
                    Rectangle().fill(.clear).contentShape(Rectangle())
                        // A held press first, so a swipe that starts on the plot still scrolls the page.
                        .gesture(SelectRangeHoldThenDrag(minimumDuration: SelectRangeMetrics.holdBeforeDrag) { start, current in
                            guard let plotFrame = proxy.plotFrame else { return }
                            let plot = geometry[plotFrame]
                            // Positions are relative to the plot area: subtract its origin.
                            let startX = start.x - plot.minX
                            // A drag that starts outside the plot selects nothing.
                            guard (0 ... plot.width).contains(startX) else { return }
                            // Past the plot's edge, the range stops at the edge.
                            let currentX = min(max(current.x - plot.minX, 0), plot.width)
                            if let start: Date = proxy.value(atX: startX),
                               let current: Date = proxy.value(atX: currentX)
                            {
                                model.dragChanged(from: start, to: current)
                            }
                        })
                        // Only the by-hand technique takes touches here; the built-in one needs them.
                        .allowsHitTesting(model.technique == .byHand)
                        .accessibilityHidden(true)
                }
            }
            // end
            .padding(.top, labelRoom)
            .accessibilityChartDescriptor(
                SelectRangeChartDescriptor(days: model.days, calendar: model.calendar, locale: locale)
            )
        }
    }
}

// UIKit's recognizer rather than SwiftUI's gestures: a `LongPressGesture` sequenced before
// `DragGesture(minimumDistance: 0)` was pressed on the simulator attached with `gesture(_:)` and with
// `simultaneousGesture(_:)`, and both kept a swipe on the plot from scrolling the page.

// snippet:select-a-range-hold-then-drag
/// A press held for `minimumDuration`, then followed as the finger moves. The long-press recognizer
/// fails if the finger moves before the press is held, so a swipe that starts on the plot scrolls the page.
struct SelectRangeHoldThenDrag: UIGestureRecognizerRepresentable {
    let minimumDuration: TimeInterval
    /// Where the press was held and where the finger is now, in the view's own coordinates.
    let onChanged: (_ start: CGPoint, _ current: CGPoint) -> Void

    final class Coordinator {
        var start: CGPoint?
    }

    func makeCoordinator(converter _: CoordinateSpaceConverter) -> Coordinator {
        Coordinator()
    }

    func makeUIGestureRecognizer(context _: Context) -> UILongPressGestureRecognizer {
        let recognizer = UILongPressGestureRecognizer()
        recognizer.minimumPressDuration = minimumDuration
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UILongPressGestureRecognizer, context: Context) {
        let location = context.converter.localLocation
        switch recognizer.state {
        case .began:
            context.coordinator.start = location
            onChanged(location, location)
        case .changed:
            if let start = context.coordinator.start { onChanged(start, location) }
        default:
            context.coordinator.start = nil
        }
    }
}

// end

/// The label over the selection: the days, then their total. Both lines are also in the headline,
/// which VoiceOver reads, since an annotation's view is not an accessibility element.
struct SelectRangeLabel: View {
    let dates: String
    let total: String

    var body: some View {
        VStack(alignment: .leading) {
            Text(dates)
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(total)
                .font(.headline)
        }
        .padding(SelectRangeMetrics.labelPadding)
        .background(
            Color.gray.opacity(SelectRangeMetrics.labelBackgroundOpacity),
            in: .rect(cornerRadius: SelectRangeMetrics.labelCornerRadius)
        )
    }
}

#Preview("Select a range") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/select-a-range") {
            SelectRangeScreen(screen: screen)
        }
    }
}

#Preview("A week selected") {
    let model = SelectRangeViewModel()
    model.builtInRangeChanged(CafeData.day(2) ... CafeData.day(8))
    return SelectRangeChart(model: model, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No data") {
    SelectRangeChart(model: SelectRangeViewModel(days: []), locale: .current)
}
