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
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.title)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                if mode == .zoom || scale > 1.05 {
                    Text(String(format: "%.1fx Yakınlaştırıldı", scale))
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            ZStack {
                Capsule()
                    .fill(.ultraThinMaterial)

                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.35), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
        .allowsHitTesting(false)
    }
}
