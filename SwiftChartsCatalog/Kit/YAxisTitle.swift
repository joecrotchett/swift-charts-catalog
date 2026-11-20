import Charts
import SwiftUI

/// A y axis title that stays clear of the axis's top label at every text size.
///
/// At its default place (above the plot, at the trailing edge) the title sits over the y axis's top value label, and
/// at the largest text sizes the two run into each other ("Wait (seconds)" over "400"). The skill's fix (`axes.md`):
/// put the title above the plot at its leading edge, which kept it clear up to `.accessibility3`, and use a shorter
/// title at `.accessibility4` and `.accessibility5`, where even a 16-character title still met the label.
///
/// Adopting it, in place of `.chartYAxisLabel(title)`:
/// ```swift
/// Chart(waits) { ... }
///     .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)   // "Wait (seconds)", "Wait (s)"
/// ```
/// Keep the descriptor's axis title the full one: the short title is only for what is drawn at the largest sizes.
struct YAxisTitle: ViewModifier {
    let title: String
    let shortTitle: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content.chartYAxisLabel(
            Self.title(title, short: shortTitle, at: dynamicTypeSize), position: .top, alignment: .leading
        )
    }

    /// The title drawn at a text size: the short one from `.accessibility4` up, when there is one.
    nonisolated static func title(_ title: String, short shortTitle: String?, at size: DynamicTypeSize) -> String {
        guard let shortTitle, size >= .accessibility4 else { return title }
        return shortTitle
    }
}

extension View {
    /// The y axis's title above the plot at its leading edge, and `short` in its place at `.accessibility4` and
    /// up. See `YAxisTitle`.
    func yAxisTitle(_ title: String, short shortTitle: String? = nil) -> some View {
        modifier(YAxisTitle(title: title, shortTitle: shortTitle))
    }
}

#Preview {
    VStack {
        ForEach([DynamicTypeSize.large, .accessibility5], id: \.self) { size in
            Chart(CafeData.drinkSales) { sale in
                BarMark(x: .value(CafeWording.drink, sale.drink), y: .value(CafeWording.cups, sale.cups))
            }
            .yAxisTitle(CafeWording.waitAxisTitle, short: CafeWording.waitAxisShortTitle)
            .dynamicTypeSize(size)
        }
    }
    .padding()
}
