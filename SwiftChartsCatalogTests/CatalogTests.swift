@testable import SwiftChartsCatalog
import Testing

struct CatalogTests {
    @Test("Given the catalog, when its categories are counted, then there are the seventeen the outline lists, none empty")
    func hasEveryCategory() {
        #expect(Catalog.categories.count == 17)
        #expect(Catalog.categories.allSatisfy { !$0.screens.isEmpty })
    }

    @Test("Given the catalog, when ids are collected, then no category or screen shares one")
    func idsAreUnique() {
        let categoryIDs = Catalog.categories.map(\.id)
        let screenIDs = Catalog.allScreens.map(\.id)
        #expect(Set(categoryIDs).count == categoryIDs.count)
        #expect(Set(screenIDs).count == screenIDs.count)
    }

    @Test("Given every screen, when its text is read, then it has a title, a summary and a release")
    func screensAreDescribed() {
        for screen in Catalog.allScreens {
            #expect(!screen.title.isEmpty, "\(screen.id)")
            #expect(!screen.summary.isEmpty, "\(screen.id)")
            #expect(Double(screen.apiSince) != nil, "\(screen.id)")
        }
    }

    @Test("Given a built screen, when its snippets are looked up, then it declares at least one and each is in the app bundle")
    func builtScreensHaveTheirSnippets() throws {
        let store = try SnippetStore(bundle: .main)
        for screen in Catalog.allScreens where screen.isBuilt {
            #expect(!screen.snippets.isEmpty, "\(screen.id) shows no code")
            for reference in screen.snippets {
                #expect(store[reference.name] != nil, "\(screen.id) names a missing snippet: \(reference.name)")
            }
        }
    }

    @Test("Given a planned screen, when its snippets are read, then it declares none")
    func plannedScreensHaveNoSnippets() {
        for screen in Catalog.allScreens where !screen.isBuilt {
            #expect(screen.snippets.isEmpty, "\(screen.id)")
        }
    }

    @Test("Given the registry, when its ids are checked against the catalog, then every registered screen is in the catalog and is marked built")
    func registryMatchesCatalog() {
        for id in ScreenRegistry.entries.keys {
            #expect(Catalog.screen(id: id)?.isBuilt == true, "\(id) is registered and not in the catalog")
        }
        let built = Set(Catalog.allScreens.filter(\.isBuilt).map(\.id))
        #expect(built == Set(ScreenRegistry.entries.keys))
    }

    @Test("Given a screen id, when it is looked up, then the catalog returns that screen, and nothing for an unknown id")
    func looksUpByID() {
        #expect(Catalog.screen(id: "start-here/your-first-chart")?.title == "Your first chart")
        #expect(Catalog.screen(id: "nowhere/nothing") == nil)
    }
}
