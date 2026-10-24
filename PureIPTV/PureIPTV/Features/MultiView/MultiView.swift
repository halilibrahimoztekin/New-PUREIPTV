import ComposableArchitecture
import SwiftUI
import SwiftVLC

// MARK: - MultiView View (1+3 Showcase Layout & Audio Swapping)

public struct MultiView: View {
    @Bindable var store: StoreOf<MultiViewFeature>

    #if os(tvOS)
        @FocusState private var tvFocusedSlotID: Int?
        @FocusState private var focusedLayoutMode: MultiViewLayoutMode?
        @FocusState private var isCloseFocused: Bool
        @FocusState private var isPiPFocused: Bool
    #endif

    public init(store: StoreOf<MultiViewFeature>) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            #if os(tvOS)
                let isPadOrTV = true
            #else
                let isPadOrTV = UIDevice.current.userInterfaceIdiom == .pad || isLandscape
            #endif

            VStack(spacing: 8) {
                // Top Navigation Bar & Layout Mode Switcher
                topBar

                // Canvas Grid with 1+3 Showcase, 2x2 Grid or 1+1 Dual
                GeometryReader { canvasGeo in
                    let w = canvasGeo.size.width
                    let h = canvasGeo.size.height
                    let isValid = w.isFinite && h.isFinite && w > 20 && h > 20

                    if isValid {
                        layoutCanvas(width: w, height: h, isPadOrTV: isPadOrTV)
                    } else {
                        Color.clear
                    }
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 6)
            }
        }
        .background(Color(hex: "#000000").ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
        .onDisappear { store.send(.onDisappear) }
        #if os(tvOS)
            .onExitCommand {
                if let focused = store.focusedSlotID {
                    store.send(.toggleFullscreen(slotID: focused), animation: .spring(response: 0.3, dampingFraction: 0.7))
                } else {
                    store.send(.delegate(.close))
                }
            }
            .onChange(of: tvFocusedSlotID) { _, newID in
                if let id = newID {
                    store.send(.setAudioActive(slotID: id), animation: .spring(response: 0.28, dampingFraction: 0.75))
                }
            }
        #endif
            .sheet(
                isPresented: Binding(
                    get: { store.isSelectingChannelForSlotID != nil },
                    set: {
                        if !$0 {
                            store.send(.channelSelectionDismissed)
                        }
                    }
                )
            ) {
                ChannelSelectionSheet(
                    store: store,
                    onSelect: { store.send(.channelSelected($0)) },
                    onDismiss: { store.send(.channelSelectionDismissed) }
                )
                .presentationDetents([.medium, .large])
            }
    }

    // MARK: - Top Navigation Bar

    private var topBar: some View {
        HStack(spacing: 16) {
            // Close Button
            Button(action: {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                store.send(.delegate(.close))
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Color.white.opacity(0.85))
            }
            #if os(tvOS)
            .buttonStyle(TVCircleButtonStyle())
            .focused($isCloseFocused)
            #else
            .buttonStyle(.plain)
            #endif

            // Layout Mode Switcher Pills
            layoutSwitcherPills

            Spacer()

            // Active Audio Solo Indicator
            if let activeID = store.activeAudioSlotID,
               let activeSlot = store.slots.first(where: { $0.id == activeID }),
               let channel = activeSlot.item
            {
                HStack(spacing: 6) {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Color(hex: "#0A84FF"))

                    Text(channel.title)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color(hex: "#0A84FF").opacity(0.18), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color(hex: "#0A84FF").opacity(0.5), lineWidth: 1)
                )
                .transition(.opacity)
                .animation(.spring(response: 0.3, dampingFraction: 0.75), value: store.activeAudioSlotID)
            }

            // PiP Button
            Button(action: {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                store.send(.togglePiP, animation: .spring(response: 0.3, dampingFraction: 0.7))
            }) {
                Image(systemName: store.isPiPActive ? "pip.exit" : "pip.enter")
                    .font(.system(size: 22))
                    .foregroundStyle(store.isPiPActive ? Color(hex: "#0A84FF") : Color.white.opacity(0.85))
            }
            #if os(tvOS)
            .buttonStyle(TVCircleButtonStyle())
            .focused($isPiPFocused)
            #else
            .buttonStyle(.plain)
            #endif
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    // MARK: - Layout Mode Switcher Pills

    private var layoutSwitcherPills: some View {
        HStack(spacing: 6) {
            ForEach(MultiViewLayoutMode.allCases) { mode in
                let isSelected = store.layoutMode == mode
                #if os(tvOS)
                    let isFocused = focusedLayoutMode == mode
                #else
                    let isFocused = false
                #endif

                Button {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.setLayoutMode(mode), animation: .spring(response: 0.32, dampingFraction: 0.75))
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: mode.iconName)
                            .font(.system(size: 13, weight: .bold))
                        Text(mode.title)
                            .font(.system(size: 13, weight: (isSelected || isFocused) ? .bold : .medium))
                    }
                    .foregroundColor((isSelected || isFocused) ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        isFocused
                            ? Color(hex: "#0A84FF")
                            : (isSelected ? Color(hex: "#0A84FF").opacity(0.35) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isFocused
                                    ? Color.white
                                    : (isSelected ? Color(hex: "#0A84FF").opacity(0.7) : Color.clear),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                    .focused($focusedLayoutMode, equals: mode)
                    .scaleEffect(isFocused ? 1.06 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                #endif
            }
        }
    }

    // MARK: - Layout Canvas Engine

    @ViewBuilder
    private func layoutCanvas(width: CGFloat, height: CGFloat, isPadOrTV: Bool) -> some View {
        let spacing: CGFloat = 6

        if let fullscreenSlotID = store.focusedSlotID,
           let slot = store.slots.first(where: { $0.id == fullscreenSlotID })
        {
            // Fullscreen Mode
            slotView(for: slot, isCompanion: false)
                .frame(width: width, height: height)
                .transition(.scale(scale: 0.95).combined(with: .opacity))
        } else {
            switch store.layoutMode {
            case .showcase1Plus3:
                showcaseLayout(width: width, height: height, spacing: spacing, isPadOrTV: isPadOrTV)
            case .grid2x2:
                grid2x2Layout(width: width, height: height, spacing: spacing)
            case .dual1Plus1:
                dualLayout(width: width, height: height, spacing: spacing, isPadOrTV: isPadOrTV)
            }
        }
    }

    // MARK: - 1+3 Showcase Layout

    @ViewBuilder
    private func showcaseLayout(width: CGFloat, height: CGFloat, spacing: CGFloat, isPadOrTV: Bool) -> some View {
        let primaryID = store.primarySlotID
        let primarySlot = store.slots.first(where: { $0.id == primaryID }) ?? store.slots[0]
        let companionSlots = store.slots.filter { $0.id != primaryID }

        if isPadOrTV {
            // Horizontal split: 73% Main Showcase + 27% 3-item Sidebar
            let primaryWidth = max(10, width * 0.73 - spacing / 2)
            let companionWidth = max(10, width * 0.27 - spacing / 2)
            let companionCount = max(1, companionSlots.count)
            let companionHeight = max(10, (height - spacing * CGFloat(companionCount - 1)) / CGFloat(companionCount))

            HStack(spacing: spacing) {
                // Primary Showcase Screen (Large)
                slotView(for: primarySlot, isCompanion: false)
                    .frame(width: primaryWidth, height: height)

                // 3 Companion Sub-screens (Vertical Stack)
                VStack(spacing: spacing) {
                    ForEach(companionSlots.prefix(3)) { subSlot in
                        slotView(for: subSlot, isCompanion: true)
                            .frame(width: companionWidth, height: companionHeight)
                    }
                }
                .frame(width: companionWidth, height: height)
            }
        } else {
            // Mobile Portrait: Top 60% Main + Bottom 40% Horizontal Scrollable Companions
            let primaryHeight = max(10, height * 0.60 - spacing / 2)
            let companionHeight = max(10, height * 0.40 - spacing / 2)
            let companionWidth = max(10, (width - spacing * 2) / 2)

            VStack(spacing: spacing) {
                slotView(for: primarySlot, isCompanion: false)
                    .frame(width: width, height: primaryHeight)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: spacing) {
                        ForEach(companionSlots.prefix(3)) { subSlot in
                            slotView(for: subSlot, isCompanion: true)
                                .frame(width: companionWidth, height: companionHeight)
                        }
                    }
                }
                .frame(width: width, height: companionHeight)
            }
        }
    }

    // MARK: - 2x2 Quad Grid Layout

    @ViewBuilder
    private func grid2x2Layout(width: CGFloat, height: CGFloat, spacing: CGFloat) -> some View {
        let itemWidth = max(10, (width - spacing) / 2)
        let itemHeight = max(10, (height - spacing) / 2)

        VStack(spacing: spacing) {
            HStack(spacing: spacing) {
                if store.slots.count > 0 {
                    slotView(for: store.slots[0], isCompanion: false).frame(width: itemWidth, height: itemHeight)
                }
                if store.slots.count > 1 {
                    slotView(for: store.slots[1], isCompanion: false).frame(width: itemWidth, height: itemHeight)
                }
            }
            HStack(spacing: spacing) {
                if store.slots.count > 2 {
                    slotView(for: store.slots[2], isCompanion: false).frame(width: itemWidth, height: itemHeight)
                }
                if store.slots.count > 3 {
                    slotView(for: store.slots[3], isCompanion: false).frame(width: itemWidth, height: itemHeight)
                }
            }
        }
    }

    // MARK: - 1+1 Dual Split Layout

    @ViewBuilder
    private func dualLayout(width: CGFloat, height: CGFloat, spacing: CGFloat, isPadOrTV: Bool) -> some View {
        if isPadOrTV {
            let itemWidth = max(10, (width - spacing) / 2)
            HStack(spacing: spacing) {
                if store.slots.count > 0 {
                    slotView(for: store.slots[0], isCompanion: false).frame(width: itemWidth, height: height)
                }
                if store.slots.count > 1 {
                    slotView(for: store.slots[1], isCompanion: false).frame(width: itemWidth, height: height)
                }
            }
        } else {
            let itemHeight = max(10, (height - spacing) / 2)
            VStack(spacing: spacing) {
                if store.slots.count > 0 {
                    slotView(for: store.slots[0], isCompanion: false).frame(width: width, height: itemHeight)
                }
                if store.slots.count > 1 {
                    slotView(for: store.slots[1], isCompanion: false).frame(width: width, height: itemHeight)
                }
            }
        }
    }

    // MARK: - Slot View with Audio Swapping & Primary Promote

    private func slotView(for slot: MultiViewSlot, isCompanion: Bool) -> some View {
        let isAudioActive = store.activeAudioSlotID == slot.id
        #if os(tvOS)
            let isFocused = tvFocusedSlotID == slot.id
        #else
            let isFocused = false
        #endif

        return Group {
            if let item = slot.item {
                ZStack {
                    MultiViewPlayer(
                        item: item,
                        isActiveAudio: isAudioActive,
                        isPiPActive: store.isPiPActive && isAudioActive,
                        instanceID: slot.instanceID,
                        onRetry: { store.send(.retrySlotTapped(slotID: slot.id)) }
                    )
                    .contentShape(Rectangle())
                    .onTapGesture {
                        #if !os(tvOS)
                            HapticManager.shared.trigger(.light)
                        #endif
                        store.send(.setAudioActive(slotID: slot.id), animation: .spring(response: 0.28, dampingFraction: 0.75))
                    }

                    // Slot controls are sibling controls over the video surface,
                    // so their actions remain reachable without nested Buttons.
                    VStack {
                        HStack {
                            Button {
                                store.send(.setAudioActive(slotID: slot.id), animation: .spring(response: 0.28, dampingFraction: 0.75))
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: isAudioActive ? "speaker.wave.3.fill" : "speaker.slash.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text(isAudioActive ? AppStrings.MultiView.audioActive : AppStrings.MultiView.audioMuted)
                                        .font(.system(size: 10, weight: .bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    isAudioActive ? Color(hex: "#0A84FF").opacity(0.85) : Color.black.opacity(0.6),
                                    in: Capsule()
                                )
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                #if !os(tvOS)
                                    HapticManager.shared.trigger(.light)
                                #endif
                                store.send(.removeChannelTapped(slotID: slot.id))
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .padding(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(8)

                        Spacer()

                        HStack(alignment: .bottom) {
                            Text(item.title)
                                .font(.system(size: isCompanion ? 11 : 13, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))

                            Spacer()

                            if isCompanion {
                                Button {
                                    #if !os(tvOS)
                                        HapticManager.shared.trigger(.medium)
                                    #endif
                                    store.send(.swapToPrimary(slotID: slot.id), animation: .spring(response: 0.35, dampingFraction: 0.75))
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                                            .font(.system(size: 10, weight: .bold))
                                        Text(AppStrings.MultiView.swapToPrimary)
                                            .font(.system(size: 10, weight: .bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(hex: "#BF5AF2").opacity(0.85), in: Capsule())
                                    .shadow(color: Color(hex: "#BF5AF2").opacity(0.4), radius: 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                    }
                }
                #if os(tvOS)
                .focusable()
                .focused($tvFocusedSlotID, equals: slot.id)
                .onPlayPauseCommand {
                    if isCompanion {
                        store.send(.swapToPrimary(slotID: slot.id), animation: .spring(response: 0.35, dampingFraction: 0.75))
                    } else {
                        store.send(.toggleFullscreen(slotID: slot.id), animation: .spring(response: 0.3, dampingFraction: 0.7))
                    }
                }
                #endif
            } else {
                // Empty Slot Placeholder with + Button
                Button(action: {
                    #if !os(tvOS)
                        HapticManager.shared.trigger(.light)
                    #endif
                    store.send(.selectChannelTapped(slotID: slot.id))
                }) {
                    VStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: isCompanion ? 28 : 42))
                            .foregroundStyle(Color(hex: "#0A84FF").opacity(0.7))
                        Text(AppStrings.MultiView.addChannel)
                            .font(.system(size: isCompanion ? 11 : 13, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "#0C0C10"))
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                    .focused($tvFocusedSlotID, equals: slot.id)
                #endif
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        #if os(tvOS)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isFocused
                            ? Color.white
                            : (isAudioActive ? Color(hex: "#0A84FF") : Color.white.opacity(0.12)),
                        lineWidth: isFocused ? 3.5 : (isAudioActive ? 2.5 : 1.0)
                    )
                    .shadow(
                        color: isFocused
                            ? Color.white.opacity(0.6)
                            : (isAudioActive ? Color(hex: "#0A84FF").opacity(0.6) : Color.clear),
                        radius: isFocused ? 8 : (isAudioActive ? 6 : 0)
                    )
            )
            .scaleEffect(isFocused ? 1.025 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        #else
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isAudioActive ? Color(hex: "#0A84FF") : Color.white.opacity(0.12),
                        lineWidth: isAudioActive ? 2.5 : 1.0
                    )
                    .shadow(
                        color: isAudioActive ? Color(hex: "#0A84FF").opacity(0.6) : Color.clear,
                        radius: isAudioActive ? 6 : 0
                    )
            )
        #endif
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isAudioActive)
    }
}

// MARK: - Channel Selection Sheet

private struct ChannelSelectionSheet: View {
    let store: StoreOf<MultiViewFeature>
    let onSelect: (MediaModels.Item) -> Void
    let onDismiss: () -> Void

    @State private var searchText = ""
    @State private var selectedSource: Source = .live
    @State private var selectedSeries: MediaModels.Item?

    private enum Source: String, CaseIterable, Hashable, Identifiable {
        case live
        case movies
        case series

        var id: Self {
            self
        }

        var title: String {
            switch self {
            case .live: AppStrings.Search.liveTV
            case .movies: AppStrings.Search.movies
            case .series: AppStrings.Search.series
            }
        }
    }

    var filteredChannels: [MediaModels.Item] {
        let items: [MediaModels.Item] = if selectedSeries != nil {
            store.episodeItems
        } else {
            switch selectedSource {
            case .live: store.channels
            case .movies: store.vodItems
            case .series: store.seriesItems
            }
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return items
        }
        return FuzzySearchEngine.searchItems(items, query: trimmed, limit: 100)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if selectedSeries == nil {
                    Picker(AppStrings.MultiView.selectChannel, selection: $selectedSource) {
                        ForEach(Source.allCases) { source in
                            Text(source.title).tag(source)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                }

                if store.isLoadingSources || store.isLoadingEpisodes {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredChannels) { channel in
                        Button {
                            if channel.type == .series, channel.streamURL == nil {
                                selectedSeries = channel
                                searchText = ""
                                store.send(.loadEpisodes(channel))
                            } else {
                                onSelect(channel)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if let url = channel.displayLogoURL {
                                    PlaylistAsyncImage(url: url, userAgentOverride: channel.userAgentOverride) { phase in
                                        if let img = phase.image {
                                            img.resizable().aspectRatio(contentMode: .fit).frame(width: 34, height: 34)
                                        } else {
                                            Image(systemName: "tv").frame(width: 34, height: 34)
                                        }
                                    }
                                } else {
                                    Image(systemName: "tv").frame(width: 34, height: 34)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(channel.title)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(selectedSeries?.title ?? AppStrings.MultiView.selectChannel)
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    if selectedSeries != nil {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button(AppStrings.Common.back) {
                                selectedSeries = nil
                                searchText = ""
                                store.send(.backFromEpisodes)
                            }
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel) {
                            onDismiss()
                        }
                    }
                }
                .searchable(text: $searchText, prompt: AppStrings.Common.search)
            #if os(tvOS)
                .onExitCommand {
                    if selectedSeries != nil {
                        selectedSeries = nil
                        store.send(.backFromEpisodes)
                    } else {
                        onDismiss()
                    }
                }
            #endif
        }
    }
}

// MARK: - Independent Player View

private struct MultiViewPlayer: View {
    let item: MediaModels.Item
    let isActiveAudio: Bool
    let isPiPActive: Bool
    let instanceID: UUID
    let onRetry: () -> Void

    @State private var playerClient: PlayerClient?
    @State private var playbackFailed = false
    @State private var latestIsActiveAudio = false
    @State private var hasStartedPlayback = false
    @State private var volumeGeneration = UUID()
    @State private var volumeUpdateTask: Task<Void, Never>?
    @State private var playerRunGeneration = UUID()
    #if os(iOS)
        @State private var pipController: PiPController?
    #endif

    var body: some View {
        Group {
            if playbackFailed {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.orange)
                        .accessibilityHidden(true)
                    Button(AppStrings.Common.retry, action: onRetry)
                        .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            } else if let client = playerClient {
                #if os(iOS)
                    PiPVideoView(client.vlcPlayer(), controller: $pipController)
                #else
                    VideoView(client.vlcPlayer())
                #endif
            } else {
                Color.black
            }
        }
        .task(id: instanceID) {
            await runPlayer()
        }
        .onChange(of: isActiveAudio) { _, active in
            latestIsActiveAudio = active
            guard hasStartedPlayback, let client = playerClient else { return }
            enqueueVolumeUpdate(active, for: client)
        }
        .onChange(of: isPiPActive) { _, newValue in
            #if os(iOS)
                if newValue {
                    _ = pipController?.start()
                } else {
                    pipController?.stop()
                }
            #endif
        }
    }

    private func runPlayer() async {
        @Dependency(\.playerFactoryClient) var factory
        await cancelVolumeUpdates()
        let runGeneration = UUID()
        playerRunGeneration = runGeneration
        playbackFailed = false
        hasStartedPlayback = false
        latestIsActiveAudio = isActiveAudio
        let client = factory.createPlayer()
        playerClient = client

        guard let url = item.streamURL else {
            playerClient = nil
            return
        }

        do {
            // Establish mute before starting transport so a companion stream
            // cannot briefly become audible during decoder startup.
            try await client.setVolume(latestIsActiveAudio ? 100 : 0)
            let events = await client.events()
            try await client.play(url, item.userAgentOverride, nil)
            try await client.setVolume(latestIsActiveAudio ? 100 : 0)
            hasStartedPlayback = true
            if let position = item.resumePosition, position > 0, item.type != .live {
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                try? await client.seek(position)
            }
            for await event in events {
                guard !Task.isCancelled else { break }
                switch event {
                case .encounteredError, .stateChanged(.error):
                    playbackFailed = true
                default:
                    continue
                }
                break
            }
        } catch {
            guard !Task.isCancelled else {
                await stopPlayer(client, runGeneration: runGeneration)
                clearPlayerClient(ifMatching: client)
                return
            }
            playbackFailed = true
        }
        await stopPlayer(client, runGeneration: runGeneration)
        if !Task.isCancelled {
            clearPlayerClient(ifMatching: client)
        }
    }

    private func enqueueVolumeUpdate(_ active: Bool, for client: PlayerClient) {
        volumeGeneration = UUID()
        let generation = volumeGeneration
        let runGeneration = playerRunGeneration
        let previousTask = volumeUpdateTask
        previousTask?.cancel()
        volumeUpdateTask = Task { @MainActor in
            await previousTask?.value
            guard
                !Task.isCancelled,
                volumeGeneration == generation,
                playerRunGeneration == runGeneration,
                playerClient?.vlcPlayer() === client.vlcPlayer()
            else { return }
            try? await client.setVolume(active ? 100 : 0)
        }
    }

    private func cancelVolumeUpdates() async {
        volumeGeneration = UUID()
        let task = volumeUpdateTask
        volumeUpdateTask = nil
        task?.cancel()
        await task?.value
    }

    private func stopPlayer(_ client: PlayerClient, runGeneration: UUID) async {
        if playerRunGeneration == runGeneration {
            hasStartedPlayback = false
            await cancelVolumeUpdates()
        }
        try? await client.stop()
    }

    private func clearPlayerClient(ifMatching client: PlayerClient) {
        guard let current = playerClient, current.vlcPlayer() === client.vlcPlayer() else { return }
        playerClient = nil
    }
}
