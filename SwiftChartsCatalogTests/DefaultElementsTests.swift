import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct DefaultElementsTests {
    private let english = Locale(identifier: "en_US")

    /// A fixed calendar six hours behind UTC, so the date ranges do not depend on the test machine.
    private var chicago: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Chicago") ?? .gmt
        return calendar
    }

    private func viewModel(_ chartCase: DefaultElementsCase = .oneMark) -> DefaultElementsViewModel {
        let model = DefaultElementsViewModel(calendar: chicago)
        model.chartCase = chartCase
        return model
    }

    /// The date format puts a narrow no-break space before "AM"; compare with ordinary spaces.
    private func plainSpaces(_ text: String?) -> String? {
        text?.replacing("\u{202F}", with: " ")
    }

    private var empty: DefaultElementsData {
        DefaultElementsData(drinkSales: [], drinkOrders: [], week: [], readings: [], month: [])
    }

    // MARK: The one table

    @Test("Given every picker case, when the spoken table is built, then each case has an entry with elements and an Audio Graph")
    func everyCaseHasAnEntry() {
        let table = viewModel().spokenTable(locale: english)

        #expect(Set(table.keys) == Set(DefaultElementsCase.allCases))
        for chartCase in DefaultElementsCase.allCases {
            let entry = table[chartCase]
            #expect(entry?.elements.isEmpty == false, "\(chartCase)")
            #expect(entry?.audioGraph.title == "Chart", "\(chartCase)")
            #expect(entry?.audioGraph.summary == "None", "\(chartCase)")
            #expect(entry?.realChartAdds.isEmpty == false, "\(chartCase)")
        }
    }

    @Test("Given each picker case, when the screen asks for its spoken text, then it is that case's row of the one table")
    func spokenTextComesFromTable() {
        for chartCase in DefaultElementsCase.allCases {
            let model = viewModel(chartCase)

            #expect(model.spokenText(locale: english) == model.spokenTable(locale: english)[chartCase])
        }
    }

    // MARK: The elements, as read on iOS 27

    @Test("Given one bar per drink, when the elements are written, then each is the drink and its bare number")
    func oneMarkElements() {
        let elements = viewModel(.oneMark).spokenText(locale: english)?.elements.map(\.readAs)

        #expect(elements == ["Latte, 128", "Tea, 164", "Mocha, 92", "Cocoa, 57", "Americano, 110"])
    }

    @Test("Given stacked sizes, when the elements are written, then each drink is read as its total and its sizes")
    func stackedElements() {
        let elements = viewModel(.stacked).spokenText(locale: english)?.elements.map(\.readAs)

        #expect(elements == ["Latte, total 128, 3 Sizes", "Tea, total 164, 3 Sizes", "Mocha, total 92, 3 Sizes"])
    }

    @Test("Given grouped sizes, when the elements are written, then they are exactly those of stacked bars")
    func groupedElements() {
        let elements = viewModel(.grouped).spokenText(locale: english)?.elements.map(\.readAs)

        #expect(elements == ["Latte, total 128, 3 Sizes", "Tea, total 164, 3 Sizes", "Mocha, total 92, 3 Sizes"])
    }

    @Test("Given two cafés over a week, when the elements are written, then each day runs from the first café's cups to the second's")
    func severalSeriesElements() {
        let elements = viewModel(.severalSeries).spokenText(locale: english)?.elements

        #expect(plainSpaces(elements?.first?.label) == "Mar 1, 2026 at 12 AM to Mar 2, 2026 at 12 AM")
        #expect(plainSpaces(elements?.last?.label) == "Mar 7, 2026 at 12 AM to Mar 8, 2026 at 12 AM")
        #expect(elements?.map(\.value) == [
            "190 to 155, 2 series", "159 to 197, 2 series", "152 to 188, 2 series", "168 to 202, 2 series",
            "155 to 187, 2 series", "168 to 198, 2 series", "219 to 172, 2 series",
        ])
    }

    @Test("Given the dense line with an hour missing, when the elements are written, then they are six two-hour stretches")
    func denseLineElements() {
        let model = viewModel(.denseLine)
        let elements = model.spokenText(locale: english)?.elements.map(\.readAs)

        #expect(model.data.readings.count == 330)
        #expect(model.missingHours == [12])
        #expect(elements == [
            "6 to 8, starts at 1, varies between 1 and 8, ends at 7, 60 values",
            "8 to 10, starts at 8, varies between 9 and 2, ends at 3, 60 values",
            "10 to 12, 3 to 1, decreases inconsistently, 60 values",
            "12 to 14, starts at 3, varies between 1 and 4, ends at 2, 30 values",
            "14 to 16, starts at 2, varies between 2 and 6, ends at 4, 60 values",
            "16 to 18, starts at 5, varies between 6 and 1, ends at 2, 60 values",
        ])
    }

    @Test("Given 30 days, when the elements are written, then they are merged two days to an element, each first to last")
    func monthElements() {
        let elements = viewModel(.monthOfDays).spokenText(locale: english)?.elements

        #expect(elements?.count == 15)
        #expect(plainSpaces(elements?.first?.label) == "Mar 1, 2026 at 12 AM to Mar 3, 2026 at 12 AM")
        #expect(plainSpaces(elements?.last?.label) == "Mar 29, 2026 at 12 AM to Mar 31, 2026 at 12 AM")
        #expect(elements?.map(\.value) == [
            "190 to 159, 2 values", "152 to 168, 2 values", "155 to 168, 2 values", "219 to 211, 2 values",
            "180 to 173, 2 values", "189 to 176, 2 values", "189 to 240, 2 values", "232 to 201, 2 values",
            "194 to 210, 2 values", "197 to 210, 2 values", "261 to 253, 2 values", "222 to 215, 2 values",
            "231 to 218, 2 values", "231 to 282, 2 values", "274 to 243, 2 values",
        ])
    }

    @Test("Given stretches of each shape, when they are summarised, then each takes the form read on iOS")
    func mergedForms() {
        let model = viewModel()

        #expect(model.merged([193, 146], locale: english) == "193 to 146, 2 values")
        #expect(model.merged([3, 2, 3, 1], locale: english) == "3 to 1, decreases inconsistently, 4 values")
        #expect(model.merged([1, 3, 2, 4], locale: english) == "1 to 4, increases inconsistently, 4 values")
        #expect(model.merged([8, 9, 5, 2, 3], locale: english) == "starts at 8, varies between 9 and 2, ends at 3, 5 values")
    }

    @Test("Given the café's UTC days, when they are moved to the device's calendar, then each is midnight of the same day there")
    func daysMovedToDeviceCalendar() {
        let model = viewModel(.monthOfDays)
        let first = model.data.month.first?.day ?? .distantPast

        #expect(chicago.dateComponents([.year, .month, .day, .hour], from: first)
            == DateComponents(year: 2026, month: 3, day: 1, hour: 0))
    }

    @Test("Given each case, when the Audio Graph is written, then its axes and series are those read on iOS")
    func audioGraphAsRead() {
        let table = viewModel().spokenTable(locale: english)
        let dateAxis = "Day, as numbers (seconds since 2001); both ends read as empty"

        #expect(table[.oneMark]?.audioGraph.xAxis == "Drink: the drinks as categories")
        #expect(table[.oneMark]?.audioGraph.yAxis == "Cups, 0 to 200, the drawn scale")
        #expect(table[.oneMark]?.audioGraph.series == "One series with no name, separate values, 5 values")
        #expect(table[.grouped]?.audioGraph.yAxis == "Cups, 0 to 75, the drawn scale")
        #expect(table[.stacked]?.audioGraph.series == "Small, Medium, and Large: one series per size, separate values, 3 values each")
        #expect(table[.severalSeries]?.audioGraph.xAxis == dateAxis)
        #expect(table[.severalSeries]?.audioGraph.yAxis == "Cups, 0 to 300, the drawn scale")
        #expect(table[.severalSeries]?.audioGraph.series == "Harbour Harbour and Station Station: one series per café, "
            + "named once for each of its two encodings, continuous, 7 values each")
        #expect(table[.severalSeries]?.audioGraph.points
            == "Each point like \"794080800, 190\": the middle of the day in seconds since 2001, and the bare value")
        #expect(table[.denseLine]?.audioGraph.xAxis == "Hour, 5 to 20, the drawn scale")
        #expect(table[.denseLine]?.audioGraph.yAxis == "People queuing, 0 to 10, the drawn scale")
        #expect(table[.denseLine]?.audioGraph.series == "One series with no name, continuous, 330 values: "
            + "the tone runs on through the missing hour, since series: breaks only the drawn line")
        #expect(table[.denseLine]?.audioGraph.points == "Each point like \"6, 1\": bare numbers, no time or unit")
        #expect(table[.monthOfDays]?.audioGraph.xAxis == dateAxis)
        #expect(table[.monthOfDays]?.audioGraph.series == "One series with no name, separate values, 30 values")
    }

    // MARK: The headline

    @Test("Given each case, when the headline is written, then its element count is the length of the predicted list")
    func headlineMatchesElementCount() {
        for chartCase in DefaultElementsCase.allCases {
            let model = viewModel(chartCase)
            let count = model.spokenText(locale: english)?.elements.count ?? -1
            let elements = DefaultElementsWording.elements(count, locale: english)

            #expect(model.headline(locale: english).contains(elements), "\(chartCase)")
        }
    }

    @Test("Given each case, when the headline is written, then it states what is drawn and what VoiceOver reads")
    func headlinesAreTrue() {
        #expect(viewModel(.oneMark).headline(locale: english)
            == "5 bars, one per drink: VoiceOver reads 5 elements, one per bar.")
        #expect(viewModel(.stacked).headline(locale: english)
            == "9 segments in 3 bars: VoiceOver reads 3 elements, each bar as its total.")
        #expect(viewModel(.grouped).headline(locale: english)
            == "9 bars in 3 groups: VoiceOver reads 3 elements, each group as its total, exactly as if stacked.")
        #expect(viewModel(.severalSeries).headline(locale: english)
            == "2 lines over 7 days: VoiceOver reads 7 elements, each day from the first café's cups to the last's.")
        #expect(viewModel(.denseLine).headline(locale: english)
            == "A line from 6 to 18 with no readings from 12 to 13: VoiceOver reads 6 elements of 2 hours, "
            + "and the one from 12 to 14 says nothing of the missing hour.")
        #expect(viewModel(.monthOfDays).headline(locale: english)
            == "30 bars, one per day: VoiceOver reads 15 elements of 2 days.")
    }

    @Test("Given no data, when each case's headline is written, then it says nothing is drawn")
    func emptyHeadline() {
        let model = DefaultElementsViewModel(data: empty, calendar: chicago)

        for chartCase in DefaultElementsCase.allCases {
            model.chartCase = chartCase
            #expect(!model.hasMarks, "\(chartCase)")
            #expect(model.headline(locale: english) == "No data: the chart draws nothing, so VoiceOver has nothing to read.")
        }
    }

    @Test("Given bars of only zeros, when the headline is written, then it says nothing is drawn")
    func allZeroHeadline() {
        var data = empty
        data.drinkSales = [DrinkSales(drink: "Latte", cups: 0)]
        let model = DefaultElementsViewModel(data: data, calendar: chicago)

        #expect(!model.hasMarks)
        #expect(model.headline(locale: english).hasPrefix("No data"))
    }

    @Test("Given one bar, when the headline is written, then its counts agree in number")
    func countsAgreeInNumber() {
        var data = empty
        data.drinkSales = [DrinkSales(drink: "Tea", cups: 4)]
        let model = DefaultElementsViewModel(data: data, calendar: chicago)

        #expect(model.headline(locale: english) == "1 bar, one per drink: VoiceOver reads 1 element, one per bar.")
    }

    @Test("Given a German locale, when the spoken text is written, then numbers take that locale")
    func numbersTakeLocale() {
        var data = empty
        data.drinkSales = [DrinkSales(drink: "Latte", cups: 1234)]
        let model = DefaultElementsViewModel(data: data, calendar: chicago)

        #expect(model.spokenText(locale: Locale(identifier: "de_DE"))?.elements.first?.value == "1.234")
    }

    @Test("Given a label and a count, when the category count is written, then the label is made plural")
    func categoryCountsInflect() {
        #expect(DefaultElementsWording.categories(3, label: CafeWording.size, locale: english) == "3 Sizes")
        #expect(DefaultElementsWording.series(2, locale: english) == "2 series")
        #expect(DefaultElementsWording.hours(1, locale: english) == "1 hour")
    }

    // MARK: Announcement and snippets

    @Test("Given the picker moves to a case, when the change is announced, then it names the case and then the headline")
    func announcementFollowsCase() {
        let model = viewModel(.monthOfDays)

        #expect(model.announcement(locale: english) == "Showing a month of days. \(model.headline(locale: english))")
    }

    @Test("Given each case, when its snippet is shown, then the name starts with the screen's prefix and exists in the bundle")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for chartCase in DefaultElementsCase.allCases {
            let model = viewModel(chartCase)

            #expect(model.snippets == [chartCase.snippet])
            #expect(chartCase.snippet.name.hasPrefix("default-elements"))
            #expect(store[chartCase.snippet.name] != nil, "\(chartCase.snippet.name)")
        }
    }

    @Test("Given every case, when the longest headline is chosen, then it is at least as long as each headline")
    func longestHeadlineReservesRoom() {
        let model = viewModel()
        let longest = model.longestHeadline(locale: english)

        for chartCase in DefaultElementsCase.allCases {
            #expect(longest.count >= model.headline(for: chartCase, locale: english).count)
        }
    }
}
