import Accessibility
import CoreGraphics
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct CustomGesturesTests {
    private let english = Locale(identifier: "en_US")
    private let calendar = CafeData.calendar

    /// A raw selection the way the chart reports it: a time of day inside the given day.
    private func raw(_ offset: Int) -> Date {
        CafeData.day(offset).addingTimeInterval(14 * 60 * 60 + 23 * 60)
    }

    // MARK: Modes

    @Test("Given a new screen, when it opens, then it uses the built-in drag with nothing selected")
    func startsWithBuiltInDrag() {
        let viewModel = CustomGesturesViewModel()

        #expect(viewModel.mode == .builtInDrag)
        #expect(viewModel.rawSelection == nil)
        #expect(viewModel.selectedDay == nil)
    }

    @Test("Given the built-in drag, when its state is read, then the selection ends on lift and chartXSelection is on the chart")
    func builtInDragState() {
        let mode = CustomGesturesMode.builtInDrag

        #expect(mode.title == "Built-in drag")
        #expect(!mode.selectionLastsAfterLift)
        #expect(mode.usesChartSelection)
        #expect(mode.instruction.contains("lift your finger"))
    }

    @Test("Given tap to select, when its state is read, then the selection lasts after lift and still goes through chartXSelection")
    func tapToSelectState() {
        let mode = CustomGesturesMode.tapToSelect

        #expect(mode.title == "Tap to select")
        #expect(mode.selectionLastsAfterLift)
        #expect(mode.usesChartSelection)
        #expect(mode.instruction.contains("chartGesture"))
    }

    @Test("Given the overlay, when its state is read, then the selection lasts after lift and no selection modifier is used")
    func overlayState() {
        let mode = CustomGesturesMode.overlay

        #expect(mode.title == "Overlay")
        #expect(mode.selectionLastsAfterLift)
        #expect(!mode.usesChartSelection)
    }

    @Test("Given any mode, when its instruction is read, then it names no direction, so it is true in right to left")
    func instructionsNameNoDirection() {
        for mode in CustomGesturesMode.allCases {
            for word in ["left", "right"] {
                #expect(!mode.instruction.lowercased().contains(word))
            }
        }
    }

    @Test("Given each mode, when its snippets are listed, then each shows its own gesture code, then the snap and the band")
    func snippetsFollowTheMode() {
        #expect(CustomGesturesMode.builtInDrag.snippets.map(\.name)
            == ["custom-gestures-built-in", "custom-gestures-snap", "custom-gestures-band"])
        #expect(CustomGesturesMode.tapToSelect.snippets.map(\.name)
            == ["custom-gestures-tap", "custom-gestures-plot-origin", "custom-gestures-snap", "custom-gestures-band"])
        #expect(CustomGesturesMode.overlay.snippets.map(\.name)
            == ["custom-gestures-overlay", "custom-gestures-snap", "custom-gestures-band"])
    }

    @Test("Given the built app, when every mode's snippets are looked up, then each exists in the bundle")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        for mode in CustomGesturesMode.allCases {
            for snippet in mode.snippets {
                #expect(store[snippet.name] != nil, "missing \(snippet.name)")
            }
        }
    }

    @Test("Given a tap-selected day, when the mode changes, then the selection is cleared and the change is announced")
    func modeChangeClearsSelection() {
        let viewModel = CustomGesturesViewModel()
        viewModel.mode = .tapToSelect
        viewModel.rawSelection = raw(3)

        viewModel.mode = .overlay

        #expect(viewModel.rawSelection == nil)
        #expect(viewModel.modeChangeAnnouncement(clearedSelection: true, locale: english)
            == "Selection cleared. \(viewModel.headline(locale: english))")
    }

    @Test("Given no selection, when the mode changes, then nothing is announced, as the headline does not change")
    func modeChangeWithoutSelectionIsQuiet() {
        let viewModel = CustomGesturesViewModel()

        viewModel.mode = .tapToSelect

        #expect(viewModel.modeChangeAnnouncement(clearedSelection: false, locale: english) == nil)
    }

    @Test("Given a selection, when the same mode is chosen again, then the selection stays")
    func sameModeKeepsSelection() {
        let viewModel = CustomGesturesViewModel()
        viewModel.mode = .tapToSelect
        viewModel.rawSelection = raw(3)

        viewModel.mode = .tapToSelect

        #expect(viewModel.selectedDay?.day == CafeData.day(3))
    }

    // MARK: Selection and headline

    @Test("Given a raw date with a time of day, when it is snapped, then it lands on the day that contains it")
    func snapsToTheDay() {
        let viewModel = CustomGesturesViewModel()
        viewModel.rawSelection = raw(3)

        #expect(viewModel.selectedDay?.day == CafeData.day(3))
    }

    @Test("Given a raw date beyond the data, when it is snapped, then nothing is selected and the headline is the busiest day")
    func beyondDataSelectsNothing() {
        let viewModel = CustomGesturesViewModel()
        viewModel.rawSelection = CafeData.day(40)

        #expect(viewModel.selectedDay == nil)
        #expect(viewModel.headline(locale: english).hasPrefix("Busiest day:"))
    }

    @Test(
        "Given each mode, when a day is selected, then the headline names the day written out and its cups",
        arguments: CustomGesturesMode.allCases
    )
    func headlineAfterSelection(mode: CustomGesturesMode) {
        let viewModel = CustomGesturesViewModel()
        viewModel.mode = mode
        viewModel.rawSelection = raw(3)
        let cups = CafeData.harbourSales[3].cups

        #expect(viewModel.headline(locale: english) == "Wednesday, March 4: \(cups) cups.")
    }

    @Test("Given each mode, when the selection is cleared, then the headline goes back to the busiest day")
    func clearingRestoresHeadline() {
        for mode in CustomGesturesMode.allCases {
            let viewModel = CustomGesturesViewModel()
            viewModel.mode = mode
            viewModel.rawSelection = raw(3)

            viewModel.clearSelection()

            #expect(viewModel.headline(locale: english).hasPrefix("Busiest day:"))
        }
    }

    @Test("Given the sample data, when nothing is selected, then the headline names the busiest day and its cups")
    func headlineNamesBusiestDay() throws {
        let viewModel = CustomGesturesViewModel()
        let busiest = try #require(CafeData.harbourSales.max { $0.cups < $1.cups })

        #expect(viewModel.headline(locale: english)
            == "Busiest day: \(viewModel.spokenDay(busiest.day, locale: english)), \(busiest.cups) cups.")
    }

    @Test("Given two days tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        let sales = [
            DailySales(day: CafeData.day(0), cups: 90),
            DailySales(day: CafeData.day(1), cups: 120),
            DailySales(day: CafeData.day(2), cups: 120),
        ]
        let viewModel = CustomGesturesViewModel(sales: sales)

        #expect(viewModel.headline(locale: english) == "Busiest day: Monday, March 2 and Tuesday, March 3, 120 cups.")
    }

    @Test("Given a selected day with one cup, when the headline is written, then the count agrees in number")
    func oneCupAgrees() {
        let viewModel = CustomGesturesViewModel(sales: [DailySales(day: CafeData.day(0), cups: 1)])
        viewModel.rawSelection = raw(0)

        #expect(viewModel.headline(locale: english) == "Sunday, March 1: 1 cup.")
    }

    @Test("Given a German locale, when a selection's headline is written, then the number and the day are German")
    func headlineTakesLocale() {
        let viewModel = CustomGesturesViewModel(sales: [DailySales(day: CafeData.day(0), cups: 1200)])
        viewModel.rawSelection = raw(0)

        let headline = viewModel.headline(locale: Locale(identifier: "de_DE"))

        #expect(headline.contains("1.200"))
        #expect(headline.contains("Sonntag"))
    }

    @Test("Given a day stored as midnight UTC, when it is written out, then it is that day whatever the device's time zone")
    func dayIsWrittenInUTC() {
        let viewModel = CustomGesturesViewModel()

        #expect(viewModel.spokenDay(CafeData.day(0), locale: english) == "Sunday, March 1")
    }

    @Test("Given no days, or only zeros, when the words are written, then there is no data and they say so, counting the days")
    func emptyAndZeroSaySo() {
        let cases: [([DailySales], String)] = [
            ([], "No days of sales yet."),
            ([DailySales(day: CafeData.day(0), cups: 0)], "No cups sold in 1 day."),
            ((0 ..< 28).map { DailySales(day: CafeData.day($0), cups: 0) }, "No cups sold in 28 days."),
        ]
        for (sales, expected) in cases {
            let viewModel = CustomGesturesViewModel(sales: sales)
            viewModel.rawSelection = raw(0)

            #expect(!viewModel.hasData)
            #expect(viewModel.busiestDays.isEmpty)
            #expect(viewModel.headline(locale: english) == expected)
            #expect(viewModel.audioGraphSummary(locale: english) == expected)
        }
    }

    @Test("Given the sample data, when the reserved headline is read, then it is at least as long as every headline the screen can show")
    func reservedHeadlineIsLongest() {
        let viewModel = CustomGesturesViewModel()
        let reserved = viewModel.reservedHeadline(locale: english)

        #expect(reserved.count >= viewModel.headline(locale: english).count)
        for day in viewModel.sales {
            #expect(reserved.count >= viewModel.selectionHeadline(for: day, locale: english).count)
        }
    }

    // MARK: Positions

    @Test("Given a tap inside the plot, when it is converted, then the plot's origin is taken off")
    func positionSubtractsOrigin() {
        let position = CustomGesturesViewModel.plotPosition(
            of: CGPoint(x: 60, y: 100), plotOrigin: CGPoint(x: 25, y: 0), plotSize: CGSize(width: 300, height: 200)
        )

        #expect(position == CGPoint(x: 35, y: 100))
    }

    @Test("Given a tap on the axis labels, beside or below the plot, when it is converted, then it is rejected")
    func positionOutsidePlotIsRejected() {
        let origin = CGPoint(x: 25, y: 0), size = CGSize(width: 300, height: 200)

        #expect(CustomGesturesViewModel.plotPosition(of: CGPoint(x: 10, y: 100), plotOrigin: origin, plotSize: size) == nil)
        #expect(CustomGesturesViewModel.plotPosition(of: CGPoint(x: 100, y: 230), plotOrigin: origin, plotSize: size) == nil)
        #expect(CustomGesturesViewModel.plotPosition(of: CGPoint(x: 330, y: 100), plotOrigin: origin, plotSize: size) == nil)
    }

    // MARK: Audio Graph

    @Test("Given the sample data, when the Audio Graph summary is written, then it gives the count, first, last and most in actual values")
    func summaryGivesActualValues() throws {
        let viewModel = CustomGesturesViewModel()
        let sales = CafeData.harbourSales
        let first = try #require(sales.first), last = try #require(sales.last)

        let summary = viewModel.audioGraphSummary(locale: english)

        #expect(summary.hasPrefix("28 days, March 1 to March 28. First day \(first.cups) cups, last day \(last.cups) cups. Most: "))
    }

    @Test("Given the sample data, when the descriptor is made, then days are written out in order on x and cups have their unit")
    func descriptorDescribesTheChart() throws {
        let viewModel = CustomGesturesViewModel()
        let categories = viewModel.sales.map { viewModel.spokenDay($0.day, locale: english) }
        let descriptor = CustomGesturesChartDescriptor(
            sales: viewModel.sales, summary: viewModel.audioGraphSummary(locale: english),
            categories: categories, locale: english
        ).makeChartDescriptor()

        #expect(descriptor.title == "Cups sold each day at the Harbour café")
        #expect(descriptor.summary == viewModel.audioGraphSummary(locale: english))
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == CafeWording.day)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(xAxis.categoryOrder.count == 28)
        let series = try #require(descriptor.series.first)
        #expect(series.name == CafeWording.harbour)
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == 28)
        let yAxis = try #require(descriptor.yAxis)
        // The drawn axis: 282 cups rounds up to 300, the domain the chart is given.
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(179) == "179 cups")
    }
}
