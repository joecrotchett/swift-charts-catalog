import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct StackingTests {
    private func summary(
        _ method: StackingMethod = .standard, mark: StackingMark = .bars, negative: Bool = false, mistake: Bool = false,
        orders: [DrinkOrder] = CafeData.drinkOrders, changes: [QuarterlyChange] = CafeData.quarterlyChanges
    ) -> StackingSummary {
        let viewModel = StackingViewModel(orders: orders, changes: changes)
        viewModel.method = method
        viewModel.mark = mark
        viewModel.usesNegativeValues = negative
        viewModel.isShowingMistake = mistake
        return viewModel.summary
    }

    // MARK: State

    @Test("Given a new screen, when it opens, then it shows coloured standard bars of the drink orders")
    func startsWithColouredStandardBars() {
        let viewModel = StackingViewModel()

        #expect(viewModel.method == .standard)
        #expect(viewModel.mark == .bars)
        #expect(!viewModel.usesNegativeValues)
        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.data.categories == ["Latte", "Tea", "Mocha"])
        #expect(viewModel.data.seriesNames == ["Small", "Medium", "Large"])
    }

    @Test("Given the negative values switch, when it is turned on, then the data is the quarterly changes by café")
    func negativeSwitchChangesTheData() {
        let viewModel = StackingViewModel()
        viewModel.usesNegativeValues = true

        #expect(viewModel.data.isChange)
        #expect(viewModel.data.categories == ["Q1", "Q2", "Q3", "Q4"])
        #expect(viewModel.data.seriesNames == ["Harbour", "Station"])
        #expect(viewModel.data.rows.contains { $0.value < 0 })
    }

    @Test("Given areas, when the data is read, then it is the cafés' cups by week, an ordered x, and bars stay on drinks")
    func areasAreDrawnOverAnOrderedX() {
        let viewModel = StackingViewModel()
        #expect(!viewModel.data.isOrdered)
        viewModel.mark = .areas

        #expect(viewModel.data.isOrdered)
        #expect(viewModel.data.categories == ["Week 1", "Week 2", "Week 3", "Week 4"])
        #expect(viewModel.data.seriesNames == ["Harbour", "Station"])
        let firstWeek = CafeData.storeSales[0].days.prefix(7).map(\.cups).reduce(0, +)
        #expect(viewModel.data.rows.first == StackRow(category: "Week 1", series: "Harbour", value: firstWeek))
        #expect(viewModel.summary.caption == "Cups sold each week, by café")
        #expect(summary(.normalized, mark: .areas).caption == "Share of each week's cups, by café")

        viewModel.usesNegativeValues = true
        #expect(viewModel.data.isOrdered)
        #expect(viewModel.data.categories == ["Q1", "Q2", "Q3", "Q4"])
    }

    @Test("Given a partial last week, when the weeks are made, then it is its own position holding the days there are")
    func weeksKeepAPartialWeek() {
        let days = (0 ..< 9).map { DailySales(day: CafeData.day($0), cups: 10) }
        let data = StackingData.weeks([StoreSales(store: "Harbour", days: days)])

        #expect(data.rows.map(\.value) == [70, 20])
        #expect(StackingData.weeks([]).isEmpty)
    }

    @Test("Given the mark, when the explanation is written, then only areas add that they want an ordered x")
    func explanationFollowsTheMark() {
        let viewModel = StackingViewModel()
        #expect(!viewModel.explanation.contains("ordered x"))
        viewModel.mark = .areas

        #expect(viewModel.explanation.hasSuffix(StackingViewModel.areasExplanation))
        #expect(viewModel.explanation.contains("Areas want an ordered x"))
    }

    // MARK: Announcement

    @Test("Given bars, when the mark changes to areas, then the announcement says so and what the chart now shows")
    func markChangeIsAnnounced() {
        let areas = summary(mark: .areas)
        let announcement = areas.announcement(after: summary())

        #expect(announcement.hasPrefix("Marks changed to areas. The data changed. Cups sold each week, by café. "))
        #expect(announcement.hasSuffix(areas.headline))
        // The quarterly changes are drawn by both marks, so there only the mark changed.
        #expect(
            summary(mark: .areas, negative: true).announcement(after: summary(negative: true))
                .hasPrefix("Marks changed to areas. Change in cups on last year, by quarter and café. ")
        )
    }

    @Test("Given each other control, when it changes, then the announcement names that change and gives the new caption and headline")
    func everyControlIsAnnounced() {
        let start = summary()

        #expect(
            summary(.normalized).announcement(after: start)
                == "Stacking method changed to normalized. Share of each drink's cups, by size. "
                + "Every stack fills to 100%: the largest share is Medium at Latte, 45%."
        )
        #expect(
            summary(negative: true).announcement(after: start)
                .hasPrefix("The data changed. Change in cups on last year, by quarter and café. Rises stack up")
        )
        #expect(
            summary(mistake: true).announcement(after: start)
                .hasPrefix("Colour removed. Cups sold today, by drink and size. Without colour")
        )
        #expect(
            start.announcement(after: summary(mistake: true))
                == "Colour restored. Cups sold today, by drink and size. Pieces stack up from zero: the tallest reaches 164 cups at Tea."
        )
    }

    // MARK: Snippets

    @Test(
        "Given a mark and the mistake switch, when the snippets are listed, then they are the code for that chart and the methods",
        arguments: [
            (StackingMark.bars, false, "stacking-bars"), (.areas, false, "stacking-areas"),
            (.bars, true, "stacking-mistake-bars"), (.areas, true, "stacking-mistake-areas"),
        ]
    )
    func snippetsFollowTheControls(mark: StackingMark, mistake: Bool, name: String) {
        let viewModel = StackingViewModel()
        viewModel.mark = mark
        viewModel.isShowingMistake = mistake

        #expect(viewModel.snippets.map(\.name) == [name, "stacking-method"])
    }

    @Test("Given every stacking method and data set, when the snippets are listed, then they do not change", arguments: StackingMethod.allCases)
    func snippetsIgnoreMethodAndData(method: StackingMethod) {
        let viewModel = StackingViewModel()
        viewModel.method = method
        viewModel.usesNegativeValues = true

        #expect(viewModel.snippets.map(\.name) == ["stacking-bars", "stacking-method"])
    }

    @Test("Given every snippet the screen can show, when the bundle is read, then each exists")
    func snippetsExistInTheBundle() throws {
        let store = try SnippetStore(bundle: .main)
        let names = ["stacking-bars", "stacking-areas", "stacking-mistake-bars", "stacking-mistake-areas", "stacking-method"]

        for name in names {
            #expect(store[name]?.file == "Composition/StackingScreen.swift", "\(name) is missing")
        }
    }

    // MARK: What is drawn

    @Test("Given standard stacking, when a stack is placed, then each piece starts where the one before it ends")
    func standardStacksFromZero() {
        let segments = summary().segments(in: "Tea")

        #expect(segments.map(\.start) == [0, 71, 133])
        #expect(segments.map(\.end) == [71, 133, 164])
    }

    @Test("Given standard stacking of rises and falls, when a stack is placed, then rises go up from zero and falls go down")
    func standardDivergesFromZero() {
        let summary = summary(negative: true)

        #expect(summary.segments(in: "Q1").map(\.end) == [420, -180])
        #expect(summary.extent(of: "Q3") == 0 ... 530)
        #expect(summary.valueRange == -180 ... 610)
    }

    @Test("Given normalized stacking, when a stack is placed, then it fills to 100")
    func normalizedFillsTo100() {
        let summary = summary(.normalized)

        for drink in summary.data.categories {
            #expect(abs(summary.extent(of: drink).upperBound - 100) < 0.0001)
        }
        #expect(summary.valueRange.lowerBound == 0)
    }

    @Test("Given normalized stacking of rises and falls, when a stack is placed, then its longer side reaches 100 and the other keeps its proportion")
    func normalizedScalesToTheLongerSide() {
        let changes = [
            QuarterlyChange(quarter: "Up", store: "Harbour", change: 40), QuarterlyChange(quarter: "Up", store: "Station", change: -10),
            QuarterlyChange(quarter: "Down", store: "Harbour", change: 10), QuarterlyChange(quarter: "Down", store: "Station", change: -40),
        ]
        let summary = summary(.normalized, negative: true, changes: changes)

        #expect(summary.extent(of: "Up") == -25 ... 100)
        #expect(summary.extent(of: "Down") == -100 ... 25)
    }

    @Test("Given center stacking, when a stack is placed, then it reaches as far below zero as above")
    func centerIsSymmetric() {
        #expect(summary(.center).extent(of: "Tea") == -82 ... 82)
        #expect(summary(.center, negative: true).extent(of: "Q2") == -350 ... 350)
    }

    @Test("Given no stacking, when the pieces are placed, then every one starts at zero")
    func unstackedStartsAtZero() {
        let summary = summary(.unstacked)

        #expect(summary.allSegments.allSatisfy { $0.start == 0 })
        #expect(summary.extent(of: "Tea") == 0 ... 71)
    }

    // MARK: Headline

    @Test("Given the drink orders, when the method changes, then the headline's figure is one that method draws")
    func headlineFollowsTheMethod() {
        #expect(summary().headline == "Pieces stack up from zero: the tallest reaches 164 cups at Tea.")
        #expect(summary(.normalized).headline == "Every stack fills to 100%: the largest share is Medium at Latte, 45%.")
        #expect(summary(.center).headline == "Every stack is centred on zero: the widest, Tea, reaches 82 cups either side.")
        #expect(summary(.unstacked).headline == "Every piece starts at zero: the longest is Small at Tea, 71 cups.")
    }

    @Test("Given the quarterly changes, when the method changes, then the headline says where the stacks reach above and below zero")
    func headlineFollowsTheMethodWithNegativeValues() {
        #expect(
            summary(negative: true).headline
                == "Rises stack up from zero and falls stack down: the highest reaches 610 cups at Q2, the lowest 180 cups below zero at Q1."
        )
        #expect(
            summary(.normalized, negative: true).headline
                == "Each stack is scaled so its longer side reaches 100%: the shorter side reaches furthest at Q4, 46%."
        )
        #expect(
            summary(.center, negative: true).headline
                == "Every stack is centred on zero: the widest, Q2, reaches 350 cups either side."
        )
        #expect(
            summary(.unstacked, negative: true).headline
                == "Every piece starts at zero: the longest rise is Harbour at Q2, 610 cups, and the longest fall Station at Q1, 180 cups."
        )
    }

    @Test("Given the colour removed, when the headline is written, then it says so and names no piece", arguments: StackingMethod.allCases)
    func mistakeHeadlineNamesNoPiece(method: StackingMethod) {
        let headline = summary(method, mistake: true).headline

        #expect(headline.hasPrefix("Without colour, nothing says which piece is which size."))
        for size in ["Small", "Medium", "Large"] {
            #expect(!headline.contains(size))
        }
    }

    @Test("Given the colour removed, when the headline is written, then its figure is still one the chart draws")
    func mistakeHeadlineKeepsADrawnFigure() {
        #expect(summary(mistake: true).headline.hasSuffix("Pieces stack up from zero: the tallest reaches 164 cups at Tea."))
        #expect(summary(.normalized, mistake: true).headline.hasSuffix("Every stack fills to 100%, whatever its total."))
        #expect(summary(.unstacked, mistake: true).headline.hasSuffix("Every piece starts at zero and they overlap: the tallest reaches 71 cups at Tea."))
    }

    @Test("Given two stacks tied for the tallest, when the headline is written, then it names both")
    func tieNamesBoth() {
        let orders = [
            DrinkOrder(drink: "Latte", size: "Small", cups: 30), DrinkOrder(drink: "Latte", size: "Large", cups: 20),
            DrinkOrder(drink: "Tea", size: "Small", cups: 10), DrinkOrder(drink: "Tea", size: "Large", cups: 40),
        ]

        #expect(summary(orders: orders).headline == "Pieces stack up from zero: the tallest reaches 50 cups at Latte and Tea.")
    }

    @Test("Given only falls, when the headline is written, then it speaks of the lowest stack and not of a tallest")
    func onlyFalls() {
        let changes = [
            QuarterlyChange(quarter: "Q1", store: "Harbour", change: -10), QuarterlyChange(quarter: "Q1", store: "Station", change: -30),
        ]

        #expect(
            summary(negative: true, changes: changes).headline
                == "Rises stack up from zero and falls stack down: the lowest reaches 40 cups below zero at Q1."
        )
        #expect(
            summary(.normalized, negative: true, changes: changes).headline
                == "Each stack is scaled so that it reaches 100%, up or down from zero."
        )
    }

    @Test("Given no rows or only zeros, when the words are written, then every setting says there is nothing to stack", arguments: StackingMethod.allCases)
    func emptyAndZeroDataSaySo(method: StackingMethod) {
        let zeros = [DrinkOrder(drink: "Latte", size: "Small", cups: 0), DrinkOrder(drink: "Latte", size: "Large", cups: 0)]

        for orders in [[], zeros] {
            for mistake in [false, true] {
                let summary = summary(method, mistake: mistake, orders: orders)
                #expect(summary.data.isEmpty)
                #expect(summary.headline == "Nothing to stack yet.")
                #expect(summary.audioGraphSummary == "Nothing to stack yet.")
            }
        }
    }

    @Test("Given the method or the data, when the caption is written, then it says what the value axis measures")
    func captionFollowsTheAxis() {
        #expect(summary().caption == "Cups sold today, by drink and size")
        #expect(summary(.normalized).caption == "Share of each drink's cups, by size")
        #expect(summary(negative: true).caption == "Change in cups on last year, by quarter and café")
        #expect(summary(.normalized, negative: true).caption == "Change in cups on last year, each quarter scaled to 100%")
    }

    // MARK: Accessibility

    @Test("Given a coloured piece, when its value is written, then it has its unit, and for a change the direction")
    func pieceValues() {
        let tea = StackRow(category: "Tea", series: "Small", value: 71)
        let station = StackRow(category: "Q1", series: "Station", value: -180)

        #expect(summary().valueText(for: tea) == "71 cups")
        #expect(summary(.center).valueText(for: tea) == "71 cups")
        #expect(summary(.normalized).valueText(for: tea) == "43 percent")
        #expect(summary(negative: true).valueText(for: station) == "180 cups fewer")
        #expect(summary(negative: true).valueText(for: StackRow(category: "Q1", series: "Harbour", value: 420)) == "420 cups more")
    }

    @Test("Given normalized changes, when a piece's value is written, then it is a rise or a fall and its share of the quarter's scale, not a percentage change")
    func normalizedChangeValues() throws {
        let summary = summary(.normalized, negative: true)

        #expect(summary.valueText(for: StackRow(category: "Q1", series: "Harbour", value: 420)) == "a rise, 100 percent of the quarter's scale")
        #expect(summary.valueText(for: StackRow(category: "Q1", series: "Station", value: -180)) == "a fall, 43 percent of the quarter's scale")
        for row in summary.data.rows {
            #expect(!summary.valueText(for: row).contains("more"))
            #expect(!summary.valueText(for: row).contains("fewer"))
        }
        let descriptor = StackingChartDescriptor(summary: summary).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Percent, scaled within each quarter")
        #expect(yAxis.valueDescriptionProvider(-42.9) == "a fall, 43 percent of the quarter's scale")
        #expect(yAxis.valueDescriptionProvider(0) == "no change")
        #expect(descriptor.title == "Change in cups on last year, each quarter scaled to 100%, each stack scaled so its longer side is 100 percent")
    }

    @Test("Given a count of one, when it is written, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        #expect(StackingSummary.cupsText(1) == "1 cup")
        #expect(StackingSummary.cupsText(164) == "164 cups")
    }

    @Test("Given the colour removed, when a position's value is written, then it describes one shape whose pieces have no names")
    func uncolouredValues() {
        #expect(summary(mistake: true).uncolouredValueText(for: "Tea") == "164 cups, in 3 pieces with no names")
        #expect(summary(.normalized, mistake: true).uncolouredValueText(for: "Tea") == "100 percent, in 3 pieces with no names")
        #expect(summary(.unstacked, mistake: true).uncolouredValueText(for: "Tea") == "3 pieces with no names, overlapping, reaching 71 cups")
        #expect(
            summary(negative: true, mistake: true).uncolouredValueText(for: "Q1")
                == "from 180 cups below zero to 420 cups above, in 2 pieces with no names"
        )
    }

    @Test("Given coloured bars, when the chart descriptor is made, then it has a title, a summary, and a named series of separate values per size")
    func descriptorForColouredBars() throws {
        let summary = summary()
        let descriptor = StackingChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today, by drink and size, stacked from zero")
        #expect(descriptor.summary == "3 drink positions, 3 pieces at each. Pieces stack up from zero: the tallest reaches 164 cups at Tea.")
        #expect(descriptor.series.map(\.name) == ["Small", "Medium", "Large"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 3 })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Drink")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        // The tallest stack is 164; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
    }

    @Test("Given the colour removed, when the chart descriptor is made, then there is one series that names no size, with one point per drink at the top of its bar")
    func descriptorForTheMistake() throws {
        let summary = summary(mistake: true)
        let descriptor = StackingChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold today, by drink and size, stacked from zero, drawn in one colour")
        #expect(descriptor.summary?.contains("Drawn in one colour, so the pieces have no names.") == true)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Every size, in one colour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 3)
        #expect(summary.uncolouredSeries.first?.values == [128, 164, 92])
        #expect(self.summary(.unstacked, mistake: true).uncolouredSeries.first?.values == [58, 71, 41])
    }

    @Test("Given the colour removed from stacks that reach below zero, when the chart descriptor is made, then a second series gives each stack's bottom")
    func descriptorForTheMistakeBelowZero() throws {
        let summary = summary(negative: true, mistake: true)
        let descriptor = StackingChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.series.map(\.name) == ["Top of every stack, in one colour", "Bottom of every stack, in one colour"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 4 })
        #expect(summary.uncolouredSeries.map(\.values) == [[420, 610, 530, 260], [-180, -90, 0, -120]])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.valueDescriptionProvider(-180) == "180 cups below zero")
        #expect(yAxis.valueDescriptionProvider(420) == "420 cups")
    }

    @Test("Given a mark and its data, when the chart descriptor is made, then a series is continuous only for areas over an ordered x")
    func continuityFollowsMarkAndOrder() {
        #expect(!summary().isContinuous)
        #expect(!summary(negative: true).isContinuous)
        #expect(summary(mark: .areas).isContinuous)
        #expect(summary(mark: .areas, negative: true).isContinuous)
        // Areas handed positions in no order are not a continuous measure.
        let unordered = StackingSummary(data: .orders(CafeData.drinkOrders), method: .standard, mark: .areas, isShowingMistake: false)
        #expect(!unordered.isContinuous)
        let descriptor = StackingChartDescriptor(summary: summary(mark: .areas, mistake: true)).makeChartDescriptor()
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 4)
    }

    @Test("Given normalized or negative data, when the chart descriptor is made, then its values and range are what is drawn")
    func descriptorFollowsTheDrawnScale() throws {
        let normalized = StackingChartDescriptor(summary: summary(.normalized)).makeChartDescriptor()
        let normalizedAxis = try #require(normalized.yAxis)
        #expect(normalizedAxis.title == "Percent, scaled within each drink")
        #expect(normalizedAxis.valueDescriptionProvider(43.3) == "43 percent")
        #expect(normalizedAxis.range == 0 ... 100)

        let diverging = StackingChartDescriptor(summary: summary(negative: true)).makeChartDescriptor()
        let divergingAxis = try #require(diverging.yAxis)
        // Drawn from -180 to 610, on an axis rounded out to the step of 200.
        #expect(divergingAxis.range == -200 ... 800)
        #expect(divergingAxis.valueDescriptionProvider(-180) == "180 cups fewer")
        #expect(diverging.series.map(\.name) == ["Harbour", "Station"])
        #expect(diverging.series.last?.dataPoints.count == 4)
        // A point's value is the piece's own length, signed: what the descriptor hands the Audio Graph.
        #expect(summary(negative: true).signedLength(of: StackRow(category: "Q1", series: "Station", value: -180)) == -180)
    }
}
