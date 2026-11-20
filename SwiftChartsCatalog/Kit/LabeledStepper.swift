import SwiftUI

/// A stepper beside its visible title and current value (under them at the accessibility text sizes), read by
/// VoiceOver once: its name, then the value in words.
///
/// A `Stepper` with a visible label and an `.accessibilityLabel` is read with both, the label's text first: "Bins,
/// 8 asked for, 6 drawn, Bins" and "Cafés, 5", value "5" (read on iOS). Here the visible row is hidden from
/// VoiceOver and the stepper carries the name alone, with its value spoken from `spokenValue`, the same way
/// `LabeledSlider` does for a slider.
///
/// Adopting it, in place of a `Stepper` with a label and accessibility modifiers:
/// ```swift
/// LabeledStepper(
///     title: "Bins", value: $model.desiredBinCount, in: BinningViewModel.binCountRange,
///     valueText: model.binCountText(locale: locale),             // "8 asked for, 6 drawn"
///     spokenValue: model.binCountSpokenValue(locale: locale)     // "8 bins asked for, 6 drawn. ..."
/// )
/// ```
/// Name the setting in `title` and give its value in `valueText`; the count or setting goes in the value, never in
/// the title, or it is spoken twice.
struct LabeledStepper<Value: Strideable>: View {
    let title: String
    @Binding var value: Value
    let range: ClosedRange<Value>
    var step: Value.Stride = 1
    /// The value as shown beside the title, such as "8 asked for, 6 drawn".
    let valueText: String
    /// The value as spoken. Defaults to `valueText`.
    var spokenValue: String?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        title: String, value: Binding<Value>, in range: ClosedRange<Value>, step: Value.Stride = 1,
        valueText: String, spokenValue: String? = nil
    ) {
        self.title = title
        _value = value
        self.range = range
        self.step = step
        self.valueText = valueText
        self.spokenValue = spokenValue
    }

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                LabeledStepperText(title: title, valueText: valueText, stacked: true)
                stepper
            }
        } else {
            HStack {
                LabeledStepperText(title: title, valueText: valueText, stacked: false)
                stepper
            }
        }
    }

    private var stepper: some View {
        Stepper(title, value: $value, in: range, step: step)
            .labelsHidden()
            .accessibilityValue(spokenValue ?? valueText)
    }
}

/// The stepper's visible title and value, hidden from VoiceOver: the stepper says both.
private struct LabeledStepperText: View {
    let title: String
    let valueText: String
    let stacked: Bool

    var body: some View {
        Group {
            if stacked {
                VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                    Text(title)
                    Text(valueText)
                        .foregroundStyle(.secondary)
                }
            } else {
                LabeledContent(title, value: valueText)
            }
        }
        .monospacedDigit()
        .accessibilityHidden(true)
    }
}

#Preview {
    @Previewable @State var bins = 8
    ControlsSection {
        LabeledStepper(
            title: "Bins", value: $bins, in: 2 ... 20, valueText: "\(bins) asked for",
            spokenValue: "\(bins) bins asked for"
        )
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
