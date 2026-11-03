import SwiftUI

public struct TouchLockOverlayView: View {
    public let isLocked: Bool
    public let isPillVisible: Bool
    public let onUnlock: () -> Void

    @State private var pulseIcon: Bool = false

    public init(
        isLocked: Bool,
        isPillVisible: Bool,
        onUnlock: @escaping () -> Void
    ) {
        self.isLocked = isLocked
        self.isPillVisible = isPillVisible
        self.onUnlock = onUnlock
    }

    public var body: some View {
        if isLocked, isPillVisible {
            VStack {
                HStack(spacing: 12) {
                    // Pulsing Lock Icon
                    ZStack {
                        Circle()
                            .fill(AppColors.amber.opacity(0.25))
                            .frame(width: 38, height: 38)

                        Image(systemName: "lock.fill")
                            .font(AppFonts.titleSmall.weight(.bold))
                            .foregroundStyle(AppColors.amber)
                            .scaleEffect(pulseIcon ? 1.15 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                                value: pulseIcon
                            )
                    }

                    // Text Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(AppStrings.Player.screenLocked)
                            .font(AppFonts.bodyMedium.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(AppStrings.Player.tapToUnlock)
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 8)

                    // Unlock Button Action
                    Button {
                        HapticManager.shared.trigger(.success)
                        onUnlock()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.open.fill")
                                .font(AppFonts.captionBold)
                            Text(AppStrings.Player.unlock)
                                .font(AppFonts.captionBold)
                        }
                        .foregroundStyle(AppColors.background)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppColors.textPrimary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(
                                    LinearGradient(
                                        colors: [AppColors.amber.opacity(0.6), AppColors.borderSubtle],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1.5
                                )
                        )
                        .shadow(color: AppColors.background.opacity(0.5), radius: 20, x: 0, y: 10)
                )
                .frame(maxWidth: 380)
                .padding(.top, 40)
                .transition(.scale(scale: 0.85).combined(with: .opacity))

                Spacer()
            }
            .onAppear {
                pulseIcon = true
            }
        }
    }
}
