import Accessibility
import Charts
import SwiftUI

/// "Scrolling": a horizontally scrolling chart of ten weeks, its visible domain, the bound scroll
/// position, and where scrolling comes to rest.
struct ChartScrollingScreen: View {
    let screen: CatalogScreen
    @State private var model: ChartScrollingViewModel
    /// The locale the screen's words are written in, read here and passed in.
    @Environment(\.locale) private var locale

    init(screen: CatalogScreen, days: [DailySales] = CafeData.tenWeeks) {
        self.screen = screen
        _model = State(initialValue: ChartScrollingViewModel(days: days))
    }

    var body: some View {
        // Read in the body, so a new scroll position redraws the headline and the elements.
        let summary = model.summary(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Cups sold each day, ten weeks",
            message: summary.headline,
            reservedMessage: summary.reservedHeadline,
            explanation: model.isSnapping ? ChartScrollingText.snapping : ChartScrollingText.free,
            snippets: model.snippets
        ) {
            ChartScrollingChart(model: model, summary: summary)
        } controls: {
            ChartScrollingControls(model: model, locale: locale, isDisabled: summary.hasNoSales)
        }
        .onChange(of: model.visibleLength) {
            model.clampPosition()
            // A new visible domain changes what the chart draws: say so, then the headline.
            AccessibilityNotification.Announcement(model.lengthAnnouncement(locale: locale)).post()
        }
    }
}

/// The explanation for each setting of the snapping switch, so it is true of what the chart does.
private enum ChartScrollingText {
    static let snapping = """
    chartScrollableAxes turns scrolling on, chartXVisibleDomain sets how much of the ten weeks is in view, \
    and chartScrollPosition binds the window's leading edge, which the headline reads. \
    chartScrollTargetBehavior with valueAligned makes a drag come to rest on a matching date; \
    majorAlignment asks for a different landing place for a swipe (a page on, or the 1st of a month), \
    and limitBehavior asks whether one gesture can travel far. \
    A scrolling chart ignores its chart descriptor, so the Audio Graph is given a non-scrolling copy of all ten weeks \
    through accessibilityRepresentation, with the descriptor inside.
    """
    static let free = """
    chartScrollableAxes turns scrolling on, chartXVisibleDomain sets how much of the ten weeks is in view, \
    and chartScrollPosition binds the window's leading edge, which the headline reads. \
    With no value-aligned behaviour, the chart comes to rest wherever the scroll stops, often partway through a day. \
    A scrolling chart ignores its chart descriptor, so the Audio Graph is given a non-scrolling copy of all ten weeks \
    through accessibilityRepresentation, with the descriptor inside.
    """
}

/// The scrolling chart, or a placeholder when nothing was sold.
struct ChartScrollingChart: View {
    @Bindable var model: ChartScrollingViewModel
    let summary: ChartScrollingSummary
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// The width the chart settled at. A scrolling chart laid out first at another width (the split view
    /// collapsing on iPhone) keeps its offset in points and opens on the wrong window, so it is rebuilt at
    /// its settled width (`interaction.md`, *Scrolling*).
    @State private var settledWidth: CGFloat = 0

    /// One label a week; every day when a week is in view, fewer as the text grows.
    private var daysPerLabel: Int {
        guard model.visibleLength == .oneWeek else { return 7 }
        if dynamicTypeSize >= .accessibility1 { return 7 }
        if dynamicTypeSize >= .xLarge { return 2 }
        return 1
    }

    var body: some View {
        if summary.hasNoSales {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Ten weeks of daily cups appear here, a few weeks at a time.")
            )
        } else if let domain = summary.domain {
            let behavior = ChartScrollingTargetBehavior(valueAligned: model.isSnapping ? model.valueAligned : nil)
            let calendar = ChartScrollingSummary.calendar
            // snippet:scrolling-chart
            Chart {
                ChartScrollingWeekBars(weeks: summary.weeks, calendar: calendar)
            }
            // The whole ten weeks; the visible domain is a window onto it.
            .chartXScale(domain: domain)
            .chartScrollableAxes(.horizontal)
            // How much of the axis is in view at once: on a date axis, in seconds.
            .chartXVisibleDomain(length: model.visibleLength.seconds)
            // The window's leading edge, not its centre. The chart writes it as it scrolls.
            .chartScrollPosition(x: $model.scrollPosition)
            .chartScrollTargetBehavior(behavior)
            // end
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: daysPerLabel, calendar: calendar)) {
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(
                        format: Date.FormatStyle(locale: summary.locale, calendar: calendar, timeZone: calendar.timeZone)
                            .month(.abbreviated).day()
                    )
                }
            }
            .chartYScale(domain: summary.cupsAxis)
            // snippet:scrolling-representation
            // A scrolling chart ignores a descriptor set on it: the Audio Graph gets the default ("Chart",
            // dates as numbers). Assistive technologies get this chart in its place: all ten weeks at once,
            // the same scales, and the descriptor inside, where it is kept.
            .accessibilityRepresentation {
                Chart {
                    ChartScrollingWeekBars(weeks: summary.weeks, calendar: calendar)
                }
                .chartXScale(domain: domain)
                .chartYScale(domain: summary.cupsAxis)
                .accessibilityChartDescriptor(ChartScrollingChartDescriptor(summary: summary))
            }
            // end
            .id(settledWidth)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { settledWidth = $0 }
        }
    }
}

