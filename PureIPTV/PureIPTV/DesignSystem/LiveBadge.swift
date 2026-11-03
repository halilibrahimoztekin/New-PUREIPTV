import SwiftUI

// MARK: - Live Badge (Shared Component for iOS & tvOS)

public struct LiveBadge: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppColors.live)
                .frame(width: 6, height: 6)

            Text(AppStrings.Player.liveLabel)
                .font(AppFonts.captionSmall.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .tracking(0.5)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(AppColors.live.opacity(0.85))
        )
    }
}

// MARK: - Catch-Up Badge (Shared Component for iOS & tvOS)

public struct CatchUpBadge: View {
    public var isCompact: Bool
    public var archiveDays: Int?

    public init(isCompact: Bool = false, archiveDays: Int? = nil) {
        self.isCompact = isCompact
        self.archiveDays = archiveDays.flatMap { $0 > 0 ? $0 : nil }
    }

    public var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "clock.arrow.circlepath")
                .font(AppFonts.captionSmall.weight(.bold))

            if !isCompact {
                Text(label)
                    .font(AppFonts.captionSmall.weight(.bold))
                    .tracking(0.3)
            } else if let archiveDays {
                Text("\(archiveDays)d")
                    .font(AppFonts.captionSmall.weight(.heavy))
            }
        }
        .foregroundStyle(AppColors.textPrimary)
        .padding(.horizontal, isCompact ? 5 : 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [AppColors.premium, AppColors.purpleAccent],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .overlay(
                    Capsule()
                        .stroke(AppColors.borderSubtle, lineWidth: 0.6)
                )
        )
        .shadow(color: AppColors.premium.opacity(0.4), radius: 3)
        .accessibilityLabel(label)
    }

    private var label: String {
        AppStrings.Player.catchUpDescription(archiveDays: archiveDays)
    }
}
