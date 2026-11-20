import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct LargePlotTests {
    private let english = Locale(identifier: "en_US")

    private func order(_ id: Int, drink: String = "Tea", hour: Double, cups: Int = 1, wait: Double) -> CafeOrder {
        CafeOrder(id: id, drink: drink, hour: hour, cups: cups, waitMinutes: wait)
    }

    // MARK: Data

    @Test("Given the largest count, when the orders are generated, then every wait per cup lies inside the stated domain")
    func statedDomainHoldsEveryOrder() {
        let orders = CafeData.manyOrders(count: CafeData.manyOrdersMaximum)

        #expect(orders.count == CafeData.manyOrdersMaximum)
        #expect(orders.allSatisfy { LargePlotScales.waitPerCupDomain.contains($0.minutesPerCup) })
        #expect(Set(orders.map(\.drink)).isSubset(of: Set(LargePlotScales.drinks)))
    }

    @Test("Given orders, when the computed wait per cup is read, then it equals the stored one for every order")
    func computedMatchesStored() {
        let orders = CafeData.manyOrders(count: CafeData.manyOrdersMaximum)

        #expect(orders.allSatisfy { $0.largePlotComputedMinutesPerCup == $0.minutesPerCup })
    }

    @Test("Given unsorted orders, when they are sorted by drink, then they come in legend order and the colour changes three times")
    func sortedByDrink() {
        let orders = CafeData.manyOrders(count: 5000)
        let sorted = LargePlotViewModel.sortedByDrink(orders)

        #expect(sorted.count == orders.count)
        #expect(Set(sorted.map(\.id)) == Set(orders.map(\.id)))
        #expect(LargePlotViewModel.styleChanges(in: sorted) == 3)
        #expect(sorted.first?.drink == "Latte")
        #expect(sorted.last?.drink == "Espresso")
        #expect(LargePlotViewModel.styleChanges(in: orders) > 3000)
    }

    @Test("Given two orders of one drink, when sorted, then they keep their order by id")
    func sortIsStable() {
        let sorted = LargePlotViewModel.sortedByDrink([
            order(2, drink: "Tea", hour: 8, wait: 1), order(1, drink: "Latte", hour: 9, wait: 1),
            order(0, drink: "Tea", hour: 10, wait: 1),
        ])

        #expect(sorted.map(\.id) == [1, 0, 2])
    }

    // MARK: View model

    @Test("Given a new screen, when it opens, then it draws the default count with every piece of advice on, sorted")
    func defaults() {
        let model = LargePlotViewModel()

        #expect(model.count == LargePlotViewModel.defaultCount)
        #expect(model.readsStoredProperties && model.sortsByDrink && model.setsScaleDomains)
        #expect(model.orders.map(\.id) == model.sortedOrders.map(\.id))
        #expect(model.styleChanges == 3)
        #expect(model.styleChangesText(locale: english)
            == "The colour changes 3 times along the data. Espresso, drawn last, covers the other drinks where points overlap.")
    }

    @Test("Given the sort turned off, when the chart is handed its orders, then they are the generated ones")
    func unsortedOrders() {
        let model = LargePlotViewModel()
        model.sortsByDrink = false

        #expect(model.orders.map(\.id) == Array(0 ..< LargePlotViewModel.defaultCount))
        #expect(model.styleChanges > 3)
        #expect(model.styleChangesText(locale: english).hasSuffix("The drinks are drawn mixed, so none covers the others."))
    }

    @Test("Given the slider moved, when the count changes, then the orders, stretches and headline follow")
    func countChanges() {
        let model = LargePlotViewModel()
        model.orderCount = 12000

        #expect(model.count == 12000)
        #expect(model.sortedOrders.count == 12000)
        #expect(model.portions.map(\.waits.count).reduce(0, +) == 12000)
        #expect(model.headline(locale: english).hasPrefix("Of 12,000 orders, the longest wait per cup"))
        #expect(model.countText(locale: english) == "12,000")
    }

    @Test("Given any setting of the toggles, when the headline is written, then it is the same, naming the longest wait per cup and its time")
    func headlineSameInEverySetting() throws {
        let model = LargePlotViewModel()
        let first = model.headline(locale: english)
        let longest = try #require(model.longestWait)
        #expect(model.generatedOrders.allSatisfy { $0.minutesPerCup <= longest.minutesPerCup })

        for stored in [true, false] {
            for sorted in [true, false] {
                for domains in [true, false] {
                    model.readsStoredProperties = stored
                    model.sortsByDrink = sorted
                    model.setsScaleDomains = domains
                    #expect(model.headline(locale: english) == first)
                }
            }
        }
        let expected = "Of 5,000 orders, the longest wait per cup, "
            + "\(TimeOfDayWording.minutes(longest.minutesPerCup, locale: english)), came at "
            + "\(TimeOfDayWording.time(hour: longest.hour, locale: english))."
        #expect(first == expected)
    }

    @Test("Given the slider, when its value is spoken, then it says the count and then the headline")
    func sliderSpokenValue() {
        let model = LargePlotViewModel()

        #expect(model.countSpokenValue(locale: english) == "5,000 orders. \(model.headline(locale: english))")
    }

    @Test("Given each toggle switched, when the change is announced, then it says what changed and then the headline")
    func announcements() {
        let model = LargePlotViewModel()
        let headline = model.headline(locale: english)

        model.readsStoredProperties = false
        #expect(model.announcement(for: .storedProperties, locale: english)
            == "The plot now reads a computed wait per cup. \(headline)")
        model.sortsByDrink = false
        #expect(model.announcement(for: .sortedByStyle, locale: english)
            == "The orders are now unsorted. The drinks are drawn mixed, so none covers the others. \(headline)")
        model.setsScaleDomains = false
        #expect(model.announcement(for: .sortedByStyle, locale: english)
            == "The orders are now unsorted. The drinks are drawn mixed, so none covers the others. "
            + "With automatic domains, the drinks change colour too. \(headline)")
        #expect(model.announcement(for: .explicitDomains, locale: english)
            == "The wait and drink domains are now automatic. \(headline)")
        #expect(model.domainNote?.hasPrefix("The wait axis now ends") == true)
        model.setsScaleDomains = true
        #expect(model.domainNote == nil)
        #expect(model.announcement(for: .explicitDomains, locale: english)
            == "The wait and drink domains are now stated. \(headline)")
    }

    @Test("Given automatic domains, when the sort changes, then the colours change too, because the drinks first appear in another order")
    func sortChangesColours() {
        let model = LargePlotViewModel()

        #expect(LargePlotViewModel.firstAppearance(in: model.sortedOrders) == LargePlotScales.drinks)
        #expect(LargePlotViewModel.firstAppearance(in: model.generatedOrders) != LargePlotScales.drinks)
        #expect(!model.sortChangesColours)
        model.setsScaleDomains = false
        #expect(model.sortChangesColours)
    }

    @Test("Given automatic domains, when the wait axis's end is worked out, then it ends where the framework ended the drawn axis")
    func automaticWaitTop() {
        #expect(LargePlotScales.automaticWaitTop(longest: 7.6) == 8)
        #expect(LargePlotScales.automaticWaitTop(longest: 4) == 4)
        #expect(LargePlotScales.automaticWaitTop(longest: 8.2) == 10)
        #expect(LargePlotScales.automaticWaitTop(longest: 4.3) == 6)
        #expect(LargePlotScales.automaticWaitTop(longest: 23) == 30)
        #expect(LargePlotScales.automaticWaitTop(longest: 47) == 60)
        #expect(LargePlotScales.automaticWaitTop(longest: 0) == 0)
    }

    @Test("Given a count that agrees in number, when the colour changes once, then it says 1 time")
    func timesAgrees() {
        #expect(LargePlotViewModel.times(1, locale: english) == "1 time")
        #expect(LargePlotViewModel.times(14987, locale: english) == "14,987 times")
    }

    // MARK: Spoken stretches

    @Test("Given orders across the day, when a stretch is spoken, then it gives counts, waits per cup in minutes and drinks")
    func spokenStretch() throws {
        let portions = TimeOfDayPortion.make(
            [order(0, drink: "Latte", hour: 6.5, cups: 2, wait: 4), order(1, drink: "Tea", hour: 7.5, wait: 1)],
            hour: \.hour, wait: \.minutesPerCup, category: \.drink, categoryOrder: LargePlotScales.drinks
        )
        let first = try #require(portions.first)

        #expect(portions.count == 6)
        #expect(LargePlotViewModel.spokenValue(of: first, locale: english)
            == "2 orders, waits per cup from 1 minute to 2 minutes, median 1.5 minutes; Latte 1, Tea 1, Mocha 0, and Espresso 0")
        #expect(LargePlotViewModel.spokenValue(of: portions[1], locale: english) == "No orders.")
    }

    // MARK: Descriptor

    @Test("Given orders, when the descriptor is made, then it has titles, a summary in values, hourly medians and the drawn range")
    func descriptor() throws {
        let orders = [
            order(0, drink: "Latte", hour: 6.2, wait: 2), order(1, drink: "Tea", hour: 6.8, wait: 4),
            order(2, drink: "Mocha", hour: 17.5, cups: 2, wait: 3),
        ]
        let descriptor = LargePlotChartDescriptor(orders: orders, setsScaleDomains: true, locale: english)
            .makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Wait per cup of each order across one day")
        #expect(descriptor.summary == "3 orders between 6:00\u{202F}AM and 6:00\u{202F}PM. "
            + "Waits per cup from 1.5 minutes to 4 minutes, the longest at 6:48\u{202F}AM. "
            + "By drink: Latte 1, Tea 1, Mocha 1, and Espresso 0. Played as each hour's median.")
        #expect(descriptor.xAxis.title == TimeOfDayWording.timeOfDay)
        #expect(yAxis.title == LargePlotWording.waitPerCupAxisTitle)
        #expect(yAxis.range == LargePlotScales.waitPerCupDomain)
        #expect(yAxis.valueDescriptionProvider(1) == "1 minute")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == LargePlotWording.medianSeries)
        #expect(descriptor.series.first?.dataPoints.count == 2)

        let automatic = LargePlotChartDescriptor(orders: orders, setsScaleDomains: false, locale: english)
        #expect(automatic.yRange == 0 ... 4)
        #expect(automatic.hourlyMedians.map(\.hour) == [6.5, 17.5])
        #expect(automatic.hourlyMedians.map(\.median) == [3, 1.5])
    }

    @Test("Given no orders, when the descriptor and headline are written, then they say so")
    func noOrders() {
        let descriptor = LargePlotChartDescriptor(orders: [], setsScaleDomains: false, locale: english)

        #expect(descriptor.summary == "No orders.")
        #expect(descriptor.yRange == 0 ... 0)
        #expect(descriptor.hourlyMedians.isEmpty)
    }

    // MARK: Snippets

    @Test("Given each setting, when the snippets are chosen, then they show the plot and the code behind each toggle")
    func snippetsFollowToggles() {
        #expect(LargePlotSnippets.defaults.map(\.name) == [
            "keeping-a-large-plot-fast-plot", "keeping-a-large-plot-fast-sorted", "keeping-a-large-plot-fast-domains",
        ])
        #expect(LargePlotSnippets.references(readsStoredProperties: false, sortsByDrink: false, setsScaleDomains: false)
            .map(\.name) == [
                "keeping-a-large-plot-fast-plot", "keeping-a-large-plot-fast-computed",
                "keeping-a-large-plot-fast-unsorted", "keeping-a-large-plot-fast-automatic",
            ])
    }

    @Test("Given the app's snippets, when they are loaded, then every snippet the screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let all = [
            LargePlotSnippets.plot, LargePlotSnippets.computed, LargePlotSnippets.sorted,
            LargePlotSnippets.unsorted, LargePlotSnippets.domains, LargePlotSnippets.automatic,
        ]

        for reference in all {
            #expect(store[reference.name] != nil, "\(reference.name) is missing")
        }
    }

    // MARK: Timings

    @Test("Given the measured medians, when the timings are written, then each variant gets its median in milliseconds")
    func timingLines() {
        let lines = LargePlotViewModel.timingLines(LargePlotViewModel.measurements, locale: english)

        #expect(lines == [
            "All three on: 178.1 ms", "A computed property: 180.6 ms", "Orders unsorted: 178.4 ms",
            "Automatic domains: 179.1 ms", "All three off: 182.4 ms",
        ])
        #expect(LargePlotViewModel.timingLines([LargePlotMeasurement(name: "Lost", milliseconds: .nan)], locale: english)
            .isEmpty)
        #expect(LargePlotViewModel.timingCaption(orderCount: 20000, spread: 5 ... 13, locale: english)
            == "One render on the iOS simulator at 20,000 orders, the median of 9. "
            + "One variant's renders varied by 5 to 13 ms.")
    }

    @Test("Given medians closer than the spread, when the verdict is written, then no setting is called faster and the point count is")
    func timingVerdict() {
        let verdict = LargePlotViewModel.timingVerdict(
            LargePlotViewModel.measurements,
            orderCount: LargePlotViewModel.measuredOrderCount,
            spread: LargePlotViewModel.spreadMilliseconds,
            smallerCount: LargePlotViewModel.smallerOrderCount,
            smallerMilliseconds: LargePlotViewModel.smallerMilliseconds,
            locale: english
        )

        #expect(verdict == "No setting was measurably faster: the medians lie within the spread of one variant's renders. "
            + "What costs time is the number of points: 5,000 orders took 52 to 54 ms in every setting, so 4 times "
            + "the points took about 3.4 times as long. A single render says nothing about live updates, scrolling or a device.")
    }

    @Test("Given medians further apart than the spread, when the verdict is written, then it does not say no setting was faster")
    func timingVerdictWithADifference() {
        let verdict = LargePlotViewModel.timingVerdict(
            [LargePlotMeasurement(name: "On", milliseconds: 100), LargePlotMeasurement(name: "Off", milliseconds: 150)],
            orderCount: 20000, spread: 5 ... 13, smallerCount: 5000, smallerMilliseconds: 30 ... 30, locale: english
        )

        #expect(verdict.hasPrefix("The settings' medians differ by more than one variant's renders did."))
    }
}
