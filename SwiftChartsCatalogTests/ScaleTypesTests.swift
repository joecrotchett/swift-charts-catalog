import Accessibility
@testable import SwiftChartsCatalog
import Testing

struct ScaleTypesTests {
    private let english = Locale(identifier: "en_US")

    private func summary(_ kind: ScaleTypesKind, cafes: [ChainCafe] = CafeData.chainCafes) -> ScaleTypesSummary {
        ScaleTypesSummary(cafes: cafes, kind: kind, locale: english)
    }

    // MARK: Scales

    @Test("Given the chain's cafés, when the linear scale is made, then it runs from zero to a round 500,000 with a label every 100,000")
    func linearScale() {
        let scale = summary(.linear).scale

        #expect(scale.domain == 0 ... 500_000)
        #expect(scale.labelledValues == [0, 100_000, 200_000, 300_000, 400_000, 500_000])
        #expect(scale.gridOnlyValues.isEmpty)
    }

    @Test("Given the chain's cafés, when the log scale is made, then it runs between the powers of ten around the data")
    func logScale() {
        let scale = summary(.log).scale

        #expect(scale.domain == 100 ... 1_000_000)
        #expect(scale.labelledValues == [100, 1000, 10000, 100_000, 1_000_000])
    }

    @Test("Given the chain's cafés, when the square-root scale is made, then it starts at zero and labels values that spread along it")
    func squareRootScale() {
        let scale = summary(.squareRoot).scale

        #expect(scale.domain == 0 ... 500_000)
        #expect(scale.labelledValues == [0, 10000, 100_000, 250_000, 500_000])
    }

    @Test("Given changes that cross zero, when the symmetric log scale is made, then it spans both signs and labels every other power of ten")
    func symmetricLogScale() {
        let scale = summary(.symmetricLog).scale

        #expect(scale.domain == -50000 ... 200_000)
        #expect(scale.labelledValues == [-1000, 0, 1000, 100_000])
        #expect(scale.gridOnlyValues == [-10000, -100, -10, 10, 100, 10000])
    }

    @Test("Given six labels, when the scale is thinned for large text, then every third from the last is kept and the rest keep their grid lines")
    func thinnedLinearScale() {
        let scale = summary(.linear).scale.thinned()

        #expect(scale.labelledValues == [200_000, 500_000])
        #expect(scale.gridOnlyValues == [0, 100_000, 300_000, 400_000])
        #expect(scale.domain == 0 ... 500_000)
    }

    @Test("Given five labels or fewer, when the scale is thinned for large text, then every other from the last is kept")
    func thinnedLogScale() {
        #expect(summary(.log).scale.thinned().labelledValues == [100, 10000, 1_000_000])
    }

    @Test("Given a domain that runs below zero, when the scale is thinned for large text, then one label is kept on the negative side")
    func thinnedSymmetricLogKeepsANegativeLabel() {
        let scale = summary(.symmetricLog).scale.thinned()

        #expect(scale.labelledValues == [-10000, 0, 100_000])
        #expect(scale.gridOnlyValues == [-1000, -100, -10, 10, 100, 1000, 10000])
    }

    @Test("Given a change of scale type, when it is made, then it is animated only while the points keep their measure")
    func animatesOnlyWithinAMeasure() {
        #expect(ScaleTypesKind.linear.animatesChange(to: .log))
        #expect(ScaleTypesKind.log.animatesChange(to: .squareRoot))
        #expect(!ScaleTypesKind.linear.animatesChange(to: .symmetricLog))
        #expect(!ScaleTypesKind.symmetricLog.animatesChange(to: .squareRoot))
    }

    @Test("Given the zero line, when the Audio Graph summary is written, then it says the line is there only when it is drawn")
    func zeroLineInAudioGraphSummary() {
        #expect(summary(.symmetricLog).audioGraphSummary.contains("A line marks no change."))
        #expect(!summary(.linear).audioGraphSummary.contains("A line marks no change."))
    }

    @Test("Given values, when they are rounded up, then the result is 1, 2 or 5 times a power of ten and at least 10")
    func roundUp() {
        #expect(ScaleTypesScale.roundUp(480_000) == 500_000)
        #expect(ScaleTypesScale.roundUp(120_000) == 200_000)
        #expect(ScaleTypesScale.roundUp(38000) == 50000)
        #expect(ScaleTypesScale.roundUp(100) == 100)
        #expect(ScaleTypesScale.roundUp(0) == 10)
    }

