import SwiftUI

/// A segmented picker under a visible title. The title is read once, as the picker's label: a segmented
/// picker does not take its name from the `Picker` title (read on iOS: it had none), so it is set explicitly.
struct LabeledSegmentedPicker<Selection: Hashable, Options: View>: View {
    let title: String
    @Binding var selection: Selection
    @ViewBuilder let options: Options

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(title)
                .accessibilityHidden(true)
            Picker(title, selection: $selection) {
                options
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(title)
        }
    }
}

#Preview {
    @Previewable @State var form = "Basic"
    ControlsSection {
        LabeledSegmentedPicker(title: "Area form", selection: $form) {
            Text("Basic").tag("Basic")
            Text("Range").tag("Range")
        }
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
