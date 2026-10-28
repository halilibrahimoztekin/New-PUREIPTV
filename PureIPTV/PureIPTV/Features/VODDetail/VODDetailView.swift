import ComposableArchitecture
import SwiftUI
#if os(iOS)
    import WebKit
#endif

struct ExpandableSynopsisView: View {
    let text: String
    let font: Font
    let lineLimit: Int
    let onPresent: () -> Void

    var body: some View {
        Button {
            onPresent()
        } label: {
            Text(text)
                .font(font)
                .foregroundStyle(Color.white.opacity(0.8))
                .lineSpacing(6)
                .lineLimit(lineLimit)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AppStrings.VODDetail.overview)
    }
}

public struct VODDetailView: View {
    let store: StoreOf<VODDetailFeature>
    let onPresentSynopsis: (String) -> Void
    @State private var hasDisappeared = false

    public init(
        store: StoreOf<VODDetailFeature>,
        onPresentSynopsis: @escaping (String) -> Void = { _ in }
    ) {
        self.store = store
        self.onPresentSynopsis = onPresentSynopsis
    }

    public var body: some View {
        Group {
            #if os(tvOS)
                VODDetailView_tvOS(store: store, onPresentSynopsis: onPresentSynopsis)
                    .onAppear { hasDisappeared = false }
                    .onDisappear {
                        guard !hasDisappeared else { return }
                        hasDisappeared = true
                        store.send(.viewDidDisappear)
                    }
            #else
                VODDetailView_iOS(store: store)
                    .onAppear { hasDisappeared = false }
                    .onDisappear {
                        guard !hasDisappeared else { return }
                        hasDisappeared = true
                        store.send(.viewDidDisappear)
                    }
            #endif
        }
        .overlay(alignment: .topTrailing) {
            if store.canManageTMDBMatch {
                Button {
                    store.send(.showTMDBMatchPicker)
                } label: {
                    Label(AppStrings.TMDBMatchPicker.title, systemImage: "film")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                }
                .padding(.top, 12)
                .padding(.trailing, 16)
                .accessibilityHint(AppStrings.TMDBMatchPicker.searchAccessibilityLabel)
            }
        }
    }
}

// MARK: - iOS View

