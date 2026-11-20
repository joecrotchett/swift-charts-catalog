import Foundation
@testable import SwiftChartsCatalog
import Testing

struct SnippetStoreTests {
    @Test("Given the built app, when the store loads its bundle, then it holds the region extracted from the app's own source")
    func loadsFromAppBundle() throws {
        let store = try SnippetStore(bundle: .main)

        let snippet = try #require(store[SnippetStore.pipelineCheckName])
        #expect(snippet.file == "Code/SnippetStore.swift")
        #expect(snippet.code.contains("static let pipelineCheckName = \"pipeline-check\""))
    }

    @Test("Given an extracted region, when it is read, then the indentation its lines shared is gone")
    func regionIsDedented() throws {
        let store = try SnippetStore(bundle: .main)

        let snippet = try #require(store[SnippetStore.pipelineCheckName])
        #expect(snippet.code.hasPrefix("/// A fixed region"))
    }

    @Test("Given the script's JSON, when it is decoded, then names are sorted and each snippet is found by name")
    func decodesScriptOutput() throws {
        let json = #"{"b": {"code": "BarMark()", "file": "Marks/Bar.swift"}, "a": {"code": "AxisMarks()", "file": "Axes/Axis.swift"}}"#

        let store = try SnippetStore(data: Data(json.utf8))

        #expect(store.names == ["a", "b"])
        #expect(store["b"] == CodeSnippet(code: "BarMark()", file: "Marks/Bar.swift"))
        #expect(store["missing"] == nil)
    }

    @Test("Given a bundle with no snippet file, when the store loads it, then it reports the missing resource")
    func missingResourceThrows() {
        #expect(throws: SnippetStore.LoadError.missingResource) {
            try SnippetStore(bundle: Bundle(for: BundleMarker.self))
        }
    }

    @Test("Given malformed JSON, when it is decoded, then decoding fails")
    func malformedJSONThrows() {
        #expect(throws: (any Error).self) {
            try SnippetStore(data: Data("[1, 2]".utf8))
        }
    }
}

/// Lives in the test bundle, which has no `Snippets.json`.
private final class BundleMarker {}
