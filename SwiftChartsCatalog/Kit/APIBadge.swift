import SwiftUI

/// The release that introduced the API a screen shows, such as "iOS 17.0+".
struct APIBadge: View {
    let apiSince: String

    var body: some View {
        Text("iOS \(apiSince)+")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, Layout.badgeHorizontalPadding)
            .padding(.vertical, Layout.badgeVerticalPadding)
            .background(.tint.opacity(0.15), in: .rect(cornerRadius: Layout.badgeCornerRadius))
            .accessibilityLabel("Available from iOS \(apiSince)")
    }
}

#Preview {
    APIBadge(apiSince: "17.0")
}