#if !os(tvOS)
    public struct VODDetailView_iOS: View {
        let store: StoreOf<VODDetailFeature>

        public init(store: StoreOf<VODDetailFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack(alignment: .top) {
                Color(hex: "#0F0F13").ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        headerView

                        if store.availableVersions.count > 1 {
                            MovieVersionPickerView(
                                versions: store.availableVersions,
                                selectedVersionId: store.selectedVersionId ?? store.vod.id,
                                onSelectVersion: { version in
                                    store.send(.selectVersion(version))
                                }
                            )
                            .padding(.top, 14)
                        }

                        contentView
                    }
                }
                .id(store.vod.id)
                .sheet(isPresented: Binding(
                    get: { store.selectedUnmatchedMovie != nil },
                    set: {
                        if !$0 {
                            store.send(.dismissUnmatchedMovie)
                        }
                    }
                )) {
                    if let item = store.selectedUnmatchedMovie {
                        unmatchedMovieSheet(item: item)
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.isTrailerPresented },
                set: {
                    if !$0 {
                        store.send(.dismissTrailer)
                    }
                }
            )) {
                if let key = store.trailerVideoKey, let title = store.trailerTitle {
                    trailerPlayerSheet(videoKey: key, title: title)
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { store.selectedActor != nil },
                set: {
                    if !$0 {
                        store.send(.dismissActorDetails)
                    }
                }
            )) {
                if let actor = store.selectedActor {
                    actorBiographySheet(actor: actor)
                }
            }
        }

        // MARK: - Header & Cinematic Backdrop

        private var headerView: some View {
            VStack(spacing: 0) {
                // Edge-to-edge Cinematic Backdrop / Auto-Play Trailer (Madde #46)
                let backdropURLString = store.tmdbMovie?.backdropPath.map { "https://image.tmdb.org/t/p/w1280\($0)" } ??
                    store.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                    store.vod.coverURL?.absoluteString
                let backdropURL = backdropURLString.flatMap { URL(string: $0) }

                ZStack(alignment: .topTrailing) {
                    InlineTrailerHeroView(
                        backdropURL: backdropURL,
                        userAgentOverride: store.config.userAgentOverride,
                        trailerKey: store.resolvedTrailerKey,
                        isAutoPlayActive: store.isAutoPlayTrailerActive,
                        isMuted: store.isTrailerMuted,
                        onToggleMute: {
                            store.send(.toggleTrailerMute)
                        },
                        onExpandTrailer: {
                            store.send(.expandTrailer)
                        },
                        onOpenTrailerSheet: {
                            store.send(.trailerTapped)
                        }
                    )

                    // Quality Badges at Top Trailing
                    HStack {
                        Spacer()
                        HStack(spacing: 6) {
                            badgeCapsule(title: AppStrings.VODDetail.uhdQualityBadge, color: .cyan)
                            badgeCapsule(title: AppStrings.VODDetail.hdrBadge, color: .purple)
                            badgeCapsule(title: AppStrings.VODDetail.audio51Badge, color: .white)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                    }
                    .frame(maxHeight: .infinity, alignment: .topTrailing)
                }
                .frame(height: 260)

                // Poster & Metadata Overlap Section
                HStack(alignment: .top, spacing: 18) {
                    // High-res Floating Poster
                    let posterURLString = store.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" } ??
                        store.vod.coverURL?.absoluteString

                    if let urlString = posterURLString, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            case .empty:
                                Rectangle().fill(Color(hex: "#2A2A30")).shimmeringPlaceholder(isLoading: true)
                            case .failure:
                                Rectangle().fill(Color(hex: "#2A2A30"))
                            @unknown default:
                                Rectangle().fill(Color(hex: "#2A2A30"))
                            }
                        }
                        .frame(width: 125, height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                        )
                        .shadow(color: .black.opacity(0.7), radius: 14, x: 0, y: 8)
                        .offset(y: -50)
                        .padding(.bottom, -50)
                    }

                    // Metadata & Action Buttons
                    VStack(alignment: .leading, spacing: 10) {
                        Text(store.tmdbMovie?.title ?? store.vod.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)

                        // Rating & Tag row
                        HStack(spacing: 8) {
                            if let rating = store.tmdbMovie?.voteAverage ?? store.info?.rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.yellow)
                                    Text(String(format: "%.1f", rating))
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                    Text(AppStrings.VODDetail.imdbRating)
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(Color.yellow.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))
                                        .foregroundStyle(.yellow)
                                }
                            }

                            if let date = store.tmdbMovie?.releaseDate ?? store.info?.releaseDate {
                                Text(String(date.prefix(4)))
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }

                            if let runtime = store.tmdbMovie?.runtime, runtime > 0 {
                                Text("\(runtime / 60)s \(runtime % 60)dk")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 20)
                .padding(.top, -10)

                // Primary & Secondary Action Section (Zero-Friction "Don't Make Me Think")
                actionSection
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
            }
        }

        private func badgeCapsule(title: String, color: Color) -> some View {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .padding(.horizontal, 7)
                .padding(.vertical, 3.5)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.8))
        }

        // MARK: - Action Section (Zero-Friction "Don't Make Me Think")

        private var actionSection: some View {
            VStack(spacing: 12) {
                // 1. Primary Full-Width CTA
                if let history = store.historyItem, history.duration > 0 {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.resumeTapped)
                    } label: {
                        HStack(spacing: 10) {
                            CircularProgressRing(
                                progress: WatchProgressFormatter.progressRatio(progress: history.progress, duration: history.duration),
                                lineWidth: 2.5,
                                size: 22,
                                gradientColors: [Color(hex: "#00F5D4"), Color(hex: "#FFFFFF")],
                                trackColor: Color.white.opacity(0.3)
                            ) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                            Text(AppStrings.VODDetail.continueWatching)
                                .font(.system(size: 16, weight: .semibold))

                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                            Text("%\(percent)")
                                .font(.system(size: 12, weight: .bold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Color.white.opacity(0.2), in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#0055B3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#0A84FF").opacity(0.35), radius: 8, y: 3)
                    }
                } else {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.playTapped)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 16, weight: .bold))
                            Text(AppStrings.Common.watchNow)
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), Color(hex: "#0055B3")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: Color(hex: "#0A84FF").opacity(0.35), radius: 8, y: 3)
                    }
                }

                // 2. Secondary Symmetrical Action Row (Zero-Scroll Above-the-Fold)
                HStack(spacing: 8) {
                    if let history = store.historyItem, history.duration > 0 {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.restartTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.VODDetail.restart)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                            .foregroundStyle(.white)
                        }
                        if history.progress / history.duration >= 0.90 {
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.markUnwatched)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "eye.slash")
                                        .font(.system(size: 16, weight: .medium))
                                    Text(AppStrings.SeriesDetail.unwatched)
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                                .foregroundStyle(.white)
                            }
                        }
                    }

                    if store.resolvedTrailerKey != nil {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.trailerTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "film.fill")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.VODDetail.trailer)
                                    .font(.system(size: 10, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 0.8))
                            .foregroundStyle(.white)
                        }
                    }

                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.toggleFavorite)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(store.isFavorite ? Color.red : Color.white)
                            Text(store.isFavorite ? AppStrings.Common.favorited : AppStrings.Common.favorite)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(store.isFavorite ? Color.red : Color.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            store.isFavorite ? Color.red.opacity(0.15) : Color.white.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(store.isFavorite ? Color.red.opacity(0.3) : Color.white.opacity(0.15), lineWidth: 0.8))
                    }

                    #if os(iOS)
                        if store.config.type != .plex, store.config.type != .emby {
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.downloadTapped)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: store.isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(store.isDownloaded ? Color.green : Color.white)
                                    Text(store.isDownloaded ? AppStrings.Common.downloaded : AppStrings.Common.download)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(store.isDownloaded ? Color.green : Color.white)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(
                                    store.isDownloaded ? Color.green.opacity(0.15) : Color.white.opacity(0.08),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                )
                                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(store.isDownloaded ? Color.green.opacity(0.3) : Color.white.opacity(0.15), lineWidth: 0.8))
                            }
                        }
                    #endif
                }
                #if os(iOS)
                    if let downloadErrorMessage = store.downloadErrorMessage {
                        Text(downloadErrorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                #endif
            }
        }

        // MARK: - Content View

        private var contentView: some View {
            VStack(alignment: .leading, spacing: 22) {
                // Genres
                let genres = store.tmdbMovie?.genres?.map(\.name) ?? store.info?.genre?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                if !genres.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(genres, id: \.self) { genre in
                                Text(genre)
                                    .font(.system(size: 13, weight: .medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .foregroundStyle(Color.white.opacity(0.85))
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }

                // Overview
                let plot = store.tmdbMovie?.overview ?? store.info?.plot
                if let plotText = plot, !plotText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStrings.VODDetail.overview)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        Text(plotText)
                            .font(.system(size: 14.5))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .lineSpacing(4)
                    }
                    .padding(.horizontal, 24)
                } else if store.isTMDBLoading || store.isLoading {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStrings.VODDetail.overview)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.12)).frame(width: 220, height: 14)
                        }
                        .shimmeringPlaceholder(isLoading: true)
                    }
                    .padding(.horizontal, 24)
                }

                if !store.awardRecognitions.isEmpty {
                    AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                        .padding(.horizontal, 24)
                }

                // Oyuncu Kadrosu (Cast & Crew Carousel)
                if let cast = store.tmdbMovie?.credits?.cast, !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(AppStrings.VODDetail.castCrew)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)

                            Spacer()

                            Text("\(cast.count)")
                                .font(.caption.bold())
                                .foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(cast.prefix(20), id: \.id) { actor in
                                    Button {
                                        HapticManager.shared.trigger(.light)
                                        store.send(.actorTapped(actor))
                                    } label: {
                                        VStack(spacing: 7) {
                                            // Avatar
                                            let avatarURL = actor.profilePath.map { "https://image.tmdb.org/t/p/w185\($0)" }
                                            if let urlString = avatarURL, let url = URL(string: urlString) {
                                                AsyncImage(url: url) { phase in
                                                    switch phase {
                                                    case let .success(img):
                                                        img.resizable().scaledToFill()
                                                    default:
                                                        actorAvatarFallback(name: actor.name)
                                                    }
                                                }
                                                .frame(width: 70, height: 70)
                                                .clipShape(Circle())
                                                .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.2))
                                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                                            } else {
                                                actorAvatarFallback(name: actor.name)
                                                    .frame(width: 70, height: 70)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(Color.white.opacity(0.15), lineWidth: 1.2))
                                            }

                                            // Real Name
                                            Text(actor.name ?? "")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(1)
                                                .frame(width: 82)

                                            // Character Name
                                            if let char = actor.character, !char.isEmpty {
                                                Text(char)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(Color.white.opacity(0.55))
                                                    .lineLimit(1)
                                                    .frame(width: 82)
                                            }
                                        }
                                    }
                                    .buttonStyle(FluidScaleButtonStyle())
                                }
                            }
                        }
                    }
                } else if store.isTMDBLoading {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStrings.VODDetail.castCrew)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(0 ..< 5, id: \.self) { _ in
                                    VStack(spacing: 7) {
                                        Circle()
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 70, height: 70)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.12))
                                            .frame(width: 60, height: 10)
                                    }
                                    .shimmeringPlaceholder(isLoading: true)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                // Production Countries
                if let countries = store.tmdbMovie?.productionCountries, !countries.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(AppStrings.VODDetail.productionCountries)
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(.white)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(countries, id: \.iso3166_1) { country in
                                    Text(country.name)
                                        .font(.system(size: 12))
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Color(hex: "#163450"))
                                        .foregroundStyle(Color(hex: "#66B2FF"))
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                    .padding(.horizontal, 24)
                }

                // IMDb Web Link Button
                if let imdbId = store.tmdbMovie?.imdbId {
                    Button {
                        if let url = URL(string: "https://www.imdb.com/title/\(imdbId)") {
                            #if os(iOS)
                                UIApplication.shared.open(url)
                            #endif
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.up.right.square")
                            Text(AppStrings.VODDetail.viewOnIMDb)
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(Color(hex: "#1A1A24"))
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    }
                    .buttonStyle(FluidScaleButtonStyle())
                    .padding(.horizontal, 24)
                }

                // Similar Movies
                if let similar = store.tmdbMovie?.similar?.results, !similar.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 8) {
                            Text(AppStrings.VODDetail.similarMovies)
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(.white)

                            if !store.matchedVODsByTMDBId.isEmpty {
                                Text("\(store.matchedVODsByTMDBId.count) \(AppStrings.VODDetail.inLibrary)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color(hex: "#00F5D4"))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color(hex: "#00F5D4").opacity(0.15), in: Capsule())
                            }
                        }
                        .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(similar, id: \.id) { item in
                                    let isMatched = store.matchedVODsByTMDBId[item.id] != nil
                                    Button {
                                        HapticManager.shared.trigger(.light)
                                        store.send(.similarMovieTapped(item))
                                    } label: {
                                        VStack(alignment: .leading, spacing: 6) {
                                            ZStack(alignment: .topTrailing) {
                                                let cover = item.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" }
                                                if let urlString = cover, let url = URL(string: urlString) {
                                                    AsyncImage(url: url) { phase in
                                                        switch phase {
                                                        case let .success(image):
                                                            image.resizable().scaledToFill()
                                                        default:
                                                            Rectangle().fill(Color(hex: "#2A2A30"))
                                                        }
                                                    }
                                                    .frame(width: 110, height: 165)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(isMatched ? Color(hex: "#00F5D4").opacity(0.6) : Color.white.opacity(0.12), lineWidth: isMatched ? 1.5 : 0.8)
                                                    )
                                                    .shadow(color: isMatched ? Color(hex: "#00F5D4").opacity(0.2) : .black.opacity(0.4), radius: 8, y: 4)
                                                } else {
                                                    Rectangle()
                                                        .fill(Color(hex: "#2A2A30"))
                                                        .frame(width: 110, height: 165)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                }

                                                // Top Badge: "Kütüphanenizde" if matched, or IMDb rating
                                                if isMatched {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "checkmark.circle.fill")
                                                            .font(.system(size: 8, weight: .bold))
                                                        Text(AppStrings.VODDetail.inLibrary)
                                                            .font(.system(size: 7.5, weight: .heavy))
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3.5)
                                                    .background(
                                                        LinearGradient(
                                                            colors: [Color(hex: "#00F5D4"), Color(hex: "#00BB99")],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        in: Capsule()
                                                    )
                                                    .foregroundStyle(.black)
                                                    .shadow(color: Color(hex: "#00F5D4").opacity(0.5), radius: 4)
                                                    .padding(6)
                                                } else if let vote = item.voteAverage, vote > 0 {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "star.fill")
                                                            .font(.system(size: 7))
                                                            .foregroundStyle(.yellow)
                                                        Text(String(format: "%.1f", vote))
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2.5)
                                                    .background(.ultraThinMaterial, in: Capsule())
                                                    .overlay(Capsule().stroke(Color.white.opacity(0.25), lineWidth: 0.5))
                                                    .padding(6)
                                                }
                                            }

                                            Text(item.title ?? item.name ?? "")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(.white)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .frame(width: 110, alignment: .leading)

                                            if let date = item.releaseDate ?? item.firstAirDate, !date.isEmpty {
                                                Text(String(date.prefix(4)))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(.white.opacity(0.6))
                                            }
                                        }
                                    }
                                    .buttonStyle(FluidScaleButtonStyle())
                                }
                            }
                        }
                    }
                } else if store.isTMDBLoading {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStrings.VODDetail.similarMovies)
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0 ..< 4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.12))
                                        .frame(width: 110, height: 165)
                                        .shimmeringPlaceholder(isLoading: true)
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(.top, 16)
        }

        // MARK: - Actor Avatar Fallback

        private func actorAvatarFallback(name: String?) -> some View {
            ZStack {
                LinearGradient(
                    colors: [Color(hex: "#1E293B"), Color(hex: "#0F172A")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let firstLetter = name?.first {
                    Text(String(firstLetter).uppercased())
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.white.opacity(0.4))
                }
            }
        }

        // MARK: - Actor Biography Sheet

        private func actorBiographySheet(actor: TMDBCastMemberDTO) -> some View {
            NavigationStack {
                ZStack {
                    Color(hex: "#0D0D12").ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Header Profile
                            HStack(spacing: 18) {
                                let avatarURL = (store.selectedActorDetails?.profilePath ?? actor.profilePath).map { "https://image.tmdb.org/t/p/w300\($0)" }
                                if let urlString = avatarURL, let url = URL(string: urlString) {
                                    AsyncImage(url: url) { phase in
                                        switch phase {
                                        case let .success(img):
                                            img.resizable().scaledToFill()
                                        default:
                                            actorAvatarFallback(name: actor.name)
                                        }
                                    }
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                                    .shadow(color: .black.opacity(0.6), radius: 10, y: 5)
                                } else {
                                    actorAvatarFallback(name: actor.name)
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(actor.name ?? "")
                                        .font(.title2.bold())
                                        .foregroundColor(.white)

                                    if let char = actor.character, !char.isEmpty {
                                        Text("\(AppStrings.VODDetail.character): \(char)")
                                            .font(.subheadline)
                                            .foregroundColor(Color(hex: "#66B2FF"))
                                    }

                                    if let department = store.selectedActorDetails?.knownForDepartment {
                                        Text(department)
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                            // Personal Details Chips
                            if let details = store.selectedActorDetails {
                                HStack(spacing: 10) {
                                    if let bday = details.birthday, !bday.isEmpty {
                                        HStack(spacing: 5) {
                                            Image(systemName: "calendar")
                                                .foregroundColor(.cyan)
                                            Text(bday)
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.08), in: Capsule())
                                    }

                                    if let pob = details.placeOfBirth, !pob.isEmpty {
                                        HStack(spacing: 5) {
                                            Image(systemName: "mappin.and.ellipse")
                                                .foregroundColor(.red)
                                            Text(pob)
                                                .lineLimit(1)
                                        }
                                        .font(.caption.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.white.opacity(0.08), in: Capsule())
                                    }
                                }
                                .padding(.horizontal, 24)
                            }

                            Divider().background(Color.white.opacity(0.12)).padding(.horizontal, 24)

                            // Biography Text
                            VStack(alignment: .leading, spacing: 10) {
                                Text(AppStrings.VODDetail.biography)
                                    .font(.headline.bold())
                                    .foregroundColor(.white)

                                if store.isLoadingActorDetails {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)).frame(height: 14)
                                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)).frame(height: 14)
                                        RoundedRectangle(cornerRadius: 4).fill(Color.white.opacity(0.1)).frame(width: 200, height: 14)
                                    }
                                    .shimmeringPlaceholder(isLoading: true)
                                } else if let bio = store.selectedActorDetails?.biography, !bio.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(bio)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.85))
                                        .lineSpacing(5)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text(AppStrings.VODDetail.noBiography)
                                        .font(.subheadline)
                                        .foregroundColor(.white.opacity(0.5))
                                        .italic()
                                }
                            }
                            .padding(.horizontal, 24)

                            Spacer().frame(height: 32)
                        }
                    }
                }
                .navigationTitle(actor.name ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.close) {
                            HapticManager.shared.trigger(.light)
                            store.send(.dismissActorDetails)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }

        // MARK: - In-App Trailer Player Sheet

        private func trailerPlayerSheet(videoKey: String, title: String) -> some View {
            NavigationStack {
                ZStack {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 20) {
                        // 16:9 Video Player Frame
                        #if os(iOS)
                            TrailerPlaybackView(videoKey: videoKey)
                                .aspectRatio(16 / 9, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                )
                                .shadow(color: .black.opacity(0.8), radius: 16, y: 8)
                                .padding(.horizontal, 16)
                        #else
                            Text(title)
                                .foregroundColor(.white)
                        #endif

                        // Direct "Filmi Şimdi Başlat" Action Button
                        Button {
                            HapticManager.shared.trigger(.medium)
                            store.send(.dismissTrailer)
                            store.send(.playTapped)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                Text(AppStrings.VODDetail.startMovieNow)
                                    .fontWeight(.bold)
                            }
                            .font(.system(size: 16))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(hex: "#0A84FF"), Color(hex: "#0066CC")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color(hex: "#0A84FF").opacity(0.4), radius: 8, y: 3)
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 12)

                        Spacer()
                    }
                    .padding(.top, 20)
                }
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.close) {
                            HapticManager.shared.trigger(.light)
                            store.send(.dismissTrailer)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }

        // MARK: - Unmatched Similar Movie Synopsis Sheet

        private func unmatchedMovieSheet(item: TMDBSimilarItemDTO) -> some View {
            NavigationStack {
                ZStack {
                    Color(hex: "#0F0F13").ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            // Backdrop Header
                            let backdropURL = item.backdropPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                                item.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
                            if let urlString = backdropURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case let .success(img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Rectangle().fill(Color(hex: "#1E1E24"))
                                    }
                                }
                                .frame(height: 180)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [Color.clear, Color(hex: "#0F0F13")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                Text(item.title ?? item.name ?? "")
                                    .font(.title2.bold())
                                    .foregroundStyle(.white)

                                HStack(spacing: 12) {
                                    if let vote = item.voteAverage, vote > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(.yellow)
                                            Text(String(format: "%.1f", vote))
                                                .font(.system(size: 13, weight: .bold))
                                                .foregroundStyle(.white)
                                            Text(AppStrings.VODDetail.imdbRating)
                                                .font(.system(size: 8, weight: .heavy))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1.5)
                                                .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                                                .foregroundStyle(.yellow)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: Capsule())
                                    }

                                    if let date = item.releaseDate ?? item.firstAirDate, !date.isEmpty {
                                        Text(String(date.prefix(4)))
                                            .font(.subheadline)
                                            .foregroundStyle(.white.opacity(0.7))
                                    }
                                }

                                // Not in Library Alert Capsule
                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(AppStrings.VODDetail.notInLibrary)
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.orange)
                                        Text(AppStrings.VODDetail.notInLibraryDesc)
                                            .font(.system(size: 11))
                                            .foregroundStyle(.white.opacity(0.8))
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.orange.opacity(0.25), lineWidth: 1)
                                )

                                if let plot = item.overview, !plot.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(AppStrings.VODDetail.overview)
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundStyle(.white)

                                        Text(plot)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.white.opacity(0.8))
                                            .lineSpacing(4)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                            .padding(.horizontal, 20)

                            Spacer().frame(height: 24)
                        }
                    }
                }
                .navigationTitle(item.title ?? item.name ?? "")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.close) {
                            HapticManager.shared.trigger(.light)
                            store.send(.dismissUnmatchedMovie)
                        }
                        .foregroundColor(.white)
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    }
#endif

