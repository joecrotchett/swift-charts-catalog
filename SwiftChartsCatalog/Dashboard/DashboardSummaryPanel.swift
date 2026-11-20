import SwiftUI

/// The summary card: a caption, the selection's cups as a large figure, the period it covers, its change on
/// the same weekday a week earlier, and the busiest café and drink. With nothing selected it covers the four weeks.
struct DashboardSummaryPanel: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.locale) private var locale

    var body: some View {
        let summary = model.summary(locale: locale)
        DashboardPanel(title: "Summary", subtitle: summary.period) {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text(summary.caption.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(summary.totalText)
                    .font(.title.bold())
                Text(summary.change)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            DashboardSummaryRow(title: "Busiest \(CafeWording.store.lowercased())", value: summary.busiestCafe)
            // Always shown, so the card keeps its height and the charts below do not move when a drink is selected.
            DashboardSummaryRow(title: "Busiest \(CafeWording.drink.lowercased())", value: summary.busiestDrink)
        }
    }
}

/// One labelled figure of the summary card.
private struct DashboardSummaryRow: View {
    let title: String
    let value: String

    var body: some View {
        LabeledContent(title, value: value)
            .font(.subheadline)
    }
}

#Preview {
    ScrollView {
        DashboardSummaryPanel()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environment(DashboardModel())
}
