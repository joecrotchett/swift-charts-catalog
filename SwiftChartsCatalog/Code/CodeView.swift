import SwiftUI

/// The sheet behind See Code: the snippets for the concept a screen demonstrates.
struct CodeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: CodeViewModel

    init(screen: CatalogScreen, snippets: [SnippetReference], store: SnippetStore? = try? SnippetStore()) {
        _viewModel = State(initialValue: CodeViewModel(screen: screen, snippets: snippets, store: store))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                    if viewModel.entries.count > 1 {
                        SnippetPicker(viewModel: viewModel)
                    }
                    if let entry = viewModel.selectedEntry, entry.snippet != nil {
                        CodeBlockView(lines: entry.lines)
                    } else {
                        ContentUnavailableView(
                            "No code to show",
                            systemImage: "chevron.left.forwardslash.chevron.right",
                            description: Text("This screen's snippet was not found in the app.")
                        )
                    }
                    CodeFooter(screen: viewModel.screen)
                }
                .padding(Layout.screenPadding)
            }
            .navigationTitle(viewModel.screen.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(
                        viewModel.didCopy ? "Copied" : "Copy",
                        systemImage: viewModel.didCopy ? "checkmark" : "doc.on.doc"
                    ) {
                        viewModel.copySelected()
                    }
                    .disabled(viewModel.selectedEntry?.snippet == nil)
                }
            }
        }
    }
}

/// Chooses between a screen's snippets when it has more than one: segments when there are two and both titles fit
/// whole, otherwise a menu on its own row under its title.
///
/// Segments were chosen by count alone, so two long titles were cut short ("A point per reading, an arr…"), and the
/// menu sat in `LabeledContent`'s trailing column, where a long title wrapped to three lines and its last was clipped
/// ("Bars: category axis on the bottom edge"). `ViewThatFits` now measures the segments' titles whole, and the menu
/// has the full row to wrap in.
struct SnippetPicker: View {
    @Bindable var viewModel: CodeViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        if Self.mayUseSegments(count: viewModel.entries.count, accessibilitySize: dynamicTypeSize.isAccessibilitySize) {
            ViewThatFits(in: .horizontal) {
                SnippetChoices(viewModel: viewModel)
                    .pickerStyle(.segmented)
                SnippetMenu(viewModel: viewModel)
            }
        } else {
            SnippetMenu(viewModel: viewModel)
        }
    }

    /// Past this many, segments are too narrow for any title at phone width.
    static let segmentLimit = 2

    /// Whether segments are tried at all: two snippets at most, and never at the accessibility text sizes, where no
    /// two titles fit side by side. Even then they are used only when both titles fit whole.
    static func mayUseSegments(count: Int, accessibilitySize: Bool) -> Bool {
        count <= segmentLimit && !accessibilitySize
    }
}

/// The menu on a row of its own under its visible title, so the selected title has the row's full width to wrap in.
/// The menu's label is plain text that wraps to as many lines as it needs: a menu-style `Picker` draws its own label
/// at a fixed height, and at `.accessibility3` it clipped the first of three lines (seen in a render). The menu holds
/// the same picker inline, so the choices keep their checkmark. VoiceOver reads it once: "Snippet", then the title.
private struct SnippetMenu: View {
    @Bindable var viewModel: CodeViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Text(SnippetChoices.title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            Menu {
                SnippetChoices(viewModel: viewModel)
                    .pickerStyle(.inline)
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: Layout.tightSpacing) {
                    Text(selectedTitle)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.up.chevron.down")
                        .imageScale(.small)
                }
            }
            .accessibilityLabel(SnippetChoices.title)
            .accessibilityValue(selectedTitle)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var selectedTitle: String {
        viewModel.selectedEntry?.reference.title ?? ""
    }
}

/// The picker itself, styled by its container.
private struct SnippetChoices: View {
    static let title = "Snippet"
    @Bindable var viewModel: CodeViewModel

    var body: some View {
        Picker(Self.title, selection: Binding(
            get: { viewModel.selectedName },
            set: { viewModel.select($0) }
        )) {
            ForEach(viewModel.entries) { entry in
                Text(entry.reference.title).tag(entry.id)
            }
        }
    }
}

/// Where the API came from: its release, and the skill reference the screen draws on.
private struct CodeFooter: View {
    let screen: CatalogScreen

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            APIBadge(apiSince: screen.apiSince)
            if !screen.skillReferences.isEmpty {
                Text("Skill reference: \(screen.skillReferences.formatted(.list(type: .and)))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    CodeView(
        screen: CatalogScreen(
            id: "preview", title: "A screen", summary: "", apiSince: "16.0", skillReferences: ["marks.md"]
        ),
        snippets: [SnippetReference(name: "one", title: "The mark"), SnippetReference(name: "two", title: "The scale")],
        store: try? SnippetStore(data: Data(#"{"one": {"code": "BarMark(x: .value(\"Drink\", name))", "file": "A.swift"}, "two": {"code": "// a comment\nlet count = 42", "file": "A.swift"}}"#.utf8))
    )
}
