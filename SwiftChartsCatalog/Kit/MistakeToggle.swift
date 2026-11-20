import SwiftUI

/// The switch on screens that can show the wrong way to do something, so the mistake is seen and named.
struct MistakeToggle: View {
    /// What the mistake is, such as "Leave out the series".
    let title: String
    @Binding var isShowingMistake: Bool
    /// On a screen with two charts, the one that shows the mistake, such as "lower"; `nil` when there is one chart.
    var chart: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            Toggle(title, isOn: $isShowingMistake)
            if isShowingMistake {
                // The words in the primary colour, so they keep their contrast in both appearances; the icon
                // alone carries the warning colour. Orange footnote text was about 2.2:1 on the light panel.
                Label {
                    Text(MistakeToggle.note(chart: chart))
                        .foregroundStyle(.primary)
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
                .font(.footnote)
            }
        }
    }

    /// "This is the mistake, shown on purpose.", or with the chart named: "The lower chart is the mistake, shown on purpose."
    nonisolated static func note(chart: String?) -> String {
        guard let chart, !chart.isEmpty else { return "This is the mistake, shown on purpose." }
        return "The \(chart) chart is the mistake, shown on purpose."
    }
}

#Preview {
    @Previewable @State var isShowingMistake = true
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
        MistakeToggle(title: "Leave out the series", isShowingMistake: $isShowingMistake)
        MistakeToggle(title: "Start the axis at 140", isShowingMistake: $isShowingMistake, chart: "lower")
    }
    .padding()
}
