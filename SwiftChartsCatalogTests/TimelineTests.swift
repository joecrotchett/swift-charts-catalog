import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct TimelineTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ shifts: [Shift] = CafeData.shifts, locale: Locale? = nil) -> TimelineSummary {
        TimelineSummary(shifts: shifts, locale: locale ?? english)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when it opens, then it draws bars with the row labels outside, as the recipe does")
    func startsWithTheRecipe() {
        let model = TimelineViewModel()

        #expect(model.markStyle == .bars)
        #expect(model.labelPlacement == .outside)
        #expect(model.shifts == CafeData.shifts)
    }

    @Test(
        "Given a mark and a label placement, when the snippets are asked for, then they are the mark's and then the labels'",
        arguments: [
            (TimelineMarkStyle.bars, TimelineLabelPlacement.outside, ["timeline-bars", "timeline-labels-outside"]),
            (.bars, .inside, ["timeline-bars", "timeline-labels-inside"]),
            (.rules, .outside, ["timeline-rules", "timeline-labels-outside"]),
            (.rules, .inside, ["timeline-rules", "timeline-labels-inside"]),
        ]
    )
    func snippetsFollowControls(style: TimelineMarkStyle, placement: TimelineLabelPlacement, names: [String]) {
        let model = TimelineViewModel()
        model.markStyle = style
        model.labelPlacement = placement

        #expect(model.snippets.map(\.name) == names)
    }

    @Test("Given the built app, when every snippet the screen can show is looked up, then each exists and holds its code")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        #expect(try #require(store["timeline-bars"]).code.contains("BarMark("))
        #expect(try #require(store["timeline-rules"]).code.contains("RuleMark("))
        #expect(try #require(store["timeline-rules"]).code.contains(".lineStyle("))
        #expect(try #require(store["timeline-labels-inside"]).code.contains("AxisMarks()"))
        #expect(try #require(store["timeline-labels-outside"]).code.contains("AxisMarks(preset: .aligned, position: .leading)"))
        for name in ["timeline-bars", "timeline-rules", "timeline-labels-inside", "timeline-labels-outside"] {
            #expect(try #require(store[name]).file == "Marks/TimelineScreen.swift")
        }
    }

    @Test("Given any setting of the controls, when the headline is written, then it is the same, since no control changes a shift")
    func headlineHoldsForEverySetting() {
        let model = TimelineViewModel()
        let first = model.headline(locale: english)
        model.markStyle = .rules
        model.labelPlacement = .inside

        #expect(model.headline(locale: english) == first)
    }

    @Test("Given the mark changes, when the announcement is written, then it says what changed and then the headline")
    func markAnnouncement() {
        let model = TimelineViewModel()
        model.markStyle = .rules
        #expect(model.markStyleAnnouncement(locale: english) == "Shifts drawn as thin rules. \(model.headline(locale: english))")
        model.markStyle = .bars
        #expect(model.markStyleAnnouncement(locale: english) == "Shifts drawn as bars. \(model.headline(locale: english))")
    }

    // MARK: Derived text

    @Test("Given the café's shifts, when the headline is written, then it gives the longest shift in the data's time zone")
    func headlineNamesLongestShift() {
        #expect(summary().headline == "The longest shift is 7 hours: Tom, 11:00\u{202F}AM to 6:00\u{202F}PM.")
    }

    @Test("Given two shifts tied for the longest, when the headline is written, then it names both")
    func tieNamesBoth() {
        let shifts = [
            Shift(id: 0, barista: "Ana", start: CafeData.time(6), end: CafeData.time(8)),
            Shift(id: 1, barista: "Ben", start: CafeData.time(9), end: CafeData.time(11)),
            Shift(id: 2, barista: "Tom", start: CafeData.time(9), end: CafeData.time(10)),
        ]

        #expect(summary(shifts).longestShifts.map(\.barista) == ["Ana", "Ben"])
        #expect(summary(shifts).headline == "The longest shift is 2 hours: Ana, 6:00\u{202F}AM to 8:00\u{202F}AM and Ben, 9:00\u{202F}AM to 11:00\u{202F}AM.")
    }

    @Test("Given a German locale and a tie, when the headline is written, then the times are German and the list is joined in English")
    func listStaysEnglish() {
        let shifts = [
            Shift(id: 0, barista: "Ana", start: CafeData.time(6), end: CafeData.time(8)),
            Shift(id: 1, barista: "Ben", start: CafeData.time(13), end: CafeData.time(15)),
        ]
        let headline = summary(shifts, locale: Locale(identifier: "de_DE")).headline

        #expect(headline.contains("13:00"))
        #expect(headline.contains(" and Ben"))
        #expect(!headline.contains(" und "))
    }

    @Test("Given a German locale, when a shift's length is written, then its words are English like the sentence round it")
    func durationStaysEnglish() {
        let german = summary(locale: Locale(identifier: "de_DE"))
        let ben = CafeData.shifts[1]

        #expect(german.duration(of: ben) == "6 hours, 30 minutes")
        #expect(german.headline.hasPrefix("The longest shift is 7 hours: "))
        #expect(!german.headline.contains("Stunden"))
        #expect(german.spokenValue(of: ben).hasSuffix(", 6 hours, 30 minutes"))
    }

    @Test("Given no shifts, when the chart's words are written, then they say none are scheduled")
    func emptySaysSo() {
        #expect(summary([]).headline == "No shifts scheduled.")
        #expect(summary([]).audioGraphSummary == "No shifts scheduled.")
        #expect(summary([]).baristas.isEmpty)
    }

    @Test("Given only shifts with no length, when the chart's words are written, then nothing is drawn and they say none are scheduled")
    func zeroLengthShiftsAreNotDrawn() {
        let shifts = [Shift(id: 0, barista: "Ana", start: CafeData.time(6), end: CafeData.time(6))]

        #expect(summary(shifts).shifts.isEmpty)
        #expect(summary(shifts).headline == "No shifts scheduled.")
        #expect(TimelineViewModel(shifts: shifts).headline(locale: english) == "No shifts scheduled.")
    }

    @Test("Given a shift, when its spoken value is written, then it gives start, end and length with units in words")
    func spokenValue() {
        let ben = CafeData.shifts[1]

        #expect(summary().spokenValue(of: ben) == "7:30\u{202F}AM to 2:00\u{202F}PM, 6 hours, 30 minutes")
    }

    @Test("Given a German locale, when a time is written, then it follows that locale and stays in the data's time zone")
    func timesFollowLocale() {
        let german = summary(locale: Locale(identifier: "de_DE"))

        #expect(german.time(CafeData.time(13)) == "13:00")
    }

    @Test("Given counts of one and of several, when they are written, then the noun agrees with the number")
    func countsAgreeInNumber() {
        #expect(TimelineWording.baristas(1, locale: english) == "1 barista")
        #expect(TimelineWording.baristas(4, locale: english) == "4 baristas")
        #expect(CafeWording.shifts(1, locale: english) == "1 shift")
        #expect(CafeWording.shifts(5, locale: english) == "5 shifts")
    }

    @Test("Given a barista with two shifts, when the shifts are named for the Audio Graph, then her two names differ by their start")
    func shiftNamesAreUnique() {
        #expect(summary().baristas == ["Ana", "Ben", "Mia", "Tom"])
        #expect(summary().shiftNames == ["Ana", "Ben", "Mia, from 6:00\u{202F}AM", "Mia, from 1:00\u{202F}PM", "Tom"])
    }

    // MARK: The chart descriptor

    @Test("Given the café's shifts, when the descriptor is made, then it has a title, a summary in actual values and two named series")
    func descriptorDescribesTheTimeline() throws {
        let descriptor = TimelineChartDescriptor(summary: summary()).makeChartDescriptor()

        #expect(descriptor.title == "Today's shifts, by barista")
        #expect(descriptor.summary == "4 baristas, 5 shifts, from 6:00\u{202F}AM to 6:00\u{202F}PM. The longest shift is 7 hours: Tom, 11:00\u{202F}AM to 6:00\u{202F}PM.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Shift")
        #expect(xAxis.categoryOrder == ["Ana", "Ben", "Mia, from 6:00\u{202F}AM", "Mia, from 1:00\u{202F}PM", "Tom"])
        #expect(descriptor.series.map(\.name) == ["Start", "End"])
        #expect(descriptor.series.map(\.dataPoints.count) == [5, 5])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }

    @Test("Given the café's shifts, when the descriptor's value axis is made, then it spans the drawn scale and says times, not numbers")
    func descriptorValueAxisSaysTimes() throws {
        let yAxis = try #require(TimelineChartDescriptor(summary: summary()).makeChartDescriptor().yAxis)

        #expect(yAxis.title == "Time of day")
        #expect(yAxis.range == 6 ... 18)
        #expect(yAxis.valueDescriptionProvider(13.5) == "1:30\u{202F}PM")
    }
}
