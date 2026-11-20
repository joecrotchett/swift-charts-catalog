@testable import SwiftChartsCatalog
import Testing

struct LaunchArgumentsTests {
    @Test("Given a screen id, when the arguments are read, then that screen opens in the catalog")
    func screen() {
        let arguments = LaunchArguments(["app", "-screen", "start-here/your-first-chart", "-showCode"])
        #expect(arguments.screenID == "start-here/your-first-chart")
        #expect(arguments.showsCode)
        #expect(!arguments.opensDashboard)
    }

    @Test("Given the dashboard id, when the arguments are read, then the Dashboard tab opens and no catalog screen does")
    func dashboard() {
        let arguments = LaunchArguments(["app", "-screen", LaunchArguments.dashboardID])
        #expect(arguments.opensDashboard)
        #expect(arguments.screenID == nil)
    }

    @Test("Given no arguments, when they are read, then the catalog opens at its start")
    func none() {
        let arguments = LaunchArguments(["app"])
        #expect(arguments.screenID == nil)
        #expect(!arguments.opensDashboard)
        #expect(!arguments.showsCode)
    }
}
