import SwiftUI

@main
struct SwiftChartsCatalogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
            #if DEBUG
                .task { await ChartDescriptorDump.runIfAsked() }
            #endif
        }
    }
}
