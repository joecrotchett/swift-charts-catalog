import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LinkedChartsTests {
    private let locale = Locale(identifier: "en_US")

    /// A time of day inside a day of the data, as `chartXSelection` reports it.
    private func position(onDay offset: Int, hour: Int = 15) -> Date {
        CafeData.calendar.date(byAdding: .hour, value: hour, to: CafeData.day(offset)) ?? CafeData.day(offset)
    }

    // MARK: Data

    @Test("Given the sample data, when the screen's cafés are made, then Harbour has 28 days and Station starts a week later")
    func stationStartsLater() {
        #expect(LinkedChartsData.harbour.days.count == 28)
        #expect(LinkedChartsData.station.days.count == 21)
        #expect(LinkedChartsData.station.days.first?.day == CafeData.day(7))
        #expect(LinkedChartsData.station.days.last?.day == CafeData.day(27))
    }

    // MARK: Selection

    @Test("Given no finger down, when the screen appears, then neither chart draws a band")
    func noSelectionNoBand() {
        let viewModel = LinkedChartsViewModel()

        #expect(viewModel.selectedDay == nil)
        #expect(viewModel.bandDay(for: viewModel.top) == nil)
        #expect(viewModel.bandDay(for: viewModel.bottom) == nil)
    }

    @Test("Given one selection, when it falls on a day both cafés recorded, then both charts draw their band on that day")
    func oneSelectionDrivesBothCharts() {
        let viewModel = LinkedChartsViewModel()

        viewModel.rawSelection = position(onDay: 24)

        #expect(viewModel.selectedDay == CafeData.day(24))
        #expect(viewModel.bandDay(for: viewModel.top) == CafeData.day(24))
        #expect(viewModel.bandDay(for: viewModel.bottom) == CafeData.day(24))
    }

    @Test("Given a selection on a day only Harbour recorded, when the bands are worked out, then only Harbour's chart draws one")
    func dayWithOneRecord() {
        let viewModel = LinkedChartsViewModel()

        viewModel.rawSelection = position(onDay: 2)

        #expect(viewModel.bandDay(for: viewModel.top) == CafeData.day(2))
        #expect(viewModel.bandDay(for: viewModel.bottom) == nil)
    }

    @Test("Given a raw position late in a day, when it is snapped, then it selects that day and not the next")
    func snapsToTheDay() {
        let viewModel = LinkedChartsViewModel()

        viewModel.rawSelection = position(onDay: 10, hour: 23)

        #expect(viewModel.selectedDay == CafeData.day(10))
    }

    @Test("Given a position on no recorded day, when it is snapped, then nothing is selected")
    func positionOffTheData() {
        let viewModel = LinkedChartsViewModel()

        viewModel.rawSelection = position(onDay: 40)

        #expect(viewModel.selectedDay == nil)
        #expect(viewModel.summary(locale: locale).headline.hasPrefix("Busiest days"))
    }

    @Test("Given a selection, when the finger lifts and the binding returns to nil, then both bands go and the headline returns")
    func liftingClearsBoth() {
        let viewModel = LinkedChartsViewModel()
        let resting = viewModel.summary(locale: locale).headline
        viewModel.rawSelection = position(onDay: 24)

        viewModel.rawSelection = nil

        #expect(viewModel.bandDay(for: viewModel.top) == nil)
        #expect(viewModel.bandDay(for: viewModel.bottom) == nil)
        #expect(viewModel.summary(locale: locale).headline == resting)
    }

    // MARK: Headline

    @Test("Given no selection, when the headline is written, then it names each café's busiest day and cups")
    func restingHeadline() {
        let viewModel = LinkedChartsViewModel()

        #expect(viewModel.summary(locale: locale).headline
            == "Busiest days: Harbour on March 28, 282 cups; Station on March 25, 223 cups.")
    }

    @Test("Given a selected day, when the headline is written, then it gives both cafés' cups that day")
    func selectedHeadline() {
        let viewModel = LinkedChartsViewModel()

        viewModel.rawSelection = position(onDay: 24)

        #expect(viewModel.summary(locale: locale).headline == "Wednesday, March 25: Harbour 231 cups, Station 223 cups.")
    }

    @Test("Given a selected day Station did not record, when the headline is written, then it says so")
    func selectedHeadlineWithNoRecord() {
        let viewModel = LinkedChartsViewModel()

        viewModel.rawSelection = position(onDay: 0)

        #expect(viewModel.summary(locale: locale).headline == "Sunday, March 1: Harbour 190 cups, no record at Station.")
    }

    @Test("Given every headline the screen can show, when the reserved headline is chosen, then none is longer")
    func reservedHeadlineIsTheLongest() {
        let viewModel = LinkedChartsViewModel()
        let reserved = viewModel.summary(locale: locale).reservedHeadline

        for offset in 0 ..< 28 {
            viewModel.rawSelection = position(onDay: offset)
            #expect(viewModel.summary(locale: locale).headline.count <= reserved.count)
        }
    }

    @Test("Given no data, when the screen is drawn, then it is empty and the headline says nothing was recorded")
    func emptyData() {
        let viewModel = LinkedChartsViewModel(
            top: StoreSales(store: CafeWording.harbour, days: []),
            bottom: StoreSales(store: CafeWording.station, days: [])
        )

        #expect(viewModel.isEmpty)
        #expect(viewModel.sharedDomain == nil)
        #expect(viewModel.summary(locale: locale).headline == "No cups recorded at either café.")
    }

    @Test("Given only zeros, when the screen is drawn, then it is empty and the headline names no busiest day")
    func allZeros() {
        let zeros = (0 ..< 7).map { DailySales(day: CafeData.day($0), cups: 0) }
        let viewModel = LinkedChartsViewModel(
            top: StoreSales(store: CafeWording.harbour, days: zeros),
            bottom: StoreSales(store: CafeWording.station, days: zeros)
        )

        #expect(viewModel.isEmpty)
        #expect(viewModel.summary(locale: locale).headline == "No cups recorded at either café.")
    }

    @Test("Given one café with no cups, when the headline is written, then it says so for that café")
    func oneCafeEmpty() {
        let viewModel = LinkedChartsViewModel(
            top: LinkedChartsData.harbour,
            bottom: StoreSales(store: CafeWording.station, days: [])
        )

        #expect(!viewModel.isEmpty)
        #expect(!viewModel.hasCups(viewModel.bottom))
        #expect(viewModel.summary(locale: locale).headline
            == "Busiest days: Harbour on March 28, 282 cups; no cups recorded at Station.")
    }

    @Test("Given two busiest days at a café, when the headline is written, then it names both")
    func tiedBusiestDays() {
        let days = [DailySales(day: CafeData.day(0), cups: 9), DailySales(day: CafeData.day(1), cups: 9)]
        let viewModel = LinkedChartsViewModel(
            top: StoreSales(store: CafeWording.harbour, days: days),
            bottom: StoreSales(store: CafeWording.station, days: days)
        )

        #expect(viewModel.summary(locale: locale).headline.hasPrefix("Busiest days: Harbour on March 1 and March 2, 9 cups;"))
    }

    // MARK: Domain

    @Test("Given the shared domain, when it is worked out, then it runs from the first day to the end of the last")
    func sharedDomain() {
        let viewModel = LinkedChartsViewModel()

        #expect(viewModel.sharedDomain == CafeData.day(0) ... CafeData.day(28))
        #expect(viewModel.xDomain == viewModel.sharedDomain)
    }

    @Test("Given the mistake, when the domain is chosen, then no chart is given one")
    func mistakeHasNoDomain() {
        let viewModel = LinkedChartsViewModel()

        viewModel.isShowingOwnDomains = true

        #expect(viewModel.xDomain == nil)
    }

    @Test("Given the mistake, when a day is selected, then both charts still draw their band on it")
    func mistakeKeepsTheSharedSelection() {
        let viewModel = LinkedChartsViewModel()
        viewModel.isShowingOwnDomains = true

        viewModel.rawSelection = position(onDay: 24)

        #expect(viewModel.bandDay(for: viewModel.top) == CafeData.day(24))
        #expect(viewModel.bandDay(for: viewModel.bottom) == CafeData.day(24))
    }

    @Test("Given both cafés, when the y domain is worked out, then it reaches the highest day at either")
    func sharedYDomain() {
        #expect(LinkedChartsViewModel().highestCups == 282)
    }

    // MARK: Snippets and announcements

    @Test("Given each setting, when the snippets are listed, then the domain snippet follows the toggle")
    func snippetsFollowTheToggle() {
        let viewModel = LinkedChartsViewModel()
        #expect(viewModel.snippets.map(\.name)
            == ["linked-charts-shared-selection", "linked-charts-band", "linked-charts-shared-domain"])

        viewModel.isShowingOwnDomains = true
        #expect(viewModel.snippets.map(\.name)
            == ["linked-charts-shared-selection", "linked-charts-band", "linked-charts-own-domain"])
    }

    @Test("Given either setting, when its snippets are looked up, then each exists in the built app", arguments: [false, true])
    func snippetsExist(isShowingOwnDomains: Bool) throws {
        let store = try SnippetStore()
        let viewModel = LinkedChartsViewModel()
        viewModel.isShowingOwnDomains = isShowingOwnDomains

        for snippet in viewModel.snippets {
            #expect(store[snippet.name] != nil, "missing \(snippet.name)")
        }
    }

    @Test("Given the toggle, when it changes, then the announcement says what changed and ends with the headline")
    func announcement() {
        let viewModel = LinkedChartsViewModel()
        let headline = viewModel.summary(locale: locale).headline

        viewModel.isShowingOwnDomains = true
        #expect(viewModel.changeAnnouncement(locale: locale)
            == "Each chart now chooses its own x domain from its own days. \(headline)")

        viewModel.isShowingOwnDomains = false
        #expect(viewModel.changeAnnouncement(locale: locale)
            == "Both charts now share one x domain, March 1 to March 28. \(headline)")
    }

    // MARK: Accessibility

    @Test("Given a bar, when its element value is written, then it gives its cups and the other café's that day")
    func elementValues() throws {
        let summary = LinkedChartsViewModel().summary(locale: locale)
        let harbourFirst = try #require(LinkedChartsData.harbour.days.first)
        let stationLast = try #require(LinkedChartsData.station.days.last)

        #expect(summary.fullDayText(harbourFirst.day) == "Sunday, March 1")
        #expect(summary.elementValue(for: LinkedChartsData.harbour, day: harbourFirst)
            == "190 cups. Same day: no record at Station.")
        #expect(summary.elementValue(for: LinkedChartsData.station, day: stationLast)
            == "193 cups. Same day: Harbour 282 cups.")
    }

    @Test("Given the Station chart, when its descriptor is made, then it names the café, its days and the shared y range")
    func descriptor() throws {
        let summary = LinkedChartsViewModel().summary(locale: locale)
        let descriptor = LinkedChartsDescriptor(store: LinkedChartsData.station, summary: summary).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold each day at the Station café")
        #expect(descriptor.series.map(\.name) == ["Station"])
        #expect(descriptor.series.first?.dataPoints.count == 21)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(xAxis.categoryOrder.first == "March 8")
        #expect(yAxis.range == 0 ... 282)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.summary == "21 days recorded, March 8 to March 28. Busiest March 25, 223 cups. "
            + "Drawn on the same days as the other chart, March 1 to March 28.")
    }

    @Test("Given the mistake, when the descriptors are made, then they say what is drawn: Station's days out of line")
    func descriptorInTheMistake() {
        let viewModel = LinkedChartsViewModel()
        viewModel.isShowingOwnDomains = true
        let summary = viewModel.summary(locale: locale)

        #expect(summary.audioGraphSummary(for: LinkedChartsData.station).hasSuffix(
            "Drawn on its own days, March 8 to March 28, which do not line up with the other chart's days."
        ))
        #expect(summary.audioGraphSummary(for: LinkedChartsData.harbour).hasSuffix(
            "Drawn on its own days, March 1 to March 28."
        ))
    }

    @Test("Given another locale, when the headline and descriptor are written, then they use it")
    func usesTheLocalePassedIn() throws {
        let french = Locale(identifier: "fr_FR")
        let viewModel = LinkedChartsViewModel()
        viewModel.rawSelection = position(onDay: 24)
        let summary = viewModel.summary(locale: french)
        let xAxis = try #require(
            LinkedChartsDescriptor(store: LinkedChartsData.harbour, summary: summary).makeChartDescriptor().xAxis
                as? AXCategoricalDataAxisDescriptor
        )

        #expect(summary.locale == french)
        #expect(summary.headline.hasPrefix("mercredi 25 mars"))
        #expect(xAxis.categoryOrder.first == "1 mars")
    }
}
