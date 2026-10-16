import SwiftUI

// MARK: - Live Badge (Shared Component for iOS & tvOS)

public struct LiveBadge: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: "#FF453A"))
                .frame(width: 6, height: 6)

            Text(AppStrings.Player.liveLabel)
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

// MARK: - Catch-Up Badge (Shared Component for iOS & tvOS)

public struct CatchUpBadge: View {
    public var isCompact: Bool

    public init(isCompact: Bool = false) {
        self.isCompact = isCompact
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: isCompact ? 8 : 9, weight: .bold))

            if !isCompact {
                Text(AppStrings.Player.catchUp)
                    .font(.system(size: 9, weight: .bold))
                    .tracking(0.3)
            }
        }
        .foregroundStyle(.white)
        .padding(.horizontal, isCompact ? 5 : 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "#AF52DE"), Color(hex: "#5856D6")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.3), lineWidth: 0.6)
                )
        )
        .shadow(color: Color(hex: "#AF52DE").opacity(0.4), radius: 3)
    }
}
