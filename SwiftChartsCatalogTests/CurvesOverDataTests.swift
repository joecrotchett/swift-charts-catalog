import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct CurvesOverDataTests {
    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    // MARK: Histogram

    @Test("Given 2,000 orders, when they are binned, then ten one-minute bins count every order")
    func waitsBinned() {
        let model = CurvesOverDataViewModel()

        #expect(model.bins.count == 10)
        #expect(model.bins.map(\.orders) == [10, 68, 237, 411, 513, 382, 241, 105, 29, 4])
        #expect(model.bins.map(\.orders).reduce(0, +) == 2000)
        #expect(model.histogramXDomain == 0 ... 10)
        #expect(model.histogramYDomain == 0 ... 560)
    }

    @Test("Given the waits, when the normal curve is fitted, then it gives orders per bin, the bars' own unit")
    func normalFit() throws {
        let fit = try #require(CurvesOverDataViewModel().normalFit)

        #expect(abs(fit.mean - 4.604) < 0.001)
        #expect(abs(fit.deviation - 1.549) < 0.001)
        #expect(fit.scale == 2000)
        #expect(abs(fit.peakOrders - 515.1) < 0.1)
        #expect(fit.expectedOrders(atWait: fit.mean + 1) < fit.peakOrders)
    }

    @Test("Given each layer, when a bin's spoken value is written, then it gives the drawn layers' orders there")
    func binValues() throws {
        let model = CurvesOverDataViewModel()
        let tallest = try #require(model.bins.first { $0.orders == 513 })

        #expect(model.binLabel(tallest, locale: english) == "4 to 5 minutes")
        #expect(model.binValue(tallest, locale: english) == "513 orders; fitted curve 514 orders")
        model.setShowing(.curve, false)
        #expect(model.binValue(tallest, locale: english) == "513 orders")
        model.setShowing(.curve, true)
        model.setShowing(.bars, false)
        #expect(model.binValue(tallest, locale: english) == "fitted curve 514 orders")
    }

    @Test("Given both layers, when the headline is written, then it names the tallest bin and the curve's peak")
    func histogramHeadline() {
        let model = CurvesOverDataViewModel()

        #expect(model.headline(locale: english)
            == "The most common wait was 4 to 5 minutes: 513 of 2,000 orders. The fitted curve peaks at 4.6 minutes.")
        #expect(model.caption(locale: english) == "Waits for 2,000 orders")
    }

    @Test("Given the histogram, when each layer is switched off in turn, then the headline speaks only of what is drawn")
    func histogramLayers() {
        let model = CurvesOverDataViewModel()

        model.setShowing(.curve, false)
        #expect(model.drawsBars && !model.drawsCurve)
        #expect(model.headline(locale: english) == "The most common wait was 4 to 5 minutes: 513 of 2,000 orders.")
        #expect(model.layerAnnouncement(for: .curve, locale: english)
            == "Fitted curve hidden. The most common wait was 4 to 5 minutes: 513 of 2,000 orders.")

        model.setShowing(.curve, true)
        model.setShowing(.bars, false)
        #expect(model.headline(locale: english) == "The fitted normal curve peaks at a wait of 4.6 minutes.")
        #expect(model.placeholder == nil)

        model.setShowing(.curve, false)
        #expect(model.headline(locale: english) == "Every layer is off: turn one on to draw it.")
        #expect(model.placeholder?.title == "Nothing drawn")
    }

    @Test("Given a German locale, when the headline is written, then its numbers are written the German way")
    func germanNumbers() {
        let model = CurvesOverDataViewModel()

        #expect(model.headline(locale: german).contains("513 of 2.000 orders"))
        #expect(model.headline(locale: german).contains("4,6 minutes"))
    }

    @Test("Given both layers, when the histogram's descriptor is made, then it has the bars and the curve as two series")
    func histogramDescriptor() throws {
        let model = CurvesOverDataViewModel()
        let descriptor = model.histogramDescriptor(locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Waits for 2,000 orders, in minutes")
        #expect(descriptor.summary == "2,000 orders in 10 bins, from 0 to 10 minutes. Tallest: 4 to 5 minutes, 513 orders. "
            + "Fitted normal curve: mean 4.6 minutes, standard deviation 1.5 minutes.")
        #expect(descriptor.series.map(\.name) == ["Orders", "Fitted curve"])
        #expect(descriptor.series.map(\.isContinuous) == [false, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [10, 10])
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "0 to 1 minute")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 560)
        #expect(yAxis.valueDescriptionProvider(1) == "1 order")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given the bars switched off, when the descriptor is made, then only the curve is a series")
    func histogramDescriptorFollowsLayers() {
        let model = CurvesOverDataViewModel()
        model.setShowing(.bars, false)
        let descriptor = model.histogramDescriptor(locale: english).makeChartDescriptor()

        #expect(descriptor.series.map(\.name) == ["Fitted curve"])
        #expect(!(descriptor.summary ?? "").contains("Tallest"))
    }

    @Test("Given every order with the same wait, when it is binned, then one bin is drawn and no curve is fitted")
    func singleWait() {
        let orders = (0 ..< 5).map { CafeOrder(id: $0, drink: "Tea", hour: 9, cups: 1, waitMinutes: 3) }
        let model = CurvesOverDataViewModel(orders: orders, waits: [])

        #expect(model.bins.map(\.orders) == [5])
        #expect(model.normalFit == nil)
        #expect(!model.drawsCurve)
        model.setShowing(.bars, false)
        #expect(model.headline(locale: english) == "Every order waited the same time, so there is no curve to fit.")
        #expect(model.placeholder?.title == "Nothing drawn")
    }

    // MARK: Trend

    @Test("Given the Harbour café's orders, when the line is fitted, then it rises about 14 seconds per person")
    func lineFit() throws {
        let model = CurvesOverDataViewModel()
        let fit = try #require(model.lineFit)

        #expect(model.waits.count == 20)
        #expect(abs(fit.slope - 13.68) < 0.01)
        #expect(abs(fit.intercept - 62.94) < 0.01)
        #expect(fit.margin(at: fit.meanX) < fit.margin(at: 11))
        #expect(model.queueRange == 1 ... 11)
        #expect(model.trendXDomain == 0.5 ... 11.5)
        #expect(model.trendYDomain == 0 ... 270)
    }

    @Test("Given every trend layer, when the headline is written, then it gives the trend's ends and the band's width")
    func trendHeadline() {
        let model = CurvesOverDataViewModel()
        model.kind = .trend

        #expect(model.headline(locale: english) == "The trend runs from 77 seconds at 1 person queuing to 213 seconds at "
            + "11 people queuing. The band reaches 27 seconds either side of it at its narrowest.")
        #expect(model.kindAnnouncement(locale: english).hasPrefix("Scatter with a trend line. The trend runs"))
        #expect(model.caption(locale: english) == "Harbour café: wait against queue")
    }

    @Test("Given the trend chart, when layers are switched off, then the headline falls back to what is still drawn")
    func trendLayers() {
        let model = CurvesOverDataViewModel()
        model.kind = .trend

        model.setShowing(.trend, false)
        #expect(model.headline(locale: english) == "The band runs from 49 to 105 seconds at 1 person queuing, "
            + "and from 185 to 242 seconds at 11 people queuing.")
        model.setShowing(.band, false)
        #expect(model.headline(locale: english) == "20 orders waited 59 to 214 seconds, with 1 to 11 people queuing.")
        model.setShowing(.points, false)
        #expect(model.placeholder?.title == "Nothing drawn")
        #expect(model.headline(locale: english) == "Every layer is off: turn one on to draw it.")
    }

    @Test("Given 20 points, when the band's multiplier is chosen, then it is t for 18 degrees of freedom, not 1.96")
    func tMultiplier() {
        #expect(CurvesOverDataLineFit.t95(degreesOfFreedom: 18) == 2.101)
        #expect(CurvesOverDataLineFit.t95(degreesOfFreedom: 1) == 12.706)
        #expect(CurvesOverDataLineFit.t95(degreesOfFreedom: 50) == 2.021)
        #expect(CurvesOverDataLineFit.t95(degreesOfFreedom: 500) == 1.96)
        #expect(CurvesOverDataLineFit.t95(degreesOfFreedom: 0).isNaN)
    }

    @Test("Given the trend chart, when its stretches are made, then each queue length with orders says the drawn layers' values")
    func trendPortions() throws {
        let model = CurvesOverDataViewModel()
        model.kind = .trend
        let portions = model.queuePortions

        #expect(portions.map(\.queue) == [1, 3, 5, 7, 9, 11])
        #expect(portions.map(\.start) == [0.5, 2, 4, 6, 8, 10])
        #expect(portions.map(\.end) == [2, 4, 6, 8, 10, 11.5])
        let first = try #require(portions.first)
        #expect(model.portionLabel(first, locale: english) == "1 person queuing")
        #expect(model.portionValue(first, locale: english)
            == "3 orders, waits 59 to 93 seconds; trend 77 seconds; band 49 to 105 seconds")

        model.setShowing(.band, false)
        model.setShowing(.trend, false)
        #expect(model.portionValue(first, locale: english) == "3 orders, waits 59 to 93 seconds")
    }

    @Test("Given every trend layer, when the descriptor is made, then points, trend and both band edges are series")
    func trendDescriptor() throws {
        let model = CurvesOverDataViewModel()
        model.kind = .trend
        let descriptor = model.trendDescriptor(locale: english).makeChartDescriptor()

        #expect(descriptor.title == "Wait against people queuing at the Harbour café")
        #expect((descriptor.summary ?? "").hasPrefix("20 orders, 1 to 11 people queuing, waits 59 to 214 seconds."))
        #expect((descriptor.summary ?? "").hasSuffix("Band: where about 95 in 100 waits are expected, "
                + "27 seconds either side of the trend at its narrowest."))
        #expect(descriptor.series.map(\.name) == ["Orders", "Trend", "Band low", "Band high"])
        #expect(descriptor.series.map(\.isContinuous) == [false, true, true, true])
        #expect(descriptor.series.map(\.dataPoints.count) == [20, 11, 11, 11])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 270)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.range == 0.5 ... 11.5)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person queuing")
    }

    @Test("Given no orders, when either chart is shown, then a placeholder replaces it and the headline says so")
    func noOrders() {
        let model = CurvesOverDataViewModel(orders: [], waits: [])

        #expect(model.headline(locale: english) == "No orders to chart.")
        #expect(model.placeholder?.title == "No orders")
        #expect(!model.hasData)
        model.kind = .trend
        #expect(model.headline(locale: english) == "No orders to chart.")
        #expect(model.placeholder?.title == "No orders")
        #expect(model.trendSummary(locale: english) == "No orders to chart.")
    }

    // MARK: Snippets

    @Test("Given each chart, when its snippets are listed, then the build extracted every one of them")
    func snippets() throws {
        let store = try SnippetStore()
        let model = CurvesOverDataViewModel()

        #expect(model.snippets.map(\.name) == ["curves-over-data-histogram", "curves-over-data-normal-fit"])
        for name in model.snippets.map(\.name) {
            #expect(store[name] != nil)
        }
        model.kind = .trend
        #expect(model.snippets.map(\.name) == ["curves-over-data-trend", "curves-over-data-line-fit"])
        for name in model.snippets.map(\.name) {
            #expect(store[name] != nil)
        }
    }

    @Test("Given orders whose longest wait sits on the last boundary, when they are binned, then it is counted in the last bin")
    func topValueCountedInLastBin() throws {
        let waits: [Double] = [0, 1, 2.5, 4, 6, 8, 10]
        let orders = waits.enumerated().map { CafeOrder(id: $0.offset, drink: "Latte", hour: 8, cups: 1, waitMinutes: $0.element) }
        let model = CurvesOverDataViewModel(orders: orders)

        #expect(model.bins.map(\.orders).reduce(0, +) == orders.count)
        let last = try #require(model.bins.last)
        #expect(last.range.upperBound == 10)
        #expect(last.orders >= 1)
    }
}
