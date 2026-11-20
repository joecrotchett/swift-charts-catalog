import SwiftUI

/// The container for a screen's controls, so pickers and toggles look the same on every screen.
/// Its title is "Try it" unless the scaffold's `controlsTitle` or the section's own `title` says otherwise.
struct ControlsSection<Content: View>: View {
    static var defaultTitle: String {
        "Try it"
    }

    /// A title for this section alone, such as "Compare"; `nil` takes the scaffold's.
    var title: String?
    @ViewBuilder let content: Content
    @Environment(\.controlsSectionTitle) private var scaffoldTitle

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            Text(title ?? scaffoldTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .accessibilityAddTraits(.isHeader)
            content
        }
        .padding(Layout.panelPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

extension EnvironmentValues {
    /// The title the scaffold gives the controls sections inside it.
    @Entry var controlsSectionTitle = ControlsSection<EmptyView>.defaultTitle
}

#Preview {
    @Previewable @State var isOn = true
    ControlsSection {
        Toggle("Show the average", isOn: $isOn)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
