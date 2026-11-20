import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct LowerBoundTests {
    private let english = Locale(identifier: "en_US")

    // MARK: Domains

    @Test("Given the sample data, when the screen opens, then both axes start at zero and nothing is marked a mistake")
    func startsFromZero() {
        let model = LowerBoundViewModel()
        #expect(model.leavesOutZero == false)
        #expect(model.lineDomain == 0 ... 13.5)
        #expect(model.barDomain == 0 ... 170)
        #expect(model.isShowingMistake == false)
    }

    @Test("Given the toggle on, when the domains are read, then only the lower bounds move and the bars are the mistake")
    func toggleMovesLowerBounds() {
        let model = LowerBoundViewModel()
        model.leavesOutZero = true
        #expect(model.lineDomain == 10.5 ... 13.5)
        #expect(model.barDomain == 50 ... 170)
        #expect(model.isShowingMistake)
    }

    @Test("Given the fewest cups on a multiple of ten, when zero is left out, then the bottom stays below that bar")
    func fittedBarsKeepShortestBarDrawn() {
        #expect(LowerBoundDomains.fittedBars([60, 120]) == 50 ... 120)
        #expect(LowerBoundDomains.fittedBars([5, 40]) == 0 ... 40)
    }

    @Test("Given no data, when the domains are read, then they still have a top above zero")
    func emptyDomains() {
        #expect(LowerBoundDomains.zeroBars([]) == 0 ... 10)
        #expect(LowerBoundDomains.fittedBars([]) == 0 ... 10)
        #expect(LowerBoundDomains.fittedLine([]) == LowerBoundDomains.zeroLine([]))
    }

    // MARK: Ratios

    @Test("Given each setting, when the bars are measured, then from zero they keep the cups' ratio and without it they do not")
    func heightRatios() throws {
        let model = LowerBoundViewModel()
        let cups = try #require(model.cupsRatio)
        #expect(abs(cups - 164.0 / 57.0) < 0.0001)
        #expect(try abs(#require(model.heightRatio) - cups) < 0.0001)
        model.leavesOutZero = true
        #expect(try abs(#require(model.heightRatio) - 114.0 / 7.0) < 0.0001)
    }

    // MARK: Headline

    @Test("Given prices low in their plot or spread over it, when the fill is put in words, then the words say where the band is")
    func lineFillWords() {
        func model(_ closes: [Double]) -> LowerBoundViewModel {
            LowerBoundViewModel(prices: closes.enumerated().map { index, close in
                WeeklyPrice(week: CafeData.day(index * 7), open: close, high: close, low: close, close: close)
            })
        }
        #expect(model([0.5, 0.6]).lineFillWords == "is a thin band in its plot")
        #expect(model([1, 2]).lineFillWords == "fills less than half of its plot")
        #expect(LowerBoundViewModel().lineFillWords == "is a thin band at the top of its plot")
    }

    @Test("Given the axes from zero, when the headline is written, then it gives the price range, the fill and the true ratio")
    func headlineFromZero() {
        let model = LowerBoundViewModel()
        #expect(model.headline(locale: english) == "From zero, the bean price's range, $11.00 to $13.00, is a thin band at the top of its plot. "
            + "Tea's bar (164 cups) stands 2.9 times as tall as cocoa's (57), in proportion to the cups.")
    }

    @Test("Given zero left out, when the headline is written, then it gives the fuller line and the misstated bars")
    func headlineWithoutZero() {
        let model = LowerBoundViewModel()
        model.leavesOutZero = true
        #expect(model.headline(locale: english) == "Without zero, the bean price's range, $11.00 to $13.00, fills most of its plot. "
            + "But tea's bar (164 cups) stands 16.3 times as tall as cocoa's (57), for 2.9 times the cups.")
    }

    @Test("Given no prices and no cups, when the headline is written, then it says so in either setting and the toggle is off")
    func headlineWithNoData() {
        let model = LowerBoundViewModel(prices: [], sales: [])
        #expect(model.headline(locale: english) == "No bean prices recorded. No cups sold yet.")
        model.leavesOutZero = true
        #expect(model.headline(locale: english) == "No bean prices recorded. No cups sold yet.")
        #expect(model.isShowingMistake == false)
        #expect(model.isToggleEnabled == false)
    }

    @Test("Given only zeros sold, when the bars are checked, then none are drawn and the headline says no cups")
    func allZeroCups() {
        let model = LowerBoundViewModel(sales: [DrinkSales(drink: "Tea", cups: 0), DrinkSales(drink: "Latte", cups: 0)])
        #expect(model.drawsBars == false)
        #expect(model.headline(locale: english).hasSuffix("No cups sold yet."))
        #expect(model.isToggleEnabled)
    }

    @Test("Given one drink sold and one at zero, when the headline is written, then it names no bar of zero")
    func oneBarDrawn() {
        let model = LowerBoundViewModel(sales: [DrinkSales(drink: "Tea", cups: 12), DrinkSales(drink: "Latte", cups: 0)])
        #expect(model.headline(locale: english).hasSuffix("Every bar stands at 12 cups."))
    }

    @Test("Given one price every week, when the headline is written, then it says the price held")
    func flatPrice() {
        let flat = [WeeklyPrice(week: CafeData.day(0), open: 12, high: 12, low: 12, close: 12)]
        let model = LowerBoundViewModel(prices: flat)
        #expect(model.headline(locale: english).hasPrefix("From zero, the bean price holds at $12.00 every week."))
    }

    @Test("Given a German locale, when the headline is written, then numbers follow the locale")
    func headlineLocale() {
        let model = LowerBoundViewModel()
        model.leavesOutZero = true
        let headline = model.headline(locale: Locale(identifier: "de_DE"))
        #expect(headline.contains("16,3 times"))
        #expect(headline.contains("11,00"))
    }

    // MARK: Announcement

    @Test("Given the toggle flips, when the announcement is written, then it says what changed and then the headline")
    func announcements() {
        let model = LowerBoundViewModel()
        model.leavesOutZero = true
        #expect(model.announcement(locale: english) == "\(LowerBoundWords.zeroLeftOut) \(model.headline(locale: english))")
        model.leavesOutZero = false
        #expect(model.announcement(locale: english) == "\(LowerBoundWords.zeroRestored) \(model.headline(locale: english))")
    }

    // MARK: Snippets

    @Test("Given each setting, when the snippets are listed, then the domains shown are the ones in effect")
    func snippetsFollowToggle() {
        let model = LowerBoundViewModel()
        #expect(model.snippets.map(\.name) == [
            "axes-the-lower-bound-line", "axes-the-lower-bound-bars", "axes-the-lower-bound-zero-domains",
        ])
        model.leavesOutZero = true
        #expect(model.snippets.map(\.name) == [
            "axes-the-lower-bound-line", "axes-the-lower-bound-bars", "axes-the-lower-bound-fitted-domains",
        ])
    }

    @Test("Given the built app, when its snippets are read, then every snippet this screen lists exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ["axes-the-lower-bound-line", "axes-the-lower-bound-bars", "axes-the-lower-bound-zero-domains",
                     "axes-the-lower-bound-fitted-domains"]
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Descriptors

    @Test("Given each setting, when the line's descriptor is made, then its axis matches the drawn domain and values have the unit")
    func lineDescriptor() throws {
        let model = LowerBoundViewModel()
        model.leavesOutZero = true
        let descriptor = LowerBoundLineDescriptor(prices: model.prices, domain: model.lineDomain, locale: english)
            .makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 10.5 ... 13.5)
        #expect(yAxis.valueDescriptionProvider(11) == "$11.00 per kilogram")
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 12)
        #expect(descriptor.summary?.contains("Lowest $11.00 per kilogram, week of March 15.") == true)
        #expect(descriptor.summary?.contains("Highest $13.00 per kilogram, week of May 3.") == true)
        #expect(descriptor.summary?.hasSuffix("The value axis runs from $10.50 per kilogram to $13.50 per kilogram.") == true)
    }

    @Test("Given zero left off the bars, when their descriptor is made, then the summary says the axis starts above zero")
    func barsDescriptor() throws {
        let model = LowerBoundViewModel()
        let fromZero = LowerBoundBarsDescriptor(sales: model.sales, domain: model.barDomain, locale: english).makeChartDescriptor()
        #expect(fromZero.summary?.hasSuffix("The value axis runs from zero to 170 cups.") == true)
        model.leavesOutZero = true
        let cut = LowerBoundBarsDescriptor(sales: model.sales, domain: model.barDomain, locale: english).makeChartDescriptor()
        let yAxis = try #require(cut.yAxis)
        #expect(yAxis.range == 50 ... 170)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(cut.summary?.contains("starts at 50 cups, not zero") == true)
        #expect(cut.series.first?.isContinuous == false)
    }

    @Test("Given a date at midnight UTC, when its week is named, then it is the UTC day")
    func weekNameInUTC() {
        #expect(LowerBoundWords.weekName(CafeData.day(14), locale: english) == "Week of March 15")
    }
}
