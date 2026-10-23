import SwiftUI

// MARK: - DynamicRangeHUDView (Madde #20)

/// A cinematic, Obsidian glassmorphic HUD pill displayed at the top of the screen
/// when starting or switching to an HDR, Dolby Vision, HLG, or SDR video stream.
public struct DynamicRangeHUDView: View {
    public let info: DynamicRangeInfo
    @State private var isGlowPulsing: Bool = false

    public init(info: DynamicRangeInfo) {
        self.info = info
    }

    public var body: some View {
        HStack(spacing: 12) {
            // Icon & Format Badge
            HStack(spacing: 6) {
                Image(systemName: info.range.iconName)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(badgeGradient)

                Text(info.range.badgeTitle)
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(badgeGradient)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(hex: info.range.primaryColorHex).opacity(0.18))
                    .overlay(
                        Capsule()
                            .stroke(badgeGradient.opacity(0.45), lineWidth: 1)
                    )
            )

            // Technical Specs (Resolution & Color Space)
            HStack(spacing: 6) {
                if let res = info.detectedResolution {
                    Text(res)
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text("•")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }

                Text("\(info.bitDepth)-Bit")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))

                Text("•")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))

                Text(info.range.isHDR ? "BT.2020" : "BT.709")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }

            Spacer(minLength: 0)

            // Peak Brightness Chip (Only if HDR)
            if info.range.isHDR {
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.system(size: 10, weight: .bold))
                    Text(info.range == .dolbyVision || info.range == .hdr10Plus ? "4000 nits" : "1000 nits")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                }
                .foregroundStyle(Color(hex: info.range.primaryColorHex))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color(hex: info.range.primaryColorHex).opacity(0.12))
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        #if os(tvOS)
            .frame(minWidth: 420, maxWidth: 520)
        #else
            .frame(minWidth: 280, maxWidth: 360)
        #endif
            .background(
                ZStack {
                    // OLED True Black Base
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color(hex: "#0C0C10").opacity(0.92))
                        .background(.ultraThinMaterial)

                    // Cinematic Glowing Rim Border
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: info.range.gradientHexes.map { Color(hex: $0).opacity(isGlowPulsing ? 0.65 : 0.3) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.2
                        )
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color(hex: info.range.primaryColorHex).opacity(info.range.isHDR ? 0.35 : 0.15), radius: 18, x: 0, y: 6)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isGlowPulsing = true
                }
            }
    }

    private var badgeGradient: LinearGradient {
        LinearGradient(
            colors: info.range.gradientHexes.map { Color(hex: $0) },
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
