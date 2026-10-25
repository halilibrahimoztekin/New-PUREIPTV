import SwiftUI

// MARK: - EPG 'Now & Next' Channel Peek with Live Elapsed Progress Ring (Feature #7)

/// A cinematic EPG sneak-peek component showing currently playing program with a circular/linear
/// elapsed progress indicator and the upcoming next program with countdown badges.
public struct NowNextEPGPeekView: View {
    @Environment(\.locale) private var locale
    public let currentProgram: EPGProgram?
    public let nextProgram: EPGProgram?
    public var isCompact: Bool = false
    public var showProgressRing: Bool = true

    @State private var currentDate: Date = .init()
    @State private var pulseLiveBadge: Bool = false

    public init(
        currentProgram: EPGProgram?,
        nextProgram: EPGProgram?,
        isCompact: Bool = false,
        showProgressRing: Bool = true
    ) {
        self.currentProgram = currentProgram
        self.nextProgram = nextProgram
        self.isCompact = isCompact
        self.showProgressRing = showProgressRing
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 6 : 10) {
            if let current = currentProgram {
                nowPlayingRow(program: current)

                if let next = nextProgram {
                    nextProgramRow(program: next)
                }
            } else {
                fallbackNoEPGView
            }
        }
        .onAppear {
            currentDate = Date()
            pulseLiveBadge = true
        }
    }

    // MARK: - Now Playing Row

    @ViewBuilder
    private func nowPlayingRow(program: EPGProgram) -> some View {
        let progress = program.progress(at: currentDate)
        let remainingMins = program.remainingMinutes(at: currentDate)
        let elapsedPercent = Int(progress * 100)

        HStack(alignment: .center, spacing: isCompact ? 8 : 12) {
            // Live Elapsed Progress Ring
            if showProgressRing {
                progressRing(progress: progress, percent: elapsedPercent)
            }

            VStack(alignment: .leading, spacing: 3) {
                // Program Title & Time Range
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(program.title)
                    #if os(tvOS)
                        .font(.system(size: isCompact ? 17 : 20, weight: .bold))
                    #else
                        .font(.system(size: isCompact ? 14 : 16, weight: .bold))
                    #endif
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer(minLength: 0)

                    Text(program.formattedTimeRange(locale: locale))
                        .font(.system(size: isCompact ? 11 : 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.65))
                }

                // Gradient Progress Bar & Remaining Time Pill
                HStack(spacing: 8) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.white.opacity(0.12))
                                .frame(height: isCompact ? 3.5 : 4.5)

                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#0A84FF"), Color(hex: "#00F5D4")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(0, min(geo.size.width, geo.size.width * CGFloat(progress))), height: isCompact ? 3.5 : 4.5)
                                .shadow(color: Color(hex: "#0A84FF").opacity(0.5), radius: 4, x: 0, y: 0)
                        }
                    }
                    .frame(height: isCompact ? 3.5 : 4.5)

                    if remainingMins > 0 {
                        Text(AppStrings.Player.minutesRemaining(remainingMins))
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#00F5D4"))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 1.5)
                            .background(Color(hex: "#00F5D4").opacity(0.15), in: Capsule())
                    }
                }
            }
        }
    }

    // MARK: - Circular Progress Ring

    private func progressRing(progress: Double, percent: Int) -> some View {
        let size: CGFloat = isCompact ? 28 : 36
        let strokeWidth: CGFloat = isCompact ? 2.5 : 3.5

        return ZStack {
            // Track
            Circle()
                .stroke(Color.white.opacity(0.12), lineWidth: strokeWidth)

            // Progress Fill
            Circle()
                .trim(from: 0.0, to: CGFloat(min(1.0, max(0.0, progress))))
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#0A84FF"), Color(hex: "#00F5D4")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)

            // Center Percentage
            Text("\(percent)%")
                .font(.system(size: isCompact ? 8 : 10, weight: .heavy, design: .monospaced))
                .foregroundStyle(Color(hex: "#00F5D4"))
        }
        .frame(width: size, height: size)
    }

    // MARK: - Next Program Row

    private func nextProgramRow(program: EPGProgram) -> some View {
        HStack(alignment: .center, spacing: 6) {
            // "SONRAKİ" Badge
            Text(AppStrings.Player.nextLabel)
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(hex: "#BF5AF2"))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color(hex: "#BF5AF2").opacity(0.18), in: RoundedRectangle(cornerRadius: 4))

            Text(program.formattedStartTime(locale: locale))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#BF5AF2").opacity(0.9))

            Text(program.title)
                .font(.system(size: isCompact ? 12 : 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.leading, showProgressRing ? (isCompact ? 36 : 48) : 0)
    }

    // MARK: - Fallback when EPG is Unavailable

    private var fallbackNoEPGView: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 7, height: 7)
                .scaleEffect(pulseLiveBadge ? 1.25 : 0.8)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseLiveBadge)

            Text(AppStrings.Player.liveBroadcast)
                .font(.system(size: isCompact ? 12 : 14, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))

            Spacer(minLength: 0)
        }
    }
}
