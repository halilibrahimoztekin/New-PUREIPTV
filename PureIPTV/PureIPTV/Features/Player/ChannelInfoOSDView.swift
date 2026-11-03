import SwiftUI

// MARK: - On-Screen Display (OSD) Channel Info Card (Madde #95)

/// A modern, glassmorphic On-Screen Display (OSD) card displayed for 4 seconds when switching channels.
/// Presents channel logo, number, quality badge, active EPG program with timeline progress bar, and next program sneak-peek.
public struct ChannelInfoOSDView: View {
    public let item: PlayerFeature.PlayableItem
    public let channelIndex: Int?
    public let totalChannels: Int?
    public let currentProgram: EPGProgram?
    public let nextProgram: EPGProgram?
    public let isCleaningEnabled: Bool
    public let dynamicRange: VideoDynamicRange?
    public let playlistName: String?

    @State private var isLivePulsing: Bool = false

    public init(
        item: PlayerFeature.PlayableItem,
        channelIndex: Int? = nil,
        totalChannels: Int? = nil,
        currentProgram: EPGProgram? = nil,
        nextProgram: EPGProgram? = nil,
        isCleaningEnabled: Bool = true,
        dynamicRange: VideoDynamicRange? = nil,
        playlistName: String? = nil
    ) {
        self.item = item
        self.channelIndex = channelIndex
        self.totalChannels = totalChannels
        self.currentProgram = currentProgram
        self.nextProgram = nextProgram
        self.isCleaningEnabled = isCleaningEnabled
        self.dynamicRange = dynamicRange
        self.playlistName = playlistName
    }

    public var body: some View {
        HStack(alignment: .center, spacing: 18) {
            // Channel Logo
            channelLogoView

            // Main Details
            VStack(alignment: .leading, spacing: 6) {
                // Top Row: Index, Title, Live Badge, Quality Badge
                HStack(alignment: .center, spacing: 10) {
                    if let index = channelIndex {
                        Text(String(format: "#%02d", index + 1))
                            .font(AppFonts.bodySmall.weight(.bold).monospaced())
                            .foregroundStyle(AppColors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppColors.primary.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                    }

                    Text(isCleaningEnabled ? item.cleanTitle : item.title)
                    #if os(tvOS)
                        .font(AppFonts.headline)
                    #else
                        .font(AppFonts.bodyBold)
                    #endif
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(1)

                    // Live Badge
                    HStack(spacing: 5) {
                        Circle()
                            .fill(AppColors.live)
                            .frame(width: 7, height: 7)
                            .scaleEffect(isLivePulsing ? 1.25 : 0.85)
                            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isLivePulsing)

                        Text(AppStrings.Player.liveLabel)
                            .font(AppFonts.captionSmall.weight(.heavy))
                            .foregroundStyle(AppColors.live)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(AppColors.live.opacity(0.18), in: Capsule())

                    // Quality Badge
                    qualityBadgeView

                    Spacer(minLength: 0)
                }

                // Middle Row: Now & Next EPG Peek with Live Progress Ring (Feature #7)
                NowNextEPGPeekView(
                    currentProgram: currentProgram,
                    nextProgram: nextProgram,
                    isCompact: false,
                    showProgressRing: true
                )

                if let playlistName, !playlistName.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: "list.bullet.rectangle")
                            .accessibilityHidden(true)
                        Text("\(AppStrings.Search.playlistSource) \(playlistName)")
                            .lineLimit(1)
                    }
                    .font(AppFonts.captionMedium)
                    .foregroundStyle(AppColors.textSecondary)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            ZStack {
                #if os(tvOS)
                    AppColors.oledBlack.opacity(0.82)
                #else
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    AppColors.oledBlack.opacity(0.35)
                #endif
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [AppColors.borderStrong, AppColors.borderSubtle],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: AppColors.oledBlack.opacity(0.55), radius: 24, x: 0, y: 12)
        .frame(maxWidth: 720)
        .onAppear {
            isLivePulsing = true
        }
    }

    // MARK: - Channel Logo

    private var channelLogoView: some View {
        Group {
            if let coverURL = item.coverURL {
                PlaylistAsyncImage(url: coverURL, fallbackURL: item.fallbackCoverURL, userAgentOverride: item.userAgentOverride, playlistID: item.config?.playlistID) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        PureLoadingView(size: .small)
                    case .failure:
                        fallbackLogo
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        #if os(tvOS)
        .frame(width: 64, height: 64)
        #else
        .frame(width: 48, height: 48)
        #endif
        .background(AppColors.glassPlate)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppColors.borderStrong, lineWidth: 0.8)
        )
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv")
            .font(AppFonts.titleSmall)
            .foregroundStyle(AppColors.textSecondary)
    }

    // MARK: - Quality Badge

    private var qualityBadgeView: some View {
        let meta = item.cleanedMetadata
        let badgeText: String
        let badgeColor: Color

        if let q = meta.detectedQuality {
            badgeText = q == .uhd4k ? "4K UHD" : (q == .fhd1080 ? "FHD 1080p" : q.rawValue)
            badgeColor = q.badgeColor
        } else if meta.isHEVC {
            badgeText = "HEVC"
            badgeColor = AppColors.success
        } else {
            badgeText = "HD"
            badgeColor = AppColors.textPrimary.opacity(0.8)
        }

        return HStack(spacing: 5) {
            if let country = meta.detectedCountry {
                Text(country)
                    .font(AppFonts.captionSmall.weight(.heavy))
                    .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppColors.borderMedium, in: RoundedRectangle(cornerRadius: 4))
            }

            Text(badgeText)
                .font(AppFonts.captionSmall.weight(.heavy))
                .foregroundStyle(badgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(badgeColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 5))

            if meta.isHEVC, meta.detectedQuality != nil {
                Text("HEVC")
                    .font(AppFonts.captionSmall.weight(.heavy))
                    .foregroundStyle(AppColors.premium)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppColors.premium.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            }

            if meta.isBackup {
                Text("YEDEK")
                    .font(AppFonts.captionSmall.weight(.bold))
                    .foregroundStyle(AppColors.warning)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(AppColors.warning.opacity(0.18), in: RoundedRectangle(cornerRadius: 4))
            }

            // Dynamic Range Badge (HDR, Dolby Vision, HLG) (Madde #20)
            let detectedRange = dynamicRange ?? ColorSpaceDetector.detectFromText(title: item.title, urlString: item.streamURL.absoluteString).range
            if detectedRange.isHDR {
                HStack(spacing: 3) {
                    Image(systemName: detectedRange.iconName)
                        .font(AppFonts.captionSmall.weight(.bold))
                    Text(detectedRange.badgeTitle)
                        .font(AppFonts.captionSmall.weight(.heavy))
                }
                .foregroundStyle(detectedRange.primaryColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(detectedRange.primaryColor.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(detectedRange.primaryColor.opacity(0.4), lineWidth: 0.8)
                        )
                )
            }
        }
    }
}
