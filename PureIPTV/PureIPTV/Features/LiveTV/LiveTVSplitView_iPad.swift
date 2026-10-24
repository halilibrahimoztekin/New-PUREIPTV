import ComposableArchitecture
import SwiftUI

#if os(iOS)
    public struct LiveTVSplitView_iPad: View {
        @Bindable var store: StoreOf<LiveTVFeature>
        let config: PlaylistConfig

        @State private var categorySearchQuery: String = ""
        @State private var channelSearchQuery: String = ""
        @State private var isSmartGroupManagerPresented = false

        public init(store: StoreOf<LiveTVFeature>, config: PlaylistConfig) {
            self.store = store
            self.config = config
        }

        private var filteredCategories: [MediaModels.Category] {
            if categorySearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return store.categories
            }
            return store.categories.filter { $0.name.localizedCaseInsensitiveContains(categorySearchQuery) }
        }

        private var filteredChannels: [MediaModels.Item] {
            let base = store.currentChannels
            if channelSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return base
            }
            return base.filter { $0.title.localizedCaseInsensitiveContains(channelSearchQuery) }
        }

        public var body: some View {
            HStack(spacing: 0) {
                categorySidebarView
                Divider().background(Color.white.opacity(0.15))
                channelListView
                Divider().background(Color.white.opacity(0.15))
                detailView
            }
            .sheet(isPresented: $isSmartGroupManagerPresented) {
                SmartChannelGroupManagementView(store: store)
            }
        }

        // MARK: - Column 1: Category Sidebar

        private var categorySidebarView: some View {
            VStack(spacing: 0) {
                HStack {
                    Text(AppStrings.LiveTV.categories)
                        .font(.title3.bold())
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        isSmartGroupManagerPresented = true
                    } label: {
                        Image(systemName: "square.stack.3d.up")
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(AppStrings.LiveTV.smartGroups)
                    .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)
                    Text("\(store.categories.count)")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.12), in: Capsule())
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                    TextField(AppStrings.Search.searchPlaceholder, text: $categorySearchQuery)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if !categorySearchQuery.isEmpty {
                        Button { categorySearchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                FavoriteChannelListSwitcher(store: store)
                    .padding(.bottom, 10)

                Divider().background(Color.white.opacity(0.15))

                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(store.smartChannelGroups) { group in
                            let isSelected = store.selectedSmartGroupID == group.id
                            Button {
                                store.send(.smartGroupSelected(group.id))
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isSelected ? "square.stack.3d.up.fill" : "square.stack.3d.up")
                                        .foregroundColor(isSelected ? .accentColor : .white.opacity(0.7))
                                    Text(group.name)
                                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                                        .lineLimit(1)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(isSelected ? Color.accentColor.opacity(0.18) : .clear, in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)
                        }
                        ForEach(filteredCategories) { category in
                            let isSelected = store.selectedCategoryID == category.id
                            Button {
                                HapticManager.shared.trigger(.light)
                                store.send(.categorySelected(category))
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: isSelected ? "folder.fill" : "folder")
                                        .font(.subheadline)
                                        .foregroundColor(isSelected ? .accentColor : .white.opacity(0.7))

                                    Text(category.name)
                                        .font(.subheadline.weight(isSelected ? .bold : .regular))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                                        .lineLimit(1)

                                    Spacer()

                                    if let count = store.channelsByCategory[category.id]?.count {
                                        Text("\(count)")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundColor(isSelected ? .white : .white.opacity(0.5))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(
                                                isSelected ? Color.accentColor.opacity(0.4) : Color.white.opacity(0.08),
                                                in: Capsule()
                                            )
                                    }
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(
                                    isSelected ? Color.accentColor.opacity(0.25) : Color.clear,
                                    in: RoundedRectangle(cornerRadius: 10)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
            .frame(width: 250)
            .background(Color(hex: "#121318"))
        }

        // MARK: - Column 2: Channel List

        private var channelListView: some View {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.categories.first(where: { $0.id == store.selectedCategoryID })?.name ?? AppStrings.LiveTV.channelsTitle)
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text("\(filteredChannels.count) \(AppStrings.LiveTV.channelsTitle.lowercased())")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button {
                            store.send(.openMultiViewTapped)
                        } label: {
                            Image(systemName: "square.split.2x2.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }

                        Button {
                            store.send(.openEPGTimelineTapped)
                        } label: {
                            Image(systemName: "calendar.day.timeline.left")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.85))
                                .frame(width: 32, height: 32)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))
                        .font(.caption)
                    TextField(AppStrings.Search.searchPlaceholder, text: $channelSearchQuery)
                        .font(.subheadline)
                        .foregroundColor(.white)
                    if !channelSearchQuery.isEmpty {
                        Button { channelSearchQuery = "" } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                                .font(.caption)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

                Divider().background(Color.white.opacity(0.15))

                if store.isLoadingChannels {
                    Spacer()
                    PureLoadingView(size: .medium)
                    Spacer()
                } else if filteredChannels.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "tv.slash")
                            .font(.system(size: 32))
                            .foregroundColor(.white.opacity(0.3))
                        Text(AppStrings.LiveTV.noChannels)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 6) {
                            ForEach(filteredChannels) { channel in
                                channelRow(channel: channel)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                }
            }
            .frame(width: 340)
            .background(Color(hex: "#181920"))
        }

        private func channelRow(channel: MediaModels.Item) -> some View {
            let isSelected = store.selectedChannel?.id == channel.id
            return Button {
                store.send(.selectChannelPreview(channel))
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)

                        if let coverURL = channel.displayLogoURL {
                            PlaylistAsyncImage(url: coverURL, userAgentOverride: channel.userAgentOverride) { phase in
                                if let image = phase.image {
                                    image.resizable().scaledToFit()
                                } else {
                                    Image(systemName: "tv").foregroundColor(.white.opacity(0.4))
                                }
                            }
                            .frame(width: 38, height: 38)
                        } else {
                            Image(systemName: "tv")
                                .foregroundColor(.white.opacity(0.4))
                        }
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(channel.title)
                            .font(.subheadline.weight(isSelected ? .bold : .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if store.favoriteIDs.contains(channel.id) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.red)
                            }

                            Text(AppStrings.LiveTV.title)
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    Button {
                        HapticManager.shared.trigger(.medium)
                        store.send(.channelSelected(channel))
                    } label: {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? .accentColor : .white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    isSelected ? Color.white.opacity(0.12) : Color.white.opacity(0.03),
                    in: RoundedRectangle(cornerRadius: 12)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
            .contextMenu {
                Button {
                    store.send(.toggleFavorite(channel))
                } label: {
                    if store.favoriteIDs.contains(channel.id) {
                        Label(AppStrings.Common.removeFromFavorites, systemImage: "heart.slash")
                    } else {
                        Label(AppStrings.Common.addToFavorites, systemImage: "heart")
                    }
                }

                if !store.favoriteLists.isEmpty {
                    Menu(AppStrings.LiveTV.addToFavoriteList) {
                        ForEach(store.favoriteLists) { list in
                            Button {
                                store.send(.toggleNamedFavorite(channel, listID: list.id))
                            } label: {
                                Label(list.name, systemImage: list.channelIDs.contains(channel.id) ? "checkmark.circle.fill" : "circle")
                            }
                        }
                    }
                }

                Button {
                    store.send(.sendToMultiView(channel))
                } label: {
                    Label(AppStrings.LiveTV.sendToMultiView, systemImage: "square.grid.2x2")
                }

                Button {
                    store.send(.openChannelEPG(channel))
                } label: {
                    Label(AppStrings.LiveTV.channelGuide, systemImage: "calendar.badge.clock")
                }

                Button(role: .destructive) {
                    store.send(.hideChannel(channel))
                } label: {
                    Label(AppStrings.LiveTV.hideChannel, systemImage: "eye.slash")
                }
            }
        }

        // MARK: - Column 3: Detail, Preview & EPG

        private var detailView: some View {
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
                            .foregroundColor(.white.opacity(0.3))
                        Text(AppStrings.LiveTV.noChannels)
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.5))
                    }
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(hex: "#0E0F14"))
        }

        private func heroCard(selected: MediaModels.Item) -> some View {
            VStack(alignment: .leading, spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#1C1D26"), Color(hex: "#12131A")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .aspectRatio(16 / 9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 12) {
                                if let cover = selected.displayLogoURL {
                                    PlaylistAsyncImage(url: cover, userAgentOverride: selected.userAgentOverride) { phase in
                                        if let img = phase.image {
                                            img.resizable().scaledToFit()
                                        } else {
                                            Image(systemName: "tv")
                                                .font(.system(size: 40))
                                                .foregroundColor(.white.opacity(0.3))
                                        }
                                    }
                                    .frame(maxHeight: 100)
                                } else {
                                    Image(systemName: "tv")
                                        .font(.system(size: 48))
                                        .foregroundColor(.white.opacity(0.3))
                                }

                                Text(selected.title)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                            }
                        )

                    HStack(spacing: 6) {
                        Circle().fill(Color.red).frame(width: 8, height: 8)
                        Text(AppStrings.Player.liveLabel)
                            .font(.system(size: 10, weight: .black, design: .rounded))
                            .foregroundColor(.white)
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
                                .font(.title2.bold())
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Text(AppStrings.Player.liveBroadcast)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.6))
                        }

                        Spacer()

                        Button {
                            HapticManager.shared.trigger(.medium)
                            store.send(.channelSelected(selected))
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.subheadline)
                                Text(AppStrings.Common.play)
                                    .font(.subheadline.bold())
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.accentColor, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Button {
                            store.send(.toggleFavorite(selected))
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: store.favoriteIDs.contains(selected.id) ? "heart.fill" : "heart")
                                    .foregroundColor(store.favoriteIDs.contains(selected.id) ? .red : .white)
                                Text(store.favoriteIDs.contains(selected.id) ? AppStrings.Common.removeFromFavorites : AppStrings.Common.addToFavorites)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08), in: Capsule())
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
                                    .foregroundColor(.white)
                                Text(AppStrings.LiveTV.sendToMultiView)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.08), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(hex: "#1A1B24"))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
            .padding(.top, 20)
        }

        private var epgScheduleSection: some View {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(AppStrings.LiveTV.channelGuide)
                        .font(.headline)
                        .foregroundColor(.white)
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
                                .foregroundColor(.white.opacity(0.3))
                            Text(AppStrings.Player.epgNotFound)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.5))
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
                        .font(.caption.bold().monospacedDigit())
                        .foregroundColor(program.isPlayingNow ? .accentColor : .white)
                    Text(formatTime(program.endTime))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(width: 50, alignment: .leading)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(program.title)
                            .font(.subheadline.weight(program.isPlayingNow ? .bold : .medium))
                            .foregroundColor(program.isPlayingNow ? .accentColor : .white)
                            .lineLimit(1)

                        if program.isPlayingNow {
                            Text(AppStrings.Player.nowPlaying.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(Color.accentColor, in: Capsule())
                        } else if store.selectedChannel?.tvArchive == 1, program.endTime < Date() {
                            CatchUpBadge(isCompact: true)
                        }
                    }

                    if !program.description.isEmpty {
                        Text(program.description)
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(12)
            .background(
                program.isPlayingNow ? Color.accentColor.opacity(0.12) : Color.white.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(program.isPlayingNow ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }

        private func formatTime(_ date: Date) -> String {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
#endif
