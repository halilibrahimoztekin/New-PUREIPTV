import SwiftUI

public struct LiveTimeIndicatorView: View {
    public let height: CGFloat
    public let showTopBadge: Bool

    @State private var pulseGlow: Bool = false

    public init(height: CGFloat, showTopBadge: Bool = true) {
        self.height = height
        self.showTopBadge = showTopBadge
    }

    public var body: some View {
        VStack(spacing: 0) {
            if showTopBadge {
                // Illuminated Live Time Beacon Header Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(AppColors.live)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulseGlow ? 1.3 : 0.9)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseGlow)

                    Text(AppStrings.Player.nowPlaying.uppercased())
                        .font(AppFonts.captionSmall.weight(.heavy))
                        .foregroundColor(AppColors.textPrimary)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColors.live, AppColors.destructive],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            Capsule()
                                .stroke(AppColors.borderSubtle, lineWidth: 0.8)
                        )
                        .shadow(color: AppColors.live.opacity(0.9), radius: pulseGlow ? 10 : 4)
                )
                .offset(y: -4)
            }

            // Pulsing Neon Vertical Laser Line
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            AppColors.live,
                            AppColors.destructive,
                            AppColors.error,
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 2.2, height: height)
                .shadow(color: AppColors.live.opacity(pulseGlow ? 0.9 : 0.5), radius: pulseGlow ? 8 : 4)
        }
        .onAppear {
            pulseGlow = true
        }
    }
}
