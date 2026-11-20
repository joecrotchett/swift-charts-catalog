import Accessibility
@testable import SwiftChartsCatalog
import Testing

struct ReleaseTimelineTests {
    private let english = Locale(identifier: "en_US")

    private func screen(_ id: String, since: String) -> CatalogScreen {
        CatalogScreen(id: id, title: id, summary: "", apiSince: since, skillReferences: [])
    }

    @Test("Given the catalog, when it is grouped by release, then every release row links only to screens that exist in the catalog")
    func everyLinkExists() {
        let summary = ReleaseTimelineSummary(screens: Catalog.allScreens, locale: english)

        for group in summary.groups {
            for linked in group.screens {
                #expect(Catalog.screen(id: linked.id) != nil, "\(group.release.rawValue) links to \(linked.id)")
            }
        }
    }

    @Test("Given the catalog, when it is grouped by release, then every screen appears under exactly one release, the one its since names")
    func everyScreenOnce() {
        let summary = ReleaseTimelineSummary(screens: Catalog.allScreens, locale: english)
        let linkedIDs = summary.groups.flatMap { $0.screens.map(\.id) }

        #expect(summary.unmatchedScreens.isEmpty)
        #expect(linkedIDs.count == Catalog.allScreens.count)
        #expect(Set(linkedIDs) == Set(Catalog.allScreens.map(\.id)))
        for group in summary.groups {
            #expect(group.screens.allSatisfy { $0.apiSince == group.release.version })
        }
    }

    @Test("Given the catalog, when it is grouped, then every release that some screen needs has at least one link")
    func neededReleasesHaveLinks() {
        let summary = ReleaseTimelineSummary(screens: Catalog.allScreens, locale: english)
        let needed = Set(Catalog.allScreens.compactMap { ReleaseTimelineRelease(version: $0.apiSince) })

        for group in summary.groups where needed.contains(group.release) {
            #expect(!group.screens.isEmpty)
        }
    }

    @Test("Given the releases, when they are listed, then they come in release order with their versions")
    func releaseOrder() {
        #expect(ReleaseTimelineRelease.allCases.map(\.version) == ["16.0", "16.4", "17.0", "18.0", "26.0", "27.0"])
        #expect(ReleaseTimelineRelease(version: "17.0") == .iOS17)
        #expect(ReleaseTimelineRelease(version: "19.0") == nil)
    }

    @Test("Given screens across releases, when the headline is written, then it names the busiest release and only the count drawn beside its bar")
    func headlineNamesBusiest() {
        let screens = [
            screen("a", since: "16.0"), screen("b", since: "16.0"), screen("c", since: "16.0"),
            screen("d", since: "17.0"), screen("e", since: "26.0"),
        ]
        let summary = ReleaseTimelineSummary(screens: screens, locale: english)

        #expect(summary.headline == "iOS 16.0 has the most: 3 screens.")
        #expect(summary.counts.map(\.screenCount) == [3, 0, 1, 0, 1, 0])
    }

    @Test("Given two releases tied for the most screens, when the headline is written, then it names both")
    func tieNamesBoth() {
        let screens = [screen("a", since: "16.0"), screen("b", since: "18.0"), screen("c", since: "17.0"), screen("d", since: "18.0"), screen("e", since: "16.0")]
        let summary = ReleaseTimelineSummary(screens: screens, locale: english)

        #expect(summary.headline == "iOS 16.0 and iOS 18.0 tie for the most: 2 screens each.")
    }

    @Test("Given no screens, when the chart's words are written, then they say the catalog is empty")
    func emptyCatalog() {
        let summary = ReleaseTimelineSummary(screens: [], locale: english)

        #expect(summary.total == 0)
        #expect(summary.headline == "The catalog has no screens yet.")
        #expect(summary.audioGraphSummary == "The catalog has no screens yet.")
        #expect(summary.busiestReleases.isEmpty)
    }

    @Test("Given the real catalog, when the headline is written, then its figure is the longest bar's count")
    func headlineMatchesCatalog() {
        let summary = ReleaseTimelineSummary(screens: Catalog.allScreens, locale: english)
        let most = summary.counts.map(\.screenCount).max() ?? 0

        #expect(summary.headline.hasSuffix(": \(most) screens."))
        #expect(!summary.headline.contains("\(Catalog.allScreens.count)"))
    }

    @Test("Given counts up to 87, when the axis is set, then it ends at the next step of 20 past the largest")
    func axisTopLeavesRoom() {
        let counts = Array(repeating: screen("x", since: "16.0"), count: 87)
        #expect(ReleaseTimelineSummary(screens: counts, locale: english).axisTop == 100)
        let eighty = Array(repeating: screen("x", since: "16.0"), count: 80)
        #expect(ReleaseTimelineSummary(screens: eighty, locale: english).axisTop == 100)
    }

    @Test("Given one screen, when counts are written, then the noun agrees in number")
    func countsAgree() {
        #expect(ReleaseTimelineWording.screens(1, locale: english) == "1 screen")
        #expect(ReleaseTimelineWording.screens(21, locale: english) == "21 screens")
    }

    @Test("Given screens across releases, when the Audio Graph summary is written, then it gives the totals and the extremes in actual values")
    func audioGraphSummary() {
        let screens = [screen("a", since: "16.0"), screen("b", since: "16.0"), screen("c", since: "16.4")]
        let summary = ReleaseTimelineSummary(screens: screens, locale: english)

        #expect(summary.audioGraphSummary == "6 releases, 3 screens in total. Most: iOS 16.0, 2 screens. "
            + "Fewest: iOS 17.0, iOS 18.0, iOS 26.0, and iOS 27.0, 0 screens.")
    }

    @Test("Given the catalog, when the descriptor is made, then it has releases in order and screens with their unit")
    func descriptor() throws {
        let summary = ReleaseTimelineSummary(screens: Catalog.allScreens, locale: english)
        let descriptor = ReleaseTimelineChartDescriptor(
            counts: summary.counts, summary: summary.audioGraphSummary, axisTop: summary.axisTop, locale: english
        ).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Catalog screens by the Swift Charts release they need")
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(xAxis.categoryOrder == ReleaseTimelineRelease.allCases.map(\.rawValue))
        #expect(yAxis.range == 0 ... Double(summary.axisTop))
        #expect(yAxis.valueDescriptionProvider(1) == "1 screen")
        #expect(yAxis.valueDescriptionProvider(21) == "21 screens")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == ReleaseTimelineRelease.allCases.count)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given the built app, when its snippets are read, then the screen's three regions exist")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for name in ["what-each-release-added-grouping", "what-each-release-added-chart", "what-each-release-added-link"] {
            #expect(store[name] != nil, "\(name)")
        }
    }

    @Test("Given the screen's registration, when its snippets are read, then every one it lists exists")
    func registeredSnippetsExist() throws {
        let store = try SnippetStore()
        let snippets = try #require(ScreenRegistry.entries["availability/what-each-release-added"]?.snippets)

        #expect(snippets.count == 3)
        for snippet in snippets {
            #expect(store[snippet.name] != nil, "\(snippet.name)")
        }
    }
}
