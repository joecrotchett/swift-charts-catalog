import Observation

/// The state behind the catalog's navigation: what is selected, and what a search shows.
@Observable
final class CatalogViewModel {
    let categories: [CatalogCategory]
    var selectedCategoryID: CatalogCategory.ID?
    var selectedScreenID: CatalogScreen.ID?
    var searchText = ""

    /// - Parameter openScreenID: a screen to open at once, as the `-screen <id>` launch argument asks.
    init(categories: [CatalogCategory] = Catalog.categories, openScreenID: String? = nil) {
        self.categories = categories
        selectedCategoryID = categories.first?.id
        if let openScreenID, let category = categories.first(where: { $0.screens.contains { $0.id == openScreenID } }) {
            selectedCategoryID = category.id
            selectedScreenID = openScreenID
        }
    }

    var selectedCategory: CatalogCategory? {
        categories.first { $0.id == selectedCategoryID }
    }

    var selectedScreen: CatalogScreen? {
        categories.lazy.flatMap(\.screens).first { $0.id == selectedScreenID }
    }

    var isSearching: Bool {
        !trimmedSearch.isEmpty
    }

    /// The screens to list: the selected category's, or, while searching, every match in the catalog.
    var visibleScreens: [CatalogScreen] {
        guard isSearching else { return selectedCategory?.screens ?? [] }
        return categories.flatMap(\.screens).filter { screen in
            screen.title.localizedStandardContains(trimmedSearch)
                || screen.summary.localizedStandardContains(trimmedSearch)
        }
    }

    var builtCount: Int {
        categories.reduce(0) { $0 + $1.builtCount }
    }

    var screenCount: Int {
        categories.reduce(0) { $0 + $1.screens.count }
    }

    private var trimmedSearch: String {
        searchText.trimmingCharacters(in: .whitespaces)
    }
}
