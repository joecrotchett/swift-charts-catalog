import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ChartScrollingTests {
    private let english = Locale(identifier: "en_US")
    private let calendar = CafeData.calendar

    /// A moment on the given day of the sample data, in UTC.
    private func time(day offset: Int, hour: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(hour: hour), to: CafeData.day(offset)) ?? .distantPast
    }

    private func summary(at position: Date, days: Int = 14, data: [DailySales] = CafeData.tenWeeks) -> ChartScrollingSummary {
        ChartScrollingSummary(days: data, position: position, visibleDays: days, locale: english)
    }

    // MARK: The visible window and its headline

    @Test("Given the position at the first day and two weeks in view, when the window is read, then it is 1 to 14 March")
    func windowAtTheStart() {
        let window = summary(at: CafeData.day(0))

        #expect(window.visibleSales.map(\.day) == (0 ..< 14).map(CafeData.day))
        #expect(window.windowEnd == CafeData.day(14))
        #expect(window.headline == "March 1 to March 14: 14 days, 2,569 cups.")
    }

    @Test("Given the position at the latest it can go, when the window is read, then it ends on the last day, 9 May")
    func windowAtTheEnd() {
        let model = ChartScrollingViewModel()
        model.scrollPosition = model.latestPosition

        #expect(model.scrollPosition == CafeData.day(56))
        let window = model.summary(locale: english)
        #expect(window.visibleSales.last?.day == CafeData.day(69))
        #expect(window.windowEnd == CafeData.day(70))
        #expect(window.headline == "April 26 to May 9: 14 days, 4,921 cups.")
    }

    @Test("Given each visible length at the end of the data, when the headline is read, then it covers that many days up to 9 May")
    func headlineAtTheEndForEachLength() {
        let model = ChartScrollingViewModel()
        let expected: [ChartScrollingLength: String] = [
            .oneWeek: "May 3 to May 9: 7 days, 2,534 cups.",
            .twoWeeks: "April 26 to May 9: 14 days, 4,921 cups.",
            .fourWeeks: "April 12 to May 9: 28 days, 9,254 cups.",
        ]
        for length in ChartScrollingLength.allCases {
            model.visibleLength = length
            model.scrollPosition = model.latestPosition
            #expect(model.summary(locale: english).headline == expected[length])
        }
    }

    @Test("Given a position partway through the first day, when the window is read, then a bar more than half in view is counted")
    func partDayBeforeMidday() {
        let window = summary(at: time(day: 0, hour: 10))

        #expect(window.visibleSales.first?.day == CafeData.day(0))
        #expect(window.visibleSales.count == 14)
        #expect(window.headline == "March 1 to March 14: 14 days, 2,569 cups.")
    }

    @Test("Given a position past midday of the first day, when the window is read, then the half-hidden first bar is left out and the next day's bar is in")
    func partDayAfterMidday() {
        let window = summary(at: time(day: 0, hour: 13))

        #expect(window.visibleSales.first?.day == CafeData.day(1))
        #expect(window.visibleSales.last?.day == CafeData.day(14))
        #expect(window.headline == "March 2 to March 15: 14 days, 2,611 cups.")
    }

    @Test("Given one day of data, when the headline is read, then it names that day alone and agrees in number")
    func headlineForOneDay() {
        let window = summary(at: CafeData.day(0), data: [DailySales(day: CafeData.day(0), cups: 1)])

        #expect(window.headline == "March 1: 1 day, 1 cup.")
    }

    @Test("Given no data, when the summary is read, then there is nothing to draw and the headline says so")
    func headlineWithNoData() {
        let window = summary(at: CafeData.day(0), data: [])

        #expect(window.hasNoSales)
        #expect(window.domain == nil)
        #expect(window.headline == "No days of sales yet.")
        #expect(window.audioGraphSummary == "No days of sales yet.")
    }

    @Test("Given only zeros, when the summary is read, then it is treated as no sales and names how many days")
    func headlineWithOnlyZeros() {
        let zeros = (0 ..< 14).map { DailySales(day: CafeData.day($0), cups: 0) }
        let window = summary(at: CafeData.day(0), data: zeros)

        #expect(window.hasNoSales)
        #expect(window.headline == "No cups sold in 14 days.")
        #expect(window.audioGraphSummary == "No cups sold in 14 days.")
    }

    @Test("Given a German locale and each visible length, when the reserved headline is read, then it is the longest headline at any start day")
    func reservedHeadlineIsLongestInGerman() {
        let german = Locale(identifier: "de_DE")
        for length in ChartScrollingLength.allCases {
            let headlines = (0 ... CafeData.tenWeeks.count - length.days).map { start in
                ChartScrollingSummary(
                    days: CafeData.tenWeeks, position: CafeData.day(start), visibleDays: length.days, locale: german
                ).headline
            }
            let reserved = ChartScrollingSummary(
                days: CafeData.tenWeeks, position: CafeData.day(0), visibleDays: length.days, locale: german
            ).reservedHeadline

            #expect(headlines.contains(reserved))
            #expect(headlines.allSatisfy { $0.count <= reserved.count })
        }
    }

    @Test("Given a German locale, when the headline is read, then its numbers follow the locale")
    func headlineTakesTheLocale() {
        let window = ChartScrollingSummary(
            days: CafeData.tenWeeks, position: CafeData.day(0), visibleDays: 14, locale: Locale(identifier: "de_DE")
        )

        #expect(window.headline.contains("2.569"))
    }

    @Test("Given the data, when the domain is read, then it runs from the first midnight to the end of the last day")
    func domainCoversWholeDays() {
        #expect(summary(at: CafeData.day(0)).domain == CafeData.day(0) ... CafeData.day(70))
    }

    // MARK: Moving the window without a gesture

    @Test("Given the start of the data, when the model is read, then Earlier is unavailable and Later is available")
    func buttonsAtTheStart() {
        let model = ChartScrollingViewModel()

        #expect(model.scrollPosition == CafeData.day(0))
        #expect(!model.canShowEarlier)
        #expect(model.canShowLater)
    }

    @Test("Given two weeks in view, when Later is pressed, then the window moves on two weeks; and Earlier moves it back")
    func laterAndEarlier() {
        let model = ChartScrollingViewModel()

        model.showLater()
        #expect(model.scrollPosition == CafeData.day(14))
        #expect(model.summary(locale: english).headline.hasPrefix("March 15 to March 28"))
        model.showEarlier()
        #expect(model.scrollPosition == CafeData.day(0))
    }

    @Test("Given Earlier or Later pressed, when the announcement is written, then it says what changed, then the headline")
    func moveAnnouncements() {
        let model = ChartScrollingViewModel()

        model.showLater()
        #expect(model.moveAnnouncement(earlier: false, locale: english)
            == "Showing later days. March 15 to March 28: 14 days, \(CafeWording.cups(model.summary(locale: english).visibleTotal, locale: english)).")
        model.showEarlier()
        #expect(model.moveAnnouncement(earlier: true, locale: english)
            == "Showing earlier days. March 1 to March 14: 14 days, 2,569 cups.")
    }

    @Test("Given the window near the end, when Later is pressed, then it stops at the last full window")
    func laterStopsAtTheEnd() {
        let model = ChartScrollingViewModel()
        model.scrollPosition = CafeData.day(50)

        model.showLater()
        #expect(model.scrollPosition == CafeData.day(56))
        #expect(!model.canShowLater)
        model.showLater()
        #expect(model.scrollPosition == CafeData.day(56))
    }

    @Test("Given the window near the start, when Earlier is pressed, then it stops at the first day")
    func earlierStopsAtTheStart() {
        let model = ChartScrollingViewModel()
        model.scrollPosition = CafeData.day(5)

        model.showEarlier()
        #expect(model.scrollPosition == CafeData.day(0))
    }

    @Test("Given the window at the end, when the visible length grows and the position is clamped, then the window still ends on the last day")
    func clampAfterLengthGrows() {
        let model = ChartScrollingViewModel()
        model.scrollPosition = model.latestPosition

        model.visibleLength = .fourWeeks
        model.clampPosition()
        #expect(model.scrollPosition == CafeData.day(42))
        #expect(model.lengthAnnouncement(locale: english) == "Showing 4 weeks at a time. April 12 to May 9: 28 days, 9,254 cups.")
    }

    // MARK: Snapping choices and snippets

    @Test("Given each resting point, when its components are read, then they match midnight in UTC, and a Sunday for weeks")
    func restComponents() {
        let day = ChartScrollingRest.day.components
        #expect(day.hour == 0)
        #expect(day.weekday == nil)
        #expect(day.timeZone == TimeZone(identifier: "UTC"))
        #expect(day.calendar?.timeZone == TimeZone(identifier: "UTC"))

        let week = ChartScrollingRest.week.components
        #expect(week.hour == 0)
        #expect(week.weekday == 1)
        #expect(calendar.component(.weekday, from: CafeData.day(0)) == 1)
    }

    @Test("Given snapping on and then off, when the snippets are read, then they follow the switch")
    func snippetsFollowSnapping() {
        let model = ChartScrollingViewModel()

        #expect(model.snippets.map(\.name) == [
            "scrolling-chart", "scrolling-window", "scrolling-representation", "scrolling-value-aligned",
            "scrolling-rest-components",
        ])
        model.isSnapping = false
        #expect(model.snippets.map(\.name) == ["scrolling-chart", "scrolling-window", "scrolling-representation", "scrolling-free"])
    }

    @Test("Given no sales or a small week, when the value axis is read, then it is rounded up to 50 cups and never empty")
    func cupsAxis() {
        let none = ChartScrollingSummary(days: [], position: CafeData.firstDay, visibleDays: 14, locale: .current)
        #expect(none.cupsAxis == 0 ... 50)
        let small = ChartScrollingSummary(
            days: [DailySales(day: CafeData.day(0), cups: 51)], position: CafeData.firstDay, visibleDays: 14, locale: .current
        )
        #expect(small.cupsAxis == 0 ... 100)
    }

    @Test("Given the built app, when every snippet the screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let model = ChartScrollingViewModel()
        var names = model.snippets.map(\.name)
        model.isSnapping = false
        names += model.snippets.map(\.name)

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Accessibility text

    @Test("Given the data, when the weekly elements are read, then there are ten, each a week with its total, lowest and highest day")
    func weeklyElements() {
        let weeks = summary(at: CafeData.day(0)).weeks

        #expect(weeks.count == 10)
        #expect(weeks.allSatisfy { $0.days.count == 7 })
        #expect(weeks.first?.label == "March 1 to March 7")
        #expect(weeks.first?.value == "1,211 cups; lowest day 152 cups, highest 219 cups")
        #expect(weeks.last?.label == "May 3 to May 9")
    }

    @Test("Given the start of the data, when the descriptor is made, then it describes all seventy days with the window in its summary")
    func descriptor() throws {
        let descriptor = ChartScrollingChartDescriptor(summary: summary(at: CafeData.day(0))).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café over ten weeks, a scrolling chart")
        #expect(descriptor.summary == "70 days, March 1 to May 9. In view: March 1 to March 14, 14 days and 2,569 cups. "
            + "Lowest day 152 cups on March 3, highest 408 cups on May 9.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder.count == 70)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The axis as drawn: the highest day, 408 cups, rounded up to the next 50.
        #expect(yAxis.range == 0 ... 450)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 70)
    }
}
