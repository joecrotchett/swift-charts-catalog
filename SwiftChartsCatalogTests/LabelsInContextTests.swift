import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LabelsInContextTests {
    private let locale = Locale(identifier: "en_US")

    /// Date formats put a narrow no-break space before "AM"; compare the words, not the space.
    private func plain(_ text: String) -> String {
        text.replacing("\u{202F}", with: " ")
    }

    private func day(_ offset: Int, cups: Int) -> DailySales {
        DailySales(day: CafeData.day(offset), cups: cups)
    }

    @Test("Given a new screen, when it opens, then it shows the written labels and their two snippets")
    func startsWritten() {
        let model = LabelsInContextViewModel()
        #expect(model.style == .written)
        #expect(model.days.count == 7)
        #expect(model.snippets.map(\.name) == ["labels-in-context-written", "labels-in-context-wording"])
    }

    @Test("Given the written labels, when the default is switched on, then the style and snippet follow")
    func switchesToDefault() {
        let model = LabelsInContextViewModel()
        model.isShowingDefault = true
        #expect(model.style == .framework)
        #expect(model.snippets.map(\.name) == ["labels-in-context-default"])
    }

    @Test("Given every snippet the screen can show, when the store is read, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let model = LabelsInContextViewModel()
        var names = model.snippets.map(\.name)
        model.isShowingDefault = true
        names += model.snippets.map(\.name)
        for name in names {
            #expect(store[name] != nil, "Missing snippet \(name)")
        }
    }

    @Test("Given the written labels, when the first day is spoken, then it reads the day and the cups")
    func writtenLine() throws {
        let model = LabelsInContextViewModel()
        let line = try #require(model.spokenLines(locale: locale).first)
        #expect(line.label == "Sunday, March 1")
        #expect(line.value == "190 cups")
        #expect(line.spoken == "Sunday, March 1, 190 cups")
    }

    @Test("Given the default, when the first day is spoken, then it is the UTC day as a range of date-times and a bare number")
    func frameworkLine() throws {
        let model = LabelsInContextViewModel()
        model.isShowingDefault = true
        let line = try #require(model.spokenLines(locale: locale).first)
        #expect(plain(line.label) == "Mar 1, 2026 at 12 AM to Mar 2, 2026 at 12 AM")
        #expect(line.value == "190")
    }

    @Test(
        "Given the data's calendar in any zone, when the default is spoken, then each day is read from its midnight in that zone",
        arguments: ["UTC", "America/Chicago", "Asia/Kolkata", "Pacific/Auckland"]
    )
    func frameworkLineFollowsTheCalendar(identifier: String) throws {
        // The label takes no device time zone: on iOS 27 a device six hours behind UTC read the UTC day, so
        // whatever zone the device is in, the reading follows only the calendar given to the value.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        let start = try #require(calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        let label = LabelsInContextSpokenText.frameworkLabel(for: start, dataCalendar: calendar, locale: locale)
        #expect(plain(label) == "Mar 1, 2026 at 12 AM to Mar 2, 2026 at 12 AM")
    }

    @Test("Given the sample week, when the default is spoken, then every day is the UTC day from 12 AM to 12 AM")
    func frameworkWeek() {
        let model = LabelsInContextViewModel()
        model.isShowingDefault = true
        let labels = model.spokenLines(locale: locale).map { plain($0.label) }
        #expect(labels.count == 7)
        #expect(labels.last == "Mar 7, 2026 at 12 AM to Mar 8, 2026 at 12 AM")
        #expect(labels.allSatisfy { $0.hasSuffix("at 12 AM") && $0.contains("at 12 AM to") })
    }

    @Test("Given one cup, when the value is written, then it agrees in number")
    func oneCup() {
        #expect(LabelsInContextSpokenText.writtenValue(cups: 1, locale: locale) == "1 cup")
    }

    @Test("Given the written labels, when the shortfalls are asked for, then there are none")
    func noShortfallsWhenWritten() {
        let model = LabelsInContextViewModel()
        #expect(model.shortfalls(locale: locale).isEmpty)
    }

    @Test("Given the default, when the shortfalls are listed, then the last contrasts the reading without a calendar")
    func shortfalls() {
        let model = LabelsInContextViewModel()
        model.isShowingDefault = true
        let items = model.shortfalls(locale: locale).map(plain)
        #expect(items.count == 3)
        #expect(items[0].contains("\u{201C}190\u{201D}"))
        #expect(items[2].contains("Leave out calendar:"))
        #expect(items[2].contains("\u{201C}Feb 28, 2026 at 12 AM to Mar 1, 2026 at 12 AM\u{201D}"))
    }

    @Test("Given a week that sold nothing, when the screen shows its placeholder, then nothing is spoken and the switch has nothing to change")
    func allZeroWeek() {
        let model = LabelsInContextViewModel(days: [day(0, cups: 0), day(1, cups: 0)])
        #expect(model.isEmpty)
        #expect(model.spokenLines(locale: locale).isEmpty)
        model.isShowingDefault = true
        #expect(model.spokenLines(locale: locale).isEmpty)
        #expect(model.shortfalls(locale: locale).isEmpty)
    }

    @Test("Given the sample week, when the caption is written, then it names the dates the data covers")
    func caption() {
        let caption = LabelsInContextViewModel().summary(locale: locale).caption
        #expect(caption == "Cups sold each day at the Harbour café, "
            + CafeWording.dayRange(CafeData.day(0), CafeData.day(6), locale: locale))
        // Month first, as on every other screen of these days.
        #expect(caption.contains("March 1"))
    }

    @Test("Given days across a month's end, when the caption is written, then both months are named")
    func captionAcrossMonths() {
        let summary = LabelsInContextSummary(
            days: [day(-1, cups: 5), day(5, cups: 9)], dataCalendar: CafeData.calendar, locale: locale
        )
        #expect(summary.caption == "Cups sold each day at the Harbour café, "
            + CafeWording.dayRange(CafeData.day(-1), CafeData.day(5), locale: locale))
        #expect(summary.caption.contains("February 28"))
        let none = LabelsInContextSummary(days: [], dataCalendar: CafeData.calendar, locale: locale)
        #expect(none.caption == "Cups sold each day at the Harbour café")
    }

    @Test("Given the sample week, when the headline is written, then it names the busiest day and its cups")
    func headline() {
        let summary = LabelsInContextViewModel().summary(locale: locale)
        #expect(summary.headline == "Busiest: Saturday, March 7, with 219 cups.")
        #expect(summary.valueAxisTop == 250)
    }

    @Test("Given a tie, when the headline is written, then both days are named")
    func headlineTie() {
        let summary = LabelsInContextSummary(
            days: [day(0, cups: 5), day(1, cups: 9), day(2, cups: 9)], dataCalendar: CafeData.calendar, locale: locale
        )
        #expect(summary.headline == "Busiest: Monday, March 2 and Tuesday, March 3, with 9 cups.")
    }

    @Test("Given no data or only zeros, when the headline is written, then it says nothing sold")
    func headlineEmpty() {
        let empty = LabelsInContextSummary(days: [], dataCalendar: CafeData.calendar, locale: locale)
        let zeros = LabelsInContextSummary(days: [day(0, cups: 0)], dataCalendar: CafeData.calendar, locale: locale)
        #expect(empty.headline == "No cups sold this week.")
        #expect(zeros.headline == "No cups sold this week.")
        #expect(zeros.valueAxisTop == LabelsInContextScale.roundingStep)
    }

    @Test("Given the sample week, when the descriptor is made, then it has written days, a matching range and cups")
    func descriptor() throws {
        let model = LabelsInContextViewModel()
        let descriptor = LabelsInContextChartDescriptor(days: model.days, dataCalendar: model.dataCalendar, locale: locale)
            .makeChartDescriptor()
        #expect(descriptor.title == "Cups sold each day at the Harbour café")
        #expect(descriptor.summary == "7 days, 1,211 cups in total. First day 190 cups, last day 219 cups. Most: Saturday, March 7, 219 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == 7)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 250)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Harbour")
        #expect(series.isContinuous == false)
        #expect(series.dataPoints.count == 7)
    }
}
