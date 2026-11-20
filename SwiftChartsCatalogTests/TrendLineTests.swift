import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct TrendLineTests {
    let locale = Locale(identifier: "en_US")

    /// Orders exactly on wait = 10 + 2 × queue, at queues 1 to 5, at the Harbour.
    private var exactOrders: [OrderWait] {
        (1 ... 5).map { OrderWait(id: $0, store: CafeWording.harbour, queueLength: $0, waitSeconds: 10 + 2 * $0) }
    }

    @Test("Given orders on a straight line, when fitted, then the intercept, slope and range are the line's")
    func fitExact() throws {
        let fit = try #require(TrendLineFit.fitted(to: exactOrders, store: CafeWording.harbour))
        #expect(abs(fit.intercept - 10) < 1e-9)
        #expect(abs(fit.slope - 2) < 1e-9)
        #expect(fit.queueRange == 1 ... 5)
        #expect(abs(fit.wait(atQueue: 3) - 16) < 1e-9)
    }

    @Test("Given orders at only one queue length, when fitted, then there is no line")
    func fitNeedsTwoQueues() {
        let orders = [
            OrderWait(id: 0, store: CafeWording.harbour, queueLength: 4, waitSeconds: 90),
            OrderWait(id: 1, store: CafeWording.harbour, queueLength: 4, waitSeconds: 110),
        ]
        #expect(TrendLineFit.fitted(to: orders, store: CafeWording.harbour) == nil)
        #expect(TrendLineFit.fitted(to: orders, store: CafeWording.station) == nil)
    }

    @Test("Given the sample orders, when fitted, then each café has a line over its own queues")
    func sampleFits() {
        let model = TrendLineViewModel().chartModel(locale: locale)
        #expect(model.fits.map(\.store) == [CafeWording.harbour, CafeWording.station])
        #expect(model.fits.map(\.queueRange) == [1 ... 11, 0 ... 10])
        #expect(model.fits.allSatisfy { $0.slope > 0 })
    }

    @Test("Given the sample orders, when the scales are made, then x reaches past the data and y holds every line end")
    func scales() {
        let model = TrendLineViewModel().chartModel(locale: locale)
        #expect(model.xDomain == 0 ... 15)
        let longest = Double(CafeData.orderWaits.map(\.queueLength).max() ?? 0)
        #expect(model.xDomain.upperBound > longest)
        for fit in model.fits {
            #expect(model.yDomain.contains(fit.wait(atQueue: model.xDomain.upperBound)))
            #expect(model.yDomain.contains(fit.wait(atQueue: model.xDomain.lowerBound)))
        }
        #expect(CafeData.orderWaits.allSatisfy { model.yDomain.contains(Double($0.waitSeconds)) })
    }

    @Test("Given the default state, when drawn, then each line spans its café's queues")
    func drawnWithDomain() {
        let viewModel = TrendLineViewModel()
        let model = viewModel.chartModel(locale: locale)
        #expect(model.limitsToData)
        #expect(model.fits.map { model.drawnRange(of: $0) } == [1 ... 11, 0 ... 10])
    }

    @Test("Given domain: left out, when drawn, then every line spans the whole x scale")
    func drawnWithoutDomain() {
        let viewModel = TrendLineViewModel()
        viewModel.isLeavingOutDomain = true
        let model = viewModel.chartModel(locale: locale)
        #expect(!model.limitsToData)
        #expect(model.fits.allSatisfy { model.drawnRange(of: $0) == model.xDomain })
    }

    @Test("Given each setting, when the snippets are listed, then they show the line as drawn")
    func snippetNames() {
        let viewModel = TrendLineViewModel()
        #expect(viewModel.snippets.map(\.name) == [
            "trend-line-fit", "trend-line-points", "trend-line-with-domain", "trend-line-scale",
        ])
        viewModel.isLeavingOutDomain = true
        #expect(viewModel.snippets.map(\.name) == [
            "trend-line-fit", "trend-line-points", "trend-line-without-domain", "trend-line-scale",
        ])
    }

    @Test("Given the built app, when its snippets are read, then every one this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ["trend-line-fit", "trend-line-points", "trend-line-with-domain", "trend-line-without-domain", "trend-line-scale"]
        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given each setting, when the headline is written, then it names what is drawn")
    func headlines() {
        let viewModel = TrendLineViewModel()
        #expect(viewModel.chartModel(locale: locale).headline
            == "Each trend line stops where its café's orders do: Harbour 1 to 11 people and Station 0 to 10 people.")
        viewModel.isLeavingOutDomain = true
        #expect(viewModel.chartModel(locale: locale).headline
            == "Without domain:, the Harbour and Station lines run on to 15 people, though no order had a queue longer than 11.")
    }

    @Test("Given no orders, or too few queues, when the headline is written, then it says so")
    func headlinesWithoutLines() {
        let empty = TrendLineChartModel(orders: [], limitsToData: true, locale: locale)
        #expect(empty.isEmpty)
        #expect(empty.headline == "No orders yet, so there is nothing to fit a line to.")
        #expect(empty.portions.isEmpty)
        let one = [OrderWait(id: 0, store: CafeWording.station, queueLength: 2, waitSeconds: 100)]
        let single = TrendLineChartModel(orders: one, limitsToData: false, locale: locale)
        #expect(single.headline == "Too few queue lengths at either café to fit a trend line.")
    }

    @Test("Given one café's line, when domain: is left out, then the headline speaks of one line")
    func headlineOneLine() {
        let model = TrendLineChartModel(orders: exactOrders, limitsToData: false, locale: locale)
        #expect(model.headline == "Without domain:, the Harbour line runs on to 9 people, though no order had a queue longer than 5.")
    }

    @Test("Given a change of setting, when announced, then it says what changed and then the headline")
    func announcements() {
        let on = TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: true, locale: locale)
        let off = TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: false, locale: locale)
        #expect(on.announcement == "Trend lines limited to the data with domain:. \(on.headline)")
        #expect(off.announcement == "Trend lines no longer limited with domain:. \(off.headline)")
    }

    @Test("Given each setting, when the portions are made, then only queues with something drawn have one")
    func portions() throws {
        let on = TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: true, locale: locale)
        let off = TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: false, locale: locale)
        #expect(on.portions.map(\.queue) == Array(0 ... 11))
        #expect(off.portions.map(\.queue) == Array(0 ... 15))
        let first = try #require(on.portions.first)
        #expect(first.label == "0 people queuing")
        #expect(first.start == 0)
        #expect(first.value.hasPrefix("Station: "))
        #expect(first.value.contains("Station trend line"))
        #expect(!first.value.contains("Harbour trend line"))
        let beyond = try #require(off.portions.last)
        #expect(beyond.value.hasPrefix("Harbour trend line"))
        #expect(beyond.end == 15)
    }

    @Test("Given a queue of one, when its portion is labelled, then the count agrees in number")
    func portionAgreement() throws {
        let model = TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: true, locale: locale)
        let one = try #require(model.portions.first { $0.queue == 1 })
        #expect(one.label == "1 person queuing")
    }

    @Test("Given each setting, when described, then the Audio Graph has both cafés and each line as drawn")
    func descriptor() throws {
        let on = TrendLineChartDescriptor(model: TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: true, locale: locale))
            .makeChartDescriptor()
        #expect(on.title == "Wait against queue length at two cafés, with a trend line for each")
        #expect(on.series.map(\.name) == ["Harbour", "Station", "Harbour trend line", "Station trend line"])
        #expect(on.series.map(\.isContinuous) == [false, false, true, true])
        #expect(on.series.map(\.dataPoints.count) == [20, 20, 11, 11])
        #expect(on.summary?.hasPrefix("40 orders at 2 cafés.") == true)
        #expect(on.summary?.contains("Harbour trend line from 1 to 11 people") == true)
        let yAxis = try #require(on.yAxis)
        #expect(yAxis.title == CafeWording.waitAxisTitle)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        let off = TrendLineChartDescriptor(model: TrendLineChartModel(orders: CafeData.orderWaits, limitsToData: false, locale: locale))
            .makeChartDescriptor()
        #expect(off.series.map(\.dataPoints.count) == [20, 20, 16, 16])
        #expect(off.summary?.contains("Harbour trend line from 0 to 15 people") == true)
    }

    @Test("Given a German locale, when the headline is written, then numbers follow that locale")
    func germanLocale() {
        let orders = (0 ... 1).map { OrderWait(id: $0, store: CafeWording.harbour, queueLength: $0 * 1500, waitSeconds: 60 + $0) }
        let model = TrendLineChartModel(orders: orders, limitsToData: false, locale: Locale(identifier: "de_DE"))
        #expect(model.headline.contains("1.504 people"))
        #expect(model.headline.contains("longer than 1.500."))
    }
}
