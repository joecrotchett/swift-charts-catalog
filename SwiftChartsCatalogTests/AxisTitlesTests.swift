import Accessibility
import Charts
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct AxisTitlesTests {
    private let english = Locale(identifier: "en_US")

    // MARK: View model

    @Test("Given a new screen, when it opens, then every setting is the default and only the titles code is listed")
    func startsAtDefaults() {
        let model = AxisTitlesViewModel()
        #expect(model.xPosition == .automatic)
        #expect(model.yPosition == .automatic)
        #expect(model.alignment == .automatic)
        #expect(model.wording == .short)
        #expect(model.textSize == .device)
        #expect(model.snippets.map(\.name) == ["axis-titles-titles"])
    }

    @Test("Given a moved title or alignment, when the snippets are listed, then the code for each setting off its default is added", arguments: [
        (AxisTitlesXPosition.top, AxisTitlesYPosition.automatic, AxisTitlesAlignment.automatic, ["axis-titles-titles", "axis-titles-positions"]),
        (.automatic, .leading, .automatic, ["axis-titles-titles", "axis-titles-positions"]),
        (.automatic, .automatic, .center, ["axis-titles-titles", "axis-titles-alignments"]),
        (.bottom, .trailing, .trailing, ["axis-titles-titles", "axis-titles-positions", "axis-titles-alignments"]),
    ])
    func snippetsFollowSettings(
        x: AxisTitlesXPosition, y: AxisTitlesYPosition, alignment: AxisTitlesAlignment, expected: [String]
    ) {
        let model = AxisTitlesViewModel()
        model.xPosition = x
        model.yPosition = y
        model.alignment = alignment
        #expect(model.snippets.map(\.name) == expected)
    }

    @Test("Given the wording and text size pickers, when they change, then the snippets stay the titles code alone")
    func wordingAndSizeLeaveSnippets() {
        let model = AxisTitlesViewModel()
        model.wording = .long
        model.textSize = .accessibility5
        #expect(model.snippets.map(\.name) == ["axis-titles-titles"])
    }

    @Test("Given each wording, when the titles are read, then short uses the catalog's words and long its own, each y title with its unit")
    func titlesFollowWording() {
        #expect(AxisTitlesWording.short.xTitle == CafeWording.queueAxisTitle)
        #expect(AxisTitlesWording.short.yTitle == CafeWording.waitAxisTitle)
        #expect(AxisTitlesWording.long.xTitle == AxisTitlesWords.longQueueTitle)
        #expect(AxisTitlesWording.long.yTitle == AxisTitlesWords.longWaitTitle)
        #expect(AxisTitlesWording.long.yTitle.hasSuffix("(seconds)"))
    }

    @Test("Given long titles, when the text size is XL or smaller, then they are drawn and no note shows")
    func longTitlesDrawnAtStandardSizes() {
        let model = AxisTitlesViewModel()
        model.wording = .long
        for size in [DynamicTypeSize.large, .xLarge] {
            #expect(model.drawnWording(at: size) == .long)
            #expect(model.wordingNote(at: size) == nil)
        }
    }

    @Test("Given long titles, when the text size is XX Large or larger, then the short ones are drawn and the note says why")
    func longTitlesFallBackAtAccessibilitySizes() throws {
        let model = AxisTitlesViewModel()
        model.wording = .long
        for size in [DynamicTypeSize.xxLarge, .xxxLarge, .accessibility5] {
            #expect(model.drawnWording(at: size) == .short)
            let note = try #require(model.wordingNote(at: size))
            #expect(note.contains("short ones"))
        }
    }

    @Test("Given short titles, when the text size is an accessibility size, then they are drawn and no note shows")
    func shortTitlesNeedNoNote() {
        let model = AxisTitlesViewModel()
        #expect(model.drawnWording(at: .accessibility5) == .short)
        #expect(model.wordingNote(at: .accessibility5) == nil)
    }

    @Test("Given a forced text size, when the effective size is read, then it wins over the device's; otherwise the device's is used")
    func effectiveTextSize() {
        let model = AxisTitlesViewModel()
        #expect(model.effectiveTextSize(device: .accessibility2) == .accessibility2)
        model.textSize = .xxxLarge
        #expect(model.effectiveTextSize(device: .accessibility2) == .xxxLarge)
    }

    @Test("Given each text size, when the chart environment is read, then only the text size is forced")
    func textSizeForcesOnlyTextSize() {
        let model = AxisTitlesViewModel()
        #expect(model.chartEnvironment == .device)
        model.textSize = .accessibility5
        #expect(model.chartEnvironment == ChartEnvironment(dynamicTypeSize: .accessibility5))
        model.textSize = .xxxLarge
        #expect(model.chartEnvironment.dynamicTypeSize == .xxxLarge)
        #expect(model.chartEnvironment.locale == nil)
    }

    @Test("Given each picker option, when it is mapped, then it gives the matching position or alignment")
    func optionsMapToAPI() {
        #expect(AxisTitlesXPosition.automatic.annotationPosition == .automatic)
        #expect(AxisTitlesXPosition.bottom.annotationPosition == .bottom)
        #expect(AxisTitlesXPosition.top.annotationPosition == .top)
        #expect(AxisTitlesYPosition.automatic.annotationPosition == .automatic)
        #expect(AxisTitlesYPosition.top.annotationPosition == .top)
        #expect(AxisTitlesYPosition.leading.annotationPosition == .leading)
        #expect(AxisTitlesYPosition.trailing.annotationPosition == .trailing)
        #expect(AxisTitlesAlignment.automatic.alignment == nil)
        #expect(AxisTitlesAlignment.leading.alignment == .leading)
        #expect(AxisTitlesAlignment.center.alignment == .center)
        #expect(AxisTitlesAlignment.trailing.alignment == .trailing)
    }

    // MARK: Headline and summary

    @Test("Given the sample orders, when the headline is written, then it names the highest point and its queue")
    func headlineNamesHighestPoint() throws {
        let orders = CafeData.orderWaits
        let longest = try #require(orders.map(\.waitSeconds).max())
        let queue = try #require(orders.first { $0.waitSeconds == longest }?.queueLength)
        let headline = AxisTitlesSummary(orders: orders, locale: english).headline
        #expect(headline == "The longest wait, \(longest) seconds, came with \(queue) people queuing.")
    }

    @Test("Given no orders, when the headline and summary are written, then both say there are none")
    func emptyOrders() {
        let summary = AxisTitlesSummary(orders: [], locale: english)
        #expect(summary.headline == "No orders yet.")
        #expect(summary.audioGraphSummary == "No orders yet.")
    }

    @Test("Given a tie at different queues, when the headline is written, then both queues are named")
    func headlineOnTie() {
        let orders = [
            OrderWait(id: 0, store: "Harbour", queueLength: 1, waitSeconds: 90),
            OrderWait(id: 1, store: "Station", queueLength: 4, waitSeconds: 90),
        ]
        let headline = AxisTitlesSummary(orders: orders, locale: english).headline
        #expect(headline == "The longest wait, 90 seconds, came with 1 person and 4 people queuing.")
    }

    @Test("Given all-zero orders, when the headline is written, then it agrees in number and is still true")
    func headlineAtZero() {
        let orders = [OrderWait(id: 0, store: "Harbour", queueLength: 0, waitSeconds: 0)]
        let headline = AxisTitlesSummary(orders: orders, locale: english).headline
        #expect(headline == "The longest wait, 0 seconds, came with 0 people queuing.")
    }

    @Test("Given a German locale, when the summary is written, then its numbers are written the German way")
    func summaryTakesLocale() {
        let orders = [
            OrderWait(id: 0, store: "Harbour", queueLength: 2, waitSeconds: 1200),
            OrderWait(id: 1, store: "Station", queueLength: 3, waitSeconds: 1500),
        ]
        let summary = AxisTitlesSummary(orders: orders, locale: Locale(identifier: "de_DE"))
        #expect(summary.headline.contains("1.500 seconds"))
        #expect(summary.audioGraphSummary.contains("1.200"))
    }

    @Test("Given the sample orders, when the Audio Graph summary is written, then it gives the counts and ranges in actual values")
    func audioGraphSummary() {
        let summary = AxisTitlesSummary(orders: CafeData.orderWaits, locale: english).audioGraphSummary
        #expect(summary.hasPrefix("40 orders at 2 cafés. Queues from 0 to 11 people, waits from "))
        #expect(summary.contains("The longest wait came with"))
    }

    // MARK: Chart descriptor

    @Test("Given each wording, when the descriptor is made, then its axis titles are the titles drawn")
    func descriptorTitlesFollowWording() throws {
        for wording in AxisTitlesWording.allCases {
            let descriptor = AxisTitlesChartDescriptor(
                orders: CafeData.orderWaits, xTitle: wording.xTitle, yTitle: wording.yTitle, locale: english
            ).makeChartDescriptor()
            let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
            #expect(xAxis.title == wording.xTitle)
            let yAxis = try #require(descriptor.yAxis)
            #expect(yAxis.title == wording.yTitle)
        }
    }

    @Test("Given a descriptor made with the short titles, when the long titles update it, then its axes carry the long titles")
    func descriptorUpdatesWithWording() throws {
        let descriptor = AxisTitlesChartDescriptor(
            orders: CafeData.orderWaits, xTitle: AxisTitlesWording.short.xTitle,
            yTitle: AxisTitlesWording.short.yTitle, locale: english
        ).makeChartDescriptor()
        AxisTitlesChartDescriptor(
            orders: CafeData.orderWaits, xTitle: AxisTitlesWording.long.xTitle,
            yTitle: AxisTitlesWording.long.yTitle, locale: english
        ).updateChartDescriptor(descriptor)
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        #expect(xAxis.title == AxisTitlesWording.long.xTitle)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == AxisTitlesWording.long.yTitle)
        #expect(yAxis.valueDescriptionProvider(120) == "120 seconds")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
    }

    @Test("Given the sample orders, when the descriptor is made, then it has a series per café, ranges from zero and values with units")
    func descriptorContents() throws {
        let descriptor = AxisTitlesChartDescriptor(
            orders: CafeData.orderWaits, xTitle: CafeWording.queueAxisTitle, yTitle: CafeWording.waitAxisTitle,
            locale: english
        ).makeChartDescriptor()
        #expect(descriptor.title == "Queue length and wait for each order, by café")
        #expect(descriptor.series.map(\.name) == ["Harbour", "Station"])
        #expect(descriptor.series.allSatisfy { !$0.isContinuous })
        #expect(descriptor.series.map(\.dataPoints.count) == [20, 20])
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        // Queues up to 11 on an axis drawn to 15; waits up to 309 on an axis pinned at 400.
        #expect(xAxis.range == 0 ... 15)
        #expect(xAxis.valueDescriptionProvider(1) == "1 person")
        #expect(xAxis.valueDescriptionProvider(5) == "5 people")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range.lowerBound == 0)
        #expect(yAxis.range.upperBound == 400)
        #expect(yAxis.valueDescriptionProvider(1) == "1 second")
        #expect(yAxis.valueDescriptionProvider(120) == "120 seconds")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    // MARK: Snippets

    @Test("Given the app's bundle, when the snippets are read, then every name the screen lists exists and shows the concept")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for reference in [AxisTitlesSnippets.titles, AxisTitlesSnippets.positions, AxisTitlesSnippets.alignments] {
            #expect(store[reference.name] != nil)
        }
        let titles = try #require(store[AxisTitlesSnippets.titles.name])
        #expect(titles.file == "Axes/AxisTitlesScreen.swift")
        #expect(titles.code.contains("chartXAxisLabel"))
        #expect(titles.code.contains("chartYAxisLabel"))
        #expect(store[AxisTitlesSnippets.positions.name]?.code.contains("AnnotationPosition") == true)
        #expect(store[AxisTitlesSnippets.alignments.name]?.code.contains("Alignment?") == true)
    }

    @Test("Given the sample orders, when the scales' domain is read, then it names every café in the data, in a fixed order")
    func scaleDomainCoversCafes() {
        #expect(AxisTitlesWords.cafes == [CafeWording.harbour, CafeWording.station])
        #expect(Set(CafeData.orderWaits.map(\.store)) == Set(AxisTitlesWords.cafes))
    }

    @Test("Given the sample waits, when the y axis is laid out at each size, then from Accessibility 1 its labels stop a step below the top")
    func yValuesAtLargeSizes() {
        let longest = CafeData.orderWaits.map(\.waitSeconds).max() ?? 0
        #expect(AxisTitlesYValues.top(maxWait: longest) == 400)
        #expect(AxisTitlesYValues.top(maxWait: 300) == 300)
        #expect(AxisTitlesYValues.top(maxWait: 0) == 100)
        #expect(AxisTitlesYValues.values(maxWait: longest, at: .xxxLarge) == nil)
        #expect(AxisTitlesYValues.values(maxWait: longest, at: .accessibility1) == [0, 100, 200, 300])
    }
}
