import ComposableArchitecture
import Observation
import SwiftUI
import SwiftVLC

#if os(tvOS)
    private enum MultiViewSlotFocusTarget: Hashable {
        case audio(Int)
        case aspectRatio(Int)
        case remove(Int)
        case channelTitle(Int)
        case companionSwap(Int)
        case emptySlot(Int)

        var slotID: Int {
            switch self {
            case let .audio(slotID), let .aspectRatio(slotID), let .remove(slotID),
                 let .channelTitle(slotID), let .companionSwap(slotID), let .emptySlot(slotID):
                slotID
            }
        }
    }
#endif

@MainActor
private final class MultiViewPlaybackSessionStore {
    private var sessions: [UUID: MultiViewPlaybackSession] = [:]
    private let clock = ContinuousClock()
    private var nextStartTime: ContinuousClock.Instant?

    func session(for instanceID: UUID) -> MultiViewPlaybackSession {
        if let session = sessions[instanceID] {
            return session
        }
        let session = MultiViewPlaybackSession()
        sessions[instanceID] = session
        return session
    }

    func synchronize(slots: [MultiViewSlot], activeAudioSlotID: Int?) {
        let activeSlots = slots.filter { $0.item != nil }
        let activeInstanceIDs = Set(activeSlots.map(\.instanceID))

        let inactiveInstanceIDs = sessions.keys.filter { !activeInstanceIDs.contains($0) }
        for instanceID in inactiveInstanceIDs {
            sessions.removeValue(forKey: instanceID)?.cancel()
        }

        for slot in activeSlots.sorted(by: { $0.selectionOrder < $1.selectionOrder }) {
            guard let item = slot.item else { continue }
            let session = session(for: slot.instanceID)
            let isActiveAudio = activeAudioSlotID == slot.id
            if session.isForInstance(slot.instanceID) {
                session.setAudioActive(isActiveAudio)
                continue
            }

            session.start(
                item: item,
                instanceID: slot.instanceID,
                isActiveAudio: isActiveAudio,
                delay: reserveStartDelay()
            )
        }
    }

    func cancelAll() {
        for session in sessions.values {
            session.cancel()
        }
        nextStartTime = nil
    }

    private func reserveStartDelay() -> Duration {
        let now = clock.now
        let scheduledStart = max(now, nextStartTime ?? now)
        nextStartTime = scheduledStart.advanced(by: .milliseconds(350))
        return now.duration(to: scheduledStart)
    }
}

@Observable
@MainActor
private final class MultiViewPlaybackSession {
    enum Status: Equatable {
        case idle
        case starting
        case buffering
        case ready
        case failed
    }

    private(set) var playerClient: PlayerClient?
    private(set) var status: Status = .idle

    @ObservationIgnored @Dependency(\.playerFactoryClient) private var playerFactoryClient
    @ObservationIgnored @Dependency(\.settingsClient) private var settingsClient
    @ObservationIgnored private var currentInstanceID: UUID?
    @ObservationIgnored private var playbackTask: Task<Void, Never>?
    @ObservationIgnored private var latestIsActiveAudio = false
    @ObservationIgnored private var hasStartedPlayback = false
    @ObservationIgnored private var volumeGeneration = UUID()
    @ObservationIgnored private var volumeUpdateTask: Task<Void, Never>?
    @ObservationIgnored private var playerRunGeneration = UUID()

    func isForInstance(_ instanceID: UUID) -> Bool {
        currentInstanceID == instanceID
    }

    func start(item: MediaModels.Item, instanceID: UUID, isActiveAudio: Bool, delay: Duration) {
        guard currentInstanceID != instanceID else {
            setAudioActive(isActiveAudio)
            return
        }

        let previousTask = playbackTask
        let previousClient = playerClient
        previousTask?.cancel()
        if let previousClient {
            Task { @MainActor in
                try? await previousClient.stop()
            }
        }
        currentInstanceID = instanceID
        latestIsActiveAudio = isActiveAudio
        hasStartedPlayback = false
        status = .starting
        let runGeneration = UUID()
        playerRunGeneration = runGeneration

        playbackTask = Task { @MainActor [weak self] in
            await previousTask?.value
            if delay > .zero {
                try? await Task.sleep(for: delay)
            }
            guard !Task.isCancelled, let self else { return }
            await runPlayer(item: item, instanceID: instanceID, runGeneration: runGeneration)
        }
    }

