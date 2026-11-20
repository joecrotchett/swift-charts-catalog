import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ChartSystemTests {
    private let locale = Locale(identifier: "en_US")

    /// The interval format puts thin spaces around its dash; compare with plain ones.
    private func plain(_ text: String?) -> String? {
        text?.replacingOccurrences(of: "\u{2009}", with: " ").replacingOccurrences(of: "\u{202F}", with: " ")
    }

    private func viewModel(at step: ChartSystemStep, trends: [MonthlyDrinkCups] = CafeData.monthlyDrinkTrends) -> ChartSystemViewModel {
        let viewModel = ChartSystemViewModel(trends: trends)
        for _ in 0 ..< step.rawValue {
            viewModel.goForward()
        }
        return viewModel
    }

    /// The sample data with every cup of one drink set to zero.
    private func trends(withNo drink: String) -> [MonthlyDrinkCups] {
        CafeData.monthlyDrinkTrends.map { MonthlyDrinkCups(drink: $0.drink, month: $0.month, cups: $0.drink == drink ? 0 : $0.cups) }
    }

    // MARK: Steps

    @Test("Given a new screen, when it appears, then it is on the period step and can only go forward")
    func startsOnPeriod() {
        let viewModel = ChartSystemViewModel()

        #expect(viewModel.step == .period)
        #expect(viewModel.stepTitle == "Step 1 of 3")
        #expect(!viewModel.canGoBack)
        #expect(viewModel.canGoForward)
    }

    @Test("Given the last step, when Next is pressed, then the step stays on the measure")
    func stopsAtTheEnd() {
        let viewModel = viewModel(at: .measure)

        viewModel.goForward()

        #expect(viewModel.step == .measure)
        #expect(!viewModel.canGoForward)
        #expect(viewModel.canGoBack)
    }

    @Test("Given the kind-of-data step, when Back is pressed, then the period step returns")
    func goesBack() {
        let viewModel = viewModel(at: .kindOfData)

        viewModel.goBack()

        #expect(viewModel.step == .period)
    }

    @Test("Given no cups at all, when the screen appears, then neither step button is enabled")
    func noDataDisablesSteps() {
        let viewModel = ChartSystemViewModel(trends: [])

        #expect(!viewModel.canGoBack)
        #expect(!viewModel.canGoForward)
        viewModel.goForward()
        #expect(viewModel.step == .period)
    }

    // MARK: The system: what stays and what changes

    @Test("Given any step, when the charts are read, then the first chart is Latte's cups from March to August")
    func referenceNeverChanges() {
        for step in ChartSystemStep.allCases {
            let reference = viewModel(at: step).reference
            #expect(reference == ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .cups))
        }
    }

    @Test("Given each step, when the second chart is read, then it differs from the first by the step's one thing")
    func comparedDiffersByOneThing() {
        #expect(viewModel(at: .period).compared == ChartSystemChartSpec(drink: "Latte", months: 6 ..< 12, measure: .cups))
        #expect(viewModel(at: .kindOfData).compared == ChartSystemChartSpec(drink: "Tea", months: 0 ..< 6, measure: .cups))
        #expect(viewModel(at: .measure).compared == ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .share))
    }

    @Test("Given the palette, when each drink is looked up, then the colours follow the drinks' fixed order")
    func paletteOrder() {
        #expect(CafeDrinkStyle.drinks == ["Latte", "Tea", "Mocha"])
        #expect(["Latte", "Tea", "Mocha", "Chai"].map(CafeDrinkStyle.colourName(for:)) == ["brown", "green", "purple", "grey"])
        #expect(Set(CafeDrinkStyle.drinks.map(CafeDrinkStyle.colour(for:))).count == 3)
        #expect(CafeDrinkStyle.colour(for: "Chai") == .gray)
    }

    @Test("Given the sample data, when the cups scale is worked out, then every cups chart runs from 0 to 800")
    func oneCupsScale() {
        let data = ChartSystemData(trends: CafeData.monthlyDrinkTrends)

        #expect(data.valueDomain(for: .cups) == 0 ... 800)
        #expect(data.valueDomain(for: .share) == 0 ... 100)
        #expect(ChartSystemData(trends: []).valueDomain(for: .cups) == 0 ... 200)
    }

    @Test("Given the sample data, when this screen's cups scale and Small multiples' shared scale are compared, then they are one domain")
    func cupsScaleSharedWithSmallMultiples() {
        let data = ChartSystemData(trends: CafeData.monthlyDrinkTrends)
        let smallMultiples = SmallMultiplesSummary(trends: CafeData.monthlyDrinkTrends, drinks: CafeData.trendDrinks)

        #expect(data.valueDomain(for: .cups) == smallMultiples.sharedDomain)
        #expect(data.valueDomain(for: .cups) == CafeDrinkStyle.trendCupsDomain(for: CafeData.monthlyDrinkTrends))
    }

    @Test("Given Latte's share, when the points are worked out, then each is its cups over all three drinks' cups")
    func sharePoints() throws {
        let data = ChartSystemData(trends: CafeData.monthlyDrinkTrends)
        let points = data.points(for: ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .share))

        #expect(points.count == 6)
        let august = try #require(points.last)
        #expect(abs(august.value - 561.0 / 1229.0 * 100) < 0.0001)
        #expect(august.cups == 561)
        #expect(Set(points.map(\.run)) == [0])
    }

    @Test("Given a month with no record, when a share line is worked out, then the months after it start a new run")
    func missingMonthBreaksTheLine() {
        let trends = CafeData.monthlyDrinkTrends.filter { !($0.drink == "Latte" && $0.month == CafeData.month(2)) }
        let points = ChartSystemData(trends: trends).points(for: ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .share))

        #expect(points.count == 5)
        #expect(points.map(\.run) == [0, 0, 1, 1, 1])
    }

    @Test("Given each chart, when its marked months are read, then they are the drink's best month in cups")
    func markedMonths() {
        let data = ChartSystemData(trends: CafeData.monthlyDrinkTrends)

        #expect(data.markedMonths(for: ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .cups)) == [CafeData.month(5)])
        #expect(data.markedMonths(for: ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .share)) == [CafeData.month(5)])
        #expect(data.markedMonths(for: ChartSystemChartSpec(drink: "Tea", months: 0 ..< 6, measure: .cups)) == [CafeData.month(4)])
    }

    @Test("Given a drink that sold nothing, when its cups chart is checked, then it has no marks; its share of zero still does")
    func zeroCupsHaveNoBars() {
        let data = ChartSystemData(trends: trends(withNo: "Tea"))

        #expect(!data.hasMarks(for: ChartSystemChartSpec(drink: "Tea", months: 0 ..< 6, measure: .cups)))
        #expect(data.hasMarks(for: ChartSystemChartSpec(drink: "Tea", months: 0 ..< 6, measure: .share)))
    }

    // MARK: Headlines

    @Test("Given each step, when the headline is written, then it names figures marked on the charts")
    func headlines() {
        #expect(viewModel(at: .period).headline(locale: locale) == "Latte peaked at 561 cups in August, and at 611 cups in December.")
        #expect(viewModel(at: .kindOfData).headline(locale: locale) == "Latte peaked at 561 cups in August, Tea at 588 cups in July.")
        #expect(viewModel(at: .measure).headline(locale: locale) == "Latte's best month, August with 561 cups, was 46% of all cups sold.")
    }

    @Test("Given no Tea sold, when the kind-of-data headline is written, then it says so instead of naming a peak")
    func headlineWithoutTea() {
        let viewModel = viewModel(at: .kindOfData, trends: trends(withNo: "Tea"))

        #expect(viewModel.headline(locale: locale) == "Latte peaked at 561 cups in August; no Tea was sold.")
    }

    @Test("Given no cups at all, when each headline is written, then none names a peak")
    func headlinesWithNoData() {
        let viewModel = ChartSystemViewModel(trends: [])

        #expect(viewModel.headline(locale: locale) == "No cups of Latte were sold in either period.")
    }

    @Test("Given two best months, when the measure headline is written, then both months and both shares are named")
    func tiedBestMonths() {
        let trends = CafeData.monthlyDrinkTrends.map {
            MonthlyDrinkCups(drink: $0.drink, month: $0.month, cups: $0.drink == "Latte" && $0.month == CafeData.month(0) ? 561 : $0.cups)
        }
        let viewModel = viewModel(at: .measure, trends: trends)

        #expect(viewModel.headline(locale: locale)
            == "Latte's best months, March and August with 561 cups each, were 51% and 46% of all cups sold.")
    }

    @Test("Given a step forward, when the announcement is written, then it says the step, what changed, then the headline")
    func announcement() {
        let viewModel = viewModel(at: .kindOfData)

        #expect(viewModel.announcement(locale: locale)
            == "Step 2 of 3. The second chart now shows Tea, in its own colour. Latte peaked at 561 cups in August, Tea at 588 cups in July.")
    }

    @Test("Given a German locale, when the headline is written, then its numbers and months are German")
    func germanHeadline() {
        let viewModel = viewModel(at: .period)

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")) == "Latte peaked at 561 cups in August, and at 611 cups in Dezember.")
    }

    @Test("Given each step, when the look-for sentence is written, then it names the colours the palette gives")
    func lookFor() {
        #expect(viewModel(at: .kindOfData).lookFor(locale: locale) == "Tea's bars are green, on the same 0 to 800 cups axis; Latte stays brown.")
    }

    // MARK: Snippets

    @Test("Given each step, when the snippets are read, then the pairs come first and then the step's own")
    func snippetsFollowTheStep() {
        #expect(viewModel(at: .period).snippets.map(\.name) == ["a-chart-design-system-pairs", "a-chart-design-system-one-style"])
        #expect(viewModel(at: .kindOfData).snippets.map(\.name) == ["a-chart-design-system-pairs", "a-chart-design-system-colour"])
        #expect(viewModel(at: .measure).snippets.map(\.name) == ["a-chart-design-system-pairs", "a-chart-design-system-mark"])
    }

    @Test("Given the app bundle, when its snippets are loaded, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for step in ChartSystemStep.allCases {
            for snippet in viewModel(at: step).snippets {
                #expect(store[snippet.name] != nil, "missing \(snippet.name)")
            }
        }
    }

    // MARK: Headings and descriptors

    @Test("Given each kind of chart, when its heading is written, then it names the drink, the measure and the months")
    func headings() {
        #expect(plain(ChartSystemWording.heading(ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .cups), locale: locale))
            == "Latte: cups a month, Mar – Aug 2026")
        #expect(plain(ChartSystemWording.heading(ChartSystemChartSpec(drink: "Latte", months: 6 ..< 12, measure: .share), locale: locale))
            == "Latte: share of all cups, Sep 2026 – Feb 2027")
    }

    @Test("Given a cups chart, when its descriptor is made, then it has separate bars, the shared scale and months written out")
    func cupsDescriptor() throws {
        let spec = ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .cups)
        let descriptor = ChartSystemChartDescriptor(spec: spec, data: ChartSystemData(trends: CafeData.monthlyDrinkTrends), locale: locale)
            .makeChartDescriptor()

        #expect(plain(descriptor.title) == "Latte: cups a month, Mar – Aug 2026")
        #expect(descriptor.summary == "6 months. Highest: August, 561 cups. Lowest: March, 512 cups.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "March 2026")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 800)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(descriptor.series.first?.name == "Latte")
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 6)
    }

    @Test("Given a share chart, when its descriptor is made, then it is one continuous line from 0 to 100 percent")
    func shareDescriptor() throws {
        let spec = ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .share)
        let descriptor = ChartSystemChartDescriptor(spec: spec, data: ChartSystemData(trends: CafeData.monthlyDrinkTrends), locale: locale)
            .makeChartDescriptor()

        #expect(descriptor.summary == "6 months. Highest: March and April, 49% of all cups. Lowest: July, 44% of all cups.")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 100)
        #expect(yAxis.valueDescriptionProvider(45.6) == "46%")
        #expect(descriptor.series.first?.name == "Latte, share of all cups")
        #expect(descriptor.series.first?.isContinuous == true)
    }

    @Test("Given no cups, when a descriptor is made, then its summary says nothing was sold")
    func emptyDescriptor() {
        let spec = ChartSystemChartSpec(drink: "Latte", months: 0 ..< 6, measure: .cups)
        let descriptor = ChartSystemChartDescriptor(spec: spec, data: ChartSystemData(trends: []), locale: locale).makeChartDescriptor()

        #expect(plain(descriptor.summary) == "No cups sold in Mar – Aug 2026.")
    }
}
