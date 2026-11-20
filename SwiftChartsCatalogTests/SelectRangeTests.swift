import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct SelectRangeTests {
    private let english = Locale(identifier: "en_US")
    private let hour: TimeInterval = 60 * 60

    /// A model with a built-in selection already reported.
    private func selected(_ range: ClosedRange<Date>, days: [DailySales] = CafeData.harbourSales) -> SelectRangeViewModel {
        let model = SelectRangeViewModel(days: days)
        model.builtInRangeChanged(range)
        return model
    }

    // MARK: States

    @Test("Given a new screen, when it opens, then it uses the built-in selection and nothing is selected")
    func startsBuiltInWithNoSelection() {
        let model = SelectRangeViewModel()
        #expect(model.technique == .builtIn)
        #expect(model.rawRange == nil)
        #expect(model.selection == nil)
        #expect(model.rangeText(locale: english) == nil)
        #expect(model.totalText(locale: english) == nil)
        #expect(model.hasData)
    }

    @Test("Given the techniques, when their names are read, then they are the picker's segments in order")
    func techniqueNames() {
        #expect(SelectRangeTechnique.allCases.map(\.rawValue) == ["Built in", "By hand"])
    }

    @Test("Given a selection, when the technique changes, then the selection is cleared")
    func switchingClears() {
        let model = selected(CafeData.day(2) ... CafeData.day(8))
        #expect(model.selection != nil)
        model.technique = .byHand
        #expect(model.selection == nil)
        model.dragChanged(from: CafeData.day(1), to: CafeData.day(3))
        model.technique = .builtIn
        #expect(model.selection == nil)
    }

    @Test("Given the built-in technique, when a drag reports, then it is ignored; and the reverse when by hand")
    func eachTechniqueTakesOnlyItsOwnInput() {
        let model = SelectRangeViewModel()
        model.dragChanged(from: CafeData.day(1), to: CafeData.day(3))
        #expect(model.selection == nil)
        model.technique = .byHand
        model.builtInRangeChanged(CafeData.day(1) ... CafeData.day(3))
        #expect(model.selection == nil)
    }

    @Test("Given a built-in selection, when the fingers lift and it reports nil, then nothing is selected")
    func builtInClears() {
        let model = selected(CafeData.day(2) ... CafeData.day(8))
        model.builtInRangeChanged(nil)
        #expect(model.selection == nil)
        #expect(model.headline(locale: english) == "Harbour sold 152 to 282 cups a day, March 1 to March 28.")
    }

    // MARK: Snapping

    @Test("Given a raw range with times of day, when it is snapped, then each end is the nearest day")
    func snapsToNearestDay() throws {
        let model = selected(CafeData.day(2).addingTimeInterval(11 * hour) ... CafeData.day(8).addingTimeInterval(-11 * hour))
        let selection = try #require(model.selection)
        #expect(selection.firstDay == CafeData.day(2))
        #expect(selection.lastDay == CafeData.day(8))
        #expect(selection.days.count == 7)
        #expect(selection.total == 1253)

        let later = selected(CafeData.day(2).addingTimeInterval(13 * hour) ... CafeData.day(8))
        #expect(later.selection?.firstDay == CafeData.day(3))
    }

    @Test("Given a range reaching past the data, when it is snapped, then it stops at the first and last days")
    func clampsToData() throws {
        let model = selected(CafeData.day(-3) ... CafeData.day(40))
        let selection = try #require(model.selection)
        #expect(selection.firstDay == CafeData.day(0))
        #expect(selection.lastDay == CafeData.day(27))
        #expect(selection.total == 5726)
        #expect(model.band == CafeData.day(0) ... CafeData.day(27))
    }

    @Test("Given one selected day in the middle, when the band is made, then it covers half a day either side")
    func bandAroundOneDay() {
        let model = selected(CafeData.day(5) ... CafeData.day(5))
        #expect(model.band == CafeData.day(5).addingTimeInterval(-12 * hour) ... CafeData.day(5).addingTimeInterval(12 * hour))
    }

    // MARK: The same range from both techniques

    @Test("Given the same two positions, when each technique reports them, then both select the same range", arguments: [
        (2.0, 8.0), (8.4, 2.3), (0.0, 27.0), (13.6, 13.4), (-2.0, 3.0),
    ])
    func bothTechniquesAgree(startOffset: Double, endOffset: Double) {
        let start = CafeData.day(0).addingTimeInterval(startOffset * 24 * hour)
        let end = CafeData.day(0).addingTimeInterval(endOffset * 24 * hour)

        let builtIn = SelectRangeViewModel()
        // The framework hands over an ordered range; a drag can run either way.
        builtIn.builtInRangeChanged(min(start, end) ... max(start, end))

        let byHand = SelectRangeViewModel()
        byHand.technique = .byHand
        byHand.dragChanged(from: start, to: end)

        #expect(builtIn.selection != nil)
        #expect(builtIn.selection == byHand.selection)
        #expect(builtIn.rangeText(locale: english) == byHand.rangeText(locale: english))
        #expect(builtIn.headline(locale: english) == byHand.headline(locale: english))
    }

    // MARK: The range's text

    @Test("Given a week selected, when its text is read, then the label and headline give the days and the total")
    func weekText() {
        let model = selected(CafeData.day(2) ... CafeData.day(8))
        #expect(model.rangeText(locale: english) == "Mar 3 – Mar 9")
        #expect(model.totalText(locale: english) == "1,253 cups")
        #expect(model.headline(locale: english) == "March 3 to March 9: 1,253 cups in 7 days.")
    }

    @Test("Given a week selected at an accessibility text size, when the compact text is read, then the month is written once")
    func compactWeekText() throws {
        let model = selected(CafeData.day(2) ... CafeData.day(8))
        let text = try #require(model.rangeText(locale: english, compact: true))
        #expect(text.hasPrefix("Mar 3"))
        #expect(text.hasSuffix("9"))
        #expect(!text.contains("Mar 9"))
        #expect(text.count < "Mar 3 – Mar 9".count)
        let oneDay = selected(CafeData.day(2) ... CafeData.day(2))
        #expect(oneDay.rangeText(locale: english, compact: true) == "Mar 3")
    }

    @Test("Given one day selected, when its text is read, then it names the day once and agrees in number")
    func singleDayText() {
        let model = selected(CafeData.day(2) ... CafeData.day(2).addingTimeInterval(hour))
        #expect(model.rangeText(locale: english) == "Mar 3")
        #expect(model.totalText(locale: english) == "152 cups")
        #expect(model.headline(locale: english) == "March 3: 152 cups.")
    }

    @Test("Given a range that holds no data, when its text is read, then it says no sales were recorded")
    func emptyRangeText() {
        let model = selected(CafeData.day(32) ... CafeData.day(35))
        #expect(model.selection?.days.isEmpty == true)
        #expect(model.rangeText(locale: english) == "Apr 2 – Apr 5")
        #expect(model.totalText(locale: english) == "No sales")
        #expect(model.headline(locale: english) == "No sales recorded from April 2 to April 5.")

        let oneDay = selected(CafeData.day(32) ... CafeData.day(32))
        #expect(oneDay.headline(locale: english) == "No sales recorded on April 2.")
    }

    @Test("Given a locale that writes numbers differently, when the text is read, then the total follows it")
    func localeFollowed() {
        let model = selected(CafeData.day(2) ... CafeData.day(8))
        let german = Locale(identifier: "de_DE")
        #expect(model.totalText(locale: german) == "1.253 cups")
        #expect(model.rangeText(locale: german)?.contains("3.") == true)
    }

    // MARK: Headline at rest and with no data

    @Test("Given no selection, when the headline is read, then it gives the lowest and highest days drawn")
    func restingHeadline() {
        #expect(SelectRangeViewModel().headline(locale: english) == "Harbour sold 152 to 282 cups a day, March 1 to March 28.")
    }

    @Test("Given one day of data, when the headline is read, then it names that day and its cups")
    func oneDayOfData() {
        let model = SelectRangeViewModel(days: [DailySales(day: CafeData.day(0), cups: 1)])
        #expect(model.headline(locale: english) == "Harbour sold 1 cup on March 1.")
    }

    @Test("Given no data, when the screen is read, then the headline says so and nothing can be selected")
    func noData() {
        let model = SelectRangeViewModel(days: [])
        #expect(!model.hasData)
        #expect(model.headline(locale: english) == "No sales to show.")
        model.builtInRangeChanged(CafeData.day(0) ... CafeData.day(3))
        #expect(model.selection?.days.isEmpty == true)
        #expect(model.totalText(locale: english) == "No sales")
    }

    // MARK: Announcement

    @Test("Given a range drawn by hand, when the picker changes the technique, then the announcement says it was cleared, then the headline")
    func announcementWhenCleared() {
        let model = SelectRangeViewModel()
        model.technique = .byHand
        model.dragChanged(from: CafeData.day(2), to: CafeData.day(8))
        model.technique = .builtIn

        #expect(model.techniqueAnnouncement(locale: english)
            == "Range cleared. Harbour sold 152 to 282 cups a day, March 1 to March 28.")
    }

    @Test("Given nothing selected, when the picker changes the technique, then nothing is announced, as nothing drawn changed")
    func noAnnouncementWithoutSelection() {
        let model = SelectRangeViewModel()
        model.technique = .byHand
        #expect(model.techniqueAnnouncement(locale: english) == nil)

        model.dragChanged(from: CafeData.day(2), to: CafeData.day(8))
        model.technique = .builtIn
        model.technique = .byHand
        #expect(model.techniqueAnnouncement(locale: english) == nil)
    }

    // MARK: Clearing a range drawn by hand

    @Test("Given a range drawn by hand, when Clear range is pressed, then nothing is selected and the button can no longer act")
    func clearRange() {
        let model = SelectRangeViewModel()
        model.technique = .byHand
        #expect(!model.canClearRange)

        model.dragChanged(from: CafeData.day(2), to: CafeData.day(8))
        #expect(model.canClearRange)

        model.clearSelection()
        #expect(model.selection == nil)
        #expect(!model.canClearRange)
        #expect(model.headline(locale: english) == "Harbour sold 152 to 282 cups a day, March 1 to March 28.")
    }

    @Test("Given the built-in technique, when a range is selected, then Clear range cannot act, as lifting the fingers clears it")
    func noClearForBuiltIn() {
        let model = selected(CafeData.day(2) ... CafeData.day(8))
        #expect(!model.canClearRange)
    }

    // MARK: Room kept for the headline

    @Test("Given the sample data, when the reserved headline is read, then it is the longest headline at rest or for any range of days")
    func reservedHeadlineIsTheLongest() throws {
        let model = SelectRangeViewModel()
        let reserved = try #require(model.reservedHeadline(locale: english))
        var longest = model.headline(locale: english).count
        for start in 0 ..< 28 {
            for end in start ..< 28 {
                let probe = selected(CafeData.day(start) ... CafeData.day(end))
                longest = max(longest, probe.headline(locale: english).count)
            }
        }

        #expect(reserved.count == longest)
        #expect(model.reservedHeadline(locale: english) == reserved)
    }

    @Test("Given no data, when the reserved headline is read, then nothing is reserved")
    func reservedHeadlineWithoutData() {
        #expect(SelectRangeViewModel(days: []).reservedHeadline(locale: english) == nil)
    }

    // MARK: Elements and the Audio Graph

    @Test("Given a day, when its element label is read, then the date is written out in the data's time zone")
    func elementLabel() {
        let model = SelectRangeViewModel()
        #expect(model.elementLabel(for: CafeData.harbourSales[2], locale: english) == "Tuesday, March 3")
    }

    @Test("Given the sample data, when the descriptor is made, then it names the axes and series and totals each week")
    func descriptor() throws {
        let descriptor = SelectRangeChartDescriptor(days: CafeData.harbourSales, calendar: CafeData.calendar, locale: english)
            .makeChartDescriptor()
        #expect(descriptor.title == "Cups sold a day at the Harbour café")
        #expect(descriptor.summary == "28 days, March 1 to March 28. Lowest 152 cups, highest 282 cups, 5,726 cups in total. "
            + "By week: March 1 to March 7, 1,211 cups; March 8 to March 14, 1,358 cups; "
            + "March 15 to March 21, 1,505 cups; March 22 to March 28, 1,652 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        // 282 cups rounds up to 300, the domain the chart is given.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(190) == "190 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 28)
    }

    @Test("Given no data, when the descriptor is made, then its summary says there is nothing to show")
    func emptyDescriptor() {
        let descriptor = SelectRangeChartDescriptor(days: [], calendar: CafeData.calendar, locale: english)
        #expect(descriptor.summary == "No sales to show.")
        #expect(descriptor.makeChartDescriptor().series.first?.dataPoints.isEmpty == true)
    }

    // MARK: Snippets

    @Test("Given each technique, when See Code opens, then it shows that technique's snippets and the snapping")
    func snippetsFollowTechnique() {
        let model = SelectRangeViewModel()
        #expect(model.snippets.map(\.name) == [
            "select-a-range-built-in-modifier", "select-a-range-built-in-marks", "select-a-range-snapping",
        ])
        model.technique = .byHand
        #expect(model.snippets.map(\.name) == [
            "select-a-range-by-hand-gesture", "select-a-range-hold-then-drag", "select-a-range-by-hand-mark",
            "select-a-range-snapping",
        ])
    }

    @Test("Given the app's snippets, when they are loaded, then every snippet this screen names exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for reference in SelectRangeViewModel.allSnippets {
            #expect(store[reference.name] != nil, "missing \(reference.name)")
        }
    }
}
