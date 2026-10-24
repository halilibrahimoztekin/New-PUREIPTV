#if os(tvOS)
    import Kingfisher
    import SwiftUI

    // MARK: - TV Channel Parallax Card (16:9)

    public struct TVChannelCard: View {
        public let channel: MediaModels.Item
        public let isSelected: Bool
        public let action: () -> Void

        @Environment(\.isFocused) private var isFocused
        @AppStorage("com.pureiptv.tvOSChannelTitlesTwoLines") private var showTwoLineTitles = false

        public init(
            channel: MediaModels.Item,
            isSelected: Bool = false,
            action: @escaping () -> Void
        ) {
            self.channel = channel
            self.isSelected = isSelected
            self.action = action
        }

        public var body: some View {
            Button(action: action) {
                TVParallaxCardContainer(
                    isFocused: isFocused,
                    isSelected: isSelected,
                    cornerRadius: 16,
                    accentColor: Color(hex: "#0A84FF")
                ) {
                    // Katman 1: Arka Plan & Gradyan
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(hex: "#1F1F23"))

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.85)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                } floatingContent: {
                    // Katman 3: Öne fırlayan Parallax Logo & Bilgiler
                    ZStack(alignment: .bottomLeading) {
                        if let logoURL = channel.displayLogoURL {
                            KFImage.url(logoURL, cacheKey: PlaylistArtworkRequest.cacheKey(for: logoURL, userAgentOverride: channel.userAgentOverride))
                                .requestModifier { request in
                                    UserAgentManager.applyHeaders(to: &request, override: channel.userAgentOverride)
                                }
                                .placeholder {
                                    Image(systemName: "tv.fill")
                                        .font(.system(size: 34))
                                        .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                                }
                                .downsampling(size: CGSize(width: 240, height: 160))
                                .cacheOriginalImage()
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: 110, maxHeight: 72)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Image(systemName: "tv.fill")
                                .font(.system(size: 34))
                                .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }

                        HStack(alignment: .center, spacing: 8) {
                            Text(channel.title)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(showTwoLineTitles ? 2 : 1)
                            Spacer()
                            if channel.tvArchive == 1 {
                                CatchUpBadge(isCompact: true, archiveDays: channel.tvArchiveDuration)
                            }
                            LiveBadge()
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 12)
                    }
                }
                .aspectRatio(16 / 9, contentMode: .fit)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(channel.title)
        }
    }

    // MARK: - TV VOD Parallax Card (2:3)

    public struct TVVODCard: View {
        public let vod: MediaModels.Item
        public let isSelected: Bool
        public let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        public init(
            vod: MediaModels.Item,
            isSelected: Bool = false,
            action: @escaping () -> Void
        ) {
            self.vod = vod
            self.isSelected = isSelected
            self.action = action
        }

        public var body: some View {
            Button(action: action) {
                TVParallaxCardContainer(
                    isFocused: isFocused,
                    isSelected: isSelected,
                    cornerRadius: 16,
                    accentColor: Color(hex: "#BF5AF2")
                ) {
                    // Katman 1: Arka Plan Posteri
                    ZStack {
                        if let posterURL = vod.coverURL {
                            KFImage.url(posterURL, cacheKey: PlaylistArtworkRequest.cacheKey(for: posterURL, userAgentOverride: vod.userAgentOverride))
                                .requestModifier { request in
                                    UserAgentManager.applyHeaders(to: &request, override: vod.userAgentOverride)
                                }
                                .placeholder {
                                    ZStack {
                                        Color(hex: "#2C2C30")
                                        Image(systemName: "film")
                                            .font(.system(size: 38))
                                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                                    }
                                }
                                .downsampling(size: CGSize(width: 300, height: 450))
                                .cacheOriginalImage()
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color(hex: "#2C2C30")
                                Image(systemName: "film")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                            }
                        }

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.85)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                } floatingContent: {
                    // Katman 3: Öne fırlayan Dil Rozeti, Başlık & Puan
                    VStack(alignment: .leading, spacing: 6) {
                        if let tag = MediaLanguageDetector.primaryTag(from: vod.title) {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: tag.systemIcon)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(tag.label)
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                }
                                .foregroundColor(tag.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.8), in: Capsule())
                                .overlay(Capsule().stroke(tag.color.opacity(0.7), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.6), radius: 4, y: 1)
                                .padding(10)
                            }
                        }

                        Spacer()
                        Text(vod.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 2)

                        if let rating = vod.rating, rating > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.yellow)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .aspectRatio(2 / 3, contentMode: .fit)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - TV Series Parallax Card (2:3)

    public struct TVSeriesCard: View {
        public let series: MediaModels.Item
        public let isSelected: Bool
        public let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        public init(
            series: MediaModels.Item,
            isSelected: Bool = false,
            action: @escaping () -> Void
        ) {
            self.series = series
            self.isSelected = isSelected
            self.action = action
        }

        public var body: some View {
            Button(action: action) {
                TVParallaxCardContainer(
                    isFocused: isFocused,
                    isSelected: isSelected,
                    cornerRadius: 16,
                    accentColor: Color(hex: "#30D158")
                ) {
                    // Katman 1: Arka Plan Posteri
                    ZStack {
                        if let posterURL = series.coverURL {
                            KFImage.url(posterURL, cacheKey: PlaylistArtworkRequest.cacheKey(for: posterURL, userAgentOverride: series.userAgentOverride))
                                .requestModifier { request in
                                    UserAgentManager.applyHeaders(to: &request, override: series.userAgentOverride)
                                }
                                .placeholder {
                                    ZStack {
                                        Color(hex: "#2C2C30")
                                        Image(systemName: "tv")
                                            .font(.system(size: 38))
                                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                                    }
                                }
                                .downsampling(size: CGSize(width: 300, height: 450))
                                .cacheOriginalImage()
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            ZStack {
                                Color(hex: "#2C2C30")
                                Image(systemName: "tv")
                                    .font(.system(size: 38))
                                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
                            }
                        }

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.85)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                } floatingContent: {
                    // Katman 3: Öne fırlayan Dil Rozeti & Başlık
                    VStack(alignment: .leading, spacing: 6) {
                        if let tag = MediaLanguageDetector.primaryTag(from: series.title) {
                            HStack {
                                Spacer()
                                HStack(spacing: 4) {
                                    Image(systemName: tag.systemIcon)
                                        .font(.system(size: 11, weight: .bold))
                                    Text(tag.label)
                                        .font(.system(size: 11, weight: .heavy, design: .rounded))
                                }
                                .foregroundColor(tag.color)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.8), in: Capsule())
                                .overlay(Capsule().stroke(tag.color.opacity(0.7), lineWidth: 1))
                                .shadow(color: Color.black.opacity(0.6), radius: 4, y: 1)
                                .padding(10)
                            }
                        }

                        Spacer()
                        Text(series.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 2)
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
                .aspectRatio(2 / 3, contentMode: .fit)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - TV Favorite Media Parallax Card

    public struct TVFavoriteMediaCard: View {
        public let item: FavoriteItem
        public let userAgentOverride: String?
        public let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        public init(item: FavoriteItem, userAgentOverride: String? = nil, action: @escaping () -> Void) {
            self.item = item
            self.userAgentOverride = userAgentOverride
            self.action = action
        }

        private var isLive: Bool {
            item.type.lowercased() == "live"
        }

        public var body: some View {
            Button(action: action) {
                TVParallaxCardContainer(
                    isFocused: isFocused,
                    isSelected: false,
                    cornerRadius: 16,
                    accentColor: Color(hex: "#FF375F")
                ) {
                    // Katman 1: Poster & Arka Plan
                    ZStack {
                        if let urlString = item.coverURL, let url = URL(string: urlString) {
                            KFImage.url(url, cacheKey: PlaylistArtworkRequest.cacheKey(for: url, userAgentOverride: userAgentOverride))
                                .requestModifier { request in
                                    UserAgentManager.applyHeaders(to: &request, override: userAgentOverride)
                                }
                                .placeholder {
                                    placeholderBackground
                                }
                                .downsampling(size: isLive ? CGSize(width: 320, height: 180) : CGSize(width: 300, height: 450))
                                .cacheOriginalImage()
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else {
                            placeholderBackground
                        }

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.85)],
                            startPoint: .center,
                            endPoint: .bottom
                        )
                    }
                } floatingContent: {
                    // Katman 3: Floating Heart Icon & Title
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Spacer()
                            Image(systemName: "heart.fill")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(Color(hex: "#FF375F"))
                                .padding(8)
                                .background(Color.black.opacity(0.65), in: Circle())
                                .shadow(color: Color.black.opacity(0.5), radius: 4, y: 1)
                                .padding(10)
                        }

                        Spacer()
                        Text(item.title)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(isLive ? 1 : 2)
                            .shadow(color: .black.opacity(0.8), radius: 6, x: 0, y: 2)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 12)
                    }
                }
                .aspectRatio(isLive ? 16 / 9 : 2 / 3, contentMode: .fit)
            }
            .buttonStyle(.plain)
        }

        private var placeholderBackground: some View {
            ZStack {
                Color(hex: "#2C2C30")
                Image(systemName: isLive ? "tv" : "film")
                    .font(.system(size: 34))
                    .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.25))
            }
        }
    }
#endif
