import Charts
import SwiftUI

/// The constants the dashboard's own views use, beside the kit's `Layout`.
enum DashboardLayout {
    /// The narrowest a column may be: two columns need twice this, so an iPad gets two and an iPhone one.
    static let minimumColumnWidth: CGFloat = 380
    /// The plot's height before Dynamic Type scales it.
    static let chartHeight: CGFloat = 240
    /// The heat map has only two or three rows, so it is shorter.
    static let heatMapHeight: CGFloat = 170
    /// Room above the top value label, scaled with the text and capped.
    static let valueAxisEndPadding: CGFloat = 8
    static let valueAxisEndPaddingCap: CGFloat = 28
    /// Point symbols on the per-day lines, in square points.
    static let lineSymbolSize: CGFloat = 18
    /// Opacity of a series or bar that is not the selected one.
    static let fadedOpacity: Double = 0.3
    /// The band behind the selected day on the per-day chart.
    static let selectedDayBandOpacity: Double = 0.25
    /// Heat-map cells leave a thin gap, through which the band behind the selected weekday shows as an outline.
    static let heatCellRatio: CGFloat = 0.86
    /// The heat map's own key: a gradient strip between the domain's two ends.
    static let heatLegendWidth: CGFloat = 120
    static let heatLegendHeight: CGFloat = 8
    static let heatLegendCornerRadius: CGFloat = 2
    /// Grid lines on the interactive charts, light so the marks lead.
    static let gridLineOpacity: Double = 0.2
}

/// One colour and one symbol per series for every panel: cafés from `CafeSeriesStyle`, drinks from
/// `CafeDrinkStyle`. The drinks have no shared symbol, so the dashboard adds one here, chosen not to repeat
/// a café's circle or square.
nonisolated enum DashboardSeriesStyle {
    static func colour(for series: String) -> Color {
        CafeSeriesStyle.stores.contains(series) ? CafeSeriesStyle.colour(for: series) : CafeDrinkStyle.colour(for: series)
    }

    static func symbol(for series: String) -> AnyChartSymbolShape {
        if CafeSeriesStyle.stores.contains(series) { return CafeSeriesStyle.symbol(for: series) }
        switch series {
        case CafeDrinkStyle.drinks.first: return AnyChartSymbolShape(.triangle)
        case CafeDrinkStyle.drinks.dropFirst().first: return AnyChartSymbolShape(.diamond)
        default: return AnyChartSymbolShape(.pentagon)
        }
    }

    /// The heat map's ramp: a different kind of measure (an average), so a neutral grey that is none of the
    /// series' colours. Light grey to near-black in Light Mode, dark grey to white in Dark Mode. It starts at
    /// `systemGray3`, not `systemGray6`, which is almost the card in Light Mode and is the card in Dark Mode,
    /// so the lowest cells would vanish into the panel.
    static let heatGradient = Gradient(colors: [Color(.systemGray3), Color(.label)])

    /// The outline of the selected weekday and the selected drink's row: the app's tint, the system's colour
    /// for a selection, which the grey ramp never reaches.
    static let selectionOutline = Color.accentColor
}

/// The one panel style of the dashboard: a title, a line saying what is measured, and the content.
struct DashboardPanel<Content: View>: View {
    let title: String
    let subtitle: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.itemSpacing) {
            VStack(alignment: .leading, spacing: Layout.tightSpacing) {
                Text(title)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Layout.panelPadding)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: Layout.panelCornerRadius))
    }
}

/// The band behind the selected day, written once for every chart that shows days.
struct DashboardSelectedDayBand: ChartContent {
    let day: Date
    let calendar: Calendar

    var body: some ChartContent {
        RectangleMark(
            x: .value(CafeWording.day, day, unit: .day, calendar: calendar),
            width: .ratio(1)
        )
        .foregroundStyle(Color.gray.opacity(DashboardLayout.selectedDayBandOpacity))
        // It only marks the selection; the day's own element already describes it.
        .accessibilityHidden(true)
    }
}

/// Says aloud that the dashboard changed, for people who cannot see it happen.
@MainActor
func dashboardAnnounce(_ message: String) {
    AccessibilityNotification.Announcement(message).post()
}

#Preview {
    DashboardPanel(title: "Cups per day", subtitle: "By café") {
        Color.blue.opacity(0.2)
            .frame(height: DashboardLayout.chartHeight)
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
