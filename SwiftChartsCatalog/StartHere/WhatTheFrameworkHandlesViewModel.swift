import Observation
import SwiftUI

/// The appearance the chart is drawn in.
enum FrameworkHandlesAppearance: String, CaseIterable, Identifiable {
    case device, light, dark

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .device: "Device"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .device: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// The text size the chart is drawn at.
enum FrameworkHandlesTextSize: String, CaseIterable, Identifiable {
    case device, extraExtraExtraLarge, accessibility2, accessibility5

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .device: "Device"
        case .extraExtraExtraLarge: "XXX Large"
        case .accessibility2: "Accessibility 2"
        case .accessibility5: "Accessibility 5"
        }
    }

    var dynamicTypeSize: DynamicTypeSize? {
        switch self {
        case .device: nil
        case .extraExtraExtraLarge: .xxxLarge
        case .accessibility2: .accessibility2
        case .accessibility5: .accessibility5
        }
    }
}

/// The locale the chart is drawn in.
enum FrameworkHandlesLocale: String, CaseIterable, Identifiable {
    case device, german, arabic, japanese

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .device: "Device"
        case .german: "German (Germany)"
        case .arabic: "Arabic (Egypt)"
        case .japanese: "Japanese (Japan)"
        }
    }

    var locale: Locale? {
        switch self {
        case .device: nil
        case .german: Locale(identifier: "de_DE")
        case .arabic: Locale(identifier: "ar_EG")
        case .japanese: Locale(identifier: "ja_JP")
        }
    }
}

/// The state of "What the framework handles": three settings forced on the chart, and the words that follow them.
/// The chart's data and code are the same whatever they are set to.
@Observable
final class WhatTheFrameworkHandlesViewModel {
    static let snippets = [
        SnippetReference(name: "what-the-framework-handles-chart", title: "The chart, the same in every setting"),
    ]

    var appearance = FrameworkHandlesAppearance.device
    var textSize = FrameworkHandlesTextSize.device
    var locale = FrameworkHandlesLocale.device

    let totals: [FrameworkHandlesRunningTotal]
    /// The locale the device is in, for the headline's figure and every other word the screen writes.
    private let deviceLocale: Locale

    init(days: [DailySales] = CafeData.harbourSales, deviceLocale: Locale = .current, timeZone: TimeZone = .current) {
        totals = FrameworkHandlesRunningTotal.totals(of: days, timeZone: timeZone)
        self.deviceLocale = deviceLocale
    }

    /// What is forced on the chart. Layout direction is left to the device: the locale control changes formats only.
    var chartEnvironment: ChartEnvironment {
        ChartEnvironment(
            colorScheme: appearance.colorScheme,
            dynamicTypeSize: textSize.dynamicTypeSize,
            locale: locale.locale
        )
    }

    /// The same code in every setting, so the same snippet.
    var snippets: [SnippetReference] {
        Self.snippets
    }

    private var summary: FrameworkHandlesSummary {
        FrameworkHandlesSummary(totals: totals)
    }

    /// The chart's message. Its figure is in the device's locale whatever locale is forced on the chart: the total
    /// is not one of the numbers the chart writes, and the sentence around it is English.
    var headline: String {
        summary.headline(locale: deviceLocale)
    }

    /// The text size the chart is drawn at: the forced one, else the device's.
    func effectiveTextSize(deviceTextSize: DynamicTypeSize) -> DynamicTypeSize {
        textSize.dynamicTypeSize ?? deviceTextSize
    }

    /// The concept, then one sentence for each setting that is forced, saying what changed with no code.
    /// The note on cut-short date labels follows the size the chart is drawn at, forced or the device's own.
    func explanation(deviceTextSize: DynamicTypeSize) -> String {
        var sentences = [Self.concept]
        if chartEnvironment == .device { sentences.append(Self.devicePrompt) }
        if let note = Self.appearanceNote(appearance) { sentences.append(note) }
        if let note = Self.textSizeNote(textSize, effective: effectiveTextSize(deviceTextSize: deviceTextSize)) {
            sentences.append(note)
        }
        if let note = Self.localeNote(locale) { sentences.append(note) }
        return sentences.joined(separator: " ")
    }

