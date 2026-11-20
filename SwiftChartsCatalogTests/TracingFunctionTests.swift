import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct TracingFunctionTests {
    private let locale = Locale(identifier: "en_US")
    private let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test("Given the cooling model, when it is evaluated, then it starts at 90\u{00A0}°C and approaches the room")
    func coolingValues() {
        let cooling = TracingFunctionCooling()

        #expect(cooling.temperature(at: 0) == 90)
        #expect(abs(cooling.temperature(at: 60) - 26.35) < 0.01)
        #expect(cooling.temperature(at: 300) > cooling.room)
    }

    // MARK: Draw-in

    @Test("Given no draw-in, when the reach is asked for, then the curve spans the whole x scale")
    func wholeCurveWithoutDrawIn() {
        let model = TracingFunctionViewModel()

        #expect(!model.isDrawing)
        #expect(model.drawnTo(at: start) == 60)
    }

    @Test("Given a draw-in, when time passes, then the domain grows from 0 to 60 minutes over three seconds")
    func drawInGrows() {
        let model = TracingFunctionViewModel()
        model.startDrawing(at: start)

        #expect(model.isDrawing)
        #expect(model.drawnTo(at: start.addingTimeInterval(-1)) == 0)
        #expect(model.drawnTo(at: start) == 0)
        #expect(model.drawnTo(at: start.addingTimeInterval(1.5)) == 30)
        #expect(model.drawnTo(at: start.addingTimeInterval(10)) == 60)
    }

    @Test("Given a replay during a draw-in, when the first draw-in finishes, then the replay keeps running")
    func finishOnlyMatchingDrawIn() {
        let model = TracingFunctionViewModel()
        model.startDrawing(at: start)
        let replay = start.addingTimeInterval(1)
        model.startDrawing(at: replay)

        model.finishDrawing(startedAt: start)
        #expect(model.isDrawing)

        model.finishDrawing(startedAt: replay)
        #expect(!model.isDrawing)
    }

    @Test("Given a draw-in, when Reduce Motion asks for the whole curve, then it is drawn whole at once")
    func wholeCurveUnderReduceMotion() {
        let model = TracingFunctionViewModel()
        model.startDrawing(at: start)

        model.showWholeCurve()

        #expect(!model.isDrawing)
        #expect(model.drawnTo(at: start) == 60)
    }

    // MARK: Selection

    @Test("Given a raw selection, when it is snapped, then it is a whole minute inside the scale")
    func selectionSnaps() {
        let model = TracingFunctionViewModel()

        #expect(model.selectedMinute(drawnTo: 60) == nil)
        model.rawSelectedMinute = 12.4
        #expect(model.selectedMinute(drawnTo: 60) == 12)
        model.rawSelectedMinute = -3
        #expect(model.selectedMinute(drawnTo: 60) == 0)
        model.rawSelectedMinute = 71
        #expect(model.selectedMinute(drawnTo: 60) == 60)
        model.rawSelectedMinute = .nan
        #expect(model.selectedMinute(drawnTo: 60) == nil)
    }

    @Test("Given a partly drawn curve, when the selection is past its end, then nothing is selected")
    func selectionOnlyWhereDrawn() {
        let model = TracingFunctionViewModel()
        model.rawSelectedMinute = 30

        #expect(model.selectedMinute(drawnTo: 24) == nil)
        #expect(model.selectedMinute(drawnTo: 30) == 30)
    }

    @Test("Given a selected minute, when its coordinates are written, then they give the minute and the temperature")
    func coordinates() {
        let model = TracingFunctionViewModel()

        #expect(model.coordinates(of: 12, locale: locale) == "(12\u{00A0}min, 63\u{00A0}°C)")
    }

    @Test("Given accessibility text sizes, when the coordinates are stacked, then they go on two lines without brackets")
    func coordinatesStacked() {
        let model = TracingFunctionViewModel()

        #expect(model.coordinates(of: 12, locale: locale, stacked: true) == "12\u{00A0}min\n63\u{00A0}°C")
    }

    @Test("Given a point on each half of the curve, when its label is placed, then it goes below only on the second half")
    func labelSide() {
        #expect(!TracingFunctionViewModel.labelsBelow(0))
        #expect(!TracingFunctionViewModel.labelsBelow(30))
        #expect(TracingFunctionViewModel.labelsBelow(31))
        #expect(TracingFunctionViewModel.labelsBelow(60))
    }

    @Test("Given the selection at 0 minutes, when the headline is written, then it speaks of the moment of pouring")
    func headlineAtPouring() {
        let model = TracingFunctionViewModel()
        model.rawSelectedMinute = 0.2

        #expect(model.message(drawnTo: 60, locale: locale) == "When poured, the coffee is at 90\u{00A0}°C.")
    }

    // MARK: Headline

    @Test("Given the whole curve and no selection, when the headline is written, then it gives the start and the end")
    func headlineWhole() {
        let model = TracingFunctionViewModel()

        #expect(model.message(drawnTo: 60, locale: locale) == "Poured at 90\u{00A0}°C, the coffee is down to 26\u{00A0}°C after 60 minutes.")
    }

    @Test("Given a selection, when the headline is written, then it gives the selected point")
    func headlineSelection() {
        let model = TracingFunctionViewModel()
        model.rawSelectedMinute = 0.8

        #expect(model.message(drawnTo: 60, locale: locale) == "After 1 minute, the coffee is at 87\u{00A0}°C.")
    }

    @Test("Given a draw-in partway, when the headline is written, then it speaks only of what is drawn")
    func headlinePartway() {
        let model = TracingFunctionViewModel()

        #expect(model.message(drawnTo: 24.6, locale: locale) == "Drawn to 24 minutes so far: down from 90\u{00A0}°C to 47\u{00A0}°C.")
        #expect(model.message(drawnTo: 0.5, locale: locale) == "Drawing the curve from 0 minutes.")
    }

    @Test("Given every headline, when the reserved one is chosen, then none is longer")
    func reservedIsLongest() {
        let model = TracingFunctionViewModel()
        let reserved = model.reservedMessage(locale: locale)
        var messages = [0.0, 0.5, 9.5, 24.6, 59.9, 60].map { model.message(drawnTo: $0, locale: locale) }
        for minute in [0.0, 1, 12, 59, 60] {
            model.rawSelectedMinute = minute
            messages.append(model.message(drawnTo: 60, locale: locale))
        }

        #expect(messages.allSatisfy { $0.count <= reserved.count })
    }

    @Test("Given a replay, when it is announced, then it says what changes and then the headline it ends on")
    func replayAnnouncement() {
        let model = TracingFunctionViewModel()

        #expect(model.replayAnnouncement(locale: locale)
            == "Drawing the curve again over 60 minutes. Poured at 90\u{00A0}°C, the coffee is down to 26\u{00A0}°C after 60 minutes.")
    }

    // MARK: What VoiceOver reads

    @Test("Given the whole curve, when it is cut into portions, then there are twelve of five minutes, read with units")
    func portionsWhole() throws {
        let model = TracingFunctionViewModel()
        let portions = model.portions(drawnTo: 60)

        #expect(portions.count == 12)
        let first = try #require(portions.first)
        #expect(first.label(locale: locale) == "0 to 5 minutes")
        #expect(first.value(locale: locale) == "starts at 90 degrees Celsius, ends at 77 degrees Celsius")
        #expect(portions.last?.end == 60)
    }

    @Test("Given a partly drawn curve, when it is cut into portions, then only whole five-minute stretches are read")
    func portionsPartway() {
        let model = TracingFunctionViewModel()

        #expect(model.portions(drawnTo: 12).map(\.end) == [5, 10])
        #expect(model.portions(drawnTo: 4.9).isEmpty)
        #expect(model.portions(drawnTo: 0).isEmpty)
    }

    @Test("Given a draw-in moving frame by frame, when the portions are read, then each keeps its text until a new one is complete")
    func portionsStableDuringDrawIn() {
        let model = TracingFunctionViewModel()
        let frames = stride(from: 10.0, to: 15.0, by: 0.3).map { model.portions(drawnTo: $0) }

        #expect(Set(frames.map { $0.map { "\($0.label(locale: locale)) \($0.value(locale: locale))" } }).count == 1)
        #expect(TracingFunctionViewModel.spokenReach(drawnTo: 24.6) == 20)
        #expect(TracingFunctionViewModel.spokenReach(drawnTo: 60) == 60)
        #expect(TracingFunctionViewModel.spokenReach(drawnTo: 90) == 60)
        #expect(TracingFunctionViewModel.spokenReach(drawnTo: -1) == 0)
    }

    @Test("Given the whole curve, when the descriptor is made, then it has numeric axes, one continuous series and a summary in values")
    func descriptorWhole() throws {
        let descriptor = TracingFunctionChartDescriptor(cooling: TracingFunctionCooling(), locale: locale)
            .makeChartDescriptor()

        #expect(descriptor.title == "Temperature of a cup of coffee after pouring")
        #expect(descriptor.summary == "Poured at 90 degrees Celsius. After 60 minutes, 26 degrees Celsius.")
        let series = try #require(descriptor.series.first)
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == 61)
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 100)
        #expect(yAxis.valueDescriptionProvider(1) == "1 degree Celsius")
        #expect(yAxis.valueDescriptionProvider(26.35) == "26 degrees Celsius")
        #expect(yAxis.valueDescriptionProvider(.infinity) == "")
    }

    @Test("Given the draw-in partway, when the descriptor is made, then it still describes the whole curve")
    func descriptorIgnoresTheDrawIn() throws {
        // The Audio Graph keeps the first descriptor it reads, so it never follows the draw-in.
        let descriptor = TracingFunctionChartDescriptor(cooling: TracingFunctionCooling(), locale: locale)

        #expect(descriptor.minutes.first == 0)
        #expect(descriptor.minutes.last == 60)
        #expect(try #require(descriptor.makeChartDescriptor().series.first).dataPoints.count == 61)
    }

    // MARK: Code

    @Test("Given the built app, when the screen's snippets are looked up, then every one exists")
    func snippetsExist() throws {
        let store = try SnippetStore()

        for snippet in TracingFunctionViewModel.snippets {
            #expect(store[snippet.name] != nil, "missing \(snippet.name)")
        }
        #expect(store[TracingFunctionViewModel.chartSnippet.name]?.code.contains("domain:") == true)
    }
}
