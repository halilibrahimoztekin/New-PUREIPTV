import ComposableArchitecture
import SwiftUI

// MARK: - Edge-Swipe Channel & Category Sidebar Drawer

public struct PlayerSidebarDrawer: View {
    @Bindable var store: StoreOf<PlayerFeature>
    let onClose: () -> Void

    @State private var selectedFilter: FilterType = .all
    @State private var searchQuery: String = ""
    @FocusState private var focusedItemID: String?

    private enum FilterType: Hashable {
        case all
        case history
        case category(String)
    }

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    public var body: some View {
        HStack(spacing: 0) {
            drawerContent
            #if os(tvOS)
                .frame(width: 560)
            #else
                .frame(width: min(360, UIScreen.main.bounds.width * 0.85))
            #endif
                .frame(maxHeight: .infinity)
                .background(
                    ZStack {
                        #if os(tvOS)
                            Color.black.opacity(0.85)
                        #else
                            Rectangle()
                                .fill(.ultraThinMaterial)
                            Color.black.opacity(0.4)
                        #endif
                    }
                )
                .overlay(
                    Rectangle()
                        .fill(Color.white.opacity(0.12))
                        .frame(width: 1),
                    alignment: .trailing
                )
            #if os(tvOS)
                .focusSection()
            #endif

            // Tap-outside overlay to dismiss
            Color.black.opacity(0.001)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .onTapGesture {
                    onClose()
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .transition(.move(edge: .leading).combined(with: .opacity))
        .onAppear {
            focusedItemID = store.item.id
        }
        .onChange(of: focusedItemID) { _, newID in
            if let newID, let ch = store.playlist?.first(where: { $0.id == newID }) {
                PrebufferingManager.shared.prepareChannel(url: ch.streamURL)
            }
        }
        #if os(tvOS)
        .onExitCommand {
            onClose()
        }
        #endif
    }

    // MARK: - Drawer Content

    private var drawerContent: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Search Bar
            searchBarView

            // Filter Tabs (All / History / Categories)
            filterTabsView

            Divider()
                .background(Color.white.opacity(0.15))

            // Channel List
            channelsListView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: "sidebar.leading")
            #if os(tvOS)
                .font(.system(size: 28, weight: .bold))
            #else
                .font(.title3.weight(.bold))
            #endif
                .foregroundStyle(Color(hex: "#0A84FF"))

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.LiveTV.channelsTitle)
                #if os(tvOS)
                    .font(.system(size: 26, weight: .bold))
                #else
                    .font(.headline.weight(.bold))
                #endif
                    .foregroundStyle(.white)

