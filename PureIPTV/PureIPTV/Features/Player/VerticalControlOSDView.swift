import SwiftUI

#if !os(tvOS)
    import UIKit

    /// Type and value of vertical gesture control
    public enum VerticalOSDType: Equatable, Sendable {
        case volume(Int32)
        case brightness(Double)

        public var percentage: Int {
            switch self {
            case let .volume(val):
                Int(max(0, min(100, val)))
            case let .brightness(val):
                Int(max(0, min(100, round(val * 100))))
            }
        }

        public var isVolume: Bool {
            switch self {
            case .volume: true
            case .brightness: false
            }
        }

        public var systemImageName: String {
            switch self {
            case let .volume(val):
                if val <= 0 {
                    "speaker.slash.fill"
                } else if val < 33 {
                    "speaker.wave.1.fill"
                } else if val < 66 {
                    "speaker.wave.2.fill"
                } else {
                    "speaker.wave.3.fill"
                }
            case let .brightness(val):
                if val < 0.35 {
                    "sun.min.fill"
                } else {
                    "sun.max.fill"
                }
            }
        }

        public var title: String {
            switch self {
            case .volume: "Ses"
            case .brightness: "Parlaklık"
            }
        }
    }

    /// A modern, glassmorphic On-Screen Display (OSD) pill for iOS video playback,
    /// featuring dynamic icons, vertical gradient gauge, and percentage badge.
    public struct VerticalControlOSDView: View {
        let osdType: VerticalOSDType

        public init(osdType: VerticalOSDType) {
            self.osdType = osdType
        }

        public var body: some View {
            VStack(spacing: 12) {
                // Icon with dynamic symbol
                Image(systemName: osdType.systemImageName)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 28, height: 28)
                    .contentTransition(.symbolEffect(.replace))

                // Vertical Track & Level Gauge
                GeometryReader { trackProxy in
                    let height = trackProxy.size.height
                    let fillHeight = height * CGFloat(Double(osdType.percentage) / 100.0)

                    ZStack(alignment: .bottom) {
                        // Track background
                        Capsule()
                            .fill(Color.white.opacity(0.18))
                            .frame(width: 8)

                        // Active fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: osdType.isVolume
                                        ? [Color(hex: "#0A84FF"), Color(hex: "#5E5CE6")]
                                        : [Color(hex: "#FFD60A"), Color(hex: "#FF9F0A")],
                                    startPoint: .bottom,
                                    endPoint: .top
                                )
                            )
                            .frame(width: 8, height: max(6, fillHeight))
                            .animation(.interactiveSpring(response: 0.15, dampingFraction: 0.8), value: fillHeight)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
                .frame(width: 20, height: 110)

                // Percentage Badge
                Text("\(osdType.percentage)%")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(.white)
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 10)
            .frame(width: 58)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                }
            )
            .shadow(color: .black.opacity(0.4), radius: 14, x: 0, y: 6)
            .allowsHitTesting(false)
        }
    }
#endif
