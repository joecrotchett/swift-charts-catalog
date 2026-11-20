import Foundation

/// Arguments the app accepts at launch, so one screen can be opened and captured without tapping through.
///
///     -screen start-here/your-first-chart    open this screen
///     -screen dashboard                      open the Dashboard tab
///     -showCode                              and present its Code view
struct LaunchArguments: Equatable {
    /// The catalog screen to open; nil when the dashboard is asked for.
    var screenID: String?
    var showsCode = false
    /// Open the Dashboard tab instead of the catalog.
    var opensDashboard = false

    /// The id that opens the Dashboard tab, so the scripts that take a screen id can open it too.
    static let dashboardID = "dashboard"

    init(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        if let index = arguments.firstIndex(of: "-screen"), arguments.indices.contains(index + 1) {
            let id = arguments[index + 1]
            if id == Self.dashboardID { opensDashboard = true } else { screenID = id }
        }
        showsCode = arguments.contains("-showCode")
    }

    static let current = LaunchArguments()
}
