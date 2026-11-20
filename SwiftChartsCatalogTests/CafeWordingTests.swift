import Accessibility
import Foundation
@testable import SwiftChartsCatalog
import Testing

@MainActor
struct CafeWordingTests {
    private let english = Locale(identifier: "en_US")

    @Test("Given the recorded and the invented March, when their captions are written, then each says which it is and they differ")
    func dailyCaptionsTellTheTwoMarchesApart() {
        let recorded = CafeWording.harbourDaysCaption(locale: english)
        let invented = CafeWording.inventedDaysCaption(locale: english)

        #expect(recorded.hasPrefix("Cups sold each day at the Harbour café, March 1"))
        #expect(recorded.hasSuffix("28, 2026"))
        #expect(invented == "Invented sample: cups a day at the Harbour café, March 2026")
        #expect(recorded != invented)
        #expect(CafeData.thirtyDays.first?.cups != CafeData.harbourSales.first?.cups)
    }

    @Test("Given a run of Harbour's days, when its caption is written, then it names the café and those days, and without days it has no dates")
    func harbourDaysSliceCaption() {
        let fortnight = CafeWording.harbourDaysCaption(from: CafeData.day(0), to: CafeData.day(13), locale: english)

        #expect(fortnight == "Cups sold each day at the Harbour café, "
            + CafeWording.dayRange(CafeData.day(0), CafeData.day(13), locale: english))
        #expect(fortnight.hasSuffix("14, 2026"))
        #expect(CafeWording.harbourDaysCaption(from: nil, to: CafeData.day(13), locale: english)
            == "Cups sold each day at the Harbour café")
        #expect(CafeWording.harbourDaysCaption(locale: english)
            == CafeWording.harbourDaysCaption(from: CafeData.day(0), to: CafeData.day(27), locale: english))
    }

    @Test("Given the monthly ranges, when their caption is read, then it names the café and the months")
    func monthlyRangesCaption() {
        #expect(CafeWording.monthlyRangesCaption == "Cups a day at the Harbour café, by month")
    }

    @Test("Given a finite value, when a descriptor's count is written, then it is the words Int(value) gave")
    func finiteCountMatchesInt() {
        #expect(CafeWording.count(12, locale: english) == CafeWording.cups(12, locale: english))
        #expect(CafeWording.count(12.9, locale: english) == "12 cups")
        #expect(CafeWording.count(-3.7, locale: english) == CafeWording.cups(-3, locale: english))
        #expect(CafeWording.count(1, locale: english, as: CafeWording.people) == "1 person")
        #expect(CafeWording.count(1200, locale: Locale(identifier: "de_DE")).hasPrefix("1.200"))
    }

    @Test("Given counts of one and of many, when bars, sizes and bins are written, then each agrees in number")
    func barsAndSizesAgreeInNumber() {
        #expect(CafeWording.bars(1, locale: english) == "1 bar")
        #expect(CafeWording.bars(12, locale: english) == "12 bars")
        #expect(CafeWording.sizes(1, locale: english) == "1 size")
        #expect(CafeWording.sizes(3, locale: english) == "3 sizes")
        #expect(CafeWording.bins(1, locale: english) == "1 bin")
        #expect(CafeWording.bins(8, locale: english) == "8 bins")
    }

    @Test("Given a value that is not finite or does not fit an Int, when a descriptor's count is written, then it is empty and nothing traps", arguments: [
        Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude, -.greatestFiniteMagnitude,
    ])
    func unrepresentableValueIsEmpty(value: Double) {
        #expect(CafeWording.count(value, locale: english).isEmpty)
        #expect(CafeWording.count(value, locale: english, as: CafeWording.seconds).isEmpty)
    }

    @Test("Given chart descriptors, when the system asks for a value that is not finite, then each says nothing instead of trapping")
    func descriptorsSurviveNaN() throws {
        let descriptors: [AXChartDescriptor] = [
            DrinkSalesChartDescriptor(sales: CafeData.drinkSales, locale: english).makeChartDescriptor(),
            BoxPlotChartDescriptor(summary: BoxPlotViewModel().summary(locale: english)).makeChartDescriptor(),
        ]
        for descriptor in descriptors {
            let yAxis = try #require(descriptor.yAxis)
            #expect(yAxis.valueDescriptionProvider(.nan).isEmpty)
            #expect(!yAxis.valueDescriptionProvider(3).isEmpty)
        }
    }
}
