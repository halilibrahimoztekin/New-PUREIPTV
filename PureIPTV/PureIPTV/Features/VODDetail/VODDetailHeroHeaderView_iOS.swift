#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    struct VODDetailHeroHeaderView_iOS: View {
        let store: StoreOf<VODDetailFeature>

        var body: some View {
            VStack(spacing: 0) {
                // Edge-to-edge cinematic backdrop with an explicit trailer action.
                let backdropURLString = store.tmdbMovie?.backdropPath.flatMap { TMDBImageURL.make(path: $0, size: .w1280)?.absoluteString } ??
                    store.vod.presentationOverride?.posterURL?.absoluteString ??
                    store.tmdbMovie?.posterPath.flatMap { TMDBImageURL.make(path: $0, size: .w780)?.absoluteString } ??
                    store.vod.coverURL?.absoluteString
                let backdropURL = backdropURLString.flatMap { URL(string: $0) }

                ZStack(alignment: .topTrailing) {
                    InlineTrailerHeroView(
                        backdropURL: backdropURL,
                        userAgentOverride: store.config.userAgentOverride,
                        trailerKey: store.resolvedTrailerKey,
                        onOpenTrailerSheet: {
                            store.send(.trailerTapped)
                        }
                    )

                    // Quality Badges at Top Trailing
                    HStack {
                        Spacer()
                        LiquidGlassContainer(spacing: 6) {
                            badgeCapsule(title: AppStrings.VODDetail.uhdQualityBadge, color: AppColors.cyan)
                            badgeCapsule(title: AppStrings.VODDetail.hdrBadge, color: AppColors.premium)
                            badgeCapsule(title: AppStrings.VODDetail.audio51Badge, color: AppColors.textPrimary)
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
                    let posterURLString = store.vod.presentationOverride?.posterURL?.absoluteString ??
                        store.tmdbMovie?.posterPath.flatMap { TMDBImageURL.make(path: $0, size: .w500)?.absoluteString } ??
                        store.vod.coverURL?.absoluteString

                    if let urlString = posterURLString, let url = URL(string: urlString) {
                        PlaylistAsyncImage(url: url, userAgentOverride: store.config.userAgentOverride, playlistID: store.config.playlistID, downsamplingSize: CGSize(width: 250, height: 376)) { phase in
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
                        .frame(width: 125, height: 188)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppColors.borderMedium, lineWidth: 1)
                        )
                        .shadow(color: AppColors.oledBlack.opacity(0.7), radius: 14, x: 0, y: 8)
                        .offset(y: -50)
                        .padding(.bottom, -50)
                    }

                    // Metadata & Action Buttons
                    VStack(alignment: .leading, spacing: 10) {
                        TMDBTitleLogoView(
                            path: store.vod.presentationOverride?.title == nil ? store.tmdbMovie?.preferredTitleLogoPath : nil,
                            backdropPath: store.tmdbMovie?.backdropPath,
                            title: store.vod.presentationOverride?.title ?? store.tmdbMovie?.title ?? store.vod.title,
                            maxWidth: .infinity,
                            height: 72,
                            fallbackFont: AppFonts.title.bold(),
                            userAgentOverride: store.config.userAgentOverride,
                            playlistID: store.config.playlistID,
                            cacheKey: store.vod.presentationOverride?.title == nil
                                ? TMDBTitleLogoCache.key(for: store.vod, mediaType: "movie")
                                : nil
                        )

                        // Rating & Tag row
                        HStack(spacing: 8) {
                            if let rating = store.tmdbMovie?.voteAverage ?? store.info?.rating, rating > 0 {
                                HStack(spacing: 4) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppColors.warningGold)
                                    Text(String(format: "%.1f", rating))
                                        .font(AppFonts.bodySmall.bold())
                                        .foregroundStyle(AppColors.textPrimary)
                                    Text(AppStrings.VODDetail.imdbRating)
                                        .font(.system(size: 9, weight: .heavy))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1.5)
                                        .background(AppColors.warningGold.opacity(0.25), in: RoundedRectangle(cornerRadius: 3))
                                        .foregroundStyle(AppColors.warningGold)
                                }
                            }

                            if let year = store.vod.presentationOverride?.year {
                                Text(String(year))
                                    .font(AppFonts.bodySmall.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                            } else if let date = store.tmdbMovie?.releaseDate ?? store.info?.releaseDate ?? store.vod.releaseDate, !date.isEmpty {
                                Text(String(date.prefix(4)))
                                    .font(AppFonts.bodySmall.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
                            }

                            if let runtime = store.tmdbMovie?.runtime, runtime > 0 {
                                Text("\(runtime / 60)s \(runtime % 60)dk")
                                    .font(AppFonts.bodySmall.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)
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
                .liquidGlass(shape: .capsule, tint: color.opacity(0.15))
                .overlay(Capsule().stroke(color.opacity(0.35), lineWidth: 0.8))
        }

        // MARK: - Action Section

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
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }

                            Text(AppStrings.VODDetail.continueWatching)
                                .font(AppFonts.bodyLarge.weight(.semibold))

                            let percent = WatchProgressFormatter.percentage(progress: history.progress, duration: history.duration)
                            Text("%\(percent)")
                                .font(AppFonts.caption.bold())
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
                        store.send(.playTapped)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(AppFonts.bodyLarge.bold())
                            Text(AppStrings.Common.watchNow)
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
                    if let history = store.historyItem, history.duration > 0 {
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.restartTapped)
                        } label: {
                            VStack(spacing: 4) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 16, weight: .medium))
                                Text(AppStrings.VODDetail.restart)
                                    .font(AppFonts.caption)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                            .foregroundStyle(AppColors.textPrimary)
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
                                        .font(AppFonts.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), isInteractive: true)
                                .foregroundStyle(AppColors.textPrimary)
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
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                            Text(store.isFavorite ? AppStrings.Common.favorited : AppStrings.Common.favorite)
                                .font(AppFonts.caption)
                                .foregroundStyle(store.isFavorite ? AppColors.destructive : AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), tint: store.isFavorite ? AppColors.destructive.opacity(0.15) : nil, isInteractive: true)
                    }

                    #if os(iOS)
                        if store.config.type != .plex, store.config.type != .emby {
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.downloadTapped)
                            } label: {
                                VStack(spacing: 4) {
                                    if store.isStartingDownload || store.isDeletingDownload {
                                        ProgressView()
                                    } else {
                                        Image(systemName: store.isDownloaded ? "arrow.down.circle.fill" : "arrow.down.circle")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(store.isDownloaded ? AppColors.success : AppColors.textPrimary)
                                    }
                                    Text(store.isDownloaded ? AppStrings.Common.downloaded : AppStrings.Common.download)
                                        .font(AppFonts.caption)
                                        .foregroundStyle(store.isDownloaded ? AppColors.success : AppColors.textPrimary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .liquidGlass(shape: .roundedRectangle(cornerRadius: 10), tint: store.isDownloaded ? AppColors.success.opacity(0.15) : nil, isInteractive: true)
                            }
                            .disabled(store.isStartingDownload || store.isDeletingDownload)
                            .accessibilityValue(store.isStartingDownload || store.isDeletingDownload ? AppStrings.Common.loading : "")
                        }
                    #endif
                }

                #if os(iOS)
                    if let downloadErrorMessage = store.downloadErrorMessage {
                        Text(downloadErrorMessage)
                            .font(AppFonts.caption)
                            .foregroundStyle(AppColors.destructive)
                    }
                #endif
            }
        }
    }
#endif
