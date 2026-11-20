import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct ValueTypesTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ type: ValueTypesXType, sales: [DailySales]? = nil) -> ValueTypesSummary {
        let model = sales.map { ValueTypesViewModel(sales: $0) } ?? ValueTypesViewModel()
        model.xType = type
        return model.summary(locale: english)
    }

    @Test("Given a new screen, when it opens, then the day is a String over the first week")
    func startsAsString() {
        let model = ValueTypesViewModel()

        #expect(model.xType == .string)
        #expect(model.sales == Array(CafeData.harbourSales.prefix(7)))
    }

    @Test("Given the first week, when it is shaped, then each day carries a name, a number and its date")
    func daysCarryAllThreeTypes() {
        let days = ValueTypesViewModel().days(locale: english)

        #expect(days.map(\.name) == ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"])
        #expect(days.map(\.number) == Array(1 ... 7))
        #expect(days.map(\.date) == (0 ..< 7).map(CafeData.day))
    }

    @Test("Given each type, when the snippets are listed, then they name that type's code")
    func snippetsFollowType() {
        let model = ValueTypesViewModel()
        #expect(model.snippets.map(\.name) == ["value-types-string"])
        model.xType = .number
        #expect(model.snippets.map(\.name) == ["value-types-number"])
        model.xType = .date
        #expect(model.snippets.map(\.name) == ["value-types-date", "value-types-date-axis"])
    }

    @Test("Given the built app, when every type's snippets are looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        for type in ValueTypesXType.allCases {
            for reference in type.snippets {
                #expect(store[reference.name] != nil, "\(reference.name)")
            }
        }
        #expect(store["value-types-date"]?.code.contains("unit: .day, calendar: CafeData.calendar") == true)
    }

    @Test("Given each type, when the headline is written, then it names the busiest day as the axis draws it")
    func headlinePerType() {
        #expect(summary(.string).headline == "Most cups: Saturday, 219 cups.")
        #expect(summary(.number).headline == "Most cups: day 7, 219 cups.")
        #expect(summary(.date).headline == "Most cups: March 7, 219 cups.")
    }

    @Test("Given a tie, when the headline is written, then it names both days and says the figure is each one's")
    func headlineTie() {
        let sales = [DailySales(day: CafeData.day(0), cups: 40), DailySales(day: CafeData.day(1), cups: 40)]

        #expect(summary(.number, sales: sales).headline == "Most cups: day 1 and day 2, 40 cups each.")
    }

    @Test("Given the number type, when the axis marks are chosen, then the day the headline names is labelled")
    func numberAxisLabelsHeadlineDay() {
        let words = summary(.number)

        #expect(words.numberAxisValues == Array(1 ... 7))
        for day in words.busiestDays {
            #expect(words.numberAxisValues.contains(day.number))
        }
    }

    @Test(
        "Given a text size, when the date axis is labelled, then every day is labelled until the accessibility sizes and every other day from there",
        arguments: [(DynamicTypeSize.large, 1), (.xxxLarge, 1), (.accessibility1, 2), (.accessibility5, 2)]
    )
    func dateLabelsThinAtAccessibilitySizes(size: DynamicTypeSize, daysPerLabel: Int) {
        #expect(ValueTypesSummary.daysPerDateLabel(at: size) == daysPerLabel)
    }

    @Test(
        "Given a text size, when a date label is written, then it names the month until accessibility 3 and only the day from there",
        arguments: [(DynamicTypeSize.large, true), (.accessibility2, true), (.accessibility3, false), (.accessibility5, false)]
    )
    func dateLabelsDropMonthAtLargestSizes(size: DynamicTypeSize, namesMonth: Bool) {
        #expect(ValueTypesSummary.dateLabelsNameMonth(at: size) == namesMonth)
    }

    @Test("Given one cup at most, when the headline is written, then the count agrees in number")
    func headlineSingular() {
        let sales = [DailySales(day: CafeData.day(0), cups: 1), DailySales(day: CafeData.day(1), cups: 0)]

        #expect(summary(.string, sales: sales).headline == "Most cups: Sunday, 1 cup.")
    }

    @Test("Given no sales or no days, when the headline is written, then it says so")
    func headlineEmptyAndZero() {
        let zeros = [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]

        #expect(summary(.date, sales: zeros).headline == "No cups sold on any day.")
        #expect(summary(.date, sales: []).headline == "No days to show.")
        #expect(summary(.date, sales: zeros).audioGraphSummary == "2 days. No cups sold on any day.")
    }

    @Test("Given each type, when an element is labelled, then it names the day as drawn and its cups")
    func elementText() throws {
        let saturday = try #require(summary(.string).days.last)

        #expect(summary(.string).spokenDay(saturday) == "Saturday")
        #expect(summary(.number).spokenDay(saturday) == "Day 7")
        #expect(summary(.date).spokenDay(saturday) == "Saturday, March 7")
        #expect(summary(.date).spokenCups(saturday) == "219 cups")
    }

    @Test("Given a change to the date type, when it is announced, then it says what changed and then the headline")
    func announcement() {
        #expect(summary(.date).announcement == "Day is now a Date: a date scale, one day per step. Most cups: March 7, 219 cups.")
        #expect(summary(.number).announcement.hasPrefix("Day is now a Number: a number scale that starts at zero."))
    }

    @Test("Given the week, when the Audio Graph summary is written, then it gives the most and fewest in values")
    func audioGraphSummary() {
        #expect(summary(.string).audioGraphSummary == "7 days. Most: Saturday, 219 cups. Fewest: Tuesday, 152 cups.")
    }

    @Test("Given a String or a Date, when the descriptor is made, then the days are categories in data order")
    func descriptorCategories() throws {
        let days = summary(.date).days
        let descriptor = ValueTypesChartDescriptor(days: days, xType: .date, locale: english).makeChartDescriptor()

        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == 7)
        #expect(descriptor.title == "Cups sold each day at the Harbour café, with the day given as a Date")
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.dataPoints.count == 7)
        #expect(descriptor.series.first?.isContinuous == false)
        let yAxis = try #require(descriptor.yAxis)
        // The busiest day is 219; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
    }

    @Test("Given a number, when the descriptor is made, then x is a number axis from zero that says each day")
    func descriptorNumeric() throws {
        let days = summary(.number).days
        let descriptor = ValueTypesChartDescriptor(days: days, xType: .number, locale: english).makeChartDescriptor()

        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        // Days 1 to 7 on a number axis from zero, drawn to 8.
        #expect(xAxis.range == 0 ... 8)
        #expect(xAxis.valueDescriptionProvider(3) == "Day 3")
        #expect(xAxis.valueDescriptionProvider(.nan) == "")
    }
}
