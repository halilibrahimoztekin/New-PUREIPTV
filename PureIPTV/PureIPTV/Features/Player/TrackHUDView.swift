import SwiftUI

public struct TrackHUDView: View {
    public let message: String
    public let iconName: String

    public init(message: String, iconName: String = "waveform.circle.fill") {
        self.message = message
        self.iconName = iconName
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(AppFonts.headline)
                .foregroundColor(AppColors.cyan)
                .shadow(color: AppColors.cyan.opacity(0.5), radius: 6)

            Text(message)
                .font(AppFonts.bodySmall.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [AppColors.borderSubtle, AppColors.cyan.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppColors.oledBlack.opacity(0.6), radius: 14, x: 0, y: 6)
    }
}
