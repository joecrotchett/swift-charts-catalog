import SwiftUI

/// A slider under a row with its name and current value. VoiceOver reads the name and
/// `spokenValue`, the value written out in words ("60% of the outer radius").
struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1
    /// The value as shown beside the title, such as "60%" or "4 pt".
    let valueText: String
    /// The value as spoken. Defaults to `valueText`.
    var spokenValue: String?
    /// Called when a drag starts (`true`) and ends (`false`).
    var onEditingChanged: (Bool) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            LabeledContent(title, value: valueText)
                .accessibilityHidden(true)
            Slider(value: $value, in: range, step: step, onEditingChanged: onEditingChanged)
                .accessibilityLabel(title)
                .accessibilityValue(spokenValue ?? valueText)
        }
    }
}

#Preview {
    @Previewable @State var radius = 0.6
    ControlsSection {
        LabeledSlider(
            title: "Inner radius", value: $radius, range: 0 ... 0.7, step: 0.05,
            valueText: radius.formatted(.percent.precision(.fractionLength(0))),
            spokenValue: "\(radius.formatted(.percent.precision(.fractionLength(0)))) of the outer radius"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
