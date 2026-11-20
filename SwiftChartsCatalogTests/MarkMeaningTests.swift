import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct MarkMeaningTests {
    private let british = Locale(identifier: "en_GB")

    private func day(_ offset: Int, _ cups: Int) -> DailySales {
        DailySales(day: CafeData.day(offset), cups: cups)
    }

    // MARK: The view model's states

    @Test("Given a new screen, when it opens, then it draws the thirty days as bars, from zero, with the toggle off")
    func startsAsBars() {
        let viewModel = MarkMeaningViewModel()

        #expect(viewModel.days == CafeData.thirtyDays)
        #expect(viewModel.mark == .bars)
        #expect(!viewModel.showsPointsOnLine)
        #expect(!viewModel.showsPlaceholder)
        #expect(viewModel.cupsAxis == 0 ... 250)
        #expect(viewModel.isCombineToggleDisabled)
        #expect(!viewModel.isMarkPickerDisabled)
    }

    @Test("Given the line, when the combine toggle is on, then the line carries its points and the toggle is enabled")
    func pointsOnTheLine() {
        let viewModel = MarkMeaningViewModel(mark: .line, pointsOnLine: true)

        #expect(viewModel.showsPointsOnLine)
        #expect(!viewModel.isCombineToggleDisabled)
    }

    @Test("Given the toggle is on, when another mark is picked, then no points are added and the toggle is disabled")
    func toggleActsOnlyOnTheLine() {
        let viewModel = MarkMeaningViewModel(mark: .line, pointsOnLine: true)
        viewModel.mark = .points

        #expect(!viewModel.showsPointsOnLine)
        #expect(viewModel.isCombineToggleDisabled)
        #expect(viewModel.pointsOnLine)
    }

    @Test("Given every mark, when the value axis is read, then it is the same, so only the mark changes")
    func sameAxisForEveryMark() {
        let axes = MarkMeaningMark.allCases.map { MarkMeaningViewModel(mark: $0).cupsAxis }

        #expect(Set(axes.map(\.upperBound)) == [250])
        #expect(Set(axes.map(\.lowerBound)) == [0])
    }

    @Test("Given no days, when the screen draws, then a placeholder shows and both controls are disabled")
    func noDays() {
        let viewModel = MarkMeaningViewModel(days: [], mark: .line)

        #expect(viewModel.showsPlaceholder)
        #expect(viewModel.isMarkPickerDisabled)
        #expect(viewModel.isCombineToggleDisabled)
        #expect(viewModel.placeholderTitle == "No days recorded")
        #expect(viewModel.headline(locale: british) == "No days recorded yet.")
        #expect(viewModel.cupsAxis == 0 ... 50)
    }

    @Test("Given days of no cups, when drawn as bars, then a placeholder shows; as a line or points, the zeros are drawn")
    func onlyZeros() {
        let zeros = [day(0, 0), day(1, 0)]
        let bars = MarkMeaningViewModel(days: zeros, mark: .bars)
        let line = MarkMeaningViewModel(days: zeros, mark: .line)
        let points = MarkMeaningViewModel(days: zeros, mark: .points)

        #expect(bars.showsPlaceholder)
        #expect(!bars.isMarkPickerDisabled)
        #expect(bars.placeholderTitle == "No cups sold")
        #expect(bars.headline(locale: british) == "No cups sold on any of these days.")
        #expect(!line.showsPlaceholder)
        #expect(line.headline(locale: british) == "The line starts and ends at 0 cups, on 1 March and 2 March.")
        #expect(!points.showsPlaceholder)
        #expect(points.headline(locale: british) == "Every point sits at 0 cups.")
    }

    // MARK: Headlines

    @Test("Given bars, when the headline is written, then it names only the longest bar, whose cups are labelled on it")
    func barsHeadline() {
        let viewModel = MarkMeaningViewModel(mark: .bars)
        let summary = MarkMeaningSummary(days: viewModel.days, locale: british)

        #expect(viewModel.headline(locale: british) == "Longest bar: 29 March, 230 cups.")
        #expect(summary.labelledDays(mark: .bars).map(\.cups) == [230])
        #expect(summary.labelText(230) == "230")
    }

    @Test("Given a line, when the headline is written, then it gives the direction and the first and last days, and no figure the axis cannot resolve")
    func lineHeadline() {
        let viewModel = MarkMeaningViewModel(mark: .line)

        #expect(viewModel.headline(locale: british) == "The line rises from its first day, 1 March, to its last, 30 March.")
        #expect(MarkMeaningSummary(days: viewModel.days, locale: british).labelledDays(mark: .line).isEmpty)
    }

    @Test("Given points on the line, when the headline is written, then it adds that every day is marked")
    func linePointsHeadline() {
        let headline = MarkMeaningViewModel(mark: .line, pointsOnLine: true).headline(locale: british)

        #expect(headline == "The line rises from its first day, 1 March, to its last, 30 March. Its points mark all 30 days.")
    }

    @Test("Given points, when the headline is written, then it names the highest point, whose cups are labelled on it")
    func pointsHeadline() {
        let headline = MarkMeaningViewModel(mark: .points).headline(locale: british)

        #expect(headline == "Each point is one day. Highest: 29 March, 230 cups.")
        #expect(MarkMeaningSummary(days: CafeData.thirtyDays, locale: british).labelledDays(mark: .points).count == 1)
    }

    @Test("Given days all alike, when bars or points are described, then no figure is given and no day is labelled")
    func flatDays() {
        let days = [day(0, 7), day(1, 7)]
        let summary = MarkMeaningSummary(days: days, locale: british)

        #expect(MarkMeaningViewModel(days: days, mark: .bars).headline(locale: british) == "Every bar is the same length.")
        #expect(MarkMeaningViewModel(days: days, mark: .points).headline(locale: british) == "Every point sits at the same height.")
        #expect(MarkMeaningViewModel(days: days, mark: .line).headline(locale: british)
            == "The line starts and ends at the same height, on 1 March and 2 March.")
        #expect(summary.labelledDays(mark: .bars).isEmpty)
    }

    @Test("Given a falling line, when the headline is written, then it says falls")
    func fallingLine() {
        let headline = MarkMeaningViewModel(days: [day(0, 9), day(1, 1)], mark: .line).headline(locale: british)

        #expect(headline == "The line falls from its first day, 1 March, to its last, 2 March.")
    }

    @Test("Given a tie for the longest bar, when bars are described, then both tied days are named and labelled")
    func barsTie() {
        let days = [day(0, 5), day(1, 0), day(2, 1), day(3, 5)]
        let viewModel = MarkMeaningViewModel(days: days, mark: .bars)

        #expect(viewModel.headline(locale: british) == "Longest bars: 1 March and 4 March, 5 cups.")
        #expect(MarkMeaningSummary(days: days, locale: british).labelledDays(mark: .bars).count == 2)
    }

    @Test("Given one day, when drawn as a line, then the headline says the line is one day")
    func oneDayLine() {
        let headline = MarkMeaningViewModel(days: [day(0, 1)], mark: .line).headline(locale: british)

        #expect(headline == "The line is one day, 1 March: a single point, with no change to show.")
    }

    @Test("Given every setting, when the reserved headline is read, then it is at least as long as each one")
    func reservedHeadline() {
        let viewModel = MarkMeaningViewModel()
        let longest = viewModel.longestHeadline(locale: british)
        for mark in MarkMeaningMark.allCases {
            for points in [false, true] {
                let headline = MarkMeaningViewModel(mark: mark, pointsOnLine: points).headline(locale: british)
                #expect(longest.count >= headline.count)
            }
        }
    }

    // MARK: Announcements and text

    @Test("Given the mark changes, when it is announced, then the announcement says what changed, then the headline")
    func markAnnouncement() {
        let viewModel = MarkMeaningViewModel(mark: .points)

        #expect(viewModel.markChangeAnnouncement(locale: british)
            == "Showing points. Each point is one day. Highest: 29 March, 230 cups.")
    }

    @Test("Given the toggle changes, when it is announced, then it says points were added or taken off, then the headline")
    func pointsAnnouncement() {
        let on = MarkMeaningViewModel(mark: .line, pointsOnLine: true)
        let off = MarkMeaningViewModel(mark: .line, pointsOnLine: false)

        #expect(on.pointsChangeAnnouncement(locale: british).hasPrefix("Points added to the line. The line rises"))
        #expect(off.pointsChangeAnnouncement(locale: british)
            == "Points taken off the line. The line rises from its first day, 1 March, to its last, 30 March.")
    }

    @Test("Given a day, when its element is written, then the label is the day in full and the value its cups")
    func elementText() {
        let summary = MarkMeaningSummary(days: CafeData.thirtyDays, locale: british)

        #expect(summary.elementLabel(CafeData.day(0)) == "Sunday 1 March")
        #expect(summary.elementValue(1) == "1 cup")
        #expect(summary.elementValue(174) == "174 cups")
    }

    @Test("Given each mark, when the explanation is read, then it names what that mark makes easy to see")
    func explanations() {
        #expect(MarkMeaningViewModel(mark: .bars).explanation.contains("Bars make amounts easy to compare"))
        #expect(MarkMeaningViewModel(mark: .line).explanation.contains("A line makes change easy to see"))
        #expect(MarkMeaningViewModel(mark: .line, pointsOnLine: true).explanation.contains("Points on the line"))
        #expect(MarkMeaningViewModel(mark: .points).explanation.contains("Points make single readings easy to pick out"))
    }

    // MARK: Snippets

    @Test("Given each setting, when its snippet is chosen, then it is the one for that mark")
    func snippetNames() {
        #expect(MarkMeaningViewModel(mark: .bars).snippets.map(\.name) == [MarkMeaningViewModel.barsSnippet])
        #expect(MarkMeaningViewModel(mark: .line).snippets.map(\.name) == [MarkMeaningViewModel.lineSnippet])
        #expect(MarkMeaningViewModel(mark: .line, pointsOnLine: true).snippets.map(\.name)
            == [MarkMeaningViewModel.linePointsSnippet])
        #expect(MarkMeaningViewModel(mark: .points, pointsOnLine: true).snippets.map(\.name)
            == [MarkMeaningViewModel.pointsSnippet])
    }

    @Test("Given the built app, when each snippet is looked up, then it exists and shows its mark")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for reference in MarkMeaningViewModel.allSnippets {
            #expect(store[reference.name] != nil, "\(reference.name) is missing")
        }
        #expect(try #require(store[MarkMeaningViewModel.barsSnippet]).code.contains("BarMark("))
        #expect(try #require(store[MarkMeaningViewModel.lineSnippet]).code.contains("LineMark("))
        #expect(try #require(store[MarkMeaningViewModel.linePointsSnippet]).code.contains(".symbol(.circle)"))
        #expect(try #require(store[MarkMeaningViewModel.pointsSnippet]).code.contains("PointMark("))
    }

    // MARK: The Audio Graph

    @Test("Given the line, when the descriptor is made, then it is one continuous named series on the drawn axis")
    func lineDescriptor() throws {
        let descriptor = MarkMeaningViewModel(mark: .line).descriptor(locale: british).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café, as a line")
        #expect(descriptor.summary == "30 days. First day 174 cups, last day 214 cups. "
            + "Highest 230 cups on 29 March, lowest 150 cups on 3 March.")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 30)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "1 March")
        #expect(xAxis.categoryOrder.last == "30 March")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        #expect(yAxis.range == 0 ... 250)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(230) == "230 cups")
    }

    @Test("Given bars or points, when the descriptor is made, then the series is separate readings")
    func separateDescriptors() {
        for mark in [MarkMeaningMark.bars, .points] {
            let descriptor = MarkMeaningViewModel(mark: mark).descriptor(locale: british).makeChartDescriptor()
            #expect(descriptor.series.first?.isContinuous == false)
            #expect(descriptor.title == "Cups sold each day at the Harbour café, as \(mark.spokenName)")
        }
    }

    @Test("Given the thirty days, when the caption is written, then it names the month the axis's day numbers belong to")
    func captionNamesMonth() {
        #expect(MarkMeaningViewModel().caption(locale: Locale(identifier: "en_US"))
            == "Invented sample: cups a day at the Harbour café, March 2026")
        #expect(MarkMeaningViewModel().caption(locale: Locale(identifier: "en_US")) == CafeWording.inventedDaysCaption(locale: Locale(identifier: "en_US")))
        #expect(MarkMeaningViewModel(days: Array(CafeData.thirtyDays.prefix(10))).caption(locale: Locale(identifier: "en_US"))
            == "Cups sold each day at the Harbour café, March 2026")
        #expect(MarkMeaningViewModel(days: []).caption(locale: british) == "Cups sold each day at the Harbour café")
    }
}
