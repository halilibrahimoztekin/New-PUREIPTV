import SwiftUI

/// Floating interactive glass card presenting the next episode countdown with auto-play trigger (Madde #42 / #48).
public struct UpNextCountdownOverlayView: View {
    public let item: PlayerFeature.PlayableItem
    public let countdownSeconds: Int
    public let totalSeconds: Int
    public let onPlayNow: () -> Void
    public let onDismiss: () -> Void

    @FocusState private var isPlayButtonFocused: Bool
    @FocusState private var isDismissButtonFocused: Bool

    public init(
        item: PlayerFeature.PlayableItem,
        countdownSeconds: Int,
        totalSeconds: Int = 15,
        onPlayNow: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.item = item
        self.countdownSeconds = countdownSeconds
        self.totalSeconds = max(totalSeconds, 1)
        self.onPlayNow = onPlayNow
        self.onDismiss = onDismiss
    }

    private var progressRatio: CGFloat {
        CGFloat(max(0, countdownSeconds)) / CGFloat(totalSeconds)
    }

    public var body: some View {
        ViewThatFits(in: .horizontal) {
            wideContent
            compactContent
        }
        .padding(14)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.black.opacity(0.45))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.35), location: 0.0),
                                .init(color: Color.white.opacity(0.08), location: 0.5),
                                .init(color: Color.accentColor.opacity(0.3), location: 1.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.55), radius: 24, x: 0, y: 12)
        .onAppear {
            #if os(tvOS)
                isPlayButtonFocused = true
            #endif
        }
        #if os(tvOS)
        .onExitCommand(perform: onDismiss)
        #endif
    }

    private var wideContent: some View {
        HStack(spacing: 16) {
            thumbnail(width: 90, height: 60)
            episodeInfo
                .frame(maxWidth: 240, alignment: .leading)
            Spacer(minLength: 8)
            actionButtons
        }
        .fixedSize(horizontal: true, vertical: false)
    }

    private var compactContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                thumbnail(width: 64, height: 48)
                episodeInfo
            }
            actionButtons
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var episodeInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(AppStrings.Player.upNext.uppercased())
                    .font(.caption.weight(.heavy))
                    .foregroundColor(Color.accentColor)

                Text("•")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Text(AppStrings.Player.upNextPlayingInSeconds(countdownSeconds))
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text(item.title)
                .font(.headline.weight(.bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.75)

            if let series = item.seriesTitle, !series.isEmpty {
                Text(series)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(.white.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var actionButtons: some View {
        HStack(spacing: 10) {
            Button(action: {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                onDismiss()
            }) {
                Text(AppStrings.Player.cancel)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(Color.white.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
            .focused($isDismissButtonFocused)
            .scaleEffect(isDismissButtonFocused ? 1.08 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isDismissButtonFocused)

            Button(action: {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.medium)
                #endif
                onPlayNow()
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(AppStrings.Player.playNow)
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(
                    LinearGradient(
                        colors: [Color.accentColor, Color(hex: "#0A84FF")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: Color.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
            .focused($isPlayButtonFocused)
            .scaleEffect(isPlayButtonFocused ? 1.1 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isPlayButtonFocused)
        }
    }

    private func thumbnail(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            if let url = item.coverURL {
                PlaylistAsyncImage(url: url, fallbackURL: item.fallbackCoverURL, userAgentOverride: item.userAgentOverride, playlistID: item.config?.playlistID) { phase in
                    switch phase {
                    case let .success(img):
                        img.resizable()
                            .scaledToFill()
                    default:
                        fallbackThumbnail
                    }
                }
            } else {
                fallbackThumbnail
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.2), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: progressRatio)
                            .stroke(
                                LinearGradient(
                                    colors: [Color.accentColor, Color(hex: "#0A84FF")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: countdownSeconds)

                        Text("\(countdownSeconds)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .monospacedDigit()
                    }
                    .frame(width: 26, height: 26)
                    .padding(6)
                }
            }
        }
        .frame(width: width, height: height)
        .clipped()
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.5)
        )
    }

    private var fallbackThumbnail: some View {
        ZStack {
            Color(hex: "#1A1A24")
            Image(systemName: "tv.fill")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.3))
        }
    }
}
