import Charts
import SwiftUI

/// One colour and one symbol for each café, shared by every screen that draws the Harbour and Station series,
/// so the same café looks the same on each. A screen passes it to `chartForegroundStyleScale(domain:mapping:)`
/// and `chartSymbolScale(domain:mapping:)`, and draws any legend of its own from it too.
/// A screen whose subject is the colours themselves ("Colour: never colour alone") keeps its own.
nonisolated enum CafeSeriesStyle {
    /// The cafés in the order their legend lists them.
    static let stores = [CafeWording.harbour, CafeWording.station]

    static func colour(for store: String) -> Color {
        store == CafeWording.station ? .orange : .blue
    }

    static func symbol(for store: String) -> AnyChartSymbolShape {
        store == CafeWording.station ? AnyChartSymbolShape(.square) : AnyChartSymbolShape(.circle)
    }
}

#Preview {
    HStack(spacing: Layout.itemSpacing) {
        ForEach(CafeSeriesStyle.stores, id: \.self) { store in
            Label {
                Text(store)
            } icon: {
                CafeSeriesStyle.symbol(for: store)
                    .fill(CafeSeriesStyle.colour(for: store))
                    .frame(width: Layout.itemSpacing, height: Layout.itemSpacing)
            }
        }
    }
    .padding()
}
