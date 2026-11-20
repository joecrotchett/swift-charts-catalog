import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct Axes3DTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the screen opens, when nothing is touched, then every domain is 0 to 10 and all 60 samples are drawn")
    func startsWithFullDomains() {
        let viewModel = Axes3DViewModel()
        for axis in Axes3DAxis.allCases {
            #expect(viewModel.domain(for: axis) == 0 ... 10)
            #expect(viewModel.markedValues(for: axis) == [2, 4, 6, 8])
        }
        #expect(viewModel.beansInside.count == 60)
        #expect(viewModel.headline(locale: english) == "Inside the three domains: all 60 samples.")
        #expect(viewModel.azimuthDegrees == -30)
        #expect(viewModel.inclinationDegrees == 15)
    }

    @Test("Given each domain start, when the axis marks are chosen, then they are the even scores strictly inside")
    func marksInsideDomain() {
        #expect(Axes3DViewModel.markedValues(in: 0 ... 10) == [2, 4, 6, 8])
        #expect(Axes3DViewModel.markedValues(in: 1 ... 10) == [2, 4, 6, 8])
        #expect(Axes3DViewModel.markedValues(in: 2 ... 10) == [4, 6, 8])
        #expect(Axes3DViewModel.markedValues(in: 3 ... 10) == [4, 6, 8])
        #expect(Axes3DViewModel.markedValues(in: 4 ... 10) == [6, 8])
        #expect(Axes3DViewModel.markedValues(in: 5 ... 10) == [6, 8])
    }

    @Test("Given a domain start moved up, when the chart is drawn, then only samples inside every domain remain")
    func narrowingFilters() {
        let viewModel = Axes3DViewModel()
        viewModel.setStart(5, for: .acidity)
        #expect(viewModel.domain(for: .acidity) == 5 ... 10)
        #expect(viewModel.beansInside.allSatisfy { $0.acidity >= 5 })
        #expect(viewModel.beansInside.count == CafeData.beanTastings.count(where: { $0.acidity >= 5 }))
        #expect(viewModel.originGroups.map(\.origin).contains("Sumatra") == false)
        let inside = viewModel.beansInside.count
        #expect(viewModel.headline(locale: english) == "Inside the three domains: \(inside) of 60 samples.")
    }

    @Test("Given a start out of bounds or fractional, when it is set, then it is rounded and held within 0 to 5")
    func startIsClamped() {
        let viewModel = Axes3DViewModel()
        viewModel.setStart(7, for: .body)
        #expect(viewModel.bodyStart == 5)
        viewModel.setStart(-2, for: .body)
        #expect(viewModel.bodyStart == 0)
        viewModel.setStart(2.6, for: .sweetness)
        #expect(viewModel.sweetnessStart == 3)
    }

    @Test("Given no samples, when the headline is written, then it says there are none to show")
    func emptyData() {
        let viewModel = Axes3DViewModel(beans: [])
        #expect(viewModel.beansInside.isEmpty)
        #expect(viewModel.originGroups.isEmpty)
        #expect(viewModel.headline(locale: english) == "No bean samples to show.")
    }

    @Test("Given domains that leave every sample out, when the headline is written, then it says none are inside")
    func noneInside() {
        let bean = BeanTasting(id: 0, origin: "Ethiopia", acidity: 1, body: 1, sweetness: 1)
        let viewModel = Axes3DViewModel(beans: [bean])
        viewModel.setStart(2, for: .acidity)
        #expect(viewModel.headline(locale: english) == "Inside the three domains: none of the 1 sample.")
    }

    @Test("Given a slider moved, when its value is spoken, then it says the domain and then the headline")
    func sliderWords() {
        let viewModel = Axes3DViewModel()
        viewModel.setStart(3, for: .body)
        #expect(viewModel.sliderTitle(for: .body) == "Body domain")
        #expect(viewModel.domainText(for: .body, locale: english) == "3 to 10")
        #expect(viewModel.sliderSpokenValue(for: .body, locale: english)
            == "3 to 10. \(viewModel.headline(locale: english))")
    }

    @Test("Given an origin's samples, when its element is written, then it gives the origin, the count and each span")
    func elementText() throws {
        let beans = [
            BeanTasting(id: 0, origin: "Colombia", acidity: 5, body: 5.5, sweetness: 5),
            BeanTasting(id: 1, origin: "Colombia", acidity: 6.5, body: 6, sweetness: 6),
        ]
        let viewModel = Axes3DViewModel(beans: beans)
        let group = try #require(viewModel.originGroups.first)
        #expect(viewModel.elementLabel(for: group) == "Colombia")
        #expect(viewModel.elementValue(for: group, locale: english)
            == "2 samples. acidity 5 to 6.5, body 5.5 to 6, and sweetness 5 to 6.")
    }

    @Test("Given the default domains, when the descriptor is made, then it has three axes over the domains and a series per origin")
    func descriptor() throws {
        let viewModel = Axes3DViewModel()
        viewModel.setStart(2, for: .acidity)
        let descriptor = Axes3DChartDescriptor(viewModel: viewModel, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Bean samples by acidity, body and sweetness")
        #expect(descriptor.xAxis.title == "Acidity")
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.range == 2 ... 10)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Body")
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(6.5) == "6.5 out of 10")
        #expect(descriptor.additionalAxes.count == 1)
        #expect(descriptor.additionalAxes.first?.title == "Sweetness")
        #expect(descriptor.series.map(\.name) == viewModel.originGroupsInOriginOrder.map(\.origin))
        #expect(descriptor.series.allSatisfy { $0.isContinuous == false })
        #expect(descriptor.series.map(\.dataPoints.count).reduce(0, +) == viewModel.beansInside.count)
        let summary = try #require(descriptor.summary)
        #expect(summary.hasPrefix(viewModel.headline(locale: english)))
        #expect(summary.contains("Domains: acidity 2 to 10, body 0 to 10, and sweetness 0 to 10."))
    }

    @Test("Given the bean samples, when the origins are listed, then the elements follow the chart and the key and series the app's one order")
    func readOrder() {
        let viewModel = Axes3DViewModel()
        #expect(viewModel.originGroups.map(\.origin) == ["Sumatra", "Colombia", "Ethiopia"])
        #expect(viewModel.originGroupsInOriginOrder.map(\.origin) == BeanOriginStyle.origins)
        let descriptor = Axes3DChartDescriptor(viewModel: viewModel, locale: english).makeChartDescriptor()
        #expect(descriptor.series.map(\.name) == ["Ethiopia", "Colombia", "Sumatra"])
    }

    @Test("Given different domains, when the chart's identity is read, then it changes with every start")
    func identityFollowsDomains() {
        let viewModel = Axes3DViewModel()
        let before = viewModel.chartIdentity
        viewModel.setStart(1, for: .sweetness)
        #expect(viewModel.chartIdentity != before)
    }

    @Test("Given each viewpoint button, when it is pressed, then the pose takes the preset's angles")
    func viewpoints() {
        let viewModel = Axes3DViewModel()
        viewModel.show(.below)
        #expect(viewModel.azimuthDegrees == 0)
        #expect(viewModel.inclinationDegrees == -89.9)
        viewModel.show(.side)
        #expect(viewModel.azimuthDegrees == 90)
        #expect(viewModel.inclinationDegrees == 0)
    }

    @Test("Given the app's snippets, when the screen's names are looked up, then each region exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in ["scales-and-axes-in-3d-availability", "scales-and-axes-in-3d-chart"] {
            #expect(store[name] != nil)
        }
    }
}
