@testable import SwiftChartsCatalog
import Testing

struct SyntaxHighlighterTests {
    private typealias Token = SyntaxHighlighter.Token

    @Test("Given a line of Swift, when it is split, then joining the tokens gives the line back")
    func tokensRebuildTheLine() {
        let lines = [
            "    BarMark(x: .value(\"Drink\", item.drink), y: .value(\"Cups\", 12.5)) // one bar",
            "let name = \"a \\\"quoted\\\" word\"",
            "",
            "    ",
            "\"never closed",
        ]
        for line in lines {
            #expect(SyntaxHighlighter.tokens(in: line).map(\.text).joined() == line)
        }
    }

    @Test("Given a keyword, a string, a number and a comment, when the line is split, then each gets its kind")
    func classifiesEachKind() {
        let tokens = SyntaxHighlighter.tokens(in: "let cups = 42 + \"tea\".count // total")

        #expect(tokens == [
            Token(kind: .keyword, text: "let"),
            Token(kind: .plain, text: " cups = "),
            Token(kind: .number, text: "42"),
            Token(kind: .plain, text: " + "),
            Token(kind: .string, text: "\"tea\""),
            Token(kind: .plain, text: ".count "),
            Token(kind: .comment, text: "// total"),
        ])
    }

    @Test("Given a keyword inside a string or a comment, when the line is split, then it is not a keyword")
    func keywordsInsideStringsAndCommentsAreLeftAlone() {
        let inString = SyntaxHighlighter.tokens(in: "\"let it be\"")
        let inComment = SyntaxHighlighter.tokens(in: "// return to this")

        #expect(inString == [Token(kind: .string, text: "\"let it be\"")])
        #expect(inComment == [Token(kind: .comment, text: "// return to this")])
    }

    @Test("Given two slashes inside a string, when the line is split, then no comment starts there")
    func slashesInsideAStringAreNotAComment() {
        let tokens = SyntaxHighlighter.tokens(in: "let url = \"https://example.com\"")

        #expect(tokens.last == Token(kind: .string, text: "\"https://example.com\""))
        #expect(!tokens.contains { $0.kind == .comment })
    }

    @Test("Given a word that only contains a keyword, when the line is split, then it stays plain")
    func wordsContainingKeywordsStayPlain() {
        let tokens = SyntaxHighlighter.tokens(in: "letter.inside")

        #expect(tokens == [Token(kind: .plain, text: "letter.inside")])
    }

    @Test("Given a digit inside an identifier, when the line is split, then it is not a number")
    func digitsInsideIdentifiersStayPlain() {
        let tokens = SyntaxHighlighter.tokens(in: "value2")

        #expect(tokens == [Token(kind: .plain, text: "value2")])
    }

    @Test("Given an empty line, when it is split or styled, then nothing is produced and nothing fails")
    func emptyLineIsSafe() {
        #expect(SyntaxHighlighter.tokens(in: "").isEmpty)
        #expect(String(SyntaxHighlighter.attributed("").characters).isEmpty)
    }

    @Test("Given a line, when it is styled, then the text is unchanged")
    func stylingKeepsTheText() {
        let line = "    .foregroundStyle(by: .value(\"Size\", order.size))"

        #expect(String(SyntaxHighlighter.attributed(line).characters) == line)
    }
}
