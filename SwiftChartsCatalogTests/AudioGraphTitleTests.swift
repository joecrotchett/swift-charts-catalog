import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct AudioGraphTitleTests {
    private let english = Locale(identifier: "en_US")
    private let week = AudioGraphTitleViewModel.sampleWeek

    private func descriptor(_ days: [DailySales], locale: Locale? = nil) -> AXChartDescriptor {
        AudioGraphTitleDescriptor(words: AudioGraphTitleWords(days: days, locale: locale ?? english)).makeChartDescriptor()
    }

    private var zeroWeek: [DailySales] {
        week.map { DailySales(day: $0.day, cups: 0) }
    }

    // MARK: Sample data

    @Test("Given the sample week, when it is read, then it is seven days from March 1 with a busiest Saturday")
    func sampleWeekIsAsExpected() {
        #expect(week.map(\.cups) == [190, 159, 152, 168, 155, 168, 219])
    }

    // MARK: Headline

    @Test("Given the sample week, when the headline is written, then it names the tallest bar's day and cups")
    func headlineNamesBusiestDay() {
        #expect(AudioGraphTitleWords(days: week, locale: english).headline
            == "The café sold the most on Saturday, March 7: 219 cups.")
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func headlineNamesTies() {
        let tied = [DailySales(day: CafeData.day(0), cups: 40), DailySales(day: CafeData.day(1), cups: 40)]

        #expect(AudioGraphTitleWords(days: tied, locale: english).headline
            == "The café sold the most on Sunday, March 1 and Monday, March 2: 40 cups.")
    }

    @Test("Given all-zero days, when the headline is written, then it says nothing sold over the period")
    func headlineAllZero() {
        #expect(AudioGraphTitleWords(days: zeroWeek, locale: english).headline == "No cups sold from March 1 to March 7.")
    }

    @Test("Given no days, when the headline is written, then it says there is nothing to show")
    func headlineEmpty() {
        #expect(AudioGraphTitleWords(days: [], locale: english).headline == "No days to show.")
    }

    @Test("Given one cup on the busiest day, when the headline is written, then the count agrees in number")
    func headlineAgreesInNumber() {
        let one = [DailySales(day: CafeData.day(0), cups: 1)]

        #expect(AudioGraphTitleWords(days: one, locale: english).headline == "The café sold the most on Sunday, March 1: 1 cup.")
    }

    // MARK: Elements

    @Test("Given a day, when its element text is written, then it is the date in the data's time zone and the cups")
    func elementText() throws {
        let words = AudioGraphTitleWords(days: week, locale: english)
        let first = try #require(week.first)

        #expect(words.elementLabel(first) == "Sunday, March 1")
        #expect(words.elementValue(first) == "190 cups")
    }

    // MARK: Descriptor: normal data

    @Test("Given the sample week, when the descriptor is made, then its title and summary give the period and values")
    func descriptorTitleAndSummary() {
        let made = descriptor(week)

        #expect(made.title == "Cups sold each day at the Harbour café")
        #expect(made.summary == "7 days, March 1 to March 7. 1,211 cups in total. "
            + "Fewest: 152 cups on Tuesday, March 3. Most: 219 cups on Saturday, March 7.")
    }

    @Test("Given the sample week, when the descriptor is made, then its axis titles differ from the chart's value labels")
    func descriptorAxisTitles() throws {
        let made = descriptor(week)
        let yAxis = try #require(made.yAxis)

        #expect(made.xAxis.title == "Date")
        #expect(yAxis.title == "Cups sold")
        #expect(made.xAxis.title != CafeWording.day)
        #expect(yAxis.title != CafeWording.cups)
    }

    @Test("Given the sample week, when the descriptor is made, then the dates are written-out categories in order")
    func descriptorDates() throws {
        let xAxis = try #require(descriptor(week).xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(xAxis.categoryOrder == [
            "Sunday, March 1", "Monday, March 2", "Tuesday, March 3", "Wednesday, March 4",
            "Thursday, March 5", "Friday, March 6", "Saturday, March 7",
        ])
    }

    @Test("Given the sample week, when the descriptor is made, then the value axis is the drawn scale, 0 to 300, with units")
    func descriptorValueAxis() throws {
        let yAxis = try #require(descriptor(week).yAxis)

        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.range == AudioGraphTitleViewModel().yDomain)
        #expect(yAxis.valueDescriptionProvider(219) == "219 cups")
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given a taller week, when the scale is chosen, then it rounds the tallest bar up to the next hundred")
    func yDomainRoundsUp() {
        #expect(AudioGraphTitleWords.yDomain(for: [DailySales(day: CafeData.day(0), cups: 300)]) == 0 ... 300)
        #expect(AudioGraphTitleWords.yDomain(for: [DailySales(day: CafeData.day(0), cups: 301)]) == 0 ... 400)
        #expect(AudioGraphTitleWords.yDomain(for: []) == 0 ... 100)
    }

    @Test("Given the sample week, when the descriptor is made, then it has one named series of separate values, one per day")
    func descriptorSeries() throws {
        let series = try #require(descriptor(week).series.first)

        #expect(descriptor(week).series.count == 1)
        #expect(series.name == "Harbour")
        #expect(series.isContinuous == false)
        #expect(series.dataPoints.count == 7)
    }

    @Test("Given the sample week, when the descriptor is written out, then each point says its date and cups")
    func descriptorPointText() {
        let rows = AudioGraphTitleViewModel.rows(from: descriptor(week), days: week)
        let points = rows.filter { $0.id.hasPrefix("point-") }.map(\.text)

        #expect(points == [
            "Sunday, March 1, 190 cups", "Monday, March 2, 159 cups", "Tuesday, March 3, 152 cups",
            "Wednesday, March 4, 168 cups", "Thursday, March 5, 155 cups", "Friday, March 6, 168 cups",
            "Saturday, March 7, 219 cups",
        ])
    }

    @Test("Given the sample week, when the descriptor is written out, then the rows give title, axes and series")
    func descriptorRows() {
        let rows = AudioGraphTitleViewModel.rows(from: descriptor(week), days: week)
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.text) })

        #expect(byID["title"] == "Cups sold each day at the Harbour café")
        #expect(byID["x-axis"] == "Date: Sunday, March 1 to Saturday, March 7")
        #expect(byID["y-axis"] == "Cups sold: 0 cups to 300 cups")
        #expect(byID["series-0"] == "Harbour, separate values")
    }

    @Test("Given a German locale, when the descriptor is made, then numbers and dates follow the locale")
    func descriptorFollowsLocale() throws {
        let made = descriptor(week, locale: Locale(identifier: "de_DE"))
        let yAxis = try #require(made.yAxis)
        let xAxis = try #require(made.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(made.summary?.contains("1.211") == true)
        #expect(yAxis.valueDescriptionProvider(1211) == "1.211 cups")
        #expect(xAxis.categoryOrder.first?.contains("März") == true)
    }

    // MARK: Descriptor: empty and all-zero data

    @Test("Given all-zero days, when the descriptor is made, then it keeps the dates, says nothing sold, and runs 0 to 100")
    func descriptorAllZero() throws {
        let made = descriptor(zeroWeek)
        let yAxis = try #require(made.yAxis)
        let xAxis = try #require(made.xAxis as? AXCategoricalDataAxisDescriptor)
        let points = AudioGraphTitleViewModel.rows(from: made, days: zeroWeek).filter { $0.id.hasPrefix("point-") }

        #expect(made.title == "Cups sold each day at the Harbour café")
        #expect(made.summary == "7 days, March 1 to March 7. No cups sold.")
        #expect(yAxis.range == 0 ... 100)
        #expect(xAxis.categoryOrder.count == 7)
        #expect(points.first?.text == "Sunday, March 1, 0 cups")
        #expect(points.count == 7)
    }

    @Test("Given no days, when the descriptor is made, then it says so, has no categories or points, and runs 0 to 100")
    func descriptorEmpty() throws {
        let made = descriptor([])
        let yAxis = try #require(made.yAxis)
        let xAxis = try #require(made.xAxis as? AXCategoricalDataAxisDescriptor)
        let rows = AudioGraphTitleViewModel.rows(from: made, days: [])

        #expect(made.title == "Cups sold each day at the Harbour café")
        #expect(made.summary == "No days to show.")
        #expect(yAxis.range == 0 ... 100)
        #expect(xAxis.categoryOrder.isEmpty)
        #expect(made.series.first?.dataPoints.isEmpty == true)
        #expect(rows.first { $0.id == "x-axis" }?.text == "Date")
        #expect(rows.filter { $0.id.hasPrefix("point-") }.isEmpty)
    }

    // MARK: The default, as read on iOS

    @Test("Given the sample week, when the default is written out, then it is titled Chart, has no summary and bare numbers")
    func readDefault() {
        let rows = AudioGraphTitleWords(days: week, locale: english).defaultRows
        let byID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.text) })

        #expect(byID["title"] == "Chart")
        #expect(byID["summary"] == "None")
        #expect(byID["x-axis"] == "Day, as numbers (seconds since 2001), both ends read as empty")
        #expect(byID["y-axis"] == "Cups, 0 to 300, the drawn scale, no unit")
        #expect(byID["series"] == "One series with no name, separate values")
        #expect(rows.filter { $0.id.hasPrefix("point-") }.map(\.text) == ["190", "159", "152", "168", "155", "168", "219"])
    }

    // MARK: View model

    @Test("Given the screen opens, when nothing is touched, then the descriptor is attached and its snippets show")
    func startsWithDescriptor() {
        let model = AudioGraphTitleViewModel()

        #expect(model.isShowingDefault == false)
        #expect(model.showsPlaceholder == false)
        #expect(model.snippets.map(\.name)
            == ["audio-graph-title-chart", "audio-graph-title-attach", "audio-graph-title-descriptor"])
    }

    @Test("Given the toggle is on, when the snippets are listed, then they show the chart with no descriptor")
    func defaultSnippets() {
        let model = AudioGraphTitleViewModel()
        model.isShowingDefault = true

        #expect(model.snippets.map(\.name) == ["audio-graph-title-chart", "audio-graph-title-default"])
    }

    @Test("Given no days or only zeros, when the model is asked, then a placeholder replaces the chart")
    func placeholder() {
        #expect(AudioGraphTitleViewModel(days: []).showsPlaceholder)
        #expect(AudioGraphTitleViewModel(days: zeroWeek).showsPlaceholder)
    }

    @Test("Given the model, when its descriptor rows are read, then they come from the descriptor it attaches")
    func modelRowsMatchDescriptor() {
        let model = AudioGraphTitleViewModel()

        #expect(model.descriptorRows(locale: english) == AudioGraphTitleViewModel.rows(from: descriptor(week), days: week))
    }

    @Test("Given the app's snippets, when each state's names are looked up, then every one exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ["audio-graph-title-chart", "audio-graph-title-attach", "audio-graph-title-descriptor", "audio-graph-title-default"]

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }
}
