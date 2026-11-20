import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct TitleGivesWayTests {
    private let english = Locale(identifier: "en_US")

    /// A moment `hours` hours into the day `offset` days after 1 March 2026 (UTC).
    private func moment(day offset: Int, hours: Double) -> Date {
        CafeData.day(offset).addingTimeInterval(hours * 60 * 60)
    }

    /// The interval format puts thin spaces around its dash, so the title is checked by its two ends.
    private func expectTitle(_ header: TitleGivesWayHeaderText) {
        guard case let .title(title) = header else {
            Issue.record("Expected the title, got \(header)")
            return
        }
        #expect(title.hasPrefix("Cups a day, Mar 1"))
        #expect(title.hasSuffix("28, 2026"))
    }

    private func cups(_ store: String, on offset: Int) -> Int {
        CafeData.storeSales.first { $0.store == store }?.days[offset].cups ?? -1
    }

    @Test("Given no selection, when the header is read, then it is the chart's title over the data's dates")
    func restingHeaderIsTitle() {
        let viewModel = TitleGivesWayViewModel()
        expectTitle(viewModel.header(locale: english))
    }

    @Test("Given a raw position part way through a day, when the header is read, then the selection label for that day replaces the title")
    func selectionReplacesTitle() throws {
        let viewModel = TitleGivesWayViewModel(rawSelection: moment(day: 3, hours: 7.25))
        guard case let .selection(text) = viewModel.header(locale: english) else {
            Issue.record("Expected the selection label")
            return
        }
        #expect(text.dayText == "Wednesday, March 4")
        let harbour = cups(CafeWording.harbour, on: 3), station = cups(CafeWording.station, on: 3)
        #expect(text.valuesText == "Harbour \(harbour) cups, Station \(station) cups")
        #expect(try #require(viewModel.selectedDay).date == CafeData.day(3))
    }

    @Test("Given a raw position late in the evening, when it is snapped, then it selects the nearest day's point, the next day")
    func lateEveningSnapsToNextDay() throws {
        let viewModel = TitleGivesWayViewModel(rawSelection: moment(day: 3, hours: 20))
        #expect(try #require(viewModel.selectedDay).date == CafeData.day(4))
    }

    @Test("Given a raw position beyond the data, when the header is read, then the title stays")
    func positionOffTheDataKeepsTitle() {
        let viewModel = TitleGivesWayViewModel(rawSelection: moment(day: 30, hours: 0))
        #expect(viewModel.selectedDay == nil)
        expectTitle(viewModel.header(locale: english))
    }

    @Test("Given a selection that is cleared, when the header is read again, then the title returns")
    func clearingSelectionRestoresTitle() {
        let viewModel = TitleGivesWayViewModel(rawSelection: moment(day: 10, hours: 12))
        viewModel.rawSelection = nil
        expectTitle(viewModel.header(locale: english))
    }

    @Test("Given the sample data, when every selection label is listed, then there is one per day, in order")
    func oneReservedLabelPerDay() {
        let texts = TitleGivesWayViewModel().allSelectionTexts(locale: english)
        #expect(texts.count == 28)
        #expect(texts.first?.dayText == "Sunday, March 1")
        #expect(texts.last?.dayText == "Saturday, March 28")
    }

    @Test("Given the sample data, when the labelled days are listed, then they count from the first day")
    func labelledDaysFromFirstDay() {
        let summary = TitleGivesWaySummary(stores: CafeData.storeSales, locale: english)
        #expect(summary.labelledDays(every: 7) == [0, 7, 14, 21].map { CafeData.day($0) })
        #expect(summary.labelledDays(every: 14) == [0, 14].map { CafeData.day($0) })
    }

    @Test("Given the sample data, when the value axis's marks are listed, then grid lines fall on every step and the accessibility labels on the ends")
    func cupsAxisMarks() {
        let summary = TitleGivesWaySummary(stores: CafeData.storeSales, locale: english)
        #expect(summary.cupsAxisSteps == [150, 200, 250, 300])
        #expect(summary.cupsAxisEnds == [150, 300])
    }

    @Test("Given a selected day, when its label is written, then it has a short form for the accessibility sizes")
    func shortDayText() {
        let viewModel = TitleGivesWayViewModel(rawSelection: moment(day: 3, hours: 7.25))
        guard case let .selection(text) = viewModel.header(locale: english) else {
            Issue.record("Expected the selection label")
            return
        }
        #expect(text.shortDayText == "Wed, Mar 4")
    }

    @Test("Given a café with one cup, when its value is written, then the count agrees in number")
    func valuesAgreeInNumber() {
        let stores = [StoreSales(store: CafeWording.harbour, days: [DailySales(day: CafeData.day(0), cups: 1)])]
        let summary = TitleGivesWaySummary(stores: stores, locale: english)
        let day = summary.days[0]
        #expect(summary.valuesText(day) == "Harbour 1 cup")
    }

    @Test("Given the sample data, when the headline is written, then it counts the days Harbour sold more")
    func headlineCountsDaysAhead() {
        let summary = TitleGivesWaySummary(stores: CafeData.storeSales, locale: english)
        let ahead = (0 ..< 28).count { cups(CafeWording.harbour, on: $0) > cups(CafeWording.station, on: $0) }
        #expect(summary.headline == "Harbour sold more cups than Station on \(ahead) of 28 days.")
        #expect(ahead == 13)
    }

    @Test("Given no data, when the headline and title are written, then they say so and nothing is selected")
    func emptyData() {
        let viewModel = TitleGivesWayViewModel(stores: [], rawSelection: moment(day: 3, hours: 7))
        #expect(!viewModel.hasData)
        #expect(viewModel.headline(locale: english) == "No sales recorded yet.")
        #expect(viewModel.selectedDay == nil)
        #expect(viewModel.header(locale: english) == .title("Cups a day"))
    }

    @Test("Given two cafés selling the same every day, when the headline is written, then it says Harbour never sold more")
    func allZeroHeadline() {
        let days = [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]
        let stores = [StoreSales(store: CafeWording.harbour, days: days), StoreSales(store: CafeWording.station, days: days)]
        let summary = TitleGivesWaySummary(stores: stores, locale: english)
        #expect(summary.headline == "Harbour never sold more cups than Station in these 2 days.")
        #expect(summary.cupsAxis == 0 ... 50)
    }

    @Test("Given the sample data, when the value axis is worked out, then it runs between round steps of 50 around the data")
    func cupsAxisAroundData() {
        let all = CafeData.storeSales.flatMap { $0.days.map(\.cups) }
        let axis = TitleGivesWaySummary(stores: CafeData.storeSales, locale: english).cupsAxis
        #expect(axis.lowerBound <= Double(all.min() ?? 0))
        #expect(axis.upperBound >= Double(all.max() ?? 0))
        #expect(axis.lowerBound.truncatingRemainder(dividingBy: 50) == 0)
        #expect(axis.upperBound.truncatingRemainder(dividingBy: 50) == 0)
    }

    @Test("Given the chart descriptor, when it is made, then it has a title, two continuous series of 28 days and values with units")
    func descriptor() throws {
        let summary = TitleGivesWaySummary(stores: CafeData.storeSales, locale: english)
        let descriptor = TitleGivesWayDescriptor(summary: summary).makeChartDescriptor()
        #expect(descriptor.title == "Cups a day at the Harbour and Station cafés")
        #expect(descriptor.summary?.hasPrefix("28 days, March 1 to March 28.") == true)
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.allSatisfy { $0.isContinuous && $0.dataPoints.count == 28 })
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == summary.cupsAxis)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan).isEmpty)
    }

    @Test("Given the built app, when its snippets are read, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in [
            "title-gives-way-to-selection-header",
            "title-gives-way-to-selection-reserve",
            "title-gives-way-to-selection-snap",
        ] {
            #expect(store[name] != nil, "missing \(name)")
        }
    }
}