    /// How the chart is drawn now, from all three controls.
    func displayDescription(deviceTextSize: DynamicTypeSize) -> String {
        let look = appearance == .device ? "the device's appearance" : "the \(appearance.title.lowercased()) appearance"
        let size = textSize == .device ? "the device's text size" : "\(textSize.title) text size"
        let formats = locale == .device ? "the device's formats" : "\(locale.title) formats"
        let cutShort = Self.cutsDateLabelsShort(at: effectiveTextSize(deviceTextSize: deviceTextSize))
            ? " Date labels that no longer fit are cut short."
            : ""
        return "Shown in \(look), at \(size), in \(formats).\(cutShort)"
    }

    /// Said aloud when a control redraws the chart, for people who cannot see it happen: which settings changed,
    /// how the chart is drawn now, and that its data did not change.
    func announcement(after previous: ChartEnvironment, deviceTextSize: DynamicTypeSize) -> String {
        let now = chartEnvironment
        var changed: [String] = []
        if previous.colorScheme != now.colorScheme { changed.append("appearance") }
        if previous.dynamicTypeSize != now.dynamicTypeSize { changed.append("text size") }
        if previous.locale != now.locale { changed.append("locale") }
        let what = changed.isEmpty ? "Chart redrawn." : "Chart redrawn: \(changed.formatted(.list(type: .and))) changed."
        let data = summary.total > 0
            ? "The line is the same: \(headline)"
            : FrameworkHandlesSummary.nothingSold
        return "\(what) \(displayDescription(deviceTextSize: deviceTextSize)) \(data)"
    }

    static let concept = """
    This chart is one LineMark a day with nothing configured: no colour, font, number format or axis of its own. \
    Swift Charts draws it for the appearance, text size and locale it finds around it, so its code is the same in \
    every setting below.
    """

    static let devicePrompt = "Right now it follows this device."

    static func appearanceNote(_ appearance: FrameworkHandlesAppearance) -> String? {
        switch appearance {
        case .device: nil
        case .light: "Light: the labels, grid lines and line are in the light appearance's colours."
        case .dark: "Dark: the labels and grid lines were redrawn for a dark background, and the line is that appearance's blue."
        }
    }

    /// Whether the default date labels are cut short at a text size. Read from renders of this chart at phone
    /// width: all four fit up to Accessibility 1 and two are cut to an ellipsis from Accessibility 2.
    static func cutsDateLabelsShort(at size: DynamicTypeSize) -> Bool {
        size >= .accessibility2
    }

    static let grewNote = "the axis labels grew with the text and the plot gave up the room."

    static let fewerLabelsNote = """
    What the framework did not do is choose fewer date labels: where they no longer fit it cuts them short, so \
    asking for fewer is the app's job.
    """

    /// The note on text size. `effective` is the size the chart is drawn at: the forced size, else the device's,
    /// so a device already at an accessibility size is told about its cut-short labels with the control on Device.
    static func textSizeNote(_ textSize: FrameworkHandlesTextSize, effective: DynamicTypeSize) -> String? {
        let cutsShort = cutsDateLabelsShort(at: effective)
        switch textSize {
        case .device:
            return cutsShort ? "Text size: this device's text is large enough that the date labels no longer fit. \(fewerLabelsNote)" : nil
        case .extraExtraExtraLarge, .accessibility2, .accessibility5:
            return cutsShort ? "Text size: \(grewNote) \(fewerLabelsNote)" : "Text size: \(grewNote)"
        }
    }

    static func localeNote(_ locale: FrameworkHandlesLocale) -> String? {
        switch locale {
        case .device: nil
        case .german: "Locale: thousands are grouped with a full stop and the dates read day first, as in 1. März."
        case .arabic:
            """
            Locale: both axes use Arabic-Indic digits and Arabic month names. This control does not mirror the \
            chart: layout direction is a separate setting, left as the device has it.
            """
        case .japanese: "Locale: the dates are written month first with their counters, as in 3月1日."
        }
    }
}