// MARK: - tvOS View

#if os(tvOS)
    public struct VODDetailView_tvOS: View {
        @Bindable var store: StoreOf<VODDetailFeature>
        let onPresentSynopsis: (String) -> Void
        @FocusState private var isPlayButtonFocused: Bool

        public init(
            store: StoreOf<VODDetailFeature>,
            onPresentSynopsis: @escaping (String) -> Void = { _ in }
        ) {
            self.store = store
            self.onPresentSynopsis = onPresentSynopsis
        }

        public var body: some View {
            ZStack(alignment: .leading) {
                // Background
                GeometryReader { proxy in
                    let cover = store.tmdbMovie?.backdropPath.map { "https://image.tmdb.org/t/p/w1280\($0)" } ??
                        store.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                        store.vod.coverURL?.absoluteString

                    if let urlString = cover, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "#0F0F13"))
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [Color(hex: "#0F0F13"), Color(hex: "#0F0F13").opacity(0.8), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            LinearGradient(
                                colors: [Color(hex: "#0F0F13"), Color.clear],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                    }
                }
                .ignoresSafeArea()

                ScrollView(.vertical) {
                    HStack(spacing: 80) {
                        // Info Section
                        VStack(alignment: .leading, spacing: 28) {
                            Text(store.tmdbMovie?.title ?? store.vod.title)
                                .font(.system(size: 58, weight: .bold))
                                .foregroundStyle(.white)
                                .lineLimit(2)

                            // Metadata
                            HStack(spacing: 20) {
                                if let vote = store.tmdbMovie?.voteAverage, vote > 0 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(.yellow)
                                        Text(String(format: "%.1f", vote))
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.white)
                                        Text(AppStrings.VODDetail.imdbRating)
                                            .font(.caption.bold())
                                            .foregroundColor(.yellow)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.yellow.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }

                                if let releaseDate = store.tmdbMovie?.releaseDate {
                                    let year = String(releaseDate.prefix(4))
                                    Text(year)
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                if let duration = store.tmdbMovie?.runtime, duration > 0 {
                                    Text("\(duration) \(AppStrings.Common.minAbbr)")
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.7))
                                } else if let dur = store.vod.duration, !dur.isEmpty {
                                    Text(dur)
                                        .font(.title3)
                                        .foregroundStyle(.white.opacity(0.7))
                                }

                                Text(AppStrings.VODDetail.uhdQualityBadge)
                                    .font(.caption.bold())
                                    .foregroundColor(.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.cyan.opacity(0.2), in: Capsule())
                            }

                            // Plot
                            if let plot = store.tmdbMovie?.overview ?? store.info?.plot, !plot.isEmpty {
                                ExpandableSynopsisView(
                                    text: plot,
                                    font: .system(size: 22),
                                    lineLimit: 4,
                                    onPresent: { onPresentSynopsis(plot) }
                                )
                            } else if store.isTMDBLoading || store.isLoading {
                                VStack(alignment: .leading, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)).frame(height: 22)
                                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)).frame(height: 22)
                                    RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.12)).frame(width: 400, height: 22)
                                }
                                .shimmeringPlaceholder(isLoading: true)
                            }

                            if !store.awardRecognitions.isEmpty {
                                AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                                    .padding(.top, 8)
                            }

                            if store.availableVersions.count > 1 {
                                MovieVersionPickerView(
                                    versions: store.availableVersions,
                                    selectedVersionId: store.selectedVersionId ?? store.vod.id,
                                    onSelectVersion: { version in
                                        store.send(.selectVersion(version))
                                    }
                                )
                                .padding(.top, 8)
                            }

                            // Actions
                            HStack(spacing: 24) {
                                if let history = store.historyItem, history.duration > 0 {
                                    Button {
                                        store.send(.resumeTapped)
                                    } label: {
                                        HStack(spacing: 12) {
                                            CircularProgressRing(
                                                progress: WatchProgressFormatter.progressRatio(progress: history.progress, duration: history.duration),
                                                lineWidth: 3.5,
                                                size: 26,
                                                gradientColors: [Color(hex: "#00F5D4"), Color(hex: "#FFFFFF")],
                                                trackColor: Color.white.opacity(0.3)
                                            ) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(.white)
                                            }

                                            Text(AppStrings.VODDetail.continueWatching)
                                                .fontWeight(.bold)

                                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                                            Text("%\(percent)")
                                                .font(.system(size: 14, weight: .bold))
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.white.opacity(0.2), in: Capsule())
                                        }
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                    }
                                    .focused($isPlayButtonFocused)

                                    Button {
                                        store.send(.restartTapped)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "arrow.counterclockwise")
                                            Text(AppStrings.VODDetail.restart)
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 16)
                                    }
                                    if history.progress / history.duration >= 0.90 {
                                        Button {
                                            store.send(.markUnwatched)
                                        } label: {
                                            Label(AppStrings.SeriesDetail.unwatched, systemImage: "eye.slash")
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 16)
                                        }
                                    }
                                } else {
                                    Button {
                                        store.send(.playTapped)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "play.fill")
                                            Text(AppStrings.Common.watchNow)
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                    }
                                    .focused($isPlayButtonFocused)
                                }

                                // Fragman on tvOS
                                if store.resolvedTrailerKey != nil {
                                    Button {
                                        store.send(.trailerTapped)
                                    } label: {
                                        HStack(spacing: 12) {
                                            Image(systemName: "film.fill")
                                            Text(AppStrings.VODDetail.trailer)
                                                .fontWeight(.bold)
                                        }
                                        .padding(.horizontal, 28)
                                        .padding(.vertical, 16)
                                    }
                                }

                                Button {
                                    store.send(.toggleFavorite)
                                } label: {
                                    Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                        .foregroundColor(store.isFavorite ? .red : .white)
                                        .padding()
                                }
                            }

                            // Cast Row on tvOS
                            if let cast = store.tmdbMovie?.credits?.cast, !cast.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(AppStrings.VODDetail.castCrew)
                                        .font(.title3.bold())
                                        .foregroundStyle(.white)

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 20) {
                                            ForEach(cast.prefix(12), id: \.id) { actor in
                                                Button {
                                                    store.send(.actorTapped(actor))
                                                } label: {
                                                    VStack(spacing: 8) {
                                                        let avatarURL = actor.profilePath.map { "https://image.tmdb.org/t/p/w185\($0)" }
                                                        if let urlString = avatarURL, let url = URL(string: urlString) {
                                                            AsyncImage(url: url) { phase in
                                                                switch phase {
                                                                case let .success(img):
                                                                    img.resizable().scaledToFill()
                                                                default:
                                                                    Rectangle().fill(Color(hex: "#2A2A30"))
                                                                }
                                                            }
                                                            .frame(width: 80, height: 80)
                                                            .clipShape(Circle())
                                                        } else {
                                                            Rectangle()
                                                                .fill(Color(hex: "#2A2A30"))
                                                                .frame(width: 80, height: 80)
                                                                .clipShape(Circle())
                                                        }

                                                        Text(actor.name ?? "")
                                                            .font(.caption.bold())
                                                            .foregroundStyle(.white)
                                                            .lineLimit(1)
                                                            .frame(width: 100)

                                                        if let char = actor.character {
                                                            Text(char)
                                                                .font(.system(size: 10))
                                                                .foregroundStyle(.white.opacity(0.6))
                                                                .lineLimit(1)
                                                                .frame(width: 100)
                                                        }
                                                    }
                                                    .padding(6)
                                                }
                                                .buttonStyle(.card)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 12)
                            }

                            // Similar Movies on tvOS
                            if let similar = store.tmdbMovie?.similar?.results, !similar.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 12) {
                                        Text(AppStrings.VODDetail.similarMovies)
                                            .font(.title3.bold())
                                            .foregroundStyle(.white)

                                        if !store.matchedVODsByTMDBId.isEmpty {
                                            Text("\(store.matchedVODsByTMDBId.count) \(AppStrings.VODDetail.inLibrary)")
                                                .font(.caption.bold())
                                                .foregroundStyle(Color(hex: "#00F5D4"))
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(Color(hex: "#00F5D4").opacity(0.18), in: Capsule())
                                        }
                                    }

                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 24) {
                                            ForEach(similar.prefix(12), id: \.id) { item in
                                                let isMatched = store.matchedVODsByTMDBId[item.id] != nil
                                                Button {
                                                    store.send(.similarMovieTapped(item))
                                                } label: {
                                                    VStack(alignment: .leading, spacing: 10) {
                                                        ZStack(alignment: .topTrailing) {
                                                            let cover = item.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" }
                                                            if let urlString = cover, let url = URL(string: urlString) {
                                                                AsyncImage(url: url) { phase in
                                                                    switch phase {
                                                                    case let .success(img):
                                                                        img.resizable().scaledToFill()
                                                                    default:
                                                                        Rectangle().fill(Color(hex: "#2A2A30"))
                                                                    }
                                                                }
                                                                .frame(width: 140, height: 210)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                            } else {
                                                                Rectangle()
                                                                    .fill(Color(hex: "#2A2A30"))
                                                                    .frame(width: 140, height: 210)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                            }

                                                            if isMatched {
                                                                Text(AppStrings.VODDetail.inLibrary)
                                                                    .font(.system(size: 10, weight: .heavy))
                                                                    .foregroundStyle(.black)
                                                                    .padding(.horizontal, 8)
                                                                    .padding(.vertical, 4)
                                                                    .background(Color(hex: "#00F5D4"), in: Capsule())
                                                                    .padding(8)
                                                            } else if let vote = item.voteAverage, vote > 0 {
                                                                HStack(spacing: 3) {
                                                                    Image(systemName: "star.fill")
                                                                        .font(.system(size: 9))
                                                                        .foregroundStyle(.yellow)
                                                                    Text(String(format: "%.1f", vote))
                                                                        .font(.system(size: 10, weight: .bold))
                                                                        .foregroundStyle(.white)
                                                                }
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 3)
                                                                .background(.ultraThinMaterial, in: Capsule())
                                                                .padding(8)
                                                            }
                                                        }

                                                        Text(item.title ?? item.name ?? "")
                                                            .font(.caption.bold())
                                                            .foregroundStyle(.white)
                                                            .lineLimit(1)
                                                            .frame(width: 140, alignment: .leading)
                                                    }
                                                    .padding(6)
                                                }
                                                .buttonStyle(.card)
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 16)
                            }

                            Spacer().frame(height: 60)
                        }
                        .frame(maxWidth: 880, alignment: .leading)
                        .padding(.leading, 100)
                        .padding(.top, 100)

                        Spacer()
                    }
                }
                .id(store.vod.id)
            }
            .onAppear {
                store.send(.onAppear)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    isPlayButtonFocused = true
                }
            }
            .sheet(isPresented: Binding(
                get: { store.selectedActor != nil },
                set: {
                    if !$0 {
                        store.send(.dismissActorDetails)
                    }
                }
            )) {
                if let actor = store.selectedActor {
                    tvOSActorBioSheet(actor: actor)
                }
            }
            .sheet(isPresented: Binding(
                get: { store.isTrailerPresented },
                set: {
                    if !$0 {
                        store.send(.dismissTrailer)
                    }
                }
            )) {
                if let title = store.trailerTitle {
                    tvOSTrailerSheet(title: title)
                }
            }
            .sheet(isPresented: Binding(
                get: { store.selectedUnmatchedMovie != nil },
                set: {
                    if !$0 {
                        store.send(.dismissUnmatchedMovie)
                    }
                }
            )) {
                if let item = store.selectedUnmatchedMovie {
                    tvOSUnmatchedMovieSheet(item: item)
                }
            }
            .onExitCommand {
                store.send(.closeTapped)
            }
        }

        private func tvOSTrailerSheet(title: String) -> some View {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

                VStack(spacing: 30) {
                    Text(title)
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)

                    Text(AppStrings.VODDetail.watchTrailer)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.7))

                    Button {
                        store.send(.dismissTrailer)
                        store.send(.playTapped)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                            Text(AppStrings.VODDetail.startMovieNow)
                                .fontWeight(.bold)
                        }
                        .padding(.horizontal, 36)
                        .padding(.vertical, 18)
                    }
                    .buttonStyle(.card)

                    Button(AppStrings.Common.close) {
                        store.send(.dismissTrailer)
                    }
                    .buttonStyle(.card)
                }
                .padding(60)
            }
        }

        private func tvOSActorBioSheet(actor: TMDBCastMemberDTO) -> some View {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

                HStack(spacing: 40) {
                    let avatarURL = (store.selectedActorDetails?.profilePath ?? actor.profilePath).map { "https://image.tmdb.org/t/p/w500\($0)" }
                    if let urlString = avatarURL, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(img):
                                img.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "#1E293B"))
                            }
                        }
                        .frame(width: 240, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text(actor.name ?? "")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        if let char = actor.character, !char.isEmpty {
                            Text("\(AppStrings.VODDetail.character): \(char)")
                                .font(.title3)
                                .foregroundColor(Color(hex: "#66B2FF"))
                        }

                        if let bday = store.selectedActorDetails?.birthday {
                            Text("\(AppStrings.VODDetail.born): \(bday)")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        if let pob = store.selectedActorDetails?.placeOfBirth {
                            Text("\(AppStrings.VODDetail.birthplace): \(pob)")
                                .font(.headline)
                                .foregroundColor(.white.opacity(0.7))
                        }

                        if let bio = store.selectedActorDetails?.biography, !bio.isEmpty {
                            Text(bio)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(8)
                        } else {
                            Text(AppStrings.VODDetail.noBiography)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.5))
                                .italic()
                        }

                        Button(AppStrings.Common.close) {
                            store.send(.dismissActorDetails)
                        }
                        .buttonStyle(.card)
                        .padding(.top, 16)
                    }
                    .frame(maxWidth: 600, alignment: .leading)
                }
                .padding(60)
            }
        }

        private func tvOSUnmatchedMovieSheet(item: TMDBSimilarItemDTO) -> some View {
            ZStack {
                Color(hex: "#0F0F13").ignoresSafeArea()

                HStack(spacing: 40) {
                    let cover = item.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
                    if let urlString = cover, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case let .success(img):
                                img.resizable().scaledToFill()
                            default:
                                Rectangle().fill(Color(hex: "#1E293B"))
                            }
                        }
                        .frame(width: 240, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.2), lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Text(item.title ?? item.name ?? "")
                            .font(.largeTitle.bold())
                            .foregroundColor(.white)

                        HStack(spacing: 16) {
                            if let vote = item.voteAverage, vote > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill")
                                        .foregroundColor(.yellow)
                                    Text(String(format: "%.1f", vote))
                                        .font(.title3.bold())
                                        .foregroundColor(.white)
                                }
                            }

                            if let date = item.releaseDate ?? item.firstAirDate, !date.isEmpty {
                                Text(String(date.prefix(4)))
                                    .font(.title3)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(.title3)
                                .foregroundColor(.orange)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppStrings.VODDetail.notInLibrary)
                                    .font(.headline.bold())
                                    .foregroundColor(.orange)
                                Text(AppStrings.VODDetail.notInLibraryDesc)
                                    .font(.subheadline)
                                    .foregroundColor(.white.opacity(0.75))
                            }
                        }
                        .padding(16)
                        .background(Color.orange.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                        if let plot = item.overview, !plot.isEmpty {
                            Text(plot)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.85))
                                .lineLimit(6)
                        }

                        Button(AppStrings.Common.close) {
                            store.send(.dismissUnmatchedMovie)
                        }
                        .buttonStyle(.card)
                        .padding(.top, 16)
                    }
                    .frame(maxWidth: 600, alignment: .leading)
                }
                .padding(60)
            }
        }
    }
#endif
