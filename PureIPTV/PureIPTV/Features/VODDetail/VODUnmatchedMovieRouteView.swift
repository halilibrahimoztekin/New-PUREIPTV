import ComposableArchitecture
import SwiftUI

struct VODUnmatchedMovieRouteContent: View {
    let item: TMDBSimilarItemDTO
    let close: () -> Void

    var body: some View {
        #if os(tvOS)
            tvOSContent
        #else
            iOSContent
        #endif
    }

    #if !os(tvOS)
        private var iOSContent: some View {
            NavigationStack {
                ZStack {
                    AppColors.surfaceDark.ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            let backdropURL = item.backdropPath.map { "https://image.tmdb.org/t/p/w780\($0)" }
                                ?? item.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
                            if let urlString = backdropURL, let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    if case let .success(image) = phase {
                                        image.resizable().scaledToFill()
                                    } else {
                                        Rectangle().fill(AppColors.surfaceSecondary)
                                    }
                                }
                                .frame(height: 180)
                                .clipped()
                                .overlay(
                                    LinearGradient(
                                        colors: [Color.clear, AppColors.surfaceDark],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                            }

                            VStack(alignment: .leading, spacing: 14) {
                                Text(item.title ?? item.name ?? "")
                                    .font(AppFonts.title.bold())
                                    .foregroundStyle(AppColors.textPrimary)

                                HStack(spacing: 12) {
                                    if let vote = item.voteAverage, vote > 0 {
                                        HStack(spacing: 4) {
                                            Image(systemName: "star.fill")
                                                .font(.system(size: 11))
                                                .foregroundStyle(AppColors.warningGold)
                                            Text(String(format: "%.1f", vote))
                                                .font(AppFonts.bodySmall.bold())
                                                .foregroundStyle(AppColors.textPrimary)
                                            Text(AppStrings.VODDetail.imdbRating)
                                                .font(.system(size: 8, weight: .heavy))
                                                .padding(.horizontal, 4)
                                                .padding(.vertical, 1.5)
                                                .background(AppColors.warningGold.opacity(0.2), in: RoundedRectangle(cornerRadius: 3))
                                                .foregroundStyle(AppColors.warningGold)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(.ultraThinMaterial, in: Capsule())
                                    }

                                    if let date = item.releaseDate ?? item.firstAirDate, !date.isEmpty {
                                        Text(String(date.prefix(4)))
                                            .font(AppFonts.bodyMedium)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }

                                HStack(spacing: 10) {
                                    Image(systemName: "info.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(AppColors.warning)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(AppStrings.VODDetail.notInLibrary)
                                            .font(AppFonts.bodySmall.bold())
                                            .foregroundStyle(AppColors.warning)
                                        Text(AppStrings.VODDetail.notInLibraryDesc)
                                            .font(.system(size: 11))
                                            .foregroundStyle(AppColors.onSurfaceVariant)
                                    }
                                }
                                .padding(12)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(AppColors.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(AppColors.warning.opacity(0.25), lineWidth: 1)
                                )

                                if let plot = item.overview, !plot.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(AppStrings.VODDetail.overview)
                                            .font(AppFonts.titleSmall.bold())
                                            .foregroundStyle(AppColors.textPrimary)

                                        Text(plot)
                                            .font(AppFonts.bodySmall)
                                            .foregroundStyle(AppColors.onSurface)
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
                            close()
                        }
                        .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
            #if os(iOS)
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            #endif
        }
    #endif

    #if os(tvOS)
        private var tvOSContent: some View {
            ZStack {
                AppColors.surfaceDark.ignoresSafeArea()

                HStack(spacing: 40) {
                    let cover = item.posterPath.map { "https://image.tmdb.org/t/p/w500\($0)" }
                    if let urlString = cover, let url = URL(string: urlString) {
                        AsyncImage(url: url) { phase in
                            if case let .success(image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(AppColors.surfaceSecondary)
                            }
                        }
                        .frame(width: 240, height: 360)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.borderStrong, lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 20) {
                        Text(item.title ?? item.name ?? "")
                            .font(AppFonts.displayMedium)
                            .foregroundColor(AppColors.textPrimary)

                        HStack(spacing: 16) {
                            if let vote = item.voteAverage, vote > 0 {
                                HStack(spacing: 6) {
                                    Image(systemName: "star.fill").foregroundColor(AppColors.warningGold)
                                    Text(String(format: "%.1f", vote))
                                        .font(AppFonts.title.bold())
                                        .foregroundColor(AppColors.textPrimary)
                                }
                            }

                            if let date = item.releaseDate ?? item.firstAirDate, !date.isEmpty {
                                Text(String(date.prefix(4)))
                                    .font(AppFonts.title)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }

                        HStack(spacing: 10) {
                            Image(systemName: "info.circle.fill")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.warning)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(AppStrings.VODDetail.notInLibrary)
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.warning)
                                Text(AppStrings.VODDetail.notInLibraryDesc)
                                    .font(AppFonts.bodyMedium)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding(16)
                        .background(AppColors.warning.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))

                        if let plot = item.overview, !plot.isEmpty {
                            Text(plot)
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.onSurface)
                                .lineLimit(6)
                        }

                        Button(AppStrings.Common.close, action: close)
                            .tvFocusEffect(shape: .capsule)
                            .padding(.top, 16)
                    }
                    .frame(maxWidth: 600, alignment: .leading)
                }
                .padding(60)
            }
        }
    #endif
}