/// The bars, one labelled `Plot` per week: ten elements instead of seventy single days.
struct ChartScrollingWeekBars: ChartContent {
    let weeks: [ChartScrollingWeek]
    let calendar: Calendar

    var body: some ChartContent {
        ForEach(weeks) { week in
            Plot {
                ForEach(week.days) { day in
                    BarMark(
                        x: .value(CafeWording.day, day.day, unit: .day, calendar: calendar),
                        y: .value(CafeWording.cups, day.cups)
                    )
                }
            }
            .accessibilityLabel(week.label)
            .accessibilityValue(week.value)
        }
    }
}

extension ChartScrollingViewModel {
    // snippet:scrolling-value-aligned
    /// Where scrolling rests: a drag on the next date that matches the components, a swipe on the
    /// major alignment, and the limit on how far one gesture travels.
    var valueAligned: ValueAlignedChartScrollTargetBehavior {
        let calendar = ChartScrollingSummary.calendar
        let major: MajorValueAlignment<Date>? = switch majorAlignment {
        case .none: nil
        case .page: .page
        case .month: .matching(DateComponents(calendar: calendar, timeZone: calendar.timeZone, day: 1))
        }
        let limit: ValueAlignedLimitBehavior = switch limitBehavior {
        case .automatic: .automatic
        case .always: .always
        case .never: .never
        }
        return .valueAligned(matching: restingPoint.components, majorAlignment: major, limitBehavior: limit)
    }
    // end
}

// snippet:scrolling-free
/// The behaviour the chart is given. With no value-aligned behaviour inside it, it leaves the target
/// where the scroll would stop anyway, so the chart comes to rest there, often partway through a day.
nonisolated struct ChartScrollingTargetBehavior: ChartScrollTargetBehavior {
    let valueAligned: ValueAlignedChartScrollTargetBehavior?

    func updateTarget(_ target: inout ScrollTarget, context: ChartScrollTargetBehaviorContext) {
        valueAligned?.updateTarget(&target, context: context)
    }
}

// end

/// The visible length, buttons that move the window without a gesture, and the snapping choices.
struct ChartScrollingControls: View {
    @Bindable var model: ChartScrollingViewModel
    let locale: Locale
    let isDisabled: Bool

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "Visible length", selection: $model.visibleLength) {
                ForEach(ChartScrollingLength.allCases) { length in
                    Text(length.title(locale: locale)).tag(length)
                }
            }
            ChartScrollingMoveButtons(model: model, locale: locale)
            Toggle("Snap where scrolling rests", isOn: $model.isSnapping)
            ChartScrollingAlignmentPickers(model: model)
                .disabled(!model.isSnapping)
        }
        .disabled(isDisabled)
    }
}

/// Earlier and Later: the window moves one visible length, for anyone who cannot drag the chart.
struct ChartScrollingMoveButtons: View {
    @Bindable var model: ChartScrollingViewModel
    let locale: Locale

    var body: some View {
        // Side by side while they fit; one above the other at the largest text sizes, so neither is cut short.
        ViewThatFits(in: .horizontal) {
            HStack {
                earlier
                Spacer()
                later
            }
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                earlier
                later
            }
        }
        .buttonStyle(.bordered)
    }

    private var earlier: some View {
        Button("Earlier", systemImage: "chevron.backward") {
            model.showEarlier()
            announce(earlier: true)
        }
        .disabled(!model.canShowEarlier)
    }

    private var later: some View {
        Button("Later", systemImage: "chevron.forward") {
            model.showLater()
            announce(earlier: false)
        }
        .labelStyle(ChartScrollingTrailingIconLabelStyle())
        .disabled(!model.canShowLater)
    }

    /// The days in view changed: say so, then the new headline.
    private func announce(earlier: Bool) {
        AccessibilityNotification.Announcement(model.moveAnnouncement(earlier: earlier, locale: locale)).post()
    }
}

/// A label with its icon after the title, for the Later button.
private struct ChartScrollingTrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Layout.tightSpacing) {
            configuration.title
            configuration.icon
        }
    }
}

/// Where a drag rests, where a swipe lands, and the limit on one gesture.
struct ChartScrollingAlignmentPickers: View {
    @Bindable var model: ChartScrollingViewModel

    var body: some View {
        LabeledSegmentedPicker(title: "A drag rests on", selection: $model.restingPoint) {
            ForEach(ChartScrollingRest.allCases) { Text($0.title).tag($0) }
        }
        LabeledSegmentedPicker(title: "A swipe lands on", selection: $model.majorAlignment) {
            ForEach(ChartScrollingMajorAlignment.allCases) { Text($0.title).tag($0) }
        }
        LabeledSegmentedPicker(title: "Limit one gesture", selection: $model.limitBehavior) {
            ForEach(ChartScrollingLimit.allCases) { Text($0.title).tag($0) }
        }
    }
}

#Preview("Scrolling") {
    NavigationStack {
        if let screen = Catalog.screen(id: "interaction/scrolling") {
            ChartScrollingScreen(screen: screen)
        }
    }
}

#Preview("No sales") {
    ChartScrollingChart(
        model: ChartScrollingViewModel(days: []),
        summary: ChartScrollingSummary(days: [], position: CafeData.firstDay, visibleDays: 14, locale: .current)
    )
}
