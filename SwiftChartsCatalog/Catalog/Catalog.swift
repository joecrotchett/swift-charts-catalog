import Foundation

/// Every category and screen of the catalog, in the order the app shows them.
///
/// Transcribed from the catalog tables in the skill repository's `DEMO-APP.md`. A screen is marked
/// built, and given its snippets, by its entry in `ScreenRegistry` when its epic lands.
enum Catalog {
    static let categories: [CatalogCategory] = [
        CatalogCategory(id: "start-here", title: "Start here", systemImage: "flag", screens: [
            screen("start-here/anatomy-of-a-chart", "Anatomy of a chart", "Marks, scales, axes and legend as the four building blocks; axes, legend and plot area as the three customisable parts; labelled on one chart", since: "16.0", ["composition.md"]),
            screen("start-here/one-data-set-three-charts", "One data set, three charts", "The same data as bars, switched by a picker with animation, and as a multi-series line: change the mark, keep the rest", since: "16.0", ["composition.md"]),
            screen("start-here/what-the-framework-handles", "What the framework handles", "One chart shown in Dark Mode, at a large text size, in another locale and described by VoiceOver, with no code changed", since: "16.0", ["composition.md"]),
            screen("start-here/your-first-chart", "Your first chart", "Data, Chart, one BarMark per element", since: "16.0", ["gallery/bar.md"]),
            screen("start-here/charts-in-other-locales", "Charts in other locales", "What a chart does by itself in another locale and layout direction: number and date formats on default axes, right-to-left layout; and what the app must supply: formatted values in place of finished strings, and the locale for an explicit axis format", since: "16.0", ["composition.md", "data.md"]),
            screen("start-here/what-you-get-for-free", "What you get for free", "The defaults: axis sides, grid lines, colour order, legend, category order", since: "16.0", ["gallery/README.md"]),
            screen("start-here/three-ways-to-create-a-chart", "Three ways to create a chart", "Chart(data), Chart(data, id:), Chart { }, and when each fits", since: "16.0", ["composition.md"]),
        ]),
        CatalogCategory(id: "marks", title: "Marks", systemImage: "chart.bar", screens: [
            screen("marks/how-positions-are-given", "How positions are given", "On each axis a mark takes a value, an interval or nothing; the same three choices explain every initializer of bar, rectangle, rule and point", since: "16.0", ["marks.md"]),
            screen("marks/area", "Area", "Area under a line; range area between two values", since: "16.0", ["gallery/area.md", "marks.md"]),
            screen("marks/line", "Line", "Single line; straight, smooth and stepped interpolation; line style; point symbols", since: "16.0", ["gallery/line-shapes.md", "gallery/multi-series-line.md", "mark-configuration.md"]),
            screen("marks/point", "Point", "Scatter plot with colour and symbol by group; points on one axis only", since: "16.0", ["gallery/scatter.md", "marks.md"]),
            screen("marks/vector-field", "Vector field", "A rotated view as the symbol of each point", since: "16.0", ["gallery/vector-field.md"]),
            screen("marks/rectangle", "Rectangle", "A shaded region behind points; a tick aligned to a bar's band", since: "16.0", ["marks.md", "gallery/scatter.md", "gallery/range-bar.md"]),
            screen("marks/calendar-heat-map", "Calendar heat map", "Dates on both axes: weeks as rows, weekdays as columns, tiles shaded by value", since: "16.0", ["gallery/calendar.md"]),
            screen("marks/heat-map", "Heat map", "Rectangles on two category axes coloured by a number; the two-dimensional histogram on number axes", since: "16.0", ["gallery/heat-map.md"]),
            screen("marks/rule", "Rule", "Threshold, average, selected position", since: "16.0", ["marks.md"]),
            screen("marks/bar", "Bar", "Vertical and horizontal bars; width: as ratio or fixed; one bar with no category", since: "16.0", ["gallery/bar.md", "gallery/stacked-bar.md", "marks.md"]),
            screen("marks/range-bar", "Range bar", "yStart / yEnd floating bars", since: "16.0", ["gallery/range-bar.md"]),
            screen("marks/diverging-bar", "Diverging bar", "Signed values growing left and right from zero, names as annotations, signed axis on top", since: "16.0", ["gallery/diverging-bar.md"]),
            screen("marks/difference-chart", "Difference chart", "Two area layers that each draw only where their series leads", since: "16.0", ["gallery/difference.md"]),
            screen("marks/beeswarm", "Beeswarm", "Points dodged into rows computed in the data", since: "16.0", ["gallery/scatter.md"]),
            screen("marks/candlestick", "Candlestick", "A custom mark type built from a rule and a rectangle, coloured by the caller", since: "16.0", ["gallery/candlestick.md"]),
            screen("marks/box-plot", "Box plot", "A rule, a bar and a rectangle at one position: range, middle half and median", since: "16.0", ["gallery/box-plot.md"]),
            screen("marks/population-pyramid", "Population pyramid", "Back-to-back bars from negated values with absolute axis labels", since: "16.0", ["gallery/population-pyramid.md"]),
            screen("marks/timeline", "Timeline", "Interval bars per row (a Gantt chart), and the thin-rule version", since: "16.0", ["gallery/timeline.md"]),
            screen("marks/sector", "Sector", "Pie to donut: inner radius, angular inset, corner radius", since: "17.0", ["gallery/donut.md", "marks.md"]),
            screen("marks/symbol-shapes", "Symbol shapes", "The eight built-in shapes, outlined versions, and a custom ChartSymbolShape with perceptualUnitRect (mark configuration)", since: "16.0", ["mark-configuration.md", "gallery/multi-series-line.md"]),
            screen("marks/mark-dimensions", "Mark dimensions", "MarkDimension: automatic, ratio, inset and fixed bar widths", since: "16.0", ["mark-configuration.md"]),
        ]),
        CatalogCategory(id: "mark-modifiers", title: "Mark modifiers", systemImage: "paintbrush", screens: [
            screen("mark-modifiers/styling-marks", "Styling marks", "Fixed colour, one highlighted element, opacity, corner radius, line style, shadow and blur", since: "16.0", ["mark-modifiers.md"]),
            screen("mark-modifiers/gradients-and-the-plot-area", "Gradients and the plot area", "alignsMarkStylesWithPlotArea: a gradient per bar or across the plot", since: "16.0", ["mark-modifiers.md"]),
            screen("mark-modifiers/positioning-marks", "Positioning marks", "offset and its start and end forms", since: "16.0", ["mark-modifiers.md"]),
            screen("mark-modifiers/symbols", "Symbols", "Built-in shapes, a view as a symbol, symbol size", since: "16.0", ["mark-modifiers.md"]),
            screen("mark-modifiers/encoding-data", "Encoding data", "The five by: modifiers: colour, position, symbol, symbol size, line style", since: "16.0", ["mark-modifiers.md"]),
            screen("mark-modifiers/layering", "Layering", "zIndex", since: "17.0", ["mark-modifiers.md"]),
            screen("mark-modifiers/masking-and-clipping", "Masking and clipping", "clipShape for pill bars; mask", since: "16.0", ["mark-modifiers.md"]),
        ]),
        CatalogCategory(id: "composition", title: "Composition", systemImage: "square.stack.3d.up", screens: [
            screen("composition/series", "Series", "What makes marks one line or several: series: or a by: encoding", since: "16.0", ["gallery/multi-series-line.md"]),
            screen("composition/layering-marks", "Layering marks", "A chart form built from three marks sharing one scale", since: "16.0", ["gallery/range-bar.md"]),
            screen("composition/stacking", "Stacking", "Marks sharing a position stack; colour only reveals the pieces; the four stacking methods", since: "16.0", ["gallery/area.md", "gallery/stacked-bar.md", "mark-configuration.md"]),
            screen("composition/grouping", "Grouping", "position(by:) puts bars side by side instead of stacking", since: "16.0", ["gallery/grouped-bar.md"]),
            screen("composition/reusable-chart-content", "Reusable chart content", "A custom ChartContent type and a @ChartContentBuilder property", since: "16.0", ["composition.md"]),
            screen("composition/grouping-with-plot", "Grouping with Plot", "One modifier or annotation applied to a group", since: "16.0", ["composition.md"]),
            screen("composition/control-flow-in-a-chart", "Control flow in a chart", "if, if let, ForEach inside chart content", since: "16.0", ["composition.md"]),
        ]),
        CatalogCategory(id: "data", title: "Data", systemImage: "tablecells", screens: [
            screen("data/value-types-shape-the-chart", "Value types shape the chart", "String, number and date on an axis give bands, a number scale, a date scale", since: "16.0", ["data.md"]),
            screen("data/ranges-as-values", "Ranges as values", "A range of dates as a bar's x value, for periods that are not calendar units", since: "16.0", ["data.md"]),
            screen("data/your-own-plottable-types", "Your own plottable types", "A String enum conforming to Plottable; a custom type with a primitive value", since: "16.0", ["data.md"]),
            screen("data/dates-and-units", "Dates and units", "unit: gives each bar its day or month", since: "16.0", ["data.md"]),
            screen("data/order-comes-from-the-data", "Order comes from the data", "Category, stack and legend order", since: "16.0", ["data.md", "gallery/stacked-bar.md"]),
            screen("data/binning", "Binning", "NumberBins and DateBins: a histogram, and weekly totals from daily data", since: "16.0", ["data.md", "gallery/histogram.md"]),
        ]),
        CatalogCategory(id: "scales", title: "Scales", systemImage: "ruler", screens: [
            screen("scales/colour-that-means-something", "Colour that means something", "foregroundStyle(by:) creates a colour scale; chartForegroundStyleScale sets it", since: "16.0", ["scales.md", "gallery/stacked-bar.md"]),
            screen("scales/colour-ramps", "Colour ramps", "A number encoded as colour: the gradient scale and its legend; a custom Gradient range", since: "16.0", ["scales.md", "gallery/heat-map.md"]),
            screen("scales/stable-colours", "Stable colours", "A fixed colour-scale domain: filter the data and watch colours hold, then remove the domain and watch them shift", since: "16.0", ["scales.md"]),
            screen("scales/symbol-and-size-scales", "Symbol and size scales", "chartSymbolScale and chartSymbolSizeScale(range:)", since: "16.0", ["scales.md", "mark-modifiers.md"]),
            screen("scales/scale-padding", "Scale padding", "plotDimension(padding:) and its start and end forms", since: "16.0", ["scales.md"]),
            screen("scales/domain", "Domain", "Automatic, exact, without zero, reversed, and adjusted in a closure; categories ordered by a domain array", since: "16.0", ["scales.md"]),
            screen("scales/scale-types", "Scale types", "Linear against log, square root and symmetric log on data spanning orders of magnitude", since: "16.0", ["scales.md"]),
        ]),
        CatalogCategory(id: "axes", title: "Axes", systemImage: "arrow.up.right", screens: [
            screen("axes/hiding-axes", "Hiding axes", ".hidden on each axis", since: "16.0", ["axes.md", "gallery/compact.md"]),
            screen("axes/composing-axis-marks", "Composing axis marks", "AxisMarks with grid line, tick and label as separate axis marks; two AxisMarks for labels at some values and grid lines at more", since: "16.0", ["axes.md", "gallery/custom-axes.md"]),
            screen("axes/choosing-axis-values", "Choosing axis values", ".automatic(desiredCount:), .stride(by:), an exact array; values that widen the scale", since: "16.0", ["axes.md"]),
            screen("axes/position-and-presets", "Position and presets", "Leading, trailing, top, bottom; aligned, extended, inset", since: "16.0", ["axes.md", "gallery/custom-axes.md"]),
            screen("axes/styling-axis-marks", "Styling axis marks", "Stroke, colour, tick length, label font and orientation", since: "16.0", ["axes.md"]),
            screen("axes/axis-titles", "Axis titles", "chartXAxisLabel and chartYAxisLabel with units; position and alignment", since: "16.0", ["axes.md"]),
            screen("axes/crowded-labels", "Crowded labels", "Truncation by default; greedy, disabled and vertical labels as alternatives", since: "16.0", ["axes.md"]),
            screen("axes/formatting-and-conditional-labels", "Formatting and conditional labels", "A format style on the axis; labels that differ by value through AxisValue; two-line labels; centred day labels", since: "16.0", ["axes.md", "gallery/custom-axes.md"]),
        ]),
        CatalogCategory(id: "legend", title: "Legend", systemImage: "list.bullet.rectangle", screens: [
            screen("legend/legend", "Legend", "Where it comes from, position, alignment, hidden", since: "16.0", ["legend.md"]),
            screen("legend/a-legend-of-your-own", "A legend of your own", "A custom layout drawn from the chart's own scale through ChartProxy", since: "16.4", ["legend.md"]),
        ]),
        CatalogCategory(id: "plot-area", title: "Plot area", systemImage: "rectangle.dashed", screens: [
            screen("plot-area/styling-the-plot-area", "Styling the plot area", "chartPlotStyle background and border", since: "16.0", ["plot-area.md", "gallery/bar.md"]),
            screen("plot-area/plot-aspect-ratio", "Plot aspect ratio", "A circle drawn in a free and in a square plot area", since: "16.0", ["plot-area.md", "gallery/function-plot.md"]),
            screen("plot-area/plot-height-from-content", "Plot height from content", "A fixed height per row, so the chart grows with its categories", since: "16.0", ["plot-area.md"]),
            screen("plot-area/a-view-in-the-plot-area", "A view in the plot area", "chartBackground with plotFrame: text in a donut's hole", since: "17.0", ["plot-area.md", "gallery/donut.md"]),
            screen("plot-area/chart-proxy", "Chart proxy", "Positions to values and back: a badge pinned to a category's band; the value under a pointer shown live", since: "16.0", ["plot-area.md"]),
            screen("plot-area/plot-frame-and-container-frame", "Plot frame and container frame", "In a scrolling chart, the whole plot against its visible part", since: "17.0", ["plot-area.md"]),
            screen("plot-area/clipping-the-plot-area", "Clipping the plot area", "Marks beyond a scale's domain are drawn outside the plot until it is clipped", since: "16.0", ["plot-area.md", "vectorized-plots.md"]),
        ]),
        CatalogCategory(id: "annotations", title: "Annotations", systemImage: "text.bubble", screens: [
            screen("annotations/labelling-a-mark", "Labelling a mark", "annotation: a value on each bar; the ten positions and the alignment along each", since: "16.0", ["annotations.md", "gallery/bar.md"]),
            screen("annotations/overflow", "Overflow", "The overflow strategies for a label at the chart's edge: disabled, fit to plot, fit to chart, pad scale", since: "17.0", ["annotations.md"]),
        ]),
        CatalogCategory(id: "interaction", title: "Interaction", systemImage: "hand.tap", screens: [
            screen("interaction/select-a-value", "Select a value", "chartXSelection(value:), snapping, rule and popover; the default gesture on each platform", since: "17.0", ["gallery/selection-line.md"]),
            screen("interaction/select-a-range", "Select a range", "chartXSelection(range:) with one annotation over two rules; the iOS 16 technique of a drag gesture and a rectangle mark beside it", since: "17.0", ["gallery/selection-line.md"]),
            screen("interaction/select-the-nearest-point", "Select the nearest point", "x and y selection together on a scatter plot; accept only a close point", since: "17.0", ["interaction.md", "gallery/scatter.md"]),
            screen("interaction/linked-charts", "Linked charts", "Two charts sharing one selection, with a band behind the selected day in both", since: "17.0", ["gallery/linked-charts.md"]),
            screen("interaction/select-a-sector", "Select a sector", "chartAngleSelection and the cumulative value", since: "17.0", ["gallery/donut.md"]),
            screen("interaction/scrolling", "Scrolling", "Visible domain, bound position, and where scrolling rests: value-aligned by date components or unit, major alignment, limit behaviour", since: "17.0", ["gallery/scrolling-bar.md", "interaction.md"]),
            screen("interaction/custom-gestures", "Custom gestures", "A tap gesture driving the chart's own selection through chartGesture; an overlay gesture reading values directly", since: "17.0", ["interaction.md"]),
        ]),
        CatalogCategory(id: "design", title: "Design", systemImage: "paintpalette", screens: [
            screen("design/table-or-chart", "Table or chart", "The same data as a list and as a chart; what each is for", since: "16.0", ["design.md"]),
            screen("design/start-from-the-goal", "Start from the goal", "One data set, the insights it could show, and how choosing three of them decides the chart", since: "17.0", ["design.md"]),
            screen("design/design-with-real-data", "Design with real data", "Points, a line and bars on smooth data and then on real data with zero days", since: "16.0", ["design.md"]),
            screen("design/marks-what-each-communicates", "Marks: what each communicates", "One data set as bars, a line and points, with what each makes easy to see; points added to a line", since: "16.0", ["design.md", "marks.md"]),
            screen("design/axes-fixed-or-dynamic-range", "Axes: fixed or dynamic range", "A percentage on a fixed 0 to 100 axis; a count on a dynamic axis across two periods", since: "16.0", ["design.md", "scales.md"]),
            screen("design/axes-the-lower-bound", "Axes: the lower bound", "Bars from zero; a line of values far from zero with and without the zero baseline", since: "16.0", ["design.md", "scales.md"]),
            screen("design/axes-density-and-weight", "Axes: density and weight", "Many heavy grid lines against three quiet ones; short value labels", since: "17.0", ["design.md", "gallery/custom-axes.md"]),
            screen("design/descriptions-say-the-message", "Descriptions: say the message", "Caption, headline figure, period and chart; the four levels of description from a bare title to an interpretation", since: "17.0", ["design.md"]),
            screen("design/interaction-explore-do-not-require", "Interaction: explore, do not require", "A chart that reads complete at rest and reveals detail on selection anywhere in the plot", since: "17.0", ["design.md", "gallery/selection-line.md"]),
            screen("design/title-gives-way-to-selection", "Title gives way to selection", "The selection label taking the title's place", since: "17.0", ["design.md"]),
            screen("design/one-focus-at-a-time", "One focus at a time", "Fading all but one element; muting marks under an overlay", since: "17.0", ["design.md", "gallery/range-bar.md"]),
            screen("design/colour-never-colour-alone", "Colour: never colour alone", "Two series by colour only, then by colour and shape; a greyscale switch to prove it", since: "16.0", ["design.md", "gallery/scatter.md"]),
            screen("design/colour-separation", "Colour: separation", "Stacked segments with and without gaps; a donut with and without angular inset", since: "17.0", ["design.md", "gallery/stacked-bar.md"]),
            screen("design/colour-weight-and-meaning", "Colour: weight and meaning", "Two category colours of unequal and then equal visual weight; names that are easy to tell apart", since: "16.0", ["design.md"]),
            screen("design/a-chart-design-system", "A chart design system", "Two charts that differ by period, then by kind of data, then by measure, with the design changing as much as the content", since: "16.0", ["design.md"]),
            screen("design/overview-and-detail", "Overview and detail", "A compact chart with a headline that opens a full chart of the same data in the same style", since: "17.0", ["design.md", "gallery/compact.md"]),
            screen("design/small-multiples", "Small multiples", "Three aligned charts on a shared scale, against one crowded chart", since: "16.0", ["gallery/small-multiples.md"]),
        ]),
        CatalogCategory(id: "availability", title: "Availability", systemImage: "calendar.badge.clock", screens: [
            screen("availability/what-each-release-added", "What each release added", "The release timeline, linking to the screens that need each OS", since: "16.0", ["availability/README.md"]),
            screen("availability/gating-with-a-fallback", "Gating with a fallback", "A 3D chart on iOS 26 and the 2D chart people on iOS 18 see instead; the same pattern explained for older targets", since: "26.0", ["availability/README.md", "chart3d.md"]),
        ]),
        CatalogCategory(id: "3d-charts", title: "3D charts", systemImage: "cube", screens: [
            screen("3d-charts/surface-plot", "Surface plot", "SurfacePlot of a function; height-based, normal-based and gradient styles", since: "26.0", ["chart3d.md"]),
            screen("3d-charts/from-2d-to-3d", "From 2D to 3D", "Three 2D scatter plots of the same data, then one 3D chart that holds all three; when 3D is worth it", since: "26.0", ["chart3d.md"]),
            screen("3d-charts/3d-scatter", "3D scatter", "PointMark(x:y:z:) with colour by category; symbol shapes and size, metalness, roughness", since: "26.0", ["chart3d.md"]),
            screen("3d-charts/a-surface-through-the-points", "A surface through the points", "A fitted plane drawn with the data it was fitted to", since: "26.0", ["chart3d.md"]),
            screen("3d-charts/pose-and-projection", "Pose and projection", "The initial pose and why it matters: one angle shows clusters, another a trend; orthographic against perspective", since: "26.0", ["chart3d.md"]),
            screen("3d-charts/scales-and-axes-in-3d", "Scales and axes in 3D", "Domain, range and axis marks on all three axes", since: "26.0", ["chart3d.md"]),
            screen("3d-charts/rules-and-rectangles-in-3d", "Rules and rectangles in 3D", "One range makes a rule, two make a rectangle: axis lines and a reference plane", since: "26.0", ["chart3d.md"]),
        ]),
        CatalogCategory(id: "vectorized-plots", title: "Vectorized plots", systemImage: "function", screens: [
            screen("vectorized-plots/marks-and-plots", "Marks and plots", "The same chart from a ForEach of marks and from one plot, and Apple's rule for choosing", since: "18.0", ["vectorized-plots.md"]),
            screen("vectorized-plots/key-paths", "Key paths", ".value(\"Label\", \\.property), intervals from two key paths, and the key-path modifiers", since: "18.0", ["vectorized-plots.md"]),
            screen("vectorized-plots/modifier-order", "Modifier order", "Key-path modifiers first, plain-value modifiers after, with the compiler error shown as text", since: "18.0", ["vectorized-plots.md"]),
            screen("vectorized-plots/function-plots", "Function plots", "A function as a line, the area between two functions, a parametric curve; a grid of examples in the manner of Apple's Function Catalog", since: "18.0", ["gallery/function-plot.md"]),
            screen("vectorized-plots/tracing-and-drawing-a-function", "Tracing and drawing a function", "Selection along a curve showing its coordinates; a curve drawn in by growing its domain", since: "18.0", ["gallery/function-plot.md"]),
            screen("vectorized-plots/curves-over-data", "Curves over data", "A histogram with a fitted curve; a trend line with an uncertainty band", since: "18.0", ["gallery/histogram.md", "gallery/scatter.md"]),
            screen("vectorized-plots/keeping-a-large-plot-fast", "Keeping a large plot fast", "Stored against computed properties, sorted against unsorted data, on several thousand points", since: "18.0", ["vectorized-plots.md"]),
            screen("vectorized-plots/undefined-values", "Undefined values", "Returning .nan, and clipping a curve that leaves the scale", since: "18.0", ["vectorized-plots.md"]),
            screen("vectorized-plots/trend-line", "Trend line", "A function plot over a point plot, limited to the data's range", since: "18.0", ["gallery/scatter.md", "vectorized-plots.md"]),
        ]),
        CatalogCategory(id: "limits-and-escape-hatches", title: "Limits and escape hatches", systemImage: "exclamationmark.triangle", screens: [
            screen("limits-and-escape-hatches/gauge", "Gauge", "A half ring from SectorMark angle ranges, a clear sector and a rotated chart", since: "17.0", ["gallery/gauge.md"]),
            screen("limits-and-escape-hatches/exporting-an-image", "Exporting an image", "ImageRenderer on a chart, and why scrolling and 3D charts need a static 2D twin", since: "17.0", ["limits-and-escapes.md"]),
        ]),
        CatalogCategory(id: "accessibility", title: "Accessibility", systemImage: "accessibility", screens: [
            screen("accessibility/what-you-get-for-free", "What you get for free", "The default elements, one per x position, and the default Audio Graph, with instructions for hearing them. The element text is shown on screen beside each chart: one mark, stacked, grouped, several series, a dense line and a month of days", since: "16.0", ["accessibility-defaults.md", "accessibility.md"]),
            screen("accessibility/labels-that-give-context", "Labels that give context", "The default description of a bar against a written label and value", since: "16.0", ["accessibility.md"]),
            screen("accessibility/one-element-or-many", "One element or many", "Per mark, per portion, or one for the whole chart, chosen by the chart's purpose", since: "16.0", ["accessibility.md"]),
            screen("accessibility/labels-that-are-not-read", "Labels that are not read", "A stacked bar with labels on its bare segments (ignored) against the same labels on a Plot around each (read)", since: "16.0", ["accessibility.md"]),
            screen("accessibility/a-simpler-chart-for-voiceover", "A simpler chart for VoiceOver", "accessibilityRepresentation swapping a stacked chart for one bar per category", since: "16.0", ["accessibility.md"]),
            screen("accessibility/audio-graph-title-and-summary", "Audio Graph title and summary", "The default Audio Graph data (titled \"Chart\", bare values, no dates) beside the same chart with a descriptor", since: "16.0", ["audio-graph.md", "accessibility.md", "accessibility-defaults.md"]),
            screen("accessibility/layers-counted-twice", "Layers counted twice", "A line over an area with both visible to assistive technologies, then with the area hidden", since: "16.0", ["accessibility.md"]),
            screen("accessibility/dynamic-type", "Dynamic Type", "Axis labels thinned and shortened as text grows, a legend that wraps, a chart that grows with its text, and horizontal bar names, with a text size control", since: "16.0", ["accessibility-beyond-voiceover.md"]),
        ]),
    ]

    private static func screen(
        _ id: String, _ title: String, _ summary: String, since: String, _ references: [String]
    ) -> CatalogScreen {
        CatalogScreen(
            id: id, title: title, summary: summary, apiSince: since, skillReferences: references,
            snippets: ScreenRegistry.entries[id]?.snippets ?? [], isBuilt: ScreenRegistry.entries[id] != nil
        )
    }

    static var allScreens: [CatalogScreen] {
        categories.flatMap(\.screens)
    }

    static func screen(id: String) -> CatalogScreen? {
        allScreens.first { $0.id == id }
    }
}
