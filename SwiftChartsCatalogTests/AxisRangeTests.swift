import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct AxisRangeTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the screen opens, when nothing is touched, then it shows Tuesday with the ranges chosen by meaning")
    func startsOnTuesday() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.period == .tuesday)
        #expect(viewModel.isSwapped == false)
        #expect(viewModel.readings.count == 12)
        #expect(viewModel.cupsDays.map(\.cups) == [152, 173, 194, 215])
    }

    @Test("Given each period, when the cups are chosen, then they are that weekday's days in March")
    func cupsPerPeriod() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.cupsDays(for: .tuesday).map(\.cups) == [152, 173, 194, 215])
        #expect(viewModel.cupsDays(for: .saturday).map(\.cups) == [219, 240, 261, 282])
        #expect(viewModel.readings(for: .saturday).map(\.percent).max() == 92)
    }

    @Test("Given the ranges chosen by meaning, when either period is shown, then the percentage stays at 0 to 100")
    func fixedPercentHolds() {
        let viewModel = AxisRangeViewModel()
        for period in AxisRangePeriod.allCases {
            #expect(viewModel.seatsAxis(for: period, swapped: false).domain == 0 ... 100)
        }
    }

    @Test("Given the ranges chosen by meaning, when each period is shown, then the cups top follows its largest day")
    func dynamicCupsFollows() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.cupsAxis(for: .tuesday, swapped: false).domain == 0 ... 250)
        #expect(viewModel.cupsAxis(for: .saturday, swapped: false).domain == 0 ... 300)
    }

    @Test("Given the ranges swapped, when each period is shown, then the percentage follows the data")
    func swappedPercentFollows() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.seatsAxis(for: .tuesday, swapped: true).domain == 30 ... 60)
        #expect(viewModel.seatsAxis(for: .saturday, swapped: true).domain == 40 ... 100)
    }

    @Test("Given the ranges swapped, when either period is shown, then the cups stay under a fixed 500")
    func swappedCupsHold() {
        let viewModel = AxisRangeViewModel()
        for period in AxisRangePeriod.allCases {
            #expect(viewModel.cupsAxis(for: period, swapped: true).domain == 0 ... 500)
        }
    }

    @Test("Given the controls, when they change, then the current axes follow them")
    func currentAxesFollowControls() {
        let viewModel = AxisRangeViewModel()
        viewModel.period = .saturday
        #expect(viewModel.cupsAxis.top == 300)
        viewModel.isSwapped = true
        #expect(viewModel.seatsAxis.top == 100)
        #expect(viewModel.cupsAxis.top == 500)
    }

    @Test("Given a cups count on a round step, when the range is worked out, then the top is that count")
    func dynamicTopOnStep() {
        #expect(AxisRangeScales.cupsRange(largest: 250) == 0 ... 250)
        #expect(AxisRangeScales.cupsRange(largest: 251) == 0 ... 300)
        #expect(AxisRangeScales.cupsRange(largest: 0) == 0 ... 50)
    }

    @Test("Given every reading the same, when the percentage follows the data, then the axis still has height")
    func flatPercent() {
        #expect(AxisRangeScales.percentRangeFollowingData(lowest: 40, highest: 40) == 30 ... 40)
        #expect(AxisRangeScales.percentRangeFollowingData(lowest: 0, highest: 0) == 0 ... 10)
    }

    @Test("Given each axis, when its labels are listed, then the bottom and the top are labelled, also when thinned")
    func labelsIncludeBothEnds() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.seatsAxis(for: .tuesday, swapped: false).labels(thinned: false) == [0, 25, 50, 75, 100])
        #expect(viewModel.seatsAxis(for: .tuesday, swapped: false).labels(thinned: true) == [0, 50, 100])
        #expect(viewModel.seatsAxis(for: .saturday, swapped: true).labels(thinned: false) == [40, 50, 60, 70, 80, 90, 100])
        #expect(viewModel.seatsAxis(for: .saturday, swapped: true).labels(thinned: true) == [40, 70, 100])
        #expect(viewModel.seatsAxis(for: .tuesday, swapped: true).labels(thinned: true) == [30, 60])
        #expect(viewModel.cupsAxis(for: .tuesday, swapped: false).labels(thinned: false) == [0, 50, 100, 150, 200, 250])
        #expect(viewModel.cupsAxis(for: .tuesday, swapped: false).labels(thinned: true) == [0, 100, 250])
        #expect(viewModel.cupsAxis(for: .saturday, swapped: true).labels(thinned: true) == [0, 250, 500])
        #expect(viewModel.cupsAxis(for: .saturday, swapped: false).labels(thinned: true) == [0, 150, 300])
    }

    @Test("Given a counted value close under the top, when the labels are listed, then it is left out for the top")
    func labelsCrowdingTopLeftOut() {
        #expect(AxisRangeAxis(domain: 0 ... 220, labelStep: 50).labels(thinned: false) == [0, 50, 100, 150, 220])
        #expect(AxisRangeAxis(domain: 0 ... 0, labelStep: 50).labels(thinned: false) == [0, 0])
        #expect(AxisRangeAxis.isRound(250) && AxisRangeAxis.isRound(70))
        #expect(!AxisRangeAxis.isRound(125) && !AxisRangeAxis.isRound(45))
    }

    @Test("Given each period in each mode, when the headline is read, then it names the axes' labelled ends")
    func headlines() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.headline(locale: english)
            == "Tuesday: seats filled on the full 0% to 100% axis; the cups axis stops at 250 cups, following the busiest Tuesday.")
        viewModel.period = .saturday
        #expect(viewModel.headline(locale: english)
            == "Saturday: seats filled on the full 0% to 100% axis; the cups axis stops at 300 cups, following the busiest Saturday.")
        viewModel.isSwapped = true
        #expect(viewModel.headline(locale: english)
            == "Swapped: the seats axis runs from 40% to 100%, so Saturday's line fills the plot; the cups axis is fixed at 500 cups.")
        viewModel.period = .tuesday
        #expect(viewModel.headline(locale: english)
            == "Swapped: the seats axis runs from 30% to 60%, so Tuesday's line fills the plot; the cups axis is fixed at 500 cups.")
    }

    @Test("Given no data, when the headline is read, then it says so and neither chart is drawn")
    func emptyHeadline() {
        let viewModel = AxisRangeViewModel(seatsFilled: [], sales: [])
        #expect(viewModel.hasSeats == false)
        #expect(viewModel.hasCups == false)
        #expect(viewModel.headline(locale: english) == "No seat readings for Tuesday; no cups recorded on Tuesdays.")
    }

    @Test("Given only zero cups, when the chart is chosen, then the cups chart is a placeholder")
    func zeroCups() {
        let sales = [DailySales(day: CafeData.day(2), cups: 0)]
        let viewModel = AxisRangeViewModel(sales: sales)
        #expect(viewModel.hasCups == false)
        #expect(viewModel.headline(locale: english).hasSuffix("no cups recorded on Tuesdays."))
    }

    @Test("Given a German locale, when the headline is read, then its numbers are written the German way")
    func germanHeadline() {
        let viewModel = AxisRangeViewModel()
        let headline = viewModel.headline(locale: Locale(identifier: "de_DE"))
        #expect(headline.contains("100\u{A0}%"))
    }

    @Test("Given each change, when it is announced, then it says what changed and then the headline")
    func announcements() {
        let viewModel = AxisRangeViewModel()
        viewModel.period = .saturday
        #expect(viewModel.announcement(after: .period, locale: english)
            == "Showing Saturday. " + viewModel.headline(locale: english))
        viewModel.isSwapped = true
        #expect(viewModel.announcement(after: .swap, locale: english)
            == "Ranges swapped, the mistake. " + viewModel.headline(locale: english))
        viewModel.isSwapped = false
        #expect(viewModel.announcement(after: .swap, locale: english)
            == "Ranges as chosen by meaning. " + viewModel.headline(locale: english))
    }

    @Test("Given the explanation, when it is read, then it names both periods' cups tops")
    func explanation() {
        #expect(AxisRangeViewModel().explanation(locale: english).contains("stops at 250 cups on Tuesdays and 300 cups on Saturdays"))
    }

    @Test("Given each mode, when the snippets are listed, then both charts lead and that mode's ranges follow")
    func snippetNames() {
        let viewModel = AxisRangeViewModel()
        #expect(viewModel.snippets.map(\.name) == [
            "axes-fixed-or-dynamic-range-seats-chart", "axes-fixed-or-dynamic-range-cups-chart",
            "axes-fixed-or-dynamic-range-fixed", "axes-fixed-or-dynamic-range-dynamic",
        ])
        viewModel.isSwapped = true
        #expect(viewModel.snippets.map(\.name) == [
            "axes-fixed-or-dynamic-range-seats-chart", "axes-fixed-or-dynamic-range-cups-chart",
            "axes-fixed-or-dynamic-range-mistake-percent", "axes-fixed-or-dynamic-range-mistake-cups",
        ])
    }

    @Test("Given each state, when the charts' identity is read, then it changes with the day and the swap")
    func chartIdentity() {
        let viewModel = AxisRangeViewModel()
        var seen: Set<String> = []
        for period in AxisRangePeriod.allCases {
            for swapped in [false, true] {
                viewModel.period = period
                viewModel.isSwapped = swapped
                seen.insert(viewModel.chartIdentity)
            }
        }
        #expect(seen.count == 4)
    }

    @Test("Given the built app, when its snippets are read, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = AxisRangeViewModel()
        var names = viewModel.snippets.map(\.name)
        viewModel.isSwapped = true
        names += viewModel.snippets.map(\.name)
        for name in Set(names) {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given the seats chart, when its descriptor is made, then it carries the drawn range, hours and percentages")
    func seatsDescriptor() throws {
        let viewModel = AxisRangeViewModel()
        let descriptor = viewModel.seatsDescriptor(locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Seats filled by hour on Tuesday")
        #expect(descriptor.summary
            == "12 hourly readings from 7:00\u{202F}AM. Lowest 35% at 7:00\u{202F}AM, highest 60% at 1:00\u{202F}PM. The axis runs from 0% to 100%.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "7:00\u{202F}AM")
        #expect(xAxis.categoryOrder.count == 12)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 100)
        #expect(yAxis.valueDescriptionProvider(35) == "35%")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 12)

        viewModel.isSwapped = true
        let swapped = try #require(viewModel.seatsDescriptor(locale: english).makeChartDescriptor().yAxis)
        #expect(swapped.range == 30 ... 60)
    }

    @Test("Given the cups chart, when its descriptor is made, then it carries the drawn range, days and cups")
    func cupsDescriptor() throws {
        let viewModel = AxisRangeViewModel()
        viewModel.period = .saturday
        let descriptor = viewModel.cupsDescriptor(locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups on each Saturday in March at the Harbour café")
        #expect(descriptor.summary
            == "4 days. Fewest 219 cups on March 7, most 282 cups on March 28. The axis runs from 0 to 300 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["March 7", "March 14", "March 21", "March 28"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == false)

        viewModel.isSwapped = true
        let swapped = try #require(viewModel.cupsDescriptor(locale: english).makeChartDescriptor().yAxis)
        #expect(swapped.range == 0 ... 500)
    }

    @Test("Given each day, when it is written for the axis and for VoiceOver, then it is the UTC day")
    func dayWords() {
        #expect(AxisRangeViewModel.shortDay(CafeData.day(2), locale: english) == "3")
        #expect(AxisRangeViewModel.longDay(CafeData.day(2), locale: english) == "March 3")
    }
}
