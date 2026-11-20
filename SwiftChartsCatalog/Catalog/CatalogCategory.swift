import Foundation

/// A group of screens about one part of the framework.
struct CatalogCategory: Identifiable, Hashable {
    let id: String
    let title: String
    let systemImage: String
    let screens: [CatalogScreen]

    var builtCount: Int {
        screens.count { $0.isBuilt }
    }
}
