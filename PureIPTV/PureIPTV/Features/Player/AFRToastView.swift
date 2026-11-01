import SwiftUI

// MARK: - AFRToastView (Madde #21)

/// Reports whether tvOS received a display-criteria request or why matching was unavailable.
public struct AFRToastView: View {
    public let result: DisplayMatchResult
    @State private var isGlowPulsing: Bool = false

    public init(result: DisplayMatchResult) {
        self.result = result
    }

    public var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(tintGradient)
                .frame(width: 40, height: 40)
                .background(tintColor.opacity(0.18), in: Circle())

            Text(result.message)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #if os(tvOS)
            .frame(minWidth: 420, maxWidth: 540)
        #else
            .frame(minWidth: 280, maxWidth: 360)
        #endif
            .background(
                ZStack {
                    // OLED True Black Base
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "#0C0C10").opacity(0.92))
                        .background(.ultraThinMaterial)

                    // Glowing Rim Border
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(isGlowPulsing ? 0.7 : 0.3),
                                    Color(hex: "#BF5AF2").opacity(isGlowPulsing ? 0.4 : 0.15),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: tintColor.opacity(0.3), radius: 18, x: 0, y: 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isGlowPulsing = true
                }
            }
    }

    private var iconName: String {
        result.status == .requestSubmitted ? "tv" : "exclamationmark.triangle.fill"
    }

    private var tintColor: Color {
        result.status == .requestSubmitted ? Color(hex: "#0A84FF") : Color(hex: "#FF9F0A")
    }

    private var tintGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor, Color(hex: "#0A84FF")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
