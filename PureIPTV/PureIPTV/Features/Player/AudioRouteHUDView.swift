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
            .blue
        case .airPods:
            .green
        case .bluetooth:
            .orange
        case .wired:
            .purple
        case .speaker, .unknown:
            .white
        }
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon Badge with Glowing Aura
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.2))
                    .frame(width: 36, height: 36)

                Image(systemName: routeInfo.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(accentColor)
            }

            // Route Name & Status
            VStack(alignment: .leading, spacing: 2) {
                Text(routeInfo.name)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(routeInfo.isExternal ? AppStrings.Player.audioConnected : AppStrings.Player.audioRoute)
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
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
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [accentColor.opacity(0.6), Color.white.opacity(0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                )
                .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
        )
        .frame(maxWidth: 340)
        .onAppear {
            wavePhase = true
        }
    }
}
