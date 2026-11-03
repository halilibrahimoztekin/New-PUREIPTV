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
        LiquidGlassHUDCard(cornerRadius: 18, tint: info.range.primaryColor, isInteractive: false) {
            HStack(spacing: 12) {
                // Icon & Format Badge
                HStack(spacing: 6) {
                    Image(systemName: info.range.iconName)
                        .font(AppFonts.captionBold)
                        .foregroundStyle(badgeGradient)

                    Text(info.range.badgeTitle)
                        .font(AppFonts.captionSmall.weight(.heavy))
                        .tracking(1.2)
                        .foregroundStyle(badgeGradient)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(info.range.primaryColor.opacity(0.18))
                        .overlay(
                            Capsule()
                                .stroke(badgeGradient.opacity(0.45), lineWidth: 1)
                        )
                )

                // Technical Specs (Resolution & Color Space)
                HStack(spacing: 6) {
                    if let res = info.detectedResolution {
                        Text(res)
                            .font(AppFonts.captionBold)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("•")
                            .font(AppFonts.captionMedium)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Text("\(info.bitDepth)-Bit")
                        .font(AppFonts.captionSemibold.monospacedDigit())
                        .foregroundStyle(AppColors.textPrimary.opacity(0.85))

                    Text("•")
                        .font(AppFonts.captionMedium)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(info.range.isHDR ? "BT.2020" : "BT.709")
                        .font(AppFonts.captionSemibold)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                }

                Spacer(minLength: 0)

                // Peak Brightness Chip (Only if HDR)
                if info.range.isHDR {
                    HStack(spacing: 4) {
                        Image(systemName: "sun.max")
                            .font(AppFonts.captionSmall.weight(.bold))
                        Text(info.range == .dolbyVision || info.range == .hdr10Plus ? "4000 nits" : "1000 nits")
                            .font(AppFonts.captionSmall.weight(.heavy).monospacedDigit())
                    }
                    .foregroundStyle(info.range.primaryColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(info.range.primaryColor.opacity(0.12))
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        #if os(tvOS)
        .frame(minWidth: 420, maxWidth: 520)
        #else
        .frame(minWidth: 280, maxWidth: 360)
        #endif
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                isGlowPulsing = true
            }
        }
    }

    private var badgeGradient: LinearGradient {
        LinearGradient(
            colors: info.range.gradientColors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
