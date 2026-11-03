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
                .font(AppFonts.titleSmall.weight(.bold))
                .foregroundStyle(tintGradient)
                .frame(width: 40, height: 40)
                .background(tintColor.opacity(0.18), in: Circle())

            Text(result.message)
                .font(AppFonts.captionBold)
                .foregroundStyle(AppColors.textPrimary)
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
                        .fill(AppColors.background.opacity(0.92))
                        .background(.ultraThinMaterial)

                    // Glowing Rim Border
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    tintColor.opacity(isGlowPulsing ? 0.7 : 0.3),
                                    AppColors.premium.opacity(isGlowPulsing ? 0.4 : 0.15),
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
        result.status == .requestSubmitted ? AppColors.primary : AppColors.amber
    }

    private var tintGradient: LinearGradient {
        LinearGradient(
            colors: [tintColor, AppColors.primary],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
