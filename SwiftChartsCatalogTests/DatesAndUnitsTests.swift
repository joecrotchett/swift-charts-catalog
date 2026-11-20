import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DatesAndUnitsTests {
    private let locale = Locale(identifier: "en_US")

    @Test("Given the screen opens, when nothing is changed, then it shows days with the unit on")
    func startsOnDays() {
        let viewModel = DatesAndUnitsViewModel()

        #expect(viewModel.period == .days)
        #expect(!viewModel.isLeavingOutUnit)
        #expect(viewModel.bars.count == CafeData.harbourSales.count)
        #expect(viewModel.xTitle == CafeWording.day)
        #expect(viewModel.yTitle == CafeWording.cups)
    }

    @Test("Given months, when the bars are read, then there is one per month carrying its average day")
    func monthsUseAverageDay() {
        let viewModel = DatesAndUnitsViewModel()
        viewModel.period = .months

        #expect(viewModel.bars.map(\.cups) == CafeData.monthlySummaries.map(\.averageDay))
        #expect(viewModel.bars.map(\.date) == CafeData.monthlySummaries.map(\.month))
        #expect(viewModel.xTitle == CafeWording.month)
        #expect(viewModel.period.unit == .month)
    }

    @Test("Given each setting, when the snippets are listed, then they name the mark as written and the axis")
    func snippetNamesFollowSettings() {
        let viewModel = DatesAndUnitsViewModel()
        #expect(viewModel.snippets.map(\.name) == ["dates-and-units-days", "dates-and-units-axis"])

        viewModel.period = .months
        #expect(viewModel.snippets.map(\.name) == ["dates-and-units-months", "dates-and-units-axis"])

        viewModel.isLeavingOutUnit = true
        #expect(viewModel.snippets.map(\.name) == ["dates-and-units-no-unit", "dates-and-units-axis"])

        viewModel.period = .days
        #expect(viewModel.snippets.map(\.name) == ["dates-and-units-no-unit", "dates-and-units-axis"])
    }

    @Test("Given the built app, when every snippet the screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let all = [
            DatesAndUnitsViewModel.daysSnippet, DatesAndUnitsViewModel.monthsSnippet,
            DatesAndUnitsViewModel.noUnitSnippet, DatesAndUnitsViewModel.axisSnippet,
        ]

        for reference in all {
            let snippet = try #require(store[reference.name])
            #expect(snippet.file == "DataScreens/DatesAndUnitsScreen.swift")
        }
        #expect(store[DatesAndUnitsViewModel.daysSnippet.name]?.code.contains("unit: .day") == true)
        #expect(store[DatesAndUnitsViewModel.monthsSnippet.name]?.code.contains("unit: .month") == true)
        #expect(store[DatesAndUnitsViewModel.noUnitSnippet.name]?.code.contains("unit: .") == false)
    }

    @Test("Given the sample days, when the headline is written, then it names the busiest day and its cups")
    func dayHeadline() throws {
        let viewModel = DatesAndUnitsViewModel()
        let most = try #require(CafeData.harbourSales.map(\.cups).max())
        let busiest = try #require(CafeData.harbourSales.last { $0.cups == most })

        let headline = viewModel.headline(locale: locale)

        #expect(headline.hasPrefix("Busiest day: "))
        #expect(headline.contains(viewModel.periodName(busiest.day, locale: locale)))
        #expect(headline.hasSuffix("\(most) cups."))
    }

    @Test("Given months, when the headline is written, then it names July and its average day")
    func monthHeadline() {
        let viewModel = DatesAndUnitsViewModel()
        viewModel.period = .months

        #expect(viewModel.headline(locale: locale) == "Busiest month: July 2026, 253 cups a day on average.")
    }

    @Test("Given the mistake, when the headline is written, then it is unchanged because the bar heights are")
    func mistakeKeepsHeadline() {
        let viewModel = DatesAndUnitsViewModel()
        let before = viewModel.headline(locale: locale)

        viewModel.isLeavingOutUnit = true

        #expect(viewModel.headline(locale: locale) == before)
    }

    @Test("Given two days tied for most, when the headline is written, then it names both")
    func tiedHeadline() {
        let viewModel = DatesAndUnitsViewModel(days: [
            DailySales(day: CafeData.day(0), cups: 40),
            DailySales(day: CafeData.day(1), cups: 10),
            DailySales(day: CafeData.day(2), cups: 40),
        ])

        #expect(viewModel.headline(locale: locale)
            == "Busiest days: Sunday, March 1 and Tuesday, March 3, 40 cups each.")
    }

    @Test("Given one cup on the busiest day, when the headline is written, then the count agrees in number")
    func singularHeadline() {
        let viewModel = DatesAndUnitsViewModel(days: [DailySales(day: CafeData.day(0), cups: 1)])

        #expect(viewModel.headline(locale: locale) == "Busiest day: Sunday, March 1, 1 cup.")
    }

    @Test("Given no data or only zeros, when the screen is drawn, then it has no chart and says why")
    func emptyAndZero() {
        let empty = DatesAndUnitsViewModel(days: [], months: [])
        let zeros = DatesAndUnitsViewModel(days: [DailySales(day: CafeData.day(0), cups: 0)], months: [])

        for viewModel in [empty, zeros] {
            #expect(!viewModel.hasData)
            #expect(viewModel.headline(locale: locale) == "No cups sold in this period.")
            #expect(viewModel.audioGraphSummary(locale: locale) == "No cups sold in this period.")
        }
    }

    @Test("Given a date stored as midnight UTC, when it is written, then it names that day in any device time zone")
    func periodNameUsesDataTimeZone() {
        let viewModel = DatesAndUnitsViewModel()

        #expect(viewModel.periodName(CafeData.day(0), locale: locale) == "Sunday, March 1")
        viewModel.period = .months
        #expect(viewModel.periodName(CafeData.month(4), locale: locale) == "July 2026")
    }

    @Test("Given the unit is on or off, when a bar is labelled, then the label names its period or its instant")
    func barLabelsDescribeWhatIsDrawn() {
        let viewModel = DatesAndUnitsViewModel()
        let bar = DatesAndUnitsBar(date: CafeData.day(0), cups: 150)

        #expect(viewModel.barLabel(bar, locale: locale) == "Sunday, March 1")
        #expect(viewModel.barValue(bar, locale: locale) == "150 cups")

        viewModel.isLeavingOutUnit = true
        let instant = viewModel.barLabel(bar, locale: locale)
        #expect(instant.hasPrefix("Sunday, March 1"))
        #expect(instant.contains("12:00"))

        viewModel.period = .months
        #expect(viewModel.barValue(bar, locale: locale) == "150 cups a day")
    }

    @Test("Given each control changes, when the announcement is built, then it says what changed and then the headline")
    func announcements() {
        let viewModel = DatesAndUnitsViewModel()
        viewModel.period = .months
        let headline = viewModel.headline(locale: locale)

        #expect(viewModel.periodChangeAnnouncement(locale: locale) == "Showing one bar per month. \(headline)")

        viewModel.isLeavingOutUnit = true
        #expect(viewModel.unitChangeAnnouncement(locale: locale)
            == "Unit left off: each bar is narrow and centred on midnight on the first of its month. \(headline)")

        viewModel.isLeavingOutUnit = false
        #expect(viewModel.unitChangeAnnouncement(locale: locale) == "Unit on: each bar fills its month. \(headline)")
    }

    @Test("Given days with the unit left off, when the announcement is built, then it says the bars are shifted half a day, not narrow")
    func dayAnnouncementSaysShifted() {
        let viewModel = DatesAndUnitsViewModel()
        viewModel.isLeavingOutUnit = true
        let announcement = viewModel.unitChangeAnnouncement(locale: locale)

        #expect(announcement.hasPrefix("Unit left off: each bar is about as wide as a day but centred on midnight, so it is shifted half a day."))
        #expect(!announcement.contains("narrow"))
    }

    @Test(
        "Given each period, when the explanation is written, then what it says of bars with no unit is true of that period",
        arguments: [
            (DatesAndUnitsPeriod.days, "shifted half a day", "narrow"),
            (.months, "narrow and centred on midnight on the first of its month", "shifted half a day"),
        ]
    )
    func explanationFollowsPeriod(period: DatesAndUnitsPeriod, says: String, doesNotSay: String) {
        let viewModel = DatesAndUnitsViewModel()
        viewModel.period = period

        #expect(viewModel.explanation.hasPrefix("A date on its own is an instant."))
        #expect(viewModel.explanation.contains(says))
        #expect(!viewModel.explanation.contains(doesNotSay))
        viewModel.isLeavingOutUnit = true
        #expect(viewModel.audioGraphSummary(locale: locale).contains(says))
    }

    @Test("Given the period picker, when its options are read after its title, then they read as one bar's period")
    func pickerTitlesReadAfterTitle() {
        #expect(DatesAndUnitsPeriod.allCases.map(\.title) == ["Day", "Month"])
    }

    @Test("Given the unit and stride, when axis labels are placed, then they are centred only under bars that fill every labelled period")
    func labelCentring() {
        let viewModel = DatesAndUnitsViewModel()

        #expect(viewModel.axisLabelsCentered(stride: 1))
        #expect(!viewModel.axisLabelsCentered(stride: 7))
        viewModel.isLeavingOutUnit = true
        #expect(!viewModel.axisLabelsCentered(stride: 1))
    }

    @Test("Given days, when the descriptor is made, then it has the title, axes, one point per day and a zero-based range")
    func descriptorForDays() {
        let viewModel = DatesAndUnitsViewModel()

        let descriptor = viewModel.chartDescriptor(locale: locale).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café")
        #expect(descriptor.xAxis.title == CafeWording.day)
        #expect(descriptor.yAxis?.title == CafeWording.cupsAxisTitle)
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == CafeData.harbourSales.count)
        let categories = (descriptor.xAxis as? AXCategoricalDataAxisDescriptor)?.categoryOrder
        #expect(categories?.first == "Sunday, March 1")
        let yAxis = descriptor.yAxis
        #expect(yAxis?.range.lowerBound == 0)
        // The busiest day is 282; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis?.range.upperBound == 300)
        #expect(descriptor.summary?.hasPrefix("28 days. Highest ") == true)
    }

    @Test("Given months and the mistake, when the descriptor is made, then it says the bars are drawn at instants")
    func descriptorForMistake() {
        let viewModel = DatesAndUnitsViewModel()
        viewModel.period = .months
        viewModel.isLeavingOutUnit = true

        let descriptor = viewModel.chartDescriptor(locale: locale).makeChartDescriptor()

        #expect(descriptor.title?.hasSuffix("each bar drawn at an instant") == true)
        #expect(descriptor.summary?.hasPrefix("Drawn without a unit") == true)
        #expect(descriptor.summary?.contains("6 months. Highest July 2026, 253 cups a day.") == true)
        #expect(descriptor.yAxis?.title == DatesAndUnitsViewModel.averageDayAxisTitle)
    }

    @Test("Given the descriptor, when the Audio Graph asks for values, then they agree in number and are empty when not finite")
    func spokenValues() {
        let viewModel = DatesAndUnitsViewModel()
        let days = viewModel.chartDescriptor(locale: locale)
        viewModel.period = .months
        let months = viewModel.chartDescriptor(locale: locale)

        #expect(days.spokenValue(1) == "1 cup")
        #expect(days.spokenValue(274) == "274 cups")
        #expect(months.spokenValue(219) == "219 cups a day")
        #expect(months.spokenValue(.nan) == "")
    }

    @Test("Given each period, when the bar the headline names is labelled, then the label names its day or month and value")
    func calloutNamesTheHeadlineBar() throws {
        let model = DatesAndUnitsViewModel()
        model.period = .days
        let day = try #require(model.highestBars.first)
        #expect(model.calloutText(for: day, locale: Locale(identifier: "en_US")) == "Mar 28: 282")
        model.period = .months
        let month = try #require(model.highestBars.first)
        #expect(model.calloutText(for: month, locale: Locale(identifier: "en_US")) == "Jul: 253")
    }
}
