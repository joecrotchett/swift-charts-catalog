import Accessibility
import Charts
import SwiftUI

/// "Rules and rectangles in 3D": the same three positions make a point, a rule or a rectangle, depending on
/// how many of them are ranges.
struct Guides3DScreen: View {
    let screen: CatalogScreen
    @State private var viewModel = Guides3DViewModel()
    @Environment(\.locale) private var locale

    var body: some View {
        CatalogScreenScaffold(
            screen: screen,
            caption: "Bean tasting scores, with a reference mark",
            message: viewModel.headline(locale: locale),
            explanation: viewModel.explanation,
            snippets: Guides3DSnippets.references(for: viewModel.markKind)
        ) {
            Guides3DChartGate(viewModel: viewModel, locale: locale)
        } controls: {
            Guides3DControls(viewModel: viewModel, locale: locale)
        }
    }
}

/// The 3D chart where the system has it, and a plain explanation where it does not.
struct Guides3DChartGate: View {
    let viewModel: Guides3DViewModel
    let locale: Locale

    var body: some View {
        // snippet:rules-and-rectangles-in-3d-gate
        if #available(iOS 26, *) {
            Guides3DChart(viewModel: viewModel, locale: locale)
        } else {
            ContentUnavailableView(
                "3D charts need iOS 26",
                systemImage: "cube.transparent",
                description: Text("This system has no Chart3D, so the \(viewModel.markKind.name) is not drawn.")
            )
        }
        // end
    }
}

/// The context points and the one guide mark, with the elements and Audio Graph a `Chart3D` does not give.
@available(iOS 26, *)
struct Guides3DChart: View {
    let viewModel: Guides3DViewModel
    let locale: Locale
    @Environment(\.colorScheme) private var colorScheme

    /// The pose as the chart takes it, read from the view model's plain angles; a drag is written back, so
    /// the angle survives the chart's new identity when the ranges change, and the picker sets it.
    private var pose: Binding<Chart3DPose> {
        Binding(
            get: {
                Chart3DPose(azimuth: .degrees(viewModel.azimuthDegrees), inclination: .degrees(viewModel.inclinationDegrees))
            },
            set: { newPose in
                viewModel.turn(azimuth: newPose.azimuth.degrees, inclination: newPose.inclination.degrees)
            }
        )
    }

    var body: some View {
        Chart3D {
            ForEach(viewModel.beans) { bean in
                PointMark(
                    x: .value(Guides3DAxis.acidity.title, bean.acidity),
                    y: .value(Guides3DAxis.body.title, bean.body),
                    z: .value(Guides3DAxis.sweetness.title, bean.sweetness)
                )
                .symbol(.sphere)
                .symbolSize(Guides3DMarkStyle.contextSize)
                .foregroundStyle(Guides3DMarkStyle.context)
            }
            Guides3DGuideMark(ranges: viewModel.ranges)
        }
        .chart3DPose(pose)
        .chartXAxisLabel(Guides3DAxis.acidity.title)
        .chartYAxisLabel(Guides3DAxis.body.title)
        .chartZAxisLabel(Guides3DAxis.sweetness.title)
        .chartXScale(domain: Guides3DScale.domain, range: -0.5 ... 0.5)
        .chartYScale(domain: Guides3DScale.domain, range: -0.5 ... 0.5)
        .chartZScale(domain: Guides3DScale.domain, range: -0.5 ... 0.5)
        .chartXAxis { Self.axisMarks() }
        .chartYAxis { Self.axisMarks() }
        .chartZAxis { Self.axisMarks() }
        // snippet:rules-and-rectangles-in-3d-accessibility
        // A Chart3D gives assistive technologies nothing: an undrawn 2D chart stands in for it,
        // one element for the samples and one for the guide, with the Audio Graph inside it.
        .accessibilityRepresentation {
            Chart {
                Plot {
                    ForEach(viewModel.beans) { bean in
                        PointMark(
                            x: .value(Guides3DAxis.acidity.title, bean.acidity),
                            y: .value(Guides3DAxis.body.title, bean.body)
                        )
                    }
                }
                .accessibilityLabel(Guides3DWording.samplesTitle)
                .accessibilityValue(viewModel.samplesValue(locale: locale))
                Plot {
                    PointMark(
                        x: .value(Guides3DAxis.acidity.title, Guides3DScale.reference),
                        y: .value(Guides3DAxis.body.title, Guides3DScale.reference)
                    )
                }
                .accessibilityLabel(viewModel.guideLabel)
                .accessibilityValue(viewModel.guideValue(locale: locale))
            }
            .chartXScale(domain: Guides3DScale.domain)
            .chartYScale(domain: Guides3DScale.domain)
            .accessibilityChartDescriptor(Guides3DChartDescriptor(
                beans: viewModel.beans,
                title: viewModel.audioGraphTitle,
                summary: viewModel.audioGraphSummary(locale: locale),
                locale: locale
            ))
        }
        // A new identity whenever the ranges change, or VoiceOver and the Audio Graph keep the old words.
        .id(viewModel.chartIdentity)
        // end
        // The axis value labels keep the colour of the appearance the chart was first drawn in when Light
        // and Dark switch live, while the titles follow (read on iOS 27): a new identity redraws them. The pose is
        // the view model's, so it survives.
        .id(colorScheme)
        .accessibilityIdentifier("press-target")
    }

    /// The marks on each axis: labels inside the domain, the reference among them. `AxisContent` cannot be
    /// adopted by a type of one's own (it has no `body`), so the marks come from a function.
    static func axisMarks() -> some AxisContent {
        AxisMarks(values: Guides3DScale.labelledValues) {
            AxisTick()
            AxisGridLine()
            AxisValueLabel()
        }
    }
}

