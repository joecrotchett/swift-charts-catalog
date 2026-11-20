import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

struct LegendBasicsTests {
    private let english = Locale(identifier: "en_US")

    private func stores(harbour: [Int], station: [Int]) -> [StoreSales] {
        [
            StoreSales(store: CafeWording.harbour, days: harbour.enumerated().map { DailySales(day: CafeData.day($0), cups: $1) }),
            StoreSales(store: CafeWording.station, days: station.enumerated().map { DailySales(day: CafeData.day($0), cups: $1) }),
        ]
    }

    // MARK: State

    @Test("Given a new screen, when it opens, then the legend is shown, automatic and at the start")
    @MainActor
    func defaults() {
        let viewModel = LegendBasicsViewModel()
        #expect(viewModel.visibility == .shown)
        #expect(viewModel.position == .automatic)
        #expect(viewModel.alignment == .start)
        #expect(viewModel.placesLegend)
        #expect(!viewModel.labelsLineEnds)
        #expect(viewModel.legendAlignment == .leading)
    }

    @Test("Given the legend hidden, when the state is read, then it is not placed and the lines are named at their ends")
    @MainActor
    func hidden() {
        let viewModel = LegendBasicsViewModel()
        viewModel.visibility = .hidden
        #expect(!viewModel.placesLegend)
        #expect(viewModel.labelsLineEnds)
        #expect(viewModel.legendVisibility == .hidden)
    }

    @Test("Given the legend shown, when its visibility is passed to the chart, then it is automatic, whatever the position")
    @MainActor
    func shownVisibility() {
        let viewModel = LegendBasicsViewModel()
        for position in LegendBasicsPosition.allCases {
            viewModel.position = position
            #expect(viewModel.legendVisibility == .automatic)
        }
    }

    @Test(
        "Given a legend above or below, when an alignment is chosen, then it is horizontal",
        arguments: [LegendBasicsPosition.automatic, .top, .bottom]
    )
    func horizontalAlignment(position: LegendBasicsPosition) {
        #expect(LegendBasicsAlignment.start.alignment(for: position) == .leading)
        #expect(LegendBasicsAlignment.centre.alignment(for: position) == .center)
        #expect(LegendBasicsAlignment.end.alignment(for: position) == .trailing)
    }

    @Test(
        "Given a legend at a side, when an alignment is chosen, then it is vertical",
        arguments: [LegendBasicsPosition.leading, .trailing]
    )
    func verticalAlignment(position: LegendBasicsPosition) {
        #expect(LegendBasicsAlignment.start.alignment(for: position) == .top)
        #expect(LegendBasicsAlignment.centre.alignment(for: position) == .center)
        #expect(LegendBasicsAlignment.end.alignment(for: position) == .bottom)
    }

    @Test("Given each position, when it is passed to the chart, then it is the matching annotation position")
    func positions() {
        #expect(LegendBasicsPosition.automatic.annotationPosition == .automatic)
        #expect(LegendBasicsPosition.top.annotationPosition == .top)
        #expect(LegendBasicsPosition.bottom.annotationPosition == .bottom)
        #expect(LegendBasicsPosition.leading.annotationPosition == .leading)
        #expect(LegendBasicsPosition.trailing.annotationPosition == .trailing)
    }

    // MARK: Snippets

    @Test("Given the legend shown, when See Code opens, then it shows the source and the placement")
    func shownSnippets() {
        #expect(LegendBasicsViewModel.snippets(for: .shown).map(\.name) == ["the-legend-source", "the-legend-placement"])
    }

