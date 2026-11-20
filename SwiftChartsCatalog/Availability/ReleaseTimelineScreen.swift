import Accessibility
import Charts
import SwiftUI

/// "What each release added": the Swift Charts releases in order, how many of the catalog's screens need
/// each one, and a link to every one of those screens.
struct ReleaseTimelineScreen: View {
    let screen: CatalogScreen
    /// The screens counted. The whole catalog, so the counts and the links cannot drift from it.
    var screens = Catalog.allScreens
    /// Read here and passed in, so the headline, the elements and the Audio Graph write numbers alike.
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = ReleaseTimelineSummary(screens: screens, locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: "Catalog screens by the release they need",
            message: summary.headline,
            explanation: """
            Every Swift Charts release builds on the one before: iOS 16 brought the framework, 17 added pies, \
            selection and scrolling, 18 vectorized plots, 26 3D charts, and 27 no new chart API. Each screen in \
            this catalog records the release its API needs, and the bars are counted from that record. This app \
            targets iOS 18, so a screen that needs iOS 26 checks for it and shows a fallback on older systems.
            """
        ) {
            ReleaseTimelineChart(summary: summary, locale: locale)
        } controls: {
            ReleaseTimelineReleaseList(groups: summary.groups, locale: locale)
        }
    }
}

// MARK: - Releases

/// The Swift Charts releases, as the skill's availability overview lists them, in order.
/// A fixed set of categories, so it is an enum that plots directly.
nonisolated enum ReleaseTimelineRelease: String, CaseIterable, Identifiable, Plottable {
    case iOS16 = "iOS 16.0"
    case iOS16Point4 = "iOS 16.4"
    case iOS17 = "iOS 17.0"
    case iOS18 = "iOS 18.0"
    case iOS26 = "iOS 26.0"
    case iOS27 = "iOS 27.0"

    var id: Self {
        self
    }

    /// The version as a catalog screen records it in `apiSince`, such as "16.4".
    var version: String {
        String(rawValue.dropFirst("iOS ".count))
    }

    /// The release a catalog screen's `apiSince` names, or `nil` when it names none of them.
    init?(version: String) {
        guard let release = Self.allCases.first(where: { $0.version == version }) else { return nil }
        self = release
    }

    /// What the release added, from the skill's table of releases.
    var additions: String {
        switch self {
        case .iOS16:
            "The framework: Chart, the six marks (area, bar, line, point, rectangle, rule), scales, axes, legends, "
                + "annotations, chartOverlay and chartBackground with ChartProxy, and binning."
        case .iOS16Point4:
            "Blur and shadow on marks; power, square-root and symmetric-log scales; ChartProxy lookups for domains "
                + "and resolved styles."
        case .iOS17:
            "SectorMark for pies and donuts; selection; scrolling; chartGesture; annotation overflow resolution; "
                + "zIndex; compositingLayer; axis styles."
        case .iOS18:
            "Vectorized plots, one plot for a whole collection; function plots on LinePlot and AreaPlot; "
                + "PlottableProjection; MarkDimensions."
        case .iOS26:
            "3D charts: Chart3D, SurfacePlot, z initializers on PointMark, RectangleMark and RuleMark, chart3DPose, "
                + "and a Z axis, scale and selection. None of it exists on tvOS or watchOS."
        case .iOS27:
            "No new chart API. SwiftUI's EmptyView and TupleContent conform to ChartContent."
        }
    }
}

/// One release and the catalog screens whose API it introduced.
struct ReleaseTimelineGroup: Identifiable {
    let release: ReleaseTimelineRelease
    let screens: [CatalogScreen]

    var id: ReleaseTimelineRelease {
        release
    }
}

/// One bar: a release and how many screens need it. Plain values, so the descriptor can hold them off the main actor.
nonisolated struct ReleaseTimelineCount: Identifiable, Equatable {
    let release: ReleaseTimelineRelease
    let screenCount: Int

    var id: ReleaseTimelineRelease {
        release
    }
}

/// Counts that agree in number, each in the locale passed.
nonisolated enum ReleaseTimelineWording {
    /// "1 screen", "87 screens". `CafeWording` has no noun for screens, so it lives here.
    static func screens(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) screen](inflect: true)", locale: locale).characters)
    }

    /// "6 releases".
    static func releases(_ count: Int, locale: Locale) -> String {
        String(AttributedString(localized: "^[\(count) release](inflect: true)", locale: locale).characters)
    }
}

