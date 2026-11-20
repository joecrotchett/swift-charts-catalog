import Accessibility
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct DynamicTypeChartTests {
    private let english = Locale(identifier: "en_US")
    private let march = (0 ..< 28).map { CafeData.day($0) }

    private func words(_ viewModel: DynamicTypeChartViewModel = DynamicTypeChartViewModel()) -> DynamicTypeChartWords {
        viewModel.words(locale: english)
    }

    // MARK: Label stride and format for each size

    @Test(
        "Given each text size, when the date labels are chosen, then the stride and format follow it",
        arguments: [
            (DynamicTypeSize.xSmall, 7, DynamicTypeChartDateLabels.Style.monthAndDay),
            (.small, 7, .monthAndDay), (.medium, 7, .monthAndDay), (.large, 7, .monthAndDay),
            (.xLarge, 7, .monthAndDay), (.xxLarge, 7, .monthAndDay), (.xxxLarge, 7, .monthAndDay),
            (.accessibility1, 14, .monthAndDay), (.accessibility2, 14, .monthAndDay),
            (.accessibility3, 14, .monthAndDay), (.accessibility4, 14, .dayOnly), (.accessibility5, 14, .dayOnly),
        ]
    )
    func dateLabelsForSize(size: DynamicTypeSize, daysPerLabel: Int, style: DynamicTypeChartDateLabels.Style) {
        let labels = DynamicTypeChartDateLabels.forSize(size)

        #expect(labels.daysPerLabel == daysPerLabel)
        #expect(labels.style == style)
    }

    @Test("Given the offered sizes, when the labels are written, then they read as drawn at each size")
    func labelTextForOfferedSizes() {
        let expected: [DynamicTypeChartTextSize: [String]] = [
            .large: ["Mar 1", "Mar 8", "Mar 15", "Mar 22"],
            .xxxLarge: ["Mar 1", "Mar 8", "Mar 15", "Mar 22"],
            .accessibility1: ["Mar 1", "Mar 15"],
            .accessibility3: ["Mar 1", "Mar 15"],
            .accessibility5: ["1", "15"],
        ]
        for size in DynamicTypeChartTextSize.allCases {
            guard let forced = size.dynamicTypeSize else { continue }
            let labels = DynamicTypeChartDateLabels.forSize(forced)
            let text = labels.labelledDays(of: march).map { $0.formatted(labels.format(locale: english)) }
            #expect(text == expected[size], "\(size)")
        }
    }

    @Test("Given the mistake, when its labels are written, then they stay weekly with the month at every size")
    func unadjustedLabelsStayWeekly() {
        let labels = DynamicTypeChartUnadjusted.dateLabels
        let text = labels.labelledDays(of: march).map { $0.formatted(labels.format(locale: english)) }

        #expect(text == ["Mar 1", "Mar 8", "Mar 15", "Mar 22"])
        #expect(DynamicTypeChartUnadjusted.valueLabels == nil)
        #expect(DynamicTypeChartUnadjusted.legend == .automatic)
        #expect(DynamicTypeChartUnadjusted.growsWithText == false)
    }

    @Test("Given a day at midnight UTC, when it is labelled, then it is the same day in a zone west of UTC")
    func labelsUseTheDataTimeZone() {
        let labels = DynamicTypeChartDateLabels.forSize(.large)
        let local = Locale(identifier: "en_US@timezone=America/Chicago")

        #expect(CafeData.day(0).formatted(labels.format(locale: local)) == "Mar 1")
    }

    @Test(
        "Given each text size, when the value axis's labels are chosen, then the accessibility sizes get three exact values",
        arguments: [
            (DynamicTypeSize.large, [Double]?.none, [Double]?.none), (.xxxLarge, nil, nil),
            (.accessibility1, [0, 150, 300], [0, 100, 200]), (.accessibility5, [0, 150, 300], [0, 100, 200]),
        ]
    )
    func valueLabels(size: DynamicTypeSize, dates: [Double]?, bars: [Double]?) {
        #expect(DynamicTypeChartValueLabels.values(for: size, domain: 0 ... 300) == dates)
        #expect(DynamicTypeChartValueLabels.values(for: size, domain: 0 ... 200) == bars)
    }

    @Test("Given a domain that does not halve to a round fifty, when the labels are chosen, then they keep a step of fifty")
    func valueLabelsRoundStep() {
        #expect(DynamicTypeChartValueLabels.values(for: .accessibility3, domain: 0 ... 350) == [0, 200])
        #expect(DynamicTypeChartValueLabels.values(for: .accessibility3, domain: 0 ... 50) == [0, 50])
    }

    // MARK: Text size

    @Test("Given the screen opens, when nothing is chosen, then the chart follows the device's own text size")
    func defaultForcesNothing() {
        let viewModel = DynamicTypeChartViewModel()

        #expect(viewModel.textSize == .device)
        #expect(viewModel.textSize.dynamicTypeSize == nil)
        #expect(viewModel.chartEnvironment == ChartEnvironment.device)
        #expect(DynamicTypeChartTextSize.allCases.first == .device)
    }

    @Test("Given a forced size, when the chart's environment is made, then it forces that size alone")
    func forcedSize() {
        let viewModel = DynamicTypeChartViewModel()
        viewModel.textSize = .accessibility5

        #expect(viewModel.chartEnvironment == ChartEnvironment(dynamicTypeSize: .accessibility5))
    }

    @Test(
        "Given the mistake below Accessibility 1, when its note is written, then it says nothing goes wrong yet",
        arguments: [DynamicTypeSize.large, .xxxLarge]
    )
    func mistakeNoteBelowAccessibility(size: DynamicTypeSize) {
        for kind in DynamicTypeChartKind.allCases {
            #expect(DynamicTypeChartMistakeNote.text(for: kind, size: size).hasPrefix("At this text size nothing goes wrong yet"))
        }
    }

    @Test(
        "Given the mistake from Accessibility 1 up, when its note is written, then it says only what goes wrong",
        arguments: [DynamicTypeSize.accessibility1, .accessibility5]
    )
    func mistakeNoteAtAccessibility(size: DynamicTypeSize) {
        #expect(DynamicTypeChartMistakeNote.text(for: .dates, size: size).hasPrefix("A label every week"))
        #expect(DynamicTypeChartMistakeNote.text(for: .bars, size: size).hasPrefix("The chart keeps the panel's fixed height"))
    }

    // MARK: Data

    @Test("Given Harbour's days, when they are split by drink, then every day adds up to its total, in drink order")
    func splitKeepsTotals() {
        let rows = DynamicTypeChartDrinkDay.split(CafeData.harbourSales, by: CafeData.drinkSales)

        for day in CafeData.harbourSales {
            #expect(rows.filter { $0.day == day.day }.map(\.cups).reduce(0, +) == day.cups)
        }
        #expect(Array(rows.prefix(5)).map(\.drink) == CafeData.drinkSales.map(\.drink))
        #expect(rows.allSatisfy { $0.cups >= 0 })
    }

    @Test("Given 28 days, when they are cut into weeks, then there are four, each labelled with its first and last day")
    func weeksAndTheirLabels() {
        let words = words()

        #expect(words.weeks.count == 4)
        #expect(words.weeks.map(words.weekLabel) == [
            "March 1 to March 7", "March 8 to March 14", "March 15 to March 21", "March 22 to March 28",
        ])
        #expect(words.weeks.allSatisfy { $0.rows.count == 35 })
    }

    @Test("Given a week, when its value is written, then it gives each drink's cups and the week's total")
    func weekValue() throws {
        let words = words()
        let week = try #require(words.weeks.first)
        let total = week.rows.map(\.cups).reduce(0, +)
        let value = words.weekValue(week)

        #expect(value.hasPrefix("Latte "))
        #expect(value.contains(", and Americano "))
        #expect(value.hasSuffix(". \(CafeWording.cups(total, locale: english)) in total."))
    }

    // MARK: Headlines and words

    @Test("Given the sample data, when the headlines are written, then each names the largest value drawn")
    func headlines() {
        let words = words()

        #expect(words.datesHeadline == "Busiest day: March 28, with 282 cups.")
        #expect(words.barsHeadline == "Tea sold the most: 164 cups.")
        #expect(words.datesCaption == "Cups a day by drink at the Harbour café, March 2026")
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func tiedDays() {
        let days = [DailySales(day: CafeData.day(0), cups: 90), DailySales(day: CafeData.day(1), cups: 90)]
        let words = words(DynamicTypeChartViewModel(days: days))

        #expect(words.datesHeadline == "Busiest day: March 1 and March 2, with 90 cups.")
    }

    @Test("Given nothing sold, when the screen is shown, then each chart is a placeholder and the words say so")
    func nothingSold() {
        let zeroDays = [DailySales(day: CafeData.day(0), cups: 0)]
        let zeroDrinks = [DrinkSales(drink: "Tea", cups: 0)]
        let viewModel = DynamicTypeChartViewModel(days: zeroDays, drinks: zeroDrinks)
        let words = words(viewModel)

        #expect(viewModel.isEmpty)
        viewModel.kind = .bars
        #expect(viewModel.isEmpty)
        #expect(words.datesHeadline == "No cups sold on these days.")
        #expect(words.barsHeadline == "No cups sold yet today.")
        #expect(words.datesDescriptorSummary == "No cups sold on these days.")
        #expect(words.barsDescriptorSummary == "No cups sold yet today.")
    }

    @Test("Given nothing sold, when the chart switches, then the placeholder is announced, not a chart")
    func emptyAnnouncement() {
        let words = words(DynamicTypeChartViewModel(
            days: [DailySales(day: CafeData.day(0), cups: 0)], drinks: [DrinkSales(drink: "Tea", cups: 0)]
        ))

        #expect(words.isEmpty(for: .dates))
        #expect(words.announcement(for: .bars) == "No sales yet, so no chart is shown. No cups sold yet today.")
        #expect(words.announcement(for: .dates) == "No sales yet, so no chart is shown. No cups sold on these days.")
    }

    @Test("Given each chart, when the placeholder's description is written, then it does not repeat the headline")
    func placeholderDoesNotRepeatHeadline() {
        let words = words(DynamicTypeChartViewModel(days: [], drinks: []))

        for kind in DynamicTypeChartKind.allCases {
            #expect(words.placeholderDescription(for: kind) != words.headline(for: kind))
        }
    }

    @Test("Given one cup, when the words are written, then the count agrees in number")
    func oneCupAgrees() {
        let words = words(DynamicTypeChartViewModel(
            days: [DailySales(day: CafeData.day(0), cups: 1)], drinks: [DrinkSales(drink: "Tea", cups: 1)]
        ))

        #expect(words.datesHeadline == "Busiest day: March 1, with 1 cup.")
        #expect(words.barsHeadline == "Tea sold the most: 1 cup.")
        #expect(words.barValue(DrinkSales(drink: "Tea", cups: 1)) == "1 cup")
    }

    @Test("Given a switch of chart, when it is announced, then it says what changed and then the headline")
    func announcement() {
        let words = words()

        #expect(words.announcement(for: .bars) == "Showing horizontal bars of cups by drink. Tea sold the most: 164 cups.")
        #expect(words.announcement(for: .dates) == "Showing cups a day, stacked by drink. Busiest day: March 28, with 282 cups.")
    }

    @Test("Given the sample data, when the value domains are worked out, then they run from zero to the next fifty")
    func domains() {
        let words = words()

        #expect(words.dateValueDomain == 0 ... 300)
        #expect(words.barValueDomain == 0 ... 200)
        #expect(DynamicTypeChartWords.roundedDomain([]) == 0 ... 50)
    }

    @Test("Given the bars, when they are ordered, then they are ranked from most to fewest")
    func barsRanked() {
        #expect(DynamicTypeChartViewModel().drinks.map(\.drink) == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
    }

    // MARK: Descriptors

    @Test("Given the stacked bars, when the descriptor is made, then it has every day, a series per drink and the drawn range")
    func datesDescriptor() throws {
        let descriptor = DynamicTypeChartDatesDescriptor(words: words()).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups a day by drink at the Harbour café, March 2026")
        #expect(descriptor.summary?.hasPrefix("28 days, 5 drinks, ") == true)
        #expect(descriptor.summary?.contains("Busiest: March 28, 282 cups.") == true)
        #expect(xAxis.categoryOrder.first == "March 1")
        #expect(xAxis.categoryOrder.count == 28)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.map(\.name) == ["Latte", "Tea", "Mocha", "Cocoa", "Americano"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 28 })
    }

    @Test("Given the horizontal bars, when the descriptor is made, then the drinks are its categories in drawn order")
    func barsDescriptor() throws {
        let descriptor = DynamicTypeChartBarsDescriptor(words: words()).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "5 drinks, 551 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Americano", "Mocha", "Cocoa"])
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
    }

    // MARK: Snippets

    @Test(
        "Given each chart and mistake state, when the code is shown, then it shows that state's snippets",
        arguments: [
            (DynamicTypeChartKind.dates, false, [
                "dynamic-type-dates-chart", "dynamic-type-label-rule", "dynamic-type-legend", "dynamic-type-height",
            ]),
            (.dates, true, ["dynamic-type-dates-chart", "dynamic-type-unadjusted"]),
            (.bars, false, ["dynamic-type-bars-chart", "dynamic-type-bar-height"]),
            (.bars, true, ["dynamic-type-bars-chart", "dynamic-type-unadjusted"]),
        ]
    )
    func snippetsForState(kind: DynamicTypeChartKind, isShowingMistake: Bool, names: [String]) throws {
        let viewModel = DynamicTypeChartViewModel()
        viewModel.kind = kind
        viewModel.isShowingMistake = isShowingMistake
        let store = try SnippetStore()

        #expect(viewModel.snippets.map(\.name) == names)
        for name in names {
            #expect(store[name] != nil, "\(name)")
        }
    }
}
