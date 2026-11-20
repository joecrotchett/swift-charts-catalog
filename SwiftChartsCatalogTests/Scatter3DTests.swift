import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct Scatter3DTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the sample data, when the headline is written, then it counts samples and origins and names the leaders")
    func headline() {
        let summary = Scatter3DViewModel().summary(locale: english)

        #expect(summary.headline == "60 samples from 3 origins. Most acidic: Ethiopia. Fullest body: Sumatra.")
    }

    @Test("Given every control, when it changes, then the headline does not")
    func headlineIgnoresControls() {
        let viewModel = Scatter3DViewModel()
        let before = viewModel.summary(locale: english).headline

        viewModel.shapeChoice = .cone
        viewModel.symbolSize = 0.1
        viewModel.metalness = 1
        viewModel.roughness = 0

        #expect(viewModel.summary(locale: english).headline == before)
    }

    @Test("Given no data, when the headline is written, then it says there is none and there is no data to draw")
    func emptyData() {
        let viewModel = Scatter3DViewModel(beans: [])

        #expect(!viewModel.hasData)
        #expect(viewModel.summary(locale: english).headline == "No bean tastings yet.")
        #expect(viewModel.summary(locale: english).spokenText.elements.isEmpty)
    }

    @Test("Given one sample from one origin, when the headline is written, then the counts agree in number and no leader is named")
    func oneSample() {
        let bean = BeanTasting(id: 0, origin: "Kenya", acidity: 5, body: 5, sweetness: 5)
        let summary = Scatter3DViewModel(beans: [bean]).summary(locale: english)

        #expect(summary.headline == "1 sample from 1 origin.")
    }

    @Test("Given two origins tied on acidity, when the headline is written, then it names both")
    func tie() {
        let beans = [
            BeanTasting(id: 0, origin: "Kenya", acidity: 6, body: 4, sweetness: 5),
            BeanTasting(id: 1, origin: "Peru", acidity: 6, body: 7, sweetness: 5),
        ]
        let summary = Scatter3DViewModel(beans: beans).summary(locale: english)

        #expect(summary.headline == "2 samples from 2 origins. Most acidic: Kenya and Peru. Fullest body: Peru.")
    }

    @Test("Given each shape choice, when shapes are given out, then by origin differs per origin and the others are one shape")
    func shapes() {
        let viewModel = Scatter3DViewModel()

        #expect(viewModel.shapes == [.sphere, .cube, .cone])
        for choice in Scatter3DShapeChoice.allCases where choice != .byOrigin {
            viewModel.shapeChoice = choice
            #expect(Set(viewModel.shapes).count == 1)
            #expect(viewModel.shapes.first?.name == choice.title.lowercased())
        }
    }

    @Test("Given a shape change, when it is announced, then it says what changed and then the headline")
    func announcement() {
        let viewModel = Scatter3DViewModel()
        let headline = viewModel.summary(locale: english).headline

        viewModel.shapeChoice = .cube
        #expect(viewModel.shapeChangeAnnouncement(locale: english) == "Every point is now a cube. \(headline)")
        viewModel.shapeChoice = .byOrigin
        #expect(viewModel.shapeChangeAnnouncement(locale: english) == "Each origin now has its own shape. \(headline)")
    }

    @Test("Given the sliders, when their values are written, then they take the locale")
    func sliderText() {
        let viewModel = Scatter3DViewModel()
        viewModel.symbolSize = 0.07
        viewModel.metalness = 0.3

        #expect(viewModel.symbolSizeText(locale: english) == "0.07")
        #expect(viewModel.metalnessText(locale: Locale(identifier: "de_DE")) == "0,3")
        #expect(viewModel.roughnessText(locale: english) == "0.5")
    }

    @Test("Given the origins, when their looks are taken from the app's table, then each has its own colour, symbol and solid")
    func originStyle() {
        let origins = CafeData.beanOrigins

        #expect(Set(origins.map(BeanOriginStyle.colour(for:))).count == 3)
        #expect(origins.map(BeanOriginStyle.symbolName(for:)) == ["circle.fill", "square.fill", "triangle.fill"])
        #expect(origins.map(BeanOriginStyle.solid(for:)) == [.sphere, .cube, .cone])
        #expect(BeanOriginStyle.colour(for: "Kenya") == .gray)
    }

    @Test("Given each shape choice, when the legend's symbols are listed, then by origin shows each origin's symbol and the others the one solid")
    func legendSymbols() {
        let viewModel = Scatter3DViewModel()

        #expect(viewModel.legendSymbolNames == CafeData.beanOrigins.map(BeanOriginStyle.symbolName(for:)))
        viewModel.shapeChoice = .cylinder
        #expect(viewModel.legendSymbolNames == ["cylinder.fill", "cylinder.fill", "cylinder.fill"])
    }

    @Test("Given the sample data, when the elements are written, then there is one per origin with its count and score ranges")
    func elements() throws {
        let elements = Scatter3DViewModel().summary(locale: english).spokenText.elements

        #expect(elements.map(\.label) == CafeData.beanOrigins)
        let ethiopia = try #require(elements.first)
        #expect(ethiopia.value.hasPrefix("20 samples. Acidity "))
        #expect(ethiopia.value.contains(", body ") && ethiopia.value.contains(", sweetness "))
        #expect(ethiopia.value.contains(" to "))
    }

    @Test("Given the sample data, when the descriptor is made, then it has three numeric axes from 0 to 10 and a series per origin")
    func descriptor() throws {
        let summary = Scatter3DViewModel().summary(locale: english)
        let descriptor = Scatter3DChartDescriptor(summary: summary).makeChartDescriptor()

        #expect(descriptor.title == "Bean tastings: acidity, body and sweetness, by origin")
        #expect(descriptor.summary?.hasPrefix("60 samples from 3 origins, each scored 0 to 10. Ethiopia: mean acidity ") == true)
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.title == "Acidity")
        #expect(xAxis.range == 0 ... 10)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Body")
        #expect(yAxis.valueDescriptionProvider(7.84) == "7.8 out of 10")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        let zAxis = try #require(descriptor.additionalAxes.first as? AXNumericDataAxisDescriptor)
        #expect(zAxis.title == "Sweetness")
        #expect(descriptor.series.map(\.name) == CafeData.beanOrigins)
        #expect(descriptor.series.allSatisfy { !$0.isContinuous && $0.dataPoints.count == 20 })
    }

    @Test("Given the screen, when its snippets are looked up, then each exists and shows its concept")
    func snippets() throws {
        let store = try SnippetStore()
        let viewModel = Scatter3DViewModel()

        #expect(viewModel.snippets.map(\.name) == ["3d-scatter-chart", "3d-scatter-gate", "3d-scatter-legend", "3d-scatter-accessibility"])
        for snippet in viewModel.snippets {
            #expect(store[snippet.name] != nil)
        }
        let chart = try #require(store["3d-scatter-chart"]).code
        #expect(chart.contains("@available(iOS 26, *)") && chart.contains("Chart3D(") && chart.contains("z: .value("))
        #expect(chart.contains(".metalness(") && chart.contains(".roughness(") && chart.contains(".symbolSize("))
        #expect(try #require(store["3d-scatter-gate"]).code.contains("if #available(iOS 26, *)"))
        #expect(try #require(store["3d-scatter-accessibility"]).code.contains(".accessibilityChartDescriptor("))
    }
}
