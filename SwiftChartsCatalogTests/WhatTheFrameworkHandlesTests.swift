import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import SwiftUI
import Testing

@MainActor
struct WhatTheFrameworkHandlesTests {
    private let english = Locale(identifier: "en_US")
    private let denver = TimeZone(identifier: "America/Denver") ?? .gmt
    private let sampleTotals = FrameworkHandlesRunningTotal.totals(of: CafeData.harbourSales)

    private func makeViewModel(days: [DailySales] = CafeData.harbourSales) -> WhatTheFrameworkHandlesViewModel {
        WhatTheFrameworkHandlesViewModel(days: days, deviceLocale: english)
    }

    // MARK: The settings

    @Test("Given a new screen, when nothing has been chosen, then nothing is forced on the chart")
    func startsOnTheDevice() {
        let viewModel = makeViewModel()

        #expect(viewModel.chartEnvironment == .device)
    }

    @Test("Given the appearance control, when dark is chosen, then only the colour scheme is forced")
    func appearanceForcesOnlyTheColourScheme() {
        let viewModel = makeViewModel()

        viewModel.appearance = .dark

        #expect(viewModel.chartEnvironment == ChartEnvironment(colorScheme: .dark))
    }

    @Test("Given the text size control, when an accessibility size is chosen, then only the text size is forced")
    func textSizeForcesOnlyTheTextSize() {
        let viewModel = makeViewModel()

        viewModel.textSize = .accessibility5

        #expect(viewModel.chartEnvironment == ChartEnvironment(dynamicTypeSize: .accessibility5))
    }

    @Test("Given the locale control, when Arabic is chosen, then only the locale is forced and the layout direction is left alone")
    func localeForcesOnlyTheLocale() {
        let viewModel = makeViewModel()

        viewModel.locale = .arabic

        #expect(viewModel.chartEnvironment == ChartEnvironment(locale: Locale(identifier: "ar_EG")))
        #expect(viewModel.chartEnvironment.layoutDirection == nil)
    }

    @Test("Given the text size control, when its choices are listed, then at least one is an accessibility size")
    func offersAnAccessibilitySize() {
        let sizes = FrameworkHandlesTextSize.allCases.compactMap(\.dynamicTypeSize)

        #expect(sizes.contains { $0.isAccessibilitySize })
    }

    @Test("Given every setting forced, when the chart's data is read, then it is the same as with none forced")
    func dataDoesNotFollowTheSettings() {
        let viewModel = makeViewModel()
        let before = viewModel.totals

        viewModel.appearance = .dark
        viewModel.textSize = .accessibility2
        viewModel.locale = .german

        #expect(viewModel.totals == before)
    }

    // MARK: Snippets

    @Test("Given any setting, when the snippets are read, then they are the one chart, because its code never changes")
    func snippetsAreTheSameInEverySetting() {
        let viewModel = makeViewModel()
        let names = ["what-the-framework-handles-chart"]
        #expect(viewModel.snippets.map(\.name) == names)

        for appearance in FrameworkHandlesAppearance.allCases {
            for textSize in FrameworkHandlesTextSize.allCases {
                for locale in FrameworkHandlesLocale.allCases {
                    viewModel.appearance = appearance
                    viewModel.textSize = textSize
                    viewModel.locale = locale
                    #expect(viewModel.snippets.map(\.name) == names)
                }
            }
        }
    }

    @Test("Given the built app, when the screen's snippet is looked up, then it exists and configures no colour, font, format or axis")
    func snippetExistsAndConfiguresNothing() throws {
        let store = try SnippetStore(bundle: .main)

        for reference in WhatTheFrameworkHandlesViewModel.snippets {
            let snippet = try #require(store[reference.name])
            #expect(snippet.file == "StartHere/WhatTheFrameworkHandlesScreen.swift")
            #expect(snippet.code.contains("LineMark("))
            for configured in ["foregroundStyle", ".font(", "format:", "chartXAxis", "chartYAxis", ".environment("] {
                #expect(!snippet.code.contains(configured))
            }
        }
    }

    // MARK: Data

    @Test("Given the café's four weeks, when the running totals are made, then each day adds to the ones before it")
    func totalsAccumulate() {
        let days = CafeData.harbourSales

        #expect(sampleTotals.count == 28)
        #expect(sampleTotals.first?.cups == days.first?.cups)
        #expect(sampleTotals.last?.cups == days.map(\.cups).reduce(0, +))
        #expect(sampleTotals.last?.cups == 5726)
        #expect(zip(sampleTotals, sampleTotals.dropFirst()).allSatisfy { $0.cups < $1.cups })
    }

