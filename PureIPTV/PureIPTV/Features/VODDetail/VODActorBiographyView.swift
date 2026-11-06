import ComposableArchitecture
import SwiftUI

struct VODActorBiographyContent: View {
    let actor: TMDBCastMemberDTO
    let details: TMDBPersonDetailsDTO?
    let isLoading: Bool
    let userAgentOverride: String?
    let playlistID: UUID?
    let close: () -> Void

    @Environment(\.displayScale) private var displayScale

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
                        VStack(alignment: .leading, spacing: 20) {
                            HStack(spacing: 18) {
                                let avatarURL = (details?.profilePath ?? actor.profilePath).flatMap { TMDBImageURL.make(path: $0, size: .w342)?.absoluteString }
                                if let urlString = avatarURL, let url = URL(string: urlString) {
                                    PlaylistAsyncImage(
                                        url: url,
                                        userAgentOverride: userAgentOverride,
                                        playlistID: playlistID,
                                        downsamplingSize: CGSize(width: 90 * displayScale, height: 90 * displayScale)
                                    ) { phase in
                                        if case let .success(image) = phase {
                                            image.resizable().scaledToFill()
                                        } else {
                                            avatarFallback
                                        }
                                    }
                                    .frame(width: 90, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                    .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(AppColors.borderStrong, lineWidth: 1.5))
                                    .shadow(color: .black.opacity(0.6), radius: 10, y: 5)
                                } else {
                                    avatarFallback
                                        .frame(width: 90, height: 90)
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }

                                VStack(alignment: .leading, spacing: 6) {
                                    Text(actor.name ?? "")
                                        .font(AppFonts.title.bold())
                                        .foregroundColor(AppColors.textPrimary)

                                    if let character = actor.character, !character.isEmpty {
                                        Text("\(AppStrings.VODDetail.character): \(character)")
                                            .font(AppFonts.bodyMedium)
                                            .foregroundColor(AppColors.primary)
                                    }

                                    if let department = details?.knownForDepartment {
                                        Text(department)
                                            .font(AppFonts.caption)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                            if let details {
                                HStack(spacing: 10) {
                                    if let birthday = details.birthday, !birthday.isEmpty {
                                        detailChip(symbol: "calendar", color: AppColors.cyan, text: birthday)
                                    }
                                    if let placeOfBirth = details.placeOfBirth, !placeOfBirth.isEmpty {
                                        detailChip(symbol: "mappin.and.ellipse", color: AppColors.destructive, text: placeOfBirth)
                                    }
                                }
                                .padding(.horizontal, 24)
                            }

                            Divider().background(AppColors.divider).padding(.horizontal, 24)

                            VStack(alignment: .leading, spacing: 10) {
                                Text(AppStrings.VODDetail.biography)
                                    .font(AppFonts.headline)
                                    .foregroundColor(AppColors.textPrimary)

                                if isLoading {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 4).fill(AppColors.glassPlate).frame(height: 14)
                                        RoundedRectangle(cornerRadius: 4).fill(AppColors.glassPlate).frame(height: 14)
                                        RoundedRectangle(cornerRadius: 4).fill(AppColors.glassPlate).frame(width: 200, height: 14)
                                    }
                                    .shimmeringPlaceholder(isLoading: true)
                                } else if let biography = details?.biography,
                                          !biography.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                {
                                    Text(biography)
                                        .font(AppFonts.bodyMedium)
                                        .foregroundColor(AppColors.onSurface)
                                        .lineSpacing(5)
                                        .fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text(AppStrings.VODDetail.noBiography)
                                        .font(AppFonts.bodyMedium)
                                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
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
                    let avatarURL = (details?.profilePath ?? actor.profilePath).flatMap { TMDBImageURL.make(path: $0, size: .w500)?.absoluteString }
                    if let urlString = avatarURL, let url = URL(string: urlString) {
                        PlaylistAsyncImage(
                            url: url,
                            userAgentOverride: userAgentOverride,
                            playlistID: playlistID,
                            downsamplingSize: CGSize(width: 480 * displayScale, height: 640 * displayScale)
                        ) { phase in
                            if case let .success(image) = phase {
                                image.resizable().scaledToFill()
                            } else {
                                Rectangle().fill(AppColors.surfaceSecondary)
                            }
                        }
                        .frame(width: 240, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.borderStrong, lineWidth: 1.5))
                    }

                    VStack(alignment: .leading, spacing: 18) {
                        Text(actor.name ?? "")
                            .font(AppFonts.displayMedium)
                            .foregroundColor(AppColors.textPrimary)

                        if let character = actor.character, !character.isEmpty {
                            Text("\(AppStrings.VODDetail.character): \(character)")
                                .font(AppFonts.headline)
                                .foregroundColor(AppColors.primary)
                        }

                        if let birthday = details?.birthday {
                            Text("\(AppStrings.VODDetail.born): \(birthday)")
                                .font(AppFonts.titleSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        if let placeOfBirth = details?.placeOfBirth {
                            Text("\(AppStrings.VODDetail.birthplace): \(placeOfBirth)")
                                .font(AppFonts.titleSmall)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        if let biography = details?.biography, !biography.isEmpty {
                            Text(biography)
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.onSurface)
                                .lineLimit(8)
                        } else if isLoading {
                            ProgressView()
                                .tint(AppColors.textPrimary)
                        } else {
                            Text(AppStrings.VODDetail.noBiography)
                                .font(AppFonts.bodyMedium)
                                .foregroundColor(AppColors.textSecondary.opacity(0.5))
                                .italic()
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

    #if !os(tvOS)
        private var avatarFallback: some View {
            ZStack {
                LinearGradient(
                    colors: [AppColors.surfaceSecondary, AppColors.surfaceContainer],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                if let firstLetter = actor.name?.first {
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

        private func detailChip(symbol: String, color: Color, text: String) -> some View {
            HStack(spacing: 5) {
                Image(systemName: symbol).foregroundColor(color)
                Text(text).lineLimit(1)
            }
            .font(AppFonts.caption.bold())
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(AppColors.borderSubtle, in: Capsule())
        }
    #endif
}
