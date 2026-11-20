import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct BinningTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the forty waits, when eight bins are asked for, then six are drawn and every order is counted")
    func waitsBinnedAsAsked() {
        let model = BinningViewModel()

        #expect(model.desiredBinCount == 8)
        #expect(model.drawnBinCount == 6)
        #expect(model.waitBins.map(\.orders) == [9, 9, 11, 6, 3, 2])
        let counted: Int = model.waitBins.map(\.orders).reduce(0, +)
        #expect(counted == 40)
        #expect(model.binCountText(locale: english) == "8 asked for, 6 drawn")
    }

    @Test("Given the waits, when thirteen bins are asked for, then fourteen are drawn, an empty one among them")
    func moreBinsThanAsked() {
        let model = BinningViewModel()
        model.desiredBinCount = 13

        #expect(model.drawnBinCount == 14)
        #expect(model.waitBins.contains { $0.orders == 0 })
        #expect(model.waitBins.first?.range.lowerBound == 40)
    }

    @Test("Given the ten weeks of days, when they are binned by week in UTC, then ten Sunday-to-Saturday totals come back")
    func weeksBinned() {
        let model = BinningViewModel()
        model.kind = .weeks

        let bins = model.weekBins
        #expect(bins.count == 10)
        #expect(model.drawnBinCount == 10)
        #expect(bins.first?.range.lowerBound == CafeData.firstDay)
        let expected = [1211, 1358, 1505, 1652, 1799, 1946, 2093, 2240, 2387, 2534]
        #expect(bins.map(\.cups) == expected)
        let binned: Int = bins.map(\.cups).reduce(0, +)
        let daily: Int = CafeData.tenWeeks.map(\.cups).reduce(0, +)
        #expect(binned == daily)
    }

    @Test("Given the default histogram, when the headline is written, then it names the tallest bin and its count")
    func waitsHeadline() {
        let model = BinningViewModel()

        #expect(model.summary(locale: english).headline == "The most common wait was 150 to 200 seconds: 11 orders.")
    }

    @Test("Given two bins tied for tallest, when the headline is written, then both are named")
    func tiedHeadline() {
        let model = BinningViewModel()
        model.desiredBinCount = 9

        #expect(model.summary(locale: english).headline
            == "The most common waits were 75 to 100 seconds and 150 to 175 seconds: 6 orders each.")
    }

    @Test("Given weekly totals, when the headline is written, then it names the busiest week in UTC")
    func weeksHeadline() {
        let model = BinningViewModel()
        model.kind = .weeks

        #expect(model.summary(locale: english).headline == "The busiest week, starting Sunday, May 3, sold 2,534 cups.")
    }

    @Test("Given the mistake, when the headline and element values are written, then they describe dashes, not bars")
    func mistakeText() throws {
        let model = BinningViewModel()
        model.isShowingMistake = true
        let summary = model.summary(locale: english)

        #expect(summary.headline
            == "Drawn with xStart and xEnd, each bin is a dash at its count: the highest, 150 to 200 seconds, sits at 11 orders.")
        let bin = try #require(summary.waitBins.first)
        #expect(summary.waitRangeText(bin) == "50 to 100 seconds")
        #expect(summary.waitValue(bin) == "A dash at 9 orders, no bar")

        model.kind = .weeks
        let weeks = model.summary(locale: english)
        let week = try #require(weeks.weekBins.first)
        #expect(weeks.weekLabel(week) == "Week starting Sunday, March 1")
        #expect(weeks.weekValue(week) == "A dash at 1,211 cups, no bar")
        #expect(weeks.headline.hasPrefix("Drawn with xStart and xEnd, each week is a dash at its total"))
    }

    @Test("Given no data or only zeros, when the summary is read, then there is nothing to draw and the headline says so")
    func emptyAndZeros() {
        let empty = BinningViewModel(waits: [], days: [])
        #expect(empty.waitBins.isEmpty)
        #expect(!empty.summary(locale: english).hasData)
        #expect(empty.summary(locale: english).headline == "No orders to bin yet.")
        empty.kind = .weeks
        #expect(empty.summary(locale: english).headline == "No cups sold in these weeks.")

        let zeros = BinningViewModel(days: CafeData.tenWeeks.map { DailySales(day: $0.day, cups: 0) })
        zeros.kind = .weeks
        #expect(zeros.weekBins.count == 10)
        #expect(!zeros.summary(locale: english).hasData)
        #expect(zeros.summary(locale: english).headline == "No cups sold in these weeks.")
    }

    @Test("Given one order, when it is binned and counted, then it gets a bin of its own and the words agree in number")
    func singularCounts() {
        let model = BinningViewModel(waits: [120])
        let summary = model.summary(locale: english)

        #expect(model.waitBins.count == 1)
        #expect(summary.headline == "The most common wait was 120 to 121 seconds: 1 order.")
        #expect(CafeWording.bins(1, locale: english) == "1 bin")
    }

    @Test("Given each width and the mistake, when the footnote is read, then only the default width and the mistake have one")
    func barWidthFootnote() {
        let model = BinningViewModel()
        #expect(model.barWidth == .touching)
        #expect(model.barWidthFootnote == nil)

        model.barWidth = .standard
        #expect(model.barWidthFootnote
            == "At the default width the bars are narrower than their bins and leave gaps the data does not have.")
        model.kind = .weeks
        #expect(model.barWidthFootnote?.hasPrefix("At the default width") == true)

        model.isShowingMistake = true
        #expect(model.barWidthFootnote == "A dash has no width to set: the mistake draws no bars.")
    }

    @Test("Given the wait domains the stepper can make, when the large-text labels are chosen, then there are two, round and clear of the last quarter")
    func sparseAxisLabels() {
        #expect(BinningAxis.sparseLabels(from: 50, to: 350) == [100, 200])
        #expect(BinningAxis.sparseLabels(from: 0, to: 400) == [0, 200])
        let model = BinningViewModel()
        for count in BinningViewModel.binCountRange {
            model.desiredBinCount = count
            let bins = model.waitBins
            let lower = bins.first?.range.lowerBound ?? 0
            let upper = bins.last?.range.upperBound ?? 0
            let labels = BinningAxis.sparseLabels(from: lower, to: upper)
            #expect(labels.count == 2, "\(count) bins asked for: \(labels)")
            #expect(labels.allSatisfy { $0 >= lower && $0 <= upper - (upper - lower) / 4 })
        }
        #expect(BinningAxis.sparseLabels(from: 120, to: 120) == [120])
    }

    @Test("Given a German locale, when the weekly headline is written, then its numbers follow that locale")
    func localeReachesHeadline() {
        let model = BinningViewModel()
        model.kind = .weeks

        #expect(model.summary(locale: Locale(identifier: "de_DE")).headline.contains("2.534"))
    }

    @Test("Given each change, when it is announced, then the announcement says what changed and then the headline")
    func announcements() {
        let model = BinningViewModel()
        model.kind = .weeks
        let headline = model.summary(locale: english).headline
        #expect(model.announcement(after: .kind, locale: english) == "Showing weekly totals of cups. \(headline)")

        model.isShowingMistake = true
        let mistake = model.announcement(after: .mistake, locale: english)
        #expect(mistake.hasPrefix("Showing the mistake"))
        #expect(mistake.hasSuffix(model.summary(locale: english).headline))

        model.kind = .waits
        model.isShowingMistake = false
        #expect(model.binCountSpokenValue(locale: english)
            == "8 bins asked for, 6 drawn. The most common wait was 150 to 200 seconds: 11 orders.")
    }

    @Test("Given each state, when the snippets are chosen, then they follow the binning and the mistake")
    func snippetNames() {
        let model = BinningViewModel()
        #expect(model.snippets.map(\.name) == ["binning-number-bins", "binning-histogram", "binning-bar-width"])

        model.isShowingMistake = true
        #expect(model.snippets.map(\.name) == ["binning-number-bins", "binning-histogram-mistake"])

        model.kind = .weeks
        #expect(model.snippets.map(\.name) == ["binning-date-bins", "binning-weekly-mistake"])

        model.isShowingMistake = false
        #expect(model.snippets.map(\.name) == ["binning-date-bins", "binning-weekly-bars", "binning-bar-width"])
    }

    @Test("Given the built app, when every snippet a state can show is looked up, then each one exists")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let model = BinningViewModel()
        var names: Set<String> = []
        for kind in BinningKind.allCases {
            for mistake in [false, true] {
                model.kind = kind
                model.isShowingMistake = mistake
                names.formUnion(model.snippets.map(\.name))
            }
        }

        #expect(names.count == 7)
        for name in names {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    @Test("Given the binning snippets, when they are read, then each clamps the range's top value into the last bin")
    func snippetsClampTopValue() throws {
        let store = try SnippetStore(bundle: .main)

        for name in ["binning-number-bins", "binning-date-bins"] {
            let snippet = try #require(store[name])
            #expect(snippet.code.contains("min(bins.index(for:"), "\(name) does not clamp")
            #expect(snippet.code.contains("bins.count - 1"), "\(name) does not clamp")
        }
    }

    @Test("Given the mistake toggled, when the chart identity is read, then it changes, so VoiceOver rereads the labels")
    func identityFollowsMistake() {
        let model = BinningViewModel()
        let before = model.chartIdentity
        model.isShowingMistake = true

        #expect(model.chartIdentity != before)
    }

    @Test("Given the histogram, when its descriptor is made, then it has a title, the bins as categories and counts in words")
    func waitsDescriptor() throws {
        let model = BinningViewModel()
        let descriptor = BinningChartDescriptor(summary: model.summary(locale: english)).makeChartDescriptor()

        #expect(descriptor.title == "Orders by wait, in bins of seconds")
        #expect(descriptor.summary
            == "40 orders in 6 bins from 50 to 350 seconds. Most: 150 to 200 seconds, 11 orders. Fewest: 300 to 350 seconds, 2 orders.")
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.categoryOrder.first == "50 to 100 seconds")
        #expect(xAxis?.categoryOrder.count == 6)
        let yAxis = try #require(descriptor.yAxis)
        // The tallest bin holds 11 orders; the axis is drawn to 15, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 15)
        #expect(yAxis.valueDescriptionProvider(1) == "1 order")
        #expect(descriptor.series.first?.dataPoints.count == 6)
        #expect(descriptor.series.first?.isContinuous == false)
    }

    @Test("Given weekly totals shown as the mistake, when the descriptor is made, then it says the weeks are dashes")
    func weeksDescriptor() throws {
        let model = BinningViewModel()
        model.kind = .weeks
        model.isShowingMistake = true
        let descriptor = BinningChartDescriptor(summary: model.summary(locale: english)).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold per week at the Harbour café, each drawn as a dash")
        #expect(descriptor.summary?.hasPrefix("Drawn as a dash at each value, with no bars. 10 weeks, 18,725 cups in total.") == true)
        let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
        #expect(xAxis?.categoryOrder.last == "Week starting Sunday, May 3")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.valueDescriptionProvider(1651) == "1,651 cups")
        #expect(descriptor.series.first?.dataPoints.count == 10)
    }

    @Test("Given the sample orders, when the most common bin is labelled, then the label gives both its edges, as the axis does not")
    func waitCalloutGivesTheEdges() throws {
        let summary = BinningViewModel().summary(locale: english)
        let bin = try #require(summary.tallestWaitBins.first)
        #expect(summary.waitCallout(bin) == "150–200 s")
    }

    @Test("Given the weekly totals, when the busiest week is labelled, then the label names its first day")
    func weekCalloutNamesTheWeek() throws {
        let model = BinningViewModel()
        model.kind = .weeks
        let summary = model.summary(locale: english)
        let week = try #require(summary.tallestWeekBins.first)
        #expect(summary.weekCallout(week).hasPrefix("From "))
        #expect(summary.headline.contains(summary.weekStartText(week)))
    }

    @Test(
        "Given every bin count the stepper can ask for, when the waits are binned, then every order is counted once",
        arguments: 2 ... 24
    )
    func everyOrderCountedAtEverySetting(desired: Int) {
        let model = BinningViewModel()
        #expect(BinningViewModel.binCountRange == 2 ... 24)
        model.desiredBinCount = desired

        let counted: Int = model.waitBins.map(\.orders).reduce(0, +)
        #expect(counted == model.waits.count)
    }

    @Test("Given waits whose longest sits on the last boundary, when they are binned, then it is counted in the last bin")
    func topValueCountedInLastBin() throws {
        let waits = Array(0 ... 100)
        let bins = BinningBins.waitBins(of: waits, desiredCount: 8)

        let counted: Int = bins.map(\.orders).reduce(0, +)
        #expect(counted == waits.count)
        let last = try #require(bins.last)
        #expect(last.range.upperBound == 100)
        #expect(last.orders == 11)
    }

    @Test("Given the last day on a week's boundary, when the days are binned by week, then every day's cups are counted")
    func lastDayOnWeekBoundaryCounted() {
        let calendar = CafeData.calendar
        for length in 2 ... 15 {
            let days = Array(CafeData.tenWeeks.prefix(length))
            let binned: Int = BinningBins.weekBins(of: days, calendar: calendar).map(\.cups).reduce(0, +)
            let daily: Int = days.map(\.cups).reduce(0, +)
            #expect(binned == daily, "first \(length) days")
        }
    }
}
