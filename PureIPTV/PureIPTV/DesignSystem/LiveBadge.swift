import SwiftUI

// MARK: - Live Badge (Shared Component for iOS & tvOS)

public struct LiveBadge: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: "#FF453A"))
                .frame(width: 6, height: 6)

            Text("CANLI")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .tracking(0.5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(Color(hex: "#FF453A").opacity(0.85))
        )
    }
}
