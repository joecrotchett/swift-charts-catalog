import SwiftUI

/// A control beside its visible title, or under it at the accessibility text sizes, where the two no longer
/// fit side by side. The visible title is hidden from VoiceOver: the control carries the same words as its own
/// label, so it is read once. In a `LabeledContent` row a menu picker was read twice ("Day, Day, All four
/// weeks", read on iOS).
struct LabeledControlRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text(title)
                    .accessibilityHidden(true)
                control
            }
        } else {
            HStack {
                Text(title)
                    .accessibilityHidden(true)
                Spacer()
                control
            }
        }
    }
}

/// A menu picker in a `LabeledControlRow`: its title shown once and read once, as the picker's label.
struct LabeledMenuPicker<Selection: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let options: Options

    var body: some View {
        LabeledControlRow(title: title) {
            Picker(title, selection: $selection) {
                options
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

#Preview {
    @Previewable @State var position = "Top"
    ControlsSection {
        LabeledMenuPicker(title: "Position", selection: $position) {
            Text("Top").tag("Top")
            Text("Overlay").tag("Overlay")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
