import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct RealDataTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the screen opens, when nothing is changed, then it draws the invented days as a line")
    func startsInventedLine() {
        let viewModel = RealDataViewModel()
        #expect(!viewModel.isRealData)
        #expect(!viewModel.isOnlyZeros)
        #expect(viewModel.mark == .line)
        #expect(viewModel.days == CafeData.thirtyDays)
        #expect(!viewModel.isShowingMistake)
    }

    @Test("Given the invented days, when the headline is read, then it names the busiest of 30 days")
    func inventedHeadline() {
        let viewModel = RealDataViewModel()
        #expect(viewModel.summary(locale: english).headline
            == "Busiest of the 30 days on record: Sunday, March 29, with 230 cups.")
    }

    @Test("Given real data, when the headline is read, then it names the festival among 29 recorded days")
    func realHeadline() {
        let viewModel = RealDataViewModel()
        viewModel.isRealData = true
        #expect(viewModel.days.count == 29)
        #expect(viewModel.summary(locale: english).headline
            == "Busiest of the 29 days on record: Saturday, March 21, with 624 cups.")
    }

    @Test("Given real data, when its awkward days are found, then there are five zeros, March 18 missing and the festival outlier")
    func realAwkwardDays() throws {
        let summary = RealDataSummary(days: CafeData.thirtyDaysReal, mark: .bars, locale: english)
        #expect(summary.zeroDayCount == 5)
        #expect(summary.missingDays.map(summary.dayName) == ["Wednesday, March 18"])
        let outlier = try #require(summary.outlier)
        #expect(outlier.cups == 624)
        #expect(summary.nextBusiestCups == 230)
        #expect(summary.cupsAxis == 0 ... 650)
    }

    @Test("Given the invented days, when checked for awkward days, then there are none and the axis tops at 250")
    func inventedHasNoAwkwardDays() {
        let summary = RealDataSummary(days: CafeData.thirtyDays, mark: .line, locale: english)
        #expect(summary.zeroDayCount == 0)
        #expect(summary.missingDays.isEmpty)
        #expect(summary.outlier == nil)
        #expect(summary.cupsAxis == 0 ... 250)
    }

    @Test("Given only zeros, when each mark is chosen, then only bars show the placeholder")
    func zerosPlaceholderOnlyForBars() {
        let viewModel = RealDataViewModel()
        viewModel.isOnlyZeros = true
        #expect(viewModel.days.allSatisfy { $0.cups == 0 })
        for mark in RealDataMark.allCases {
            viewModel.mark = mark
            #expect(viewModel.summary(locale: english).showsPlaceholder == (mark == .bars))
        }
        #expect(viewModel.summary(locale: english).cupsAxis == 0 ... 50)
    }

    @Test("Given only zeros as bars, when the placeholder shows, then the data toggle is disabled and the others are not")
    func dataToggleDisabledUnderPlaceholder() {
        let viewModel = RealDataViewModel()
        viewModel.isOnlyZeros = true
        viewModel.mark = .bars
        #expect(viewModel.isDataToggleDisabled)
        viewModel.mark = .points
        #expect(!viewModel.isDataToggleDisabled)
    }

    @Test("Given only zeros on real data, when the headline and summary are read, then they say no cups and keep the missing day")
    func zerosHeadline() {
        let viewModel = RealDataViewModel()
        viewModel.isRealData = true
        viewModel.isOnlyZeros = true
        let summary = viewModel.summary(locale: english)
        #expect(summary.headline == "No cups sold in the 29 days on record.")
        #expect(summary.audioGraphSummary
            == "29 days on record. Every day 0 cups. No record for Wednesday, March 18.")
    }

    @Test("Given no days, when the summary is read, then it says so and shows the placeholder for every mark")
    func emptyDays() {
        for mark in RealDataMark.allCases {
            let summary = RealDataSummary(days: [], mark: mark, locale: english)
            #expect(summary.showsPlaceholder)
            #expect(summary.headline == "No days recorded.")
            #expect(summary.placeholderTitle == "No days recorded")
            #expect(summary.cupsAxis == 0 ... 50)
        }
    }

    @Test("Given one day of one cup, when the headline is read, then the count agrees in number")
    func singularCounts() {
        let summary = RealDataSummary(days: [DailySales(day: CafeData.firstDay, cups: 1)], mark: .bars, locale: english)
        #expect(summary.headline == "Busiest of the 1 day on record: Sunday, March 1, with 1 cup.")
    }

    @Test("Given two days tied for most, when the headline is read, then both are named and there is no outlier")
    func tiedHeadline() {
        let days = [DailySales(day: CafeData.day(0), cups: 9), DailySales(day: CafeData.day(1), cups: 9)]
        let summary = RealDataSummary(days: days, mark: .points, locale: english)
        #expect(summary.headline == "Busiest of the 2 days on record: Sunday, March 1 and Monday, March 2, with 9 cups.")
        #expect(summary.outlier == nil)
    }

    @Test("Given real data as a line, when the screen reads it, then it is labelled the mistake and says what the line does")
    func realLineIsTheMistake() {
        let viewModel = RealDataViewModel()
        viewModel.isRealData = true
        #expect(viewModel.isShowingMistake)
        let lookFor = viewModel.summary(locale: english).lookFor
        #expect(lookFor.contains("Each of the 5 days at 0 cups pulls the line down to zero and back up"))
        #expect(lookFor.contains("Across Wednesday, March 18, with no record, the line runs straight on"))
        #expect(lookFor.contains("Saturday, March 21 stands alone at 624 cups, and every other day is 230 cups or fewer, reaching only about a third of the way up the plot."))
        viewModel.mark = .bars
        #expect(!viewModel.isShowingMistake)
        viewModel.mark = .line
        viewModel.isOnlyZeros = true
        #expect(!viewModel.isShowingMistake)
    }

    @Test("Given real data as points and as bars, when what to look for is read, then each says how it shows zeros and the gap")
    func realPointsAndBarsLookFor() {
        let points = RealDataSummary(days: CafeData.thirtyDaysReal, mark: .points, locale: english).lookFor
        #expect(points.contains("Each of the 5 days at 0 cups is a dot on the zero line."))
        #expect(points.contains("There is no dot at all on Wednesday, March 18"))
        let bars = RealDataSummary(days: CafeData.thirtyDaysReal, mark: .bars, locale: english).lookFor
        #expect(bars.contains("Each of the 5 days at 0 cups is an empty slot"))
        #expect(bars.contains("bars cannot tell a day with no record from a day of 0"))
    }

    @Test("Given only zeros, when what to look for is read for each mark, then it says what that mark draws")
    func zerosLookFor() {
        let zeros = CafeData.thirtyDays.map { DailySales(day: $0.day, cups: 0) }
        #expect(RealDataSummary(days: zeros, mark: .points, locale: english).lookFor
            == "Every day is a dot on the zero line: a chart of zeros is still drawn.")
        #expect(RealDataSummary(days: zeros, mark: .line, locale: english).lookFor
            == "The line lies flat along zero from the first day to the last: a chart of zeros is still drawn.")
        #expect(RealDataSummary(days: zeros, mark: .bars, locale: english).lookFor.hasPrefix("A bar of 0 has no height"))
    }

    @Test("Given each mark, when See Code opens, then it shows that mark's snippet and the placeholder check")
    func snippetsFollowMark() throws {
        let viewModel = RealDataViewModel()
        let store = try SnippetStore()
        for mark in RealDataMark.allCases {
            viewModel.mark = mark
            #expect(viewModel.snippets.map(\.name) == [mark.snippet.name, "design-with-real-data-placeholder"])
            for snippet in viewModel.snippets {
                #expect(store[snippet.name] != nil)
            }
        }
        #expect(RealDataViewModel.allSnippets.count == 4)
    }

    @Test("Given each control, when it changes, then the announcement says what changed and then the headline")
    func announcements() {
        let viewModel = RealDataViewModel()
        viewModel.isRealData = true
        #expect(viewModel.dataAnnouncement(locale: english)
            == "Now showing the days as really traded. Busiest of the 29 days on record: Saturday, March 21, with 624 cups.")
        viewModel.mark = .bars
        #expect(viewModel.markAnnouncement(locale: english)
            == "Now drawn as bars. Busiest of the 29 days on record: Saturday, March 21, with 624 cups.")
        viewModel.isOnlyZeros = true
        #expect(viewModel.zerosAnnouncement(locale: english)
            == "Every recorded day set to 0 cups. No cups sold in the 29 days on record.")
        viewModel.mark = .points
        viewModel.mark = .bars
        #expect(viewModel.markAnnouncement(locale: english)
            == "Now drawn as bars. No cups sold. No cups sold in the 29 days on record.")
    }

    @Test("Given the controls, when the chart identity is read, then it changes with every setting")
    func chartIdentityChanges() {
        let viewModel = RealDataViewModel()
        var identities: Set<String> = [viewModel.chartIdentity]
        viewModel.isRealData = true
        identities.insert(viewModel.chartIdentity)
        viewModel.isOnlyZeros = true
        identities.insert(viewModel.chartIdentity)
        viewModel.mark = .points
        identities.insert(viewModel.chartIdentity)
        #expect(identities.count == 4)
    }

    @Test("Given real data as a line, when the descriptor is made, then it has written-out days, one continuous series and the drawn range")
    func descriptorLine() throws {
        let descriptor = RealDataChartDescriptor(days: CafeData.thirtyDaysReal, mark: .line, locale: english).makeChartDescriptor()
        #expect(descriptor.title == "Cups sold each day at the Harbour café, March 2026")
        #expect(descriptor.summary
            == "29 days on record. Busiest Saturday, March 21, 624 cups. 5 days at 0 cups. No record for Wednesday, March 18.")
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder.count == 29)
        #expect(xAxis.categoryOrder.first == "Sunday, March 1")
        #expect(!xAxis.categoryOrder.contains("Wednesday, March 18"))
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.title == "Cups")
        #expect(yAxis.range == 0 ... 650)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(624) == "624 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.series.count == 1)
        #expect(descriptor.series.first?.name == "Harbour")
        #expect(descriptor.series.first?.isContinuous == true)
        #expect(descriptor.series.first?.dataPoints.count == 29)
    }

    @Test("Given points or bars, when the descriptor is made, then the series is not continuous")
    func descriptorSeparateMarks() {
        for mark in [RealDataMark.points, .bars] {
            let descriptor = RealDataChartDescriptor(days: CafeData.thirtyDays, mark: mark, locale: english).makeChartDescriptor()
            #expect(descriptor.series.first?.isContinuous == false)
            #expect(descriptor.summary == "30 days on record. Busiest Sunday, March 29, 230 cups.")
        }
    }

    @Test("Given a German locale, when the headline is read, then the date and number follow it")
    func germanLocale() {
        let summary = RealDataSummary(days: CafeData.thirtyDaysReal, mark: .bars, locale: Locale(identifier: "de_DE"))
        #expect(summary.dayName(CafeData.day(20)) == "Samstag, 21. März")
    }

    @Test("Given a share of the plot's height, when it is named, then the nearest plain fraction is used")
    func fractionNames() {
        #expect(RealDataSummary.fractionName(230.0 / 650) == "a third")
        #expect(RealDataSummary.fractionName(0.26) == "a quarter")
        #expect(RealDataSummary.fractionName(0.48) == "half")
        #expect(RealDataSummary.fractionName(0.09) == "a tenth")
    }

    @Test("Given only zeros as bars, when the placeholder check is read, then it needs no locale and agrees with the summary")
    func placeholderWithoutLocale() {
        let viewModel = RealDataViewModel()
        viewModel.isOnlyZeros = true
        viewModel.mark = .bars
        #expect(RealDataSummary.showsPlaceholder(days: viewModel.days, mark: .bars))
        #expect(viewModel.isDataToggleDisabled)
        viewModel.mark = .points
        #expect(!RealDataSummary.showsPlaceholder(days: viewModel.days, mark: .points))
        #expect(!viewModel.isDataToggleDisabled)
        #expect(RealDataSummary.showsPlaceholder(days: [], mark: .line))
    }

    @Test("Given either data set, when the caption is written, then it says the month is the invented sample")
    func captionSaysInvented() {
        let viewModel = RealDataViewModel()
        #expect(viewModel.caption(locale: english) == CafeWording.inventedDaysCaption(locale: english))
        viewModel.isRealData = true
        #expect(viewModel.caption(locale: english) == "Invented sample as traded: cups a day at the Harbour café, March 2026")
    }
}
