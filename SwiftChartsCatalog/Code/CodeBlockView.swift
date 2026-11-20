import SwiftUI

/// Code shown as in a plain editor: numbered lines in a monospaced font that scroll sideways, never wrap.
struct CodeBlockView: View {
    let lines: [String]

    var body: some View {
        ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: Layout.codeLineSpacing) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: Layout.codeGutterSpacing) {
                        Text(index + 1, format: .number)
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: gutterWidth, alignment: .trailing)
                            // The number is for the eye; VoiceOver reads the code itself.
                            .accessibilityHidden(true)
                        Text(SyntaxHighlighter.attributed(line.isEmpty ? " " : line))
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
            }
            .font(.system(.footnote, design: .monospaced))
            .textSelection(.enabled)
            .padding(Layout.codePadding)
        }
        .background(Color(.secondarySystemBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }

    /// Wide enough for the largest line number, growing with the text size.
    @ScaledMetric(relativeTo: .footnote) private var digitWidth: CGFloat = 9

    private var gutterWidth: CGFloat {
        digitWidth * CGFloat(String(lines.count).count)
    }
}

#Preview {
    CodeBlockView(lines: [
        "Chart(sales) { item in",
        "    BarMark(",
        "        x: .value(\"Drink\", item.drink), // the category",
        "        y: .value(\"Cups sold\", item.cups)",
        "    )",
        "}",
    ])
    .padding()
}
