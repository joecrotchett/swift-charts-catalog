import Foundation
@testable import SwiftChartsCatalog
import Testing

struct CodeViewModelTests {
    private final class RecordingPasteboard: PasteboardWriting {
        private(set) var written: [String] = []

        func write(_ text: String) {
            written.append(text)
        }
    }

    private let screen = CatalogScreen(id: "s", title: "Screen", summary: "", apiSince: "16.0", skillReferences: [])
    private let mark = SnippetReference(name: "mark", title: "The mark")
    private let scale = SnippetReference(name: "scale", title: "The scale")

    private func store() throws -> SnippetStore {
        let json = #"{"mark": {"code": "BarMark()\n    .opacity(1)", "file": "A.swift"}, "scale": {"code": "chartYScale()", "file": "A.swift"}}"#
        return try SnippetStore(data: Data(json.utf8))
    }

    @Test("Given a screen's snippets, when the view model is made, then they keep their declared order and the first is selected")
    func resolvesInOrder() throws {
        let viewModel = try CodeViewModel(screen: screen, snippets: [scale, mark], store: store())

        #expect(viewModel.entries.map(\.id) == ["scale", "mark"])
        #expect(viewModel.selectedEntry?.id == "scale")
        #expect(viewModel.missingNames.isEmpty)
    }

    @Test("Given a snippet, when its lines are read, then the code is split at line breaks with indentation kept")
    func splitsIntoLines() throws {
        let viewModel = try CodeViewModel(screen: screen, snippets: [mark], store: store())

        #expect(viewModel.selectedEntry?.lines == ["BarMark()", "    .opacity(1)"])
    }

    @Test("Given a name the store does not hold, when the view model is made, then the entry is kept and reported as missing")
    func reportsMissingSnippets() throws {
        let gone = SnippetReference(name: "gone", title: "Gone")

        let viewModel = try CodeViewModel(screen: screen, snippets: [gone, mark], store: store())

        #expect(viewModel.entries.count == 2)
        #expect(viewModel.missingNames == ["gone"])
        #expect(viewModel.selectedEntry?.snippet == nil)
    }

    @Test("Given no store, when the view model is made, then every snippet is missing and nothing fails")
    func worksWithoutAStore() {
        let viewModel = CodeViewModel(screen: screen, snippets: [mark], store: nil)

        #expect(viewModel.missingNames == ["mark"])
        #expect(viewModel.selectedEntry?.lines.isEmpty == true)
    }

    @Test("Given a selected snippet, when it is copied, then its code goes to the pasteboard and the copy is noted")
    func copiesTheSelectedSnippet() throws {
        let pasteboard = RecordingPasteboard()
        let viewModel = try CodeViewModel(screen: screen, snippets: [mark, scale], store: store(), pasteboard: pasteboard)
        viewModel.select("scale")

        viewModel.copySelected()

        #expect(pasteboard.written == ["chartYScale()"])
        #expect(viewModel.didCopy)
    }

    @Test("Given a missing snippet, when copy is asked for, then nothing is written")
    func doesNotCopyAMissingSnippet() {
        let pasteboard = RecordingPasteboard()
        let viewModel = CodeViewModel(screen: screen, snippets: [mark], store: nil, pasteboard: pasteboard)

        viewModel.copySelected()

        #expect(pasteboard.written.isEmpty)
        #expect(!viewModel.didCopy)
    }

    @Test("Given a copy was made, when another snippet is selected, then the copied state resets")
    func selectingResetsCopied() throws {
        let viewModel = try CodeViewModel(screen: screen, snippets: [mark, scale], store: store(), pasteboard: RecordingPasteboard())
        viewModel.copySelected()

        viewModel.select("scale")

        #expect(!viewModel.didCopy)
        #expect(viewModel.selectedEntry?.id == "scale")
    }

    @Test("Given a screen with no snippets, when the view model is made, then nothing is selected")
    func handlesNoSnippets() {
        let viewModel = CodeViewModel(screen: screen, snippets: [], store: nil)

        #expect(viewModel.selectedEntry == nil)
    }
}
