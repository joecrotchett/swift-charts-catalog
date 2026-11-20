import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct VectorFieldTests {
    private let english = Locale(identifier: "en_US")

    /// A two-by-two grid, two metres apart, with one reading faster than the rest.
    private let grid = [
        Airflow(id: 0, x: 1, y: 1, direction: 90, speed: 0.4),
        Airflow(id: 1, x: 3, y: 1, direction: 180, speed: 1),
        Airflow(id: 2, x: 1, y: 3, direction: 0, speed: 0.2),
        Airflow(id: 3, x: 3, y: 3, direction: 270, speed: 0.4),
    ]

    // MARK: The view model's states

    @Test("Given a new screen, when it opens, then it draws the measured airflow")
    func startsWithMeasuredAirflow() {
        let viewModel = VectorFieldViewModel()

        #expect(viewModel.kind == .measured)
        #expect(viewModel.readings == CafeData.airflow)
    }

    @Test("Given any field, when it is drawn, then it has the measured readings' spots in the same order", arguments: VectorFieldKind.allCases)
    func everyFieldKeepsTheGrid(kind: VectorFieldKind) {
        let viewModel = VectorFieldViewModel()
        viewModel.kind = kind

        #expect(viewModel.readings.map(\.id) == CafeData.airflow.map(\.id))
        #expect(viewModel.readings.map(\.x) == CafeData.airflow.map(\.x))
        #expect(viewModel.readings.map(\.y) == CafeData.airflow.map(\.y))
    }

    @Test("Given any field, when it is drawn, then every direction is a turn of less than a full circle", arguments: VectorFieldKind.allCases)
    func directionsAreWithinOneTurn(kind: VectorFieldKind) {
        let viewModel = VectorFieldViewModel()
        viewModel.kind = kind

        #expect(viewModel.readings.allSatisfy { (0 ..< 360).contains($0.direction) })
    }

    @Test("Given the three fields, when the longest arrow's speed is worked out, then it is the fastest air in any of them, whichever is drawn")
    func speedCeilingCoversEveryField() {
        let viewModel = VectorFieldViewModel()
        let fastest = VectorFieldKind.allCases
            .flatMap { VectorFieldData.readings(for: $0, measured: CafeData.airflow) }
            .map(\.speed).max()

        #expect(viewModel.speedCeiling == fastest)
        viewModel.kind = .draught
        #expect(viewModel.speedCeiling == fastest)
    }

    // MARK: The computed fields

    @Test("Given a grid, when air circles its middle, then it moves clockwise and faster further out")
    func circlingTurnsClockwise() {
        let wide = [
            Airflow(id: 0, x: 0, y: 2, direction: 0, speed: 0),
            Airflow(id: 1, x: 4, y: 2, direction: 0, speed: 0),
            Airflow(id: 2, x: 2, y: 4, direction: 0, speed: 0),
            Airflow(id: 3, x: 2, y: 0, direction: 0, speed: 0),
            Airflow(id: 4, x: 2, y: 1, direction: 0, speed: 0),
        ]
        let field = VectorFieldData.circling(over: wide)

        // The middle is (2, 1.8). Left of it the air goes up, right of it down, above it across.
        #expect(field[0].direction < 45 || field[0].direction > 315)
        #expect((135 ... 225).contains(field[1].direction))
        #expect(field[2].direction == 90)
        #expect(field[3].direction == 270)
        #expect(field[2].speed > field[4].speed)
    }

    @Test("Given a spot on each axis, when the draught from the door is worked out, then it heads away from the door and slows with distance")
    func draughtSpreadsFromTheDoor() {
        let spots = [
            Airflow(id: 0, x: 0, y: 2, direction: 0, speed: 0),
            Airflow(id: 1, x: 2, y: 0, direction: 0, speed: 0),
            Airflow(id: 2, x: 3, y: 3, direction: 0, speed: 0),
            Airflow(id: 3, x: 0, y: 0, direction: 0, speed: 0),
        ]
        let field = VectorFieldData.draught(over: spots)

        #expect(field[0].direction == 0)
        #expect(field[1].direction == 90)
        #expect(field[2].direction == 45)
        #expect(field[0].speed == 0.6)
        #expect(field[2].speed < field[0].speed)
        #expect(field[3].speed == 0)
    }

    @Test("Given no readings, when a field is computed, then it is empty")
    func computedFieldsOfNothingAreEmpty() {
        #expect(VectorFieldData.circling(over: []).isEmpty)
        #expect(VectorFieldData.draught(over: []).isEmpty)
    }

    // MARK: The room

    @Test("Given readings two metres apart, when the room is worked out, then it runs a metre past the outermost readings")
    func roomCoversTheFloorRoundEachReading() {
        let room = VectorFieldRoom(readings: CafeData.airflow)

        #expect(room.step == 2)
        #expect(room.across == 0 ... 10)
        #expect(room.into == 0 ... 8)
        #expect(room.aspectRatio == 1.25)
    }

    @Test("Given one reading, when the room is worked out, then it is a square round that reading")
    func roomOfOneReading() {
        let room = VectorFieldRoom(readings: [Airflow(id: 0, x: 3, y: 5, direction: 0, speed: 1)])

        #expect(room.across == 2.5 ... 3.5)
        #expect(room.into == 4.5 ... 5.5)
        #expect(room.aspectRatio == 1)
    }

    // MARK: Derived text

    @Test("Given one fastest reading, when the headline is written, then it gives its speed and where it is")
    func headlineNamesTheFastestSpot() {
        let summary = VectorFieldSummary(readings: grid)

        #expect(summary.headline(locale: english) == "The fastest air, 1 metre a second, is 3 metres across and 1 metre into the room.")
    }

    @Test("Given readings tied for the fastest on one row, when the headline is written, then it counts them and names the row they share")
    func headlineCountsATie() {
        let tied = grid + [Airflow(id: 4, x: 5, y: 1, direction: 10, speed: 1)]

        #expect(
            VectorFieldSummary(readings: tied).headline(locale: english)
                == "The fastest air, 1 metre a second, is at 2 spots, both 1 metre into the room."
        )
    }

    @Test("Given the measured field, when the headline is written, then its two fastest spots are named by the line they share, not listed")
    func headlineNamesTheSharedLine() {
        #expect(
            VectorFieldSummary(readings: CafeData.airflow).headline(locale: english)
                == "The fastest air, 1.1 metres a second, is at 2 spots, both 5 metres across."
        )
    }

    @Test("Given readings, when the Audio Graph's summary is written, then it says the rows are played by speed")
    func summarySaysRowsArePlayedBySpeed() {
        #expect(VectorFieldSummary(readings: CafeData.airflow).audioGraphSummary(locale: english)
            .hasSuffix("Each row into the room is played as a series across the room, its pitch the air speed."))
    }

    @Test("Given three readings tied for the fastest, when the headline is written, then the spots are listed the English way under any locale")
    func headlineListsATieInEnglish() {
        let tied = grid + [
            Airflow(id: 4, x: 5, y: 1, direction: 10, speed: 1),
            Airflow(id: 5, x: 5, y: 3, direction: 10, speed: 1),
        ]
        let headline = VectorFieldSummary(readings: tied).headline(locale: Locale(identifier: "de_DE"))

        #expect(headline.contains("is at 3 spots: "))
        #expect(headline.contains(" in, and "))
        #expect(!headline.contains(" und "))
    }

    @Test("Given readings tied for the slowest, when the Audio Graph's summary is written, then it names each spot")
    func summaryNamesATie() {
        let summary = VectorFieldSummary(readings: grid).audioGraphSummary(locale: english)

        #expect(summary.contains("Fastest: 1 metre a second, at 3 metres across, 1 metre in. "))
        let tiedSlowest = VectorFieldSummary(readings: grid.map {
            Airflow(id: $0.id, x: $0.x, y: $0.y, direction: $0.direction, speed: $0.id == 1 ? 1 : 0.2)
        })
        #expect(tiedSlowest.audioGraphSummary(locale: english).contains(
            "Slowest: 0.2 metres a second, at 3 spots: "
                + "1 metre across by 1 metre in, 1 metre across by 3 metres in, and 3 metres across by 3 metres in."
        ))
    }

    @Test("Given any field of the sample data, when the headline is written, then its speed is the fastest drawn", arguments: VectorFieldKind.allCases)
    func headlineFollowsTheFieldDrawn(kind: VectorFieldKind) throws {
        let viewModel = VectorFieldViewModel()
        viewModel.kind = kind
        let fastest = try #require(viewModel.readings.map(\.speed).max())

        #expect(viewModel.headline(locale: english).contains(VectorFieldSummary.speed(fastest, locale: english)))
    }

    @Test("Given still air everywhere, when the words are written, then they say so and name no fastest spot")
    func stillAirSaysSo() {
        let still = grid.map { Airflow(id: $0.id, x: $0.x, y: $0.y, direction: $0.direction, speed: 0) }
        let summary = VectorFieldSummary(readings: still)

        #expect(summary.fastest.isEmpty)
        #expect(summary.headline(locale: english) == "The air is still at every spot measured.")
        #expect(summary.audioGraphSummary(locale: english) == "4 readings. The air is still at every spot measured.")
        #expect(VectorFieldSummary.movement(of: still[0], locale: english) == "Still air")
    }

    @Test("Given no readings, when the words are written, then they say there are none")
    func noReadingsSaySo() {
        let summary = VectorFieldSummary(readings: [])

        #expect(summary.headline(locale: english) == "No airflow readings yet.")
        #expect(summary.audioGraphSummary(locale: english) == "No airflow readings yet.")
    }

    @Test("Given a reading, when its element is written, then the place comes first and the movement has its units and its reference")
    func elementTextGivesPlaceThenMovement() {
        #expect(VectorFieldSummary.position(of: grid[1], locale: english) == "3 metres across, 1 metre in")
        #expect(
            VectorFieldSummary.movement(of: grid[0], locale: english)
                == "Heading 90 degrees clockwise from straight into the room, 0.4 metres a second"
        )
    }

    @Test("Given amounts of one and more, when they are written, then each unit agrees in number")
    func unitsAgreeInNumber() {
        #expect(VectorFieldSummary.metres(1, locale: english) == "1 metre")
        #expect(VectorFieldSummary.metres(9, locale: english) == "9 metres")
        #expect(VectorFieldSummary.speed(1, locale: english) == "1 metre a second")
        #expect(VectorFieldSummary.speed(0.75, locale: english) == "0.75 metres a second")
        #expect(VectorFieldSummary.degrees(1, locale: english) == "1 degree")
        #expect(VectorFieldSummary.degrees(149, locale: english) == "149 degrees")
        #expect(VectorFieldSummary.spots(1, locale: english) == "1 spot")
        #expect(VectorFieldSummary.spots(4, locale: english) == "4 spots")
        #expect(VectorFieldSummary.readingsText(20, locale: english) == "20 readings")
    }

    @Test("Given a German locale, when a speed is written, then the number is written the German way")
    func numbersTakeTheLocale() {
        #expect(VectorFieldSummary.speed(0.75, locale: Locale(identifier: "de_DE")).hasPrefix("0,75"))
    }

    @Test("Given the picker moved to another field, when the change is announced, then it says what is shown and then the headline", arguments: VectorFieldKind.allCases)
    func announcementSaysWhatChangedThenTheHeadline(kind: VectorFieldKind) {
        let viewModel = VectorFieldViewModel()
        viewModel.kind = kind

        #expect(viewModel.announcement(locale: english) == "Showing \(kind.name). \(viewModel.headline(locale: english))")
    }

    // MARK: Snippets

    @Test("Given each field, when See Code opens, then it shows the chart and the arrow, and a computed field's own code")
    func snippetsFollowTheField() {
        let viewModel = VectorFieldViewModel()

        #expect(viewModel.snippets.map(\.name) == ["vector-field-chart", "vector-field-arrow"])
        viewModel.kind = .circling
        #expect(viewModel.snippets.map(\.name) == ["vector-field-chart", "vector-field-arrow", "vector-field-circling"])
        viewModel.kind = .draught
        #expect(viewModel.snippets.map(\.name) == ["vector-field-chart", "vector-field-arrow", "vector-field-draught"])
    }

    @Test("Given every snippet the screen can show, when the store is read, then each exists and holds the code it names")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = VectorFieldViewModel()
        var names: Set<String> = []
        for kind in VectorFieldKind.allCases {
            viewModel.kind = kind
            names.formUnion(viewModel.snippets.map(\.name))
        }

        #expect(names.count == 4)
        for name in names {
            #expect(store[name] != nil, "\(name) is missing")
        }
        #expect(try #require(store["vector-field-chart"]).code.contains(".symbol {"))
        #expect(try #require(store["vector-field-arrow"]).code.contains("rotationEffect"))
        #expect(try #require(store["vector-field-circling"]).code.contains("func circling"))
        #expect(try #require(store["vector-field-draught"]).code.contains("func draught"))
    }

    // MARK: The Audio Graph

    @Test("Given the sample airflow, when its descriptor is made, then it has a series per row, speed as the value and direction on an axis of its own")
    func descriptorDescribesTheField() throws {
        let descriptor = VectorFieldChartDescriptor(
            readings: CafeData.airflow, speedCeiling: 1.2, kind: .measured, locale: english
        ).makeChartDescriptor()
        let xAxis = try #require(descriptor.xAxis as? AXNumericDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)
        let direction = try #require(descriptor.additionalAxes.first as? AXNumericDataAxisDescriptor)

        #expect(descriptor.title == "Air moving through the café: the measured airflow")
        #expect(descriptor.summary == VectorFieldSummary(readings: CafeData.airflow).audioGraphSummary(locale: english))
        #expect(xAxis.title == CafeWording.acrossAxisTitle)
        #expect(xAxis.range == 0 ... 10)
        #expect(xAxis.valueDescriptionProvider(3) == "3 metres across")
        #expect(yAxis.title == CafeWording.speedTitle)
        #expect(yAxis.range == 0 ... 1.2)
        #expect(yAxis.valueDescriptionProvider(1) == "1 metre a second")
        #expect(direction.title == "Direction (degrees)")
        #expect(direction.range == 0 ... 360)
        #expect(direction.valueDescriptionProvider(1) == "1 degree")
        #expect(descriptor.series.map(\.name) == [
            "1 metre into the room", "3 metres into the room", "5 metres into the room", "7 metres into the room",
        ])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 5 && !$0.isContinuous })
    }

    @Test("Given the sample airflow, when the Audio Graph's summary is written, then it gives the count, the fastest and slowest speeds, and what a direction means")
    func summaryGivesActualValues() {
        let summary = VectorFieldSummary(readings: grid).audioGraphSummary(locale: english)

        #expect(summary == "4 readings. Fastest: 1 metre a second, at 3 metres across, 1 metre in. "
            + "Slowest: 0.2 metres a second, at 1 metre across, 3 metres in. "
            + "Directions are in degrees clockwise from straight into the room. "
            + "Each row into the room is played as a series across the room, its pitch the air speed.")
    }
}
