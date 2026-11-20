import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct StylingMarksTests {
    private let english = Locale(identifier: "en_US")

    private func sales(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    @Test("Given the sample week, when the screen opens, then it pairs seven days of both cafés")
    func sampleWeek() {
        let model = StylingMarksViewModel()
        #expect(model.days.count == 7)
        #expect(model.days.first?.harbour == CafeData.storeSales[0].days[0].cups)
        #expect(model.days.first?.station == CafeData.storeSales[1].days[0].cups)
        #expect(!model.hasNoSales)
    }

    @Test("Given the sample week, when the headline is written, then it names Harbour's busiest day and its cups")
    func headlineNamesBusiestDay() {
        let model = StylingMarksViewModel()
        #expect(model.headline(locale: english) == "Harbour’s busiest day: Saturday, March 7, 219 cups.")
    }

    @Test("Given any combination of toggles, when the headline is written, then it does not change")
    func headlineIgnoresToggles() {
        let model = StylingMarksViewModel()
        let before = model.headline(locale: english)
        model.usesFixedColour = false
        model.highlightsBusiestDay = true
        model.fadesBars = true
        model.roundsCorners = true
        model.dashesLine = true
        model.shadowsLine = true
        model.blursBars = true
        #expect(model.headline(locale: english) == before)
    }

    @Test("Given a tie for the busiest day, when the headline is written, then both days are named and both highlighted")
    func tieNamesBoth() {
        let model = StylingMarksViewModel(harbour: sales([5, 9, 9]), station: sales([1, 2, 3]))
        model.highlightsBusiestDay = true
        #expect(model.headline(locale: english) == "Harbour’s busiest day: Monday, March 2 and Tuesday, March 3, 9 cups.")
        #expect(model.days.map { model.isHighlighted($0) } == [false, true, true])
    }

    @Test("Given no cups at either café, when the screen draws, then it shows the placeholder and says so")
    func noSales() {
        let empty = StylingMarksViewModel(harbour: [], station: [])
        #expect(empty.hasNoSales)
        #expect(empty.headline(locale: english) == "No cups sold at either café this week.")
        let zeros = StylingMarksViewModel(harbour: sales([0, 0]), station: sales([0, 0]))
        #expect(zeros.hasNoSales)
        #expect(zeros.busiestDays.isEmpty)
        #expect(zeros.audioGraphSummary(locale: english) == "No cups sold at either café this week.")
    }

    @Test("Given Harbour sold nothing and Station did, when the headline is written, then it says Harbour sold none")
    func harbourSoldNothing() {
        let model = StylingMarksViewModel(harbour: sales([0, 0]), station: sales([4, 1]))
        #expect(!model.hasNoSales)
        #expect(model.headline(locale: english) == "Harbour sold no cups this week.")
    }

    @Test("Given one cup, when counts are written, then they agree in number")
    func countsAgree() {
        let model = StylingMarksViewModel(harbour: sales([1]), station: sales([1]))
        #expect(model.headline(locale: english) == "Harbour’s busiest day: Sunday, March 1, 1 cup.")
        #expect(model.accessibilityValue(for: model.days[0], locale: english) == "Harbour 1 cup, Station 1 cup")
    }

    @Test("Given the highlight toggle, when the busiest day's element is read, then it names the highlight only while drawn")
    func elementNamesHighlight() throws {
        let model = StylingMarksViewModel()
        let saturday = try #require(model.days.last)
        #expect(model.accessibilityValue(for: saturday, locale: english) == "Harbour 219 cups, Station 172 cups")
        model.highlightsBusiestDay = true
        #expect(model.accessibilityValue(for: saturday, locale: english)
            == "Harbour 219 cups, Station 172 cups, highlighted: Harbour’s busiest day")
        let sunday = try #require(model.days.first)
        #expect(!model.accessibilityValue(for: sunday, locale: english).contains("highlighted"))
    }

    @Test("Given a German locale, when the day and counts are written, then they follow the locale")
    func localeIsPassedIn() {
        let german = Locale(identifier: "de_DE")
        let model = StylingMarksViewModel(harbour: sales([1200]), station: sales([1]))
        #expect(model.spokenDay(CafeData.day(0), locale: german).contains("März"))
        #expect(model.headline(locale: german).contains("1.200"))
    }

    @Test("Given the sample week, when the x domain is read, then it runs from the first day's start to the last day's end")
    func dayDomain() {
        let model = StylingMarksViewModel()
        #expect(model.dayDomain.lowerBound == CafeData.day(0))
        #expect(model.dayDomain.upperBound == CafeData.day(7))
    }

    @Test("Given the default toggles, when the snippets are listed, then they are the chart and the colour")
    func defaultSnippets() {
        let model = StylingMarksViewModel()
        #expect(model.snippets.map(\.name) == ["styling-marks-chart", "styling-marks-colour"])
    }

    @Test("Given every toggle on, when the snippets are listed, then each modifier has its own")
    func allSnippets() {
        let model = StylingMarksViewModel()
        model.fadesBars = true
        model.roundsCorners = true
        model.dashesLine = true
        model.shadowsLine = true
        model.blursBars = true
        #expect(model.snippets.map(\.name) == [
            "styling-marks-chart", "styling-marks-colour", "styling-marks-opacity", "styling-marks-corner-radius",
            "styling-marks-line-style", "styling-marks-shadow", "styling-marks-blur",
        ])
    }

    @Test("Given only the highlight, when the snippets are listed, then the colour snippet is shown")
    func highlightShowsColourSnippet() {
        let model = StylingMarksViewModel()
        model.usesFixedColour = false
        #expect(model.snippets.map(\.name) == ["styling-marks-chart"])
        model.highlightsBusiestDay = true
        #expect(model.snippets.map(\.name) == ["styling-marks-chart", "styling-marks-colour"])
    }

    @Test("Given the built app, when every snippet name is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [
            "styling-marks-chart", "styling-marks-colour", "styling-marks-opacity", "styling-marks-corner-radius",
            "styling-marks-line-style", "styling-marks-shadow", "styling-marks-blur",
        ]
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given the built app, when the chart snippet is read, then the line has its own colour and a Station label, and only the bars take the toggle")
    func lineKeepsItsColourAndLabel() throws {
        let store = try SnippetStore()
        let chart = try #require(store["styling-marks-chart"])
        #expect(chart.code.contains(".foregroundStyle(StylingMarksStyle.lineColour)"))
        #expect(chart.code.contains("Text(CafeWording.station)"))
        #expect(chart.code.components(separatedBy: "stylingMarksBarColour(").count == 2)

        let colour = try #require(store["styling-marks-colour"])
        #expect(colour.code.contains("func stylingMarksBarColour(usesFixedColour: Bool, isHighlighted: Bool)"))
    }

    @Test("Given the built app, when the corner-radius snippet is read, then it says the top corners are rounded and the baseline ones stay square")
    func cornerRadiusSaysWhatIsDrawn() throws {
        let store = try SnippetStore()
        let snippet = try #require(store["styling-marks-corner-radius"])
        #expect(snippet.code.contains("Rounds the two corners at the top of each bar"))
        #expect(snippet.code.contains("the two on the baseline stay square"))
        #expect(!snippet.code.contains("free end"))
    }

    @Test("Given the sample week, when the descriptor is made, then it has two named series over seven written-out days")
    func descriptor() {
        let model = StylingMarksViewModel()
        let descriptor = StylingMarksChartDescriptor(
            days: model.days,
            dayNames: model.days.map { model.spokenDay($0.day, locale: english) },
            summary: model.audioGraphSummary(locale: english),
            locale: english
        ).makeChartDescriptor()
        #expect(descriptor.title == "Cups a day at the Harbour and Station cafés")
        #expect(descriptor.summary == "7 days. Harbour, as bars: highest Saturday, March 7, 219 cups; lowest Tuesday, March 3, 152 cups. "
            + "Station, as a line: highest Wednesday, March 4, 202 cups; lowest Sunday, March 1, 155 cups.")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.isContinuous) == [false, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [7, 7])
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.categoryOrder.first == "Sunday, March 1")
        let yAxis = descriptor.yAxis
        #expect(yAxis?.title == CafeWording.cupsAxisTitle)
        // The busiest day is 219; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis?.range == 0 ... 300)
        #expect(yAxis?.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis?.valueDescriptionProvider(.nan) == "")
    }
}
