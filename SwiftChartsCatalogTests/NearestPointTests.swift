import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct NearestPointTests {
    private let locale = Locale(identifier: "en_US")
    /// 20 points per person and half a point per second: one person is as far as 40 seconds.
    private let scale = NearestPointScreenScale(pointsPerPerson: 20, pointsPerSecond: 0.5)

    private func order(_ id: Int, queue: Int, wait: Int, store: String = "Harbour") -> OrderWait {
        OrderWait(id: id, store: store, queueLength: queue, waitSeconds: wait)
    }

    private func nearest(_ queue: Double, _ wait: Double, in orders: [OrderWait], radius: Double) -> OrderWait? {
        NearestPointFinder.nearest(
            to: (queue: queue, wait: wait), in: NearestPointFinder.ordered(orders), within: radius, scale: scale
        )
    }

    // MARK: Which order is accepted

    @Test("Given a selection on an order, when the nearest is found, then that order is accepted")
    func selectionOnAnOrder() {
        let orders = [order(0, queue: 2, wait: 100), order(1, queue: 6, wait: 200)]

        #expect(nearest(6, 200, in: orders, radius: 10)?.id == 1)
    }

    @Test("Given a selection with no order inside the radius, when the nearest is found, then none is accepted")
    func emptySpaceSelectsNothing() {
        let orders = [order(0, queue: 2, wait: 100), order(1, queue: 6, wait: 200)]

        // 2 people (40 points) from the nearest order.
        #expect(nearest(4, 100, in: orders, radius: 24) == nil)
    }

    @Test("Given two orders inside the radius, when the nearest is found, then the closer one is accepted")
    func closerOrderWins() {
        let orders = [order(0, queue: 4, wait: 100), order(1, queue: 5, wait: 100)]

        // 0.4 of a person (8 points) from the first, 0.6 (12 points) from the second.
        #expect(nearest(4.4, 100, in: orders, radius: 24)?.id == 0)
    }

    @Test("Given two orders equally near, when the nearest is found, then the one listed first, the shorter wait, is accepted")
    func tieGoesToTheFirstListed() {
        // Each 20 seconds (10 points) from the selection; listed by queue, then wait.
        let orders = [order(7, queue: 3, wait: 140), order(2, queue: 3, wait: 100)]

        #expect(nearest(3, 120, in: orders, radius: 10)?.id == 2)
    }

    @Test("Given two orders at the same spot, when the nearest is found, then the lower id is accepted")
    func tieAtOneSpotGoesToTheLowerID() {
        let orders = [order(9, queue: 3, wait: 100, store: "Station"), order(4, queue: 3, wait: 100)]

        #expect(nearest(3.1, 101, in: orders, radius: 10)?.id == 4)
    }

    @Test("Given an order exactly the radius away, when the nearest is found, then it is accepted")
    func radiusIsInclusive() {
        let orders = [order(0, queue: 3, wait: 100)]

        // 0.5 of a person: 10 points.
        #expect(nearest(3.5, 100, in: orders, radius: 10)?.id == 0)
        #expect(nearest(3.5, 100, in: orders, radius: 9.9) == nil)
    }

    @Test("Given axes with different units, when the nearest is found, then distance is measured in points, not data units")
    func distanceIsInPoints() {
        // One person away is 20 points; 30 seconds away is only 15 points.
        let orders = [order(0, queue: 4, wait: 100), order(1, queue: 5, wait: 130)]

        #expect(nearest(5, 100, in: orders, radius: 18)?.id == 1)
    }

    @Test("Given a selection outside the plot, when the nearest is found, then none is accepted even with an order in reach")
    func outsideThePlotSelectsNothing() {
        let orders = [order(0, queue: 0, wait: 100), order(1, queue: 12, wait: 355)]

        #expect(nearest(-0.2, 100, in: orders, radius: 24) == nil)
        #expect(nearest(12.2, 355, in: orders, radius: 24) == nil)
        #expect(nearest(12, 362, in: orders, radius: 24) == nil)
        #expect(nearest(0, -4, in: [order(2, queue: 0, wait: 0)], radius: 24) == nil)
        // On the plot's edge is still inside it.
        #expect(nearest(0, 100, in: orders, radius: 24)?.id == 0)
    }

    // MARK: View model

    @Test("Given a new view model, when it is read, then it holds the sample orders by queue and the default radius, with nothing selected")
    func initialState() {
        let viewModel = NearestPointViewModel()

        #expect(viewModel.orders.count == 40)
        #expect(Set(viewModel.orders) == Set(CafeData.orderWaits))
        #expect(viewModel.orders.map(\.queueLength) == viewModel.orders.map(\.queueLength).sorted())
        #expect(viewModel.radius == NearestPointViewModel.defaultRadius)
        #expect(NearestPointViewModel.radiusRange.contains(viewModel.radius))
        #expect(!viewModel.isSelecting)
        #expect(viewModel.accepted == nil)
    }

    @Test("Given the sample orders, when they are read, then every one lies inside both scale domains")
    func domainsCoverTheData() {
        for order in CafeData.orderWaits {
            #expect(NearestPointViewModel.queueDomain.contains(Double(order.queueLength)))
            #expect(NearestPointViewModel.waitDomain.contains(Double(order.waitSeconds)))
        }
    }

    @Test("Given a selection near an order, when the radius shrinks below its distance, then it is no longer accepted")
    func radiusChangesAcceptance() {
        let viewModel = NearestPointViewModel()
        viewModel.screenScale = scale
        viewModel.selectedQueue = 10.5
        viewModel.selectedWait = 309
        #expect(viewModel.accepted?.id == 25)

        viewModel.radius = 8
        #expect(viewModel.isSelecting)
        #expect(viewModel.accepted == nil)
    }

    @Test("Given a selection on one axis only, or before the chart is laid out, when it is read, then nothing is accepted")
    func incompleteSelection() {
        let viewModel = NearestPointViewModel()
        viewModel.selectedQueue = 10
        viewModel.selectedWait = 309
        #expect(viewModel.accepted == nil)

        viewModel.screenScale = scale
        viewModel.selectedWait = nil
        #expect(!viewModel.isSelecting)
        #expect(viewModel.accepted == nil)
    }

    // MARK: Text

    @Test("Given no selection, when the headline is read, then it names the longest wait and its order")
    func restingHeadline() {
        let summary = NearestPointViewModel().summary(locale: locale)

        #expect(summary.headline == "The longest wait was 309 seconds: Station, 10 people queuing.")
        #expect(summary.annotation == nil)
    }

    @Test("Given an accepted order, when the headline and annotation are read, then they name it")
    func acceptedHeadline() {
        let viewModel = NearestPointViewModel()
        viewModel.screenScale = scale
        viewModel.selectedQueue = 1.1
        viewModel.selectedWait = 60
        let summary = viewModel.summary(locale: locale)

        #expect(summary.headline == "Nearest order: Harbour, 1 person queuing, 59 seconds.")
        #expect(summary.annotation == "Harbour: 59 seconds")
    }

    @Test("Given a selection with nothing in reach, when the headline is read, then it says so with the radius")
    func nothingInReachHeadline() {
        let viewModel = NearestPointViewModel()
        viewModel.screenScale = scale
        viewModel.selectedQueue = 0.5
        viewModel.selectedWait = 300
        let summary = viewModel.summary(locale: locale)

        #expect(summary.headline == "No order within 24 points of your finger.")
        #expect(summary.annotation == nil)
    }

    @Test("Given a tie for the longest wait, when the headline is read, then it names both orders")
    func tiedLongestHeadline() {
        let viewModel = NearestPointViewModel(orders: [
            order(0, queue: 4, wait: 200), order(1, queue: 9, wait: 200, store: "Station"), order(2, queue: 1, wait: 80),
        ])

        #expect(viewModel.summary(locale: locale).headline
            == "The longest wait was 200 seconds: Harbour, 4 people queuing and Station, 9 people queuing.")
    }

    @Test("Given no orders, when the headline is read, then it says there are none")
    func emptyHeadline() {
        let viewModel = NearestPointViewModel(orders: [])
        viewModel.screenScale = scale
        viewModel.selectedQueue = 3
        viewModel.selectedWait = 100

        #expect(viewModel.accepted == nil)
        #expect(viewModel.summary(locale: locale).headline == "No orders to show yet.")
        #expect(viewModel.summary(locale: locale).audioGraphSummary == "No orders to show yet.")
    }

    @Test("Given a German locale, when the headline is read, then its numbers are written the German way")
    func headlineTakesTheLocale() {
        let viewModel = NearestPointViewModel()
        viewModel.screenScale = scale
        viewModel.selectedQueue = 0.5
        viewModel.selectedWait = 300
        viewModel.radius = 8

        #expect(viewModel.summary(locale: Locale(identifier: "de_DE")).headline == "No order within 8 points of your finger.")
        viewModel.radius = 9.5
        #expect(viewModel.summary(locale: Locale(identifier: "de_DE")).headline == "No order within 9,5 points of your finger.")
    }

    // MARK: Room kept for the headline

    @Test("Given the sample orders, when the reserved headline is read, then it is the longest headline at rest or for any selection")
    func reservedHeadlineIsTheLongest() throws {
        let viewModel = NearestPointViewModel()
        viewModel.screenScale = scale
        let reserved = try #require(viewModel.reservedHeadline(locale: locale))
        var headlines = [viewModel.summary(locale: locale).headline]
        for order in viewModel.orders {
            viewModel.selectedQueue = Double(order.queueLength)
            viewModel.selectedWait = Double(order.waitSeconds)
            headlines.append(viewModel.summary(locale: locale).headline)
        }
        viewModel.selectedQueue = 0.5
        viewModel.selectedWait = 300
        headlines.append(viewModel.summary(locale: locale).headline)

        #expect(headlines.allSatisfy { $0.count <= reserved.count })
        #expect(reserved.count == headlines.map(\.count).max())
    }

    @Test("Given no orders, when the reserved headline is read, then nothing is reserved")
    func reservedHeadlineWithoutOrders() {
        #expect(NearestPointViewModel(orders: []).reservedHeadline(locale: locale) == nil)
    }

    // MARK: Audio Graph

    @Test("Given the sample orders, when the descriptor is made, then it has numeric axes over the drawn domains, two series and a summary in values")
    func descriptor() throws {
        let descriptor = NearestPointChartDescriptor(orders: CafeData.orderWaits, locale: locale).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Wait against the queue at the Harbour and Station cafés")
        #expect(descriptor.summary == "40 orders at 2 cafés. Queues from 0 people to 11 people. "
            + "Shortest wait 59 seconds, Harbour, 1 person queuing. Longest wait 309 seconds, Station, 10 people queuing.")
        #expect(xAxis.title == CafeWording.queueAxisTitle)
        #expect(xAxis.range == NearestPointViewModel.queueDomain)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person")
        #expect(xAxis.valueDescriptionProvider(7) == "7 people")
        #expect(yAxis.title == CafeWording.waitAxisTitle)
        #expect(yAxis.range == NearestPointViewModel.waitDomain)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
        #expect(descriptor.series.map(\.dataPoints.count) == [20, 20])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
    }

    // MARK: Snippets

    @Test("Given the built app, when its snippets are read, then both of this screen's are there")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)

        #expect(store["select-the-nearest-point-chart"]?.code.contains("chartYSelection") == true)
        #expect(store["select-the-nearest-point-accept"]?.code.contains("hypot") == true)
    }
}
