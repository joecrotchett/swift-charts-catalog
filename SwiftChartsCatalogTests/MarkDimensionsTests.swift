import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct MarkDimensionsTests {
    private let locale = Locale(identifier: "en_US")

    private func sales(_ cups: [Int]) -> [DailySales] {
        cups.enumerated().map { DailySales(day: CafeData.day($0.offset), cups: $0.element) }
    }

    // MARK: The view model

    @Test("Given a new screen, when it opens, then it shows fourteen days at the automatic width")
    func startsAutomatic() {
        let model = MarkDimensionsViewModel()

        #expect(model.kind == .automatic)
        #expect(model.dayCount == 14)
        #expect(model.days == Array(CafeData.harbourSales.prefix(14)))
        #expect(model.amountText(locale: locale) == nil)
        #expect(MarkDimensionsViewModel.Kind.automatic.amountRange == nil)
    }

    @Test("Given the day count, when it changes, then the chart gets the first days of the data, one per bar")
    func dayCountTakesFirstDays() {
        let model = MarkDimensionsViewModel()

        model.dayCountValue = 5
        #expect(model.days == Array(CafeData.harbourSales.prefix(5)))
        #expect(model.dayCountText(locale: locale) == "5 days")

        model.dayCountValue = 28
        #expect(model.days == CafeData.harbourSales)
    }

    @Test("Given a day count outside the range, when it is set, then it is held at the nearest end")
    func dayCountIsClamped() {
        let model = MarkDimensionsViewModel()

        model.dayCount = 0
        #expect(model.dayCount == MarkDimensionsViewModel.dayCountRange.lowerBound)

        model.dayCount = 400
        #expect(model.dayCount == MarkDimensionsViewModel.dayCountRange.upperBound)
    }

    @Test("Given each case, when the slider moves, then only that case's amount changes")
    func amountBelongsToItsCase() {
        let model = MarkDimensionsViewModel()

        model.kind = .ratio
        model.amount = 0.9
        model.kind = .inset
        model.amount = 1.5
        model.kind = .fixed
        model.amount = 20

        #expect(model.ratio == 0.9)
        #expect(model.inset == 1.5)
        #expect(model.fixed == 20)

        model.kind = .automatic
        model.amount = 3
        #expect(model.amount == 0)
        #expect(model.ratio == 0.9)
        #expect(model.inset == 1.5)
        #expect(model.fixed == 20)
    }

    @Test("Given each case, when its amount is written, then it carries the unit the case measures in")
    func amountTextHasUnits() {
        let model = MarkDimensionsViewModel()

        model.kind = .ratio
        #expect(model.amountText(locale: locale) == "0.6")
        model.kind = .inset
        #expect(model.amountText(locale: locale) == "2 points")
        model.amount = 1
        #expect(model.amountText(locale: locale) == "1 point")
        model.amount = 0.5
        #expect(model.amountText(locale: locale) == "0.5 points")
        model.kind = .fixed
        #expect(model.amountText(locale: locale) == "8 points")
    }

    @Test("Given each case's defaults, when its range is read, then the default amount lies inside it")
    func defaultsLieInRange() throws {
        let model = MarkDimensionsViewModel()

        for kind in MarkDimensionsViewModel.Kind.allCases where kind != .automatic {
            model.kind = kind
            #expect(try #require(kind.amountRange).contains(model.amount))
        }
    }

    // MARK: Snippets

    @Test("Given each case, when its snippets are listed, then they are the bar and that case's width")
    func snippetsFollowTheCase() {
        let model = MarkDimensionsViewModel()

        for kind in MarkDimensionsViewModel.Kind.allCases {
            model.kind = kind
            #expect(model.snippets.map(\.name) == ["mark-dimensions-chart", "mark-dimensions-\(kind.rawValue)"])
        }
    }

    @Test("Given every case, when its snippets are looked up, then each is in the bundle and listed for registration")
    func everySnippetExists() throws {
        let store = try SnippetStore()
        let model = MarkDimensionsViewModel()
        var shown = Set<String>()

        for kind in MarkDimensionsViewModel.Kind.allCases {
            model.kind = kind
            shown.formUnion(model.snippets.map(\.name))
        }

        #expect(shown == Set(MarkDimensionsViewModel.allSnippets.map(\.name)))
        for name in shown {
            #expect(store[name] != nil, "\(name) is missing from Snippets.json")
        }
    }

    @Test("Given the width snippets, when they are read, then each names its own case and the bar takes a width")
    func snippetsShowTheirCase() throws {
        let store = try SnippetStore()

        #expect(try #require(store["mark-dimensions-chart"]).code.contains("width: width"))
        #expect(try #require(store["mark-dimensions-automatic"]).code.contains(".automatic"))
        #expect(try #require(store["mark-dimensions-ratio"]).code.contains(".ratio(ratio)"))
        #expect(try #require(store["mark-dimensions-inset"]).code.contains(".inset(inset)"))
        #expect(try #require(store["mark-dimensions-fixed"]).code.contains(".fixed(fixed)"))
    }

    // MARK: Announcements

    @Test("Given every control, when it changes the chart, then the announcement changes with it")
    func announcementFollowsEveryControl() {
        let model = MarkDimensionsViewModel()
        var announcements = Set<String>()
        var settings = 0

        for kind in MarkDimensionsViewModel.Kind.allCases {
            model.kind = kind
            for dayCount in [3, 14, 28] {
                model.dayCount = dayCount
                for amount in kind == .automatic ? [0.0] : [1.0, 0.5] {
                    model.amount = amount
                    announcements.insert(model.announcement(locale: locale))
                    settings += 1
                }
            }
        }

        #expect(announcements.count == settings)
    }

    @Test("Given a ratio of 0.6 on fourteen days, when the announcement is written, then it gives the count and the width")
    func announcementWording() {
        let model = MarkDimensionsViewModel()
        model.kind = .ratio

        #expect(model.announcement(locale: locale) == "14 days shown. Bar width: ratio, 0.6 of each day's step.")
    }

    // MARK: Derived text

    @Test("Given days of sales, when the headline is written, then it gives the tallest bar's cups and its day")
    func headlineNamesTheBusiestDay() {
        let summary = MarkDimensionsSummary(days: sales([120, 181, 140]), locale: locale)

        #expect(summary.headline == "Most cups in 3 days: 181, on Monday, March 2.")
    }

    @Test("Given every day count the slider allows, when the headline is written, then its figure is the tallest bar drawn")
    func headlineFollowsTheDayCount() throws {
        let model = MarkDimensionsViewModel()

        for dayCount in MarkDimensionsViewModel.dayCountRange {
            model.dayCount = dayCount
            let most = try #require(model.days.map(\.cups).max())
            let headline = MarkDimensionsSummary(days: model.days, locale: locale).headline

            #expect(headline.hasPrefix("Most cups in \(dayCount) days: \(most),"))
        }
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        let summary = MarkDimensionsSummary(days: sales([90, 40, 90]), locale: locale)

        #expect(summary.busiestDays.count == 2)
        #expect(summary.headline == "Most cups in 3 days: 90, on Sunday, March 1 and Tuesday, March 3.")
    }

    @Test("Given one day, when the headline is written, then it states that day's cups without a comparison")
    func oneDayHeadline() {
        #expect(MarkDimensionsSummary(days: sales([1]), locale: locale).headline == "1 cup on Sunday, March 1.")
    }

    @Test("Given no days or only zeros, when the words are written, then they say nothing sold")
    func emptyAndZeroSaySo() {
        for days in [[], sales([0, 0, 0])] {
            let summary = MarkDimensionsSummary(days: days, locale: locale)

            #expect(summary.total == 0)
            #expect(summary.busiestDays.isEmpty)
            #expect(summary.headline == "No cups sold yet.")
            #expect(summary.audioGraphSummary == "No cups sold yet.")
        }
    }

    @Test("Given counts of cups and days, when they are written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(CafeWording.cups(1, locale: locale) == "1 cup")
        #expect(CafeWording.cups(57, locale: locale) == "57 cups")
        #expect(CafeWording.days(1, locale: locale) == "1 day")
        #expect(CafeWording.days(28, locale: locale) == "28 days")
        #expect(CafeWording.points(1, locale: locale) == "1 point")
        #expect(CafeWording.points(24, locale: locale) == "24 points")
        #expect(CafeWording.points(0.5, locale: locale) == "0.5 points")
    }

    @Test("Given a German locale, when the chart's words are written, then numbers and dates are written its way and the list is joined in English")
    func wordsTakeTheLocale() {
        let german = Locale(identifier: "de_DE")
        let summary = MarkDimensionsSummary(days: sales([1200, 40, 1200]), locale: german)
        let model = MarkDimensionsViewModel()
        model.kind = .inset
        model.inset = 0.5

        #expect(summary.headline.hasPrefix("Most cups in 3 days: 1.200, on Sonntag"))
        #expect(summary.headline.contains(" and Dienstag"))
        #expect(!summary.headline.contains(" und "))
        #expect(model.amountText(locale: german) == "0,5 points")
    }

    @Test("Given a day counted in UTC, when it is written out, then it names that day whatever the device's time zone")
    func dayLabelUsesTheDataTimeZone() {
        let summary = MarkDimensionsSummary(days: [], locale: locale)

        #expect(summary.dayLabel(CafeData.day(0)) == "Sunday, March 1")
        #expect(summary.dayLabel(CafeData.day(27)) == "Saturday, March 28")
    }

    @Test("Given more bars or larger text, when the axis labels are spaced, then there are fewer of them")
    func labelsThinOut() {
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 7, isAccessibilitySize: false) == 1)
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 14, isAccessibilitySize: false) == 2)
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 28, isAccessibilitySize: false) == 7)
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 3, isAccessibilitySize: true) == 1)
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 7, isAccessibilitySize: true) == 2)
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 14, isAccessibilitySize: true) == 7)
        #expect(MarkDimensionsSummary.daysPerLabel(dayCount: 28, isAccessibilitySize: true) == 14)
    }

    // MARK: The chart descriptor

    @Test("Given days of sales, when the Audio Graph summary is written, then it gives the span, first, last and highest in actual values")
    func summaryGivesActualValues() {
        #expect(
            MarkDimensionsSummary(days: sales([120, 181, 140]), locale: locale).audioGraphSummary
                == "3 days, Sunday, March 1 to Tuesday, March 3. First day 120 cups, last day 140 cups. Highest 181 cups, on Monday, March 2."
        )
    }

    @Test("Given days of sales, when the chart descriptor is made, then it has a title, the summary and one named series of separate bars")
    func descriptorDescribesTheChart() throws {
        let days = sales([120, 181, 140])
        let descriptor = MarkDimensionsChartDescriptor(days: days, locale: locale).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold a day at the Harbour café")
        #expect(descriptor.summary == MarkDimensionsSummary(days: days, locale: locale).audioGraphSummary)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Harbour")
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == days.count)
    }

    @Test("Given days of sales, when the descriptor's axes are read, then days are written out in order and values are said in cups from zero")
    func descriptorAxes() throws {
        let descriptor = MarkDimensionsChartDescriptor(days: sales([120, 181, 140]), locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder == ["Sunday, March 1", "Monday, March 2", "Tuesday, March 3"])
        #expect(yAxis.title == "Cups")
        // The busiest day is 181; the axis is drawn to 200, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
    }

    @Test("Given the day count changes, when the descriptor is made, then it has a point for every bar drawn")
    func descriptorFollowsTheDayCount() throws {
        let model = MarkDimensionsViewModel()
        model.dayCount = 9
        let descriptor = MarkDimensionsChartDescriptor(days: model.days, locale: locale).makeChartDescriptor()

        #expect(try #require(descriptor.series.first).dataPoints.count == 9)
    }

    @Test("Given a fixed width, when its note is read, then it says the bars at the ends are cut off at the plot's edge")
    func fixedNoteSaysTheEndsAreCutOff() {
        #expect(MarkDimensionsViewModel.Kind.fixed.note.hasSuffix(
            "then the bars run into each other, and the first and last are cut off at the plot's edge."
        ))
    }

    @Test("Given the busiest day, when its label over the bar is written, then it names the day and its cups, as the axis may not")
    func calloutNamesTheDay() throws {
        let summary = MarkDimensionsSummary(days: Array(CafeData.harbourSales.prefix(14)), locale: Locale(identifier: "en_US"))
        let busiest = try #require(summary.busiestDays.first)
        #expect(summary.calloutText(for: busiest) == "Mar 14: 240")
        #expect(summary.headline == "Most cups in 14 days: 240, on Saturday, March 14.")
    }
}