    func setAudioActive(_ active: Bool) {
        guard latestIsActiveAudio != active else { return }
        latestIsActiveAudio = active
        guard hasStartedPlayback, let playerClient else { return }
        enqueueVolumeUpdate(active, for: playerClient)
    }

    func cancel() {
        currentInstanceID = nil
        playerRunGeneration = UUID()
        status = .idle
        hasStartedPlayback = false
        let currentClient = playerClient
        playerClient = nil
        playbackTask?.cancel()
        volumeGeneration = UUID()
        volumeUpdateTask?.cancel()
        volumeUpdateTask = nil
        if let currentClient {
            Task { @MainActor in
                try? await currentClient.stop()
            }
        }
    }

    private func runPlayer(item: MediaModels.Item, instanceID: UUID, runGeneration: UUID) async {
        guard currentInstanceID == instanceID,
              playerRunGeneration == runGeneration,
              let url = item.streamURL
        else {
            if currentInstanceID == instanceID {
                status = .failed
            }
            return
        }

        let client = playerFactoryClient.createPlayer()
        playerClient = client

        do {
            try await client.setVolume(latestIsActiveAudio ? 100 : 0)
            let events = await client.events()
            let playbackContentKind: PlaybackContentKind = item.type == .live ? .live : .vod
            let playbackDefaults = settingsClient.playbackDefaults(playbackContentKind)
            _ = try await client.play(
                url,
                item.userAgentOverride,
                playbackDefaults.networkCachingMilliseconds(for: playbackContentKind),
                playbackDefaults.deinterlaceMode,
                .vlc,
                nil,
                playbackDefaults.preferredAudioLanguage,
                nil,
                playbackDefaults.preferredSubtitleLanguage
            )
            await client.setSubtitleTextScale(playbackDefaults.subtitleTextSize.scale)
            try await client.setVolume(latestIsActiveAudio ? 100 : 0)
            hasStartedPlayback = true

            if let position = item.resumePosition, position > 0, item.type != .live {
                try? await Task.sleep(for: .milliseconds(500))
                if !Task.isCancelled {
                    try? await client.seek(position)
                }
            }

            for await event in events {
                guard !Task.isCancelled,
                      currentInstanceID == instanceID,
                      playerRunGeneration == runGeneration
                else { break }

                switch event {
                case .encounteredError:
                    status = .failed
                case let .stateChanged(newState):
                    switch newState {
                    case .playing:
                        status = .ready
                    case .opening:
                        status = .starting
                    case .buffering:
                        status = .buffering
                    case .error:
                        status = .failed
                    default:
                        break
                    }
                default:
                    continue
                }

                if status == .failed {
                    break
                }
            }
        } catch {
            if !Task.isCancelled,
               currentInstanceID == instanceID,
               playerRunGeneration == runGeneration
            {
                status = .failed
            }
        }

        await stopPlayer(client, runGeneration: runGeneration)
        if playerRunGeneration == runGeneration {
            playerClient = nil
            if status != .failed {
                status = .idle
            }
        }
    }

    private func enqueueVolumeUpdate(_ active: Bool, for client: PlayerClient) {
        volumeGeneration = UUID()
        let generation = volumeGeneration
        let runGeneration = playerRunGeneration
        let previousTask = volumeUpdateTask
        previousTask?.cancel()
        volumeUpdateTask = Task { @MainActor [weak self] in
            await previousTask?.value
            guard let self,
                  !Task.isCancelled,
                  volumeGeneration == generation,
                  playerRunGeneration == runGeneration,
                  playerClient?.vlcPlayer() === client.vlcPlayer()
            else { return }
            try? await client.setVolume(active ? 100 : 0)
        }
    }

