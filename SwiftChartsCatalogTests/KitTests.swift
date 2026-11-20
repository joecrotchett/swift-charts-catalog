@testable import SwiftChartsCatalog
import SwiftUI
import Testing

struct KitTests {
    @Test("Given one chart or a named chart of two, when the mistake note is written, then it names the chart only when there is one to name")
    func mistakeNote() {
        #expect(MistakeToggle.note(chart: nil) == "This is the mistake, shown on purpose.")
        #expect(MistakeToggle.note(chart: "") == "This is the mistake, shown on purpose.")
        #expect(MistakeToggle.note(chart: "lower") == "The lower chart is the mistake, shown on purpose.")
    }

    @Test("Given no title of its own, when a controls section is built, then it takes the app's default title")
    func controlsSectionTitle() {
        #expect(ControlsSection<EmptyView>.defaultTitle == "Try it")
    }

    // MARK: ChartAxis

    @Test("Given data that starts at zero, when the value axis is worked out, then its top is the largest value rounded up to the step the automatic axis draws")
    func roundedTopMatchesTheDrawnAxis() {
        // The tops the reviews saw drawn for these data tops.
        let drawn: [(Double, Double)] = [(164, 200), (219, 300), (309, 400), (282, 300), (261, 300), (240, 300), (57, 60), (11, 15), (42, 60), (9.000826, 10), (9.4958, 10)]
        for (dataTop, axisTop) in drawn {
            #expect(ChartAxis.roundedTop(for: [0, dataTop]) == axisTop, "data top \(dataTop)")
            #expect(ChartAxis.valueDomain(for: [dataTop / 2, dataTop]) == 0 ... axisTop)
        }
    }

    @Test("Given no data, only zeros, or values that are not finite, when the value axis is worked out, then it is never empty")
    func valueDomainIsNeverEmpty() {
        #expect(ChartAxis.valueDomain(for: [Double]()) == 0 ... 1)
        #expect(ChartAxis.valueDomain(for: [Int]()) == 0 ... 1)
        #expect(ChartAxis.valueDomain(for: [0, 0, 0]) == 0 ... 1)
        #expect(ChartAxis.valueDomain(for: [Double.nan, .infinity]) == 0 ... 1)
        #expect(ChartAxis.valueDomain(for: [150], includesZero: false) == 150 ... 200)
    }

    @Test("Given a line far from zero, or data below zero, when the value axis is worked out, then each end is rounded outward to the step")
    func valueDomainLeavingOutZeroOrBelowZero() {
        #expect(ChartAxis.valueDomain(for: [152, 219, 190], includesZero: false) == 140 ... 220)
        #expect(ChartAxis.valueDomain(for: [-305, 212]) == -400 ... 400)
        #expect(ChartAxis.valueDomain(for: [-40, -10]) == -40 ... 0)
    }

    @Test("Given a step of the screen's own, when the value axis is worked out, then that step is used")
    func valueDomainWithOwnStep() {
        #expect(ChartAxis.valueDomain(for: [164], step: 25) == 0 ... 175)
        #expect(ChartAxis.roundedTop(for: [164], step: 100) == 200)
        #expect(ChartAxis.valueDomain(for: [164], step: 0) == 0 ... 200)
    }

    @Test("Given a span, when the step is chosen, then it is 1, 2 or 5 times a power of ten splitting the span into at most four steps")
    func stepForSpan() {
        #expect(ChartAxis.step(forSpan: 164) == 50)
        #expect(ChartAxis.step(forSpan: 219) == 100)
        #expect(ChartAxis.step(forSpan: 200) == 50)
        #expect(ChartAxis.step(forSpan: 0.9) == 0.5)
        #expect(ChartAxis.step(forSpan: 0) == 1)
        #expect(ChartAxis.step(forSpan: -.infinity) == 1)
    }

    // MARK: Axis title, headline reserve, chart pair, stepper, snippet picker

    @Test("Given a short title, when the y axis title is chosen for each text size, then the short one is drawn from accessibility 4 up")
    func yAxisTitleShortensAtTheLargestSizes() {
        let full = CafeWording.waitAxisTitle, short = CafeWording.waitAxisShortTitle
        #expect(YAxisTitle.title(full, short: short, at: .large) == full)
        #expect(YAxisTitle.title(full, short: short, at: .accessibility3) == full)
        #expect(YAxisTitle.title(full, short: short, at: .accessibility4) == short)
        #expect(YAxisTitle.title(full, short: short, at: .accessibility5) == short)
        #expect(YAxisTitle.title(full, short: nil, at: .accessibility5) == full)
    }

    @Test("Given a reserved message, when the headline is laid out, then it is reserved at the standard sizes and not at the accessibility sizes")
    func headlineReserve() {
        #expect(ScreenHeadline.reserve("Longest", at: .large) == "Longest")
        #expect(ScreenHeadline.reserve("Longest", at: .xxxLarge) == "Longest")
        #expect(ScreenHeadline.reserve("Longest", at: .accessibility1) == nil)
        #expect(ScreenHeadline.reserve(nil, at: .large) == nil)
    }

