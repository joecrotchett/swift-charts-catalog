import SwiftUI

/// The app's two tabs: the catalog of single-concept screens, and the dashboard, where the concepts
/// are combined on one data set.
struct RootView: View {
    @State private var tab: RootTab = LaunchArguments.current.opensDashboard ? .dashboard : .catalog

    var body: some View {
        TabView(selection: $tab) {
            Tab("Catalog", systemImage: "square.grid.2x2", value: RootTab.catalog) {
                CatalogView()
            }
            Tab("Dashboard", systemImage: "chart.bar.doc.horizontal", value: RootTab.dashboard) {
                DashboardView()
            }
        }
    }
}

enum RootTab: Hashable {
    case catalog
    case dashboard
}

/// The catalog: categories, the screens in one of them, and the selected screen.
/// Three columns on iPad; the same views collapse into a stack on iPhone.
struct CatalogView: View {
    @State private var viewModel = CatalogViewModel(openScreenID: LaunchArguments.current.screenID)
    /// On iPhone, where the columns collapse into a stack, start at the list of categories,
    /// unless the launch arguments name a screen.
    @State private var compactColumn: NavigationSplitViewColumn =
        LaunchArguments.current.screenID == nil ? .sidebar : .detail

    var body: some View {
        NavigationSplitView(preferredCompactColumn: $compactColumn) {
            CategoryList(viewModel: viewModel)
        } content: {
            ScreenList(viewModel: viewModel)
        } detail: {
            NavigationStack {
                if let screen = viewModel.selectedScreen {
                    ScreenDestination(screen: screen)
                } else {
                    ContentUnavailableView(
                        "Choose a screen",
                        systemImage: "chart.bar.xaxis",
                        description: Text("Each screen shows one Swift Charts concept and the code behind it.")
                    )
                }
            }
        }
    }
}

private struct CategoryList: View {
    @Bindable var viewModel: CatalogViewModel

    var body: some View {
        List(viewModel.categories, selection: $viewModel.selectedCategoryID) { category in
            Label(category.title, systemImage: category.systemImage)
                .badge(Text("\(category.builtCount)/\(category.screens.count)"))
                .accessibilityLabel(category.title)
                .accessibilityValue("\(category.builtCount) of \(category.screens.count) screens built")
        }
        .navigationTitle("Charts Catalog")
    }
}

private struct ScreenList: View {
    @Bindable var viewModel: CatalogViewModel

    var body: some View {
        List(viewModel.visibleScreens, selection: $viewModel.selectedScreenID) { screen in
            ScreenRow(screen: screen)
                // A planned screen is listed so the whole scope is visible, and cannot be opened.
                .selectionDisabled(!screen.isBuilt)
        }
        .overlay {
            if viewModel.isSearching, viewModel.visibleScreens.isEmpty {
                ContentUnavailableView.search(text: viewModel.searchText)
            }
        }
        .navigationTitle(viewModel.isSearching ? "Results" : viewModel.selectedCategory?.title ?? "Screens")
        .searchable(text: $viewModel.searchText, prompt: "Search all screens")
    }
}

private struct ScreenRow: View {
    let screen: CatalogScreen

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            HStack {
                Text(screen.title)
                    .font(.headline)
                Spacer()
                if !screen.isBuilt {
                    Text("Planned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text(screen.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)
        }
        .opacity(screen.isBuilt ? 1 : 0.55)
        .accessibilityElement(children: .combine)
        .accessibilityHint(screen.isBuilt ? "" : "Not built yet")
    }
}

#Preview {
    RootView()
}
