import SwiftUI

#if !os(tvOS)
    import UIKit

    /// Direction and state of smart double-tap seek
    public enum SmartSeekDirection: Equatable, Sendable {
        case backward(seconds: Int)
        case forward(seconds: Int)

        public var seconds: Int {
            switch self {
            case let .backward(sec): sec
            case let .forward(sec): sec
            }
        }

        public var isForward: Bool {
            switch self {
            case .forward: true
            case .backward: false
            }
        }
    }

    /// A high-polish animated overlay displaying expanding ripples, flowing directional chevrons,
    /// and cumulative seek seconds (YouTube / Netflix style) during rapid double/multi-tap gestures.
    public struct SmartDoubleTapSeekOverlay: View {
        let direction: SmartSeekDirection?
        let isLiveWarning: Bool

        @State private var rippleScale: CGFloat = 0.5
        @State private var rippleOpacity: Double = 0.0
        @State private var bounceScale: CGFloat = 1.0
        @State private var chevronStep: Int = 0

        public init(direction: SmartSeekDirection?, isLiveWarning: Bool = false) {
            self.direction = direction
            self.isLiveWarning = isLiveWarning
        }

        public var body: some View {
            GeometryReader { proxy in
                ZStack {
                    if let dir = direction {
                        HStack(spacing: 0) {
                            if !dir.isForward {
                                // Left-Side Backward Arch
                                seekArchView(
                                    isForward: false,
                                    seconds: dir.seconds,
                                    width: proxy.size.width * 0.42,
                                    height: proxy.size.height
                                )
                                Spacer()
                            } else {
                                // Right-Side Forward Arch
                                Spacer()
                                seekArchView(
                                    isForward: true,
                                    seconds: dir.seconds,
                                    width: proxy.size.width * 0.42,
                                    height: proxy.size.height
                                )
                            }
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 0.2)))
                    } else if isLiveWarning {
                        // Live Stream Warning Pill
                        HStack {
                            Spacer()
                            liveStreamWarningPill(width: proxy.size.width * 0.42, height: proxy.size.height)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }
                .allowsHitTesting(false)
            }
            .onChange(of: direction) { _, newDir in
                if let _ = newDir {
                    triggerPulseAnimation()
                }
            }
        }

        // MARK: - Seek Arch View

        private func seekArchView(isForward: Bool, seconds: Int, width: CGFloat, height: CGFloat) -> some View {
            ZStack {
                // Background Curved Glass Arch
                UnevenRoundedRectangle(
                    topLeadingRadius: isForward ? height * 0.5 : 0,
                    bottomLeadingRadius: isForward ? height * 0.5 : 0,
                    bottomTrailingRadius: isForward ? 0 : height * 0.5,
                    topTrailingRadius: isForward ? 0 : height * 0.5
                )
                .fill(
                    LinearGradient(
                        colors: isForward
                            ? [Color.black.opacity(0.0), Color.black.opacity(0.35), Color.black.opacity(0.65)]
                            : [Color.black.opacity(0.65), Color.black.opacity(0.35), Color.black.opacity(0.0)],
                        startPoint: isForward ? .leading : .leading,
                        endPoint: isForward ? .trailing : .trailing
                    )
                )
                .overlay(
                    // Subtle glowing rim
                    UnevenRoundedRectangle(
                        topLeadingRadius: isForward ? height * 0.5 : 0,
                        bottomLeadingRadius: isForward ? height * 0.5 : 0,
                        bottomTrailingRadius: isForward ? 0 : height * 0.5,
                        topTrailingRadius: isForward ? 0 : height * 0.5
                    )
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.25), Color.clear],
                            startPoint: isForward ? .leading : .trailing,
                            endPoint: isForward ? .trailing : .leading
                        ),
                        lineWidth: 1
                    )
                )

                // Animated Expanding Ripple Ring
                Circle()
                    .stroke(Color.white.opacity(0.35), lineWidth: 2)
                    .scaleEffect(rippleScale)
                    .opacity(rippleOpacity)
                    .frame(width: 140, height: 140)

                // Center Info & Chevrons
                VStack(spacing: 8) {
                    // Chevrons Flow Animation
                    HStack(spacing: 5) {
                        if isForward {
                            chevronImage(index: 0, isForward: true)
                            chevronImage(index: 1, isForward: true)
                            chevronImage(index: 2, isForward: true)
                        } else {
                            chevronImage(index: 2, isForward: false)
                            chevronImage(index: 1, isForward: false)
                            chevronImage(index: 0, isForward: false)
                        }
                    }

                    // Cumulative Seconds Label
                    Text("\(isForward ? "+" : "-")\(seconds) saniye")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.6), radius: 3, x: 0, y: 1)
                        .scaleEffect(bounceScale)
                }
                .padding(.horizontal, 24)
            }
            .frame(width: width, height: height)
            .clipped()
        }

        // MARK: - Chevron Animation

        @ViewBuilder
        private func chevronImage(index: Int, isForward: Bool) -> some View {
            let systemName = isForward ? "chevron.right" : "chevron.left"
            let isActive = chevronStep == index

            Image(systemName: systemName)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(isActive ? .white : .white.opacity(0.4))
                .scaleEffect(isActive ? 1.25 : 1.0)
                .animation(.easeInOut(duration: 0.18), value: chevronStep)
        }

        // MARK: - Live Stream Warning Pill

        private func liveStreamWarningPill(width: CGFloat, height: CGFloat) -> some View {
            ZStack {
                UnevenRoundedRectangle(
                    topLeadingRadius: height * 0.45,
                    bottomLeadingRadius: height * 0.45,
                    bottomTrailingRadius: 0,
                    topTrailingRadius: 0
                )
                .fill(
                    LinearGradient(
                        colors: [Color.clear, Color.red.opacity(0.2), Color.red.opacity(0.5)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )

                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                        Text("CANLI YAYIN")
                            .font(.system(size: 13, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                    }

                    Text("İleri Sarma Kapalı")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.9))
                }
                .padding(.horizontal, 20)
            }
            .frame(width: width, height: height)
        }

        // MARK: - Animation Triggers

        private func triggerPulseAnimation() {
            // Pop bounce for the seconds label
            withAnimation(.spring(response: 0.22, dampingFraction: 0.52)) {
                bounceScale = 1.28
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.65)) {
                    bounceScale = 1.0
                }
            }

            // Ripple expansion
            rippleScale = 0.5
            rippleOpacity = 0.85
            withAnimation(.easeOut(duration: 0.55)) {
                rippleScale = 1.6
                rippleOpacity = 0.0
            }

            // Step chevrons
            chevronStep = 0
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                chevronStep = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    chevronStep = 2
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                        chevronStep = 0
                    }
                }
            }
        }
    }
#endif
