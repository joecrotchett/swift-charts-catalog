import Charts
import Observation
import SwiftUI

/// Where the x axis title goes: the framework's choice, or an edge named on purpose.
enum AxisTitlesXPosition: String, CaseIterable, Identifiable {
    case automatic = "Default"
    case bottom = "Bottom"
    case top = "Top"

    var id: Self {
        self
    }

    // snippet:axis-titles-positions
    /// The `position:` a title is given. `.automatic` is what the title gets when none is named.
    var annotationPosition: AnnotationPosition {
        switch self {
        case .automatic: .automatic
        case .bottom: .bottom
        case .top: .top
        }
    }
    // end
}

/// Where the y axis title goes.
enum AxisTitlesYPosition: String, CaseIterable, Identifiable {
    case automatic = "Default"
    case top = "Top"
    case leading = "Leading"
    case trailing = "Trailing"

    var id: Self {
        self
    }

    var annotationPosition: AnnotationPosition {
        switch self {
        case .automatic: .automatic
        case .top: .top
        case .leading: .leading
        case .trailing: .trailing
        }
    }
}

/// How both titles line up along the side they sit on.
enum AxisTitlesAlignment: String, CaseIterable, Identifiable {
    case automatic = "Default"
    case leading = "Leading"
    case center = "Centre"
    case trailing = "Trailing"

    var id: Self {
        self
    }

    // snippet:axis-titles-alignments
    /// The `alignment:` a title is given. `nil` leaves it where the position puts it by default.
    var alignment: Alignment? {
        switch self {
        case .automatic: nil
        case .leading: .leading
        case .center: .center
        case .trailing: .trailing
        }
    }
    // end
}

/// The words on the two titles: the catalog's short ones, or long ones that test how a title wraps.
enum AxisTitlesWording: String, CaseIterable, Identifiable {
    case short = "Short"
    case long = "Long"

    var id: Self {
        self
    }

    /// The x title. The queue's unit is people, so the title is the unit.
    var xTitle: String {
        switch self {
        case .short: CafeWording.queueAxisTitle
        case .long: AxisTitlesWords.longQueueTitle
        }
    }

    /// The y title, with its unit in brackets.
    var yTitle: String {
        switch self {
        case .short: CafeWording.waitAxisTitle
        case .long: AxisTitlesWords.longWaitTitle
        }
    }
}

/// The text size the chart alone is drawn at, to see what the titles do at the largest sizes.
enum AxisTitlesTextSize: String, CaseIterable, Identifiable {
    case device = "As the device"
    case xxxLarge = "Largest standard"
    case accessibility3 = "Accessibility 3"
    case accessibility5 = "Largest accessibility"

    var id: Self {
        self
    }

    /// `nil` follows the device.
    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .device: nil
        case .xxxLarge: .xxxLarge
        case .accessibility3: .accessibility3
        case .accessibility5: .accessibility5
        }
    }
}

/// The y axis at large text sizes. Seen in window renders on an iPhone 17: from Accessibility 3 the default
/// y title, above the plot, sits on the top value label, "400", drawn at the top of the plot.
nonisolated enum AxisTitlesYValues {
    /// From this size the y axis is given its values.
    static let firstSize = DynamicTypeSize.accessibility1
    static let step = 100

    /// The top of the y scale: the longest wait rounded up to the next hundred, as the framework rounds it
    /// (400 for a longest wait of 309). Pinned, because values that stop short of it would otherwise shrink
    /// the scale to the data and bring the top label back up under the title.
    static func top(maxWait: Int) -> Int {
        max(1, (max(maxWait, 0) + step - 1) / step) * step
    }

    /// Every hundred seconds below the top of the scale, so no label is drawn at the top, where the title
    /// is; `nil` below `firstSize`, where the framework chooses.
    static func values(maxWait: Int, at size: DynamicTypeSize) -> [Int]? {
        guard size >= firstSize else { return nil }
        return Array(stride(from: 0, to: top(maxWait: maxWait), by: step))
    }
}

/// Words this screen needs that `CafeWording` does not have: two long titles, to see how a title
/// that does not fit is drawn.
nonisolated enum AxisTitlesWords {
    static let longQueueTitle = "People queuing when the order was placed"
    static let longWaitTitle = "Wait from order to cup in hand (seconds)"
    /// The two cafés, for the colour and symbol scales' domains.
    static let cafes = [CafeWording.harbour, CafeWording.station]
}

/// The screen's state: where each title sits, how they align, their wording and the chart's text size.
@Observable
final class AxisTitlesViewModel {
    var xPosition = AxisTitlesXPosition.automatic
    var yPosition = AxisTitlesYPosition.automatic
    var alignment = AxisTitlesAlignment.automatic
    var wording = AxisTitlesWording.short
    var textSize = AxisTitlesTextSize.device

    /// The text size the chart is drawn at: the one chosen, or the device's.
    func effectiveTextSize(device: DynamicTypeSize) -> DynamicTypeSize {
        textSize.dynamicTypeSize ?? device
    }

    /// The largest text size the long titles are drawn at. An axis title is laid out on one line at its
    /// full length, whatever view it is given: on an iPhone SE the long titles run past the chart's edges
    /// from XX Large, and on an iPhone 17 from the accessibility sizes.
    static let largestSizeForLongTitles = DynamicTypeSize.xLarge

    /// The wording drawn at a text size: the short titles above `largestSizeForLongTitles`.
    func drawnWording(at size: DynamicTypeSize) -> AxisTitlesWording {
        size > Self.largestSizeForLongTitles ? .short : wording
    }

    /// Says why the long titles are not drawn, only when that is what is happening.
    func wordingNote(at size: DynamicTypeSize) -> String? {
        guard wording == .long, drawnWording(at: size) == .short else { return nil }
        return "An axis title is drawn on one line, never wrapped or shortened, so at this text size the long "
            + "titles can run past the chart's edges on a phone. The chart shows the short ones."
    }

    /// What the chart alone is drawn under: the chosen text size, everything else as the device.
    var chartEnvironment: ChartEnvironment {
        ChartEnvironment(dynamicTypeSize: textSize.dynamicTypeSize)
    }

    /// The code for what is in effect: the titles always, and the mapping for each setting moved off its default.
    var snippets: [SnippetReference] {
        var references = [AxisTitlesSnippets.titles]
        if xPosition != .automatic || yPosition != .automatic {
            references.append(AxisTitlesSnippets.positions)
        }
        if alignment != .automatic {
            references.append(AxisTitlesSnippets.alignments)
        }
        return references
    }
}

/// The screen's code regions, by name and title.
enum AxisTitlesSnippets {
    static let titles = SnippetReference(name: "axis-titles-titles", title: "Axis titles with units")
    static let positions = SnippetReference(name: "axis-titles-positions", title: "Choosing a position")
    static let alignments = SnippetReference(name: "axis-titles-alignments", title: "Choosing an alignment")
}
