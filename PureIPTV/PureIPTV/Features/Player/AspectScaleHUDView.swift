import SwiftUI

/// Aspect ratio modes for video playback
public enum VideoAspectRatioMode: String, CaseIterable, Equatable, Sendable {
    case fit
    case fill
    case stretch
    case zoom

    public var title: String {
        switch self {
        case .fit: "Orijinal (Fit)"
        case .fill: "Ekranı Doldur (Fill)"
        case .stretch: "Genişlet (Stretch)"
        case .zoom: "Yakınlaştırma (Zoom)"
        }
    }

    public var systemIcon: String {
        switch self {
        case .fit: "arrow.down.right.and.arrow.up.left"
        case .fill: "arrow.up.left.and.arrow.down.right"
        case .stretch: "rectangle.expand.vertical"
        case .zoom: "plus.magnifyingglass"
        }
    }
}

/// A floating glass HUD badge displayed when pinch-to-zoom or aspect ratio toggle is activated.
public struct AspectScaleHUDView: View {
    let mode: VideoAspectRatioMode
    let scale: CGFloat

    public init(mode: VideoAspectRatioMode, scale: CGFloat = 1.0) {
        self.mode = mode
        self.scale = scale
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: mode.systemIcon)
                .font(AppFonts.titleSmall)
                .foregroundStyle(AppColors.textPrimary)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.title)
                    .font(AppFonts.bodyMedium.weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                if mode == .zoom, scale > 1.05 {
                    Text(String(format: "%.1fx Yakınlaştırıldı", scale))
                        .font(AppFonts.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .liquidGlass(shape: .capsule, tint: AppColors.primary, isInteractive: false)
        .shadow(color: AppColors.oledBlack.opacity(0.4), radius: 12, x: 0, y: 6)
        .allowsHitTesting(false)
    }
}
