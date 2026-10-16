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
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Color(hex: "#00F5D4"))
                .shadow(color: Color(hex: "#00F5D4").opacity(0.5), radius: 6)

            Text(message)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(
            Capsule()
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color(hex: "#00F5D4").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.6), radius: 14, x: 0, y: 6)
    }
}
