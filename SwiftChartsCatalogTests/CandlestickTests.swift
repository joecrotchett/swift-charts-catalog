import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct CandlestickTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    private func week(_ index: Int) -> Date {
        CafeData.calendar.date(byAdding: .day, value: index * 7, to: CafeData.firstDay) ?? CafeData.firstDay
    }

    /// One week that rose, one that fell and one that closed where it opened.
    private var threeWeeks: [WeeklyPrice] {
        [
            WeeklyPrice(week: week(0), open: 11.2, high: 11.9, low: 11.0, close: 11.7),
            WeeklyPrice(week: week(1), open: 11.7, high: 12.1, low: 11.5, close: 11.6),
            WeeklyPrice(week: week(2), open: 11.6, high: 11.8, low: 10.9, close: 11.6),
        ]
    }

    // MARK: Direction

    @Test("Given a week's open and close, when its direction is worked out, then it rose, fell or stayed level")
    func directionFollowsOpenAndClose() {
        #expect(threeWeeks.map(CandlestickDirection.init) == [.rose, .fell, .unchanged])
    }

    @Test("Given the three directions, when their symbols are read, then each has its own")
    func directionsHaveDistinctSymbols() {
        #expect(Set(CandlestickDirection.allCases.map(\.symbolName)).count == CandlestickDirection.allCases.count)
    }

    // MARK: Headline

    @Test("Given the café's sample prices, when the headline is written, then it counts the weeks that closed higher")
    func headlineCountsRisingWeeks() {
        let summary = CandlestickSummary(prices: CafeData.weeklyPrices, locale: english)

        #expect(summary.count(of: .rose) == 7)
        #expect(summary.count(of: .fell) == 5)
        #expect(summary.headline == "The bean price closed higher in 7 of 12 weeks.")
    }

    @Test("Given a single week, when the headline is written, then the noun agrees with the number")
    func headlineAgreesInNumber() {
        let summary = CandlestickSummary(prices: [threeWeeks[0]], locale: english)

        #expect(summary.headline == "The bean price closed higher in 1 of 1 week.")
    }

    @Test("Given no prices, when the chart's words are written, then they say there are none")
    func emptyPricesSaySo() {
        let summary = CandlestickSummary(prices: [], locale: english)

        #expect(summary.isEmpty)
        #expect(summary.priceRange == nil)
        #expect(summary.headline == "No bean prices recorded yet.")
        #expect(summary.audioGraphSummary == "No bean prices recorded yet.")
    }

    @Test("Given weeks whose prices are all zero, when the chart's words are written, then they say there are no prices")
    func allZeroPricesSaySo() {
        let zeros = (0 ..< 3).map { WeeklyPrice(week: week($0), open: 0, high: 0, low: 0, close: 0) }
        let summary = CandlestickSummary(prices: zeros, locale: english)

        #expect(summary.isEmpty)
        #expect(summary.headline == "No bean prices recorded yet.")
        #expect(summary.audioGraphSummary == "No bean prices recorded yet.")
    }

    // MARK: Element text

    @Test("Given a week, when its candle is labelled, then the label names the week's first day in the data's time zone")
    func labelNamesTheWeek() {
        let summary = CandlestickSummary(prices: threeWeeks, locale: english)

        #expect(summary.label(for: threeWeeks[0]) == "Week of March 1")
        #expect(summary.label(for: threeWeeks[1]) == "Week of March 8")
    }

    @Test("Given a week, when its candle's value is written, then it gives the direction and the four prices with their currency and unit")
    func valueGivesDirectionAndPrices() {
        let summary = CandlestickSummary(prices: threeWeeks, locale: english)

        #expect(summary.value(for: threeWeeks[0]) == "Closed higher. Prices per kilogram: open $11.20, close $11.70, low $11.00, high $11.90.")
        #expect(summary.value(for: threeWeeks[1]).hasPrefix("Closed lower. "))
        #expect(summary.value(for: threeWeeks[2]).hasPrefix("Closed level. "))
        #expect(threeWeeks.allSatisfy { summary.value(for: $0).components(separatedBy: "per kilogram").count == 2 })
    }

    @Test("Given a German locale, when a price and a day are written, then both follow that locale")
    func textFollowsTheLocale() {
        let summary = CandlestickSummary(prices: threeWeeks, locale: german)

        #expect(summary.priceText(11.2).contains("11,20"))
        #expect(summary.dayText(week(0)) == "1. März")
    }

    // MARK: Audio Graph

    @Test("Given three weeks, when the Audio Graph summary is written, then it gives the counts and prices in actual values, with the unit once")
    func summaryGivesActualValues() {
        let summary = CandlestickSummary(prices: threeWeeks, locale: english)

        #expect(
            summary.audioGraphSummary
                == "3 weeks. Closed higher in 1, lower in 1, level in 1. "
                + "Prices per kilogram: first open $11.20, last close $11.60, lowest $10.90, highest $12.10."
        )
    }

    @Test("Given three weeks, when the chart descriptor is made, then it has a title, the summary and four named series of separate values")
    func descriptorDescribesTheChart() {
        let summary = CandlestickSummary(prices: threeWeeks, locale: english)
        let descriptor = CandlestickChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Wholesale bean price by week")
        #expect(descriptor.title == CandlestickSummary.chartTitle)
        #expect(descriptor.summary == summary.audioGraphSummary)
        #expect(descriptor.series.map(\.name) == ["Open", "Close", "Low", "High"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 3 })
    }

    @Test("Given three weeks, when the descriptor's axes are read, then the weeks are written out and the price range is the drawn one, said in dollars per kilogram")
    func descriptorAxesMatchTheChart() throws {
        let descriptor = CandlestickChartDescriptor(
            summary: CandlestickSummary(prices: threeWeeks, locale: english)
        ).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == CafeWording.week)
        #expect(xAxis.categoryOrder == ["March 1", "March 8", "March 15"])
        #expect(yAxis.title == CafeWording.priceAxisTitle)
        // $10.90 to $12.10, rounded out to the drawn axis's step of $0.50.
        #expect(yAxis.range == 10.5 ... 12.5)
        #expect(yAxis.valueDescriptionProvider(11.5) == "$11.50 per kilogram")
    }

    @Test("Given no prices, when the chart descriptor is made, then it has no series and its summary says so")
    func emptyDescriptorHasNoSeries() {
        let descriptor = CandlestickChartDescriptor(
            summary: CandlestickSummary(prices: [], locale: english)
        ).makeChartDescriptor()

        #expect(descriptor.series.isEmpty)
        #expect(descriptor.summary == "No bean prices recorded yet.")
    }

    // MARK: View model

    @Test("Given a new view model, when it is read, then it shows the sample prices with the colour left to the caller")
    func startsWithoutTheMistake() {
        let viewModel = CandlestickViewModel()

        #expect(viewModel.prices == CafeData.weeklyPrices)
        #expect(!viewModel.setsColourInside)
        #expect(viewModel.snippets.map(\.name) == ["candlestick-mark", "candlestick-call", "candlestick-chart"])
        #expect(viewModel.explanation.contains("sets no colour"))
    }

    @Test("Given the mistake is switched on, when the snippets and explanation are read, then they show the mark that colours itself")
    func mistakeShowsTheSelfColouredMark() {
        let viewModel = CandlestickViewModel()
        viewModel.setsColourInside = true

        #expect(
            viewModel.snippets.map(\.name)
                == ["candlestick-mark-mistake", "candlestick-call-mistake", "candlestick-chart"]
        )
        #expect(viewModel.explanation.contains("every candle is grey"))
        #expect(viewModel.explanation.contains("The legend either disappears or stays to name colours no candle has"))
        #expect(!viewModel.explanation.contains("the legend is gone"))
    }

    @Test("Given either setting, when the headline is written, then it is the same, because the data and its symbols are")
    func headlineHoldsInBothStates() {
        let viewModel = CandlestickViewModel()
        let before = viewModel.summary(locale: english).headline
        viewModel.setsColourInside = true

        #expect(viewModel.summary(locale: english).headline == before)
    }

    @Test("Given the toggle changes, when the announcement is written, then it says what changed and then the headline")
    func announcementSaysWhatChanged() {
        let viewModel = CandlestickViewModel()
        let headline = viewModel.summary(locale: english).headline

        viewModel.setsColourInside = true
        #expect(
            viewModel.announcement(locale: english)
                == "Every candle is now drawn in one grey, set inside the mark. \(headline)"
        )

        viewModel.setsColourInside = false
        #expect(
            viewModel.announcement(locale: english)
                == "Each candle is now coloured by whether the week closed higher or lower. \(headline)"
        )
    }

    @Test("Given the built app, when each state's snippets are looked up, then every one was extracted from this screen's source")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        let viewModel = CandlestickViewModel()
        var names = viewModel.snippets.map(\.name)
        viewModel.setsColourInside = true
        names += viewModel.snippets.map(\.name)

        for name in names {
            let snippet = try #require(store[name])
            #expect(snippet.file == "Marks/CandlestickScreen.swift")
        }
        #expect(try #require(store["candlestick-mark-mistake"]).code.contains(".foregroundStyle(Color.gray)"))
        // The type styles only its clear ordering band; the wick and body take the caller's colour.
        let markCode = try #require(store["candlestick-mark"]).code
        #expect(markCode.replacingOccurrences(of: ".foregroundStyle(.clear)", with: "").contains(".foregroundStyle(") == false)
        #expect(try #require(store["candlestick-chart"]).code.contains(".foregroundStyle(by:"))
    }

    @Test("Given the sample prices, when the price axis is worked out, then it is $10 to $14, the drawn axis around $10.80 to $13.20")
    func samplePriceDomain() {
        let summary = CandlestickSummary(prices: CafeData.weeklyPrices, locale: Locale(identifier: "en_US"), calendar: CafeData.calendar)
        #expect(summary.priceDomain == 10 ... 14)
    }
}
