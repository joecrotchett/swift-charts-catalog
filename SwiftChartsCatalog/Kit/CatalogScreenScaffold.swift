import SwiftUI

/// The layout every catalog screen shares: headline, chart, explanation, controls, the API's release,
/// and the See Code button. A screen supplies its chart and, if it has any, its controls.
struct CatalogScreenScaffold<ChartContent: View, Controls: View>: View {
    let screen: CatalogScreen
    /// A short caption for the chart, such as "Cups sold today".
    let caption: String
    /// The chart's message in a sentence.
    let message: String
    /// The longest message a selection or scroll can write, so the chart does not move under the finger when the
    /// message changes. Only for a headline a selection or scroll rewrites: one a control rewrites passes `nil`.
    /// Ignored at the accessibility text sizes. See `ScreenHeadline.reservedMessage`.
    var reservedMessage: String?
    /// Two or three sentences on the concept the screen demonstrates.
    let explanation: String
    /// The snippets to show, when they depend on the controls. Defaults to the screen's own.
    var snippets: [SnippetReference]?
    /// The chart panel's height: the app's standard, or as tall as the chart when it sizes itself.
    var panelHeight: ChartPanelHeight = .standard
    /// The title above the controls.
    var controlsTitle = ControlsSection<EmptyView>.defaultTitle
    @ViewBuilder let chart: ChartContent
    @ViewBuilder let controls: Controls

    @State private var isShowingCode = LaunchArguments.current.showsCode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
                ScreenHeadline(caption: caption, message: message, reservedMessage: reservedMessage)
                ChartPanel(height: panelHeight) { chart }
                Text(explanation)
                    .foregroundStyle(.secondary)
                controls
                    .environment(\.controlsSectionTitle, controlsTitle)
                APIBadge(apiSince: screen.apiSince)
            }
            .padding(Layout.screenPadding)
            .frame(maxWidth: Layout.readableWidth)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(screen.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("See Code", systemImage: "chevron.left.forwardslash.chevron.right") {
                    isShowingCode = true
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .sheet(isPresented: $isShowingCode) {
            CodeView(screen: screen, snippets: snippets ?? screen.snippets)
        }
    }
}

extension CatalogScreenScaffold where Controls == EmptyView {
    /// A screen with no controls.
    init(
        screen: CatalogScreen, caption: String, message: String, reservedMessage: String? = nil,
        explanation: String, snippets: [SnippetReference]? = nil, panelHeight: ChartPanelHeight = .standard,
        @ViewBuilder chart: () -> ChartContent
    ) {
        self.init(
            screen: screen, caption: caption, message: message, reservedMessage: reservedMessage,
            explanation: explanation, snippets: snippets, panelHeight: panelHeight, chart: chart, controls: { EmptyView() }
        )
    }
}

#Preview {
    NavigationStack {
        CatalogScreenScaffold(
            screen: CatalogScreen(
                id: "preview", title: "A screen", summary: "", apiSince: "16.0", skillReferences: ["marks.md"],
                snippets: [SnippetReference(name: SnippetStore.pipelineCheckName, title: "Check")]
            ),
            caption: "Cups sold today",
            message: "Tea outsold every other drink.",
            explanation: "The chart goes in the panel above; this text says what the screen demonstrates."
        ) {
            Color.blue.opacity(0.2)
        }
    }
}
