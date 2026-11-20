import Accessibility
import Charts
import SwiftUI

/// "Gauge": a half ring from `SectorMark` angle ranges, a clear sector and a rotated chart.
struct HalfRingGaugeScreen: View {
    let screen: CatalogScreen
    @State private var model = HalfRingGaugeViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        let wording = model.wording(locale: locale)
        CatalogScreenScaffold(
            screen: screen,
            caption: HalfRingGaugeWording.caption,
            message: wording.headline,
            reservedMessage: HalfRingGaugeWording.reservedHeadline(locale: locale),
            explanation: """
            Swift Charts has no gauge mark and no start angle for sectors. Each SectorMark here takes a range \
            on one angle scale: the filled part from 0 to the progress, the track from there to 1, and a clear \
            sector from 1 to 2, so the gauge fills half the circle. A quarter turn back with rotationEffect \
            starts it at 9 o'clock. Turn on the clear sector to see the lower half it holds. For a plain progress \
            indicator, SwiftUI's Gauge is the system control; a chart suits only what Gauge cannot draw.
            """,
            snippets: HalfRingGaugeViewModel.snippets
        ) {
            HalfRingGaugeChart(
                angles: model.angles, showsClearSector: model.showsClearSector, wording: wording
            )
            .id(model.chartIdentity)
        } controls: {
            HalfRingGaugeControls(model: model, wording: wording)
        }
    }
}

/// The slider and the toggle.
struct HalfRingGaugeControls: View {
    @Bindable var model: HalfRingGaugeViewModel
    let wording: HalfRingGaugeWording

    var body: some View {
        ControlsSection {
            LabeledSlider(
                title: HalfRingGaugeWording.progressLabel, value: $model.progress, range: 0 ... 1, step: 0.01,
                valueText: wording.percentText, spokenValue: wording.sliderSpokenValue
            )
            Toggle("Show the clear sector", isOn: $model.showsClearSector)
        }
    }
}

/// Constants that belong to this chart's marks.
private enum HalfRingGaugeStyle {
    static let innerRadius = 0.7
    static let angularInset: CGFloat = 1
    static let cornerRadius: CGFloat = 2
    static let trackOpacity = 0.3
    static let clearSectorTint = 0.25
}

/// The half ring, with the figure written in the empty lower half of its square, outside the chart.
struct HalfRingGaugeChart: View {
    let angles: HalfRingGaugeAngles
    let showsClearSector: Bool
    let wording: HalfRingGaugeWording

    var body: some View {
        // snippet:gauge-half-ring
        Chart {
            // The filled part and the track are one gauge, so one element: it exists at 0% too.
            Plot {
                if let filled = angles.filled {
                    SectorMark(
                        angle: .value(HalfRingGaugeWording.progressLabel, filled),
                        innerRadius: .ratio(HalfRingGaugeStyle.innerRadius),
                        angularInset: HalfRingGaugeStyle.angularInset
                    )
                    .foregroundStyle(Color.blue)
                }
                if let track = angles.track {
                    SectorMark(
                        angle: .value(HalfRingGaugeWording.remainingLabel, track),
                        innerRadius: .ratio(HalfRingGaugeStyle.innerRadius),
                        angularInset: HalfRingGaugeStyle.angularInset
                    )
                    .foregroundStyle(Color.gray.opacity(HalfRingGaugeStyle.trackOpacity))
                }
            }
            .cornerRadius(HalfRingGaugeStyle.cornerRadius)
            .accessibilityLabel(HalfRingGaugeWording.elementLabel)
            .accessibilityValue(wording.elementValue)

            // Takes the other half of the circle (1 to 2, the largest value in the chart) and draws nothing.
            Plot {
                SectorMark(angle: .value(HalfRingGaugeWording.unusedLabel, angles.clear))
                    .foregroundStyle(showsClearSector ? Color.orange.opacity(HalfRingGaugeStyle.clearSectorTint) : .clear)
            }
            .accessibilityLabel(HalfRingGaugeWording.clearSectorLabel)
            .accessibilityValue(HalfRingGaugeWording.clearSectorValue)
            .accessibilityHidden(!showsClearSector)
        }
        // Sectors start at 12 o'clock; a quarter turn back starts the half ring at 9 o'clock.
        .rotationEffect(.degrees(HalfRingGaugeAngles.rotationDegrees))
        .accessibilityChartDescriptor(HalfRingGaugeChartDescriptor(wording: wording))
        // end
        .overlay {
            HalfRingGaugeFigure(wording: wording)
        }
    }
}

/// The percentage, in the lower half of the chart's square, which the half ring leaves empty. Outside the
/// chart, so the rotation does not turn it. Hidden from VoiceOver: the gauge's element says the same.
struct HalfRingGaugeFigure: View {
    let wording: HalfRingGaugeWording

    var body: some View {
        VStack(spacing: 0) {
            Color.clear
            VStack(spacing: Layout.tightSpacing) {
                Text(wording.percentText)
                    .font(.largeTitle.bold())
                    .monospacedDigit()
                Text("of today's goal")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .padding(.top, Layout.itemSpacing)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .accessibilityHidden(true)
    }
}

// snippet:gauge-descriptor
/// A gauge has no automatic Audio Graph: one category with one point, from 0 to 100 percent.
nonisolated struct HalfRingGaugeChartDescriptor: AXChartDescriptorRepresentable {
    let wording: HalfRingGaugeWording

    func makeChartDescriptor() -> AXChartDescriptor {
        let locale = wording.locale
        let title = HalfRingGaugeWording.descriptorTitle
        return AXChartDescriptor(
            title: title,
            summary: wording.audioGraphSummary,
            xAxis: AXCategoricalDataAxisDescriptor(title: "Measure", categoryOrder: [title]),
            yAxis: AXNumericDataAxisDescriptor(title: "Percent", range: 0 ... 100, gridlinePositions: []) {
                HalfRingGaugeWording.spokenPercent($0, locale: locale)
            },
            additionalAxes: [],
            series: [AXDataSeriesDescriptor(
                name: title, isContinuous: false, dataPoints: [AXDataPoint(x: title, y: Double(wording.percent))]
            )]
        )
    }
}

// end

#Preview("Gauge") {
    NavigationStack {
        if let screen = Catalog.screen(id: "limits-and-escape-hatches/gauge") {
            HalfRingGaugeScreen(screen: screen)
        }
    }
}

#Preview("Clear sector shown, 0%") {
    HalfRingGaugeChart(
        angles: HalfRingGaugeAngles(progress: 0), showsClearSector: true,
        wording: HalfRingGaugeWording(percent: 0, locale: .current)
    )
    .frame(height: Layout.chartHeightCompact)
    .padding()
}
