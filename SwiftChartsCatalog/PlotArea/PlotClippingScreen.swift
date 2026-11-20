import Accessibility
import Charts
import SwiftUI

/// "Clipping the plot area": marks beyond a scale's domain are drawn outside the plot until it is clipped.
struct PlotClippingScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = PlotClippingViewModel()
    /// Read here and passed in, so the headline, the elements and the Audio Graph write dates and
    /// numbers the way the chart's axis does.
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Daily cups at the \(CafeWording.harbour) café",
            message: viewModel.headline(locale: locale),
            explanation: """
            Narrowing a scale's domain does not remove the marks outside it: Swift Charts places them where \
            the scale would put them, past the plot area's edges, over the axis labels and beyond the chart's \
            frame. Clipping the plot area with chartPlotStyle cuts them off at its edge, while the axes and their \
            labels outside the plot stay as they are.
            """,
            snippets: viewModel.snippets
        ) {
            PlotClippingChart(viewModel: viewModel, locale: locale)
        } controls: {
            PlotClippingControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// Four weeks of daily cups as a line, with the x scale's domain set to some of them.
struct PlotClippingChart: View {
    let viewModel: PlotClippingViewModel
    let locale: Locale
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if let domain = viewModel.domain {
            let clipsPlotArea = viewModel.clipsPlotArea
            let isLargeText = dynamicTypeSize.isAccessibilitySize
            // snippet:clipping-the-plot-area-domain
            Chart(viewModel.days) { day in
                Plot {
                    LineMark(x: .value(CafeWording.day, day.day), y: .value(CafeWording.cups, day.cups))
                        .symbol(.circle)
                }
                .accessibilityLabel(viewModel.elementLabel(for: day, locale: locale))
                .accessibilityValue(viewModel.elementValue(for: day, locale: locale))
                // A day cut off by the clip is not drawn, so it is not read either.
                .accessibilityHidden(!viewModel.isDrawn(day))
            }
            // Narrower than the data: the days outside it still get marks, placed beyond the plot.
            .chartXScale(domain: domain)
            // end
            // One value axis, the same in the descriptor, so the Audio Graph's top is the drawn one.
            .chartYScale(domain: viewModel.valueDomain)
            .chartXAxis {
                AxisMarks(values: viewModel.axisDays(isLargeText: isLargeText)) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel(format: PlotClippingDates.axisFormat(locale: locale, isLargeText: isLargeText))
                }
            }
            // snippet:clipping-the-plot-area-clip
            // Marks are not clipped to the plot area. Clip it, and the marks outside the domain
            // are cut off at its edge; the axes outside the plot are untouched.
            .chartPlotStyle { plotArea in
                if clipsPlotArea {
                    plotArea.clipped()
                } else {
                    plotArea
                }
            }
            // end
            .accessibilityChartDescriptor(viewModel.descriptor(locale: locale))
            // The element text changes with the domain and the clip while the days' ids do not.
            .id(viewModel.chartIdentity)
        } else {
            ContentUnavailableView(
                "No sales yet",
                systemImage: "cup.and.saucer",
                description: Text("Daily cups appear here as a line, one point a day.")
            )
        }
    }
}

/// The domain picker, the clip as a mistake toggle (a plain one when every day is inside the domain), and a line saying what the clip is doing.
struct PlotClippingControls: View {
    @Bindable var viewModel: PlotClippingViewModel
    let locale: Locale
    private static let toggleTitle = "Leave the plot area unclipped"

    var body: some View {
        ControlsSection {
            LabeledSegmentedPicker(title: "X scale domain", selection: $viewModel.range) {
                ForEach(PlotClippingRange.allCases) { range in
                    Text(range.title(locale: locale)).tag(range)
                }
            }
            if viewModel.canShowMistake {
                MistakeToggle(title: Self.toggleTitle, isShowingMistake: $viewModel.isShowingMistake)
            } else {
                // Every day is inside the domain, so an unclipped plot is no mistake here.
                Toggle(Self.toggleTitle, isOn: $viewModel.isShowingMistake)
            }
            Text(viewModel.plotNote(locale: locale))
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        // With no data the placeholder shows, and there is nothing for these to change.
        .disabled(!viewModel.hasData)
        .onChange(of: viewModel.range) {
            PlotClippingAnnouncer.announce(viewModel.rangeAnnouncement(locale: locale))
        }
        .onChange(of: viewModel.isShowingMistake) {
            PlotClippingAnnouncer.announce(viewModel.clippingAnnouncement(locale: locale))
        }
    }
}

/// Says aloud that the chart changed, for people who cannot see it happen.
enum PlotClippingAnnouncer {
    static func announce(_ message: String) {
        // iOS 17.0+; the app's deployment target is iOS 18.0, so no check is needed.
        AccessibilityNotification.Announcement(message).post()
    }
}

#Preview("Clipped") {
    NavigationStack {
        if let screen = Catalog.screen(id: "plot-area/clipping-the-plot-area") {
            PlotClippingScreen(screen: screen)
        }
    }
}

#Preview("Unclipped") {
    let viewModel = PlotClippingViewModel()
    viewModel.isShowingMistake = true
    return PlotClippingChart(viewModel: viewModel, locale: .current)
        .frame(height: Layout.chartHeightCompact)
        .padding()
}

#Preview("No sales") {
    PlotClippingChart(viewModel: PlotClippingViewModel(days: []), locale: .current)
}