/// The guide: the same three positions, each a single value at the reference or a range across the scale.
/// How many are ranges decides the mark.
@available(iOS 26, *)
struct Guides3DGuideMark: Chart3DContent {
    let ranges: Set<Guides3DAxis>

    var body: some Chart3DContent {
        // snippet:rules-and-rectangles-in-3d-position
        // A range on an axis stretches the mark across it; a single value pins it there.
        let x = position(on: .acidity)
        let y = position(on: .body)
        let z = position(on: .sweetness)
        // end
        switch ranges.count {
        // snippet:rules-and-rectangles-in-3d-point
        case 0:
            // No range: three single values make a point.
            PointMark(x: x, y: y, z: z)
                .symbol(.sphere)
                .symbolSize(Guides3DMarkStyle.guidePointSize)
                .foregroundStyle(Guides3DMarkStyle.guide)
        // end
        // snippet:rules-and-rectangles-in-3d-rule
        case 1:
            // One range, two single values: a rule along the axis given the range.
            RuleMark(x: x, y: y, z: z)
                .foregroundStyle(Guides3DMarkStyle.guide)
        // end
        // snippet:rules-and-rectangles-in-3d-rectangle
        default:
            // Two ranges, one single value: a flat rectangle across the two axes given ranges.
            RectangleMark(x: x, y: y, z: z)
                .foregroundStyle(Guides3DMarkStyle.guide.opacity(Guides3DMarkStyle.planeOpacity))
            // end
        }
    }

    // snippet:rules-and-rectangles-in-3d-position-helper
    /// A range across the whole scale, or a single value at its middle. Both are a `PlottableValue<Double>`,
    /// so one mark initializer takes either in each place.
    private func position(on axis: Guides3DAxis) -> PlottableValue<Double> {
        ranges.contains(axis)
            ? .value(axis.title, Guides3DScale.lower ..< Guides3DScale.upper)
            : .value(axis.title, Guides3DScale.reference)
    }
    // end
}

/// Colours and sizes of this chart's marks.
private enum Guides3DMarkStyle {
    /// The samples are context, so they are grey; the guide is the one emphasised mark.
    static let context = Color.gray
    static let guide = Color.red
    /// A level (acidity–sweetness) plane at 0.6 washed nearly to white on the light panel at the default pose,
    /// while an upright one still read (rendered on iOS 27); at 0.85 both read, in light and dark.
    static let planeOpacity = 0.85
    /// Sizes as a fraction of the box's edge; for a sphere the value is its radius.
    static let contextSize: CGFloat = 0.015
    static let guidePointSize: CGFloat = 0.04
}

/// The switches for each axis's range, and the angle picker that stands in for a drag.
struct Guides3DControls: View {
    let viewModel: Guides3DViewModel
    let locale: Locale

    var body: some View {
        ControlsSection {
            ForEach(Guides3DAxis.allCases, id: \.self) { axis in
                Toggle("Range on \(axis.lowercasedTitle) (\(axis.letter))", isOn: Binding(
                    get: { viewModel.hasRange(axis) },
                    set: { isOn in
                        if let message = viewModel.setRange(axis, isOn, locale: locale) {
                            AccessibilityNotification.Announcement(message).post()
                        }
                    }
                ))
                .disabled(!viewModel.canToggle(axis))
            }
            Text(viewModel.ranges.count == Guides3DViewModel.maximumRanges
                ? "A 3D mark takes at most two ranges: turn one off to choose another."
                : "Each range turns the mark into the next: point, rule, rectangle.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Guides3DAnglePicker(viewModel: viewModel, locale: locale)
        }
    }
}

/// The angle presets, so the chart can be turned without a drag. None is selected once a drag has turned it.
struct Guides3DAnglePicker: View {
    let viewModel: Guides3DViewModel
    let locale: Locale

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.tightSpacing) {
            LabeledSegmentedPicker(title: "View from", selection: Binding(
                get: { viewModel.viewAngle },
                set: { angle in
                    if let message = viewModel.setViewAngle(angle, locale: locale) {
                        AccessibilityNotification.Announcement(message).post()
                    }
                }
            )) {
                ForEach(Guides3DViewAngle.allCases, id: \.self) { angle in
                    Text(angle.title).tag(Optional(angle))
                }
            }
            Text("Looking along a rule, or along the edge of a rectangle, you see nothing of it.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

/// The snippets for the mark the current ranges make.
enum Guides3DSnippets {
    static func references(for kind: Guides3DMarkKind) -> [SnippetReference] {
        let mark = switch kind {
        case .point: SnippetReference(name: "rules-and-rectangles-in-3d-point", title: "No range: a point")
        case .rule: SnippetReference(name: "rules-and-rectangles-in-3d-rule", title: "One range: a rule")
        case .rectangle: SnippetReference(name: "rules-and-rectangles-in-3d-rectangle", title: "Two ranges: a rectangle")
        }
        // The chart's own code first, so the Code view opens on the mark; the availability check after it.
        return [
            mark,
            SnippetReference(name: "rules-and-rectangles-in-3d-position", title: "The three positions"),
            SnippetReference(name: "rules-and-rectangles-in-3d-position-helper", title: "A range or a single value"),
            SnippetReference(name: "rules-and-rectangles-in-3d-gate", title: "Gate the 3D chart"),
            SnippetReference(name: "rules-and-rectangles-in-3d-accessibility", title: "Elements and Audio Graph"),
        ]
    }
}

#Preview {
    NavigationStack {
        if let screen = Catalog.screen(id: "3d-charts/rules-and-rectangles-in-3d") {
            Guides3DScreen(screen: screen)
        }
    }
}
