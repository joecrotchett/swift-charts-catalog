import Foundation

/// One region of the app's own source, as "See Code" shows it.
struct CodeSnippet: Decodable, Equatable {
    /// The region's lines, with the indentation they share removed.
    let code: String
    /// The source file it came from, relative to the app's source folder.
    let file: String
}

/// The snippets extracted from the app's source at build time by `scripts/extract_snippets.py`.
///
/// A region is everything between a `snippet:<name>` comment and the next `end` comment. Because
/// the build writes `Snippets.json` from the compiled source, the code on screen cannot drift
/// from the code that drew the chart.
struct SnippetStore {
    enum LoadError: Error, Equatable {
        case missingResource
    }

    private let snippets: [String: CodeSnippet]

    /// Reads `Snippets.json` from a bundle.
    init(bundle: Bundle = .main) throws {
        guard let url = bundle.url(forResource: "Snippets", withExtension: "json") else {
            throw LoadError.missingResource
        }
        try self.init(data: Data(contentsOf: url))
    }

    /// Decodes the JSON the extraction script writes.
    init(data: Data) throws {
        snippets = try JSONDecoder().decode([String: CodeSnippet].self, from: data)
    }

    /// Every snippet name, sorted.
    var names: [String] {
        snippets.keys.sorted()
    }

    subscript(name: String) -> CodeSnippet? {
        snippets[name]
    }
}

extension SnippetStore {
    // snippet:pipeline-check
    /// A fixed region that proves the build's extraction step ran. The tests read it back.
    static let pipelineCheckName = "pipeline-check"
    // end
}
