import Charts
import SwiftUI

/// One colour for each drink in the sample data, shared by every screen that draws drinks as series or categories
/// coloured by drink, so a drink looks the same on each: the three of `CafeData.monthlyDrinkTrends`, the five of
/// `CafeData.drinkSales` and the four of `CafeData.manyOrderDrinks`. A screen whose subject is the colours themselves
/// keeps its own. Adopting it:
/// ```swift
/// Chart(sales) { BarMark(...).foregroundStyle(by: .value(CafeWording.drink, $0.drink)) }
///     .chartForegroundStyleScale(domain: CafeDrinkStyle.domain(for: sales.map(\.drink)), mapping: CafeDrinkStyle.colour(for:))
/// ```
/// or `.foregroundStyle(CafeDrinkStyle.colour(for: drink))` on a mark coloured directly, and `colourName(for:)` when a
/// sentence tells a reader what to look for.
///
/// The first three are chosen for meaning where a drink has a colour people know (Latte the brown of milky coffee,
/// Tea the green of the leaf), and Mocha takes purple, the hue furthest from both, because a chocolate brown could not
/// be told from Latte's. The other three have no colour people know and take the hues left furthest from those and
/// from each other: Americano a petrol blue, Cocoa a rose (a chocolate brown, like Mocha's, would be Latte's), and
/// Espresso a cornflower blue, which never shares a chart with Americano (they are in different data sets) and is
/// lighter and less green than its petrol. None is the café blue (`.blue`, Harbour) or orange (Station).
///
/// All six are matched in weight: each is 122 of 255 under `.grayscale(1)` (0.2126R′ + 0.7152G′ + 0.0722B′, the
/// measure `design.md` gives; the first three were also sampled from a render), so no drink looks more important than
/// another, and each is 3.6 to 4.0:1 against the light panel and 4.3 to 4.7:1 against the dark one, so one colour
/// serves both appearances. Tea's green leans to teal so that it stays apart from Latte's brown for red–green colour
/// blindness. Equal weights remove the lightness cue a colour-blind reader uses, and with five drinks some pairs
/// merge under a red–green filter whatever the hues (Americano with Mocha, Cocoa with Tea, measured with a
/// deuteranopia simulation), so a chart of drinks also labels them directly or keeps its legend in the same order.
nonisolated enum CafeDrinkStyle {
    /// The trend drinks in the order the charts list them, the domain of the charts of `monthlyDrinkTrends` and
    /// `dashboardSales`.
    static let drinks = CafeData.trendDrinks

    /// Every drink with a colour: the trend drinks, then the rest of `CafeData.drinkSales`, then Espresso from
    /// `manyOrderDrinks`. A chart's legend lists its own drinks in its own data's order (`domain(for:)`).
    static let allDrinks = ["Latte", "Tea", "Mocha", "Cocoa", "Americano", "Espresso"]

    /// In the order of `allDrinks`: Latte #B6702B, Tea #259567, Mocha #B063BF, Cocoa #D75E7C, Americano #1E91A8,
    /// Espresso #4780D1.
    private static let colours: [Color] = [
        Color(.sRGB, red: 0.714, green: 0.439, blue: 0.169),
        Color(.sRGB, red: 0.145, green: 0.584, blue: 0.404),
        Color(.sRGB, red: 0.690, green: 0.388, blue: 0.749),
        Color(.sRGB, red: 0.843, green: 0.369, blue: 0.486),
        Color(.sRGB, red: 0.118, green: 0.569, blue: 0.659),
        Color(.sRGB, red: 0.278, green: 0.502, blue: 0.820),
    ]
    private static let colourNames = ["brown", "green", "purple", "rose", "petrol blue", "cornflower blue"]

    /// The drink's colour, or grey for a drink without one.
    static func colour(for drink: String) -> Color {
        guard let index = allDrinks.firstIndex(of: drink), colours.indices.contains(index) else { return .gray }
        return colours[index]
    }

    /// The colour's everyday name, for a sentence that tells a reader what to look for.
    static func colourName(for drink: String) -> String {
        guard let index = allDrinks.firstIndex(of: drink), colourNames.indices.contains(index) else { return "grey" }
        return colourNames[index]
    }

    /// A colour scale's domain for the drinks a chart draws: each drink once, in the order given (the chart's data
    /// order), so the legend lists them as the chart does.
    static func domain(for drinks: [String]) -> [String] {
        drinks.reduce(into: []) { domain, drink in
            if !domain.contains(drink) { domain.append(drink) }
        }
    }

    /// The step a cups scale of the drink trends is rounded to.
    static let trendCupsStep = 200.0

    /// The one cups scale for every chart of `CafeData.monthlyDrinkTrends` that compares heights (A chart design
    /// system, and Small multiples on its shared scale): zero to the most any drink sold in a month, rounded up to the
    /// next `trendCupsStep`, so the same cups are drawn the same height on each. 0 to 800 for the sample trends
    /// (December's 611 lattes). Set it on the chart and give it to the descriptor:
    /// ```swift
    /// let domain = CafeDrinkStyle.trendCupsDomain(for: trends)
    /// Chart(trends) { ... }.chartYScale(domain: domain)
    /// ```
    static func trendCupsDomain(for trends: [MonthlyDrinkCups]) -> ClosedRange<Double> {
        ChartAxis.valueDomain(for: trends.map { Double($0.cups) }, step: trendCupsStep)
    }
}

