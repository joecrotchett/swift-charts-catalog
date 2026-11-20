@testable import SwiftChartsCatalog
import Testing

struct CatalogViewModelTests {
    private let categories = [
        CatalogCategory(id: "marks", title: "Marks", systemImage: "chart.bar", screens: [
            CatalogScreen(id: "marks/bar", title: "Bar", summary: "Bars from a baseline", apiSince: "16.0", skillReferences: [], isBuilt: true),
            CatalogScreen(id: "marks/line", title: "Line", summary: "Change over time", apiSince: "16.0", skillReferences: []),
        ]),
        CatalogCategory(id: "axes", title: "Axes", systemImage: "ruler", screens: [
            CatalogScreen(id: "axes/hiding", title: "Hiding axes", summary: "A bare chart for a small space", apiSince: "16.0", skillReferences: []),
        ]),
    ]

    @Test("Given a new catalog, when nothing has been chosen, then the first category is selected and no screen is")
    func startsOnFirstCategory() {
        let viewModel = CatalogViewModel(categories: categories)

        #expect(viewModel.selectedCategory?.id == "marks")
        #expect(viewModel.selectedScreen == nil)
        #expect(viewModel.visibleScreens.map(\.id) == ["marks/bar", "marks/line"])
    }

    @Test("Given a selected category, when another is chosen, then its screens are listed")
    func listsTheSelectedCategory() {
        let viewModel = CatalogViewModel(categories: categories)

        viewModel.selectedCategoryID = "axes"

        #expect(viewModel.visibleScreens.map(\.id) == ["axes/hiding"])
    }

    @Test("Given search text, when it matches a title or a summary in any category, then those screens are listed")
    func searchesTitlesAndSummaries() {
        let viewModel = CatalogViewModel(categories: categories)

        viewModel.searchText = "bar"

        #expect(viewModel.isSearching)
        #expect(viewModel.visibleScreens.map(\.id) == ["marks/bar", "axes/hiding"])
    }

    @Test("Given search text in another case, when it is matched, then case is ignored")
    func searchIgnoresCase() {
        let viewModel = CatalogViewModel(categories: categories)

        viewModel.searchText = "CHANGE"

        #expect(viewModel.visibleScreens.map(\.id) == ["marks/line"])
    }

    @Test("Given a search, when the text is cleared or only spaces, then the selected category's screens return")
    func clearingSearchRestoresTheCategory() {
        let viewModel = CatalogViewModel(categories: categories)
        viewModel.searchText = "axes"

        viewModel.searchText = "   "

        #expect(!viewModel.isSearching)
        #expect(viewModel.visibleScreens.map(\.id) == ["marks/bar", "marks/line"])
    }

    @Test("Given a selected screen, when a search is typed, then the selection is kept")
    func selectionSurvivesSearch() {
        let viewModel = CatalogViewModel(categories: categories)
        viewModel.selectedScreenID = "marks/bar"

        viewModel.searchText = "line"

        #expect(viewModel.selectedScreen?.id == "marks/bar")
    }

    @Test("Given the catalog, when progress is counted, then built screens and all screens are totalled")
    func countsProgress() {
        let viewModel = CatalogViewModel(categories: categories)

        #expect(viewModel.builtCount == 1)
        #expect(viewModel.screenCount == 3)
    }

    @Test("Given a screen id to open, when the catalog starts, then that screen and its category are selected")
    func opensARequestedScreen() {
        let viewModel = CatalogViewModel(categories: categories, openScreenID: "axes/hiding")

        #expect(viewModel.selectedCategory?.id == "axes")
        #expect(viewModel.selectedScreen?.id == "axes/hiding")
    }

    @Test("Given an unknown screen id to open, when the catalog starts, then it starts as usual")
    func ignoresAnUnknownScreen() {
        let viewModel = CatalogViewModel(categories: categories, openScreenID: "nowhere/nothing")

        #expect(viewModel.selectedCategory?.id == "marks")
        #expect(viewModel.selectedScreen == nil)
    }

    @Test("Given launch arguments, when they are parsed, then the screen id and the code flag are read, and absent ones are left unset")
    func parsesLaunchArguments() {
        let both = LaunchArguments(["app", "-screen", "marks/bar", "-showCode"])
        let none = LaunchArguments(["app"])
        let dangling = LaunchArguments(["app", "-screen"])

        #expect(both.screenID == "marks/bar")
        #expect(both.showsCode)
        #expect(none.screenID == nil)
        #expect(!none.showsCode)
        #expect(dangling.screenID == nil)
    }
}
