import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct GatedChartTests {
    private let english = Locale(identifier: "en_US")
    private let headline = "60 samples from 3 origins: Ethiopia's beans are the most acidic, Sumatra's the fullest-bodied."

    private func model(systemHas3D: Bool = true, beans: [BeanTasting] = CafeData.beanTastings) -> GatedChartViewModel {
        GatedChartViewModel(beans: beans, systemHas3D: systemHas3D, systemVersion: "27.0")
    }

    @Test("Given a system that passed the check, when the toggle is off, then the 3D chart is chosen")
    func threeDOnNewerSystem() {
        let viewModel = model()

        #expect(viewModel.branch == .chart3D)
        #expect(viewModel.canChooseAngle)
        #expect(viewModel.status == "This system runs iOS 27.0 and passed the iOS 26 check: the 3D chart is drawn.")
    }

    @Test("Given a system that passed the check, when the simulated OS is older, then the fallback is chosen")
    func fallbackWhenSimulated() {
        let viewModel = model()

        viewModel.simulatesOlderOS = true

        #expect(viewModel.branch == .fallback)
        #expect(!viewModel.canChooseAngle)
        #expect(viewModel.status.contains("the toggle overrides it, so the 2D fallback is drawn"))
    }

    @Test("Given a system that failed the check, when the screen opens, then the fallback is chosen and the toggle is off limits")
    func fallbackOnOlderSystem() {
        let viewModel = model(systemHas3D: false)

        #expect(viewModel.branch == .fallback)
        #expect(!viewModel.canSimulateOlderOS)
        #expect(viewModel.status.contains("failed the iOS 26 check"))
    }

    @Test("Given the sample data, when the headline is written, then it counts samples and origins and names the leaders")
    func headlineText() {
        #expect(model().summary(locale: english).headline == headline)
    }

    @Test("Given either chart, when the toggle changes, then the headline is the same, since both draw acidity and body")
    func headlineIgnoresToggle() {
        let viewModel = model()
        let before = viewModel.summary(locale: english).headline

        viewModel.simulatesOlderOS = true

        #expect(viewModel.summary(locale: english).headline == before)
    }

    @Test("Given the toggle, when it changes, then the announcement says what is drawn and ends with the headline")
    func announcements() {
        let viewModel = model()
        #expect(viewModel.announcement(locale: english) == "Showing the 3D chart iOS 26 draws. \(headline)")

        viewModel.simulatesOlderOS = true

        #expect(viewModel.announcement(locale: english)
            == "Showing the 2D chart iOS 18 gets instead. Sweetness is not drawn. \(headline)")
    }

    @Test("Given no data, when the screen opens, then the headline says so and no control can change the chart")
    func emptyData() {
        let viewModel = model(beans: [])

        #expect(!viewModel.hasData)
        #expect(viewModel.summary(locale: english).headline == "No bean samples to show.")
        #expect(!viewModel.canSimulateOlderOS)
        #expect(!viewModel.canChooseAngle)
    }

    @Test("Given one sample, when the headline is written, then the counts agree in number")
    func oneSample() throws {
        let bean = try #require(CafeData.beanTastings.first)

        #expect(model(beans: [bean]).summary(locale: english).headline == "1 sample from 1 origin.")
    }

    @Test("Given an origin, when its element is written, then sweetness is named only in 3D")
    func elementText() {
        let summary = model().summary(locale: english)
        let threeD = summary.elementValue(origin: "Ethiopia", includesSweetness: true)
        let twoD = summary.elementValue(origin: "Ethiopia", includesSweetness: false)

        #expect(summary.elementLabel(origin: "Ethiopia") == "Ethiopia")
        #expect(twoD.hasPrefix("20 samples. Acidity "))
        #expect(twoD.contains(", body "))
        #expect(!twoD.contains("sweetness"))
        #expect(threeD.hasPrefix(String(twoD.dropLast())))
        #expect(threeD.contains(", sweetness "))
    }

    @Test("Given a German locale, when a range is written, then it takes the locale's decimal separator")
    func localeNumbers() {
        let summary = GatedChartSummary(beans: CafeData.beanTastings, locale: Locale(identifier: "de_DE"))

        #expect(summary.elementValue(origin: "Ethiopia", includesSweetness: false).contains(","))
        #expect(GatedChartWording.score(7.8, locale: Locale(identifier: "de_DE")) == "7,8")
    }

    @Test("Given an angle button, when it is pressed after a drag, then the chart turns back to that preset")
    func angleButtons() {
        let viewModel = model()
        #expect(viewModel.azimuthDegrees == 20)
        #expect(viewModel.inclinationDegrees == 15)
        viewModel.show(.side)
        #expect(viewModel.azimuthDegrees == 90)
        #expect(viewModel.inclinationDegrees == 0)
        // A drag writes its angles back; the same button then turns the chart to the preset again.
        viewModel.azimuthDegrees = 47
        viewModel.inclinationDegrees = 8
        viewModel.show(.side)
        #expect(viewModel.azimuthDegrees == 90)
        #expect(viewModel.inclinationDegrees == 0)
    }

    @Test("Given the 3D chart, when its descriptor is made, then it has three score axes and a series per origin")
    func descriptor3D() throws {
        let descriptor = GatedChartDescriptor(beans: CafeData.beanTastings, locale: english, includesSweetness: true)
            .makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Bean tastings by origin: acidity, body and sweetness")
        #expect(descriptor.xAxis.title == "Acidity")
        #expect(yAxis.title == "Body")
        #expect(yAxis.range == 0 ... 10)
        #expect(yAxis.valueDescriptionProvider(7.8) == "7.8 out of 10")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(yAxis.valueDescriptionProvider(10) == "10 out of 10")
        #expect(yAxis.valueDescriptionProvider(0) == "0 out of 10")
        #expect(descriptor.additionalAxes.map(\.title) == ["Sweetness"])
        #expect(descriptor.series.map(\.name) == ["Ethiopia", "Colombia", "Sumatra"])
        #expect(descriptor.series.map(\.dataPoints.count) == [20, 20, 20])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        #expect(descriptor.summary?.hasPrefix("60 samples from 3 origins. Ethiopia: 20 samples.") == true)
        #expect(descriptor.summary?.contains("sweetness") == true)
    }

    @Test("Given the fallback, when its descriptor is made, then it describes only the two scores drawn")
    func descriptorFallback() {
        let descriptor = GatedChartDescriptor(beans: CafeData.beanTastings, locale: english, includesSweetness: false)
            .makeChartDescriptor()

        #expect(descriptor.title == "Bean tastings by origin: acidity and body")
        #expect(descriptor.additionalAxes.isEmpty)
        #expect(descriptor.summary?.contains("sweetness") == false)
    }

    @Test("Given the app bundle, when its snippets are read, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let names = [
            "gating-with-a-fallback-gate",
            "gating-with-a-fallback-chart3d",
            "gating-with-a-fallback-accessibility",
            "gating-with-a-fallback-fallback",
        ]

        for name in names {
            #expect(store[name] != nil, "missing \(name)")
        }
        #expect(store["gating-with-a-fallback-gate"]?.code.contains("if #available(iOS 26, *)") == true)
    }
}
