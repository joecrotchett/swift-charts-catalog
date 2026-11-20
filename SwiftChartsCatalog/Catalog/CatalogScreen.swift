import Foundation

/// A snippet a screen shows in its Code view: the region's name in the source and a title for it.
struct SnippetReference: Hashable {
    let name: String
    let title: String
}

/// One screen of the catalog: a single Swift Charts concept.
struct CatalogScreen: Identifiable, Hashable {
    let id: String
    let title: String
    /// What the screen demonstrates, in a sentence.
    let summary: String
    /// The release that introduced the API the screen shows, such as "16.0".
    let apiSince: String
    /// The skill references the screen draws on.
    let skillReferences: [String]
    /// The code regions its Code view shows, in order.
    var snippets: [SnippetReference] = []
    /// Whether the screen exists yet. Planned screens are listed and cannot be opened.
    var isBuilt = false
}
