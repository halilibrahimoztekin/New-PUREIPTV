#if os(iOS)
    import AppIntents
    import SwiftData
    import SwiftUI
    import WidgetKit

    // MARK: - Widget Media Model (Madde #11)

    public struct WidgetMediaItem: Sendable, Equatable, Identifiable {
        public let id: String
        public let title: String
        public let subtitle: String?
        public let coverURL: URL?
        public let streamURL: URL?
        public let progressRatio: Double
        public let type: String
        public let deepLinkURL: URL

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            coverURL: URL? = nil,
            streamURL: URL? = nil,
            progressRatio: Double = 0.0,
            type: String = "vod",
            deepLinkURL: URL
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.coverURL = coverURL
            self.streamURL = streamURL
            self.progressRatio = progressRatio
            self.type = type
            self.deepLinkURL = deepLinkURL
        }
    }

    // MARK: - Widget Entry

    public struct PureIPTVEntry: TimelineEntry {
        public let date: Date
        public let continueWatching: WidgetMediaItem?
        public let favorites: [WidgetMediaItem]

        public init(
            date: Date,
            continueWatching: WidgetMediaItem? = nil,
            favorites: [WidgetMediaItem] = []
        ) {
            self.date = date
            self.continueWatching = continueWatching
            self.favorites = favorites
        }
    }

    // MARK: - Widget Timeline Provider

    public struct PureIPTVProvider: TimelineProvider {
        public init() {}

        static let fallbackDashboardURL: URL = {
            var comps = URLComponents()
            comps.scheme = "pureiptv"
            comps.host = "dashboard"
            return comps.url ?? URL(fileURLWithPath: "/")
        }()

        public func placeholder(in _: Context) -> PureIPTVEntry {
            let sampleDeepLink = PureIPTVProvider.makeDeepLink(
                id: "demo",
                title: "Inception",
                streamURL: nil,
                coverURL: nil,
                type: "vod",
                startPosition: nil
            )
            return PureIPTVEntry(
                date: Date(),
                continueWatching: WidgetMediaItem(
                    id: "sample_1",
                    title: "Inception",
                    subtitle: "Bilim Kurgu • 2010",
                    coverURL: nil,
                    progressRatio: 0.65,
                    type: "vod",
                    deepLinkURL: sampleDeepLink
                ),
                favorites: [
                    WidgetMediaItem(id: "fav_1", title: "TRT 1 HD", type: "live", deepLinkURL: sampleDeepLink),
                    WidgetMediaItem(id: "fav_2", title: "beIN Sports 1", type: "live", deepLinkURL: sampleDeepLink),
                ]
            )
        }

        public func getSnapshot(in _: Context, completion: @escaping (PureIPTVEntry) -> Void) {
            Task { @MainActor in
                let (continueItem, favs) = Self.fetchRealData()
                let entry = PureIPTVEntry(
                    date: Date(),
                    continueWatching: continueItem,
                    favorites: favs
                )
                completion(entry)
            }
        }

        public func getTimeline(in _: Context, completion: @escaping (Timeline<PureIPTVEntry>) -> Void) {
            Task { @MainActor in
                let (continueItem, favs) = Self.fetchRealData()
                let currentDate = Date()
                let entry = PureIPTVEntry(
                    date: currentDate,
                    continueWatching: continueItem,
                    favorites: favs
                )

                // Refresh widget every 15 minutes
                let nextUpdate = Calendar.current.date(byAdding: .minute, value: 15, to: currentDate) ?? currentDate.addingTimeInterval(900)
                let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
                completion(timeline)
            }
        }

        @MainActor
        private static func fetchRealData() -> (continueWatching: WidgetMediaItem?, favorites: [WidgetMediaItem]) {
            guard let container = try? ModelContainer(
                for: SharedDatabaseConfig.schema,
                configurations: SharedDatabaseConfig.createConfigurations()
            ) else {
                return (nil, [])
            }

            let context = container.mainContext

            // 1. Fetch latest Watch History Item
            var historyDesc = FetchDescriptor<WatchHistoryItem>(
                sortBy: [SortDescriptor(\.lastWatchedAt, order: .reverse)]
            )
            historyDesc.fetchLimit = 1

            var continueItem: WidgetMediaItem? = nil
            if let latest = try? context.fetch(historyDesc).first {
                let ratio: Double = if latest.duration > 0 {
                    min(1.0, max(0.0, latest.progress / latest.duration))
                } else {
                    0.0
                }

                let deepLink = makeDeepLink(
                    id: latest.id,
                    title: latest.title,
                    streamURL: latest.streamURL,
                    coverURL: latest.coverURL,
                    type: latest.type,
                    startPosition: latest.progress
                )

                continueItem = WidgetMediaItem(
                    id: latest.id,
                    title: latest.title,
                    subtitle: latest.seriesTitle,
                    coverURL: latest.coverURL.flatMap { URL(string: $0) },
                    streamURL: latest.streamURL.flatMap { URL(string: $0) },
                    progressRatio: ratio,
                    type: latest.type,
                    deepLinkURL: deepLink
                )
            }

            // 2. Fetch Favorites
            var favDesc = FetchDescriptor<FavoriteItem>(
                sortBy: [SortDescriptor(\.addedAt, order: .reverse)]
            )
            favDesc.fetchLimit = 4

            var favoriteItems: [WidgetMediaItem] = []
            if let favs = try? context.fetch(favDesc) {
                favoriteItems = favs.compactMap { fav in
                    let deepLink = makeDeepLink(
                        id: fav.id,
                        title: fav.title,
                        streamURL: fav.streamURL,
                        coverURL: fav.coverURL,
                        type: fav.type,
                        startPosition: nil
                    )

                    return WidgetMediaItem(
                        id: fav.id,
                        title: fav.title,
                        subtitle: nil,
                        coverURL: fav.coverURL.flatMap { URL(string: $0) },
                        streamURL: fav.streamURL.flatMap { URL(string: $0) },
                        progressRatio: 0.0,
                        type: fav.type,
                        deepLinkURL: deepLink
                    )
                }
            }

            return (continueItem, favoriteItems)
        }

        private static func makeDeepLink(
            id: String,
            title: String,
            streamURL: String?,
            coverURL: String?,
            type: String,
            startPosition: Double?
        ) -> URL {
            var comps = URLComponents()
            comps.scheme = "pureiptv"
            comps.host = type.lowercased() == "live" ? "channel" : "play"

            var items = [
                URLQueryItem(name: "id", value: id),
                URLQueryItem(name: "title", value: title),
                URLQueryItem(name: "type", value: type),
            ]

            if let s = streamURL, !s.isEmpty {
                items.append(URLQueryItem(name: "streamURL", value: s))
            }
            if let c = coverURL, !c.isEmpty {
                items.append(URLQueryItem(name: "coverURL", value: c))
            }
            if let p = startPosition, p > 0 {
                items.append(URLQueryItem(name: "startPosition", value: String(format: "%.1f", p)))
            }

            comps.queryItems = items
            return comps.url ?? fallbackDashboardURL
        }
    }

    // MARK: - Widget Views

    public struct PureIPTVWidgetEntryView: View {
        @Environment(\.widgetFamily) var family
        public var entry: PureIPTVProvider.Entry

        public init(entry: PureIPTVProvider.Entry) {
            self.entry = entry
        }

        public var body: some View {
            Group {
                switch family {
                case .systemSmall:
                    smallView
                case .systemMedium:
                    mediumView
                case .systemLarge:
                    largeView
                default:
                    smallView
                }
            }
            .containerBackground(for: .widget) {
                LinearGradient(
                    colors: [AppColors.surfaceSecondary, AppColors.background],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }

        /// ── System Small View ─────────────────────────────────────────────
        private var smallView: some View {
            VStack(alignment: .leading, spacing: 6) {
                // Header Bar
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.cyan)
                        Text("PURE IPTV")
                            .font(AppFonts.captionSmall.weight(.heavy))
                            .foregroundStyle(AppColors.cyan)
                    }

                    Spacer()

                    if entry.continueWatching != nil {
                        Circle()
                            .fill(AppColors.cyan)
                            .frame(width: 6, height: 6)
                    }
                }

                Spacer()

                if let item = entry.continueWatching {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(AppStrings.Dashboard.continueWatching.uppercased())
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.textSecondary)

                        Text(item.title)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)

                        if let sub = item.subtitle {
                            Text(sub)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.glassBorder)
                                    .frame(height: 4)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.cyan, AppColors.primary],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(item.progressRatio), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .padding(.top, 2)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(AppFonts.titleLarge)
                            .foregroundStyle(AppColors.cyan)

                        Text(AppStrings.Widget.startWatching)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Yayınları keşfetmeye başla")
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
            }
            .padding(12)
            .widgetURL(entry.continueWatching?.deepLinkURL ?? PureIPTVProvider.fallbackDashboardURL)
        }

        /// ── System Medium View ────────────────────────────────────────────
        private var mediumView: some View {
            HStack(spacing: 12) {
                // Left: Continue Watching Box
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles.tv.fill")
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.cyan)
                        Text(AppStrings.Dashboard.continueWatching)
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.cyan)
                    }

                    Spacer()

                    if let item = entry.continueWatching {
                        Text(item.title)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .lineLimit(2)

                        if let sub = item.subtitle {
                            Text(sub)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary)
                                .lineLimit(1)
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(AppColors.glassBorder)
                                    .frame(height: 4)

                                Capsule()
                                    .fill(
                                        LinearGradient(
                                            colors: [AppColors.cyan, AppColors.primary],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .frame(width: geo.size.width * CGFloat(item.progressRatio), height: 4)
                            }
                        }
                        .frame(height: 4)

                        Link(destination: item.deepLinkURL) {
                            HStack(spacing: 4) {
                                Image(systemName: "play.fill")
                                    .font(AppFonts.captionSmall.weight(.bold))
                                Text(AppStrings.Common.watchNow)
                                    .font(AppFonts.captionSmall.weight(.bold))
                            }
                            .foregroundStyle(AppColors.oledBlack)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(AppColors.cyan, in: Capsule())
                        }
                        .padding(.top, 2)
                    } else {
                        Text(AppStrings.Widget.startWatching)
                            .font(AppFonts.captionMedium)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
                    .overlay(AppColors.borderSubtle)

                // Right: Favorites Quick Access
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.live)
                        Text(AppStrings.Dashboard.myFavorites)
                            .font(AppFonts.captionSmall.weight(.bold))
                            .foregroundStyle(AppColors.textPrimary.opacity(0.8))
                    }

                    if !entry.favorites.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            ForEach(entry.favorites.prefix(3)) { fav in
                                Link(destination: fav.deepLinkURL) {
                                    HStack(spacing: 6) {
                                        Image(systemName: fav.type.lowercased() == "live" ? "tv.fill" : "film.fill")
                                            .font(AppFonts.captionSmall)
                                            .foregroundStyle(AppColors.primary)
                                            .frame(width: 14)

                                        Text(fav.title)
                                            .font(AppFonts.captionMedium)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(AppFonts.captionSmall.weight(.bold))
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                    .padding(.vertical, 3)
                                }
                            }
                        }
                    } else {
                        Text("Henüz favori eklenmedi")
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.top, 10)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(14)
        }

        /// ── System Large View ─────────────────────────────────────────────
        private var largeView: some View {
            VStack(alignment: .leading, spacing: 14) {
                // Top: Continue Watching Card
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles.tv.fill")
                                .font(AppFonts.captionBold)
                                .foregroundStyle(AppColors.cyan)
                            Text("PURE IPTV")
                                .font(AppFonts.captionSmall.weight(.heavy))
                                .foregroundStyle(AppColors.cyan)
                        }

                        Spacer()

                        Text(AppStrings.Dashboard.continueWatching)
                            .font(AppFonts.captionBold)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    if let item = entry.continueWatching {
                        Link(destination: item.deepLinkURL) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(AppColors.surfaceElevated)
                                        .frame(width: 50, height: 70)

                                    Image(systemName: "play.circle.fill")
                                        .font(AppFonts.titleLarge)
                                        .foregroundStyle(AppColors.cyan)
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.title)
                                        .font(AppFonts.headline)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .lineLimit(2)

                                    if let sub = item.subtitle {
                                        Text(sub)
                                            .font(AppFonts.caption)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }

                                    // Progress bar
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule()
                                                .fill(AppColors.glassBorder)
                                                .frame(height: 5)

                                            Capsule()
                                                .fill(
                                                    LinearGradient(
                                                        colors: [AppColors.cyan, AppColors.primary],
                                                        startPoint: .leading,
                                                        endPoint: .trailing
                                                    )
                                                )
                                                .frame(width: geo.size.width * CGFloat(item.progressRatio), height: 5)
                                        }
                                    }
                                    .frame(height: 5)
                                    .padding(.top, 4)
                                }
                            }
                            .padding(10)
                            .background(AppColors.glassPlate, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }

                Divider()
                    .overlay(AppColors.borderSubtle)

                // Bottom: Favorites Grid
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "heart.fill")
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.live)
                        Text(AppStrings.Dashboard.myFavorites)
                            .font(AppFonts.captionBold)
                            .foregroundStyle(AppColors.textPrimary)

                        Spacer()
                    }

                    if !entry.favorites.isEmpty {
                        VStack(spacing: 6) {
                            ForEach(entry.favorites) { fav in
                                Link(destination: fav.deepLinkURL) {
                                    HStack(spacing: 10) {
                                        Image(systemName: fav.type.lowercased() == "live" ? "tv.fill" : "film.fill")
                                            .font(AppFonts.headline)
                                            .foregroundStyle(AppColors.cyan)
                                            .frame(width: 20)

                                        Text(fav.title)
                                            .font(AppFonts.captionMedium)
                                            .foregroundStyle(AppColors.textPrimary)
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "play.fill")
                                            .font(.system(size: 10))
                                            .foregroundStyle(Color.white.opacity(0.6))
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    } else {
                        Text("Henüz favorilere içerik eklenmedi.")
                            .font(.system(size: 11))
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.vertical, 12)
                    }
                }

                Spacer()
            }
            .padding(16)
        }
    }

    // MARK: - Widget Configuration

    public struct PureIPTVWidget: Widget {
        public let kind: String = "PureIPTVWidget"

        public init() {}

        public var body: some WidgetConfiguration {
            StaticConfiguration(kind: kind, provider: PureIPTVProvider()) { entry in
                PureIPTVWidgetEntryView(entry: entry)
            }
            .configurationDisplayName(AppStrings.Splash.appName)
            .description(AppStrings.Widget.description)
            .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        }
    }
#endif
