import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct PointMarkTests {
    private let orders = [
        OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 50),
        OrderWait(id: 1, store: "Station", queueLength: 2, waitSeconds: 130),
        OrderWait(id: 2, store: "Harbour", queueLength: 5, waitSeconds: 125),
        OrderWait(id: 3, store: "Station", queueLength: 9, waitSeconds: 260),
    ]

    private let english = Locale(identifier: "en_US")
    private let german = Locale(identifier: "de_DE")

    private func summary(
        _ axes: PointAxes, encoded: Bool, orders: [OrderWait]? = nil, locale: Locale? = nil
    ) -> PointMarkSummary {
        PointMarkSummary(orders: orders ?? self.orders, axes: axes, showsEncodings: encoded, locale: locale ?? english)
    }

    @Test("Given a new screen, when nothing has been changed, then it shows a scatter plot with café encoded, on the sample data")
    func startsAsEncodedScatter() {
        let viewModel = PointMarkViewModel()

        #expect(viewModel.axes == .two)
        #expect(viewModel.showsEncodings)
        #expect(viewModel.orders == CafeData.orderWaits)
    }

    @Test(
        "Given a setting of the two controls, when the snippets are read, then they are the code for that setting and exist in the app",
        arguments: [
            (PointAxes.two, true, "point-scatter-encoded"), (.two, false, "point-scatter"),
            (.one, true, "point-strip-encoded"), (.one, false, "point-strip"),
        ]
    )
    func snippetsFollowControls(axes: PointAxes, encoded: Bool, name: String) throws {
        let viewModel = PointMarkViewModel(orders: orders)
        viewModel.axes = axes
        viewModel.showsEncodings = encoded
        let store = try SnippetStore(bundle: .main)

        #expect(viewModel.snippets.map(\.name) == [name])
        let snippet = try #require(store[name])
        #expect(snippet.file == "Marks/PointMarkScreen.swift")
        #expect(snippet.code.contains("PointMark("))
        #expect(snippet.code.contains("symbol(by:") == encoded)
        #expect(snippet.code.contains("y: .value(\"Wait\"") == (axes == .two))
    }

    @Test("Given the controls change, when the summary is read, then it follows them")
    func summaryFollowsControls() {
        let viewModel = PointMarkViewModel(orders: orders)
        viewModel.axes = .one
        viewModel.showsEncodings = false

        #expect(viewModel.summary(locale: english).axes == .one)
        #expect(!viewModel.summary(locale: english).showsEncodings)
        #expect(viewModel.summary(locale: english).orders == orders)
        #expect(viewModel.summary(locale: german).locale == german)
    }

    @Test("Given one longest wait, when the headline is written, then it names only what the chart draws in that setting")
    func headlineFollowsWhatIsDrawn() {
        #expect(summary(.two, encoded: true).headline == "The longest wait, 260 seconds, was at Station with 9 people queuing.")
        #expect(summary(.two, encoded: false).headline == "The longest wait, 260 seconds, came with 9 people queuing.")
        #expect(summary(.one, encoded: true).headline == "The longest wait, 260 seconds, was at Station.")
        #expect(summary(.one, encoded: false).headline == "Waits ran from 50 to 260 seconds.")
    }

    @Test("Given the sample data, when the headline is written, then its figure is the longest wait in that data")
    func headlineFollowsSampleData() {
        let longest = CafeData.orderWaits.map(\.waitSeconds).max() ?? 0
        let headline = PointMarkSummary(orders: CafeData.orderWaits, axes: .two, showsEncodings: true, locale: english).headline

        #expect(headline.contains(CafeWording.seconds(longest, locale: english)))
    }

    @Test("Given two orders tied for the longest wait, when the headline is written, then it gives the range and credits no one order")
    func tieGivesRange() {
        let tied = orders + [OrderWait(id: 4, store: "Harbour", queueLength: 3, waitSeconds: 260)]

        #expect(summary(.two, encoded: true, orders: tied).headline == "Waits ran from 50 to 260 seconds.")
    }

    @Test("Given every wait is the same, when the range is written, then it says so")
    func equalWaitsSaySo() {
        let equal = [
            OrderWait(id: 0, store: "Harbour", queueLength: 1, waitSeconds: 90),
            OrderWait(id: 1, store: "Station", queueLength: 2, waitSeconds: 90),
        ]

        #expect(summary(.one, encoded: false, orders: equal).headline == "Every wait was 90 seconds.")
    }

    @Test("Given no orders, when the chart's words are written, then they say there are none")
    func noDataSaysSo() {
        let summary = summary(.two, encoded: true, orders: [])

        #expect(!summary.hasData)
        #expect(summary.headline == "No orders yet.")
        #expect(summary.audioGraphSummary == "No orders yet.")
        #expect(summary.announcement == "No orders yet.")
        #expect(self.summary(.one, encoded: true, orders: []).portions.isEmpty)
    }

    @Test(
        "Given orders that all waited zero seconds, when the chart's words are written, then they are data and no longest wait is named",
        arguments: [(PointAxes.two, true), (.two, false), (.one, true), (.one, false)]
    )
    func zeroWaitsAreData(axes: PointAxes, encoded: Bool) {
        let zeros = [
            OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 0),
            OrderWait(id: 1, store: "Station", queueLength: 3, waitSeconds: 0),
        ]
        let summary = summary(axes, encoded: encoded, orders: zeros)

        #expect(summary.hasData)
        #expect(summary.headline == "No order had to wait.")
        #expect(summary.portions.flatMap(\.orders).count == 2)
        #expect(summary.audioGraphSummary.contains("Every wait 0 seconds."))
        #expect(summary.announcement.hasPrefix("Chart changed"))
    }

    @Test("Given a scatter plot with café encoded, when its elements are made, then there is one per café and band of queue, café first")
    func scatterPortionsByCafe() {
        let portions = summary(.two, encoded: true).portions

        #expect(portions.map(\.label) == [
            "Harbour, 0 to 3 people queuing", "Harbour, 4 to 7 people queuing",
            "Station, 0 to 3 people queuing", "Station, 8 to 11 people queuing",
        ])
        #expect(portions.first?.value == "1 order, wait 50 seconds")
        #expect(portions.flatMap(\.orders).count == orders.count)
    }

    @Test("Given a scatter plot with no encoding, when its elements are made, then cafés are not named and waits are a range")
    func scatterPortionsUnencoded() {
        let portions = summary(.two, encoded: false).portions

        #expect(portions.map(\.label) == ["0 to 3 people queuing", "4 to 7 people queuing", "8 to 11 people queuing"])
        #expect(portions.first?.value == "2 orders, waits from 50 to 130 seconds")
    }

    @Test("Given points on one axis, when its elements are made, then each is a band of waits with its number of orders")
    func stripPortions() {
        let plain = summary(.one, encoded: false).portions
        let encoded = summary(.one, encoded: true).portions

        #expect(plain.map(\.label) == ["Waits of 0 to 59 seconds", "Waits of 120 to 179 seconds", "Waits of 240 to 299 seconds"])
        #expect(plain.map(\.value) == ["1 order", "2 orders", "1 order"])
        #expect(encoded.map(\.label) == [
            "Harbour, waits of 0 to 59 seconds", "Harbour, waits of 120 to 179 seconds",
            "Station, waits of 120 to 179 seconds", "Station, waits of 240 to 299 seconds",
        ])
    }

    @Test("Given each setting, when the announcement is written, then it follows both controls")
    func announcementFollowsBothControls() {
        #expect(summary(.two, encoded: true).announcement == "Chart changed: a point per order, queue on x and wait on y, colour and symbol by café.")
        #expect(summary(.one, encoded: false).announcement == "Chart changed: a point per order on one axis, the wait, every point alike.")
        let all = [summary(.two, encoded: true), summary(.two, encoded: false), summary(.one, encoded: true), summary(.one, encoded: false)]
        #expect(Set(all.map(\.announcement)).count == 4)
    }

    @Test("Given counts, when they are written, then the unit agrees with the number")
    func wordsAgreeInNumber() {
        #expect(CafeWording.seconds(1, locale: english) == "1 second")
        #expect(CafeWording.seconds(332, locale: english) == "332 seconds")
        #expect(CafeWording.orders(1, locale: english) == "1 order")
        #expect(CafeWording.orders(0, locale: english) == "0 orders")
        // Worded as the other queue charts word their lowest value.
        #expect(PointMarkSummary.queueText(0, locale: english) == "0 people queuing")
        #expect(PointMarkSummary.queueText(1, locale: english) == "1 person queuing")
        #expect(PointMarkSummary.queueText(11, locale: english) == "11 people queuing")
    }

    @Test("Given a German locale, when the chart's words are written, then numbers are grouped its way and the words stay English")
    func numbersTakeTheLocale() {
        let slow = [
            OrderWait(id: 0, store: "Harbour", queueLength: 2, waitSeconds: 1100),
            OrderWait(id: 1, store: "Station", queueLength: 1500, waitSeconds: 2400),
        ]
        let summary = summary(.two, encoded: true, orders: slow, locale: german)

        #expect(summary.headline == "The longest wait, 2.400 seconds, was at Station with 1.500 people queuing.")
        #expect(summary.audioGraphSummary
            == "2 orders at Harbour and Station. Queues from 2 to 1.500 people queuing. Waits from 1.100 to 2.400 seconds.")
        #expect(PointMarkSummary.bandText(PointBand(lower: 1080, upper: 1139), locale: german) == "1.080 to 1.139 seconds")
    }

    @Test("Given an encoded scatter plot, when its descriptor is made, then it has two number axes from zero and a named series of separate points per café")
    func scatterDescriptor() throws {
        let descriptor = PointMarkChartDescriptor(summary: summary(.two, encoded: true)).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Wait against queue length for each order, by café")
        #expect(descriptor.summary == "4 orders at Harbour and Station. Queues from 0 to 9 people queuing. Waits from 50 to 260 seconds.")
        #expect(xAxis.title == "People queuing")
        // Queues up to 9 and waits up to 260, on axes drawn to 10 and 300.
        #expect(xAxis.range == 0 ... 10)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person queuing")
        #expect(yAxis.title == "Wait (seconds)")
        #expect(yAxis.range == 0 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.map(\.dataPoints.count) == [2, 2])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }

    @Test("Given a scatter plot with no encoding, when its descriptor is made, then it has one series and names no café")
    func scatterDescriptorUnencoded() {
        let descriptor = PointMarkChartDescriptor(summary: summary(.two, encoded: false)).makeChartDescriptor()

        #expect(descriptor.title == "Wait against queue length for each order")
        #expect(descriptor.summary == "4 orders. Queues from 0 to 9 people queuing. Waits from 50 to 260 seconds.")
        #expect(descriptor.series.map(\.name) == ["All orders"])
        #expect(descriptor.series.first?.dataPoints.count == 4)
    }

    @Test("Given points on one axis, when the descriptor is made, then it counts orders in each band of waits, a series per café when encoded")
    func stripDescriptor() throws {
        let encoded = PointMarkChartDescriptor(summary: summary(.one, encoded: true)).makeChartDescriptor()
        let plain = PointMarkChartDescriptor(summary: summary(.one, encoded: false)).makeChartDescriptor()
        let xAxis = try #require(encoded.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(encoded.yAxis)

        #expect(encoded.title == "How the waits of orders are spread, by café")
        #expect(encoded.summary == "4 orders at Harbour and Station. Waits from 50 to 260 seconds. Counted in bands of 60 seconds.")
        #expect(xAxis.categoryOrder == ["0 to 59 seconds", "60 to 119 seconds", "120 to 179 seconds", "180 to 239 seconds", "240 to 299 seconds"])
        #expect(yAxis.title == "Orders")
        #expect(yAxis.range == 0 ... 1)
        #expect(yAxis.valueDescriptionProvider(1) == "1 order")
        #expect(encoded.series.map(\.name) == ["Harbour", "Station"])
        #expect(encoded.series.map(\.dataPoints.count) == [5, 5])
        #expect(plain.series.map(\.name) == ["All orders"])
        #expect(plain.yAxis?.range == 0 ... 2)
        #expect(summary(.one, encoded: false).counts(in: orders) == [1, 0, 2, 0, 1])
    }

    @Test(
        "Given each setting of the two controls, when the sample orders are split into portions, then every order is in exactly one",
        arguments: [(PointAxes.two, true), (.two, false), (.one, true), (.one, false)]
    )
    func portionsCountEveryOrder(axes: PointAxes, encoded: Bool) {
        let summary = PointMarkSummary(orders: CafeData.orderWaits, axes: axes, showsEncodings: encoded, locale: english)

        let counted: Int = summary.portions.map(\.orders.count).reduce(0, +)
        #expect(counted == CafeData.orderWaits.count)
        if axes == .one {
            let perBand: Int = summary.counts(in: CafeData.orderWaits).reduce(0, +)
            #expect(perBand == CafeData.orderWaits.count)
        }
    }
}
