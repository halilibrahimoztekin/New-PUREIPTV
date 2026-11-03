#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    struct VODDetailCastSection_iOS: View {
        let store: StoreOf<VODDetailFeature>
        let onPresentSynopsis: (String) -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 22) {
                // Genres
                let genres = store.tmdbMovie?.genres?.map(\.name) ?? store.info?.genre?.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) } ?? []
                if !genres.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(genres, id: \.self) { genre in
                                Text(genre)
                                    .font(AppFonts.caption.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .liquidGlass(shape: .capsule)
                                    .foregroundStyle(AppColors.onSurface)
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
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        ExpandableSynopsisView(
                            text: plotText,
                            font: AppFonts.bodyMedium,
                            lineLimit: 5,
                            onPresent: { onPresentSynopsis(plotText) }
                        )
                    }
                    .padding(.horizontal, 24)
                } else if store.isTMDBLoading || store.isLoading {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(AppStrings.VODDetail.overview)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        VStack(alignment: .leading, spacing: 6) {
                            RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(height: 14)
                            RoundedRectangle(cornerRadius: 4).fill(AppColors.borderMedium).frame(width: 220, height: 14)
                        }
                        .shimmeringPlaceholder(isLoading: true)
                    }
                    .padding(.horizontal, 24)
                }

                if !store.awardRecognitions.isEmpty {
                    AwardRecognitionMetadataView(recognitions: store.awardRecognitions)
                        .padding(.horizontal, 24)
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
                .padding(.horizontal, 24)

                // Oyuncu Kadrosu (Cast & Crew Carousel)
                if let cast = store.tmdbMovie?.credits?.cast, !cast.isEmpty {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack {
                            Text(AppStrings.VODDetail.castCrew)
                                .font(AppFonts.headline)
                                .foregroundStyle(AppColors.textPrimary)

                            Spacer()

                            Text("\(cast.count)")
                                .font(AppFonts.caption.bold())
                                .foregroundStyle(AppColors.textSecondary.opacity(0.6))
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
                                                .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1.2))
                                                .shadow(color: AppColors.oledBlack.opacity(0.35), radius: 6, y: 3)
                                            } else {
                                                actorAvatarFallback(name: actor.name)
                                                    .frame(width: 70, height: 70)
                                                    .clipShape(Circle())
                                                    .overlay(Circle().stroke(AppColors.borderMedium, lineWidth: 1.2))
                                            }

                                            // Real Name
                                            Text(actor.name ?? "")
                                                .font(AppFonts.caption.weight(.semibold))
                                                .foregroundStyle(AppColors.textPrimary)
                                                .lineLimit(1)
                                                .frame(width: 82)

                                            // Character Name
                                            if let char = actor.character, !char.isEmpty {
                                                Text(char)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                                                    .lineLimit(1)
                                                    .frame(width: 82)
                                            }
                                        }
                                    }
                                    .buttonStyle(FluidScaleButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                        }
                    }
                } else if store.isTMDBLoading {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(AppStrings.VODDetail.castCrew)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 14) {
                                ForEach(0 ..< 5, id: \.self) { _ in
                                    VStack(spacing: 7) {
                                        Circle()
                                            .fill(AppColors.borderMedium)
                                            .frame(width: 70, height: 70)
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(AppColors.borderMedium)
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
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(countries, id: \.iso3166_1) { country in
                                    Text(country.name)
                                        .font(AppFonts.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(AppColors.surfaceSecondary)
                                        .foregroundStyle(AppColors.sky)
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
                                .font(AppFonts.bodyMedium.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(AppColors.surfaceTertiary)
                        .foregroundStyle(AppColors.textPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppColors.divider, lineWidth: 1)
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
                                .font(AppFonts.titleSmall.bold())
                                .foregroundStyle(AppColors.textPrimary)

                            if !store.matchedVODsByTMDBId.isEmpty {
                                Text("\(store.matchedVODsByTMDBId.count) \(AppStrings.VODDetail.inLibrary)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(AppColors.neonTeal)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(AppColors.neonTeal.opacity(0.15), in: Capsule())
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
                                                            Rectangle().fill(AppColors.surfaceElevated)
                                                        }
                                                    }
                                                    .frame(width: 110, height: 165)
                                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                            .stroke(isMatched ? AppColors.neonTeal.opacity(0.6) : AppColors.borderMedium, lineWidth: isMatched ? 1.5 : 0.8)
                                                    )
                                                    .shadow(color: isMatched ? AppColors.neonTeal.opacity(0.2) : AppColors.oledBlack.opacity(0.4), radius: 8, y: 4)
                                                } else {
                                                    Rectangle()
                                                        .fill(AppColors.surfaceElevated)
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
                                                            colors: [AppColors.neonTeal, AppColors.neonTeal.opacity(0.8)],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        ),
                                                        in: Capsule()
                                                    )
                                                    .foregroundStyle(AppColors.oledBlack)
                                                    .shadow(color: AppColors.neonTeal.opacity(0.5), radius: 4)
                                                    .padding(6)
                                                } else if let vote = item.voteAverage, vote > 0 {
                                                    HStack(spacing: 2) {
                                                        Image(systemName: "star.fill")
                                                            .font(.system(size: 7))
                                                            .foregroundStyle(AppColors.warningGold)
                                                        Text(String(format: "%.1f", vote))
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundStyle(AppColors.textPrimary)
                                                    }
                                                    .padding(.horizontal, 5)
                                                    .padding(.vertical, 2.5)
                                                    .background(.ultraThinMaterial, in: Capsule())
                                                    .overlay(Capsule().stroke(AppColors.borderStrong, lineWidth: 0.5))
                                                    .padding(6)
                                                }
                                            }

                                            Text(item.title ?? item.name ?? "")
                                                .font(AppFonts.caption.weight(.semibold))
                                                .foregroundStyle(AppColors.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                                .frame(width: 110, alignment: .leading)

                                            if let date = item.releaseDate ?? item.firstAirDate, !date.isEmpty {
                                                Text(String(date.prefix(4)))
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(AppColors.textSecondary.opacity(0.7))
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
                            .font(AppFonts.titleSmall.bold())
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 24)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(0 ..< 4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(AppColors.borderMedium)
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
                    colors: [AppColors.surfaceSecondary, AppColors.surfaceContainer],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let firstLetter = name?.first {
                    Text(String(firstLetter).uppercased())
                        .font(AppFonts.title.bold())
                        .foregroundColor(AppColors.textPrimary.opacity(0.7))
                } else {
                    Image(systemName: "person.fill")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary.opacity(0.4))
                }
            }
        }
    }
#endif
