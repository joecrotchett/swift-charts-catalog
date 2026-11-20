import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct PopulationPyramidTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    private func summary(_ rows: [(String, String, Int)], groups: [String] = ["Young", "Old"]) -> PopulationPyramidSummary {
        PopulationPyramidSummary(
            visits: rows.map { AgeGroupVisits(ageGroup: $0.0, store: $0.1, visits: $0.2) },
            ageGroups: groups
        )
    }

    // MARK: View model

    @Test("Given the screen opens, when its view model is made, then it holds the café data with Harbour as the negated side")
    func defaultState() {
        let viewModel = PopulationPyramidViewModel()

        #expect(viewModel.summary.visits == CafeData.ageGroupVisits)
        #expect(viewModel.summary.ageGroups == CafeData.ageGroups)
        #expect(viewModel.summary.stores == [CafeWording.harbour, CafeWording.station])
        #expect(viewModel.summary.negatedStore == CafeWording.harbour)
        #expect(!viewModel.summary.isEmpty)
    }

    @Test("Given the built app, when the screen's snippets are looked up, then each exists and shows its part of the concept")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        #expect(PopulationPyramidViewModel().snippets.map(\.name) == ["population-pyramid-bars", "population-pyramid-axes"])
        let bars = try #require(store["population-pyramid-bars"])
        #expect(bars.file == "Marks/PopulationPyramidScreen.swift")
        #expect(bars.code.contains("summary.plottedVisits(item)"))
        #expect(bars.code.contains("Plot {"))
        let axes = try #require(store["population-pyramid-axes"])
        #expect(axes.code.contains("abs(visits)"))
        #expect(axes.code.contains("preset: .aligned"))
    }

    // MARK: Rows and plotted values

    @Test("Given two cafés, when values are plotted, then the first café's are negated and the second's are not")
    func negatesFirstStore() {
        let summary = summary([("Young", "A", 10), ("Young", "B", 20)])

        #expect(summary.plottedVisits(summary.visits[0]) == -10)
        #expect(summary.plottedVisits(summary.visits[1]) == 20)
    }

    @Test("Given groups listed youngest first, when the rows are drawn, then the oldest group comes first and cafés keep their order")
    func rowsOldestFirst() {
        let rows = PopulationPyramidViewModel().summary.rows

        #expect(rows.count == CafeData.ageGroupVisits.count)
        #expect(rows.first?.ageGroup == CafeData.ageGroups.last)
        #expect(rows.last?.ageGroup == CafeData.ageGroups.first)
        #expect(rows.prefix(2).map(\.store) == [CafeWording.harbour, CafeWording.station])
    }

    @Test("Given the rows as drawn, when the descriptor's categories and points are read, then they run in the same order, oldest first")
    func descriptorFollowsTheDrawnOrder() throws {
        let summary = PopulationPyramidViewModel().summary
        let descriptor = PopulationPyramidChartDescriptor(summary: summary, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        var elementGroups: [String] = []
        for row in summary.rows where elementGroups.last != row.ageGroup {
            elementGroups.append(row.ageGroup)
        }

        #expect(summary.drawnAgeGroups == Array(CafeData.ageGroups.reversed()))
        #expect(xAxis.categoryOrder == elementGroups)
        #expect(xAxis.categoryOrder.first == CafeData.ageGroups.last)
        for series in descriptor.series {
            #expect(series.dataPoints.map(\.xValue.__category) == elementGroups)
        }
    }

    @Test("Given a German locale and a tie, when the headline is written, then the numbers are German and the list is joined in English")
    func listStaysEnglish() {
        let summary = summary([("Old", "A", 1200), ("Young", "A", 1200), ("Young", "B", 1), ("Old", "B", 0)])

        #expect(summary.headline(locale: german) == "A was visited most by Young and Old (1.200 visits), B by Young (1 visit).")
    }

    // MARK: Headline

    @Test("Given the café data, when the headline is written, then it names each café's longest bar with its visits")
    func headlineForCafeData() {
        let headline = PopulationPyramidViewModel().summary.headline(locale: english)

        #expect(headline == "Harbour was visited most by 30 to 44 (1,480 visits), Station by 18 to 29 (1,620 visits).")
    }

    @Test("Given a German locale, when the headline is written, then its numbers are grouped the German way")
    func headlineInGerman() {
        let headline = PopulationPyramidViewModel().summary.headline(locale: german)

        #expect(headline.contains("1.480"))
        #expect(headline.contains("1.620"))
    }

    @Test("Given two groups tie at one café, when the headline is written, then it names both, youngest first")
    func headlineOnTie() {
        let summary = summary([("Old", "A", 7), ("Young", "A", 7), ("Young", "B", 1), ("Old", "B", 0)])

        #expect(summary.headline(locale: english) == "A was visited most by Young and Old (7 visits), B by Young (1 visit).")
    }

    @Test("Given one café had no visits, when the headline is written, then it speaks only of the café that is drawn")
    func headlineWithOneSilentStore() {
        let summary = summary([("Young", "A", 0), ("Old", "A", 0), ("Young", "B", 3), ("Old", "B", 2)])

        #expect(summary.headline(locale: english) == "B was visited most by Young (3 visits).")
        #expect(!summary.isEmpty)
    }

    @Test("Given no rows or only zeros, when the summary is asked, then it is empty and says nobody visited", arguments: [0, 2])
    func emptyStates(rowCount: Int) {
        let rows = [("Young", "A", 0), ("Young", "B", 0)].prefix(rowCount)
        let summary = summary(Array(rows))

        #expect(summary.isEmpty)
        #expect(summary.headline(locale: english) == "No visits recorded this month.")
        #expect(summary.audioGraphSummary(locale: english) == "No visits recorded this month.")
    }

    // MARK: Element text

    @Test("Given a bar on the negated side, when its element text is written, then the value is the real, positive count")
    func elementText() {
        let summary = summary([("Young", "A", 1), ("Young", "B", 1200)])

        #expect(summary.elementLabel(summary.visits[0]) == "Young, A")
        #expect(summary.elementValue(summary.visits[0], locale: english) == "1 visit")
        #expect(summary.elementValue(summary.visits[1], locale: english) == "1,200 visits")
        #expect(summary.elementValue(summary.visits[1], locale: german) == "1.200 visits")
    }

    // MARK: Descriptor

    @Test("Given the café data, when the descriptor is made, then it has a series per café over the age groups in positive visits")
    func descriptor() throws {
        let summary = PopulationPyramidViewModel().summary
        let descriptor = PopulationPyramidChartDescriptor(summary: summary, locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Visits in a month by age group, at each café")
        #expect(descriptor.summary == "5 age groups at Harbour and Station. Harbour, 4,510 visits in total. "
            + "Station, 4,020 visits in total. "
            + "Harbour was visited most by 30 to 44 (1,480 visits), Station by 18 to 29 (1,620 visits).")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.ageGroup)
        #expect(xAxis.categoryOrder == Array(CafeData.ageGroups.reversed()))
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.visits)
        // The largest bar is 1,620 visits; each side of the axis is drawn to 2,000, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 2000)
        #expect(yAxis.valueDescriptionProvider(1) == "1 visit")
        #expect(yAxis.valueDescriptionProvider(1480) == "1,480 visits")
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
        #expect(descriptor.series.map(\.dataPoints.count) == [5, 5])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }
}
