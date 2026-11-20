import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct PlotClippingTests {
    private let english = Locale(identifier: "en_US")

    /// Fourteen days from 1 March 2026 with the given cups.
    private func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    @Test("Given a new screen, when it opens, then one week is in the domain and the plot is clipped")
    func startsClippedOnOneWeek() {
        let viewModel = PlotClippingViewModel()

        #expect(viewModel.range == .oneWeek)
        #expect(viewModel.clipsPlotArea)
        #expect(viewModel.domain == CafeData.day(10) ... CafeData.day(16))
        #expect(viewModel.daysInDomain.count == 7)
        #expect(viewModel.daysOutsideDomain.count == 21)
    }

    @Test("Given each range, when it is chosen, then the domain covers its days")
    func domainFollowsRange() {
        let viewModel = PlotClippingViewModel()

        viewModel.range = .fourWeeks
        #expect(viewModel.domain == CafeData.day(0) ... CafeData.day(27))
        #expect(viewModel.daysOutsideDomain.isEmpty)

        viewModel.range = .twoWeeks
        #expect(viewModel.domain == CafeData.day(7) ... CafeData.day(20))
        #expect(viewModel.daysInDomain.count == 14)
    }

    @Test("Given a narrowed domain, when the plot is clipped, then only the days inside it are drawn")
    func clippedDrawsOnlyDomain() {
        let viewModel = PlotClippingViewModel()

        #expect(viewModel.drawnDays.map(\.day) == viewModel.daysInDomain.map(\.day))
        #expect(viewModel.daysOutsideDomain.allSatisfy { !viewModel.isDrawn($0) })
    }

    @Test("Given a narrowed domain, when the mistake is shown, then every day is drawn")
    func unclippedDrawsEveryDay() {
        let viewModel = PlotClippingViewModel()
        viewModel.isShowingMistake = true

        #expect(!viewModel.clipsPlotArea)
        #expect(viewModel.drawnDays.count == 28)
    }

    @Test("Given the clip, when it is turned off, then the snippets drop the clip")
    func snippetsFollowClip() {
        let viewModel = PlotClippingViewModel()
        #expect(viewModel.snippets.map(\.name) == ["clipping-the-plot-area-domain", "clipping-the-plot-area-clip"])

        viewModel.isShowingMistake = true
        #expect(viewModel.snippets.map(\.name) == ["clipping-the-plot-area-domain"])
    }

    @Test("Given the app's bundle, when the snippets are read, then both of the screen's exist")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        #expect(store[PlotClippingViewModel.domainSnippet.name] != nil)
        #expect(store[PlotClippingViewModel.clipSnippet.name] != nil)
    }

    @Test("Given the sample data, when one week is shown, then the headline names the busiest day in it")
    func headlineNamesBusiestDay() throws {
        let viewModel = PlotClippingViewModel()
        let busiest = try #require(viewModel.daysInDomain.max { $0.cups < $1.cups })
        let headline = viewModel.headline(locale: english)

        #expect(headline.hasPrefix("Most in a day from March 11 to March 17: "))
        #expect(headline.contains(CafeWording.cups(busiest.cups, locale: english)))
        #expect(headline.contains(PlotClippingDates.dayName(busiest.day, locale: english)))
    }

    @Test("Given a busy day outside the domain, when the headline is written, then it names only days inside")
    func headlineIgnoresOutside() {
        var cups = Array(repeating: 10, count: 28)
        cups[0] = 500
        cups[12] = 40
        let viewModel = PlotClippingViewModel(days: days(cups))

        #expect(viewModel.headline(locale: english) == "Most in a day from March 11 to March 17: 40 cups, on Friday, March 13.")
    }

    @Test("Given two days tied inside the domain, when the headline is written, then it names both")
    func headlineTie() {
        var cups = Array(repeating: 10, count: 28)
        cups[11] = 90
        cups[15] = 90
        let viewModel = PlotClippingViewModel(days: days(cups))

        #expect(viewModel.headline(locale: english)
            == "Most in a day from March 11 to March 17: 90 cups, on Thursday, March 12 and Monday, March 16.")
    }

    @Test("Given only zeros, when the headline is written, then it says nothing sold")
    func headlineAllZero() {
        let viewModel = PlotClippingViewModel(days: days(Array(repeating: 0, count: 28)))

        #expect(viewModel.headline(locale: english) == "No cups sold from March 11 to March 17.")
    }

    @Test("Given no data, when the screen is built, then there is no domain and the headline says so")
    func emptyData() {
        let viewModel = PlotClippingViewModel(days: [])

        #expect(!viewModel.hasData)
        #expect(viewModel.domain == nil)
        #expect(viewModel.axisDays(isLargeText: false).isEmpty)
        #expect(viewModel.headline(locale: english) == "No daily sales to show yet.")
    }

    @Test("Given each range, when the axis is labelled, then the trailing days are left free")
    func axisDays() {
        let viewModel = PlotClippingViewModel()

        viewModel.range = .fourWeeks
        #expect(viewModel.axisDays(isLargeText: false) == [0, 7, 14, 21].map(CafeData.day))
        #expect(viewModel.axisDays(isLargeText: true) == [0, 14].map(CafeData.day))
        viewModel.range = .twoWeeks
        #expect(viewModel.axisDays(isLargeText: false) == [7, 11, 15].map(CafeData.day))
        #expect(viewModel.axisDays(isLargeText: true) == [7, 15].map(CafeData.day))
        viewModel.range = .oneWeek
        #expect(viewModel.axisDays(isLargeText: false) == [10, 12, 14].map(CafeData.day))
        #expect(viewModel.axisDays(isLargeText: true) == [10, 14].map(CafeData.day))
    }

    @Test("Given each state, when the note is written, then it says what the clip does")
    func plotNote() {
        let viewModel = PlotClippingViewModel()
        #expect(viewModel.plotNote(locale: english) == "Outside the domain: 21 days, cut off at the plot area's edge.")

        viewModel.isShowingMistake = true
        #expect(viewModel.plotNote(locale: english)
            == "Outside the domain: 21 days, drawn past the plot area, over the axis labels and beyond the chart.")

        viewModel.range = .fourWeeks
        #expect(viewModel.plotNote(locale: english)
            == "Every day is inside the x scale's domain, so the plot is unclipped and the first and last points, "
            + "which sit on the plot's edges, are drawn whole.")

        viewModel.isShowingMistake = false
        #expect(viewModel.plotNote(locale: english)
            == "Every day is inside the x scale's domain, so clipping only trims the first and last points, "
            + "which sit on the plot's edges.")
    }

    @Test("Given each range, when the clip toggle is shown, then it is a mistake only when days fall outside the domain")
    func mistakeOnlyWhenNarrowed() {
        let viewModel = PlotClippingViewModel()
        #expect(viewModel.canShowMistake)

        viewModel.range = .twoWeeks
        #expect(viewModel.canShowMistake)

        viewModel.range = .fourWeeks
        #expect(!viewModel.canShowMistake)
    }

    @Test("Given a day outside the domain, when it is labelled, then the label says it is outside the plot")
    func elementText() throws {
        let viewModel = PlotClippingViewModel()
        let inside = try #require(viewModel.daysInDomain.first)
        let outside = try #require(viewModel.daysOutsideDomain.first)

        #expect(viewModel.elementLabel(for: inside, locale: english) == "Wednesday, March 11")
        #expect(viewModel.elementLabel(for: outside, locale: english) == "Sunday, March 1, drawn outside the plot area")
        #expect(viewModel.elementValue(for: inside, locale: english) == CafeWording.cups(inside.cups, locale: english))
    }

    @Test("Given a change of domain or clip, when it is announced, then the change comes before the headline")
    func announcements() {
        let viewModel = PlotClippingViewModel()
        viewModel.range = .twoWeeks
        let headline = viewModel.headline(locale: english)

        #expect(viewModel.rangeAnnouncement(locale: english) == "X scale domain now March 8 to March 21. \(headline)")

        viewModel.isShowingMistake = true
        let clipping = viewModel.clippingAnnouncement(locale: english)
        #expect(clipping.hasPrefix("Plot area not clipped. Outside the domain: 14 days"))
        #expect(clipping.hasSuffix(headline))
    }

    @Test("Given the clipped plot, when the descriptor is made, then it describes only the days drawn")
    func descriptorClipped() throws {
        let viewModel = PlotClippingViewModel()
        let descriptor = viewModel.descriptor(locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Daily cups at the Harbour café, x axis from March 11 to March 17")
        #expect(descriptor.summary?.hasPrefix("7 days drawn.") == true)
        #expect(descriptor.summary?.contains("outside the plot area") == false)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "March 11")
        #expect(xAxis.categoryOrder.count == 7)
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.dataPoints.count == 7)
        #expect(descriptor.series.first?.isContinuous == true)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range.lowerBound == 0)
        // The drawn axis: the most cups of any day (282), rounded up to 300.
        #expect(yAxis.range.upperBound == 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given the unclipped plot, when the descriptor is made, then it describes every day drawn")
    func descriptorUnclipped() {
        let viewModel = PlotClippingViewModel()
        viewModel.isShowingMistake = true
        let descriptor = viewModel.descriptor(locale: english).makeChartDescriptor()

        #expect(descriptor.series.first?.dataPoints.count == 28)
        #expect(descriptor.summary?.hasPrefix("28 days drawn.") == true)
        #expect(descriptor.summary?.hasSuffix("Drawn outside the plot area, beyond the x axis's range: 21 days.") == true)
    }
}
