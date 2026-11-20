import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct ColourAloneTests {
    let locale = Locale(identifier: "en_US")

    /// Two cafés with the same days, every value zero.
    func zeroStores() -> [StoreSales] {
        CafeData.storeSales.map { store in
            StoreSales(store: store.store, days: store.days.map { DailySales(day: $0.day, cups: 0) })
        }
    }

    // MARK: Headlines

    @Test("Given the sample data, when points are shown, then the headline counts each café's days")
    func pointHeadline() {
        let model = ColourAloneViewModel()
        #expect(model.headline(locale: locale) == "Station sold more on 15 days and Harbour on 13 days.")
        #expect(model.daysLed(by: CafeWording.station) == 15)
        #expect(model.daysLed(by: CafeWording.harbour) == 13)
    }

    @Test("Given the sample data, when stacked bars are shown, then the headline names the weeks each café led")
    func barHeadline() {
        let model = ColourAloneViewModel()
        model.form = .stackedBars
        #expect(model.headline(locale: locale) == "Station sold more in Week 1; Harbour in Week 2, Week 3, and Week 4.")
    }

    @Test("Given the second cue or greyscale, when either changes, then the headline does not")
    func headlineIgnoresStyling() {
        let model = ColourAloneViewModel()
        let before = model.headline(locale: locale)
        model.showsSecondCue = true
        model.showsGreyscale = true
        #expect(model.headline(locale: locale) == before)
    }

    @Test("Given no data, when either form is shown, then it draws nothing and the headline says so")
    func emptyData() {
        let model = ColourAloneViewModel(stores: [])
        #expect(!model.drawsPoints)
        #expect(!model.drawsBars)
        #expect(model.headline(locale: locale) == "No sales to compare.")
        model.form = .stackedBars
        #expect(model.headline(locale: locale) == "No cups sold to compare.")
    }

    @Test("Given only zeros, when points are shown, then they are drawn and the headline says the cafés tied")
    func zeroData() {
        let model = ColourAloneViewModel(stores: zeroStores())
        #expect(model.drawsPoints)
        #expect(model.headline(locale: locale) == "Harbour and Station sold the same on all 28 days.")
        #expect(model.pointAxis == 0 ... 50)
    }

    @Test("Given only zeros, when stacked bars are shown, then nothing is drawn and the headline says so")
    func zeroBars() {
        let model = ColourAloneViewModel(stores: zeroStores())
        model.form = .stackedBars
        #expect(!model.drawsBars)
        #expect(model.headline(locale: locale) == "No cups sold to compare.")
    }

    @Test("Given one café that always sold more, when points are shown, then the headline gives the other none")
    func oneSidedData() {
        let days = CafeData.harbourSales
        let stores = [
            StoreSales(store: CafeWording.harbour, days: days),
            StoreSales(store: CafeWording.station, days: days.map { DailySales(day: $0.day, cups: $0.cups - 1) }),
        ]
        let model = ColourAloneViewModel(stores: stores)
        #expect(model.headline(locale: locale) == "Harbour sold more on 28 days, Station on none.")
    }

    // MARK: Data and scales

    @Test("Given the sample data, when weeks are totalled, then each café has four weeks with Harbour first")
    func weeklyTotals() {
        let model = ColourAloneViewModel()
        #expect(model.weekNames == ["Week 1", "Week 2", "Week 3", "Week 4"])
        #expect(model.weeks.map(\.store).prefix(2) == [CafeWording.harbour, CafeWording.station])
        #expect(model.weeks.first { $0.week == "Week 1" && $0.store == CafeWording.harbour }?.cups == 1211)
        #expect(model.weeks.first { $0.week == "Week 1" && $0.store == CafeWording.station }?.cups == 1299)
        #expect(model.weeks.first { $0.week == "Week 4" && $0.store == CafeWording.harbour }?.cups == 1652)
    }

    @Test("Given the sample data, when the axes are worked out, then points run 150 to 300 and bars 0 to 3,500")
    func axes() {
        let model = ColourAloneViewModel()
        #expect(model.pointAxis == 150 ... 300)
        #expect(model.barAxis == 0 ... 3500)
    }

    @Test("Given the sample data, when the points are split for VoiceOver, then there are four weeks, each holding both cafés in café order")
    func pointWeeks() {
        let model = ColourAloneViewModel()
        #expect(model.pointWeeks.count == 4)
        #expect(model.pointWeeks.allSatisfy { $0.portions.map(\.store) == [CafeWording.harbour, CafeWording.station] })
        #expect(model.pointWeeks.allSatisfy { week in week.portions.allSatisfy { $0.days.count == 7 } })
    }

    @Test("Given the sample data, when the caption is written, then its period comes from the data in the locale")
    func captionPeriod() {
        let model = ColourAloneViewModel()
        let caption = model.caption(locale: locale)
        #expect(caption.hasPrefix("Cups a day at two cafés, March 1"))
        #expect(caption.hasSuffix("28"))
        model.form = .stackedBars
        #expect(model.caption(locale: locale).hasPrefix("Cups a week at two cafés, March 1"))
        #expect(ColourAloneViewModel(stores: []).caption(locale: locale) == "Cups a day at two cafés")
    }

    // MARK: Words

    @Test("Given each form, when the second cue's title is read, then it names the cue that form uses")
    func secondCueTitle() {
        let model = ColourAloneViewModel()
        #expect(model.secondCueTitle == "Add shape as a second cue")
        model.form = .stackedBars
        #expect(model.secondCueTitle == "Add labels as a second cue")
    }

    @Test("Given greyscale and no second cue, when the explanation is read, then it says the cafés cannot be told apart")
    func explanationWithoutCue() {
        let model = ColourAloneViewModel()
        model.showsGreyscale = true
        #expect(model.isShowingMistake)
        #expect(model.explanation(isAccessibilitySize: false).contains("nothing on the chart says which point is which"))
        model.form = .stackedBars
        #expect(model.explanation(isAccessibilitySize: false).contains("the legend cannot say which is Harbour"))
    }

    @Test("Given greyscale and the second cue, when the explanation is read, then it names what still tells them apart")
    func explanationWithCue() {
        let model = ColourAloneViewModel()
        model.showsGreyscale = true
        model.showsSecondCue = true
        #expect(!model.isShowingMistake)
        #expect(model.explanation(isAccessibilitySize: false).contains("Harbour's circles and Station's crosses"))
        model.form = .stackedBars
        #expect(model.explanation(isAccessibilitySize: false).contains("each segment still names its café"))
    }

    @Test("Given an accessibility text size, when the explanation is read, then it says what the axis and labels give up")
    func explanationAtLargeText() {
        let model = ColourAloneViewModel()
        #expect(model.explanation(isAccessibilitySize: true).contains("every two weeks"))
        #expect(!model.explanation(isAccessibilitySize: false).contains("every two weeks"))
        model.form = .stackedBars
        model.showsSecondCue = true
        #expect(model.explanation(isAccessibilitySize: true).contains("stop growing"))
        #expect(model.explanation(isAccessibilitySize: true).contains("H for Harbour and S for Station"))
        #expect(ColourAloneViewModel.weekNumber("Week 3") == "3")
    }

    @Test("Given the second cue switched on, when the change is announced, then it says what changed and then the headline")
    func announcementSecondCue() {
        let model = ColourAloneViewModel()
        model.showsSecondCue = true
        #expect(model.announcement(after: .secondCue, locale: locale)
            == "Shapes added: Harbour as circles, Station as crosses. \(model.headline(locale: locale))")
        model.form = .stackedBars
        model.showsSecondCue = false
        #expect(model.announcement(after: .secondCue, locale: locale)
            == "Labels removed: the segments are told apart by colour alone. \(model.headline(locale: locale))")
    }

    @Test("Given the form switched to bars, when the change is announced, then it names the bars and the bars' headline")
    func announcementForm() {
        let model = ColourAloneViewModel()
        model.form = .stackedBars
        #expect(model.announcement(after: .form, locale: locale)
            == "Showing stacked bars, one segment per café per week. Station sold more in Week 1; Harbour in Week 2, Week 3, and Week 4.")
    }

    @Test("Given the sample data, when element text is read, then it gives the café and week, then values with units")
    func elementText() throws {
        let model = ColourAloneViewModel()
        let week = try #require(model.pointWeeks.first)
        #expect(model.weekLabel(week, locale: locale) == "March 1 to March 7")
        #expect(model.weekValue(week, locale: locale).hasPrefix("Harbour lowest 152 cups, highest 219 cups; Station lowest "))
        let segment = try #require(model.weeks.first)
        #expect(model.segmentLabel(segment) == "Week 1, Harbour")
        #expect(model.segmentValue(segment, locale: locale) == "1,211 cups")
    }

    // MARK: Audio Graph

    @Test("Given the points, when the descriptor is made, then it has both cafés over 28 days on the drawn axis")
    func pointDescriptor() throws {
        let model = ColourAloneViewModel()
        let descriptor = model.pointDescriptor(locale: locale).makeChartDescriptor()
        #expect(descriptor.title?.hasPrefix("Cups a day at the Harbour and Station cafés, March 1") == true)
        #expect(descriptor.title?.hasSuffix("28") == true)
        #expect(descriptor.summary?.contains(model.pointHeadline(locale: locale)) == true)
        #expect(descriptor.summary?.contains("Harbour from 152 cups to 282 cups") == true)
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 28 && !$0.isContinuous })
        let xAxis = try #require(descriptor.xAxis as? AXCategoricalDataAxisDescriptor)
        #expect(xAxis.categoryOrder.first == "March 1")
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 150 ... 300)
        #expect(yAxis.valueDescriptionProvider(1) == "1 cup")
        #expect(yAxis.valueDescriptionProvider(200) == "200 cups")
        #expect(yAxis.valueDescriptionProvider(.nan) == "")
    }

    @Test("Given the bars, when the descriptor is made, then each café is a series of its own weekly cups")
    func barDescriptor() throws {
        let model = ColourAloneViewModel()
        let descriptor = model.barDescriptor(locale: locale).makeChartDescriptor()
        #expect(descriptor.title == "Cups a week at the Harbour and Station cafés, stacked")
        #expect(descriptor.summary?.contains("Week 1: Harbour 1,211 cups and Station 1,299 cups") == true)
        #expect(descriptor.series.map(\.name) == [CafeWording.harbour, CafeWording.station])
        #expect(descriptor.series.allSatisfy { $0.dataPoints.count == 4 && !$0.isContinuous })
        let yAxis = try #require(descriptor.yAxis)
        #expect(yAxis.range == 0 ... 3500)
    }

    // MARK: Snippets

    @Test("Given each form and cue, when the snippets are listed, then they show that state's code and the colour scale")
    func snippetsFollowState() {
        let model = ColourAloneViewModel()
        #expect(model.snippets.map(\.name) == [ColourAloneViewModel.snippetColourOnly, ColourAloneViewModel.snippetEqualWeight])
        model.showsSecondCue = true
        #expect(model.snippets.map(\.name).first == ColourAloneViewModel.snippetColourAndShape)
        model.form = .stackedBars
        #expect(model.snippets.map(\.name).first == ColourAloneViewModel.snippetBarsLabelled)
        model.showsSecondCue = false
        #expect(model.snippets.map(\.name).first == ColourAloneViewModel.snippetBarsColourOnly)
        model.showsGreyscale = true
        #expect(model.snippets.map(\.name).last == ColourAloneViewModel.snippetGreyscale)
    }

    @Test("Given the app's snippets, when they are loaded, then every snippet this screen shows exists")
    func snippetsExist() throws {
        let store = try SnippetStore()
        for name in [
            ColourAloneViewModel.snippetColourOnly, ColourAloneViewModel.snippetColourAndShape,
            ColourAloneViewModel.snippetBarsColourOnly, ColourAloneViewModel.snippetBarsLabelled,
            ColourAloneViewModel.snippetEqualWeight, ColourAloneViewModel.snippetGreyscale,
        ] {
            #expect(store[name] != nil, "missing \(name)")
        }
    }
}
