#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SeriesDetailHeroHeaderView_iOS: View {
        let store: StoreOf<SeriesDetailFeature>

        public init(store: StoreOf<SeriesDetailFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack(alignment: .bottom) {
                // Background Blur
                GeometryReader { proxy in
                    let cover = store.tmdbTV?.backdropPath.map { "https://image.tmdb.org/t/p/w1280\($0)" } ??
                        store.series.presentationOverride?.posterURL?.absoluteString ??
                        store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w780\($0)" } ??
                        store.series.coverURL?.absoluteString

                    if let urlString = cover, let url = URL(string: urlString) {
                        PlaylistAsyncImage(
                            url: url,
                            userAgentOverride: store.config.userAgentOverride,
                            playlistID: store.config.playlistID,
                            downsamplingSize: CGSize(width: 640, height: 360)
                        ) { phase in
                            switch phase {
                            case let .success(image):
                                image.resizable().scaledToFill()
                            default:
                                Rectangle().fill(AppColors.surfaceTertiary)
                            }
                        }
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .blur(radius: 40)
                        .opacity(0.4)
                    } else {
                        Rectangle().fill(AppColors.surfaceTertiary)
                    }
                }

                // Gradient Overlay
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: AppColors.surfaceDark, location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )

                // Content (Poster + Info side by side, plus Action Section)
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom, spacing: 16) {
                        // Poster
                        let cover = store.series.presentationOverride?.posterURL?.absoluteString ??
                            store.tmdbTV?.posterPath.map { "https://image.tmdb.org/t/p/w342\($0)" } ?? store.series.coverURL?.absoluteString

                        if let urlString = cover, let url = URL(string: urlString) {
                            PlaylistAsyncImage(
                                url: url,
                                userAgentOverride: store.config.userAgentOverride,
                                playlistID: store.config.playlistID,
                                downsamplingSize: CGSize(width: 240, height: 360)
                            ) { phase in
                                switch phase {
                                case let .success(image):
                                    image.resizable().scaledToFill()
                                case .empty:
                                    Rectangle().fill(AppColors.surfaceElevated).shimmeringPlaceholder(isLoading: true)
                                case .failure:
                                    Rectangle().fill(AppColors.surfaceElevated)
                                @unknown default:
                                    Rectangle().fill(AppColors.surfaceElevated)
                                }
                            }
                            .frame(width: 120, height: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: AppColors.oledBlack.opacity(0.5), radius: 10, x: 0, y: 5)
                        } else if store.isTMDBLoading {
                            Rectangle()
                                .fill(AppColors.surfaceElevated)
                                .frame(width: 120, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .shimmeringPlaceholder(isLoading: true)
                        }

                        // Info block
                        VStack(alignment: .leading, spacing: 10) {
                            Text(store.series.presentationOverride?.title ?? store.tmdbTV?.name ?? store.series.title)
                                .font(AppFonts.displaySmall)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(3)
                                .fixedSize(horizontal: false, vertical: true)

                            // Rating and Status
                            HStack(spacing: 8) {
                                if let year = store.series.presentationOverride?.year {
                                    Text(String(year))
                                        .font(AppFonts.captionSemibold)
                                        .foregroundStyle(AppColors.textSecondary)
                                } else if let releaseDate = store.tmdbTV?.firstAirDate ?? store.info?.releaseDate ?? store.series.releaseDate, !releaseDate.isEmpty {
                                    Text(String(releaseDate.prefix(4)))
                                        .font(AppFonts.captionSemibold)
                                        .foregroundStyle(AppColors.textSecondary)
                                }

                                if let rating = store.tmdbTV?.voteAverage ?? store.info?.rating, rating > 0 {
                                    HStack(spacing: 4) {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(AppColors.warningGold)
                                            .font(AppFonts.captionSmall)
                                        Text(String(format: "%.1f", rating))
                                            .font(AppFonts.bodyBold)
                                            .foregroundStyle(AppColors.textPrimary)
                                    }
                                }

                                if let status = store.tmdbTV?.status ?? store.info?.status {
                                    Text(status)
                                        .font(AppFonts.captionSmall.weight(.bold))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppColors.surfaceSecondary)
                                        .foregroundStyle(AppColors.textPrimary)
                                        .clipShape(Capsule())
                                }
                            }
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.textSecondary)
                            .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Zero-Friction Action Section (Don't Make Me Think)
                    actionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 20)
            }
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
                                gradientColors: [AppColors.neonTeal, AppColors.textPrimary],
                                trackColor: AppColors.borderStrong
                            ) {
                                Image(systemName: "play.fill")
                                    .font(AppFonts.captionSmall.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }

                            Text(AppStrings.SeriesDetail.continueWatching)
                                .font(AppFonts.bodyLarge.weight(.semibold))

                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                            Text("%\(percent)")
                                .font(AppFonts.captionBold)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(AppColors.borderStrong, in: Capsule())
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppColors.primary.opacity(0.35), radius: 8, y: 3)
                    }
                } else {
                    Button {
                        HapticManager.shared.trigger(.medium)
                        if let firstEp = store.currentEpisodes.first {
                            store.send(.episodeSelected(firstEp))
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(AppFonts.bodyLarge.bold())
                            Text(AppStrings.SeriesDetail.watch)
                                .font(AppFonts.bodyLarge.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primary.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .foregroundStyle(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppColors.primary.opacity(0.35), radius: 8, y: 3)
                    }
                }

                // 2. Secondary Symmetrical Action Row (Zero-Scroll Above-the-Fold)
                LiquidGlassContainer(spacing: 8) {
                    if store.currentEpisodeRevealTarget != nil {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.revealCurrentEpisodeTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "dot.scope")
                                    .font(AppFonts.bodyMedium)
                                Text(AppStrings.SeriesDetail.currentEpisode)
                                    .font(AppFonts.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    if let history = store.historyItem, history.duration > 0 {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.restartTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(AppFonts.bodyMedium)
                                Text(AppStrings.SeriesDetail.restart)
                                    .font(AppFonts.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    if store.resolvedTrailerKey != nil {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.trailerTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "film.fill")
                                    .font(AppFonts.bodyMedium)
                                Text(AppStrings.VODDetail.trailer)
                                    .font(AppFonts.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
                        }
                    }

                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.toggleFavorite)
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: store.isFavorite ? "heart.fill" : "heart")
                                .font(AppFonts.bodyMedium)
                                .foregroundStyle(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                            Text(store.isFavorite ? AppStrings.Common.favorited : AppStrings.Common.favorite)
                                .font(AppFonts.caption)
                                .foregroundStyle(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), tint: store.isFavorite ? AppColors.destructive.opacity(0.15) : nil, isInteractive: true)
                    }
                }
            }
        }
    }
#endif
