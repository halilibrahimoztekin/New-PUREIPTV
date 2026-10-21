import SwiftUI

// MARK: - AFRToastView (Madde #21)

/// A cinematic Obsidian glassmorphic toast notification indicating automatic frame rate (AFR)
/// and dynamic range display matching for judder-free playback.
public struct AFRToastView: View {
    public let result: DisplayMatchResult
    @State private var isGlowPulsing: Bool = false

    public init(result: DisplayMatchResult) {
        self.result = result
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon & Hz Badge
            HStack(spacing: 6) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(tintGradient)

                Text(String(format: "%.0f Hz", result.matchedRate))
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundStyle(tintGradient)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(tintColor.opacity(0.18))
                    .overlay(
                        Capsule()
                            .stroke(tintGradient.opacity(0.5), lineWidth: 1)
                    )
            )

            // Description / Message
            VStack(alignment: .leading, spacing: 2) {
                Text(result.message)
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                HStack(spacing: 4) {
                    if result.isJudderFree {
                        Text("Judder-Free")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: "#30D158"))

                        Text("•")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Text("Kare Hızı Eşlendi")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer(minLength: 0)

            // Dynamic Range Indicator if HDR/DV
            if result.matchedRange.isHDR {
                Text(result.matchedRange.shortBadge)
                    .font(.system(size: 10, weight: .heavy, design: .rounded))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Color(hex: result.matchedRange.primaryColorHex).opacity(0.2))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .stroke(Color(hex: result.matchedRange.primaryColorHex).opacity(0.4), lineWidth: 1)
                            )
                    )
                    .foregroundStyle(Color(hex: result.matchedRange.primaryColorHex))
            }
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
        if result.matchedRate <= 24.5 {
            "film.stack"
        } else if result.matchedRate <= 50.5 {
            "tv"
        } else {
            "gauge.with.needle"
        }
    }

    private var tintColor: Color {
        if result.matchedRate <= 24.5 {
            Color(hex: "#0A84FF") // Apple Blue for Cinematic 24p
        } else if result.matchedRate <= 50.5 {
            Color(hex: "#30D158") // Apple Green for Broadcast 50Hz
        } else {
            Color(hex: "#BF5AF2") // Apple Purple for 60/120Hz
        }
    }

    private var tintGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor, Color(hex: "#0A84FF")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
