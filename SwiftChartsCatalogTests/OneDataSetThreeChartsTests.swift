import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct OneDataSetThreeChartsTests {
    private let stores = [
        StoreSales(store: "Harbour", days: OneDataSetThreeChartsTests.days([10, 30, 20])),
        StoreSales(store: "Station", days: OneDataSetThreeChartsTests.days([5, 5, 40])),
    ]

    private static func days(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    private func descriptor(for viewModel: OneDataSetThreeChartsViewModel) -> AXChartDescriptor {
        ThreeChartsDescriptor(
            title: viewModel.caption, summary: viewModel.audioGraphSummary,
            stores: viewModel.shownStores, isContinuous: viewModel.isContinuous, valueRange: viewModel.valueDomain
        ).makeChartDescriptor()
    }

    @Test("Given a new screen, when nothing has been chosen, then it shows the first café as bars")
    func startsWithBars() {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores)

        #expect(viewModel.form == .bars)
        #expect(viewModel.shownStores.map(\.store) == ["Harbour"])
        #expect(viewModel.hasData)
        #expect(!viewModel.isContinuous)
    }

    @Test("Given the bars, when the form changes to a line, then the data, caption and headline stay the same")
    func lineKeepsTheData() {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores)
        let bars = (viewModel.shownStores, viewModel.caption, viewModel.headline)
        viewModel.form = .line

        #expect(viewModel.shownStores == bars.0)
        #expect(viewModel.caption == bars.1)
        #expect(viewModel.headline == bars.2)
        #expect(viewModel.isContinuous)
    }

    @Test("Given one café's days, when the headline is written, then it gives the lowest and highest day's cups, which the chart shows")
    func singleSeriesHeadline() {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores)

        #expect(viewModel.caption == "Cups sold per day at the Harbour café")
        #expect(viewModel.headline == "Harbour sold between 10 and 30 cups a day.")
    }

    @Test("Given one café that sold the same every day, when the headline is written, then it says so with one figure")
    func flatSeriesHeadline() {
        let flat = [StoreSales(store: "Harbour", days: Self.days([1, 1]))]

        #expect(OneDataSetThreeChartsViewModel(stores: flat).headline == "Harbour sold 1 cup every day.")
    }

    @Test("Given two cafés, when a line per café is chosen, then both are shown and the headline names the one with the busiest day")
    func linePerCafeShowsEveryStore() {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores, form: .linePerCafe)

        #expect(viewModel.shownStores.map(\.store) == ["Harbour", "Station"])
        #expect(viewModel.caption == "Cups sold per day at each café")
        #expect(viewModel.headline == "Station had the busiest day: 40 cups.")
    }

    @Test("Given two cafés with the same busiest day, when the headline is written, then it names both and stays true")
    func tieNamesBoth() {
        let tied = [
            StoreSales(store: "Harbour", days: Self.days([10, 20])),
            StoreSales(store: "Station", days: Self.days([20, 10])),
        ]

        #expect(
            OneDataSetThreeChartsViewModel(stores: tied, form: .linePerCafe).headline
                == "Harbour and Station tied for the busiest day: 20 cups."
        )
    }

    @Test("Given the café's sample data, when each form's headline is written, then its figure is a day's cups drawn in that form, not a total", arguments: ThreeChartsForm.allCases)
    func headlineFollowsSampleData(form: ThreeChartsForm) {
        let viewModel = OneDataSetThreeChartsViewModel(form: form)
        let drawn = viewModel.shownStores.flatMap(\.days).map(\.cups)
        let total = CafeData.harbourSales.map(\.cups).reduce(0, +)

        #expect(drawn.max() == 282)
        #expect(viewModel.headline.hasPrefix("Harbour"))
        #expect(viewModel.headline.contains("282 cups"))
        #expect(!viewModel.headline.contains(total.formatted()))
    }

    @Test("Given the sample data, when each form's headline is written, then it is the range of Harbour's days, or the café with the busiest day")
    func sampleDataHeadlines() {
        #expect(OneDataSetThreeChartsViewModel(form: .bars).headline == "Harbour sold between 152 and 282 cups a day.")
        #expect(OneDataSetThreeChartsViewModel(form: .linePerCafe).headline == "Harbour had the busiest day: 282 cups.")
    }

    @Test("Given any form, when the colour scale's domain is asked for, then it is every café in data order, whichever are drawn", arguments: ThreeChartsForm.allCases)
    func colourDomainIsEveryCafe(form: ThreeChartsForm) {
        #expect(OneDataSetThreeChartsViewModel(stores: stores, form: form).cafes == ["Harbour", "Station"])
    }

    @Test("Given nine days of a café, when its line is divided for VoiceOver, then there is an element per week and the days keep their order")
    func weeksDivideTheLine() {
        let harbour = StoreSales(store: "Harbour", days: Self.days([10, 14, 12, 20, 18, 22, 30, 28, 1]))
        let weeks = ThreeChartsText.weeks(of: harbour)

        #expect(weeks.map(\.days.count) == [7, 2])
        #expect(weeks.flatMap(\.days) == harbour.days)
        #expect(Set(weeks.map(\.id)).count == 2)
        #expect(weeks.first?.label == "Harbour, March 1 to March 7")
        #expect(weeks.first?.value == "Starts at 10 cups, ends at 30 cups, lowest 10 cups, highest 30 cups")
        #expect(weeks.last?.label == "Harbour, March 8 to March 9")
        #expect(weeks.last?.value == "Starts at 28 cups, ends at 1 cup, lowest 1 cup, highest 28 cups")
    }

    @Test("Given a week of one day, when its element is described, then the date is said once")
    func singleDayWeek() {
        let station = StoreSales(store: "Station", days: Self.days([3, 3, 3, 3, 3, 3, 3, 5]))

        #expect(ThreeChartsText.weeks(of: station).last?.label == "Station, March 8")
    }

    @Test("Given the sample data, when a line per café is divided for VoiceOver, then there are four elements per café, not one per day")
    func sampleDataHasFourWeeksPerCafe() {
        let viewModel = OneDataSetThreeChartsViewModel(form: .linePerCafe)

        #expect(viewModel.shownStores.map { ThreeChartsText.weeks(of: $0).count } == [4, 4])
        #expect(ThreeChartsText.weeks(of: CafeData.storeSales[0]).first?.value
            == "Starts at 190 cups, ends at 219 cups, lowest 152 cups, highest 219 cups")
    }

    @Test("Given no cafés, when any form is shown, then there is no data and the words say nothing was sold", arguments: ThreeChartsForm.allCases)
    func emptySaysSo(form: ThreeChartsForm) {
        let viewModel = OneDataSetThreeChartsViewModel(stores: [], form: form)

        #expect(!viewModel.hasData)
        #expect(viewModel.headline == "No cups sold yet.")
        #expect(viewModel.audioGraphSummary == "No cups sold yet.")
    }

    @Test("Given days that are all zero, when any form is shown, then there is no data and the headline does not name a best seller", arguments: ThreeChartsForm.allCases)
    func allZeroSaysSo(form: ThreeChartsForm) {
        let zero = [
            StoreSales(store: "Harbour", days: Self.days([0, 0])),
            StoreSales(store: "Station", days: Self.days([0, 0])),
        ]
        let viewModel = OneDataSetThreeChartsViewModel(stores: zero, form: form)

        #expect(!viewModel.hasData)
        #expect(viewModel.headline == "No cups sold yet.")
        #expect(viewModel.audioGraphSummary == "No cups sold yet.")
    }

    @Test("Given a first café with no sales and a second with some, when the forms are compared, then only a line per café has data")
    func dataDependsOnWhatIsShown() {
        let mixed = [
            StoreSales(store: "Harbour", days: Self.days([0, 0])),
            StoreSales(store: "Station", days: Self.days([4, 6])),
        ]

        #expect(!OneDataSetThreeChartsViewModel(stores: mixed, form: .bars).hasData)
        #expect(OneDataSetThreeChartsViewModel(stores: mixed, form: .linePerCafe).hasData)
        #expect(OneDataSetThreeChartsViewModel(stores: mixed, form: .linePerCafe).headline == "Station had the busiest day: 6 cups.")
    }

    @Test("Given each form, when the Code view's snippets are asked for, then it is the one region that draws that form")
    func snippetsFollowTheForm() {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores)

        #expect(viewModel.snippets == [SnippetReference(name: "one-data-set-three-charts-bars", title: "Bars")])
        viewModel.form = .line
        #expect(viewModel.snippets == [SnippetReference(name: "one-data-set-three-charts-line", title: "A line")])
        viewModel.form = .linePerCafe
        #expect(viewModel.snippets == [SnippetReference(name: "one-data-set-three-charts-line-per-cafe", title: "A line per café")])
    }

    @Test("Given the three forms, when their snippet names are read, then each starts with the screen's slug and none repeats")
    func snippetNamesAreTheScreensOwn() {
        let names = ThreeChartsForm.allCases.map(\.snippet.name)

        #expect(names.allSatisfy { $0.hasPrefix("one-data-set-three-charts-") })
        #expect(Set(names).count == ThreeChartsForm.allCases.count)
    }

    @Test("Given each form, when the change is announced, then the announcement says which form the chart now has")
    func announcementNamesTheForm() {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores)

        #expect(viewModel.announcement == "Chart changed to bars, one per day.")
        viewModel.form = .line
        #expect(viewModel.announcement == "Chart changed to a line.")
        viewModel.form = .linePerCafe
        #expect(viewModel.announcement == "Chart changed to a line for each café.")
    }

    @Test("Given one café's days, when the Audio Graph summary is written, then it gives the days, total, first, last, lowest and highest in actual values")
    func summaryGivesActualValues() {
        #expect(
            OneDataSetThreeChartsViewModel(stores: stores).audioGraphSummary
                == "Harbour: 3 days, 60 cups in total. First day 10 cups, last day 20 cups, lowest 10 cups, highest 30 cups."
        )
    }

    @Test("Given two cafés, when the Audio Graph summary is written for a line per café, then it describes each café in turn")
    func summaryCoversEveryStore() {
        #expect(
            OneDataSetThreeChartsViewModel(stores: stores, form: .linePerCafe).audioGraphSummary
                == "Harbour: 3 days, 60 cups in total. First day 10 cups, last day 20 cups, lowest 10 cups, highest 30 cups. "
                + "Station: 3 days, 50 cups in total. First day 5 cups, last day 40 cups, lowest 5 cups, highest 40 cups."
        )
    }

    @Test("Given counts of cups and days, when they are written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(ThreeChartsText.cups(1) == "1 cup")
        #expect(ThreeChartsText.cups(0) == "0 cups")
        #expect(ThreeChartsText.cups(57) == "57 cups")
        #expect(ThreeChartsText.days(1) == "1 day")
        #expect(ThreeChartsText.days(28) == "28 days")
    }

    @Test("Given the first sample day, when it is written out, then it is the day in the data's own time zone, with its weekday")
    func daysAreWrittenOut() {
        #expect(ThreeChartsText.day(CafeData.day(0)) == "Sunday, March 1")
        #expect(ThreeChartsText.shortDay(CafeData.day(0)) == "March 1")
    }

    @Test("Given the bars, when the chart descriptor is made, then it has the caption as title, the summary, and one named series of separate values")
    func barsDescriptor() throws {
        let viewModel = OneDataSetThreeChartsViewModel(stores: stores)
        let descriptor = descriptor(for: viewModel)

        #expect(descriptor.title == "Cups sold per day at the Harbour café")
        #expect(descriptor.summary == viewModel.audioGraphSummary)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 3)
    }

    @Test("Given the line, when the chart descriptor is made, then the same series is continuous")
    func lineDescriptor() throws {
        let descriptor = descriptor(for: OneDataSetThreeChartsViewModel(stores: stores, form: .line))

        #expect(descriptor.series.map(\.name) == ["Harbour"])
        let series = try #require(descriptor.series.first)
        #expect(series.isContinuous)
    }

    @Test("Given a line per café, when the chart descriptor is made, then every café is a named continuous series over the same written-out days")
    func linePerCafeDescriptor() throws {
        let descriptor = descriptor(for: OneDataSetThreeChartsViewModel(stores: stores, form: .linePerCafe))
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(descriptor.title == "Cups sold per day at each café")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.allSatisfy { $0.isContinuous && $0.dataPoints.count == 3 })
        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder == ["Sunday, March 1", "Monday, March 2", "Tuesday, March 3"])
    }

    @Test("Given a line per café, when the descriptor's value axis is read, then it runs from zero to the drawn axis top and says values in cups")
    func descriptorValueAxisHasUnits() throws {
        let yAxis = try #require(descriptor(for: OneDataSetThreeChartsViewModel(stores: stores, form: .linePerCafe)).yAxis)

        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == 0 ... 40)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }

    @Test("Given the sample cafés, when each form's value axis is worked out, then it is 0 to 300 in all three, the drawn top above 282")
    func valueDomainIsTheSameInEveryForm() {
        for form in ThreeChartsForm.allCases {
            #expect(OneDataSetThreeChartsViewModel(form: form).valueDomain == 0 ... 300)
        }
    }
}
