#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV iPad Detail Column (Column 3)

    /// Rightmost detail column for iPad split view displaying channel preview,
    /// hero card, actions, and interactive EPG schedule.
    struct LiveTVDetail_iPad: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        @Environment(\.locale) private var locale

        var body: some View {
            VStack(spacing: 0) {
                if let selected = store.selectedChannel {
                    ScrollView {
                        VStack(spacing: 20) {
                            heroCard(selected: selected)
                            epgScheduleSection
                        }
                        .padding(.bottom, 24)
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "tv")
                            .font(.system(size: 48))
                            .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                        Text(AppStrings.LiveTV.noChannels)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.surface)
        }

        // MARK: - Hero Card

        private func heroCard(selected: MediaModels.Item) -> some View {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.surfaceSecondary, AppColors.surface],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                if let cover = selected.displayLogoURL {
                                    PlaylistAsyncImage(url: cover, fallbackURL: selected.coverURL, userAgentOverride: selected.userAgentOverride, playlistID: selected.playlistID) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFit()
                                        } else {
                                            Image(systemName: "tv")
                                                .font(.system(size: 40))
                                                .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                                        }
                                    }
                                    .frame(maxHeight: 100)
                                } else {
                                    Image(systemName: "tv")
                                        .font(.system(size: 48))
                                        .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                                }

                                Text(selected.title)
                                    .font(AppFonts.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                                    .lineLimit(1)
                            }
                        )

                    HStack(spacing: 6) {
                        Circle().fill(AppColors.live).frame(width: 8, height: 8)
                        Text(AppStrings.Player.liveLabel)
                            .font(AppFonts.captionSmall.weight(.heavy))
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.65), in: Capsule())
                    .padding(12)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(selected.title)
                                .font(AppFonts.title.weight(.bold))
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(1)

                            Text(AppStrings.Player.liveBroadcast)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                        }

                        Spacer()

                        Button {
                            HapticManager.shared.trigger(.medium)
                            store.send(.channelSelected(selected))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(AppFonts.bodySmall)
                                Text(AppStrings.Common.play)
                                    .font(AppFonts.bodySmall.weight(.bold))
                            }
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(AppColors.primary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Button {
                            store.send(.toggleFavorite(selected))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: store.favoriteIDs.contains(selected.id) ? "heart.fill" : "heart")
                                    .foregroundStyle(store.favoriteIDs.contains(selected.id) ? AppColors.destructive : AppColors.textPrimary)
                                Text(store.favoriteIDs.contains(selected.id) ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites)
                                    .font(AppFonts.captionSmall.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppColors.surfaceSecondary, in: Capsule())
                        }
                        .buttonStyle(.plain)

                        if !store.favoriteLists.isEmpty {
                            Menu(AppStrings.LiveTV.addToFavoriteList) {
                                ForEach(store.favoriteLists) { list in
                                    Button {
                                        store.send(.toggleNamedFavorite(selected, listID: list.id))
                                    } label: {
                                        Label(list.name, systemImage: list.channelIDs.contains(selected.id) ? "checkmark.circle.fill" : "circle")
                                    }
                                }
                            }
                        }

                        Button {
                            store.send(.sendToMultiView(selected))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "square.grid.2x2")
                                    .foregroundStyle(AppColors.textPrimary)
                                Text(AppStrings.LiveTV.sendToMultiView)
                                    .font(AppFonts.captionSmall.weight(.bold))
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(AppColors.surfaceSecondary, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(AppColors.surfaceContainer)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }

        // MARK: - EPG Schedule Section

        private var epgScheduleSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(AppStrings.LiveTV.channelGuide)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.textPrimary)
                    Spacer()
                    if store.isLoadingChannelEPG {
                        PureLoadingView(size: .small)
                    }
                }
                .padding(.horizontal, 20)

                if store.selectedChannelEPG.isEmpty, !store.isLoadingChannelEPG {
                    HStack {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "calendar.badge.clock")
                                .font(.system(size: 32))
                                .foregroundStyle(AppColors.textSecondary.opacity(0.3))
                            Text(AppStrings.Player.epgNotFound)
                                .font(AppFonts.caption)
                                .foregroundStyle(AppColors.textSecondary.opacity(0.5))
                        }
                        .padding(.vertical, 32)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 8) {
                        ForEach(store.selectedChannelEPG) { program in
                            epgProgramRow(program: program)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }

        private func epgProgramRow(program: EPGProgram) -> some View {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatTime(program.startTime))
                        .font(AppFonts.captionSmall.weight(.bold).monospacedDigit())
                        .foregroundStyle(program.isPlayingNow ? AppColors.primary : AppColors.textPrimary)
                    Text(formatTime(program.endTime))
                        .font(AppFonts.captionSmall.monospacedDigit())
                        .foregroundStyle(AppColors.textSecondary.opacity(0.6))
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(program.title)
                            .font(program.isPlayingNow ? AppFonts.bodySmall.weight(.bold) : AppFonts.bodySmall.weight(.medium))
                            .foregroundStyle(program.isPlayingNow ? AppColors.primary : AppColors.textPrimary)
                            .lineLimit(1)

                        if program.isPlayingNow {
                            Text(AppStrings.Player.nowPlaying.uppercased())
                                .font(AppFonts.captionSmall.weight(.heavy))
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(AppColors.primary, in: Capsule())
                        } else if store.selectedChannel?.tvArchive == 1, program.endTime < Date() {
                            CatchUpBadge(isCompact: true)
                        }
                    }

                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(AppFonts.captionSmall)
                            .foregroundStyle(AppColors.textSecondary.opacity(0.7))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                program.isPlayingNow ? AppColors.primary.opacity(0.14) : AppColors.surfaceSecondary.opacity(0.4),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(program.isPlayingNow ? AppColors.primary.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }

        private func formatTime(_ date: Date) -> String {
            LocalTimePresentation.string(from: date, locale: locale)
        }
    }
#endif