    private func stopPlayer(_ client: PlayerClient, runGeneration: UUID) async {
        if playerRunGeneration == runGeneration {
            hasStartedPlayback = false
            let task = volumeUpdateTask
            volumeUpdateTask = nil
            volumeGeneration = UUID()
            task?.cancel()
            await task?.value
        }
        try? await client.stop()
    }
}

// MARK: - MultiView View (1+3 Showcase Layout & Audio Swapping)

public struct MultiView: View {
    @Bindable var store: StoreOf<MultiViewFeature>
    @State private var playbackSessionStore = MultiViewPlaybackSessionStore()

    #if os(tvOS)
        @FocusState private var focusedSlotControl: MultiViewSlotFocusTarget?
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
        .background(AppColors.oledBlack.ignoresSafeArea())
        .onAppear { store.send(.onAppear) }
        .onDisappear {
            store.send(.onDisappear)
            playbackSessionStore.cancelAll()
        }
        .task(id: playbackSignature) {
            playbackSessionStore.synchronize(
                slots: visiblePlaybackSlots,
                activeAudioSlotID: store.activeAudioSlotID
            )
        }
        #if os(tvOS)
        .onExitCommand {
            if let focused = store.focusedSlotID {
                store.send(.toggleFullscreen(slotID: focused), animation: .spring(response: 0.3, dampingFraction: 0.7))
            } else {
                store.send(.delegate(.close))
            }
        }
        .onChange(of: focusedSlotControl) { _, target in
            guard let target else { return }
            store.send(.setAudioActive(slotID: target.slotID), animation: .spring(response: 0.28, dampingFraction: 0.75))
        }
        #endif
    }

    private var visiblePlaybackSlots: [MultiViewSlot] {
        if let focusedSlotID = store.focusedSlotID,
           let focusedSlot = store.slots.first(where: { $0.id == focusedSlotID })
        {
            return [focusedSlot]
        }
        return Array(store.slots.prefix(store.layoutMode.requiredSlotCount))
    }

    private var playbackSignature: String {
        visiblePlaybackSlots.map { slot in
            "\(slot.id):\(slot.item == nil ? "empty" : slot.instanceID.uuidString)"
        }.joined(separator: "|")
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
                        .font(AppFonts.captionSmall.weight(.bold))
                        .foregroundStyle(AppColors.primary)

                    Text(channel.title)
                        .font(AppFonts.captionSmall.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(AppColors.primary.opacity(0.18), in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(AppColors.primary.opacity(0.5), lineWidth: 1)
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
                    .foregroundStyle(store.isPiPActive ? AppColors.primary : Color.white.opacity(0.85))
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
                            .font(AppFonts.captionSmall.weight(.bold))
                        Text(mode.title)
                            .font(AppFonts.caption.weight((isSelected || isFocused) ? .bold : .medium))
                    }
                    .foregroundColor((isSelected || isFocused) ? .white : .white.opacity(0.6))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        isFocused
                            ? AppColors.primary
                            : (isSelected ? AppColors.primary.opacity(0.35) : Color.white.opacity(0.08)),
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .stroke(
                                isFocused
                                    ? Color.white
                                    : (isSelected ? AppColors.primary.opacity(0.7) : Color.clear),
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

    private func aspectRatioTitle(for mode: VideoAspectRatioMode) -> String {
        switch mode {
        case .fit: AppStrings.MultiView.aspectFit
        case .fill: AppStrings.MultiView.aspectFill
        case .stretch: AppStrings.MultiView.aspectStretch
        case .zoom: AppStrings.MultiView.aspectFit
        }
    }

    private func slotView(for slot: MultiViewSlot, isCompanion: Bool) -> some View {
        let isAudioActive = store.activeAudioSlotID == slot.id
        #if os(tvOS)
            let isFocused = focusedSlotControl?.slotID == slot.id
        #else
            let isFocused = false
        #endif

        return Group {
            if let item = slot.item {
                ZStack {
                    MultiViewPlayer(
                        aspectRatioMode: slot.aspectRatioMode,
                        isActiveAudio: isAudioActive,
                        isPiPActive: store.isPiPActive && isAudioActive,
                        session: playbackSessionStore.session(for: slot.instanceID),
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
                                        .font(AppFonts.captionSmall.weight(.bold))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    isAudioActive ? AppColors.primary.opacity(0.85) : Color.black.opacity(0.6),
                                    in: Capsule()
                                )
                                #if os(tvOS)
                                .overlay {
                                    Capsule()
                                        .stroke(focusedSlotControl == .audio(slot.id) ? Color.white : .clear, lineWidth: 2)
                                }
                                .scaleEffect(focusedSlotControl == .audio(slot.id) ? 1.08 : 1)
                                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedSlotControl == .audio(slot.id))
                                #endif
                            }
                            .buttonStyle(.plain)
                            #if os(tvOS)
                                .focused($focusedSlotControl, equals: .audio(slot.id))
                            #endif

                            Menu {
                                ForEach([VideoAspectRatioMode.fit, .fill, .stretch], id: \.rawValue) { mode in
                                    Button {
                                        store.send(.setAspectRatioMode(slotID: slot.id, mode: mode))
                                    } label: {
                                        if slot.aspectRatioMode == mode {
                                            Label(aspectRatioTitle(for: mode), systemImage: "checkmark")
                                        } else {
                                            Text(aspectRatioTitle(for: mode))
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: slot.aspectRatioMode.systemIcon)
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(7)
                                    .background(Color.black.opacity(0.68), in: Circle())
                            }
                            .accessibilityLabel(AppStrings.MultiView.aspectRatioControl)
                            .accessibilityValue(aspectRatioTitle(for: slot.aspectRatioMode))
                            #if os(tvOS)
                                .buttonStyle(TVCircleButtonStyle())
                                .focused($focusedSlotControl, equals: .aspectRatio(slot.id))
                            #else
                                .buttonStyle(.plain)
                            #endif

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
                                #if os(tvOS)
                                    .background(focusedSlotControl == .remove(slot.id) ? Color.white.opacity(0.18) : .clear, in: Circle())
                                    .overlay {
                                        Circle()
                                            .stroke(focusedSlotControl == .remove(slot.id) ? Color.white : .clear, lineWidth: 2)
                                    }
                                    .scaleEffect(focusedSlotControl == .remove(slot.id) ? 1.12 : 1)
                                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedSlotControl == .remove(slot.id))
                                #endif
                            }
                            .buttonStyle(.plain)
                            #if os(tvOS)
                                .focused($focusedSlotControl, equals: .remove(slot.id))
                            #endif
                        }
                        .padding(8)

                        Spacer()

                        HStack(alignment: .bottom) {
                            #if os(tvOS)
                                Button {
                                    store.send(.setAudioActive(slotID: slot.id), animation: .spring(response: 0.28, dampingFraction: 0.75))
                                } label: {
                                    Text(item.title)
                                        .font(.system(size: isCompanion ? 11 : 13, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                        .padding(.horizontal, 12)
                                        .frame(minHeight: 44)
                                        .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                                }
                                .buttonStyle(.plain)
                                .focused($focusedSlotControl, equals: .channelTitle(slot.id))
                            #else
                                Text(item.title)
                                    .font(.system(size: isCompanion ? 11 : 13, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 6))
                            #endif

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
                                            .font(AppFonts.captionSmall.weight(.bold))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppColors.premium.opacity(0.85), in: Capsule())
                                    .shadow(color: AppColors.premium.opacity(0.4), radius: 6)
                                    #if os(tvOS)
                                        .overlay {
                                            Capsule()
                                                .stroke(focusedSlotControl == .companionSwap(slot.id) ? Color.white : .clear, lineWidth: 2)
                                        }
                                        .scaleEffect(focusedSlotControl == .companionSwap(slot.id) ? 1.08 : 1)
                                        .animation(.spring(response: 0.25, dampingFraction: 0.75), value: focusedSlotControl == .companionSwap(slot.id))
                                    #endif
                                }
                                .buttonStyle(.plain)
                                #if os(tvOS)
                                    .focused($focusedSlotControl, equals: .companionSwap(slot.id))
                                #endif
                            }
                        }
                        .padding(8)
                    }
                }
                #if os(tvOS)
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
                            .foregroundStyle(AppColors.primary.opacity(0.7))
                        Text(AppStrings.MultiView.addChannel)
                            .font(AppFonts.caption.weight(.medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.surface)
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                    .focused($focusedSlotControl, equals: .emptySlot(slot.id))
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
                            : (isAudioActive ? AppColors.primary : Color.white.opacity(0.12)),
                        lineWidth: isFocused ? 3.5 : (isAudioActive ? 2.5 : 1.0)
                    )
                    .shadow(
                        color: isFocused
                            ? Color.white.opacity(0.6)
                            : (isAudioActive ? AppColors.primary.opacity(0.6) : Color.clear),
                        radius: isFocused ? 8 : (isAudioActive ? 6 : 0)
                    )
            )
            .scaleEffect(isFocused ? 1.025 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
        #else
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        isAudioActive ? AppColors.primary : Color.white.opacity(0.12),
                        lineWidth: isAudioActive ? 2.5 : 1.0
                    )
                    .shadow(
                        color: isAudioActive ? AppColors.primary.opacity(0.6) : Color.clear,
                        radius: isAudioActive ? 6 : 0
                    )
            )
        #endif
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: isAudioActive)
    }
}

