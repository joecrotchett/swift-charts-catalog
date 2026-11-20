import SwiftUI

/// What a chart shows, in words, above the chart: a short caption and the message in a sentence.
struct ScreenHeadline: View {
    let caption: String
    let message: String
    /// The longest message the screen can show, laid out unseen behind the message so the headline keeps its height
    /// when the message changes, and the chart below it does not move. `nil` reserves nothing.
    ///
    /// **Only for a headline that a selection or a scroll rewrites**, while a finger is on the chart: there the chart
    /// must not move under the finger (the skill's review checklist, *Interaction*). A headline that a control
    /// rewrites (a picker, a toggle, a stepper) passes `nil`: the reader is not touching the chart, and a reserve
    /// costs a blank band under every message shorter than the longest. That band was what the reviews saw, 55 to
    /// 90 points at the default size and up to about 350 at the largest, on screens whose headline only a control
    /// changes. When the message shown is the longest one the reserve costs nothing (measured in a render: the
    /// headline is the same height with and without it).
    ///
    /// Nothing is reserved at the accessibility text sizes, where the longest message can be several lines taller
    /// than the one shown and the reserve pushes the chart off the first screen behind nothing; there a chart that
    /// moves is the smaller harm.
    var reservedMessage: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(caption.uppercased())
                .font(.caption)
                .foregroundStyle(.secondary)
            ZStack(alignment: .topLeading) {
                if let reserve = Self.reserve(reservedMessage, at: dynamicTypeSize) {
                    Text(reserve)
                        .hidden()
                        .accessibilityHidden(true)
                }
                Text(message)
            }
            .font(.title3.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// The message to reserve room for at a text size: `reservedMessage`, or nothing at the accessibility sizes.
    nonisolated static func reserve(_ reservedMessage: String?, at size: DynamicTypeSize) -> String? {
        size.isAccessibilitySize ? nil : reservedMessage
    }
}

#Preview {
    ScreenHeadline(caption: "Cups sold today", message: "Tea outsold every other drink.")
        .padding()
}

#Preview("Reserved height") {
    ScreenHeadline(
        caption: "Cups sold today", message: "Tea: 40 cups.",
        reservedMessage: "The busiest drink was tea, with forty cups sold before noon."
    )
    .padding()
}
