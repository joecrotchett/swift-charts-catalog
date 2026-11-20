import Accessibility
import CoreGraphics
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct PlotAreaViewTests {
    private let english = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    @Test("Given a new screen, when it opens, then the label is placed with chartBackground")
    func startsInBackground() {
        #expect(PlotAreaViewViewModel().placement == .background)
    }

    @Test("Given the background placement, when the code is shown, then it is the background snippet and the label")
    func backgroundSnippets() {
        let viewModel = PlotAreaViewViewModel(sales: sales)

        #expect(viewModel.snippets.map(\.name) == [
            "a-view-in-the-plot-area-background", "a-view-in-the-plot-area-hole-label",
        ])
    }

    @Test("Given the overlay placement, when the code is shown, then it is the overlay snippet and the label")
    func overlaySnippets() {
        let viewModel = PlotAreaViewViewModel(sales: sales)
        viewModel.placement = .overlay

        #expect(viewModel.snippets.map(\.name) == [
            "a-view-in-the-plot-area-overlay", "a-view-in-the-plot-area-hole-label",
        ])
    }

    @Test("Given the app's bundle, when its snippets are read, then every snippet the screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = PlotAreaViewViewModel(sales: sales)
        var names = viewModel.snippets.map(\.name)
        viewModel.placement = .overlay
        names += viewModel.snippets.map(\.name)

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    @Test("Given drink sales, when they become sectors, then they run largest first and zeros are left out")
    func sharesAreRanked() {
        let withZero = sales + [DrinkSales(drink: "Mocha", cups: 0)]

        #expect(PlotAreaViewSummary(sales: withZero, locale: english).shares.map(\.drink) == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given two drinks tied, when they are ranked, then they keep the data's order")
    func tieKeepsDataOrder() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Cocoa", cups: 40), DrinkSales(drink: "Tea", cups: 90)]

        #expect(PlotAreaViewSummary.ranked(tied).map(\.drink) == ["Mocha", "Tea", "Cocoa"])
    }

    @Test("Given either placement, when the headline is written, then it is the same and names the best seller")
    func headlineIgnoresPlacement() {
        let viewModel = PlotAreaViewViewModel(sales: sales)
        let background = viewModel.summary(locale: english).headline
        viewModel.placement = .overlay
        let overlay = viewModel.summary(locale: english).headline

        #expect(background == "Tea sold the most: 164 cups.")
        #expect(overlay == background)
    }

    @Test("Given a tie for most sold, when the headline and label are written, then both drinks are named and highlighted")
    func tieNamesBoth() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90), DrinkSales(drink: "Cocoa", cups: 1)]
        let summary = PlotAreaViewSummary(sales: tied, locale: english)

        #expect(summary.headline == "Mocha and Tea sold the most: 90 cups.")
        #expect(summary.bestSellerNames == "Mocha and Tea")
        #expect(summary.shares.filter(summary.isHighlighted).map(\.drink) == ["Mocha", "Tea"])
    }

    @Test("Given one cup sold, when the headline is written, then the count agrees in number")
    func singleCup() {
        let summary = PlotAreaViewSummary(sales: [DrinkSales(drink: "Tea", cups: 1)], locale: english)

        #expect(summary.headline == "Tea sold the most: 1 cup.")
    }

    @Test("Given no sales or only zeros, when the summary is written, then there are no sectors and the headline says so")
    func noSales() {
        for empty in [[], [DrinkSales(drink: "Tea", cups: 0)]] {
            let summary = PlotAreaViewSummary(sales: empty, locale: english)

            #expect(summary.shares.isEmpty)
            #expect(summary.headline == "No cups sold yet today.")
            #expect(summary.audioGraphSummary == "No cups sold yet today.")
            #expect(PlotAreaViewViewModel(sales: empty).hasData == false)
        }
    }

    @Test("Given a German locale, when numbers are written, then they use its separators")
    func germanLocale() {
        let summary = PlotAreaViewSummary(sales: [DrinkSales(drink: "Tea", cups: 1234), DrinkSales(drink: "Cocoa", cups: 766)], locale: Locale(identifier: "de_DE"))

        #expect(summary.headline == "Tea sold the most: 1.234 cups.")
    }

    @Test("Given a sector, when its element value is written, then it gives cups and the share of the day")
    func sectorValue() throws {
        let summary = PlotAreaViewSummary(sales: sales, locale: english)
        let tea = try #require(summary.shares.first)

        #expect(summary.sectorValue(tea) == "164 cups, 47% of the day")
    }

    @Test("Given a wide plot frame, when the hole is laid out, then it is centred on the plot and sized from its shorter side")
    func holeLayout() {
        let layout = PlotAreaViewSummary.holeLayout(in: CGRect(x: 10, y: 20, width: 300, height: 200))
        let holeRadius = 100 * PlotAreaViewMetrics.innerRadiusRatio

        #expect(layout.center == CGPoint(x: 160, y: 120))
        #expect(abs(layout.labelSide - holeRadius * 2.squareRoot()) < 0.001)
        #expect(abs(layout.discDiameter - 200 * PlotAreaViewMetrics.discRatio) < 0.001)
        #expect(layout.labelSide < 2 * holeRadius)
        #expect(layout.discDiameter > 2 * holeRadius)
    }

    @Test("Given an empty plot frame, when the hole is laid out, then nothing has negative size")
    func emptyHoleLayout() {
        let layout = PlotAreaViewSummary.holeLayout(in: .zero)

        #expect(layout.labelSide == 0)
        #expect(layout.discDiameter == 0)
    }

    @Test("Given each placement, when the explanation is written, then it says which layer the label is on")
    func explanationFollowsPlacement() {
        let viewModel = PlotAreaViewViewModel(sales: sales)
        let background = viewModel.explanation(isLabelShown: true)
        viewModel.placement = .overlay
        let overlay = viewModel.explanation(isLabelShown: true)

        #expect(background.contains("behind the sectors"))
        #expect(background.contains("hidden from VoiceOver"))
        #expect(overlay.contains("in front of the sectors"))
        #expect(overlay.contains("VoiceOver reads the label"))
    }

    @Test("Given an accessibility text size, when the explanation is written, then it says the label is left out and does not mention it otherwise")
    func explanationAtLargeText() {
        let viewModel = PlotAreaViewViewModel(sales: sales)
        viewModel.placement = .overlay
        let text = viewModel.explanation(isLabelShown: false)

        #expect(text.contains("too small for the label"))
        #expect(!text.contains("VoiceOver reads the label"))
        #expect(!text.contains("the label sits"))
        #expect(text.contains("the disc sits in the middle of the ring"))
        #expect(text.contains("plotFrame"))
    }

    @Test("Given the label drawn, when the explanation is written, then it says the label sits in the middle of the hole")
    func explanationWithLabel() {
        for placement in PlotAreaViewPlacement.allCases {
            let viewModel = PlotAreaViewViewModel(sales: sales)
            viewModel.placement = placement
            let text = viewModel.explanation(isLabelShown: true)

            #expect(text.contains("plotFrame"))
            #expect(text.contains("the label sits in the middle of the hole"))
            #expect(!text.contains("too small"))
        }
    }

    @Test("Given no sales, when the explanation is written, then it states what plotFrame is and says nothing about the hole")
    func explanationWithNoData() {
        for isLabelShown in [true, false] {
            let text = PlotAreaViewViewModel(sales: []).explanation(isLabelShown: isLabelShown)

            #expect(text.contains("plotFrame"))
            // With a leading space, so "the whole chart" does not count as the hole.
            for word in [" hole", " disc", " ring", "label sits", "sectors"] {
                #expect(!text.contains(word), "mentions \(word)")
            }
        }
    }

    @Test("Given sales, when the chart descriptor is made, then it names the drinks, the café and the values with units")
    func descriptor() throws {
        let descriptor = PlotAreaViewChartDescriptor(summary: PlotAreaViewSummary(sales: sales, locale: english))
            .makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups sold today at the Harbour café, by drink")
        #expect(descriptor.summary == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Cocoa"])
        // A donut runs from 0 to the total, of which each sector is a share.
        #expect(yAxis.range == 0 ... 349)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.map(\.name) == ["Harbour"])
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 3)
    }
}