// MARK: - Channel Selection Sheet

struct ChannelSelectionSheet: View {
    let state: MultiViewFeature.State
    let send: (MultiViewFeature.Action) -> Void
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
            state.episodeItems
        } else {
            switch selectedSource {
            case .live: state.channels
            case .movies: state.vodItems
            case .series: state.seriesItems
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

                if state.isLoadingSources || state.isLoadingEpisodes {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(filteredChannels) { channel in
                        Button {
                            if channel.type == .series, channel.streamURL == nil {
                                selectedSeries = channel
                                searchText = ""
                                send(.loadEpisodes(channel))
                            } else {
                                onSelect(channel)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                if let url = channel.displayLogoURL {
                                    PlaylistAsyncImage(url: url, fallbackURL: channel.coverURL, userAgentOverride: channel.userAgentOverride, playlistID: channel.playlistID) { phase in
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
                                send(.backFromEpisodes)
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
                        send(.backFromEpisodes)
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
    let aspectRatioMode: VideoAspectRatioMode
    let isActiveAudio: Bool
    let isPiPActive: Bool
    let session: MultiViewPlaybackSession
    let onRetry: () -> Void

    #if os(iOS)
        @State private var pipController: PiPController?
    #endif

    var body: some View {
        ZStack {
            if session.status == .failed {
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
            } else if let client = session.playerClient {
                #if os(iOS)
                    PiPVideoView(client.vlcPlayer(), controller: $pipController)
                        .scaleEffect(x: videoScaleX, y: videoScaleY)
                        .clipped()
                #else
                    VideoView(client.vlcPlayer())
                        .scaleEffect(x: videoScaleX, y: videoScaleY)
                        .clipped()
                #endif
            } else {
                Color.black
            }

            if session.status == .starting || session.status == .buffering {
                VStack(spacing: 6) {
                    ProgressView()
                        .tint(.white)
                    Text(AppStrings.Common.loading)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(10)
                .background(Color.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                .accessibilityElement(children: .combine)
            } else if session.status == .ready {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
                    .accessibilityHidden(true)
            }
        }
        .onAppear {
            session.setAudioActive(isActiveAudio)
        }
        .onChange(of: isActiveAudio) { _, active in
            session.setAudioActive(active)
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
        #if os(iOS)
        .onDisappear {
            pipController?.stop()
        }
        #endif
    }

    private var videoScaleX: CGFloat {
        switch aspectRatioMode {
        case .fit: 1
        case .fill, .zoom: 1.25
        case .stretch: 1.15
        }
    }

    private var videoScaleY: CGFloat {
        aspectRatioMode == .stretch ? 1 : videoScaleX
    }
}
