import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct LabelsNotReadTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the default state, when the screen opens, then the labels are on a Plot")
    func defaultIsFixed() {
        #expect(LabelsNotReadViewModel().isShowingMistake == false)
    }

    @Test("Given labels on a Plot, when predicting, then each segment is read by its own label and value")
    func plotElements() {
        let model = LabelsNotReadViewModel()
        let elements = model.predictedElements(locale: english)
        // The order read on iOS 27: bar by bar, each from its bottom segment up.
        #expect(elements.map(\.spoken) == [
            "Latte, Small, 34 cups", "Latte, Medium, 58 cups", "Latte, Large, 36 cups",
            "Tea, Small, 71 cups", "Tea, Medium, 62 cups", "Tea, Large, 31 cups",
            "Mocha, Small, 22 cups", "Mocha, Medium, 41 cups", "Mocha, Large, 29 cups",
        ])
    }

    @Test("Given labels on bare segments, when predicting, then each bar is read as its total and size count")
    func ignoredElements() {
        let model = LabelsNotReadViewModel(isShowingMistake: true)
        let spoken = model.predictedElements(locale: english).map(\.spoken)
        #expect(spoken == [
            "Latte, total 128, 3 Sizes",
            "Tea, total 164, 3 Sizes",
            "Mocha, total 92, 3 Sizes",
        ])
    }

    @Test("Given each setting, when reading the headline, then it counts the elements read")
    func headlines() {
        let model = LabelsNotReadViewModel()
        #expect(model.headline(locale: english)
            == "VoiceOver reads 9 elements, one per segment, each by the label on its Plot.")
        model.isShowingMistake = true
        #expect(model.headline(locale: english)
            == "VoiceOver reads 3 elements, one per bar, and none of the 9 labels on the segments.")
    }

    @Test("Given one segment, when reading the headline, then the counts agree in number")
    func singular() {
        let model = LabelsNotReadViewModel(orders: [DrinkOrder(drink: "Tea", size: "Small", cups: 1)])
        #expect(model.headline(locale: english)
            == "VoiceOver reads 1 element, one per segment, each by the label on its Plot.")
        #expect(model.predictedElements(locale: english).map(\.spoken) == ["Tea, Small, 1 cup"])
        model.isShowingMistake = true
        #expect(model.predictedElements(locale: english).map(\.spoken) == ["Tea, total 1, 1 Size"])
    }

    @Test("Given no cups or only zeros, when reading the headline, then the chart is empty and says so")
    func emptyAndZeros() {
        let zeros = LabelsNotReadViewModel(orders: [DrinkOrder(drink: "Tea", size: "Small", cups: 0)])
        #expect(zeros.isEmpty)
        #expect(zeros.headline(locale: english) == "No cups sold yet, so there is nothing for VoiceOver to read.")
        #expect(LabelsNotReadViewModel(orders: []).predictedElements(locale: english).isEmpty)
    }

    @Test("Given a segment of zero cups, when drawing, then it is left out of the elements and the counts")
    func zeroSegmentLeftOut() {
        let model = LabelsNotReadViewModel(orders: [
            DrinkOrder(drink: "Tea", size: "Small", cups: 10), DrinkOrder(drink: "Tea", size: "Large", cups: 0),
        ])
        #expect(model.drawnOrders.count == 1)
        model.isShowingMistake = true
        #expect(model.predictedElements(locale: english).map(\.spoken) == ["Tea, total 10, 1 Size"])
    }

    @Test("Given a toggle, when it changes, then the announcement says what changed and then the headline")
    func announcement() {
        let model = LabelsNotReadViewModel()
        model.isShowingMistake = true
        #expect(model.changeAnnouncement(locale: english)
            == "Labels moved onto the bare segments. " + model.headline(locale: english))
        model.isShowingMistake = false
        #expect(model.changeAnnouncement(locale: english)
            == "Labels moved onto a Plot around each segment. " + model.headline(locale: english))
    }

    @Test("Given each setting, when choosing snippets, then they follow the toggle and exist in the bundle")
    func snippets() throws {
        let store = try SnippetStore()
        let model = LabelsNotReadViewModel()
        #expect(model.snippetNames == ["labels-not-read-plot", "labels-not-read-identity"])
        model.isShowingMistake = true
        #expect(model.snippetNames == ["labels-not-read-bare", "labels-not-read-identity"])
        for name in ["labels-not-read-bare", "labels-not-read-plot", "labels-not-read-identity"] {
            #expect(store[name] != nil)
        }
    }

    @Test("Given the default data, when reading the value axis, then it is rounded up to the next 50 cups")
    func domain() {
        #expect(LabelsNotReadViewModel().valueDomainTop == 200)
    }

    @Test("Given the default data, when making the descriptor, then it names every size and gives totals")
    func descriptor() throws {
        let model = LabelsNotReadViewModel()
        let descriptor = model.chartDescriptor(locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold by drink and size")
        #expect(descriptor.summary
            == "3 drinks in 3 sizes, 384 cups in total. Latte 128 cups, Tea 164 cups, Mocha 92 cups.")
        #expect(descriptor.series.map(\.name) == ["Small", "Medium", "Large"])
        #expect(descriptor.series.map(\.dataPoints.count) == [3, 3, 3])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["Latte", "Tea", "Mocha"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 200)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(34) == "34 cups")
    }
}
