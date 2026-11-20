import SwiftUI

/// The view for a catalog screen: its registered view, or a placeholder while it is only planned.
struct ScreenDestination: View {
    let screen: CatalogScreen

    var body: some View {
        if let registration = ScreenRegistry.entries[screen.id] {
            registration.makeView(screen)
        } else {
            ContentUnavailableView(
                screen.title,
                systemImage: "hammer",
                description: Text("This screen is planned and not built yet.")
            )
        }
    }
}

#Preview {
    ScreenDestination(
        screen: CatalogScreen(id: "none", title: "A planned screen", summary: "", apiSince: "16.0", skillReferences: [])
    )
}