/// One colour for each cup size, shared by every screen that colours Small, Medium and Large (`CafeData.drinkOrders`).
/// Sizes are another kind of data from cafés and drinks, so they take none of their colours (`design.md`: a different
/// kind of data takes a different colour): not the café blue and orange the automatic palette gave them, and no drink's
/// hue. Adopting it:
/// ```swift
/// Chart(orders) { BarMark(...).foregroundStyle(by: .value(CafeWording.size, $0.size)) }
///     .chartForegroundStyleScale(domain: CafeSizeStyle.sizes, mapping: CafeSizeStyle.colour(for:))
/// ```
///
/// Sizes are ordered, so they are one hue (a sage green) in three steps of lightness, Small lightest and Large
/// heaviest against the background in both appearances: the order is visible at a glance, survives `.grayscale(1)`
/// and colour blindness (greys 179, 136 and 81 of 255 in light; 105, 155 and 195 in dark, where Large is the lightest
/// so that it is still the one that stands out against the dark panel), and needs no legend lookup to tell which end is
/// which. Against the panel each step is 2.1, 3.4 and 7.8:1 in light and 3.2, 6.3 and 9.7:1 in dark.
///
/// Ordered categories that come in four (order sizes of one to four cups) take the same hue in four steps:
/// `colour(for:in:)` with the four in their order, or `colour(step:of:)`.
nonisolated enum CafeSizeStyle {
    /// The sizes, smallest first: the order of the data and of the legend.
    static let sizes = ["Small", "Medium", "Large"]

    /// In the order of `sizes`, for the light and the dark appearance.
    private static let light: [(Double, Double, Double)] = [(0.639, 0.741, 0.498), (0.463, 0.580, 0.298), (0.275, 0.345, 0.176)]
    private static let dark: [(Double, Double, Double)] = [(0.357, 0.447, 0.231), (0.525, 0.659, 0.341), (0.718, 0.796, 0.604)]

    /// The four-step form, for ordered categories that come in four (order sizes of one to four cups): the same sage
    /// hue, its ends the three-step form's Small and Large and two new steps evenly between them. Greys under
    /// `.grayscale(1)` 179, 146, 114 and 81 of 255 in light; 105, 134, 165 and 195 in dark, neighbours 11 to 14 apart
    /// in CIE lightness (L*), so neighbours stay apart in greyscale and without hue. Against the panel
    /// (`secondarySystemGroupedBackground`, white and #1C1C1E) each step is 2.1, 3.1, 4.7 and 7.8:1 in light and 3.2,
    /// 4.8, 7.0 and 9.7:1 in dark (WCAG relative luminance, worked out from the sRGB values below).
    private static let fourLight: [(Double, Double, Double)] = [light[0], (0.494, 0.619, 0.319), (0.385, 0.483, 0.249), light[2]]
    private static let fourDark: [(Double, Double, Double)] = [dark[0], (0.456, 0.572, 0.295), (0.571, 0.692, 0.402), dark[2]]

    /// The size's colour, adapting to the appearance, or grey for a size outside the three.
    static func colour(for size: String) -> Color {
        guard let index = sizes.firstIndex(of: size) else { return .gray }
        return colour(step: index, of: sizes.count)
    }

    /// Step `step` (from 0, lightest against the background first) of the ordered ramp for `count` categories:
    /// the three sizes' colours for three, the four-step form for four. Grey for any other count or a step outside it.
    static func colour(step: Int, of count: Int) -> Color {
        let ramp: (light: [(Double, Double, Double)], dark: [(Double, Double, Double)])
        switch count {
        case 3: ramp = (light, dark)
        case 4: ramp = (fourLight, fourDark)
        default: return .gray
        }
        guard ramp.light.indices.contains(step) else { return .gray }
        let lightRGB = ramp.light[step], darkRGB = ramp.dark[step]
        return Color(UIColor { traits in
            let rgb = traits.userInterfaceStyle == .dark ? darkRGB : lightRGB
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        })
    }

    /// An ordered category's colour by its place in `domain` (three or four categories, in their order), for a
    /// colour scale's mapping:
    /// ```swift
    /// .chartForegroundStyleScale(domain: domain) { CafeSizeStyle.colour(for: $0, in: domain) }
    /// ```
    static func colour(for value: String, in domain: [String]) -> Color {
        guard let index = domain.firstIndex(of: value) else { return .gray }
        return colour(step: index, of: domain.count)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        ForEach([false, true], id: \.self) { isGrey in
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                ForEach(CafeDrinkStyle.allDrinks, id: \.self) { drink in
                    Label {
                        Text("\(drink), \(CafeDrinkStyle.colourName(for: drink))")
                    } icon: {
                        RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                            .fill(CafeDrinkStyle.colour(for: drink))
                            .frame(width: Layout.sectionSpacing, height: Layout.sectionSpacing)
                    }
                }
                HStack(spacing: Layout.itemSpacing) {
                    ForEach(0 ..< 4, id: \.self) { step in
                        RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                            .fill(CafeSizeStyle.colour(step: step, of: 4))
                            .frame(width: Layout.sectionSpacing, height: Layout.sectionSpacing)
                    }
                }
                HStack(spacing: Layout.itemSpacing) {
                    ForEach(CafeSizeStyle.sizes, id: \.self) { size in
                        Label {
                            Text(size)
                        } icon: {
                            RoundedRectangle(cornerRadius: Layout.badgeCornerRadius)
                                .fill(CafeSizeStyle.colour(for: size))
                                .frame(width: Layout.sectionSpacing, height: Layout.sectionSpacing)
                        }
                    }
                }
            }
            .grayscale(isGrey ? 1 : 0)
        }
    }
    .padding()
}