                let count = filteredChannels.count
                Text("\(count) " + "Kanal".localized)
                #if os(tvOS)
                    .font(.system(size: 16, weight: .medium))
                #else
                    .font(.caption)
                #endif
                    .foregroundStyle(.white.opacity(0.6))
            }

            Spacer()

            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                #if os(tvOS)
                    .font(.system(size: 28))
                #else
                    .font(.title3)
                #endif
                    .foregroundStyle(.white.opacity(0.75))
            }
            #if os(tvOS)
            .buttonStyle(TVCircleButtonStyle())
            #else
            .buttonStyle(.plain)
            #endif
        }
        #if os(tvOS)
        .padding(.horizontal, 32)
        .padding(.top, 40)
        .padding(.bottom, 16)
        #else
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 12)
        #endif
    }

    // MARK: - Search Bar

    private var searchBarView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.white.opacity(0.55))
            #if os(tvOS)
                .font(.system(size: 22))
            #else
                .font(.system(size: 15))
            #endif

            TextField(AppStrings.Search.channelSearchPlaceholder, text: $searchQuery)
            #if os(tvOS)
                .font(.system(size: 20, weight: .medium))
            #else
                .font(.system(size: 14, weight: .medium))
            #endif
                .foregroundStyle(.white)
                .tint(Color(hex: "#0A84FF"))

            if !searchQuery.isEmpty {
                Button {
                    searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.6))
                    #if os(tvOS)
                        .font(.system(size: 20))
                    #else
                        .font(.system(size: 15))
                    #endif
                }
                #if os(tvOS)
                .buttonStyle(TVCircleButtonStyle())
                #else
                .buttonStyle(.plain)
                #endif
            }
        }
        #if os(tvOS)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .padding(.horizontal, 32)
        .padding(.bottom, 16)
        #else
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
        #endif
    }

    // MARK: - Filter Tabs

    private var filterTabsView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                filterChip(title: "Tüm Kanallar".localized, type: .all, icon: "tv")

                if !store.zappingHistory.isEmpty {
                    filterChip(title: "Son İzlenenler".localized, type: .history, icon: "clock.arrow.circlepath")
                }

                // Unique Category Chips
                ForEach(availableCategories, id: \.self) { category in
                    filterChip(title: category, type: .category(category), icon: "folder")
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 32)
            .padding(.bottom, 18)
            #else
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            #endif
        }
    }

    @ViewBuilder
    private func filterChip(title: String, type: FilterType, icon: String) -> some View {
        let isSelected = selectedFilter == type

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.light)
            #endif
            withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
                selectedFilter = type
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? .white : .white.opacity(0.7))
            .background(
                Capsule()
                    .fill(isSelected ? Color(hex: "#0A84FF") : Color.white.opacity(0.12))
            )
            .overlay(
                Capsule()
                    .stroke(isSelected ? Color.white.opacity(0.4) : Color.white.opacity(0.1), lineWidth: 1)
            )
        }
        #if os(tvOS)
        .buttonStyle(TVFilterChipButtonStyle(isSelected: isSelected))
        #else
        .buttonStyle(.plain)
        #endif
    }

    // MARK: - Channels List

    private var channelsListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(Array(filteredChannels.enumerated()), id: \.element.id) { index, item in
                        channelRow(item: item, index: index + 1)
                            .id(item.id)
                    }
                }
                #if os(tvOS)
                .padding(.horizontal, 28)
                .padding(.vertical, 16)
                #else
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                #endif
            }
            .onAppear {
                // Scroll to currently playing channel
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        proxy.scrollTo(store.item.id, anchor: .center)
                    }
                }
            }
        }
    }

    // MARK: - Channel Row

    @ViewBuilder
    private func channelRow(item: PlayerFeature.PlayableItem, index: Int) -> some View {
        let isCurrent = item.id == store.item.id
        let isPrevious = item.id == store.previousChannel?.id

        Button {
            #if !os(tvOS)
                HapticManager.shared.trigger(.medium)
            #endif
            store.send(.selectChannel(item))
        } label: {
            HStack(spacing: 12) {
                // Index
                Text("\(index)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.45))
                    .frame(width: 32, alignment: .trailing)

                // Channel Logo
                channelLogo(item: item)

                // Channel Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                    #if os(tvOS)
                        .font(.system(size: 20, weight: isCurrent ? .bold : .medium))
                    #else
                        .font(.subheadline.weight(isCurrent ? .bold : .regular))
                    #endif
                        .foregroundStyle(isCurrent ? Color(hex: "#0A84FF") : .white)
                        .lineLimit(1)

                    if let epgID = item.epgChannelID {
                        Text(epgID)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Badges
                if isCurrent {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 7, height: 7)
                        Text(AppStrings.Player.liveLabel)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.18))
                    .clipShape(Capsule())
                } else if isPrevious {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.system(size: 10, weight: .bold))
                        Text(AppStrings.Player.recallLastChannel)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .foregroundStyle(.orange)
                    .background(Color.orange.opacity(0.18))
                    .clipShape(Capsule())
                }
            }
            #if os(tvOS)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            #else
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            #endif
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCurrent ? Color(hex: "#0A84FF").opacity(0.16) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCurrent ? Color(hex: "#0A84FF").opacity(0.5) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
        .focused($focusedItemID, equals: item.id)
    }

    // MARK: - Channel Logo

    @ViewBuilder
    private func channelLogo(item: PlayerFeature.PlayableItem) -> some View {
        Group {
            if let coverURL = item.coverURL {
                AsyncImage(url: coverURL) { phase in
                    switch phase {
                    case let .success(image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    case .empty:
                        ProgressView()
                            .scaleEffect(0.6)
                    case .failure:
                        fallbackLogo
                    @unknown default:
                        fallbackLogo
                    }
                }
            } else {
                fallbackLogo
            }
        }
        #if os(tvOS)
        .frame(width: 48, height: 48)
        #else
        .frame(width: 38, height: 38)
        #endif
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.15), lineWidth: 0.8)
        )
    }

    private var fallbackLogo: some View {
        Image(systemName: "tv")
            .font(.system(size: 16))
            .foregroundStyle(.white.opacity(0.5))
    }

    // MARK: - Filtered Channels & Categories

    private var filteredChannels: [PlayerFeature.PlayableItem] {
        let baseList: [PlayerFeature.PlayableItem] = switch selectedFilter {
        case .all:
            store.playlist ?? [store.item]
        case .history:
            store.zappingHistory
        case let .category(cat):
            (store.playlist ?? [store.item]).filter { $0.categoryID == cat }
        }

        let trimmed = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return baseList
        } else {
            return FuzzySearchEngine.search(baseList, titleKeyPath: \.title, query: trimmed, limit: 100)
        }
    }

    private var availableCategories: [String] {
        guard let list = store.playlist else { return [] }
        let categories = list.compactMap(\.categoryID).filter { !$0.isEmpty }
        var unique: [String] = []
        for cat in categories where !unique.contains(cat) {
            unique.append(cat)
        }
        return unique
    }
}

#if os(tvOS)
    private struct TVFilterChipButtonStyle: ButtonStyle {
        let isSelected: Bool

        func makeBody(configuration: Configuration) -> some View {
            TVFilterChipBody(configuration: configuration, isSelected: isSelected)
        }

        private struct TVFilterChipBody: View {
            let configuration: Configuration
            let isSelected: Bool
            @Environment(\.isFocused) private var isFocused

            var body: some View {
                configuration.label
                    .scaleEffect(isFocused ? 1.08 : 1.0)
                    .brightness(isFocused ? 0.15 : 0.0)
                    .shadow(
                        color: isFocused ? Color(hex: "#0A84FF").opacity(0.6) : .clear,
                        radius: isFocused ? 10 : 0,
                        x: 0,
                        y: 0
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
            }
        }
    }
#endif
