import SwiftUI

/// PureIPTV Material Design 3 Fusion Logo
/// Blends the floating tinted glass television screen plate with the iconic 'P' + Play triangle ribbon fusion.
public struct PureMaterialLogo: View {
    public var size: CGFloat
    public var showGlow: Bool

    public init(size: CGFloat = 90, showGlow: Bool = true) {
        self.size = size
        self.showGlow = showGlow
    }

    public var body: some View {
        ZStack {
            // Ambient glow
            if showGlow {
                RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#00D2FF").opacity(0.35),
                                Color(hex: "#9333EA").opacity(0.18),
                                Color.clear,
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.8
                        )
                    )
                    .frame(width: size * 1.4, height: size * 1.4)
                    .blur(radius: size * 0.12)
            }

            // Material Layer 1: Dark Midnight Base
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#101626"),
                            Color(hex: "#070B14"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.black.opacity(0.55), radius: size * 0.14, x: 0, y: size * 0.08)

            // Material Layer 2: Floating Glass Screen Plate (Konsept 3 Screen)
            ZStack {
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: "#22314F").opacity(0.7),
                                Color(hex: "#121A2D").opacity(0.85),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // Glass specular diagonal shine reflection
                RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.4),
                                Color(hex: "#00D2FF").opacity(0.3),
                                Color.white.opacity(0.05),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: max(1.0, size * 0.015)
                    )
            }
            .frame(width: size * 0.82, height: size * 0.82)
            .shadow(color: Color.black.opacity(0.4), radius: size * 0.08, x: 0, y: size * 0.05)

            // Material Layer 3: Iconic 'P' + Play Symbol Fusion (Konsept 2 Fusion)
            PurePPlayFusionSymbol(size: size * 0.52)
                .shadow(color: Color(hex: "#00D2FF").opacity(0.45), radius: size * 0.08, x: 0, y: 0)
        }
        .frame(width: size, height: size)
    }
}

/// The Iconic "P" + Play button fusion symbol
private struct PurePPlayFusionSymbol: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            // Shadow behind the symbol
            PShape()
                .fill(Color.black.opacity(0.35))
                .frame(width: size, height: size)
                .offset(x: size * 0.03, y: size * 0.05)

            // Outer 'P' Ribbon (Electric Cyan & Blue)
            PShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#00E5FF"),
                            Color(hex: "#0A84FF"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)

            // Folded Magenta/Purple Play Ribbon Loop
            PlayRibbonLoop()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#9333EA"),
                            Color(hex: "#E11D48"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.72, height: size * 0.64)
                .offset(x: size * 0.12, y: -size * 0.08)
                .shadow(color: Color.black.opacity(0.3), radius: size * 0.04, x: -size * 0.02, y: size * 0.02)

            // Central Blue Play Triangle
            PlayTriangleShape()
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "#38BDF8"),
                            Color(hex: "#2563EB"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size * 0.44, height: size * 0.44)
                .offset(x: size * 0.06, y: -size * 0.08)
                .shadow(color: Color.black.opacity(0.25), radius: size * 0.03, x: size * 0.02, y: size * 0.02)
        }
    }
}

/// The outer curved 'P' glyph shape
private struct PShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height
        let stemWidth = w * 0.24
        let cornerRadius = w * 0.12

        // Main stem
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: rect.minY, width: stemWidth, height: h),
            cornerSize: CGSize(width: cornerRadius, height: cornerRadius)
        )

        // Upper loop
        let loopRect = CGRect(x: rect.minX + stemWidth * 0.5, y: rect.minY, width: w - stemWidth * 0.5, height: h * 0.65)
        path.addRoundedRect(
            in: loopRect,
            cornerSize: CGSize(width: loopRect.height * 0.5, height: loopRect.height * 0.5)
        )

        return path
    }
}

/// The curved loop ribbon of the 'P'
private struct PlayRibbonLoop: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.height * 0.5
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        return path
    }
}

/// The inner play triangle shape
private struct PlayTriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r: CGFloat = rect.width * 0.22

        let p1 = CGPoint(x: rect.minX + rect.width * 0.15, y: rect.minY + rect.height * 0.12)
        let p2 = CGPoint(x: rect.maxX - rect.width * 0.10, y: rect.midY)
        let p3 = CGPoint(x: rect.minX + rect.width * 0.15, y: rect.maxY - rect.height * 0.12)

        path.move(to: CGPoint(x: p1.x + r, y: p1.y))
        path.addArc(tangent1End: p2, tangent2End: p3, radius: r)
        path.addArc(tangent1End: p3, tangent2End: p1, radius: r)
        path.addArc(tangent1End: p1, tangent2End: p2, radius: r)
        path.closeSubpath()

        return path
    }
}