    @Test("Given the legend hidden, when See Code opens, then it shows the source, the one legend chain and the names in its place")
    func hiddenSnippets() {
        #expect(LegendBasicsViewModel.snippets(for: .hidden).map(\.name)
            == ["the-legend-source", "the-legend-placement", "the-legend-end-labels"])
    }

    @Test("Given the built app, when its snippets are read, then every one this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for visibility in LegendBasicsVisibility.allCases {
            for snippet in LegendBasicsViewModel.snippets(for: visibility) {
                #expect(store[snippet.name] != nil, "\(snippet.name)")
            }
        }
    }

    // MARK: Headline

    @Test("Given the sample data, when the headline is written, then it names the leader on the last day and its cups")
    func headline() {
        #expect(LegendBasicsSummary(stores: CafeData.storeSales, locale: english).headline
            == "On March 28, Harbour sold the most: 282 cups.")
    }

    @Test("Given a tie on the last day, when the headline is written, then it names both cafés")
    func headlineTie() {
        let summary = LegendBasicsSummary(stores: stores(harbour: [10, 40], station: [20, 40]), locale: english)
        #expect(summary.headline == "On March 2, Harbour and Station sold the same: 40 cups.")
    }

    @Test("Given only zeros, when the headline is written, then it is true of the zero lines")
    func headlineZeros() {
        let summary = LegendBasicsSummary(stores: stores(harbour: [0, 0], station: [0, 0]), locale: english)
        #expect(summary.headline == "On March 2, Harbour and Station sold the same: 0 cups.")
    }

    @Test("Given one café with one cup, when the headline is written, then the count agrees in number")
    func headlineOneCafe() {
        let summary = LegendBasicsSummary(stores: stores(harbour: [1], station: []), locale: english)
        #expect(summary.headline == "On March 1, Harbour sold 1 cup.")
    }

    @Test("Given no data, when the screen is drawn, then there is nothing to chart and the headline says so")
    func empty() {
        let summary = LegendBasicsSummary(stores: stores(harbour: [], station: []), locale: english)
        #expect(!summary.hasData)
        #expect(summary.headline == "No cups sold yet this month.")
        #expect(summary.audioGraphSummary == "No cups sold yet this month.")
    }

    @Test("Given a German locale, when the headline is written, then the date is written the German way")
    func headlineLocale() {
        let headline = LegendBasicsSummary(stores: CafeData.storeSales, locale: Locale(identifier: "de_DE")).headline
        #expect(headline.contains("28. März"))
    }

    // MARK: Elements and axis

    @Test("Given the sample data, when the elements are made, then each café is four weeks, café by café")
    func portions() throws {
        let summary = LegendBasicsSummary(stores: CafeData.storeSales, locale: english)
        #expect(summary.portions.count == 8)
        #expect(summary.portions.prefix(4).allSatisfy { $0.store == CafeWording.harbour })
        let first = try #require(summary.portions.first)
        #expect(summary.label(for: first) == "Harbour, March 1 to March 7")
        #expect(summary.value(for: first).hasPrefix("Starts at 190 cups, ends at "))
    }

    @Test("Given a week of one value, when it is described, then counts of one agree in number")
    func portionValue() throws {
        let summary = LegendBasicsSummary(stores: stores(harbour: [1, 1], station: []), locale: english)
        let portion = try #require(summary.portions.first)
        #expect(summary.value(for: portion) == "Starts at 1 cup, ends at 1 cup, lowest 1 cup, highest 1 cup")
    }

    @Test("Given 28 days, when the axis is labelled weekly or fortnightly, then only days with data are labelled")
    func axisDays() {
        let summary = LegendBasicsSummary(stores: CafeData.storeSales, locale: english)
        #expect(summary.axisDays(every: 7) == [CafeData.day(0), CafeData.day(7), CafeData.day(14), CafeData.day(21)])
        #expect(summary.axisDays(every: 14) == [CafeData.day(0), CafeData.day(14)])
    }

    // MARK: Audio Graph

    @Test("Given the sample data, when the descriptor is made, then it has both cafés as continuous series over 28 days")
    func descriptor() throws {
        let descriptor = LegendBasicsChartDescriptor(stores: CafeData.storeSales, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold each day at Harbour and Station")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.isContinuous) == [true, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [28, 28])
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "March 1")
        let summary = try #require(descriptor.summary)
        #expect(summary.hasPrefix("2 cafés, 28 days from March 1 to March 28."))
        #expect(summary.contains("Harbour: first day 190 cups, last day 282 cups"))
    }

    @Test("Given the descriptor, when the value axis is read, then it runs from zero to the highest day and says cups")
    func descriptorAxis() throws {
        let descriptor = LegendBasicsChartDescriptor(stores: CafeData.storeSales, locale: english).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The busiest day is 282; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given March, when the day the headline names is labelled, then the label names March 28 and its cups")
    func calloutNamesTheLastDay() {
        let summary = LegendBasicsSummary(stores: CafeData.storeSales, locale: Locale(identifier: "en_US"))
        #expect(summary.headline == "On March 28, Harbour sold the most: 282 cups.")
        #expect(summary.calloutText(day: CafeData.day(27), cups: 282) == "Mar 28: 282")
    }
}
