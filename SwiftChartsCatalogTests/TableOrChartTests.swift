import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct TableOrChartTests {
    private let locale = Locale(identifier: "en_US")

    private func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    // MARK: State and changes

    @Test("Given a new screen, when nothing has been changed, then it shows the list sorted by day")
    func startsWithTheListByDay() {
        let model = TableOrChartViewModel()

        #expect(model.form == .list)
        #expect(model.sort == .byDay)
        #expect(model.days == CafeData.harbourSales)
    }

    @Test("Given the list, when the chart is chosen, then the chart shows and the change is announced with its headline")
    func showingTheChartIsAnnounced() {
        let model = TableOrChartViewModel()

        let message = model.show(.chart, locale: locale)

        #expect(model.form == .chart)
        #expect(message == "Showing the chart. Sales rose every week, averaging 205 cups a day.")
    }

    @Test("Given the chart, when the list is chosen again, then the announcement says how the list is sorted")
    func showingTheListIsAnnounced() {
        let model = TableOrChartViewModel()
        _ = model.sortRows(.byCups, locale: locale)
        _ = model.show(.chart, locale: locale)

        let message = model.show(.list, locale: locale)

        #expect(message == "Showing the list, sorted by cups, most first. Busiest first: Sat, Mar 28, with 282 cups.")
    }

    @Test("Given the list by day, when it is sorted by cups, then the change and the new headline are announced")
    func sortingIsAnnounced() {
        let model = TableOrChartViewModel()

        #expect(model.sortRows(.byCups, locale: locale) == "Sorted by cups, most first. Busiest first: Sat, Mar 28, with 282 cups.")
        #expect(model.sortRows(.byDay, locale: locale) == "Sorted by day. 28 days, Mar 1 to Mar 28, in date order: look up any day.")
    }

    @Test("Given a setting already in effect, when it is chosen again, then nothing is announced")
    func choosingTheSameSettingIsSilent() {
        let model = TableOrChartViewModel()

        #expect(model.show(.list, locale: locale) == nil)
        #expect(model.sortRows(.byDay, locale: locale) == nil)
    }

    @Test("Given no days, when a control is used, then nothing changes, nothing is announced and the controls are off")
    func noDaysDisablesTheControls() {
        let model = TableOrChartViewModel(days: [])

        #expect(!model.hasDays)
        #expect(model.show(.chart, locale: locale) == nil)
        #expect(model.sortRows(.byCups, locale: locale) == nil)
        #expect(model.form == .list)
        #expect(model.sort == .byDay)
    }

    // MARK: The list

    @Test("Given days out of order, when the list is sorted by day, then the rows run in date order")
    func sortsByDay() {
        let shuffled = [DailySales(day: CafeData.day(2), cups: 5), DailySales(day: CafeData.day(0), cups: 9), DailySales(day: CafeData.day(1), cups: 7)]
        let model = TableOrChartViewModel(days: shuffled)

        #expect(model.sortedDays.map(\.cups) == [9, 7, 5])
    }

    @Test("Given two days with the same cups, when the list is sorted by cups, then the most come first and the tie keeps date order")
    func sortsByCupsWithTiesInDateOrder() {
        let model = TableOrChartViewModel(days: days([40, 90, 10, 90]))
        _ = model.sortRows(.byCups, locale: locale)

        #expect(model.sortedDays.map(\.day) == [CafeData.day(1), CafeData.day(3), CafeData.day(0), CafeData.day(2)])
    }

    @Test("Given the four weeks, when the rows are written, then each shows its day and cups and speaks the unit")
    func rowsShowAndSpeakTheValues() throws {
        let rows = TableOrChartViewModel().rows(locale: locale)
        let first = try #require(rows.first)

        #expect(rows.count == 28)
        #expect(first.dayText == "Sun, Mar 1")
        #expect(first.spokenDay == "Sunday, March 1")
        #expect(first.cupsText == "190")
        #expect(first.spokenCups == "190 cups")
    }

    @Test("Given a day of one cup, when its row is written, then the count agrees in number")
    func rowCountAgrees() throws {
        let row = try #require(TableOrChartViewModel(days: days([1])).rows(locale: locale).first)

        #expect(row.spokenCups == "1 cup")
    }

    @Test("Given a German locale, when the rows are written, then numbers and dates follow it")
    func rowsTakeTheLocale() throws {
        let rows = TableOrChartViewModel(days: days([1200])).rows(locale: Locale(identifier: "de_DE"))
        let row = try #require(rows.first)

        #expect(row.cupsText == "1.200")
        #expect(row.dayText.contains("1."))
    }

    // MARK: Headlines

    @Test("Given the four weeks, when each setting is shown, then each headline gives a figure that setting draws")
    func headlinesForEverySetting() {
        let model = TableOrChartViewModel()

        #expect(model.headline(form: .list, sort: .byDay, locale: locale) == "28 days, Mar 1 to Mar 28, in date order: look up any day.")
        #expect(model.headline(form: .list, sort: .byCups, locale: locale) == "Busiest first: Sat, Mar 28, with 282 cups.")
        #expect(model.headline(form: .chart, sort: .byDay, locale: locale) == "Sales rose every week, averaging 205 cups a day.")
        #expect(model.headline(form: .chart, sort: .byCups, locale: locale) == "Sales rose every week, averaging 205 cups a day.")
    }

    @Test("Given two busiest days, when the list is sorted by cups, then the headline names both")
    func listHeadlineNamesATie() {
        let model = TableOrChartViewModel(days: days([40, 90, 10, 90]))

        #expect(model.headline(form: .list, sort: .byCups, locale: locale) == "Busiest first: Mon, Mar 2 and Wed, Mar 4, with 90 cups each.")
    }

    @Test("Given weeks that fall, when the chart's headline is written, then it says they fell")
    func chartHeadlineForFallingWeeks() {
        let falling = days(Array(repeating: 30, count: 7) + Array(repeating: 20, count: 7))

        #expect(TableOrChartSummary(days: falling).chartHeadline(locale: locale) == "Sales fell every week, averaging 25 cups a day.")
    }

    @Test("Given weeks that go up and down, or less than two weeks, when the chart's headline is written, then it gives the average alone")
    func chartHeadlineWithoutATrend() {
        let mixed = days(Array(repeating: 30, count: 7) + Array(repeating: 20, count: 7) + Array(repeating: 40, count: 7))

        #expect(TableOrChartSummary(days: mixed).chartHeadline(locale: locale) == "An average of 30 cups a day.")
        #expect(TableOrChartSummary(days: days([1])).chartHeadline(locale: locale) == "An average of 1 cup a day.")
    }

    @Test("Given only zeros, when the headlines are written, then they say nothing sold and the chart draws a placeholder")
    func headlinesForZeros() {
        let model = TableOrChartViewModel(days: days([0, 0, 0]))

        #expect(model.summary.hasNoCups)
        #expect(model.headline(form: .chart, sort: .byDay, locale: locale) == "No cups sold on any of the 3 days.")
        #expect(model.headline(form: .list, sort: .byCups, locale: locale) == "No cups sold on any of the 3 days.")
        #expect(model.headline(form: .list, sort: .byDay, locale: locale) == "3 days, Mar 1 to Mar 3, in date order: look up any day.")
    }

    @Test("Given no days, when the headlines are written, then every setting says no days were recorded")
    func headlinesForNoDays() {
        let model = TableOrChartViewModel(days: [])

        for form in TableOrChartForm.allCases {
            for sort in TableOrChartSort.allCases {
                #expect(model.headline(form: form, sort: sort, locale: locale) == "No days recorded.")
            }
        }
    }

    // MARK: Snippets

    @Test("Given each form, when its snippets are listed, then they name the code for that form and exist in the bundle")
    func snippetsFollowTheForm() throws {
        let store = try SnippetStore()
        let model = TableOrChartViewModel()

        #expect(model.snippets.map(\.name) == ["table-or-chart-list", "table-or-chart-sort"])
        _ = model.show(.chart, locale: locale)
        #expect(model.snippets.map(\.name) == ["table-or-chart-chart"])
        for name in ["table-or-chart-list", "table-or-chart-sort", "table-or-chart-chart"] {
            #expect(store[name] != nil)
        }
    }

    // MARK: The chart and its descriptor

    @Test("Given the four weeks, when the chart's numbers are worked out, then the axis runs to 300 and the average is 204.5")
    func chartNumbers() {
        let summary = TableOrChartSummary(days: CafeData.harbourSales)

        #expect(summary.cupsAxis == 0 ... 300)
        #expect(summary.average == 204.5)
        #expect(summary.roundedAverage == 205)
        #expect(summary.weeklyTotals.count == 4)
    }

    @Test("Given the four weeks, when the descriptor is made, then it has a title, a summary in values, written dates and the drawn range")
    func descriptor() throws {
        let descriptor = TableOrChartChartDescriptor(days: CafeData.harbourSales, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups each day at the Harbour café")
        #expect(descriptor.summary == "28 days, March 1 to March 28. Daily average 205 cups, drawn as a dashed line. "
            + "Most: Saturday, March 28, 282 cups. Fewest: Tuesday, March 3, 152 cups.")
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == 28)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 28)
    }

    @Test("Given only zeros, when the descriptor's summary is written, then it says nothing sold")
    func descriptorForZeros() {
        #expect(TableOrChartSummary(days: days([0, 0])).audioGraphSummary(locale: locale) == "2 days, March 1 to March 2. No cups sold.")
    }

    @Test("Given each sort, when its heading is drawn and read, then the chevron and the spoken value give its direction")
    func sortDirections() {
        #expect(TableOrChartSort.byDay.symbolName == "chevron.up")
        #expect(TableOrChartSort.byDay.direction == "Earliest first")
        #expect(TableOrChartSort.byCups.symbolName == "chevron.down")
        #expect(TableOrChartSort.byCups.direction == "Most first")
    }

    @Test("Given the four weeks, when the caption is written, then it names the month the axis's day numbers belong to")
    func captionNamesMonth() {
        #expect(TableOrChartViewModel().caption(locale: locale) == "Cups sold each day at the Harbour café, March 1\u{2009}–\u{2009}28, 2026")
        #expect(TableOrChartViewModel(days: Array(CafeData.harbourSales.prefix(7))).caption(locale: locale) == "Cups each day at the Harbour café, March 2026")
        #expect(TableOrChartViewModel(days: []).caption(locale: locale) == "Cups each day at the Harbour café")
    }

    @Test("Given the four weeks, when the scroll note is written, then it counts the days the list holds")
    func scrollNote() {
        #expect(TableOrChartViewModel().scrollNote(locale: locale) == "28 days: scroll inside the list to see them all.")
    }
}
