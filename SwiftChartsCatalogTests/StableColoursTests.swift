import Accessibility
@testable import SwiftChartsCatalog
import Testing

struct StableColoursTests {
    private let english = Locale(identifier: "en_US")

    private func model(hiding hidden: [StableColoursSize] = [], domainFixed: Bool = true) -> StableColoursViewModel {
        let viewModel = StableColoursViewModel()
        for size in hidden {
            viewModel.setShown(size, false, locale: english)
        }
        viewModel.isDomainFixed = domainFixed
        return viewModel
    }

    // MARK: Colours

    @Test(
        "Given the domain on, when other sizes are filtered out, then each size left keeps the colour it had with every size shown",
        arguments: [[StableColoursSize.small], [.medium], [.small, .medium], [.small, .large]]
    )
    func seriesKeepsColourWithDomain(hidden: [StableColoursSize]) {
        let all = model()
        let filtered = model(hiding: hidden)

        for size in filtered.visibleSizes {
            #expect(filtered.colourIndex(of: size) == all.colourIndex(of: size))
        }
        #expect(filtered.colourSwaps.isEmpty)
    }

    @Test("Given the domain on and Small filtered out, when Medium's colour is read, then it is still the second colour")
    func mediumKeepsSecondColour() {
        #expect(model(hiding: [.small]).colourIndex(of: .medium) == 1)
        #expect(model(hiding: [.small]).colourIndex(of: .large) == 2)
    }

    @Test("Given the domain off and Small filtered out, when the colours are read, then Medium takes Small's and Large takes Medium's")
    func colourShiftsWithoutDomain() {
        let viewModel = model(hiding: [.small], domainFixed: false)

        #expect(viewModel.colourIndex(of: .medium) == 0)
        #expect(viewModel.colourIndex(of: .large) == 1)
        #expect(viewModel.colourSwaps.map(\.size) == [.medium, .large])
        #expect(viewModel.colourSwaps.map(\.takes) == [.small, .medium])
    }

    @Test("Given the domain off and only Large filtered out, when the colours are read, then nothing shifts")
    func removingLastSizeShiftsNothing() {
        #expect(model(hiding: [.large], domainFixed: false).colourSwaps.isEmpty)
    }

    @Test("Given a size filtered out, when its colour is read, then it has none")
    func hiddenSizeHasNoColour() {
        #expect(model(hiding: [.medium]).colourIndex(of: .medium) == nil)
    }

    // MARK: Filter

    @Test("Given Small filtered out, when the drawn data is read, then no Small segment is drawn and the others are")
    func filterRemovesSize() {
        let viewModel = model(hiding: [.small])

        #expect(viewModel.visibleSizes == [.medium, .large])
        #expect(!viewModel.visibleOrders.contains { $0.size == .small })
        #expect(viewModel.visibleOrders.count == 6)
    }

    @Test("Given the café's rows, when they become orders, then every row with a known size is kept")
    func ordersFromCafeData() {
        #expect(StableColoursOrder.orders(from: CafeData.drinkOrders).count == CafeData.drinkOrders.count)
        #expect(StableColoursOrder.orders(from: [DrinkOrder(drink: "Tea", size: "Huge", cups: 3)]).isEmpty)
    }

    // MARK: Words

    @Test("Given every size shown, when the headline is written, then it says each keeps its colour, with the domain on or off", arguments: [true, false])
    func headlineAllShown(domainFixed: Bool) {
        #expect(model(domainFixed: domainFixed).headline(locale: english) == "All 3 sizes shown: each size keeps its own colour.")
    }

