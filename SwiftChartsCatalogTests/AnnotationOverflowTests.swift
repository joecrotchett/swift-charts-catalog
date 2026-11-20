import Accessibility
import Charts
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct AnnotationOverflowTests {
    private let english = Locale(identifier: "en_US")

    // MARK: Defaults and the strategy on each axis

    @Test("Given a new screen, when it opens, then the last day is labelled, x pads the scale and y fits to the plot")
    func startsAtDefaults() {
        let model = AnnotationOverflowViewModel()
        #expect(model.labelledDay == .last)
        #expect(model.xStrategy == .padScale)
        // Not pad scale on y: its padded top cannot be read back for the Audio Graph.
        #expect(model.yStrategy == .fitToPlot)
        #expect(model.leavesValueScaleAutomatic == false)
        #expect(model.strategy(on: .x) == .padScale)
        #expect(model.strategy(on: .y) == .fitToPlot)
    }

    @Test("Given a strategy chosen for each axis, when each axis is asked, then it reports its own choice", arguments: [
        (AnnotationOverflowStrategy.disabled, AnnotationOverflowStrategy.fitToPlot),
        (.fitToChart, .padScale),
        (.fitToPlot, .disabled),
        (.padScale, .fitToChart),
    ])
    func strategyPerAxis(x: AnnotationOverflowStrategy, y: AnnotationOverflowStrategy) {
        let model = AnnotationOverflowViewModel()
        model.xStrategy = x
        model.yStrategy = y
        #expect(model.strategy(on: .x) == x)
        #expect(model.strategy(on: .y) == y)
    }

    @Test("Given each strategy, when its name is read, then it is the one the picker shows and speaks")
    func strategyTitles() {
        #expect(AnnotationOverflowStrategy.allCases.map(\.title) == ["Disabled", "Fit to plot", "Fit to chart", "Pad scale"])
        #expect(AnnotationOverflowAxis.x.title == "Across (x)")
        #expect(AnnotationOverflowAxis.y.title == "Up and down (y)")
    }

    // MARK: Text spoken for each strategy

    @Test("Given each strategy on x, when its effect is read, then it says what happens at the side edge", arguments: [
        (AnnotationOverflowStrategy.disabled, "the label stays centred on its point and runs past the edge"),
        (.fitToPlot, "the label slides inward to stay inside the plot"),
        (.fitToChart, "the label slides inward to stay inside the chart, over the axis labels if it must"),
        (.padScale, "the scale grows past the data so the label fits over its point"),
    ])
    func xEffects(strategy: AnnotationOverflowStrategy, expected: String) {
        #expect(strategy.effect(on: .x) == expected)
    }

    @Test("Given each strategy on y, when its effect is read, then it says what happens at the top", arguments: [
        (AnnotationOverflowStrategy.disabled, "it stays above its point and runs past the top"),
        (.fitToPlot, "it moves down to stay inside the plot"),
        (.fitToChart, "it moves down to stay inside the chart"),
        (.padScale, "the scale grows above the data so it fits"),
    ])
    func yEffects(strategy: AnnotationOverflowStrategy, expected: String) {
        #expect(strategy.effect(on: .y) == expected)
    }

    @Test("Given a strategy picked for x, when the announcement is made, then it names the axis and strategy, then the headline")
    func announcesStrategyChange() throws {
        let model = AnnotationOverflowViewModel()
        for strategy in AnnotationOverflowStrategy.allCases where strategy != .padScale {
            model.xStrategy = strategy
            let spoken = try #require(model.announcement(for: .strategy(.x, from: .padScale), locale: english))
            #expect(spoken == "Across (x): \(strategy.title). \(model.headlineAndEffect(locale: english))")
            #expect(spoken.contains(strategy.effect(on: .x)))
        }
    }

    @Test("Given a strategy picked for y, when the announcement is made, then it names the axis and strategy, then the headline")
    func announcesYStrategyChange() throws {
        let model = AnnotationOverflowViewModel()
        for strategy in AnnotationOverflowStrategy.allCases where strategy != .padScale {
            model.yStrategy = strategy
            let spoken = try #require(model.announcement(for: .strategy(.y, from: .padScale), locale: english))
            #expect(spoken == "Up and down (y): \(strategy.title). \(model.headlineAndEffect(locale: english))")
            #expect(spoken.contains(strategy.effect(on: .y)))
        }
    }

    @Test("Given the labelled day moves, when the announcement is made, then it names the day picked, then the headline")
    func announcesLabelledDayChange() {
        let model = AnnotationOverflowViewModel()
        model.labelledDay = .first
        #expect(model.announcement(for: .labelledDay(from: .last), locale: english)
            == "Labelled day: First. \(model.headlineAndEffect(locale: english))")
    }

    @Test("Given a strategy change that leaves the headline the same, when it is checked, then nothing is announced")
    func strategyChangeWithSameHeadlineIsQuiet() {
        let model = AnnotationOverflowViewModel()
        model.labelledDay = .middle
        model.xStrategy = .disabled
        #expect(model.announcement(for: .strategy(.x, from: .padScale), locale: english) == nil)
        model.yStrategy = .fitToChart
        #expect(model.announcement(for: .strategy(.y, from: .padScale), locale: english) == nil)

        // The first day has room above it, so only the y strategy leaves the headline alone.
        model.labelledDay = .first
        model.yStrategy = .disabled
        #expect(model.announcement(for: .strategy(.y, from: .fitToChart), locale: english) == nil)
        model.xStrategy = .fitToPlot
        #expect(model.announcement(for: .strategy(.x, from: .disabled), locale: english) != nil)
    }

    // MARK: Room for a label past the edge

    @Test("Given both strategies disabled and the last day labelled, when room is reserved, then it is half the label's width at the trailing side and its height above")
    func reservesRoomAtTheCorner() {
        let model = AnnotationOverflowViewModel()
        model.xStrategy = .disabled
        model.yStrategy = .disabled
        let room = model.reservedRoom(for: CGSize(width: 80, height: 30))
        #expect(room == EdgeInsets(top: 30, leading: 0, bottom: 0, trailing: 40))
    }

    @Test("Given the first day labelled with x disabled, when room is reserved, then it is on the leading side only")
    func reservesRoomAtTheStart() {
        let model = AnnotationOverflowViewModel()
        model.labelledDay = .first
        model.xStrategy = .disabled
        model.yStrategy = .disabled
        #expect(model.reservedRoom(for: CGSize(width: 80, height: 30)) == EdgeInsets(top: 0, leading: 40, bottom: 0, trailing: 0))
    }

    @Test("Given no disabled strategy, or a label with room, when room is reserved, then none is")
    func reservesNoRoomOtherwise() {
        let model = AnnotationOverflowViewModel()
        let size = CGSize(width: 80, height: 30)
        #expect(model.reservedRoom(for: size) == EdgeInsets())
        model.xStrategy = .fitToChart
        model.yStrategy = .fitToPlot
        #expect(model.reservedRoom(for: size) == EdgeInsets())
        model.labelledDay = .middle
        model.xStrategy = .disabled
        model.yStrategy = .disabled
        #expect(model.reservedRoom(for: size) == EdgeInsets())
    }

    // MARK: Headline

    @Test("Given the defaults, when the headline is written, then it names the last day, its cups, and both axes' effects")
    func headlineAtTheCorner() {
        let model = AnnotationOverflowViewModel()
        #expect(model.isAtSideEdge)
        #expect(model.isHighest)
        #expect(model.headlineAndEffect(locale: english) == "Saturday, March 28, 282 cups, is labelled at the end of the x axis and is the highest point. "
            + "Across, the scale grows past the data so the label fits over its point; up and down, it moves down to stay inside the plot.")
        #expect(model.headline(locale: english) == "Saturday, March 28, 282 cups, is labelled at the end of the x axis and is the highest point.")
        #expect(model.effectNote(locale: english) == "Across, the scale grows past the data so the label fits over its point; "
            + "up and down, it moves down to stay inside the plot.")
    }

    @Test("Given the first day labelled, when the headline is written, then only the x strategy has work to do")
    func headlineAtTheStart() {
        let model = AnnotationOverflowViewModel()
        model.labelledDay = .first
        model.xStrategy = .fitToPlot
        #expect(model.isAtSideEdge)
        #expect(!model.isHighest)
        #expect(model.headlineAndEffect(locale: english) == "Sunday, March 1, 190 cups, is labelled at the start of the x axis. "
            + "Across, the label slides inward to stay inside the plot; above it there is room, so the y strategy changes nothing.")
    }

    @Test("Given the middle day labelled, when the headline is written, then it says neither strategy moves it")
    func headlineInTheMiddle() {
        let model = AnnotationOverflowViewModel()
        model.labelledDay = .middle
        #expect(!model.isAtSideEdge)
        #expect(model.headlineAndEffect(locale: english) == "Sunday, March 15, 232 cups, is labelled in the middle of the x axis. "
            + "There is room on every side, so neither strategy moves it.")
    }

    @Test("Given a middle day that is the highest, when the headline is written, then only the y strategy has work to do")
    func headlineHighestInTheMiddle() {
        let days = [100, 300, 120].enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
        let model = AnnotationOverflowViewModel(days: days)
        model.labelledDay = .middle
        model.yStrategy = .fitToChart
        #expect(model.headlineAndEffect(locale: english) == "Monday, March 2, 300 cups, is labelled in the middle of the x axis and is the highest point. "
            + "Up and down, it moves down to stay inside the chart; at the sides there is room, so the x strategy changes nothing.")
    }

    @Test("Given no days, when the screen's text is written, then it says nothing sold and there is no label")
    func emptyData() {
        let model = AnnotationOverflowViewModel(days: [])
        #expect(model.isEmpty)
        #expect(model.labelled == nil)
        #expect(!model.isAtSideEdge)
        #expect(!model.isHighest)
        #expect(model.headlineAndEffect(locale: english) == "No cups sold in March yet.")
        #expect(model.audioGraphSummary(locale: english) == "No cups sold in March yet.")
    }

    @Test("Given days of only zeros, when the headline is written, then no point is called the highest")
    func allZeros() {
        let days = (0 ..< 3).map { DailySales(day: CafeData.day($0), cups: 0) }
        let model = AnnotationOverflowViewModel(days: days)
        #expect(!model.isHighest)
        #expect(model.headlineAndEffect(locale: english).hasPrefix("Tuesday, March 3, 0 cups, is labelled at the end of the x axis."))
    }

    @Test("Given one cup on the labelled day, when the headline is written, then the count agrees in number")
    func singularCup() {
        let days = [DailySales(day: CafeData.day(0), cups: 1)]
        let model = AnnotationOverflowViewModel(days: days)
        #expect(model.headlineAndEffect(locale: english).hasPrefix("Sunday, March 1, 1 cup, is labelled"))
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let days = [DailySales(day: CafeData.day(0), cups: 1200)]
        let model = AnnotationOverflowViewModel(days: days)
        #expect(model.headline(locale: Locale(identifier: "de_DE")).contains("1.200 cups"))
    }

    // MARK: Snippets

    @Test("Given the same strategy on both axes, when the snippets are listed, then that strategy's code is shown once")
    func snippetsForOneStrategy() {
        let model = AnnotationOverflowViewModel()
        model.xStrategy = .fitToChart
        model.yStrategy = .fitToChart
        #expect(model.snippets.map(\.name) == ["overflow-annotation", "overflow-fit-to-chart"])
        #expect(model.snippets.last?.title == "Both axes: Fit to chart")
    }

    @Test("Given a different strategy on each axis, when the snippets are listed, then each axis's code follows the annotation", arguments: [
        (AnnotationOverflowStrategy.disabled, AnnotationOverflowStrategy.padScale, ["overflow-annotation", "overflow-disabled", "overflow-pad-scale"]),
        (.fitToPlot, .fitToChart, ["overflow-annotation", "overflow-fit-to-plot", "overflow-fit-to-chart"]),
        (.padScale, .fitToPlot, ["overflow-annotation", "overflow-pad-scale", "overflow-fit-to-plot"]),
    ])
    func snippetsFollowStrategies(x: AnnotationOverflowStrategy, y: AnnotationOverflowStrategy, expected: [String]) {
        let model = AnnotationOverflowViewModel()
        model.xStrategy = x
        model.yStrategy = y
        #expect(model.snippets.map(\.name) == expected)
        #expect(model.snippets.map(\.title) == ["The labelled point", "Across (x): \(x.title)", "Up and down (y): \(y.title)"])
    }

    @Test("Given the labelled day changes, when the snippets are listed, then they do not change")
    func labelledDayLeavesSnippets() {
        let model = AnnotationOverflowViewModel()
        let before = model.snippets
        model.labelledDay = .first
        #expect(model.snippets == before)
    }

    @Test("Given the built app, when its snippets are read, then every one this screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ["overflow-annotation"] + AnnotationOverflowStrategy.allCases.map(\.snippetName)
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Labels and descriptor

    @Test("Given a day, when it is written for speech and for the label, then both are the UTC day that is drawn")
    func dayWording() throws {
        let model = AnnotationOverflowViewModel()
        let last = try #require(model.labelled)
        #expect(model.spokenDay(last, locale: english) == "Saturday, March 28")
        #expect(model.shortDay(last, locale: english) == "Mar 28")
    }

    @Test("Given the Harbour days, when the descriptor is made, then it has the title, summary, days and cups with their unit")
    func descriptor() throws {
        let model = AnnotationOverflowViewModel()
        let chart = AnnotationOverflowDescriptor(model: model, locale: english).makeChartDescriptor()
        #expect(chart.title == "Cups sold each day from March 1 to March 28 at the Harbour café")
        #expect(chart.summary == "28 days. First day 190 cups, last day 282 cups, highest 282 cups on Saturday, March 28. "
            + "Labelled: Saturday, March 28.")
        let xAxis = try #require(chart.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        let yAxis = try #require(chart.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The axis the chart is given: 282 cups rounds up to 300.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(282) == "282 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(chart.series.count == 1)
        #expect(chart.series.first?.name == CafeWording.harbour)
        #expect(chart.series.first?.isContinuous == true)
        #expect(chart.series.first?.dataPoints.count == 28)
    }

    @Test("Given the Harbour days, when the caption is written, then it names the days the data covers")
    func captionNamesPeriod() {
        #expect(AnnotationOverflowViewModel().caption(locale: english) == CafeWording.harbourDaysCaption(locale: english))
        #expect(AnnotationOverflowViewModel(days: []).caption(locale: english) == "Cups sold each day at the Harbour café")
    }

    @Test("Given the labelled day moves, when the descriptor is made, then its summary names the new day")
    func descriptorFollowsLabel() {
        let model = AnnotationOverflowViewModel()
        model.labelledDay = .first
        let chart = AnnotationOverflowDescriptor(model: model, locale: english).makeChartDescriptor()
        #expect(chart.summary?.hasSuffix("Labelled: Sunday, March 1.") == true)
    }

    // MARK: Axis

    @Test("Given the text size, when the axis days are chosen, then it is every week, or every other week at accessibility sizes")
    func axisDaysFollowTextSize() {
        let model = AnnotationOverflowViewModel()
        #expect(model.axisDays(at: .large) == [0, 7, 14, 21].map { CafeData.day($0) })
        #expect(model.axisDays(at: .xxxLarge).count == 4)
        #expect(model.axisDays(at: .accessibility1) == [0, 14].map { CafeData.day($0) })
        #expect(model.axisDays(at: .accessibility5) == [0, 14].map { CafeData.day($0) })
    }

    @Test("Given the text size, when the axis format is chosen, then it writes month and day, or the day alone at accessibility sizes")
    func axisFormatFollowsTextSize() {
        let model = AnnotationOverflowViewModel()
        let day = CafeData.day(7)
        #expect(day.formatted(model.axisFormat(at: .large, locale: english)) == "Mar 8")
        #expect(day.formatted(model.axisFormat(at: .accessibility3, locale: english)) == "8")
    }
}
