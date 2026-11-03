import SwiftUI

public struct CircularProgressRing<CenterContent: View>: View {
    public let progress: Double
    public let lineWidth: CGFloat
    public let size: CGFloat
    public let gradientColors: [Color]
    public let trackColor: Color
    @ViewBuilder public let centerContent: () -> CenterContent

    public init(
        progress: Double,
        lineWidth: CGFloat = 3.5,
        size: CGFloat = 36,
        gradientColors: [Color] = [AppColors.cyan, AppColors.primary],
        trackColor: Color = AppColors.glassBorder,
        @ViewBuilder centerContent: @escaping () -> CenterContent = { EmptyView() }
    ) {
        self.progress = max(0.0, min(1.0, progress))
        self.lineWidth = lineWidth
        self.size = size
        self.gradientColors = gradientColors
        self.trackColor = trackColor
        self.centerContent = centerContent
    }

    public var body: some View {
        ZStack {
            // Background track
            Circle()
                .stroke(trackColor, lineWidth: lineWidth)

            // Animated progress ring
            Circle()
                .trim(from: 0.0, to: CGFloat(progress))
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: gradientColors),
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: gradientColors.first?.opacity(0.4) ?? .clear, radius: 4, x: 0, y: 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)

            // Center slot
            centerContent()
        }
        .frame(width: size, height: size)
    }
}

public extension CircularProgressRing where CenterContent == Text {
    init(
        progress: Double,
        lineWidth: CGFloat = 3.5,
        size: CGFloat = 36,
        gradientColors: [Color] = [AppColors.cyan, AppColors.primary],
        trackColor: Color = AppColors.glassBorder,
        percentageFontSize _: CGFloat = 10
    ) {
        let percent = Int((max(0.0, min(1.0, progress)) * 100).rounded())
        self.init(
            progress: progress,
            lineWidth: lineWidth,
            size: size,
            gradientColors: gradientColors,
            trackColor: trackColor
        ) {
            Text("\(percent)%")
                .font(AppFonts.captionSmall.weight(.bold).monospacedDigit())
                .foregroundColor(AppColors.textPrimary)
        }
    }
}