    @Test("Given Small filtered out with the domain on, when the headline is written, then it says the sizes left keep their colours")
    func headlineFilteredWithDomain() {
        #expect(model(hiding: [.small]).headline(locale: english)
            == "Medium and Large shown, 2 of 3 sizes: each size keeps its own colour.")
    }

    @Test("Given Small filtered out without the domain, when the headline is written, then it names each colour taken")
    func headlineFilteredWithoutDomain() {
        #expect(model(hiding: [.small], domainFixed: false).headline(locale: english)
            == "Medium and Large shown, 2 of 3 sizes: Medium is drawn in Small’s colour and Large is drawn in Medium’s colour.")
    }

    @Test("Given one size left, when the headline is written, then the count agrees in number")
    func headlineOneSize() {
        #expect(model(hiding: [.small, .medium], domainFixed: false).headline(locale: english)
            == "Large shown, 1 of 3 sizes: Large is drawn in Small’s colour.")
    }

    @Test("Given every size filtered out, when the chart's words are written, then they say there is nothing to draw")
    func headlineNoSizes() {
        let viewModel = model(hiding: StableColoursSize.allCases)

        #expect(!viewModel.hasBars)
        #expect(viewModel.headline(locale: english) == "No sizes shown: choose a size to draw its cups.")
        #expect(viewModel.audioGraphSummary(locale: english) == viewModel.headline(locale: english))
    }

    @Test("Given only zeros, when the chart's words are written, then they say no cups were sold, and nothing is drawn")
    func headlineAllZero() {
        let viewModel = StableColoursViewModel(orders: [
            StableColoursOrder(drink: "Tea", size: .small, cups: 0), StableColoursOrder(drink: "Tea", size: .large, cups: 0),
        ])

        #expect(!viewModel.hasBars)
        #expect(viewModel.headline(locale: english) == "No cups sold in the sizes shown.")
    }

    @Test("Given Small filtered out, when the Audio Graph summary is written, then it gives each drink's total of the sizes drawn, then the headline")
    func audioGraphSummaryTotals() {
        #expect(model(hiding: [.small]).audioGraphSummary(locale: english)
            == "Sizes shown: Medium and Large. Latte 94 cups, Tea 93 cups, and Mocha 70 cups in total. "
            + "Medium and Large shown, 2 of 3 sizes: each size keeps its own colour.")
    }

    @Test("Given a filter chip and the domain switch, when each changes, then the announcement says what changed, then the headline")
    func announcements() {
        let viewModel = StableColoursViewModel()

        #expect(viewModel.setShown(.small, false, locale: english)
            == "Small hidden. Medium and Large shown, 2 of 3 sizes: each size keeps its own colour.")
        #expect(viewModel.setDomainFixed(false, locale: english)
            == "Colour domain removed. Medium and Large shown, 2 of 3 sizes: Medium is drawn in Small’s colour and Large is drawn in Medium’s colour.")
        #expect(viewModel.setShown(.small, true, locale: english)
            == "Small shown. All 3 sizes shown: each size keeps its own colour.")
    }

    // MARK: Descriptor

    @Test("Given Small filtered out, when the descriptor is made, then it has a series per size drawn over the drinks, from zero to the tallest stack")
    func descriptor() throws {
        let viewModel = model(hiding: [.small])
        let descriptor = StableColoursChartDescriptor(
            orders: viewModel.visibleOrders, sizes: viewModel.visibleSizes,
            summary: viewModel.audioGraphSummary(locale: english), locale: english
        ).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today, by drink and size")
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        #expect(descriptor.series.map(\.name) == ["Medium", "Large"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 3 && !$0.isContinuous })
        // The tallest stack shown is 94; the axis is drawn to 100, and the descriptor says the same.
        #expect(yAxis.range == 0 ... 100)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    // MARK: Code

    @Test("Given the domain on or off, when the snippets are listed, then they are the bars and that setting's scale", arguments: [
        (true, "stable-colours-fixed-domain"), (false, "stable-colours-no-domain"),
    ])
    func snippetsFollowDomain(domainFixed: Bool, name: String) {
        #expect(model(domainFixed: domainFixed).snippets.map(\.name) == ["stable-colours-bars", name])
    }

    @Test("Given every snippet the screen can show, when the bundle is read, then each exists")
    func snippetsExistInTheBundle() throws {
        let store = try SnippetStore()
        for name in ["stable-colours-bars", "stable-colours-fixed-domain", "stable-colours-no-domain"] {
            #expect(store[name] != nil)
        }
    }
}
