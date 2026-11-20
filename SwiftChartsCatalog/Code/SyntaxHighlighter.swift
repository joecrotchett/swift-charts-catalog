import SwiftUI

/// Light syntax colouring for the Code view: keywords, strings, numbers and comments, nothing more.
enum SyntaxHighlighter {
    enum Kind: Equatable {
        case plain, keyword, string, number, comment
    }

    struct Token: Equatable {
        let kind: Kind
        let text: String
    }

    static let keywords: Set<String> = [
        "actor", "any", "as", "async", "await", "break", "case", "catch", "class", "continue", "default", "do",
        "else", "enum", "extension", "false", "for", "func", "guard", "if", "import", "in", "init", "is", "let",
        "nil", "private", "protocol", "return", "self", "some", "static", "struct", "switch", "throw", "throws",
        "true", "try", "var", "where", "while",
    ]

    /// Splits one line of Swift into coloured runs. Joining the tokens' text gives the line back.
    static func tokens(in line: String) -> [Token] {
        var tokens: [Token] = []
        var plain = ""
        var index = line.startIndex

        func flushPlain() {
            if !plain.isEmpty {
                tokens.append(Token(kind: .plain, text: plain))
                plain = ""
            }
        }

        while index < line.endIndex {
            let character = line[index]
            let rest = line[index...]

            if rest.hasPrefix("//") {
                flushPlain()
                tokens.append(Token(kind: .comment, text: String(rest)))
                return tokens
            }
            if character == "\"" {
                flushPlain()
                let end = endOfString(in: line, from: index)
                tokens.append(Token(kind: .string, text: String(line[index ..< end])))
                index = end
                continue
            }
            if character.isLetter || character == "_" {
                let end = line[index...].firstIndex { !($0.isLetter || $0.isNumber || $0 == "_") } ?? line.endIndex
                let word = String(line[index ..< end])
                if keywords.contains(word) {
                    flushPlain()
                    tokens.append(Token(kind: .keyword, text: word))
                } else {
                    plain += word
                }
                index = end
                continue
            }
            if character.isNumber {
                flushPlain()
                let end = line[index...].firstIndex { !($0.isNumber || $0 == "." || $0 == "_") } ?? line.endIndex
                tokens.append(Token(kind: .number, text: String(line[index ..< end])))
                index = end
                continue
            }
            plain.append(character)
            index = line.index(after: index)
        }
        flushPlain()
        return tokens
    }

    /// The index just past the string literal that opens at `start`, or the end of the line if it never closes.
    private static func endOfString(in line: String, from start: String.Index) -> String.Index {
        var index = line.index(after: start)
        while index < line.endIndex {
            if line[index] == "\\" {
                index = line.index(index, offsetBy: 2, limitedBy: line.endIndex) ?? line.endIndex
                continue
            }
            if line[index] == "\"" {
                return line.index(after: index)
            }
            index = line.index(after: index)
        }
        return line.endIndex
    }

    /// The line as styled text. Colour is an aid only; the text itself is unchanged.
    static func attributed(_ line: String) -> AttributedString {
        var result = AttributedString()
        for token in tokens(in: line) {
            var run = AttributedString(token.text)
            run.foregroundColor = color(for: token.kind)
            result += run
        }
        return result
    }

    static func color(for kind: Kind) -> Color {
        switch kind {
        case .plain: .primary
        case .keyword: .purple
        case .string: .red
        case .number: .blue
        case .comment: .secondary
        }
    }
}
