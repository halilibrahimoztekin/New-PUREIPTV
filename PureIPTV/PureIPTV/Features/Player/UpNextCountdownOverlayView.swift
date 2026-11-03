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
                    .fill(AppColors.background.opacity(0.45))

                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: AppColors.borderSubtle.opacity(0.8), location: 0.0),
                                .init(color: AppColors.borderSubtle.opacity(0.2), location: 0.5),
                                .init(color: AppColors.primary.opacity(0.3), location: 1.0),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: AppColors.background.opacity(0.55), radius: 24, x: 0, y: 12)
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
                    .font(AppFonts.captionBold)
                    .foregroundStyle(AppColors.primary)

                Text("•")
                    .font(AppFonts.captionSmall)
                    .foregroundStyle(AppColors.textSecondary)

                Text(AppStrings.Player.upNextPlayingInSeconds(countdownSeconds))
                    .font(AppFonts.captionMedium)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Text(item.title)
                .font(AppFonts.headline)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .minimumScaleFactor(0.75)

            if let series = item.seriesTitle, !series.isEmpty {
                Text(series)
                    .font(AppFonts.bodySmall)
                    .foregroundStyle(AppColors.textSecondary.opacity(0.85))
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
                    .font(AppFonts.captionBold)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.75))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .frame(minHeight: 44)
                    .background(AppColors.surfaceSecondary, in: Capsule())
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
                        .font(AppFonts.captionBold)
                    Text(AppStrings.Player.playNow)
                        .font(AppFonts.captionBold)
                }
                .foregroundStyle(AppColors.textPrimary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(minHeight: 44)
                .background(
                    LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryDark],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: Capsule()
                )
                .shadow(color: AppColors.primary.opacity(0.4), radius: 6, x: 0, y: 3)
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
                            .stroke(AppColors.borderSubtle, lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: progressRatio)
                            .stroke(
                                LinearGradient(
                                    colors: [AppColors.primary, AppColors.primaryDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1.0), value: countdownSeconds)

                        Text("\(countdownSeconds)")
                            .font(AppFonts.captionBold)
                            .foregroundStyle(AppColors.textPrimary)
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
                .stroke(AppColors.borderSubtle, lineWidth: 0.5)
        )
    }

    private var fallbackThumbnail: some View {
        ZStack {
            AppColors.surfaceSecondary
            Image(systemName: "tv.fill")
                .font(AppFonts.titleMedium)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}
