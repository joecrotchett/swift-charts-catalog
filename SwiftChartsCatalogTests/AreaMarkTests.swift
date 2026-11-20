import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AreaMarkTests {
    private let locale = Locale(identifier: "en_US")

    private func summary(_ form: AreaMarkForm, months: [MonthlySummary] = CafeData.monthlySummaries) -> AreaMarkSummary {
        AreaMarkSummary(months: months, form: form, locale: locale)
    }

    private func month(_ offset: Int, low: Int, high: Int, average: Int) -> MonthlySummary {
        MonthlySummary(month: CafeData.month(offset), lowestDay: low, highestDay: high, averageDay: average)
    }

    // MARK: The view model

    @Test("Given a new screen, when it appears, then it draws the basic form with the basic snippet")
    func startsBasic() {
        let viewModel = AreaMarkViewModel()

        #expect(viewModel.form == .basic)
        #expect(viewModel.snippets.map(\.name) == ["area-basic"])
        #expect(viewModel.caption == "Cups on an average day at the Harbour café, by month")
    }

    @Test("Given the basic form, when range is chosen, then the snippet, caption, explanation and headline follow")
    func rangeChangesTheWords() {
        let viewModel = AreaMarkViewModel()
        let basicExplanation = viewModel.explanation
        let basicHeadline = viewModel.summary(locale: locale).headline

        viewModel.form = .range

        #expect(viewModel.snippets.map(\.name) == ["area-range"])
        #expect(viewModel.caption == "Cups on the quietest and busiest day at the Harbour café, by month")
        #expect(viewModel.explanation != basicExplanation)
        #expect(viewModel.summary(locale: locale).headline != basicHeadline)
        #expect(viewModel.summary(locale: locale).form == .range)
    }

    @Test("Given either form, when the change is announced, then the announcement names the form and carries its headline")
    func announcementFollowsTheForm() {
        let viewModel = AreaMarkViewModel()
        viewModel.form = .range
        #expect(viewModel.changeAnnouncement(locale: locale).hasPrefix("Chart changed to the range between"))
        #expect(viewModel.changeAnnouncement(locale: locale).hasSuffix(viewModel.summary(locale: locale).headline))

        viewModel.form = .basic
        #expect(viewModel.changeAnnouncement(locale: locale).hasPrefix("Chart changed to the area under"))
        #expect(viewModel.changeAnnouncement(locale: locale).hasSuffix(viewModel.summary(locale: locale).headline))
    }

    @Test("Given a locale passed in, when the headline, the element labels and the chart descriptor are written, then all use it", arguments: AreaMarkForm.allCases)
    func everyWordUsesTheLocalePassedIn(form: AreaMarkForm) throws {
        let french = Locale(identifier: "fr_FR")
        let viewModel = AreaMarkViewModel()
        viewModel.form = form
        let summary = viewModel.summary(locale: french)
        let march = try #require(viewModel.months.first)
        let xAxis = try #require(
            AreaMarkChartDescriptor(summary: summary).makeChartDescriptor().xAxis as? AXCategoricalDataAxisDescriptor
        )

        #expect(summary.locale == french)
        #expect(summary.elementLabel(for: march) == "mars 2026")
        #expect(xAxis.categoryOrder.first == "mars 2026")
        #expect(viewModel.changeAnnouncement(locale: french).hasSuffix(summary.headline))
        #expect(viewModel.summary(locale: locale).elementLabel(for: march) == "March 2026")
    }

    @Test("Given every form, when its snippets are looked up, then each exists in the built app", arguments: AreaMarkForm.allCases)
    func snippetsExist(form: AreaMarkForm) throws {
        let store = try SnippetStore()
        let viewModel = AreaMarkViewModel()
        viewModel.form = form

        #expect(!viewModel.snippets.isEmpty)
        for snippet in viewModel.snippets {
            #expect(store[snippet.name] != nil)
            #expect(snippet.name.hasPrefix("area-"))
        }
    }

    @Test("Given the two snippets, when they are read, then each shows the initializer its form is about")
    func snippetsShowTheirInitializer() throws {
        let store = try SnippetStore()
        let basic = try #require(store["area-basic"]).code
        let range = try #require(store["area-range"]).code

        #expect(basic.contains("AreaMark(") && basic.contains("y: .value(") && !basic.contains("yStart"))
        #expect(range.contains("yStart: .value(") && range.contains("yEnd: .value("))
    }

    // MARK: Headlines

    @Test("Given the sample data, when the basic headline is written, then it names the month with the highest average day")
    func basicHeadline() {
        #expect(summary(.basic).headline == "The average day was busiest in July: 253 cups.")
    }

    @Test("Given the sample data, when the range headline is written, then it gives the lowest and highest values the band draws")
    func rangeHeadline() {
        #expect(summary(.range).headline == "Across 6 months, a day sold between 152 and 347 cups.")
    }

    @Test("Given two months tied for the highest average, when the headline is written, then it names both")
    func tieNamesBoth() {
        let months = [month(0, low: 10, high: 30, average: 20), month(1, low: 5, high: 40, average: 20), month(2, low: 1, high: 9, average: 4)]

        #expect(summary(.basic, months: months).headline == "The average day was busiest in March and April: 20 cups.")
    }

    @Test("Given one month, when the range headline is written, then the month count agrees in number")
    func oneMonthAgrees() {
        #expect(summary(.range, months: [month(0, low: 0, high: 1, average: 1)]).headline == "Across 1 month, a day sold between 0 and 1 cup.")
    }

    @Test("Given no months, when the words are written, then every one says nothing was sold", arguments: AreaMarkForm.allCases)
    func emptySaysSo(form: AreaMarkForm) {
        let empty = summary(form, months: [])

        #expect(!empty.hasData)
        #expect(empty.headline == "No sales recorded yet.")
        #expect(empty.audioGraphSummary == "No sales recorded yet.")
    }

    @Test("Given months that are all zero, when the words are written, then they say nothing was sold", arguments: AreaMarkForm.allCases)
    func allZeroSaysSo(form: AreaMarkForm) {
        let zeros = summary(form, months: [month(0, low: 0, high: 0, average: 0), month(1, low: 0, high: 0, average: 0)])

        #expect(!zeros.hasData)
        #expect(zeros.peakAverageMonths.isEmpty)
        #expect(zeros.headline == "No sales recorded yet.")
        #expect(zeros.audioGraphSummary == "No sales recorded yet.")
    }

    // MARK: What assistive technologies get

    @Test("Given a month, when its element is described, then the label is the month written out and the value follows the form")
    func elementWords() throws {
        let march = try #require(CafeData.monthlySummaries.first)

        #expect(summary(.basic).elementLabel(for: march) == "March 2026")
        #expect(summary(.basic).elementValue(for: march) == "205 cups on an average day")
        #expect(summary(.range).elementValue(for: march) == "Quietest day 152 cups, busiest day 282 cups")
    }

    @Test("Given a count of cups, when it is written, then the unit agrees with the number")
    func cupsAgreeInNumber() {
        #expect(summary(.basic).cupsText(1) == "1 cup")
        #expect(summary(.basic).cupsText(0) == "0 cups")
        #expect(summary(.basic).cupsText(219) == "219 cups")
    }

    @Test("Given the sample data, when the Audio Graph summaries are written, then they give actual values for the form drawn")
    func audioGraphSummaries() {
        #expect(
            summary(.basic).audioGraphSummary
                == "6 months, March 2026 to August 2026. Average day: first month 205 cups, last month 235 cups, highest 253 cups in July 2026."
        )
        #expect(
            summary(.range).audioGraphSummary
                == "6 months, March 2026 to August 2026. Quietest day: 152 cups, in March 2026. Busiest day: 347 cups, in July 2026."
        )
    }

    @Test("Given the basic form, when the descriptor is made, then it has one continuous named series over the months, from zero")
    func basicDescriptor() throws {
        let descriptor = AreaMarkChartDescriptor(summary: summary(.basic)).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Cups on an average day at the Harbour café, by month")
        #expect(descriptor.summary == summary(.basic).audioGraphSummary)
        #expect(xAxis.title == "Month")
        #expect(xAxis.categoryOrder == ["March 2026", "April 2026", "May 2026", "June 2026", "July 2026", "August 2026"])
        #expect(yAxis.title == "Cups")
        // The highest average day is 253; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.count == 1)
        #expect(series.name == "Average day")
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == 6)
    }

    @Test("Given the range form, when the descriptor is made, then it has a named series for each edge of the band")
    func rangeDescriptor() throws {
        let descriptor = AreaMarkChartDescriptor(summary: summary(.range)).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups on the quietest and busiest day at the Harbour café, by month")
        #expect(descriptor.summary == summary(.range).audioGraphSummary)
        #expect(descriptor.series.map(\.name) == ["Quietest day", "Busiest day"])
        #expect(descriptor.series.allSatisfy { $0.isContinuous && $0.dataPoints.count == 6 })
        // The busiest day is 347, on an axis drawn to 400.
        #expect(yAxis.range == 0 ... 400)
    }
}
