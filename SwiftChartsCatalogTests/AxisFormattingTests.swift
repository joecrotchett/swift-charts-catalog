import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AxisFormattingTests {
    private let english = Locale(identifier: "en_US")
    private let twoWeeks = Array(CafeData.harbourSales.prefix(14))

    // MARK: Stages

    @Test("Given a new screen, when it appears, then it starts at the default axis, stage 1 of 5")
    func startsAtDefault() {
        let viewModel = AxisFormattingViewModel()

        #expect(viewModel.stage == .automatic)
        #expect(viewModel.stageNumber == 1)
        #expect(viewModel.stageCount == 5)
        #expect(viewModel.stageDescription == "Stage 1 of 5: Default axis")
    }

    @Test("Given the stepper, when it sets each number, then the stage follows in order to the finished axis")
    func stepsThroughStages() {
        let viewModel = AxisFormattingViewModel()
        var seen: [AxisFormattingStage] = []
        for number in 1 ... viewModel.stageCount {
            viewModel.stageNumber = number
            seen.append(viewModel.stage)
        }

        #expect(seen == [.automatic, .formatStyle, .byValue, .twoLines, .centredDays])
        #expect(viewModel.stageDescription == "Stage 5 of 5: Centred day labels")
    }

    @Test("Given a stage, when a number outside the stages is set, then the stage stays where it was")
    func ignoresOutOfRange() {
        let viewModel = AxisFormattingViewModel()
        viewModel.stage = .twoLines
        viewModel.stageNumber = 9

        #expect(viewModel.stage == .twoLines)
    }

    @Test("Given each stage, when the snippets are listed, then it shows the one snippet for its axis")
    func snippetsFollowStage() {
        let viewModel = AxisFormattingViewModel()
        var names: [String] = []
        for stage in AxisFormattingStage.allCases {
            viewModel.stage = stage
            names += viewModel.snippets.map(\.name)
        }

        #expect(names == [
            "axis-formatting-default", "axis-formatting-format-style", "axis-formatting-by-value",
            "axis-formatting-two-lines", "axis-formatting-centred-days",
        ])
    }

    @Test("Given the app's bundle, when the snippets are loaded, then every stage's snippet exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for stage in AxisFormattingStage.allCases {
            #expect(store[stage.snippet.name] != nil, "Missing \(stage.snippet.name)")
        }
    }

    // MARK: Data and dates

    @Test("Given the screen's data, when it is read, then it is two weeks from Sunday 1 March")
    func dataIsTwoWeeks() {
        let viewModel = AxisFormattingViewModel()

        #expect(viewModel.days.count == 14)
        #expect(viewModel.days.first?.day == CafeData.firstDay)
        #expect(CafeData.calendar.component(.weekday, from: CafeData.firstDay) == 1)
    }

    @Test("Given a day stored as midnight UTC, when it is written for a label, then it names that day whatever the device's time zone")
    func datesWrittenInDataTimeZone() {
        let text = AxisFormattingDateText(locale: english)
        let date = CafeData.firstDay

        #expect(text(date, text.monthDay) == "Mar 1")
        #expect(text(date, text.dayNumber) == "1")
        #expect(text(date, text.monthName) == "Mar")
        #expect(text(date, text.weekdayInitial) == "S")
        #expect(text(date, text.spoken) == "Sunday, March 1")
    }

    @Test("Given a German locale, when a label is written, then it takes that locale")
    func labelsTakeLocale() {
        let text = AxisFormattingDateText(locale: Locale(identifier: "de_DE"))

        #expect(text(CafeData.firstDay, text.weekdayInitial) == "S")
        #expect(text(CafeData.firstDay, text.spoken) == "Sonntag, 1. März")
    }

    // MARK: Headline and summary

    @Test("Given the two weeks, when the headline is written, then it names the busiest day and its cups")
    func headlineNamesBusiestDay() {
        #expect(AxisFormattingSummary(days: twoWeeks, locale: english).headline
            == "The busiest day was Saturday, March 14, with 240 cups.")
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [
            DailySales(day: CafeData.day(0), cups: 90), DailySales(day: CafeData.day(1), cups: 40),
            DailySales(day: CafeData.day(2), cups: 90),
        ]

        #expect(AxisFormattingSummary(days: tied, locale: english).headline
            == "The busiest days were Sunday, March 1 and Tuesday, March 3, with 90 cups each.")
    }

    @Test("Given one cup on the busiest day, when the words are written, then the counts agree in number")
    func cupsAgreeInNumber() {
        let summary = AxisFormattingSummary(days: [DailySales(day: CafeData.firstDay, cups: 1)], locale: english)

        #expect(summary.headline == "The busiest day was Sunday, March 1, with 1 cup.")
        #expect(summary.audioGraphSummary == "1 day, March 1 to March 1. First day 1 cup, last day 1 cup. "
            + "Most: Sunday, March 1, 1 cup. Fewest: Sunday, March 1, 1 cup.")
    }

    @Test("Given no days or only zeros, when the words are written, then they say nothing sold and the chart is a placeholder")
    func emptyAndZeroSaySo() {
        let zeros = [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]
        for days in [[], zeros] {
            let summary = AxisFormattingSummary(days: days, locale: english)
            #expect(!summary.hasSales)
            #expect(summary.headline == "No cups sold in these two weeks.")
            #expect(summary.audioGraphSummary == "No cups sold in these two weeks.")
        }
    }

    @Test("Given the two weeks, when the Audio Graph summary is written, then it gives actual values with dates")
    func audioGraphSummary() {
        #expect(AxisFormattingSummary(days: twoWeeks, locale: english).audioGraphSummary
            == "14 days, March 1 to March 14. First day 190 cups, last day 240 cups. "
            + "Most: Saturday, March 14, 240 cups. Fewest: Tuesday, March 3, 152 cups.")
    }

    // MARK: Descriptor

    @Test("Given the two weeks, when the descriptor is made, then it names the axes, the days and the series")
    func descriptorDescribesChart() throws {
        let descriptor = AxisFormattingChartDescriptor(days: twoWeeks, locale: english).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold each day, Harbour, March 1 to March 14")
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == 14)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // The busiest day is 240; the axis is drawn to 300, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(240) == "240 cups")
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 14)
    }

    @Test("Given the default stage, when its note is read, then it warns that away from UTC a label can sit a day off its bar")
    func defaultStageNote() {
        #expect(AxisFormattingStage.automatic.note.contains("device's calendar"))
        #expect(AxisFormattingStage.automatic.note.contains("a day off its bar"))
    }

    @Test("Given the centred days stage, when its note is read, then it says the grid lines fall on each Sunday")
    func centredDaysNote() {
        #expect(AxisFormattingStage.centredDays.note.contains("on each Sunday"))
    }

    @Test("Given the sample fortnight, when the caption and the busiest day's label are written, then they name the café, the days and March 14")
    func captionAndCallout() throws {
        let summary = AxisFormattingSummary(days: Array(CafeData.harbourSales.prefix(14)), locale: Locale(identifier: "en_US"))
        // The shared caption for a run of Harbour's days, month first.
        #expect(summary.caption == CafeWording.harbourDaysCaption(from: CafeData.day(0), to: CafeData.day(13), locale: Locale(identifier: "en_US")))
        #expect(summary.caption.hasPrefix("Cups sold each day at the Harbour café, March 1"))
        #expect(summary.caption.hasSuffix("14, 2026"))
        let busiest = try #require(summary.busiestDays.first)
        #expect(summary.calloutText(for: busiest) == "Mar 14: 240")
    }
}