// MARK: - Summary

/// The catalog grouped by release, and what the chart says in words.
struct ReleaseTimelineSummary {
    let groups: [ReleaseTimelineGroup]
    /// Screens whose `apiSince` names no release in the list. Empty for a correct catalog.
    let unmatchedScreens: [CatalogScreen]
    let locale: Locale

    init(screens: [CatalogScreen], locale: Locale) {
        // snippet:what-each-release-added-grouping
        // Each screen records the release its API needs: group the catalog by it, every release kept in order.
        groups = ReleaseTimelineRelease.allCases.map { release in
            ReleaseTimelineGroup(release: release, screens: screens.filter { $0.apiSince == release.version })
        }
        // end
        unmatchedScreens = screens.filter { ReleaseTimelineRelease(version: $0.apiSince) == nil }
        self.locale = locale
    }

    var counts: [ReleaseTimelineCount] {
        groups.map { ReleaseTimelineCount(release: $0.release, screenCount: $0.screens.count) }
    }

    var total: Int {
        groups.map(\.screens.count).reduce(0, +)
    }

    /// The releases that the most screens need, in release order. More than one on a tie; none with no screens.
    var busiestReleases: [ReleaseTimelineCount] {
        guard let most = counts.map(\.screenCount).max(), most > 0 else { return [] }
        return counts.filter { $0.screenCount == most }
    }

    /// The releases that the fewest screens need, in release order. None with no screens.
    var quietestReleases: [ReleaseTimelineCount] {
        guard let fewest = counts.map(\.screenCount).min(), total > 0 else { return [] }
        return counts.filter { $0.screenCount == fewest }
    }

    /// The end of the screens axis: past the largest count by at least one step of 20, so the count written
    /// after the longest bar has room. Shared by the chart and its descriptor.
    var axisTop: Int {
        let step = 20
        let most = counts.map(\.screenCount).max() ?? 0
        return (most / step + 1) * step
    }

    /// The chart's message, carrying only the figure written beside the longest bar.
    var headline: String {
        guard let most = busiestReleases.first?.screenCount else { return "The catalog has no screens yet." }
        let count = ReleaseTimelineWording.screens(most, locale: locale)
        if busiestReleases.count == 1 {
            return "\(names(busiestReleases)) has the most: \(count)."
        }
        return "\(names(busiestReleases)) tie for the most: \(count) each."
    }

    /// Actual values only: how many releases and screens, and the largest and smallest counts.
    var audioGraphSummary: String {
        guard let most = busiestReleases.first?.screenCount, let fewest = quietestReleases.first?.screenCount else {
            return "The catalog has no screens yet."
        }
        return "\(ReleaseTimelineWording.releases(counts.count, locale: locale)), "
            + "\(ReleaseTimelineWording.screens(total, locale: locale)) in total. "
            + "Most: \(names(busiestReleases)), \(ReleaseTimelineWording.screens(most, locale: locale)). "
            + "Fewest: \(names(quietestReleases)), \(ReleaseTimelineWording.screens(fewest, locale: locale))."
    }

    private func names(_ counts: [ReleaseTimelineCount]) -> String {
        CafeWording.list(counts.map(\.release.rawValue))
    }
}

// MARK: - Chart

/// One horizontal bar per release, in release order, with its count written after it.
struct ReleaseTimelineChart: View {
    let summary: ReleaseTimelineSummary
    let locale: Locale
    /// Room kept after the end of the screens axis for the count written after the longest bar. It grows
    /// with the text, capped so the bars keep most of the plot at the largest sizes.
    @ScaledMetric(relativeTo: .caption) private var countRoom = ReleaseTimelineStyle.countRoom

    private var cappedCountRoom: CGFloat {
        min(countRoom, ReleaseTimelineStyle.maximumCountRoom)
    }