    @Test("Given a pair's width, when the layout is chosen, then the charts go side by side only when each gets the minimum width")
    @MainActor
    func chartPairSideBySide() {
        let minimum = Layout.chartPairMinimumWidth
        // A catalog screen's panel on iPad: 720 readable, less the screen's and the panel's padding.
        #expect(!ChartPair<EmptyView, EmptyView>.isSideBySide(width: 656, minimumChartWidth: minimum, accessibilitySize: false))
        #expect(!ChartPair<EmptyView, EmptyView>.isSideBySide(width: 338, minimumChartWidth: minimum, accessibilitySize: false))
        #expect(ChartPair<EmptyView, EmptyView>.isSideBySide(width: 2 * minimum + Layout.sectionSpacing, minimumChartWidth: minimum, accessibilitySize: false))
        #expect(!ChartPair<EmptyView, EmptyView>.isSideBySide(width: 2000, minimumChartWidth: minimum, accessibilitySize: true))
        #expect(ChartPair<EmptyView, EmptyView>.isSideBySide(width: 656, minimumChartWidth: 240, accessibilitySize: false))
    }

    @Test("Given a screen's snippets, when the picker is chosen, then segments are tried only for two at most and never at the accessibility sizes")
    @MainActor
    func snippetPickerChoice() {
        #expect(SnippetPicker.mayUseSegments(count: 2, accessibilitySize: false))
        #expect(!SnippetPicker.mayUseSegments(count: 3, accessibilitySize: false))
        #expect(!SnippetPicker.mayUseSegments(count: 2, accessibilitySize: true))
    }

    // MARK: Drink and size styles

    @Test("Given every drink in the sample data, when its colour is looked up, then each has its own, and the first three keep theirs")
    func everyDrinkHasAColour() {
        let drinks = Set(CafeData.drinkSales.map(\.drink) + CafeData.manyOrderDrinks + CafeData.trendDrinks)
        #expect(drinks.isSubset(of: CafeDrinkStyle.allDrinks))
        #expect(Set(CafeDrinkStyle.allDrinks.map(CafeDrinkStyle.colour(for:))).count == CafeDrinkStyle.allDrinks.count)
        #expect(!CafeDrinkStyle.allDrinks.map(CafeDrinkStyle.colour(for:)).contains(.gray))
        #expect(CafeDrinkStyle.colour(for: "Latte") == Color(.sRGB, red: 0.714, green: 0.439, blue: 0.169))
        #expect(CafeDrinkStyle.allDrinks.map(CafeDrinkStyle.colourName(for:))
            == ["brown", "green", "purple", "rose", "petrol blue", "cornflower blue"])
        #expect(CafeDrinkStyle.drinks == CafeData.trendDrinks)
    }

    @Test("Given a chart's drinks, when the colour domain is made, then each drink is listed once in the chart's own order")
    func drinkDomain() {
        #expect(CafeDrinkStyle.domain(for: ["Tea", "Latte", "Tea", "Mocha"]) == ["Tea", "Latte", "Mocha"])
        #expect(CafeDrinkStyle.domain(for: CafeData.drinkSales.map(\.drink)) == ["Latte", "Tea", "Mocha", "Cocoa", "Americano"])
    }

    @Test("Given the cup sizes, when their colours are looked up, then each has its own, none a café's")
    func sizeColours() {
        #expect(Set(CafeData.drinkOrders.map(\.size)) == Set(CafeSizeStyle.sizes))
        let colours = CafeSizeStyle.sizes.map(CafeSizeStyle.colour(for:))
        #expect(Set(colours).count == 3)
        for colour in colours {
            #expect(!CafeSeriesStyle.stores.map(CafeSeriesStyle.colour(for:)).contains(colour))
            #expect(!CafeDrinkStyle.allDrinks.map(CafeDrinkStyle.colour(for:)).contains(colour))
        }
        #expect(CafeSizeStyle.colour(for: "Huge") == .gray)
    }

    /// The colour's grey under `.grayscale(1)`, 0 to 255, in the given appearance.
    private func grey(_ colour: Color, _ scheme: ColorScheme) -> Int {
        var environment = EnvironmentValues()
        environment.colorScheme = scheme
        let resolved = colour.resolve(in: environment)
        /// Resolved components are linear; the doc comments' greys weigh the gamma-encoded values, as design.md does.
        func encoded(_ linear: Float) -> Double {
            let value = Double(linear)
            return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
        }
        let weighted = 0.2126 * encoded(resolved.linearRed) + 0.7152 * encoded(resolved.linearGreen)
            + 0.0722 * encoded(resolved.linearBlue)
        return Int((weighted * 255).rounded())
    }

    @Test("Given four ordered categories, when their size colours are looked up, then they step evenly in grey in both appearances, the ends the sizes' own")
    func fourStepSizeColours() {
        let four = (0 ..< 4).map { CafeSizeStyle.colour(step: $0, of: 4) }
        #expect(four.map { grey($0, .light) } == [179, 146, 114, 81])
        #expect(four.map { grey($0, .dark) } == [105, 134, 165, 195])
        // The three-step form is unchanged.
        let three = CafeSizeStyle.sizes.map(CafeSizeStyle.colour(for:))
        #expect(three.map { grey($0, .light) } == [179, 136, 81])
        #expect(three.map { grey($0, .dark) } == [105, 155, 195])
        let domain = ["1 cup", "2 cups", "3 cups", "4 cups"]
        #expect(domain.map { grey(CafeSizeStyle.colour(for: $0, in: domain), .light) } == [179, 146, 114, 81])
        #expect(CafeSizeStyle.colour(for: "5 cups", in: domain) == .gray)
        #expect(CafeSizeStyle.colour(step: 0, of: 5) == .gray)
        #expect(CafeSizeStyle.colour(step: 4, of: 4) == .gray)
    }
}
