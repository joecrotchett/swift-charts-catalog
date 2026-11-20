import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct MarksAndPlotsTests {
    private let english = Locale(identifier: "en_US")

    private func order(_ id: Int, hour: Double, wait: Double) -> CafeOrder {
        CafeOrder(id: id, drink: "Latte", hour: hour, cups: 1, waitMinutes: wait)
    }

    @Test("Given a new screen, when it opens, then it draws the default number of orders with one plot")
    func defaults() {
        let model = MarksAndPlotsViewModel()

        #expect(model.drawing == .plot)
        #expect(model.orders.count == MarksAndPlotsViewModel.defaultCount)
        #expect(model.orders == CafeData.manyOrders(count: MarksAndPlotsViewModel.defaultCount))
    }

    @Test("Given the slider, when it moves to a count, then the orders are that many from the sample data")
    func sliderChangesOrders() {
        let model = MarksAndPlotsViewModel()

        model.orderCount = 5000

        #expect(model.orders.count == 5000)
        #expect(model.orders == CafeData.manyOrders(count: 5000))
        #expect(model.countText(locale: english) == "5,000")
    }

    @Test("Given either drawing, when the headline is written, then it is the same, as the chart is the same")
    func headlineSameForBothDrawings() {
        let model = MarksAndPlotsViewModel()
        let plotHeadline = model.summary(locale: english).headline

        model.drawing = .marks

        #expect(model.summary(locale: english).headline == plotHeadline)
    }

    @Test("Given orders, when the headline is written, then it gives the count and the highest point's wait")
    func headlineGivesLongestWait() {
        let orders = [order(0, hour: 7, wait: 2), order(1, hour: 8.25, wait: 11.34), order(2, hour: 12, wait: 4)]
        let summary = MarksAndPlotsSummary(orders: orders, locale: english)

        #expect(summary.headline == "3 orders, one point each. The longest wait was 11.3 minutes.")
    }

    @Test("Given the sample data, when the headline is written, then its wait is the longest in the data")
    func headlineFollowsSampleData() throws {
        let orders = CafeData.manyOrders(count: 2000)
        let longest = try #require(orders.map(\.waitMinutes).max())
        let words = MarksAndPlotsWording.minutes(longest, locale: english)

        #expect(MarksAndPlotsSummary(orders: orders, locale: english).headline.hasSuffix("The longest wait was \(words)."))
    }

    @Test("Given one order of one minute, when the words are written, then the counts agree in number")
    func countsAgreeInNumber() {
        let summary = MarksAndPlotsSummary(orders: [order(0, hour: 9, wait: 1)], locale: english)

        #expect(summary.headline == "1 order, one point each. The longest wait was 1 minute.")
    }

    @Test("Given no orders, when the words are written, then they say there is nothing to draw")
    func emptySaysSo() {
        let model = MarksAndPlotsViewModel(count: 0)
        let summary = model.summary(locale: english)

        #expect(model.isEmpty)
        #expect(summary.headline == "No orders to draw.")
        #expect(summary.audioGraphSummary == "No orders to draw.")
    }

    @Test("Given each drawing, when the snippets are listed, then the current one comes first and both exist")
    func snippetsFollowDrawing() throws {
        let model = MarksAndPlotsViewModel()
        let store = try SnippetStore()

        #expect(model.snippets.map(\.name) == ["marks-and-plots-plot", "marks-and-plots-marks", "marks-and-plots-spoken"])
        model.drawing = .marks
        #expect(model.snippets.map(\.name) == ["marks-and-plots-marks", "marks-and-plots-plot", "marks-and-plots-spoken"])
        for snippet in model.snippets {
            #expect(store[snippet.name] != nil)
        }
        #expect(store["marks-and-plots-plot"]?.code.contains("PointPlot(") == true)
        #expect(store["marks-and-plots-marks"]?.code.contains("ForEach(orders)") == true)
    }

    @Test("Given each drawing, when the caption and announcement are written, then they name what draws the chart, then the headline")
    func captionAndAnnouncement() {
        let model = MarksAndPlotsViewModel(count: 2000)
        let headline = model.summary(locale: english).headline

        #expect(model.drawingCaption(locale: english) == "One PointPlot takes the whole collection of 2,000 orders.")
        #expect(model.drawingAnnouncement(locale: english) == "Now drawn from one PointPlot. \(headline)")
        model.drawing = .marks
        #expect(model.drawingCaption(locale: english) == "ForEach makes one PointMark per order: 2,000 marks.")
        #expect(model.drawingAnnouncement(locale: english) == "Now drawn from a ForEach of PointMarks. \(headline)")
    }

    @Test("Given the slider, when its value is spoken, then it is the headline, which already gives the count")
    func sliderSpeaksHeadline() {
        let model = MarksAndPlotsViewModel()

        #expect(model.countSpokenValue(locale: english) == model.summary(locale: english).headline)
        #expect(model.countSpokenValue(locale: english).hasPrefix("2,000 orders"))
    }

    @Test("Given a German locale, when the headline is written, then its numbers are written the German way")
    func headlineTakesLocale() {
        let orders = (0 ..< 1500).map { order($0, hour: 9, wait: $0 == 7 ? 11.25 : 2) }
        let headline = MarksAndPlotsSummary(orders: orders, locale: Locale(identifier: "de_DE")).headline

        #expect(headline.hasPrefix("1.500 orders"))
        #expect(headline.contains("11,2") || headline.contains("11,3"))
    }

    @Test("Given hours since midnight, when they are written as times, then the device's time zone cannot shift them")
    func timesAreInDataCalendar() {
        #expect(MarksAndPlotsWording.time(hour: 8.25, locale: english) == "8:15\u{202F}AM")
        #expect(MarksAndPlotsWording.time(hour: 17.5, locale: english) == "5:30\u{202F}PM")
        #expect(MarksAndPlotsWording.time(hour: .nan, locale: english) == "")
    }

    @Test("Given the timing note, when it is read, then it gives the measured result and claims no speed for a plot")
    func timingNote() {
        let note = MarksAndPlotsViewModel.timingNote

        #expect(note.hasPrefix("Measured on the simulator with ImageRenderer, median of 6 renders"))
        #expect(note.contains("about 13 against 11 ms at 1,000 points, 52 against 45 at 5,000 and 192 against 168 at 20,000."))
        #expect(!note.lowercased().contains("faster"))
    }

    @Test("Given orders, when VoiceOver's stretches are made, then there are six of two hours, labelled with clock times")
    func spokenPortions() throws {
        let orders = [order(0, hour: 6, wait: 2), order(1, hour: 7.5, wait: 4), order(2, hour: 7.9, wait: 9), order(3, hour: 18, wait: 1)]
        let portions = TimeOfDayPortion.make(orders, hour: \.hour, wait: \.waitMinutes)
        let first = try #require(portions.first)
        let last = try #require(portions.last)

        #expect(portions.map(\.start) == [6, 8, 10, 12, 14, 16])
        #expect(first.label(locale: english) == "6:00\u{202F}AM to 8:00\u{202F}AM")
        #expect(first.value(locale: english) == "3 orders, waits from 2 minutes to 9 minutes, median 4 minutes")
        // An order at 6 pm falls in the last stretch.
        #expect(last.value(locale: english) == "1 order, waits from 1 minute to 1 minute, median 1 minute")
        #expect(portions[1].value(locale: english) == "No orders.")
    }

    @Test("Given each locale, when an hour is labelled, then it is the locale's clock, in the data's calendar")
    func hourLabels() {
        #expect(TimeOfDayWording.hourLabel(hour: 6, locale: english) == "6\u{202F}AM")
        #expect(TimeOfDayWording.hourLabel(hour: 15, locale: english) == "3\u{202F}PM")
        #expect(TimeOfDayWording.time(hour: 15, locale: Locale(identifier: "en_GB")) == "15:00")
        #expect(TimeOfDayWording.labelledHours(accessibilitySize: false) == [6, 9, 12, 15, 18])
        #expect(TimeOfDayWording.labelledHours(accessibilitySize: true) == [6, 12, 18])
    }

    @Test("Given thousands of orders, when the Audio Graph sample is taken, then it is at most 200 points in order of time")
    func sampleIsSmallAndOrdered() {
        let summary = MarksAndPlotsSummary(orders: CafeData.manyOrders(count: 20000), locale: english)
        let sample = summary.audioGraphSample

        #expect(sample.count == MarksAndPlotsSummary.audioGraphSampleSize)
        #expect(sample.map(\.hour) == sample.map(\.hour).sorted())
    }

    @Test("Given orders, when the descriptor is made, then it has a title, summary, axes with units and one sampled series")
    func descriptor() throws {
        let orders = [order(0, hour: 7, wait: 2), order(1, hour: 8.25, wait: 11.34), order(2, hour: 12, wait: 0.5)]
        let descriptor = MarksAndPlotsChartDescriptor(orders: orders, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Wait for each order by time of day, across the chain")
        #expect(descriptor.summary == "3 orders, one point each, from 7:00\u{202F}AM to 12:00\u{202F}PM. "
            + "Waits from 0.5 minutes to 11.3 minutes; the longest at 8:15\u{202F}AM.")
        #expect(xAxis.title == "Time of day")
        #expect(xAxis.range == 6 ... 18)
        #expect(xAxis.valueDescriptionProvider(8.25) == "8:15\u{202F}AM")
        #expect(yAxis.title == "Wait (minutes)")
        // The drawn wait axis: the longest wait, 11.34 minutes, rounded up to 15.
        #expect(yAxis.range == 0 ... 15)
        #expect(yAxis.valueDescriptionProvider(1) == "1 minute")
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
        #expect(descriptor.series.map(\.name) == ["Orders"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }

    @Test("Given thousands of orders, when the descriptor is made, then its summary says the Audio Graph plays a sample")
    func descriptorSaysSample() {
        let descriptor = MarksAndPlotsChartDescriptor(orders: CafeData.manyOrders(count: 2000), locale: english)
            .makeChartDescriptor()

        #expect(descriptor.summary?.contains("The Audio Graph plays an even sample of 200 orders.") == true)
        #expect(descriptor.series.first?.dataPoints.count == 200)
    }
}
