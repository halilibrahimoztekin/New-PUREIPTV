#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

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
                        store.vod.presentationOverride?.posterURL?.absoluteString ??
                        store.tmdbMovie?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                        store.vod.coverURL?.absoluteString

                    if let urlString = cover, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(AppColors.surfaceDark)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .overlay(
                            LinearGradient(
                                colors: [AppColors.surfaceDark, AppColors.surfaceDark.opacity(0.8), Color.clear],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .overlay(
                            LinearGradient(
                                colors: [AppColors.surfaceDark, Color.clear],
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
                            Text(store.vod.presentationOverride?.title ?? store.tmdbMovie?.title ?? store.vod.title)
                                .font(.system(size: 58, weight: .bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(2)

                            // Metadata
                            HStack(spacing: 20) {
                                if let vote = store.tmdbMovie?.voteAverage, vote > 0 {
                                    HStack(spacing: 8) {
                                        Image(systemName: "star.fill")
                                            .foregroundColor(AppColors.warningGold)
                                        Text(String(format: "%.1f", vote))
                                            .font(AppFonts.title)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(AppColors.textPrimary)
                                        Text(AppStrings.VODDetail.imdbRating)
                                            .font(AppFonts.caption.bold())
                                            .foregroundColor(AppColors.warningGold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppColors.warningGold.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
                                    }
                                }

                                if let year = store.vod.presentationOverride?.year {
                                    Text(String(year))
                                        .font(AppFonts.title)
                                        .foregroundStyle(AppColors.textSecondary)
                                } else if let releaseDate = store.tmdbMovie?.releaseDate ?? store.info?.releaseDate ?? store.vod.releaseDate, !releaseDate.isEmpty {
                                    let year = String(releaseDate.prefix(4))
                                    Text(year)
                                        .font(AppFonts.title)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                if let duration = store.tmdbMovie?.runtime, duration > 0 {
                                    Text("\(duration) \(AppStrings.Common.minAbbr)")
                                        .font(AppFonts.title)
                                        .foregroundStyle(AppColors.textSecondary)
                                } else if let dur = store.vod.duration, !dur.isEmpty {
                                    Text(dur)
                                        .font(AppFonts.title)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                Text(AppStrings.VODDetail.uhdQualityBadge)
                                    .font(AppFonts.caption.bold())
                                    .foregroundColor(AppColors.cyan)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.cyan.opacity(0.2), in: Capsule())
                            }

                            // Plot
                            if let plot = store.tmdbMovie?.overview ?? store.info?.plot, !plot.isEmpty {
                                ExpandableSynopsisView(
                                    text: plot,
                                    font: AppFonts.bodyLarge,
                                    lineLimit: 4,
                                    onPresent: { onPresentSynopsis(plot) }
                                )
                            } else if store.isTMDBLoading || store.isLoading {
                                VStack(alignment: .leading, spacing: 10) {
                                    RoundedRectangle(cornerRadius: 6).fill(AppColors.borderMedium).frame(height: 22)
                                    RoundedRectangle(cornerRadius: 6).fill(AppColors.borderMedium).frame(height: 22)
                                    RoundedRectangle(cornerRadius: 6).fill(AppColors.borderMedium).frame(width: 400, height: 22)
                                }
                                .shimmeringPlaceholder(isLoading: true)
                            }

                            if !store.awardRecognitions.isEmpty {
                                AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                                    .padding(.top, 8)
                            }

                            WatchAvailabilitySection(
                                countryCode: store.watchAvailabilityCountryCode,
                                availability: store.watchAvailability,
                                updatedAt: store.watchAvailabilityLoadedAt,
                                isLoading: store.isWatchAvailabilityLoading,
                                failed: store.watchAvailabilityFailed,
                                onSelectCountry: { store.send(.watchAvailabilityCountrySelected($0)) },
                                onRetry: { store.send(.retryWatchAvailability) }
                            )
                            .padding(.top, 8)

                            if store.availableVersions.count > 1 {
                                MovieVersionPickerView(
                                    versions: store.availableVersions,
                                    selectedVersionId: store.selectedVersionId ?? store.vod.id,
                                    onSelectVersion: { version in
                                        store.send(.selectVersion(version))
                                    }
                                )
                                .padding(.top, 8)
                                .disabled(store.isConfirmingDownloadDeletion || store.isStartingDownload || store.isDeletingDownload)
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
                                                gradientColors: [AppColors.neonTeal, AppColors.textPrimary],
                                                trackColor: AppColors.borderStrong
                                            ) {
                                                Image(systemName: "play.fill")
                                                    .font(.system(size: 10, weight: .bold))
                                                    .foregroundStyle(AppColors.textPrimary)
                                            }

                                            Text(AppStrings.VODDetail.continueWatching)
                                                .fontWeight(.bold)

                                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                                            Text("%\(percent)")
                                                .font(AppFonts.caption.bold())
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(AppColors.borderStrong, in: Capsule())
                                        }
                                        .padding(.horizontal, 32)
                                        .padding(.vertical, 16)
                                    }
                                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                                    .focused($isPlayButtonFocused)
                                    .defaultFocus($isPlayButtonFocused, true, priority: .userInitiated)

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
                                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))

                                    if history.progress / history.duration >= 0.90 {
                                        Button {
                                            store.send(.markUnwatched)
                                        } label: {
                                            Label(AppStrings.SeriesDetail.unwatched, systemImage: "eye.slash")
                                                .padding(.horizontal, 20)
                                                .padding(.vertical, 16)
                                        }
                                        .buttonStyle(TVCapsuleButtonStyle(isPrimary: false, isSelected: false))
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
                                    .buttonStyle(TVCapsuleButtonStyle(isPrimary: true, isSelected: false))
                                    .focused($isPlayButtonFocused)
                                    .defaultFocus($isPlayButtonFocused, true, priority: .userInitiated)
                                }

                                Button {
                                    store.send(.toggleFavorite)
                                } label: {
                                    Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                        .foregroundColor(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                                        .padding(14)
                                }
                                .buttonStyle(TVCircleButtonStyle(isFavorite: store.isFavorite))
                            }

                            // Cast Row on tvOS
                            if let cast = store.tmdbMovie?.credits?.cast, !cast.isEmpty {
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(AppStrings.VODDetail.castCrew)
                                        .font(AppFonts.headline)
                                        .foregroundStyle(AppColors.textPrimary)

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
                                                                    Rectangle().fill(AppColors.surfaceElevated)
                                                                }
                                                            }
                                                            .frame(width: 80, height: 80)
                                                            .clipShape(Circle())
                                                        } else {
                                                            Rectangle()
                                                                .fill(AppColors.surfaceElevated)
                                                                .frame(width: 80, height: 80)
                                                                .clipShape(Circle())
                                                        }

                                                        Text(actor.name ?? "")
                                                            .font(AppFonts.caption.bold())
                                                            .foregroundStyle(AppColors.textPrimary)
                                                            .lineLimit(1)
                                                            .frame(width: 100)

                                                        if let char = actor.character {
                                                            Text(char)
                                                                .font(.system(size: 10))
                                                                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                                                                .lineLimit(1)
                                                                .frame(width: 100)
                                                        }
                                                    }
                                                    .padding(6)
                                                }
                                                .tvFocusEffect()
                                            }
                                        }
                                    }
                                    .focusSection()
                                }
                                .padding(.top, 12)
                            }

                            // Similar Movies on tvOS
                            if let similar = store.tmdbMovie?.similar?.results, !similar.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 12) {
                                        Text(AppStrings.VODDetail.similarMovies)
                                            .font(AppFonts.headline)
                                            .foregroundStyle(AppColors.textPrimary)

                                        if !store.matchedVODsByTMDBId.isEmpty {
                                            Text("\(store.matchedVODsByTMDBId.count) \(AppStrings.VODDetail.inLibrary)")
                                                .font(AppFonts.caption.bold())
                                                .foregroundStyle(AppColors.neonTeal)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 4)
                                                .background(AppColors.neonTeal.opacity(0.18), in: Capsule())
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
                                                                        Rectangle().fill(AppColors.surfaceElevated)
                                                                    }
                                                                }
                                                                .frame(width: 140, height: 210)
                                                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                                            } else {
                                                                Rectangle()
                                                                    .fill(AppColors.surfaceElevated)
                                                                    .frame(width: 140, height: 210)
                                                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                                            }

                                                            if isMatched {
                                                                Text(AppStrings.VODDetail.inLibrary)
                                                                    .font(.system(size: 10, weight: .heavy))
                                                                    .foregroundStyle(AppColors.oledBlack)
                                                                    .padding(.horizontal, 8)
                                                                    .padding(.vertical, 4)
                                                                    .background(AppColors.neonTeal, in: Capsule())
                                                                    .padding(8)
                                                            } else if let vote = item.voteAverage, vote > 0 {
                                                                HStack(spacing: 3) {
                                                                    Image(systemName: "star.fill")
                                                                        .font(.system(size: 9))
                                                                        .foregroundStyle(AppColors.warningGold)
                                                                    Text(String(format: "%.1f", vote))
                                                                        .font(AppFonts.caption.bold())
                                                                        .foregroundStyle(AppColors.textPrimary)
                                                                }
                                                                .padding(.horizontal, 6)
                                                                .padding(.vertical, 3)
                                                                .background(.ultraThinMaterial, in: Capsule())
                                                                .padding(8)
                                                            }
                                                        }

                                                        Text(item.title ?? item.name ?? "")
                                                            .font(AppFonts.caption.bold())
                                                            .foregroundStyle(AppColors.textPrimary)
                                                            .lineLimit(1)
                                                            .frame(width: 140, alignment: .leading)
                                                    }
                                                    .padding(6)
                                                }
                                                .tvFocusEffect()
                                            }
                                        }
                                    }
                                    .focusSection()
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
                .focusSection()
            }
            .onAppear {
                store.send(.onAppear)
            }
            .onExitCommand {
                store.send(.closeTapped)
            }
        }
    }
#endif
