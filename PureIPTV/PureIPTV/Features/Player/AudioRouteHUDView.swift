import SwiftUI

public struct AudioRouteHUDView: View {
    public let routeInfo: AudioRouteInfo
    public let isPlaying: Bool

    @State private var wavePhase: Bool = false

    public init(routeInfo: AudioRouteInfo, isPlaying: Bool = true) {
        self.routeInfo = routeInfo
        self.isPlaying = isPlaying
    }

    private var accentColor: Color {
        switch routeInfo.type {
        case .airPlay:
            AppColors.primary
        case .airPods:
            AppColors.success
        case .bluetooth:
            AppColors.warning
        case .wired:
            AppColors.premium
        case .speaker, .unknown:
            AppColors.textPrimary
        }
    }

    public var body: some View {
        LiquidGlassHUDCard(cornerRadius: 20, tint: accentColor, isInteractive: false) {
            HStack(spacing: 12) {
                // Icon Badge with Glowing Aura
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.2))
                        .frame(width: 36, height: 36)

                    Image(systemName: routeInfo.iconName)
                        .font(AppFonts.captionBold)
                        .foregroundStyle(accentColor)
                }

                // Route Name & Status
                VStack(alignment: .leading, spacing: 2) {
                    Text(routeInfo.name)
                        .font(AppFonts.bodySmall.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    Text(routeInfo.isExternal ? AppStrings.Player.audioConnected : AppStrings.Player.audioRoute)
                        .font(AppFonts.captionSmall)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 8)

                // Animated Soundwave Visualizer Bars
                if routeInfo.isExternal, isPlaying {
                    HStack(alignment: .bottom, spacing: 3) {
                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accentColor)
                            .frame(width: 3, height: wavePhase ? 16 : 6)
                            .animation(.easeInOut(duration: 0.4).repeatForever(autoreverses: true), value: wavePhase)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accentColor)
                            .frame(width: 3, height: wavePhase ? 8 : 18)
                            .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true).delay(0.1), value: wavePhase)

                        RoundedRectangle(cornerRadius: 1.5)
                            .fill(accentColor)
                            .frame(width: 3, height: wavePhase ? 14 : 7)
                            .animation(.easeInOut(duration: 0.35).repeatForever(autoreverses: true).delay(0.2), value: wavePhase)
                    }
                    .frame(height: 20)
                    .padding(.trailing, 4)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
        }
        .frame(maxWidth: 340)
        .onAppear {
            wavePhase = true
        }
    }
}
