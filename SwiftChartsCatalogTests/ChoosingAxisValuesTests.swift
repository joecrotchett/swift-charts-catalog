import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ChoosingAxisValuesTests {
    private let english = Locale(identifier: "en_US")

    /// Reports a set of axis values as the chart's labels do, one reading per value.
    private func draw(_ values: [Double], for choice: ChoosingAxisValuesChoice, on viewModel: ChoosingAxisValuesViewModel) {
        for (index, value) in values.enumerated() {
            viewModel.record(
                ChoosingAxisValuesReading(choice: choice, index: index, count: values.count, value: value),
                locale: english
            )
        }
    }

    // MARK: Settings

    @Test("Given a new screen, when it opens, then it asks for about four automatic values")
    func defaultState() {
        let viewModel = ChoosingAxisValuesViewModel()

        #expect(viewModel.mode == .automatic)
        #expect(viewModel.desiredCount == 4)
        #expect(viewModel.choice == .automatic(desiredCount: 4))
        #expect(ChoosingAxisValuesViewModel.countRange.contains(viewModel.desiredCount))
        #expect(ChoosingAxisValuesViewModel.strides.contains(viewModel.stride))
        #expect(viewModel.actualCount == nil)
        #expect(viewModel.drawnValues == nil)
    }

    @Test("Given each mode, when the choice is read, then it carries that mode's one setting", arguments: [
        (ChoosingAxisValuesMode.automatic, ChoosingAxisValuesChoice.automatic(desiredCount: 6)),
        (.stride, .stride(by: 25)),
        (.exact, .exact([0, 100, 200, 300])),
    ])
    func choices(mode: ChoosingAxisValuesMode, expected: ChoosingAxisValuesChoice) {
        let viewModel = ChoosingAxisValuesViewModel()
        viewModel.desiredCount = 6
        viewModel.stride = 25
        viewModel.mode = mode

        #expect(viewModel.choice == expected)
    }

    @Test("Given the exact values, when compared with the data, then one lies above every bar and widens the scale")
    func exactValuesWiden() throws {
        let top = try #require(ChoosingAxisValuesViewModel.exactValues.max())
        #expect(top > ChoosingAxisValuesViewModel().tallestCups)
    }

    // MARK: Requested against actual

    @Test("Given four values asked for, when the chart draws five, then the stepper shows both counts")
    func requestedAgainstActual() {
        let viewModel = ChoosingAxisValuesViewModel(announce: { _ in })
        draw([0, 50, 100, 150, 200], for: .automatic(desiredCount: 4), on: viewModel)

        #expect(viewModel.desiredCount == 4)
        #expect(viewModel.actualCount == 5)
        #expect(viewModel.countComparison(locale: english) == "Asked for 4, drew 5")
    }

    @Test("Given counts asked for and drawn, when the headline is read, then it names both and the span drawn", arguments: [
        (4, [0.0, 50, 100, 150, 200], "Asked for about 4 values; the axis drew 5, from 0 to 200."),
        (2, [0.0, 100, 200], "Asked for about 2 values; the axis drew 3, from 0 to 200."),
        (1, [0.0], "Asked for about 1 value; the axis drew 1, at 0."),
    ])
    func automaticHeadlines(asked: Int, drawn: [Double], expected: String) {
        let viewModel = ChoosingAxisValuesViewModel(announce: { _ in })
        viewModel.desiredCount = asked
        draw(drawn, for: .automatic(desiredCount: asked), on: viewModel)

        #expect(viewModel.actualCount == drawn.count)
        #expect(viewModel.headline(locale: english) == expected)
    }

    @Test("Given a count asked for, when the chart has not yet reported, then only the request is stated")
    func beforeTheChartReports() {
        let viewModel = ChoosingAxisValuesViewModel()
        viewModel.desiredCount = 7

        #expect(viewModel.countComparison(locale: english) == "Asked for 7")
        #expect(viewModel.headline(locale: english) == "Asked for about 7 values.")
    }

    @Test("Given a report for an earlier count, when the count changes, then the old report is not shown as the new one")
    func staleReportIgnored() {
        let viewModel = ChoosingAxisValuesViewModel(announce: { _ in })
        draw([0, 50, 100, 150, 200], for: .automatic(desiredCount: 4), on: viewModel)
        viewModel.desiredCount = 8

        #expect(viewModel.actualCount == nil)
        #expect(viewModel.countComparison(locale: english) == "Asked for 8")

        viewModel.desiredCount = 4
        #expect(viewModel.actualCount == 5)
    }

    @Test("Given some values reported, when not every one has arrived, then the count is known and the values are not")
    func partialReport() {
        let viewModel = ChoosingAxisValuesViewModel(announce: { _ in })
        viewModel.record(
            ChoosingAxisValuesReading(choice: .automatic(desiredCount: 4), index: 0, count: 5, value: 0),
            locale: english
        )

        #expect(viewModel.actualCount == 5)
        #expect(viewModel.drawnValues == nil)
    }

    // MARK: Stride and exact

    @Test("Given each stride, when the chart draws its values, then the headline gives the step and the count", arguments: [
        (25, [0.0, 25, 50, 75, 100, 125, 150, 175], "A value every 25 cups: 8 values, from 0 to 175."),
        (50, [0.0, 50, 100, 150, 200], "A value every 50 cups: 5 values, from 0 to 200."),
        (100, [0.0, 100, 200], "A value every 100 cups: 3 values, from 0 to 200."),
    ])
    func strideHeadlines(step: Int, drawn: [Double], expected: String) {
        let viewModel = ChoosingAxisValuesViewModel(announce: { _ in })
        viewModel.mode = .stride
        viewModel.stride = step
        draw(drawn, for: .stride(by: step), on: viewModel)

        #expect(viewModel.headline(locale: english) == expected)
        #expect(viewModel.countComparison(locale: english) == "Asked for 4")
    }

    @Test("Given exact values, when the headline is read, then it names the value that stretches the axis and the tallest bar")
    func exactHeadline() {
        let viewModel = ChoosingAxisValuesViewModel()
        viewModel.mode = .exact

        #expect(viewModel.headline(locale: english)
            == "Exactly 0, 100, 200, and 300: 300 stretches the axis above Tea, the tallest bar.")
    }

    @Test("Given exact values none of which lie above the data, when the headline is read, then nothing is said to stretch")
    func exactHeadlineWithoutWidening() {
        let viewModel = ChoosingAxisValuesViewModel(sales: [DrinkSales(drink: "Tea", cups: 400)])
        viewModel.mode = .exact

        #expect(viewModel.headline(locale: english) == "Exactly 0, 100, 200, and 300.")
    }

    @Test("Given a German locale, when the headline is read, then its numbers are written the German way")
    func germanNumbers() {
        let viewModel = ChoosingAxisValuesViewModel(sales: [DrinkSales(drink: "Tea", cups: 1500)], announce: { _ in })
        viewModel.mode = .stride
        viewModel.stride = 100
        draw([0, 1000, 2000], for: .stride(by: 100), on: viewModel)

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")) == "A value every 100 cups: 3 values, from 0 to 2.000.")
    }

    // MARK: Domain

    @Test("Given each mode, when the chart has not reported its domain, then the domain covers the data and any exact values", arguments: [
        (ChoosingAxisValuesMode.automatic, 164.0),
        (.stride, 164.0),
        (.exact, 300.0),
    ])
    func fallbackDomain(mode: ChoosingAxisValuesMode, top: Double) {
        let viewModel = ChoosingAxisValuesViewModel()
        viewModel.mode = mode

        #expect(viewModel.domain == 0 ... top)
    }

    @Test("Given a domain reported for the current setting, when read, then it is the reported one; for another setting it is not")
    func reportedDomain() {
        let viewModel = ChoosingAxisValuesViewModel()
        viewModel.recordDomain([0, 175], for: .automatic(desiredCount: 4))
        #expect(viewModel.domain == 0 ... 175)

        viewModel.desiredCount = 2
        #expect(viewModel.domain == 0 ... 164)
    }

    // MARK: Empty and zero data

    @Test("Given no sales or only zeros, when the headline is read, then it says nothing was sold", arguments: [
        [DrinkSales](),
        [DrinkSales(drink: "Tea", cups: 0), DrinkSales(drink: "Latte", cups: 0)],
    ])
    func noData(sales: [DrinkSales]) {
        let viewModel = ChoosingAxisValuesViewModel(sales: sales)

        #expect(!viewModel.hasData)
        #expect(viewModel.headline(locale: english) == "No cups sold yet today.")
        #expect(viewModel.audioGraphSummary(locale: english) == "No cups sold yet today.")
        viewModel.mode = .exact
        #expect(viewModel.headline(locale: english) == "No cups sold yet today.")
    }

    // MARK: Announcements

    @Test("Given a control change, when the chart reports every value, then one announcement says what changed and then the headline")
    func announcesAfterDrawing() {
        var announcements: [String] = []
        let viewModel = ChoosingAxisValuesViewModel(fallbackDelay: .seconds(60), announce: { announcements.append($0) })
        viewModel.mode = .stride

        // Three of five values reported: the drawing is not complete yet.
        for (index, value) in [0.0, 50, 100].enumerated() {
            viewModel.record(
                ChoosingAxisValuesReading(choice: .stride(by: 50), index: index, count: 5, value: value),
                locale: english
            )
        }
        #expect(announcements.isEmpty)

        draw([0, 50, 100, 150, 200], for: .stride(by: 50), on: viewModel)
        #expect(announcements == [
            "Axis values: one every 50 cups. A value every 50 cups: 5 values, from 0 to 200.",
        ])

        draw([0, 50, 100, 150, 200], for: .stride(by: 50), on: viewModel)
        #expect(announcements.count == 1)
    }

    @Test("Given a control change, when a label never reports, then the announcement is still posted once the count is known")
    func announcesWhenALabelIsDropped() async throws {
        var announcements: [String] = []
        let viewModel = ChoosingAxisValuesViewModel(fallbackDelay: .zero, announce: { announcements.append($0) })
        viewModel.mode = .stride

        // Four of five labels report; the fifth was dropped by the framework.
        for (index, value) in [0.0, 50, 100, 150].enumerated() {
            viewModel.record(
                ChoosingAxisValuesReading(choice: .stride(by: 50), index: index, count: 5, value: value),
                locale: english
            )
        }
        for _ in 0 ..< 20 where announcements.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }

        #expect(announcements == ["Axis values: one every 50 cups. A value every 50 cups: 5 values."])
    }

    @Test("Given the stepper, when it changes the count, then nothing is announced and its spoken value is the setting then the headline")
    func stepperSpeaksInsteadOfAnnouncing() async throws {
        var announcements: [String] = []
        let viewModel = ChoosingAxisValuesViewModel(fallbackDelay: .zero, announce: { announcements.append($0) })
        viewModel.desiredCount = 5
        draw([0, 40, 80, 120, 160], for: .automatic(desiredCount: 5), on: viewModel)
        try await Task.sleep(for: .milliseconds(50))

        #expect(announcements.isEmpty)
        #expect(viewModel.stepperSpokenValue(locale: english)
            == "Asked for about 5 values; the axis drew 5, from 0 to 160.")
    }

    @Test("Given each mode chosen, when the chart reports, then the announcement starts with that mode's setting", arguments: [
        (ChoosingAxisValuesMode.stride, ChoosingAxisValuesChoice.stride(by: 50), [0.0, 50, 100, 150, 200],
         "Axis values: one every 50 cups. "),
        (.exact, .exact([0, 100, 200, 300]), [0.0, 100, 200, 300], "Axis values: exactly 0, 100, 200, and 300. "),
    ])
    func announcementsByMode(
        mode: ChoosingAxisValuesMode, choice: ChoosingAxisValuesChoice, drawn: [Double], prefix: String
    ) throws {
        var announcements: [String] = []
        let viewModel = ChoosingAxisValuesViewModel(announce: { announcements.append($0) })
        viewModel.mode = mode
        draw(drawn, for: choice, on: viewModel)

        let announcement = try #require(announcements.first)
        #expect(announcement.hasPrefix(prefix))
        #expect(announcement.hasSuffix(viewModel.headline(locale: english)))
    }

    @Test("Given no control change, when the chart first reports, then nothing is announced")
    func noAnnouncementOnOpen() {
        var announcements: [String] = []
        let viewModel = ChoosingAxisValuesViewModel(announce: { announcements.append($0) })
        draw([0, 50, 100, 150, 200], for: .automatic(desiredCount: 4), on: viewModel)

        #expect(announcements.isEmpty)
    }

    // MARK: Words

    @Test("Given counts of one and more, when written, then the noun agrees in number")
    func valueWords() {
        #expect(ChoosingAxisValuesWording.values(1, locale: english) == "1 value")
        #expect(ChoosingAxisValuesWording.values(5, locale: english) == "5 values")
        #expect(ChoosingAxisValuesWording.numbers([0, 1000], locale: english) == "0 and 1,000")
    }

    // MARK: Snippets

    @Test("Given each mode, when the snippets are asked for, then the chart, that mode's axis and the count reading are shown", arguments: [
        (ChoosingAxisValuesMode.automatic, "choosing-axis-values-automatic"),
        (.stride, "choosing-axis-values-stride"),
        (.exact, "choosing-axis-values-exact"),
    ])
    func snippetsByMode(mode: ChoosingAxisValuesMode, expected: String) {
        let viewModel = ChoosingAxisValuesViewModel()
        viewModel.mode = mode

        #expect(viewModel.snippets.map(\.name) == [
            "choosing-axis-values-chart", expected, "choosing-axis-values-drawn",
        ])
    }

    @Test("Given the built app, when its snippets are read, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ChoosingAxisValuesMode.allCases.flatMap { mode in
            let viewModel = ChoosingAxisValuesViewModel()
            viewModel.mode = mode
            return viewModel.snippets.map(\.name)
        }
        for name in Set(names) {
            #expect(store[name] != nil, "missing snippet \(name)")
        }
    }

    // MARK: Descriptor

    @Test("Given the drawn domain and values, when the descriptor is made, then its range, grid lines and summary match the chart")
    func descriptor() throws {
        let viewModel = ChoosingAxisValuesViewModel(announce: { _ in })
        viewModel.mode = .exact
        draw([0, 100, 200, 300], for: .exact([0, 100, 200, 300]), on: viewModel)
        viewModel.recordDomain([0, 300], for: .exact([0, 100, 200, 300]))

        let descriptor = ChoosingAxisValuesDescriptor(
            sales: viewModel.sales,
            range: viewModel.domain,
            gridlines: viewModel.drawnValues ?? [],
            summary: viewModel.audioGraphSummary(locale: english),
            locale: english
        ).makeChartDescriptor()

        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.gridlinePositions == [0, 100, 200, 300])
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(164) == "164 cups")
        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "5 drinks. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups. Axis values: 0, 100, 200, and 300.")
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 5)
    }
}
