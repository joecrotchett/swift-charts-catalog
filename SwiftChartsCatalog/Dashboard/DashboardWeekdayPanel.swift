import Charts
import SwiftUI

/// A heat map of average cups by weekday and café (or drink). Its colour domain spans the averages it shows,
/// and the subtitle says the range. The selected day's weekday is outlined, and with drinks as rows the selected
/// drink's row: a band behind the column or row shows through the gaps between cells, so no shade changes.
struct DashboardWeekdayPanel: View {
    @Environment(DashboardModel.self) private var model
    @Environment(\.locale) private var locale

    var body: some View {
        DashboardPanel(title: "Weekday rhythm", subtitle: model.weekdaySubtitle(locale: locale)) {
            if model.isEmpty {
                ContentUnavailableView("No sales", systemImage: "cup.and.saucer", description: Text("Average cups by weekday appear here."))
            } else {
                let cells = model.heatCells
                DashboardWeekdayChart(
                    cells: cells,
                    seriesLabel: model.breakdown.seriesLabel,
                    selectedWeekday: model.selectedWeekday,
                    rows: model.seriesNames,
                    selectedRow: model.selectedHeatRow,
                    colourDomain: model.heatDomain,
                    labels: cells.map { (model.heatCellLabel($0, locale: locale), model.heatCellValue($0, locale: locale)) },
                    descriptor: model.weekdayDescriptor(locale: locale),
                    narrowNames: Dictionary(uniqueKeysWithValues: CafeData.weekdays.map { ($0, model.narrowWeekdayName($0, locale: locale)) })
                )
                .id(model.weekdayIdentity)
            }
        }
    }
}

private struct DashboardWeekdayChart: View {
    let cells: [DashboardHeatCell]
    let seriesLabel: String
    let selectedWeekday: String?
    /// The row names in the shared order.
    let rows: [String]
    let selectedRow: String?
    let colourDomain: ClosedRange<Double>
    let labels: [(label: String, value: String)]
    let descriptor: DashboardWeekdayDescriptor
    /// "M" for "Mon", and so on.
    let narrowNames: [String: String]

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var chartHeight = DashboardLayout.heatMapHeight

    /// The words of the colour encoding: also the gradient legend's meaning.
    private static let averageLabel = "Average \(CafeWording.cups.lowercased())"

    var body: some View {
        Chart {
            if let selectedWeekday {
                // Behind the cells, the full height of the plot: it shows only in the gaps around the column.
                RectangleMark(x: .value(CafeWording.weekday, selectedWeekday), width: .ratio(1))
                    .foregroundStyle(DashboardSeriesStyle.selectionOutline)
                    .accessibilityHidden(true)
            }
            if let selectedRow {
                // The same band across the plot behind the selected drink's row.
                RectangleMark(y: .value(seriesLabel, selectedRow), height: .ratio(1))
                    .foregroundStyle(DashboardSeriesStyle.selectionOutline)
                    .accessibilityHidden(true)
            }
            ForEach(Array(zip(cells, labels)), id: \.0.id) { cell, text in
                Plot {
                    RectangleMark(
                        x: .value(CafeWording.weekday, cell.weekday),
                        y: .value(seriesLabel, cell.series),
                        width: .ratio(DashboardLayout.heatCellRatio),
                        height: .ratio(DashboardLayout.heatCellRatio)
                    )
                    .foregroundStyle(by: .value(Self.averageLabel, cell.averageCups))
                }
                .accessibilityLabel(text.label)
                .accessibilityValue(text.value)
            }
        }
        .chartXScale(domain: CafeData.weekdays)
        // The rows in the shared order: without it, the band behind the selected drink's row, declared first,
        // put that drink at the top (rendered: Mocha above Latte and Tea).
        .chartYScale(domain: rows)
        .chartXAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel {
                    if let weekday = value.as(String.self) {
                        // At the accessibility sizes "Wed" no longer fits a seventh of a phone beside the row
                        // names, and is cut to an ellipsis: the narrow name does.
                        Text(dynamicTypeSize.isAccessibilitySize ? narrowNames[weekday, default: weekday] : weekday)
                    }
                }
            }
        }
        // The averages shown, rounded out, so the shades spread across the whole ramp (`heatDomain`).
        .chartForegroundStyleScale(domain: colourDomain, range: DashboardSeriesStyle.heatGradient)
        // The automatic gradient legend rounded its labels out past this domain (150 to 300 for 160 to 260,
        // 0 to 300 for 70 to 210; rendered), drawing the end colours flat beyond it, so it read as if black
        // meant 300. This one runs from end to end of the domain.
        .chartLegend(position: .bottom, alignment: .leading) {
            DashboardHeatLegend(domain: colourDomain)
        }
        // Row names outside the plot, so the cells get the whole row.
        .chartYAxis {
            AxisMarks(preset: .aligned, position: .leading)
        }
        .accessibilityChartDescriptor(descriptor)
        .accessibilityIdentifier("dashboard-weekday-rhythm")
        .frame(height: chartHeight)
    }
}

/// The heat map's key: the ramp between the two ends of its colour domain.
private struct DashboardHeatLegend: View {
    let domain: ClosedRange<Double>
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .caption2) private var stripWidth = DashboardLayout.heatLegendWidth
    @ScaledMetric(relativeTo: .caption2) private var stripHeight = DashboardLayout.heatLegendHeight

    var body: some View {
        HStack(spacing: Layout.tightSpacing) {
            Text(Int(domain.lowerBound).formatted(.number.locale(locale)))
            LinearGradient(gradient: DashboardSeriesStyle.heatGradient, startPoint: .leading, endPoint: .trailing)
                .frame(width: stripWidth, height: stripHeight)
                .clipShape(.rect(cornerRadius: DashboardLayout.heatLegendCornerRadius))
            Text(Int(domain.upperBound).formatted(.number.locale(locale)))
        }
        .font(.caption2)
        .foregroundStyle(Color.secondary)
        // The subtitle already says "Shades from 160 to 260 cups"; read twice it adds nothing.
        .accessibilityHidden(true)
    }
}

#Preview {
    ScrollView {
        DashboardWeekdayPanel()
            .padding()
    }
    .background(Color(.systemGroupedBackground))
    .environment(DashboardModel())
}
