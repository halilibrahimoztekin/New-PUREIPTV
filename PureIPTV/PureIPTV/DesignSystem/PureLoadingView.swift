import SwiftUI

/// PureIPTV Signature Loading & Buffering Component
/// High-end streaming aesthetic featuring a rotating cyber neon gradient arc
/// with an ambient glow blur and an optional pulsing brand core.
public struct PureLoadingView: View {
    public enum Size {
        case small // 24x24 (inline indicators, buttons, mini player)
        case medium // 44x44 (player buffering, modal HUDs)
        case large // 72x72 (full-screen loading states)

        var dimension: CGFloat {
            switch self {
            case .small: 24
            case .medium: 44
            case .large: 72
            }
        }

        var strokeWidth: CGFloat {
            switch self {
            case .small: 2.5
            case .medium: 3.5
            case .large: 4.5
            }
        }

        var coreDotSize: CGFloat {
            switch self {
            case .small: 4
            case .medium: 8
            case .large: 14
            }
        }
    }

    public enum Style {
        case neonRing
        case pulsingDots
    }

    private let size: Size
    private let style: Style
    private let text: String?

    @State private var isSpinning = false
    @State private var isPulsing = false

    public init(
        size: Size = .medium,
        style: Style = .neonRing,
        text: String? = nil
    ) {
        self.size = size
        self.style = style
        self.text = text
    }

    public var body: some View {
        VStack(spacing: size == .large ? 16 : 10) {
            switch style {
            case .neonRing:
                neonRingView
            case .pulsingDots:
                pulsingDotsView
            }

            if let text, !text.isEmpty {
                Text(text)
                    .font(size == .large ? Typography.title() : Typography.bodySmall())
                    .fontWeight(.medium)
                    .foregroundStyle(.white.opacity(0.85))
                    .opacity(isPulsing ? 1.0 : 0.6)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
        }
        .onAppear {
            isSpinning = true
            isPulsing = true
        }
    }

    private var neonRingView: some View {
        ZStack {
            // Subtle ambient neon blur glow
            Circle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#00D2FF"),
                            Color(hex: "#0A84FF"),
                            Color(hex: "#BF5AF2"),
                            Color(hex: "#00D2FF").opacity(0.1),
                        ]),
                        center: .center
                    ),
                    lineWidth: size.strokeWidth + 2
                )
                .frame(width: size.dimension, height: size.dimension)
                .blur(radius: max(1, size.dimension * 0.12))
                .opacity(0.6)

            // Crisp spinning gradient arc
            Circle()
                .trim(from: 0.12, to: 0.88)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            Color(hex: "#00D2FF"),
                            Color(hex: "#0A84FF"),
                            Color(hex: "#BF5AF2"),
                            Color(hex: "#00D2FF").opacity(0.15),
                        ]),
                        center: .center
                    ),
                    style: StrokeStyle(lineWidth: size.strokeWidth, lineCap: .round)
                )
                .frame(width: size.dimension, height: size.dimension)
                .rotationEffect(.degrees(isSpinning ? 360 : 0))
                .animation(
                    .linear(duration: 0.95).repeatForever(autoreverses: false),
                    value: isSpinning
                )

            // Center pulsing core dot (for medium & large)
            if size != .small {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#00D2FF"),
                                Color(hex: "#0A84FF").opacity(0.7),
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size.coreDotSize
                        )
                    )
                    .frame(width: size.coreDotSize, height: size.coreDotSize)
                    .scaleEffect(isPulsing ? 1.15 : 0.75)
                    .opacity(isPulsing ? 1.0 : 0.45)
                    .animation(
                        .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
            }
        }
    }

    private var pulsingDotsView: some View {
        let dotSize = size.coreDotSize
        return HStack(spacing: size == .large ? 12 : 6) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "#00D2FF"), Color(hex: "#0A84FF")],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: dotSize, height: dotSize)
                    .scaleEffect(isPulsing ? 1.0 : 0.35)
                    .opacity(isPulsing ? 1.0 : 0.25)
                    .animation(
                        .easeInOut(duration: 0.65)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: isPulsing
                    )
            }
        }
    }
}
