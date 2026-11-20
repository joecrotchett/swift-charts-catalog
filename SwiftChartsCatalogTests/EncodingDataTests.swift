import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

struct EncodingDataTests {
    private let english = Locale(identifier: "en_US")

    private func stores(harbour: [Int], station: [Int]) -> [StoreSales] {
        [
            StoreSales(store: CafeWording.harbour, days: harbour.enumerated().map { DailySales(day: CafeData.day($0), cups: $1) }),
            StoreSales(store: CafeWording.station, days: station.enumerated().map { DailySales(day: CafeData.day($0), cups: $1) }),
        ]
    }

    @Test("Given a new screen, when it opens, then colour carries the café, on lines, with the colour snippet")
    func startsWithColour() {
        let viewModel = EncodingDataViewModel()

        #expect(viewModel.characteristic == .colour)
        #expect(viewModel.characteristic.mark == .line)
        #expect(viewModel.snippets.map(\.name) == ["encoding-data-colour"])
        #expect(viewModel.stores.map(\.store) == [CafeWording.harbour, CafeWording.station])
        #expect(viewModel.stores.allSatisfy { $0.days.count == 7 })
    }

    @Test("Given each characteristic, when it is chosen, then its mark and snippet follow")
    func marksAndSnippets() {
        let expected: [EncodingDataCharacteristic: (EncodingDataMark, String)] = [
            .colour: (.line, "encoding-data-colour"),
            .position: (.bar, "encoding-data-position"),
            .symbol: (.line, "encoding-data-symbol"),
            .symbolSize: (.point, "encoding-data-symbol-size"),
            .lineStyle: (.line, "encoding-data-line-style"),
        ]
        let viewModel = EncodingDataViewModel()
        for characteristic in EncodingDataCharacteristic.allCases {
            viewModel.characteristic = characteristic
            #expect(viewModel.characteristic.mark == expected[characteristic]?.0)
            #expect(viewModel.snippets.map(\.name) == [expected[characteristic]?.1])
            #expect(viewModel.explanation.contains(characteristic.modifier))
        }
    }

    @Test("Given the built app, when each characteristic's snippet is looked up, then it exists and shows its modifier")
    func snippetsExist() throws {
        let store = try SnippetStore(bundle: .main)
        for characteristic in EncodingDataCharacteristic.allCases {
            let snippet = try #require(store[characteristic.snippet.name])
            let call = String(characteristic.modifier.dropLast("(by:)".count))
            #expect(snippet.code.contains(".\(call)(by:"))
            #expect(snippet.file == "Modifiers/EncodingDataScreen.swift")
        }
    }

    @Test("Given position, when the explanation is read, then it names Harbour's bar by its leading side, true in both directions")
    func positionExplanationNamesLeadingBar() {
        let explanation = EncodingDataCharacteristic.position.explanation

        #expect(explanation.contains("the leading bar of each pair is Harbour"))
        #expect(explanation.contains("the left one in a left-to-right layout and the right one in right-to-left"))
        #expect(!explanation.contains("first bar"))
    }

    @Test("Given the colour snippet, when it is read, then it says the symbol helper is defined in this file")
    func colourSnippetNamesHelper() throws {
        let store = try SnippetStore(bundle: .main)
        let snippet = try #require(store["encoding-data-colour"])

        #expect(snippet.code.contains("encodingDataSymbol(by:if:) is a helper defined in this file"))
    }

    @Test("Given the sample week, when the caption and descriptor title are written, then the range comes from the data's first and last days")
    func dateRangeFromData() {
        let summary = EncodingDataViewModel().summary(locale: english)

        // The interval style puts thin spaces (U+2009) around the en dash.
        #expect(summary.dateRange == "March 1\u{2009}–\u{2009}7")
        #expect(summary.caption == "Cups sold each day, March 1\u{2009}–\u{2009}7")
        #expect(summary.descriptorTitle == "Cups sold each day at the Harbour and Station cafés, March 1\u{2009}–\u{2009}7")
        let descriptor = EncodingDataChartDescriptor(stores: EncodingDataViewModel.firstWeek, mark: .line, locale: english)
            .makeChartDescriptor()
        #expect(descriptor.title == summary.descriptorTitle)
    }

    @Test("Given other locales and other days, when the range is written, then it follows the locale and the data")
    func dateRangeFollowsLocaleAndData() {
        let british = EncodingDataSummary(stores: EncodingDataViewModel.firstWeek, locale: Locale(identifier: "en_GB"))
        #expect(british.dateRange == "1\u{2009}–\u{2009}7 March")

        let threeDays = EncodingDataSummary(stores: stores(harbour: [1, 2, 3], station: [3, 2, 1]), locale: english)
        #expect(threeDays.dateRange == "March 1\u{2009}–\u{2009}3")

        let oneDay = EncodingDataSummary(stores: stores(harbour: [1], station: [2]), locale: english)
        #expect(oneDay.dateRange == "March 1")

        let empty = EncodingDataSummary(stores: [], locale: english)
        #expect(empty.dateRange == nil)
        #expect(empty.caption == "Cups sold each day")
        #expect(empty.descriptorTitle == "Cups sold each day at the Harbour and Station cafés")
    }