    // MARK: What is drawn

    @Test("Given any setting, when the points are made, then the cafés are in the same order, largest yearly cups first")
    func orderIsStable() {
        let orders = ScaleTypesKind.allCases.map { summary($0).points.map(\.name) }

        #expect(orders.allSatisfy { $0 == orders[0] })
        #expect(orders[0].first == "Central")
        #expect(orders[0].last == "Kiosk")
    }

    @Test("Given the symmetric log setting, when the points are made, then they are the change on last year with a zero line")
    func symmetricLogDrawsChange() {
        let drawn = summary(.symmetricLog)

        #expect(drawn.measure == .change)
        #expect(drawn.points.first == ScaleTypesPoint(name: "Central", value: 120_000))
        #expect(drawn.showsZeroLine)
        #expect(!summary(.log).showsZeroLine)
    }

    @Test("Given a café with no cups, when the log scale is chosen, then it is not drawn and the headline and summary say so")
    func logLeavesOutZero() {
        let cafes = [ChainCafe(name: "Kiosk", yearlyCups: 0, change: 0), ChainCafe(name: "Pier", yearlyCups: 640, change: 250),
                     ChainCafe(name: "Central", yearlyCups: 480_000, change: 120_000)]
        let log = summary(.log, cafes: cafes)

        #expect(log.points.map(\.name) == ["Central", "Pier"])
        #expect(log.undrawnCount == 1)
        #expect(log.headline.hasSuffix("1 café with 0 cups cannot be drawn on it."))
        #expect(log.audioGraphSummary.contains("Not drawn on a log scale: 1 café with 0 cups."))
        #expect(summary(.linear, cafes: cafes).points.count == 3)
    }

    // MARK: Headlines

