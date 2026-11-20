import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct MarkLabelsTests {
    private let english = Locale(identifier: "en_US")
    private let sales = [
        DrinkSales(drink: "Latte", cups: 128),
        DrinkSales(drink: "Tea", cups: 164),
        DrinkSales(drink: "Cocoa", cups: 57),
    ]

    // MARK: Positions and placement

    @Test("Given a new screen, when it opens, then the label sits on top of each bar, centred")
    func startsAboveTheBar() {
        let model = MarkLabelsViewModel(sales: sales)

        #expect(model.position == .top)
        #expect(model.alignment == .center)
        #expect(model.placement == .outside)
    }

    @Test("Given the ten positions, when they are listed, then there are ten and only overlay is inside the bar")
    func tenPositionsOneInside() {
        #expect(MarkLabelsPosition.allCases.count == 10)
        #expect(MarkLabelsPosition.allCases.filter(\.isInside) == [.overlay])
        #expect(MarkLabelsPosition.allCases.filter(\.isBelow) == [.bottom, .bottomLeading, .bottomTrailing])
        #expect(MarkLabelsPosition.allCases.filter(\.isBeside)
            == [.leading, .trailing, .topLeading, .topTrailing, .bottomLeading, .bottomTrailing])
    }

    @Test("Given a label outside the bar, when Inside is chosen, then the position becomes overlay")
    func insideMeansOverlay() {
        let model = MarkLabelsViewModel(sales: sales)

        model.placement = .inside

        #expect(model.position == .overlay)
        #expect(model.placement == .inside)
    }

    @Test("Given a label moved to the leading side and then inside, when Outside is chosen, then it returns to the leading side")
    func outsideReturnsToLastPosition() {
        let model = MarkLabelsViewModel(sales: sales)
        model.position = .leading
        model.placement = .inside

        model.placement = .outside

        #expect(model.position == .leading)
    }

    @Test("Given the overlay position chosen from the menu, when the placement is read, then it says inside")
    func overlayFromMenuIsInside() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .overlay

        #expect(model.placement == .inside)
    }

    @Test("Given a new alignment, when it is chosen, then the position does not change")
    func alignmentChangesOneThing() {
        let model = MarkLabelsViewModel(sales: sales)
        model.position = .trailing

        model.alignment = .bottomLeading

        #expect(model.position == .trailing)
        #expect(model.alignment == .bottomLeading)
    }

    // MARK: Snippets

    @Test("Given a label outside the bar, when the snippets are listed, then they are the annotation and the outside label")
    func outsideSnippets() {
        let model = MarkLabelsViewModel(sales: sales)

        #expect(model.snippets.map(\.name) == ["labelling-a-mark-annotation", "labelling-a-mark-label-outside"])
    }

    @Test("Given a label inside the bar, when the snippets are listed, then they are the annotation and the inside label")
    func insideSnippets() {
        let model = MarkLabelsViewModel(sales: sales)
        model.position = .overlay

        #expect(model.snippets.map(\.name) == ["labelling-a-mark-annotation", "labelling-a-mark-label-inside"])
    }

    @Test("Given the app bundle, when the snippets are read, then every one this screen can show exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = ["labelling-a-mark-annotation", "labelling-a-mark-label-outside", "labelling-a-mark-label-inside"]

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
    }

    // MARK: Note and announcements

    @Test("Given a label under the bars, when the notes are read, then one says the scale runs below zero")
    func belowShowsNote() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .bottom

        #expect(model.notes(isAccessibilityTextSize: false) == [
            "A bar that rises from zero has no room under it, so the chart extends its y scale below zero to fit "
                + "the labels, leaving an empty negative band under every bar. Fixing the y scale's domain stops that, "
                + "but the labels are then drawn over the drink names: put the label above or inside the bar.",
        ])
    }

    @Test("Given a label off a bottom corner, when the notes are read, then they say the scale, the neighbouring bar and the alignment")
    func bottomCornerShowsBothNotes() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .bottomTrailing

        let notes = model.notes(isAccessibilityTextSize: false)
        #expect(notes.count == 3)
        #expect(notes.contains { $0.contains("below zero") })
        #expect(notes.contains { $0.contains("next bar") })
        #expect(notes.contains { $0.contains("alignment changes nothing") })
    }

    @Test("Given each position, when the notes are read, then only the four corners say the alignment changes nothing")
    func cornerNoteOnlyAtCorners() {
        let model = MarkLabelsViewModel(sales: sales)

        for position in MarkLabelsPosition.allCases {
            model.position = position
            let saysAlignment = model.notes(isAccessibilityTextSize: false).contains { $0.contains("alignment changes nothing") }
            let isCorner = [MarkLabelsPosition.topLeading, .topTrailing, .bottomLeading, .bottomTrailing].contains(position)
            #expect(saysAlignment == isCorner, "\(position)")
        }
    }

    @Test("Given a label above the bar, at any text size, when the notes are read, then there are none")
    func noNotesAbove() {
        let model = MarkLabelsViewModel(sales: sales)

        for position in [MarkLabelsPosition.automatic, .top] {
            model.position = position
            #expect(model.notes(isAccessibilityTextSize: false).isEmpty)
            #expect(model.notes(isAccessibilityTextSize: true).isEmpty)
        }
    }

    @Test("Given a label inside the bar, when the notes are read, then only an accessibility text size says it is cut short")
    func insideNoteOnlyAtAccessibilitySizes() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .overlay

        #expect(model.notes(isAccessibilityTextSize: false).isEmpty)
        #expect(model.notes(isAccessibilityTextSize: true).map { $0.contains("cut short") } == [true])
    }

    @Test("Given a label moved under the bars, when the change is announced, then it says the scale changed, then the headline")
    func movingBelowIsAnnounced() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .bottom

        #expect(
            model.announcement(from: .top, locale: english)
                == "The labels are under the bars, and the scale now runs below zero to fit them. Tea sold the most: 164 cups."
        )
    }

    @Test("Given a label moved back from under the bars, when the change is announced, then it says the scale starts at zero")
    func movingBackIsAnnounced() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .overlay

        #expect(model.announcement(from: .bottomLeading, locale: english) == "The scale starts at zero again. Tea sold the most: 164 cups.")
    }

    @Test("Given a label moved between two places that leave the scale alone, when the change is checked, then nothing is announced")
    func movingLabelsOnlyIsQuiet() {
        let model = MarkLabelsViewModel(sales: sales)

        model.position = .leading
        #expect(model.announcement(from: .top, locale: english) == nil)
        model.position = .bottomLeading
        #expect(model.announcement(from: .bottom, locale: english) == nil)
    }

    // MARK: Headline and empty data

    @Test("Given drink sales, when the headline is written, then it names the best seller and the figure on its bar")
    func headlineNamesBestSeller() {
        #expect(MarkLabelsSummary(sales: sales).headline(locale: english) == "Tea sold the most: 164 cups.")
    }

    @Test("Given two drinks tied for the most, when the headline is written, then it names both")
    func tieNamesBoth() {
        let tied = [DrinkSales(drink: "Mocha", cups: 90), DrinkSales(drink: "Tea", cups: 90)]

        #expect(MarkLabelsSummary(sales: tied).headline(locale: english) == "Mocha and Tea sold the most: 90 cups.")
    }

    @Test("Given one cup on the best seller, when the headline and summary are written, then the counts agree in number")
    func countsAgreeInNumber() {
        let summary = MarkLabelsSummary(sales: [DrinkSales(drink: "Tea", cups: 1)])

        #expect(summary.headline(locale: english) == "Tea sold the most: 1 cup.")
        #expect(summary.audioGraphSummary(locale: english) == "1 drink, 1 cup in total. Most: Tea, 1 cup. Fewest: Tea, 1 cup.")
    }

    @Test("Given a German locale, when the headline is written, then the number is written the German way")
    func headlineTakesLocale() {
        let summary = MarkLabelsSummary(sales: [DrinkSales(drink: "Tea", cups: 1200)])

        #expect(summary.headline(locale: Locale(identifier: "de_DE")).contains("1.200"))
    }

    @Test("Given no sales or only zeros, when the chart's words are written, then they say nothing sold and the controls are off")
    func emptyAndZeroSaySo() {
        for empty in [[], [DrinkSales(drink: "Tea", cups: 0)]] {
            let model = MarkLabelsViewModel(sales: empty)
            model.position = .bottom

            #expect(!model.hasData)
            #expect(model.summary.headline(locale: english) == "No cups sold yet today.")
            #expect(model.summary.audioGraphSummary(locale: english) == "No cups sold yet today.")
            #expect(model.notes(isAccessibilityTextSize: true).isEmpty)
            #expect(model.announcement(from: .top, locale: english) == nil)
        }
    }

    // MARK: Chart descriptor

    @Test("Given drink sales, when the descriptor is made, then it has a title, the summary and one named series of separate bars")
    func descriptorDescribesTheChart() throws {
        let descriptor = MarkLabelsViewModel(sales: sales).descriptor(locale: english).makeChartDescriptor()
        let series = try #require(descriptor.series.first)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)

        #expect(descriptor.title == "Cups sold today, by drink")
        #expect(descriptor.summary == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups.")
        #expect(descriptor.series.count == 1)
        #expect(series.name == CafeWording.harbour)
        #expect(!series.isContinuous)
        #expect(series.dataPoints.count == sales.count)
        #expect(xAxis.title == CafeWording.drink)
        #expect(xAxis.categoryOrder == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given drink sales in any order, when the screen is built, then the bars are ranked most cups first")
    func barsAreRanked() {
        let model = MarkLabelsViewModel(sales: sales)

        #expect(model.sales.map(\.drink) == ["Tea", "Latte", "Cocoa"])
    }

    @Test("Given two drinks tied, when they are ranked, then they keep their order in the data")
    func rankingKeepsTies() {
        let tied = [
            DrinkSales(drink: "Cocoa", cups: 10),
            DrinkSales(drink: "Mocha", cups: 90),
            DrinkSales(drink: "Tea", cups: 90),
        ]

        #expect(MarkLabelsSummary.ranked(tied).map(\.drink) == ["Mocha", "Tea", "Cocoa"])
    }

    @Test("Given a label under the bars, when the descriptor is made, then its summary says the y axis starts below zero")
    func descriptorSaysBelowZero() {
        let model = MarkLabelsViewModel(sales: sales)
        let above = model.descriptor(locale: english).makeChartDescriptor()
        #expect(above.summary?.contains("below zero") == false)

        model.position = .bottomLeading
        let below = model.descriptor(locale: english).makeChartDescriptor()

        #expect(below.summary == "3 drinks, 349 cups in total. Most: Tea, 164 cups. Fewest: Cocoa, 57 cups. "
            + "The labels are under the bars, so the y axis starts below zero, under an empty band.")
    }

    @Test("Given drink sales, when the descriptor's value axis is read, then it runs from zero to the drawn top and says cups")
    func descriptorValueAxis() throws {
        let yAxis = try #require(MarkLabelsViewModel(sales: sales).descriptor(locale: english).makeChartDescriptor().yAxis)

        #expect(yAxis.title == CafeWording.cupsAxisTitle)
        // 164 cups rounds up to 200, the domain the chart is given.
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
        #expect(yAxis.valueDescriptionProvider(.nan).isEmpty)
    }
}
