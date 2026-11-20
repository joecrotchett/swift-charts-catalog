import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct OneFocusTests {
    private let locale = Locale(identifier: "en_US")
    private var july: MonthlySummary {
        CafeData.monthlySummaries[4]
    }

    private var march: MonthlySummary {
        CafeData.monthlySummaries[0]
    }

    // MARK: States

    @Test("Given a new screen, when it opens, then the busiest month leads with no average line and no mistake")
    func startsFocusedOnBusiestMonth() {
        let viewModel = OneFocusViewModel()

        #expect(viewModel.focusedMonth == july.month)
        #expect(!viewModel.showsAverage)
        #expect(!viewModel.isShowingMistake)
        #expect(viewModel.hasData)
    }

    @Test("Given a month in focus, when the chart is drawn, then it leads and every other month is faded")
    func focusFadesTheRest() {
        let viewModel = OneFocusViewModel()

        #expect(viewModel.emphasis(of: july) == .focused)
        for month in viewModel.months where month.month != july.month {
            #expect(viewModel.emphasis(of: month) == .faded)
        }
        #expect(OneFocusEmphasis.faded.barOpacity() < OneFocusEmphasis.focused.barOpacity())
        #expect(OneFocusEmphasis.faded.tickOpacity() == OneFocusEmphasis.fadedStrength)
        // Dark Mode fades less, so the faded months still show on the dark panel.
        #expect(OneFocusEmphasis.faded.tickOpacity(isDark: true) == OneFocusEmphasis.fadedStrengthDark)
        #expect(OneFocusEmphasis.faded.barOpacity(isDark: true) > OneFocusEmphasis.faded.barOpacity())
        #expect(OneFocusEmphasis.faded.barOpacity(isDark: true) < OneFocusEmphasis.focused.barOpacity(isDark: true))
        #expect(viewModel.isLabelled(july))
        #expect(!viewModel.isLabelled(march))
    }

    @Test("Given the average line, when it is shown, then every month is grey and none is labelled")
    func averageMutesEveryMonth() {
        let viewModel = OneFocusViewModel()
        viewModel.showsAverage = true

        for month in viewModel.months {
            #expect(viewModel.emphasis(of: month) == .muted)
            #expect(!viewModel.isLabelled(month))
        }
        #expect(OneFocusEmphasis.muted.isGrey)
    }

    @Test("Given the mistake, when it is shown with or without the average, then every month is at full strength")
    func mistakeKeepsEverythingFull() {
        let viewModel = OneFocusViewModel()
        viewModel.isShowingMistake = true
        #expect(viewModel.months.allSatisfy { viewModel.emphasis(of: $0) == .full })

        viewModel.showsAverage = true
        #expect(viewModel.months.allSatisfy { viewModel.emphasis(of: $0) == .full })
        #expect(!OneFocusEmphasis.full.isGrey)
    }

    @Test("Given each setting, when the identity is read, then it differs, so VoiceOver reads fresh text")
    func identityFollowsEveryState() {
        let viewModel = OneFocusViewModel()
        var identities: Set<String> = [viewModel.chartIdentity]
        viewModel.focusedMonth = march.month
        identities.insert(viewModel.chartIdentity)
        viewModel.showsAverage = true
        identities.insert(viewModel.chartIdentity)
        viewModel.isShowingMistake = true
        identities.insert(viewModel.chartIdentity)

        #expect(identities.count == 4)
    }

    // MARK: Words

    @Test("Given July in focus, when the headline is written, then it gives July's labelled low, high and average")
    func monthHeadline() {
        let viewModel = OneFocusViewModel()

        #expect(viewModel.headline(locale: locale) == "July's days ran from 171 to 347 cups, 253 on average.")
    }

    @Test("Given the average line, when the headline is written, then it gives the day-weighted average of six months")
    func averageHeadline() {
        let viewModel = OneFocusViewModel()
        viewModel.showsAverage = true

        #expect(viewModel.overallAverage == 231)
        #expect(viewModel.headline(locale: locale) == "Across 6 months, the average day sold 231 cups.")
    }

    @Test("Given no months or only zeros, when the headline is written, then it says so and nothing is drawn")
    func emptyAndZeroHeadlines() {
        let empty = OneFocusViewModel(months: [])
        #expect(!empty.hasData)
        #expect(empty.headline(locale: locale) == "No months to show yet.")

        let zeros = OneFocusViewModel(months: [
            MonthlySummary(month: CafeData.month(0), lowestDay: 0, highestDay: 0, averageDay: 0),
        ])
        zeros.showsAverage = true
        #expect(!zeros.hasData)
        #expect(zeros.headline(locale: locale) == "No cups sold in these months.")
    }

    @Test("Given a month of one cup, when it is written, then the count agrees in number")
    func countsAgree() {
        let one = MonthlySummary(month: CafeData.month(0), lowestDay: 1, highestDay: 1, averageDay: 1)
        let viewModel = OneFocusViewModel(months: [one])

        #expect(viewModel.headline(locale: locale) == "March's days ran from 1 to 1 cup, 1 on average.")
        #expect(viewModel.elementValue(for: one, locale: locale) == "Lowest day 1 cup, highest day 1 cup, average day 1 cup")
    }

    @Test("Given a German locale, when the headline is written, then its numbers are written the German way")
    func headlineTakesLocale() {
        let big = MonthlySummary(month: CafeData.month(0), lowestDay: 1200, highestDay: 2400, averageDay: 1800)
        let viewModel = OneFocusViewModel(months: [big])

        #expect(viewModel.headline(locale: Locale(identifier: "de_DE")).contains("1.200"))
    }

    @Test("Given one month under the average line in the mistake, when the explanation is written, then the bar count agrees in number")
    func explanationCountsBars() throws {
        let month = try #require(CafeData.monthlySummaries.first)
        let viewModel = OneFocusViewModel(months: [month])
        viewModel.showsAverage = true
        viewModel.isShowingMistake = true
        #expect(viewModel.explanation(locale: locale).contains("competes with 1 bar of its own colour"))
    }

    @Test("Given each state, when the explanation is written, then it describes what is drawn")
    func explanationFollowsState() {
        let viewModel = OneFocusViewModel()
        #expect(viewModel.explanation(locale: locale).hasPrefix("July is drawn at full strength"))
        #expect(viewModel.explanation(locale: locale).contains("faded to 30% of its strength"))
        viewModel.showsAverage = true
        #expect(viewModel.explanation(locale: locale).hasPrefix("Every month is grey"))
        viewModel.isShowingMistake = true
        #expect(viewModel.explanation(locale: locale).hasPrefix("The months keep their full blue"))
        #expect(viewModel.explanation(locale: locale).contains("competes with 6 bars of its own colour"))
        viewModel.showsAverage = false
        #expect(viewModel.explanation(locale: locale).hasPrefix("Every month is at full strength"))
    }

    // MARK: VoiceOver and announcements

    @Test("Given July in focus, when its element is read, then it is named in focus, with its three values")
    func elementText() {
        let viewModel = OneFocusViewModel()

        #expect(viewModel.elementLabel(for: july, locale: locale) == "July, in focus")
        #expect(viewModel.elementLabel(for: march, locale: locale) == "March")
        #expect(viewModel.elementValue(for: july, locale: locale)
            == "Lowest day 171 cups, highest day 347 cups, average day 253 cups")
        viewModel.isShowingMistake = true
        #expect(viewModel.elementLabel(for: july, locale: locale) == "July")
    }

    @Test("Given the average line, when its rule is read, then it has a label and a value with its unit")
    func ruleText() {
        let viewModel = OneFocusViewModel()

        #expect(viewModel.ruleLabel == "Average across all months")
        #expect(viewModel.ruleValue(locale: locale) == "231 cups a day")
    }

    @Test("Given a change of focus or of the line, when it is announced, then it says what changed, then the headline")
    func announcements() {
        let viewModel = OneFocusViewModel()
        viewModel.focusedMonth = march.month
        #expect(viewModel.focusAnnouncement(locale: locale)
            == "March in focus. March's days ran from 152 to 282 cups, 205 on average.")

        viewModel.showsAverage = true
        #expect(viewModel.averageAnnouncement(locale: locale)
            == "Average line shown, months greyed under it. Across 6 months, the average day sold 231 cups.")
    }

    // MARK: Snippets

    @Test("Given each setting, when the snippets are listed, then they name regions the build extracted")
    func snippetsExist() throws {
        let store = try SnippetStore()
        let viewModel = OneFocusViewModel()
        #expect(viewModel.snippets.map(\.name) == ["one-focus-at-a-time-chart", "one-focus-at-a-time-emphasis"])
        viewModel.isShowingMistake = true
        #expect(viewModel.snippets.map(\.name) == ["one-focus-at-a-time-chart", "one-focus-at-a-time-mistake"])

        for name in ["one-focus-at-a-time-chart", "one-focus-at-a-time-emphasis", "one-focus-at-a-time-mistake"] {
            #expect(store[name] != nil)
        }
    }

    // MARK: Audio Graph

    @Test("Given the chart, when its descriptor is made, then it names three series over the months on the drawn axis")
    func descriptor() throws {
        let viewModel = OneFocusViewModel()
        let descriptor = OneFocusChartDescriptor(
            months: viewModel.months, cupsAxis: viewModel.cupsAxis,
            summary: viewModel.audioGraphSummary(locale: locale), locale: locale
        ).makeChartDescriptor()

        #expect(descriptor.title == "Cups a day by month at the Harbour café, March to August 2026")
        #expect(descriptor.series.map(\.name) == ["Lowest day", "Average day", "Highest day"])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 6 && !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder == ["March", "April", "May", "June", "July", "August"])
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 350)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
        #expect(descriptor.summary?.contains("In focus: July") == true)
    }

    @Test("Given the average line, when the summary is written, then it states the line's value")
    func summaryWithAverage() {
        let viewModel = OneFocusViewModel()
        viewModel.showsAverage = true

        #expect(viewModel.audioGraphSummary(locale: locale)
            == "6 months. Lowest day 152 cups in March, highest day 347 cups in July. Average line at 231 cups a day.")
    }
}
