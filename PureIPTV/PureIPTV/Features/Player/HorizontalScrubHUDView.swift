import SwiftUI

#if !os(tvOS)
    import UIKit

    /// Model holding horizontal scrubbing preview details
    public struct HorizontalScrubState: Equatable, Sendable {
        public var targetTime: Duration
        public var totalTime: Duration
        public var offsetSeconds: Int
        public var targetPosition: Double
        public var initialPosition: Double

        public init(
            targetTime: Duration,
            totalTime: Duration,
            offsetSeconds: Int,
            targetPosition: Double,
            initialPosition: Double
        ) {
            self.targetTime = targetTime
            self.totalTime = totalTime
            self.offsetSeconds = offsetSeconds
            self.targetPosition = targetPosition
            self.initialPosition = initialPosition
        }
    }

    /// A high-polish floating glass HUD for horizontal pan scrubbing across video timelines,
    /// featuring target timestamp, relative offset pill (+01:30 / -00:45), and dual-indicator progress line.
    public struct HorizontalScrubHUDView: View {
        let state: HorizontalScrubState

        public init(state: HorizontalScrubState) {
            self.state = state
        }

        public var body: some View {
            VStack(spacing: 12) {
                // Target Time & Offset Badge Header
                HStack(spacing: 8) {
                    // Direction icon
                    Image(systemName: state.offsetSeconds >= 0 ? "goforward" : "gobackward")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(state.offsetSeconds >= 0 ? Color(hex: "#30D158") : Color(hex: "#FF9F0A"))

                    // Target timestamp
                    Text(formatDuration(state.targetTime))
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(.white)

                    // Total duration suffix
                    Text("/ \(formatDuration(state.totalTime))")
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.65))

                    // Relative offset pill (+01:30 / -00:45)
                    HStack(spacing: 2) {
                        Text(state.offsetSeconds >= 0 ? "+\(formatSeconds(state.offsetSeconds))" : "-\(formatSeconds(abs(state.offsetSeconds)))")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundColor(state.offsetSeconds >= 0 ? Color(hex: "#30D158") : Color(hex: "#FF9F0A"))
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        (state.offsetSeconds >= 0 ? Color(hex: "#30D158") : Color(hex: "#FF9F0A")).opacity(0.18),
                        in: Capsule()
                    )
                }

                // Dual Indicator Miniature Timeline Bar
                GeometryReader { proxy in
                    let width = proxy.size.width
                    let targetX = min(width, max(0, width * CGFloat(state.targetPosition)))
                    let initialX = min(width, max(0, width * CGFloat(state.initialPosition)))

                    ZStack(alignment: .leading) {
                        // Base track
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(height: 5)

                        // Spanned seek highlight
                        let startX = min(initialX, targetX)
                        let spanWidth = max(4, abs(targetX - initialX))

                        Capsule()
                            .fill(state.offsetSeconds >= 0 ? Color(hex: "#30D158").opacity(0.6) : Color(hex: "#FF9F0A").opacity(0.6))
                            .frame(width: spanWidth, height: 5)
                            .offset(x: startX)

                        // Initial position anchor pin
                        Circle()
                            .fill(Color.white.opacity(0.5))
                            .frame(width: 7, height: 7)
                            .offset(x: max(0, initialX - 3.5))

                        // Target scrub cursor (glowing head)
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .shadow(color: .white.opacity(0.6), radius: 4)
                            .offset(x: max(0, targetX - 7))
                    }
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .frame(height: 16)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(minWidth: 260, maxWidth: 320)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(.ultraThinMaterial)

                    RoundedRectangle(cornerRadius: 20, style: .continuous)
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
            .shadow(color: .black.opacity(0.45), radius: 16, x: 0, y: 8)
            .allowsHitTesting(false)
        }

        private func formatDuration(_ duration: Duration) -> String {
            let totalSeconds = Int(duration.components.seconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }

        private func formatSeconds(_ secs: Int) -> String {
            let hours = secs / 3600
            let minutes = (secs % 3600) / 60
            let seconds = secs % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
    }
#endif
