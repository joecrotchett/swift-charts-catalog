import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing
import UIKit

@MainActor
struct ChartExportTests {
    let english = Locale(identifier: "en_US")

    @Test("Given the sample data, when the screen opens, then the latest week is in view")
    func opensOnLatestWeek() {
        let model = ChartExportViewModel()
        #expect(model.scrollStart == CafeData.day(21))
        #expect(model.daysInView.map(\.day) == (21 ... 27).map(CafeData.day))
    }

    @Test("Given the latest week, when the headline is read, then it names the week and its busiest day")
    func headlineForLatestWeek() {
        let model = ChartExportViewModel()
        #expect(model.headline(locale: english)
            == "March 22 to March 28 in view; the busiest, Saturday, March 28, sold 282 cups.")
    }

    @Test("Given a scroll to the second week, when the headline is read, then it follows the window")
    func headlineFollowsScroll() {
        let model = ChartExportViewModel()
        model.scrollStart = CafeData.day(7)
        #expect(model.daysInView.count == ChartExportViewModel.visibleDayCount)
        #expect(model.headline(locale: english).hasPrefix("March 8 to March 14 in view"))
    }

    @Test("Given the sample data, when the scrolling chart's scale is read, then it covers every day, whole")
    func fullDomainCoversEveryDay() {
        let model = ChartExportViewModel()
        #expect(model.fullDomain == CafeData.day(0) ... CafeData.day(28))
        #expect(model.fullDomain.contains(model.visibleWindow.lowerBound))
        #expect(model.fullDomain.contains(model.visibleWindow.upperBound))
    }

    @Test("Given the reserved headline, when it is read twice and in another locale, then it is the same text for the same locale")
    func reservedHeadlinePerLocale() {
        let model = ChartExportViewModel()
        let first = model.reservedHeadline(locale: english)
        #expect(model.reservedHeadline(locale: english) == first)
        let german = model.reservedHeadline(locale: Locale(identifier: "de_DE"))
        #expect(german != first)
        #expect(model.reservedHeadline(locale: english) == first)
    }

    @Test("Given a window resting off midnight, when the twin's domain is read, then it covers whole days")
    func twinDomainCoversWholeDays() throws {
        let model = ChartExportViewModel()
        let start = try #require(model.calendar.date(byAdding: .hour, value: 30, to: CafeData.day(10)))
        model.scrollStart = start
        #expect(model.daysInView.first?.day == CafeData.day(11))
        #expect(model.twinDomain == CafeData.day(11) ... CafeData.day(18))
    }

    @Test("Given two days tied for the most, when the headline is read, then both are named")
    func headlineNamesTies() {
        let days = [
            DailySales(day: CafeData.day(0), cups: 40),
            DailySales(day: CafeData.day(1), cups: 40),
        ]
        let model = ChartExportViewModel(days: days)
        #expect(model.headline(locale: english)
            == "March 1 to March 2 in view; the busiest, tied, Sunday, March 1 and Monday, March 2, sold 40 cups.")
    }

    @Test("Given only zeros, when the headline is read, then it says nothing sold")
    func headlineForZeros() {
        let model = ChartExportViewModel(days: [DailySales(day: CafeData.day(0), cups: 0)])
        #expect(model.busiestInView.isEmpty)
        #expect(model.headline(locale: english) == "March 1 to March 1 in view; no cups sold.")
    }

    @Test("Given no data, when the headline is read, then it says so")
    func headlineForNoData() {
        let model = ChartExportViewModel(days: [])
        #expect(!model.hasData)
        #expect(model.headline(locale: english) == "No days to show.")
    }

    @Test("Given the sample data, when the value axis is read, then it leaves room above 282 cups")
    func cupsAxis() {
        #expect(ChartExportViewModel().cupsAxis == 0 ... 350)
        #expect(ChartExportViewModel(days: []).cupsAxis == 0 ... 50)
    }

    @Test("Given every scroll position, when the reserved headline is read, then no headline is longer")
    func reservedHeadlineIsLongest() {
        let model = ChartExportViewModel()
        let reserved = model.reservedHeadline(locale: english)
        for day in model.days {
            model.scrollStart = day.day
            #expect(model.headline(locale: english).count <= reserved.count)
        }
    }

    @Test("Given a bar, when its words are read, then the day comes first and the cups agree in number")
    func barWords() {
        let model = ChartExportViewModel()
        let day = DailySales(day: CafeData.day(0), cups: 1)
        #expect(model.barLabel(day, locale: english) == "Sunday, March 1")
        #expect(model.barValue(day, locale: english) == "1 cup")
        let words = model.barWords(locale: english)
        #expect(words.label(day) == "Sunday, March 1")
        #expect(words.calendar == CafeData.calendar)
    }

    @Test("Given results out of order, when the export finishes, then they are kept in route order")
    func resultsInRouteOrder() {
        let model = ChartExportViewModel()
        model.beginExport()
        #expect(model.isExporting)
        let image = UIImage()
        model.finishExport([
            ChartExportResult(route: .flatTwin3D, outcome: .image(image)),
            ChartExportResult(route: .scrollingChart, outcome: .image(image)),
            ChartExportResult(route: .chart3DWindow, outcome: .unavailable("Needs iOS 26.")),
        ])
        #expect(!model.isExporting)
        #expect(model.results.map(\.route) == [.scrollingChart, .chart3DWindow, .flatTwin3D])
        #expect(model.exportAnnouncement(locale: english) == "Export finished: 2 images below.")
        #expect(model.result(for: .chart3DWindow)?.imageDescription == "Needs iOS 26.")
    }

    @Test("Given each route, when its result is described, then it says what the route was seen to make")
    func routeWords() {
        #expect(ChartExportRoute.allCases.count == 5)
        #expect(ChartExportRoute.allCases.filter(\.needsChart3D) == [.chart3DRenderer, .chart3DWindow])
        #expect(ChartExportRoute.allCases.filter(\.givesTheChart) == [.staticTwin, .chart3DWindow, .flatTwin3D])
        let result = ChartExportResult(route: .chart3DRenderer, outcome: .image(UIImage()))
        #expect(result.imageDescription == "Exported image. \(ChartExportSeen.chart3DRenderer)")
        #expect(ChartExportResult(route: .staticTwin, outcome: .failed).imageDescription == "No image was made.")
    }

    @Test("Given the snippets the screen lists, when the store is read, then each exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        #expect(ChartExportViewModel.snippets.count == 6)
        for snippet in ChartExportViewModel.snippets {
            #expect(store[snippet.name] != nil, "\(snippet.name)")
        }
    }

    @Test("Given the four weeks, when the descriptor is made, then it names every day with cups as the unit")
    func descriptor() throws {
        let model = ChartExportViewModel()
        let descriptor = ChartExportChartDescriptor(
            days: model.days, calendar: model.calendar, cupsAxis: model.cupsAxis, locale: english
        ).makeChartDescriptor()
        #expect(descriptor.title == "Cups a day at the Harbour café")
        #expect(descriptor.summary == "28 days, March 1 to March 28. Fewest: 152 cups on March 3. Most: 282 cups on March 28.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.count == 28)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 350)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.first?.name == CafeWording.harbour)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 28)
    }
}