    var body: some View {
        if summary.total == 0 {
            ContentUnavailableView(
                "No screens yet",
                systemImage: "calendar.badge.clock",
                description: Text("Each release appears here with the number of screens that need it.")
            )
        } else {
            // snippet:what-each-release-added-chart
            Chart(summary.counts) { item in
                // The release and its count on a Plot around the bar: VoiceOver reads "iOS 17.0, 21 screens".
                Plot {
                    BarMark(
                        x: .value("Screens", item.screenCount),
                        y: .value("Release", item.release)
                    )
                    // The count is written after each bar; an annotation is not read, so the Plot says it too.
                    .annotation(position: .trailing, overflowResolution: .init(x: .fit(to: .plot))) {
                        Text(item.screenCount.formatted(.number.locale(locale)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityLabel(item.release.rawValue)
                .accessibilityValue(ReleaseTimelineWording.screens(item.screenCount, locale: locale))
            }
            // One explicit domain, shared with the descriptor, and room after it for the longest bar's count.
            .chartXScale(domain: 0 ... summary.axisTop, range: .plotDimension(endPadding: cappedCountRoom))
            .accessibilityChartDescriptor(ReleaseTimelineChartDescriptor(
                counts: summary.counts, summary: summary.audioGraphSummary, axisTop: summary.axisTop, locale: locale
            ))
            // end
        }
    }
}

/// Constants that belong to this chart's count labels.
private enum ReleaseTimelineStyle {
    /// Points kept after the axis at the default text size: about three caption digits.
    static let countRoom: CGFloat = 24
    static let maximumCountRoom: CGFloat = 64
}

/// The chart for the Audio Graph: releases on the category axis, screens with their unit on the value axis.
/// Not tied to the main actor: the accessibility system calls its value description when it chooses.
nonisolated struct ReleaseTimelineChartDescriptor: AXChartDescriptorRepresentable {
    let counts: [ReleaseTimelineCount]
    let summary: String
    let axisTop: Int
    let locale: Locale

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = locale
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Release",
            categoryOrder: counts.map(\.release.rawValue)
        )
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Screens",
            range: 0 ... Double(axisTop),
            gridlinePositions: []
        ) { value in
            CafeWording.count(value, locale: locale, as: ReleaseTimelineWording.screens(_:locale:))
        }
        let series = AXDataSeriesDescriptor(
            name: "Catalog screens",
            isContinuous: false,
            dataPoints: counts.map { AXDataPoint(x: $0.release.rawValue, y: Double($0.screenCount)) }
        )
        return AXChartDescriptor(
            title: "Catalog screens by the Swift Charts release they need",
            summary: summary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}

// MARK: - Release list

/// Every release with what it added and a link to each screen that needs it.
struct ReleaseTimelineReleaseList: View {
    let groups: [ReleaseTimelineGroup]
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text("Releases")
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            ForEach(groups) { group in
                ReleaseTimelineReleaseRow(group: group, locale: locale)
            }
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// One release: its name and count, opening to what it added and its screens.
struct ReleaseTimelineReleaseRow: View {
    let group: ReleaseTimelineGroup
    let locale: Locale

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                Text(group.release.additions)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if group.screens.isEmpty {
                    Text("No screen in the catalog needs this release.")
                        .font(.subheadline)
                }
                ForEach(group.screens) { screen in
                    ReleaseTimelineScreenLink(screen: screen)
                }
            }
            .padding(.top, Layout.tightSpacing)
        } label: {
            HStack {
                Text(group.release.rawValue)
                    .font(.headline)
                Spacer()
                Text(ReleaseTimelineWording.screens(group.screens.count, locale: locale))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// A link to one screen, or its title marked planned while the screen is not built.
struct ReleaseTimelineScreenLink: View {
    let screen: CatalogScreen

    var body: some View {
        // snippet:what-each-release-added-link
        NavigationLink {
            ScreenDestination(screen: screen)
        } label: {
            Text(screen.title)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        // end
        .disabled(!screen.isBuilt)
        .overlay(alignment: .trailing) {
            if !screen.isBuilt {
                Text("Planned")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityHint(screen.isBuilt ? "" : "Not built yet")
    }
}

#Preview("Catalog") {
    NavigationStack {
        if let screen = Catalog.screen(id: "availability/what-each-release-added") {
            ReleaseTimelineScreen(screen: screen)
        }
    }
}

#Preview("No screens") {
    ReleaseTimelineChart(summary: ReleaseTimelineSummary(screens: [], locale: .current), locale: .current)
}
