import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct PositioningMarksTests {
    private let english = Locale(identifier: "en_GB")

    private func store(_ name: String, _ cups: [Int]) -> StoreSales {
        StoreSales(store: name, days: cups.enumerated().map { DailySales(day: CafeData.day(15 + $0.offset), cups: $0.element) })
    }

    // MARK: View model

    @Test("Given a new screen, when it opens, then the lollipops are nudged 6 points each way and stems stop 5 points short")
    func defaults() {
        let model = PositioningMarksViewModel()
        #expect(model.nudge == 6)
        #expect(model.stemInset == 5)
        #expect(model.nudgeForm == .xAndY)
    }

    @Test("Given a nudge, when each café's shift is read, then Harbour moves before the day and Station after it by the same distance")
    func shiftsAreOpposite() {
        let model = PositioningMarksViewModel()
        model.nudge = 9
        #expect(model.shift(for: CafeWording.harbour) == -9)
        #expect(model.shift(for: CafeWording.station) == 9)
        model.nudge = 0
        #expect(model.shift(for: CafeWording.harbour) == 0)
        #expect(model.shift(for: CafeWording.station) == 0)
    }

    @Test("Given each way of writing the nudge, when the snippets are read, then the head's snippet follows it and the stem's is always shown")
    func snippetsFollowTheForm() {
        let model = PositioningMarksViewModel()
        #expect(model.snippets.map(\.name) == ["positioning-marks-nudge-xy", "positioning-marks-stem"])
        model.nudgeForm = .size
        #expect(model.snippets.map(\.name) == ["positioning-marks-nudge-size", "positioning-marks-stem"])
    }

    @Test("Given the app's snippets, when every name the screen can show is looked up, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let model = PositioningMarksViewModel()
        for form in PositioningMarksNudgeForm.allCases {
            model.nudgeForm = form
            for reference in model.snippets {
                #expect(store[reference.name] != nil, "missing \(reference.name)")
            }
        }
    }

    @Test("Given slider settings of one and of many, when their values are written, then the points agree in number")
    func sliderTextAgreesInNumber() {
        let model = PositioningMarksViewModel()
        model.nudge = 1
        model.stemInset = 1
        #expect(model.nudgeText(locale: english) == "1 point each way")
        #expect(model.stemInsetText(locale: english) == "1 point")
        model.nudge = 12
        model.stemInset = 0
        #expect(model.nudgeText(locale: english) == "12 points each way")
        #expect(model.stemInsetText(locale: english) == "0 points")
    }

    @Test("Given the slider ranges, when their ends are read, then the nudge reaches 12 points and the inset 10")
    func ranges() {
        #expect(PositioningMarksViewModel.nudgeRange == 0 ... 12)
        #expect(PositioningMarksViewModel.stemInsetRange == 0 ... 10)
        #expect(PositioningMarksViewModel.nudgeRange.contains(PositioningMarksViewModel.defaultNudge))
        #expect(PositioningMarksViewModel.stemInsetRange.contains(PositioningMarksViewModel.defaultStemInset))
    }

    // MARK: Data and words

    @Test("Given the sample week, when it is read, then both cafés have the seven days from Monday 16 to Sunday 22 March")
    func sampleWeek() {
        let week = PositioningMarksData.week
        #expect(week.map(\.store) == [CafeWording.harbour, CafeWording.station])
        #expect(week.allSatisfy { $0.days.count == 7 })
        let summary = PositioningMarksSummary(stores: week, locale: english)
        #expect(summary.dayName(summary.days[0]) == "Monday 16 March")
        #expect(summary.dayName(summary.days[6]) == "Sunday 22 March")
    }

    @Test("Given the sample week, when the entries are read, then they go day by day with Harbour before Station")
    func entriesGoDayByDay() {
        let summary = PositioningMarksSummary(stores: PositioningMarksData.week, locale: english)
        #expect(summary.entries.count == 14)
        #expect(summary.entries.prefix(2).map(\.store) == [CafeWording.harbour, CafeWording.station])
        #expect(summary.entries[0].day == summary.entries[1].day)
        #expect(summary.entries.map(\.cups).prefix(4) == [201, 211, 194, 202])
    }

    @Test("Given the sample week, when the headline is written, then it counts the days each café sold more")
    func sampleHeadline() {
        let summary = PositioningMarksSummary(stores: PositioningMarksData.week, locale: english)
        #expect(summary.headline == "Station sold more on 5 of the 7 days, Harbour on 2.")
    }

    @Test("Given one café ahead every day, when the headline is written, then it says all the days")
    func headlineAllDays() {
        let summary = PositioningMarksSummary(stores: [store("Harbour", [5, 6]), store("Station", [1, 2])], locale: english)
        #expect(summary.headline == "Harbour sold more on all 2 days.")
    }

    @Test("Given level days, when the headline is written, then it counts them and still agrees with the chart")
    func headlineWithTies() {
        let summary = PositioningMarksSummary(stores: [store("Harbour", [5, 6, 3]), store("Station", [5, 2, 3])], locale: english)
        #expect(summary.headline == "Harbour sold more on 1 of the 3 days, Station on 0, level on 2.")
    }

    @Test("Given one compared day, when the headline is written, then it speaks of the one day, not all of one")
    func headlineOneDay() {
        let summary = PositioningMarksSummary(stores: [store("Harbour", [5]), store("Station", [9])], locale: english)
        #expect(summary.headline == "Station sold more on the one day shown.")
        let level = PositioningMarksSummary(stores: [store("Harbour", [5]), store("Station", [5])], locale: english)
        #expect(level.headline == "Both cafés sold the same on the one day shown.")
    }

    @Test("Given each café ahead on as many days, when the headline is written, then it names neither as the leader")
    func headlineEqualCounts() {
        let even = PositioningMarksSummary(
            stores: [store("Harbour", [5, 1, 6, 1]), store("Station", [1, 5, 1, 5])], locale: english
        )
        #expect(even.headline == "Each sold more on 2 of the 4 days.")
        let withLevel = PositioningMarksSummary(
            stores: [store("Harbour", [5, 1, 3]), store("Station", [1, 5, 3])], locale: english
        )
        #expect(withLevel.headline == "Each sold more on 1 of the 3 days, level on 1.")
        let allLevel = PositioningMarksSummary(stores: [store("Harbour", [2, 3]), store("Station", [2, 3])], locale: english)
        #expect(allLevel.headline == "Both cafés sold the same on all 2 days.")
    }

    @Test("Given the sample week in several locales, when the caption is written, then its dates come from the data in that locale")
    func captionDatesFromData() {
        let british = PositioningMarksSummary(stores: PositioningMarksData.week, locale: english)
        #expect(british.caption == "Cups sold each day at both cafés, 16\u{2009}–\u{2009}22 March")
        let german = PositioningMarksSummary(stores: PositioningMarksData.week, locale: Locale(identifier: "de_DE"))
        #expect(german.dateRange == "16.–22. März")
        let oneDay = PositioningMarksSummary(stores: [store("Harbour", [5]), store("Station", [9])], locale: english)
        #expect(oneDay.dateRange == "16 March")
        let empty = PositioningMarksSummary(stores: [], locale: english)
        #expect(empty.caption == "Cups sold each day at both cafés")
    }

    @Test("Given a day with no cups, when the stem's inset is read, then that day gets none and the others the slider's")
    func noInsetOnAZeroDay() {
        let model = PositioningMarksViewModel()
        model.stemInset = 5
        let zero = PositioningMarksEntry(store: CafeWording.harbour, day: CafeData.day(15), cups: 0)
        let some = PositioningMarksEntry(store: CafeWording.harbour, day: CafeData.day(15), cups: 1)
        #expect(model.stemInset(for: zero) == 0)
        #expect(model.stemInset(for: some) == 5)
    }

    @Test("Given no data or only zeros, when the summary is read, then the chart is empty and the headline says nothing was sold")
    func emptyAndZeros() {
        let empty = PositioningMarksSummary(stores: [], locale: english)
        #expect(empty.isEmpty)
        #expect(empty.headline == "No cups sold at either café this week.")
        let zeros = PositioningMarksSummary(stores: [store("Harbour", [0, 0]), store("Station", [0, 0])], locale: english)
        #expect(zeros.isEmpty)
        #expect(zeros.headline == "No cups sold at either café this week.")
    }

    @Test("Given a German locale, when the headline is written, then the numbers take that locale and the sentence stays English")
    func headlineTakesLocale() {
        let summary = PositioningMarksSummary(
            stores: [store("Harbour", Array(repeating: 2, count: 1200)), store("Station", Array(repeating: 1, count: 1200))],
            locale: Locale(identifier: "de_DE")
        )
        #expect(summary.headline == "Harbour sold more on all 1.200 days.")
    }

    // MARK: Audio Graph

    @Test("Given a nudge, when the Audio Graph summary is written, then it gives the values and says the marks are drawn apart without changing them")
    func summaryWithNudge() {
        let summary = PositioningMarksSummary(stores: PositioningMarksData.week, locale: english)
        let text = summary.audioGraphSummary(nudge: 6)
        #expect(text.hasPrefix("7 days. Station sold more on 5 of the 7 days, Harbour on 2."))
        #expect(text.contains("Harbour: lowest 194 cups, highest 261 cups."))
        #expect(text.contains("Station: lowest 176 cups, highest 216 cups."))
        #expect(text.contains("drawn 12 points apart, Harbour first"))
        #expect(text.contains("does not change their values"))
    }

    @Test("Given no nudge, when the Audio Graph summary is written, then it says the marks are drawn at one place and can cover each other")
    func summaryWithoutNudge() {
        let summary = PositioningMarksSummary(stores: PositioningMarksData.week, locale: english)
        #expect(summary.audioGraphSummary(nudge: 0).hasSuffix(
            "Each day's two marks are drawn at the same place, so where the values are close they cover each other."
        ))
    }

    @Test("Given the sample week, when the descriptor is made, then it has two named series over seven written-out days")
    func descriptor() throws {
        let made = PositioningMarksChartDescriptor(stores: PositioningMarksData.week, nudge: 6, locale: english)
            .makeChartDescriptor()
        #expect(made.title == "Cups sold each day at the Harbour and Station cafés, 16\u{2009}–\u{2009}22 March")
        #expect(made.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
        #expect(made.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 7 })
        let xAxis = try #require(made.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "Monday 16 March")
        #expect(xAxis.categoryOrder.count == 7)
        let yAxis = try #require(made.yAxis)
        // The busiest day is 261; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(201) == "201 cups")
        #expect(made.summary?.contains("12 points apart") == true)
    }
}
