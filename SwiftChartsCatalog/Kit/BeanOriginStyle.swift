import Charts
import SwiftUI

/// One look for each bean origin of `CafeData.beanTastings`, shared by every screen that draws the origins,
/// so Ethiopia, Colombia and Sumatra look the same on each: one colour, one 2D symbol (an SF Symbol for a
/// legend, and the matching chart symbol for a 2D chart), and one 3D solid for a `Chart3D`.
///
/// The solids are sphere, cube and cone, each standing for its 2D symbol (circle, square, triangle). The
/// cylinder is left out: seen from the front or the side it draws as a square, the same as a cube. An origin
/// outside the three takes a neutral look, grey with a diamond, so it is never mistaken for one of them; its
/// solid has to be the cylinder, the only one left, and the grey is what tells it from the cube.
nonisolated enum BeanOriginStyle {
    /// The origins in the order every legend lists them: the data's own order.
    static let origins = CafeData.beanOrigins

    /// Ethiopia purple, Colombia teal, Sumatra brown: not the cafés' blue and orange, since this is other data.
    private static let colours: [Color] = [.purple, .teal, .brown]
    private static let neutralColour = Color.gray

    private static let symbolNames = ["circle.fill", "square.fill", "triangle.fill"]
    private static let neutralSymbolName = "diamond.fill"

    private static let solids: [BeanOriginSolid] = [.sphere, .cube, .cone]
    private static let neutralSolid = BeanOriginSolid.cylinder

    /// Whether the origin is one of the three this table styles.
    static func isKnown(_ origin: String) -> Bool {
        origins.contains(origin)
    }

    static func colour(for origin: String) -> Color {
        guard let index = origins.firstIndex(of: origin) else { return neutralColour }
        return colours[index]
    }

    /// The SF Symbol a legend draws for the origin, the same shape as its 2D chart symbol.
    static func symbolName(for origin: String) -> String {
        guard let index = origins.firstIndex(of: origin) else { return neutralSymbolName }
        return symbolNames[index]
    }

    /// The 2D chart symbol, for `chartSymbolScale(domain:mapping:)`: the shape of `symbolName(for:)`.
    static func chartSymbol(for origin: String) -> AnyChartSymbolShape {
        switch origins.firstIndex(of: origin) {
        case 0: AnyChartSymbolShape(.circle)
        case 1: AnyChartSymbolShape(.square)
        case 2: AnyChartSymbolShape(.triangle)
        default: AnyChartSymbolShape(.diamond)
        }
    }

    /// The 3D solid a `Chart3D` draws the origin's points with.
    static func solid(for origin: String) -> BeanOriginSolid {
        guard let index = origins.firstIndex(of: origin) else { return neutralSolid }
        return solids[index]
    }
}

/// The four 3D point shapes, as plain values a view model or a test can hold on any system; the chart maps
/// them to `BasicChart3DSymbolShape` behind its iOS 26 check.
nonisolated enum BeanOriginSolid: CaseIterable {
    case sphere, cube, cone, cylinder

    var name: String {
        switch self {
        case .sphere: "sphere"
        case .cube: "cube"
        case .cone: "cone"
        case .cylinder: "cylinder"
        }
    }

    /// "spheres", for a legend that names the solid beside the origin.
    var pluralName: String {
        switch self {
        case .sphere: "spheres"
        case .cube: "cubes"
        case .cone: "cones"
        case .cylinder: "cylinders"
        }
    }

    /// The SF Symbol for the solid as a legend draws it: the 2D shape it looks like from the front.
    var symbolName: String {
        switch self {
        case .sphere: "circle.fill"
        case .cube: "square.fill"
        case .cone: "triangle.fill"
        case .cylinder: "cylinder.fill"
        }
    }
}

@available(iOS 26, *)
extension BeanOriginSolid {
    /// The framework's symbol for the solid.
    var chartSymbol: BasicChart3DSymbolShape {
        switch self {
        case .sphere: .sphere
        case .cube: .cube
        case .cone: .cone
        case .cylinder: .cylinder
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
        ForEach(BeanOriginStyle.origins + ["Elsewhere"], id: \.self) { origin in
            Label {
                Text("\(origin), \(BeanOriginStyle.solid(for: origin).pluralName)")
            } icon: {
                Image(systemName: BeanOriginStyle.symbolName(for: origin))
                    .foregroundStyle(BeanOriginStyle.colour(for: origin))
            }
        }
    }
    .padding()
}