    @Test("Given the sample week, when the headline is written, then Station led on 5 days and Harbour on 2")
    func headlineForSampleWeek() {
        let summary = EncodingDataViewModel().summary(locale: english)

        #expect(summary.headline == "Station sold more on 5 days, Harbour on 2 days.")
    }

    @Test("Given any characteristic, when the headline is read, then it is the same, as the data is")
    func headlineIgnoresCharacteristic() {
        let viewModel = EncodingDataViewModel()
        let first = viewModel.summary(locale: english).headline
        for characteristic in EncodingDataCharacteristic.allCases {
            viewModel.characteristic = characteristic
            #expect(viewModel.summary(locale: english).headline == first)
        }
    }

    @Test("Given a tied day and one day led, when the headline is written, then both agree in number")
    func headlineWithTie() {
        let summary = EncodingDataSummary(stores: stores(harbour: [10, 5], station: [10, 4]), locale: english)

        #expect(summary.headline == "Harbour sold more on 1 day, both the same on 1 day.")
    }

    @Test("Given every day tied, when the headline is written, then it says the cafés sold the same")
    func headlineAllTied() {
        let summary = EncodingDataSummary(stores: stores(harbour: [3, 4], station: [3, 4]), locale: english)

        #expect(summary.headline == "The cafés sold the same on 2 days.")
    }

    @Test("Given only zeros, when the chart is drawn, then bars show a placeholder and lines and points draw the zeros")
    func allZero() {
        let viewModel = EncodingDataViewModel(stores: stores(harbour: [0, 0], station: [0, 0]))

        #expect(viewModel.summary(locale: english).headline == "Neither café sold a cup this week.")
        for characteristic in EncodingDataCharacteristic.allCases {
            viewModel.characteristic = characteristic
            #expect(viewModel.showsPlaceholder == (characteristic == .position))
        }
    }

    @Test("Given no data, when the screen is drawn, then every setting shows a placeholder under a true headline")
    func noData() {
        let viewModel = EncodingDataViewModel(stores: [])

        #expect(viewModel.summary(locale: english).headline == "No sales to show.")
        for characteristic in EncodingDataCharacteristic.allCases {
            viewModel.characteristic = characteristic
            #expect(viewModel.showsPlaceholder)
        }
    }

    @Test("Given a switch to position, when it is announced, then the change comes first and the headline after")
    func announcement() {
        let viewModel = EncodingDataViewModel(characteristic: .position)

        #expect(viewModel.announcement(locale: english)
            == "The café is now shown by position, as bars side by side. Station sold more on 5 days, Harbour on 2 days.")
    }

    @Test("Given a mark, when its element text is written, then it names the café and the day, then the cups")
    func elementText() {
        let summary = EncodingDataViewModel().summary(locale: english)

        #expect(summary.elementLabel(store: CafeWording.harbour, day: CafeData.day(0)) == "Sunday, March 1, Harbour")
        #expect(summary.elementValue(cups: 1) == "1 cup")
        #expect(summary.elementValue(cups: 190) == "190 cups")
    }

    @Test("Given a German locale, when the text is written, then numbers take the locale and the sentence stays English")
    func localeIsPassedIn() {
        let summary = EncodingDataSummary(stores: stores(harbour: [1234], station: [10]), locale: Locale(identifier: "de_DE"))

        #expect(summary.elementValue(cups: 1234) == "1.234 cups")
        #expect(summary.audioGraphSummary.contains("1.234 cups in total"))
    }

    @Test("Given the sample week, when the Audio Graph summary is written, then it gives each café's actual values")
    func audioGraphSummary() {
        let summary = EncodingDataViewModel().summary(locale: english)

        #expect(summary.audioGraphSummary == """
        7 days, 2 cafés. Harbour: 1,211 cups in total, highest 219 cups on Saturday, March 7. \
        Station: 1,299 cups in total, highest 202 cups on Wednesday, March 4. \
        Station sold more on 5 days, Harbour on 2 days.
        """)
    }

    @Test("Given each mark, when the descriptor is made, then lines are continuous, bars and points are not, and both cafés are named")
    func descriptor() {
        for (mark, continuous) in [(EncodingDataMark.line, true), (.bar, false), (.point, false)] {
            let descriptor = EncodingDataChartDescriptor(stores: EncodingDataViewModel.firstWeek, mark: mark, locale: english)
                .makeChartDescriptor()

            #expect(descriptor.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
            #expect(descriptor.series.allSatisfy { $0.isContinuous == continuous })
            #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 7 })
            let xAxis = descriptor.xAxis as? AXCategoricalDataAxisDescriptor
            #expect(xAxis?.categoryOrder.first == "Sunday, March 1")
            let yAxis = descriptor.yAxis
            // The busiest day is 219; the axis is drawn to 300, and the descriptor says the same.
            #expect(yAxis?.range == 0 ... 300)
            #expect(yAxis?.valueDescriptionProvider(1) == "1 cup")
            #expect(yAxis?.valueDescriptionProvider(.nan) == "")
        }
    }
}