    @Test("Given days counted in UTC, when the totals are made for a device west of Greenwich, then each is the start of the same calendar day there")
    func daysMoveToTheDeviceDay() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = denver

        let totals = FrameworkHandlesRunningTotal.totals(of: CafeData.harbourSales, timeZone: denver)

        let first = try #require(totals.first)
        let last = try #require(totals.last)
        #expect(calendar.dateComponents([.year, .month, .day, .hour], from: first.day)
            == DateComponents(year: 2026, month: 3, day: 1, hour: 0))
        #expect(calendar.dateComponents([.year, .month, .day, .hour], from: last.day)
            == DateComponents(year: 2026, month: 3, day: 28, hour: 0))
    }

    @Test("Given no days, when the totals are made, then there are none")
    func noDaysNoTotals() {
        #expect(FrameworkHandlesRunningTotal.totals(of: []).isEmpty)
    }

    // MARK: Headline

    @Test("Given the sample data, when the headline is written in English, then it gives the last point of the line")
    func headlineGivesTheTotal() {
        #expect(makeViewModel().headline == "The café sold 5,726 cups in 28 days.")
    }

    @Test("Given a forced locale, when the headline is written, then its figure stays in the device's locale, like the words around it")
    func headlineFigureStaysInTheDeviceLocale() {
        let viewModel = makeViewModel()

        for locale in FrameworkHandlesLocale.allCases {
            viewModel.locale = locale
            #expect(viewModel.headline == "The café sold 5,726 cups in 28 days.")
        }
    }

    @Test("Given a device in German, when the headline is written, then its figures are grouped as that device groups them")
    func headlineFollowsTheDeviceLocale() {
        let viewModel = WhatTheFrameworkHandlesViewModel(deviceLocale: Locale(identifier: "de_DE"))
        viewModel.locale = .arabic

        #expect(viewModel.headline == "The café sold 5.726 cups in 28 days.")
    }

    @Test("Given no data or only zeros, when the headline is written, then it says nothing was sold")
    func headlineIsTrueWithNothingSold() {
        let zeros = [DailySales(day: CafeData.day(0), cups: 0), DailySales(day: CafeData.day(1), cups: 0)]

        #expect(makeViewModel(days: []).headline == "No cups sold yet.")
        #expect(makeViewModel(days: zeros).headline == "No cups sold yet.")
    }

    @Test("Given one cup on one day, when the headline is written, then its units agree in number")
    func headlineAgreesInNumber() {
        let viewModel = makeViewModel(days: [DailySales(day: CafeData.day(0), cups: 1)])

        #expect(viewModel.headline == "The café sold 1 cup in 1 day.")
    }

    // MARK: Explanation

    @Test("Given nothing forced, when the explanation is written, then it gives the concept and says the chart follows the device")
    func explanationOnTheDevice() {
        let viewModel = makeViewModel()

        #expect(viewModel.explanation(deviceTextSize: .large)
            == WhatTheFrameworkHandlesViewModel.concept + " " + WhatTheFrameworkHandlesViewModel.devicePrompt)
    }

    @Test("Given one setting forced, when the explanation is written, then it says what that setting changed and nothing about the others")
    func explanationNamesOnlyWhatIsForced() {
        let viewModel = makeViewModel()

        viewModel.appearance = .dark

        #expect(viewModel.explanation(deviceTextSize: .large).hasPrefix(WhatTheFrameworkHandlesViewModel.concept))
        #expect(viewModel.explanation(deviceTextSize: .large).contains("Dark:"))
        #expect(!viewModel.explanation(deviceTextSize: .large).contains("Text size:"))
        #expect(!viewModel.explanation(deviceTextSize: .large).contains("Locale:"))
        #expect(!viewModel.explanation(deviceTextSize: .large).contains(WhatTheFrameworkHandlesViewModel.devicePrompt))
    }

    @Test("Given every setting forced, when the explanation is written, then it has a note for each, in the order of the controls")
    func explanationCoversEverySetting() throws {
        let viewModel = makeViewModel()

        viewModel.appearance = .light
        viewModel.textSize = .extraExtraExtraLarge
        viewModel.locale = .japanese

        let text = viewModel.explanation(deviceTextSize: .large)
        let appearance = try #require(text.range(of: "Light:"))
        let textSize = try #require(text.range(of: "Text size:"))
        let locale = try #require(text.range(of: "Locale:"))
        #expect(appearance.lowerBound < textSize.lowerBound)
        #expect(textSize.lowerBound < locale.lowerBound)
    }

    @Test("Given an accessibility text size, when the explanation is written, then it says what the framework did not do")
    func explanationIsHonestAboutLargeText() {
        let viewModel = makeViewModel()

        viewModel.textSize = .accessibility5
        #expect(viewModel.explanation(deviceTextSize: .large).contains("did not do"))

        viewModel.textSize = .extraExtraExtraLarge
        #expect(!viewModel.explanation(deviceTextSize: .large).contains("did not do"))
    }

    @Test("Given a device at an accessibility size and the control on Device, when the explanation is written, then it still says the date labels are cut short")
    func explanationFollowsTheDeviceTextSize() {
        let viewModel = makeViewModel()

        let text = viewModel.explanation(deviceTextSize: .accessibility3)

        #expect(viewModel.chartEnvironment == .device)
        #expect(text.contains(WhatTheFrameworkHandlesViewModel.devicePrompt))
        #expect(text.contains("this device's text is large enough that the date labels no longer fit"))
        #expect(text.contains("did not do"))
        #expect(!text.contains("grew with the text"))
    }

    @Test("Given a device at an accessibility size, when a smaller size is forced, then the note follows the forced size")
    func explanationFollowsTheForcedSizeOverTheDevice() {
        let viewModel = makeViewModel()

        viewModel.textSize = .extraExtraExtraLarge
        let text = viewModel.explanation(deviceTextSize: .accessibility5)

        #expect(viewModel.effectiveTextSize(deviceTextSize: .accessibility5) == .xxxLarge)
        #expect(text.contains("grew with the text"))
        #expect(!text.contains("did not do"))
    }

    @Test("Given the Arabic locale, when the explanation is written, then it says the control does not mirror the chart, not that the chart is unmirrored")
    func explanationSaysTheControlDoesNotMirror() {
        let viewModel = makeViewModel()

        viewModel.locale = .arabic
        let text = viewModel.explanation(deviceTextSize: .large)

        #expect(text.contains("This control does not mirror the chart"))
        #expect(text.contains("left as the device has it"))
        #expect(!text.contains("is not mirrored"))
    }

    @Test("Given each text size, when the chart is drawn at phone width, then the date labels are cut short from Accessibility 2, as rendered")
    func dateLabelsAreCutShortFromAccessibility2() {
        #expect(!WhatTheFrameworkHandlesViewModel.cutsDateLabelsShort(at: .large))
        #expect(!WhatTheFrameworkHandlesViewModel.cutsDateLabelsShort(at: .xxxLarge))
        #expect(!WhatTheFrameworkHandlesViewModel.cutsDateLabelsShort(at: .accessibility1))
        #expect(WhatTheFrameworkHandlesViewModel.cutsDateLabelsShort(at: .accessibility2))
        #expect(WhatTheFrameworkHandlesViewModel.cutsDateLabelsShort(at: .accessibility5))
        #expect(makeViewModel().explanation(deviceTextSize: .accessibility1).hasSuffix(WhatTheFrameworkHandlesViewModel.devicePrompt))
    }

    // MARK: Announcement

    @Test("Given one control changes, when the change is announced, then it names that control, all three settings and the unchanged data")
    func announcementNamesWhatChanged() {
        let viewModel = makeViewModel()
        let before = viewModel.chartEnvironment

        viewModel.locale = .german

        #expect(
            viewModel.announcement(after: before, deviceTextSize: .large)
                == "Chart redrawn: locale changed. Shown in the device's appearance, at the device's text size, "
                + "in German (Germany) formats. The line is the same: The café sold 5,726 cups in 28 days."
        )
    }

    @Test("Given all three controls forced, when a change is announced, then the description is built from all three")
    func announcementIsBuiltFromEveryControl() {
        let viewModel = makeViewModel()
        viewModel.appearance = .dark
        viewModel.locale = .arabic
        let before = viewModel.chartEnvironment

        viewModel.textSize = .accessibility2

        #expect(
            viewModel.announcement(after: before, deviceTextSize: .large)
                == "Chart redrawn: text size changed. Shown in the dark appearance, at Accessibility 2 text size, "
                + "in Arabic (Egypt) formats. Date labels that no longer fit are cut short. "
                + "The line is the same: The café sold 5,726 cups in 28 days."
        )
    }

    @Test("Given a device at an accessibility size, when the text size returns to Device, then the announcement still says the date labels are cut short")
    func announcementFollowsTheEffectiveTextSize() {
        let viewModel = makeViewModel()
        viewModel.textSize = .extraExtraExtraLarge
        let before = viewModel.chartEnvironment
        #expect(!viewModel.displayDescription(deviceTextSize: .accessibility4).contains("cut short"))

        viewModel.textSize = .device

        #expect(viewModel.announcement(after: before, deviceTextSize: .accessibility4).contains("at the device's text size"))
        #expect(viewModel.announcement(after: before, deviceTextSize: .accessibility4).contains("cut short"))
        #expect(!viewModel.announcement(after: before, deviceTextSize: .large).contains("cut short"))
    }

    @Test("Given no sales, when a control changes, then the announcement says there is nothing sold, not that a line is the same")
    func announcementWithNoData() {
        let viewModel = makeViewModel(days: [])
        let before = viewModel.chartEnvironment

        viewModel.appearance = .light

        #expect(
            viewModel.announcement(after: before, deviceTextSize: .large)
                == "Chart redrawn: appearance changed. Shown in the light appearance, at the device's text size, "
                + "in the device's formats. No cups sold yet."
        )
    }

    // MARK: Words for assistive technologies

    @Test("Given a count of cups or days, when it is written, then the unit agrees with the number")
    func unitsAgreeInNumber() {
        #expect(FrameworkHandlesSummary.cupsText(1) == "1 cup")
        #expect(FrameworkHandlesSummary.cupsText(0) == "0 cups")
        #expect(FrameworkHandlesSummary.cupsText(92) == "92 cups")
        #expect(FrameworkHandlesSummary.daysText(1) == "1 day")
        #expect(FrameworkHandlesSummary.daysText(28) == "28 days")
    }

    @Test("Given a day's total, when its value is written for VoiceOver, then it has its unit and says it is a running total")
    func spokenValueHasUnit() {
        #expect(FrameworkHandlesSummary(totals: sampleTotals).spokenValue(190) == "190 cups so far")
    }

    @Test("Given a day, when its label is written for VoiceOver, then it is the weekday, month and day in words")
    func spokenDayIsWrittenOut() throws {
        let first = try #require(sampleTotals.first)

        #expect(FrameworkHandlesSummary(totals: sampleTotals).spokenDay(first.day)
            == first.day.formatted(.dateTime.weekday(.wide).month(.wide).day()))
    }

    @Test("Given the sample data, when the Audio Graph summary is written, then it gives the days and the first and last totals")
    func summaryGivesActualValues() {
        let summary = FrameworkHandlesSummary(totals: sampleTotals)

        #expect(summary.audioGraphSummary
            == "28 days. 190 cups after the first day, \(5726.formatted()) cups after the last.")
        #expect(FrameworkHandlesSummary(totals: []).audioGraphSummary == "No cups sold yet.")
    }

    @Test("Given the sample data, when the chart descriptor is made, then it has a title, the summary and one named continuous series")
    func descriptorDescribesTheChart() throws {
        let descriptor = FrameworkHandlesChartDescriptor(totals: sampleTotals).makeChartDescriptor()

        #expect(descriptor.title == "Running total of cups sold at the Harbour café, by day")
        #expect(descriptor.summary == FrameworkHandlesSummary(totals: sampleTotals).audioGraphSummary)
        #expect(descriptor.series.count == 1)
        let series = try #require(descriptor.series.first)
        #expect(series.name == "Harbour")
        #expect(series.isContinuous)
        #expect(series.dataPoints.count == 28)
    }

    @Test("Given the sample data, when the descriptor's axes are read, then the days are written out in order and values are said in cups from zero")
    func descriptorAxes() throws {
        let descriptor = FrameworkHandlesChartDescriptor(totals: sampleTotals).makeChartDescriptor()
        let summary = FrameworkHandlesSummary(totals: sampleTotals)
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        let yAxis = try #require(descriptor.yAxis)

        #expect(xAxis.title == "Day")
        #expect(xAxis.categoryOrder == sampleTotals.map { summary.spokenDay($0.day) })
        #expect(Set(xAxis.categoryOrder).count == 28)
        #expect(yAxis.title == "Cups sold so far")
        // 5,726 at the end, on an axis drawn to 6,000: the descriptor says 6,000.
        #expect(yAxis.range == 0 ... 6000)
        #expect(yAxis.valueDescriptionProvider(92) == "92 cups")
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
    }
}