    @Test("Given the chain's cafés, when each headline is written, then it states figures that are on the chart")
    func headlines() {
        #expect(summary(.linear).headline
            == "Central, at 480,000 cups a year, sets the axis, leaving 8 cafés in its first fifth.")
        #expect(summary(.log).headline
            == "Kiosk, at 120 cups, and Central, at 480,000, can both be read.")
        #expect(summary(.squareRoot).headline
            == "The 100,000 grid line sits nearly halfway along the axis, giving the 8 cafés below it more room.")
        #expect(summary(.symmetricLog).headline
            == "Falls and rises on one axis: Airport fell by 38,000 cups and Central rose by 120,000.")
    }

    @Test("Given no cafés, when anything is written, then it says there are none and nothing is drawn")
    func emptyData() {
        for kind in ScaleTypesKind.allCases {
            let empty = summary(kind, cafes: [])
            #expect(empty.headline == "No cafés to show.")
            #expect(empty.audioGraphSummary == "No cafés to show.")
            #expect(empty.points.isEmpty)
        }
    }

    @Test("Given cafés that are all zero, when each headline is written, then it is still true")
    func allZeroData() {
        let zeros = [ChainCafe(name: "Kiosk", yearlyCups: 0, change: 0), ChainCafe(name: "Pier", yearlyCups: 0, change: 0)]

        #expect(summary(.linear, cafes: zeros).headline == "Every café sold 0 cups this year, so every point sits at zero.")
        #expect(summary(.squareRoot, cafes: zeros).headline == "Every café sold 0 cups this year, so every point sits at zero.")
        #expect(summary(.log, cafes: zeros).headline == "A log scale cannot draw 0 cups, and no café sold any this year.")
        #expect(summary(.log, cafes: zeros).points.isEmpty)
        #expect(summary(.symmetricLog, cafes: zeros).headline == "No café's cups changed on last year, so every point sits at zero.")
        #expect(summary(.symmetricLog, cafes: zeros).scale.domain == -10 ... 10)
    }

    @Test("Given only rises, when the symmetric log headline is written, then it names the largest rise and says none fell")
    func onlyRises() {
        let cafes = [ChainCafe(name: "Pier", yearlyCups: 640, change: 250), ChainCafe(name: "Kiosk", yearlyCups: 120, change: 1)]

        #expect(summary(.symmetricLog, cafes: cafes).headline
            == "On a symmetric log scale: Largest rise: Pier, 250 cups. No café fell.")
    }

    @Test("Given one café below the first grid line and a rise of one cup, when the words are written, then the counts agree in number")
    func countsAgree() {
        let cafes = [ChainCafe(name: "Kiosk", yearlyCups: 1, change: 1), ChainCafe(name: "Central", yearlyCups: 480_000, change: -1)]

        #expect(summary(.linear, cafes: cafes).headline.hasSuffix("leaving 1 café in its first fifth."))
        #expect(summary(.symmetricLog, cafes: cafes).spokenValue(1) == "1 cup more than last year")
        #expect(summary(.symmetricLog, cafes: cafes).headline.contains("fell by 1 cup "))
        #expect(summary(.linear, cafes: cafes).spokenValue(1) == "1 cup a year")
    }

    @Test("Given a German locale, when the headline is written, then its numbers are written the German way")
    func headlineTakesLocale() {
        let german = ScaleTypesSummary(cafes: CafeData.chainCafes, kind: .linear, locale: Locale(identifier: "de_DE"))

        #expect(german.headline.contains("480.000"))
    }

    @Test("Given a change in scale, when it is announced, then the announcement says what changed and then the headline")
    func announcement() {
        let log = summary(.log)
        let change = summary(.symmetricLog)

        #expect(log.announcement == "Scale changed to log, showing cups a year. \(log.headline)")
        #expect(change.announcement
            == "Scale changed to symmetric log, showing the change on last year. \(change.headline)")
    }

    @Test("Given changes of each sign, when an element's value is written, then it says more, fewer or the same")
    func spokenChange() {
        let change = summary(.symmetricLog)

        #expect(change.spokenValue(-38000) == "38,000 cups fewer than last year")
        #expect(change.spokenValue(9800) == "9,800 cups more than last year")
        #expect(change.spokenValue(0) == "the same as last year")
    }

    // MARK: View model and snippets

    @Test("Given the view model, when the kind changes, then the snippets follow it")
    @MainActor
    func snippetsFollowKind() {
        let model = ScaleTypesViewModel()
        #expect(model.kind == .linear)
        #expect(model.snippets.map(\.name) == ["scale-types-chart", "scale-types-linear"])

        model.kind = .symmetricLog

        #expect(model.snippets.map(\.name) == ["scale-types-chart", "scale-types-symmetric-log"])
        #expect(model.summary(locale: english).measure == .change)
    }

    @Test("Given every setting, when its snippets are looked up, then each one exists in the build's snippets")
    @MainActor
    func snippetsExist() throws {
        let store = try SnippetStore()
        for kind in ScaleTypesKind.allCases {
            for snippet in ScaleTypesViewModel.snippets(for: kind) {
                #expect(store[snippet.name] != nil, "missing \(snippet.name)")
            }
        }
    }

    // MARK: Chart descriptor

    @Test("Given the log setting, when the descriptor is made, then its title, axes, range and series describe what is drawn")
    func logDescriptor() throws {
        let descriptor = ScaleTypesChartDescriptor(summary: summary(.log)).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.title == "Cups a year at each café, on a log scale")
        #expect(descriptor.summary
            == "10 cafés. Most: Central, 480,000 cups a year. Fewest: Kiosk, 120 cups a year. Drawn on a log scale.")
        #expect(xAxis.title == CafeWording.store)
        #expect(xAxis.categoryOrder.first == "Central")
        #expect(yAxis.title == CafeWording.yearlyCupsAxisTitle)
        #expect(yAxis.range == 100 ... 1_000_000)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup a year")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == CafeWording.yearlyCupsAxisTitle)
        #expect(descriptor.series.first?.isContinuous == false)
        #expect(descriptor.series.first?.dataPoints.count == 10)
    }

    @Test("Given the symmetric log setting, when the descriptor is made, then it describes the change, both signs and the range drawn")
    func changeDescriptor() throws {
        let descriptor = ScaleTypesChartDescriptor(summary: summary(.symmetricLog)).makeChartDescriptor()
        let yAxis = try #require(descriptor.yAxis)

        #expect(descriptor.summary
            == "10 cafés. Largest rise: Central, 120,000 cups. Largest fall: Airport, 38,000 cups. A line marks no change. Drawn on a symmetric log scale.")
        #expect(yAxis.title == CafeWording.yearlyChangeAxisTitle)
        #expect(yAxis.range == -50000 ... 200_000)
        #expect(yAxis.valueDescriptionProvider(-38000) == "38,000 cups fewer than last year")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }
}
