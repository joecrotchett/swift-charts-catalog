import SwiftUI

/// Settings a screen can force on its chart alone, to show what the chart does under them
/// while the rest of the app stays as the device has it.
struct ChartEnvironment: Equatable {
    var colorScheme: ColorScheme?
    var dynamicTypeSize: DynamicTypeSize?
    var locale: Locale?
    var layoutDirection: LayoutDirection?

    static let device = ChartEnvironment()
}

private struct ChartEnvironmentOverride: ViewModifier {
    @Environment(\.colorScheme) private var deviceColorScheme
    @Environment(\.dynamicTypeSize) private var deviceDynamicTypeSize
    @Environment(\.locale) private var deviceLocale
    @Environment(\.layoutDirection) private var deviceLayoutDirection
    let environment: ChartEnvironment

    func body(content: Content) -> some View {
        let scheme = environment.colorScheme ?? deviceColorScheme
        content
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, environment.dynamicTypeSize ?? deviceDynamicTypeSize)
            .environment(\.locale, environment.locale ?? deviceLocale)
            .environment(\.layoutDirection, environment.layoutDirection ?? deviceLayoutDirection)
            // A forced appearance needs its own background, or dark marks sit on a light panel.
            .background(environment.colorScheme == nil ? Color.clear : (scheme == .dark ? Color.black : Color.white))
    }
}

extension View {
    /// Draws this view as it would look under the given settings. `nil` settings follow the device.
    func chartEnvironment(_ environment: ChartEnvironment) -> some View {
        modifier(ChartEnvironmentOverride(environment: environment))
    }
}

#Preview {
    Text(1234.5, format: .number)
        .padding()
        .chartEnvironment(ChartEnvironment(colorScheme: .dark, locale: Locale(identifier: "de_DE")))
}
