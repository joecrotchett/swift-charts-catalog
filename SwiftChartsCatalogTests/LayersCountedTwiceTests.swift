import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LayersCountedTwiceTests {
    private let locale = Locale(identifier: "en_US")

    @Test("Given the sample months, when the screen opens, then it shows the area case with both layers heard")
    func initialState() {
        let model = LayersCountedTwiceViewModel()
        #expect(model.layerCase == .lineOverArea)
        #expect(model.isShowingMistake)
        #expect(!model.hasDescriptor)
    }

    @Test("Given the sample months, when named, then they are March to August in the data's calendar")
    func monthNames() {
        let months = LayersCountedTwiceViewModel().months(locale: locale)
        #expect(months.map(\.name) == ["March", "April", "May", "June", "July", "August"])
        #expect(months.map(\.cups) == [205, 218, 230, 246, 253, 235])
    }

    @Test("Given the sample months, when the headline is written, then it names July and its figure")
    func headline() {
        let model = LayersCountedTwiceViewModel()
        #expect(model.headline(locale: locale) == "Busiest on average: July, 253 cups a day.")
        model.layerCase = .lineWithPoints
        model.isShowingMistake = false
        #expect(model.headline(locale: locale) == "Busiest on average: July, 253 cups a day.")
    }

    @Test("Given a tie for the busiest month, when the headline is written, then it names both")
    func headlineTie() {
        let summaries = [
            MonthlySummary(month: CafeData.month(0), lowestDay: 1, highestDay: 3, averageDay: 2),
            MonthlySummary(month: CafeData.month(1), lowestDay: 1, highestDay: 3, averageDay: 2),
        ]
        let model = LayersCountedTwiceViewModel(summaries: summaries)
        #expect(model.headline(locale: locale) == "Busiest on average: March and April, 2 cups a day.")
    }

    @Test("Given one cup a day, when spoken, then the count agrees in number")
    func singular() {
        #expect(LayersCountedTwiceWording.cupsADay(1, locale: locale) == "1 cup a day")
    }

    @Test("Given no months or only zeros, when the screen draws, then only the area case of zeros and no months show no chart")
    func noData() {
        let empty = LayersCountedTwiceViewModel(summaries: [])
        #expect(empty.hasNoData)
        #expect(empty.hasNoMonths)
        #expect(empty.headline(locale: locale) == "No cups sold in these months.")
        let zeros = LayersCountedTwiceViewModel(summaries: [
            MonthlySummary(month: CafeData.month(0), lowestDay: 0, highestDay: 0, averageDay: 0),
        ])
        #expect(zeros.hasNoData)
        #expect(!zeros.hasNoMonths)
        #expect(zeros.headline(locale: locale) == "No cups sold in these months.")
        zeros.layerCase = .lineWithPoints
        #expect(!zeros.hasNoData)
    }

    @Test("Given each state, when its snippets are listed, then each names the chart drawn and the descriptor when fixed")
    func snippetNames() {
        let model = LayersCountedTwiceViewModel()
        #expect(model.snippets.map(\.name) == ["layers-counted-twice-area-both"])
        model.isShowingMistake = false
        #expect(model.snippets.map(\.name) == ["layers-counted-twice-area-hidden", "layers-counted-twice-descriptor"])
        model.layerCase = .lineWithPoints
        #expect(model.snippets.map(\.name) == ["layers-counted-twice-points-symbol", "layers-counted-twice-descriptor"])
        model.isShowingMistake = true
        #expect(model.snippets.map(\.name) == ["layers-counted-twice-points-layer"])
    }

    @Test("Given the app bundle, when its snippets are read, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [
            "layers-counted-twice-area-both", "layers-counted-twice-area-hidden",
            "layers-counted-twice-points-layer", "layers-counted-twice-points-symbol",
            "layers-counted-twice-descriptor",
        ]
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given a line over an area both heard, when the elements are written, then each month is heard twice in the order read")
    func areaMistakeElements() {
        let spoken = LayersCountedTwiceViewModel().spokenText(locale: locale)
        #expect(spoken.elements == [
            "March, 205", "March, 205 cups a day",
            "April, 218 cups a day", "April, 218",
            "May, 230 cups a day", "May, 230",
            "June, 246 cups a day", "June, 246",
            "July, 253 cups a day", "July, 253",
            "August, 235 cups a day", "August, 235",
        ])
        #expect(spoken.audioGraph == [
            "Title: \"Chart\"",
            "Summary: none",
            "Axes: x axis \"Month\", y axis \"Average cups a day\", from 0 to 300, the drawn scale, ends read as bare numbers",
            "Series: one, with no name, continuous, 12 points: every month twice",
            "Each point: March, 205, no unit",
        ])
    }

    @Test("Given a line with a point layer both heard, when the elements are written, then the line's six come first and the points' six in the order read")
    func pointsMistakeElements() {
        let model = LayersCountedTwiceViewModel()
        model.layerCase = .lineWithPoints
        let spoken = model.spokenText(locale: locale)
        #expect(spoken.elements == [
            "March, 205 cups a day", "April, 218 cups a day", "May, 230 cups a day",
            "June, 246 cups a day", "July, 253 cups a day", "August, 235 cups a day",
            "June, 246", "July, 253", "May, 230", "August, 235", "April, 218", "March, 205",
        ])
        #expect(spoken.audioGraph.contains {
            $0 == "Series: two, neither named: the line (continuous) and the points (separate), 6 points each"
        })
    }

    @Test("Given the fixed state, when the elements are predicted, then each month is heard once with its unit")
    func fixedElements() {
        let model = LayersCountedTwiceViewModel()
        model.isShowingMistake = false
        let spoken = model.spokenText(locale: locale)
        #expect(spoken.elements.count == 6)
        #expect(spoken.elements.first == "March, 205 cups a day")
        #expect(spoken.audioGraph.first == "Title: Average cups a day at the Harbour café, March to August")
        #expect(spoken.audioGraph.contains("Axes: x axis \"Month\", y axis \"Average cups a day\", from 0 to 300, the drawn scale"))
        #expect(spoken.audioGraph.last?.hasPrefix("Predicted, not read:") == true)
    }

    @Test("Given a change of state, when announced, then it says what changed and then the headline")
    func announcement() {
        let model = LayersCountedTwiceViewModel()
        model.isShowingMistake = false
        #expect(model.announcement(locale: locale)
            == "Showing a line over an area, the area hidden from VoiceOver. Busiest on average: July, 253 cups a day.")
    }

    @Test("Given the sample months, when the descriptor is made, then it has a title, a summary, months and units")
    func descriptor() throws {
        let model = LayersCountedTwiceViewModel()
        let months = model.months(locale: locale)
        let descriptor = LayersCountedTwiceDescriptor(months: months, yDomain: model.yDomain(locale: locale), locale: locale)
            .makeChartDescriptor()
        #expect(descriptor.title == "Average cups a day at the Harbour café, March to August")
        #expect(descriptor.summary == "6 months. First March, 205 cups a day; last August, 235 cups a day. "
            + "Highest July, 253 cups a day; lowest March, 205 cups a day.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == months.map(\.name))
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Average cups a day")
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.range == model.yDomain(locale: locale))
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup a day")
        #expect(yAxis.valueDescriptionProvider(253) == "253 cups a day")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Harbour café")
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 6)
    }
}
