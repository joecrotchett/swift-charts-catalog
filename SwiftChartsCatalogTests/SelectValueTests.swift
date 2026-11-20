import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SelectValueTests {
    private let english = Locale(identifier: "en_US")
    private let calendar = CafeData.calendar
    /// Three days: 1, 2 and 3 March, 100, 140 and 120 cups.
    private let days = [
        DailySales(day: CafeData.day(0), cups: 100),
        DailySales(day: CafeData.day(1), cups: 140),
        DailySales(day: CafeData.day(2), cups: 120),
    ]

    /// A moment on the given day of the sample data, in UTC.
    private func time(day offset: Int, hour: Int, minute: Int = 0) -> Date {
        calendar.date(byAdding: DateComponents(hour: hour, minute: minute), to: CafeData.day(offset)) ?? .distantPast
    }

    // MARK: Snapping

    @Test("Given a raw value inside a day, when it is snapped, then it lands on that day")
    func snapsInsideADay() {
        #expect(SelectValueSummary.nearestDay(to: time(day: 1, hour: 7, minute: 14), in: days)?.day == CafeData.day(1))
        #expect(SelectValueSummary.nearestDay(to: time(day: 1, hour: 23, minute: 30), in: days)?.day == CafeData.day(1))
    }

    @Test("Given a raw value just past midnight, when it is snapped, then it lands on the new day")
    func snapsAcrossMidnight() {
        #expect(SelectValueSummary.nearestDay(to: time(day: 2, hour: 0, minute: 30), in: days)?.day == CafeData.day(2))
    }

    @Test("Given a raw value before the first point, when it is snapped, then it lands on the first day")
    func snapsBeforeTheFirstPoint() {
        #expect(SelectValueSummary.nearestDay(to: time(day: 0, hour: 1), in: days)?.day == CafeData.day(0))
        #expect(SelectValueSummary.nearestDay(to: time(day: -3, hour: 9), in: days)?.day == CafeData.day(0))
    }

    @Test("Given a raw value after the last point, when it is snapped, then it lands on the last day")
    func snapsAfterTheLastPoint() {
        #expect(SelectValueSummary.nearestDay(to: time(day: 2, hour: 22), in: days)?.day == CafeData.day(2))
        #expect(SelectValueSummary.nearestDay(to: time(day: 9, hour: 9), in: days)?.day == CafeData.day(2))
    }

    @Test("Given no days, when a raw value is snapped, then there is no day")
    func snapsToNothingWithoutDays() {
        #expect(SelectValueSummary.nearestDay(to: time(day: 0, hour: 9), in: []) == nil)
    }

    // MARK: The view model's states

    @Test("Given a selection with snapping on, when the model is read, then the rule is at the snapped day and not at the raw value")
    func snappingOnDrawsTheDay() {
        let model = SelectValueViewModel(days: days)
        model.rawSelection = time(day: 1, hour: 7, minute: 14)

        #expect(model.snappedDay?.day == CafeData.day(1))
        #expect(model.unsnappedSelection == nil)
    }

    @Test("Given a selection with snapping off, when the model is read, then the rule is at the raw value and no day is snapped")
    func snappingOffDrawsTheRawValue() {
        let model = SelectValueViewModel(days: days)
        model.isSnapping = false
        model.rawSelection = time(day: 1, hour: 7, minute: 14)

        #expect(model.snappedDay == nil)
        #expect(model.unsnappedSelection == time(day: 1, hour: 7, minute: 14))
    }

    @Test("Given no selection, when the model is read, then nothing is drawn for a selection")
    func noSelectionDrawsNothing() {
        let model = SelectValueViewModel(days: days)

        #expect(model.snappedDay == nil)
        #expect(model.unsnappedSelection == nil)
        #expect(model.isSnapping)
    }

    // MARK: The headline

    @Test("Given no selection, when the headline is written, then it names the busiest day and its cups")
    func headlineWithoutSelection() {
        let model = SelectValueViewModel(days: days)

        #expect(model.headline(locale: english) == "The busiest day was Monday, March 2: 140 cups.")
    }

    @Test("Given a snapped selection, when the headline is written, then it gives the selected day and its cups")
    func headlineWithSnappedSelection() {
        let model = SelectValueViewModel(days: days)
        model.rawSelection = time(day: 2, hour: 15)

        #expect(model.headline(locale: english) == "Tuesday, March 3: 120 cups.")
    }

    @Test("Given an unsnapped selection, when the headline is written, then it gives the raw value and says no data point is there")
    func headlineWithRawSelection() {
        let model = SelectValueViewModel(days: days)
        model.isSnapping = false
        model.rawSelection = time(day: 1, hour: 7, minute: 14)

        let raw = SelectValueSummary(days: days, locale: english).rawText(time(day: 1, hour: 7, minute: 14))

        #expect(raw.hasPrefix("March 2"))
        #expect(raw.contains("7:14"))
        #expect(raw.hasSuffix(" UTC"))
        #expect(model.headline(locale: english) == "\(raw) is between data points: no day's cups are at that exact time.")
    }

    @Test("Given the selection is cleared, when the headline is written, then it returns to the busiest day")
    func headlineReturnsAfterSelection() {
        let model = SelectValueViewModel(days: days)
        model.rawSelection = time(day: 0, hour: 9)
        model.rawSelection = nil

        #expect(model.headline(locale: english) == "The busiest day was Monday, March 2: 140 cups.")
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func headlineNamesTies() {
        let tied = [DailySales(day: CafeData.day(0), cups: 90), DailySales(day: CafeData.day(1), cups: 90)]

        #expect(SelectValueViewModel(days: tied).headline(locale: english)
            == "The busiest days were Sunday, March 1 and Monday, March 2: 90 cups each.")
    }

    @Test("Given days that are all zero or no days, when the headline is written, then it names no busiest day")
    func headlineForZeroAndEmpty() {
        let zeros = [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]

        #expect(SelectValueViewModel(days: zeros).headline(locale: english) == "No cups sold in 2 days.")
        #expect(SelectValueViewModel(days: []).headline(locale: english) == "No days of sales yet.")
    }

    @Test("Given a selected day of one cup, when the headline is written, then the count agrees in number")
    func headlineAgreesInNumber() {
        let model = SelectValueViewModel(days: [DailySales(day: CafeData.day(0), cups: 1)])
        model.rawSelection = time(day: 0, hour: 12)

        #expect(model.headline(locale: english) == "Sunday, March 1: 1 cup.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let model = SelectValueViewModel(days: [DailySales(day: CafeData.day(0), cups: 1200)])

        #expect(model.headline(locale: Locale(identifier: "de_DE")).contains("1.200"))
    }

    @Test("Given the sample data, when the headline is written at rest, then its day is the sample's busiest")
    func headlineFollowsSampleData() throws {
        let busiest = try #require(CafeData.harbourSales.max { $0.cups < $1.cups })
        let summary = SelectValueSummary(days: CafeData.harbourSales, locale: english)

        #expect(SelectValueViewModel().headline(locale: english).contains(summary.dayText(busiest.day)))
    }

    // MARK: Popover

    @Test("Given a snapped selection, when the popover is written, then it gives the day, its cups and the raw time it came from")
    func snappedPopoverText() {
        let summary = SelectValueSummary(days: days, locale: english)
        let text = summary.snappedPopover(day: days[1], rawSelection: time(day: 1, hour: 7, minute: 14))

        #expect(text.title == "Monday, March 2")
        #expect(text.value == "140 cups")
        #expect(text.footnote.hasPrefix("Snapped from March 2"))
        #expect(text.footnote.contains("7:14"))
        #expect(text.compactValue == "140 cups")
    }

    @Test("Given an unsnapped selection, when the popover is written, then it gives the raw value and says it is not a data point")
    func rawPopoverText() {
        let text = SelectValueSummary(days: days, locale: english).rawPopover(rawSelection: time(day: 1, hour: 7, minute: 14))

        #expect(text.title == "Raw value")
        #expect(text.value.contains("7:14"))
        #expect(text.footnote == "Not a data point")
        #expect(text.compactValue.contains("7:14"))
        #expect(text.compactValue.hasSuffix(" UTC"))
        #expect(!text.compactValue.contains("March"))
    }

    @Test("Given a raw value late in a UTC day, when it is written, then it names that UTC day and hour")
    func rawTextIsInUTC() {
        let text = SelectValueSummary(days: days, locale: english).rawText(time(day: 1, hour: 23, minute: 30))

        #expect(text.hasPrefix("March 2"))
        #expect(text.contains("11:30"))
    }

    // MARK: Room kept for the headline

    @Test("Given each snapping setting, when the reserved headline is read, then it is the longest headline at rest or for a selection on any day")
    func reservedHeadlineIsTheLongest() throws {
        let sample = CafeData.harbourSales
        let model = SelectValueViewModel(days: sample)
        for isSnapping in [true, false] {
            model.isSnapping = isSnapping
            let reserved = try #require(model.reservedHeadline(locale: english))
            var headlines = [model.headline(locale: english)]
            for day in sample.indices {
                for hour in [0, 7, 12, 22] {
                    model.rawSelection = time(day: day, hour: hour, minute: 58)
                    headlines.append(model.headline(locale: english))
                }
            }
            model.rawSelection = nil

            #expect(headlines.allSatisfy { $0.count <= reserved.count })
            #expect(reserved.count == headlines.map(\.count).max())
        }
    }

    @Test("Given snapping on and a resting headline longer than any day's, when the reserved headline is read, then it is the resting one")
    func reservedHeadlineWhileSnapping() {
        let model = SelectValueViewModel(days: days)

        #expect(model.reservedHeadline(locale: english) == "The busiest day was Monday, March 2: 140 cups.")
    }

    @Test("Given snapping off, when the reserved headline is read, then it is a raw value's headline in UTC")
    func reservedHeadlineWithoutSnapping() throws {
        let model = SelectValueViewModel(days: days)
        model.isSnapping = false
        let reserved = try #require(model.reservedHeadline(locale: english))

        #expect(reserved.contains("UTC is between data points"))
        #expect(reserved.contains("10:58"))
    }

    @Test("Given no days, when the reserved headline is read, then nothing is reserved")
    func reservedHeadlineWithoutDays() {
        #expect(SelectValueViewModel(days: []).reservedHeadline(locale: english) == nil)
    }

    // MARK: Snippets

    @Test("Given each setting, when the snippets are listed, then they follow the setting and exist in the bundle")
    func snippetsFollowTheSetting() throws {
        let store = try SnippetStore()
        let model = SelectValueViewModel(days: days)

        #expect(model.snippets.map(\.name) == ["select-a-value-binding", "select-a-value-snap", "select-a-value-snapped-rule"])
        model.isSnapping = false
        #expect(model.snippets.map(\.name) == ["select-a-value-binding", "select-a-value-raw-rule"])

        for name in ["select-a-value-binding", "select-a-value-snap", "select-a-value-snapped-rule", "select-a-value-raw-rule"] {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    // MARK: The Audio Graph

    @Test("Given days, when the Audio Graph summary is written, then it gives actual values")
    func audioGraphSummary() {
        #expect(SelectValueSummary(days: days, locale: english).audioGraphSummary
            == "3 days, March 1 to March 3. First day 100 cups, last day 120 cups. Lowest 100 cups, highest 140 cups.")
        #expect(SelectValueSummary(days: [], locale: english).audioGraphSummary == "No days of sales yet.")
    }

    @Test("Given days, when the chart descriptor is made, then it has a title, written-out dates and one continuous named series")
    func descriptorDescribesTheChart() throws {
        let descriptor = SelectValueChartDescriptor(days: days, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let series = try #require(descriptor.series.first)

        #expect(descriptor.title == "Cups sold each day at the Harbour café")
        #expect(descriptor.summary == SelectValueSummary(days: days, locale: english).audioGraphSummary)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder == ["Sunday, March 1", "Monday, March 2", "Tuesday, March 3"])
        #expect(descriptor.series.count == 1)
        #expect(series.name == CafeWording.harbour)
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == 3)
    }

    @Test("Given days, when the descriptor's value axis is read, then it runs from zero to the drawn top and speaks cups")
    func descriptorValueAxis() throws {
        let yAxis = try #require(SelectValueChartDescriptor(days: days, locale: english).makeChartDescriptor().yAxis)

        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // 140 cups rounds up to 150, the domain the chart is given.
        #expect(yAxis.range == 0 ... 150)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(120) == "120 cups")
    }
}
