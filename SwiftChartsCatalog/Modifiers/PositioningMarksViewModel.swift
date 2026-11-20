import Foundation
import Observation

/// How the screen writes the nudge on each lollipop's head. Both draw the same thing.
enum PositioningMarksNudgeForm: String, CaseIterable, Identifiable {
    /// `offset(x:y:)`, the two distances as separate arguments.
    case xAndY = "x: y:"
    /// `offset(_:)`, the same move as one `CGSize`.
    case size = "CGSize"

    var id: Self {
        self
    }
}

/// The state of the "Positioning marks" screen: how far each café's lollipops are nudged from the
/// day they stand for, how far each stem stops short of its head, and which form of `offset` the
/// heads are written with. None of it changes a value: it moves marks on screen.
@Observable
final class PositioningMarksViewModel {
    /// The nudge, in points, each café's lollipop is moved from the middle of its day: Harbour one
    /// way, Station the other, so they sit twice this far apart.
    var nudge: Double = PositioningMarksViewModel.defaultNudge
    /// How far, in points, the top of each stem stops short of the value, so it ends at the ring of
    /// the hollow head instead of running through it to the centre.
    var stemInset: Double = PositioningMarksViewModel.defaultStemInset
    var nudgeForm: PositioningMarksNudgeForm = .xAndY

    static let defaultNudge: Double = 6
    static let defaultStemInset: Double = 5
    /// Up to 12 points each way: a day's band on a phone is about 40 points wide, so a lollipop at
    /// the first or last day stays inside the plot.
    static let nudgeRange: ClosedRange<Double> = 0 ... 12
    static let stemInsetRange: ClosedRange<Double> = 0 ... 10

    /// The horizontal shift for a café's marks, in points: Harbour before the day's middle, Station after.
    func shift(for store: String) -> CGFloat {
        store == CafeWording.harbour ? -nudge : nudge
    }

    /// The code the Code view shows for the current form of the nudge.
    var snippets: [SnippetReference] {
        let nudge = switch nudgeForm {
        case .xAndY: SnippetReference(name: "positioning-marks-nudge-xy", title: "Nudge the head: offset(x:y:)")
        case .size: SnippetReference(name: "positioning-marks-nudge-size", title: "Nudge the head: offset(_:)")
        }
        return [nudge, SnippetReference(name: "positioning-marks-stem", title: "Move and inset the stem")]
    }

    /// The nudge as shown and as spoken, which say the same: the setting and what it means, since
    /// each café moves that far, in opposite directions.
    func nudgeText(locale: Locale) -> String {
        "\(CafeWording.points(nudge, locale: locale)) each way"
    }

    /// How far a lollipop's stem stops short of its head. A day with no cups has a stem of no height,
    /// and an inset on it would draw its top edge below the baseline, so it gets none.
    func stemInset(for entry: PositioningMarksEntry) -> CGFloat {
        entry.cups > 0 ? stemInset : 0
    }

    func stemInsetText(locale: Locale) -> String {
        CafeWording.points(stemInset, locale: locale)
    }
}
