import Observation
import UIKit

/// Somewhere copied text can go. The app uses the system pasteboard; tests use a recorder.
protocol PasteboardWriting {
    func write(_ text: String)
}

struct SystemPasteboard: PasteboardWriting {
    func write(_ text: String) {
        UIPasteboard.general.string = text
    }
}

/// The state behind the Code view: which snippets a screen shows, which is selected, and copying.
@Observable
final class CodeViewModel {
    /// One snippet as the Code view shows it.
    struct Entry: Identifiable, Equatable {
        let reference: SnippetReference
        /// The code, or `nil` when the name is not in the store.
        let snippet: CodeSnippet?

        var id: String {
            reference.name
        }

        var lines: [String] {
            snippet?.code.components(separatedBy: "\n") ?? []
        }
    }

    let screen: CatalogScreen
    let entries: [Entry]
    var selectedName: String
    private(set) var didCopy = false
    private let pasteboard: any PasteboardWriting

    init(
        screen: CatalogScreen, snippets: [SnippetReference], store: SnippetStore?,
        pasteboard: any PasteboardWriting = SystemPasteboard()
    ) {
        self.screen = screen
        entries = snippets.map { Entry(reference: $0, snippet: store?[$0.name]) }
        selectedName = snippets.first?.name ?? ""
        self.pasteboard = pasteboard
    }

    var selectedEntry: Entry? {
        entries.first { $0.id == selectedName }
    }

    /// Names declared by the screen that the store does not hold.
    var missingNames: [String] {
        entries.filter { $0.snippet == nil }.map(\.id)
    }

    func copySelected() {
        guard let code = selectedEntry?.snippet?.code else { return }
        pasteboard.write(code)
        didCopy = true
    }

    func select(_ name: String) {
        selectedName = name
        didCopy = false
    }
}
