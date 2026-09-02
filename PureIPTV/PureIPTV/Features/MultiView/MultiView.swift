import ComposableArchitecture
import FactoryKit
import SwiftUI
import SwiftVLC

public struct MultiView: View {
    @Bindable var store: StoreOf<MultiViewFeature>

    public init(store: StoreOf<MultiViewFeature>) {
        self.store = store
    }

    public var body: some View {
        GeometryReader { geo in
            let isLandscape = geo.size.width > geo.size.height
            #if os(tvOS)
                let isPad = true
            #else
                let isPad = UIDevice.current.userInterfaceIdiom == .pad
            #endif
            let columns = (isLandscape || isPad) ? 2 : 1

            VStack(spacing: 4) {
                // Top Bar
                HStack {
                    Button(action: {
                        store.send(.delegate(.close))
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(Color.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Multi-view")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Spacer()

                    // PiP Button
                    Button(action: {
                        store.send(.togglePiP, animation: .spring(response: 0.3, dampingFraction: 0.7))
                    }) {
                        Image(systemName: store.isPiPActive ? "pip.exit" : "pip.enter")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.trailing, 8)
                    }
                    .buttonStyle(.plain)
                }
                .padding()

                // Grid
                if let focusedID = store.focusedSlotID, let slot = store.slots.first(where: { $0.id == focusedID }) {
                    slotView(for: slot)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .scale))
                        .id("fullscreen_\(focusedID)")
                } else {
                    if columns == 2 {
                        VStack(spacing: 4) {
                            HStack(spacing: 4) {
                                slotView(for: store.slots[0])
                                slotView(for: store.slots[1])
                            }
                            HStack(spacing: 4) {
                                slotView(for: store.slots[2])
                                slotView(for: store.slots[3])
                            }
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .scale))
                    } else {
                        VStack(spacing: 4) {
                            slotView(for: store.slots[0])
                            slotView(for: store.slots[1])
                        }
                        .padding(.horizontal, 4)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .scale))
                    }
                }
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.focusedSlotID)
        }
        .background(Color.black.ignoresSafeArea())
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
                channels: store.channels,
                onSelect: { store.send(.channelSelected($0)) }
            )
            .presentationDetents([.medium, .large])
        }
    }

    private func slotView(for slot: MultiViewSlot) -> some View {
        ZStack {
            if let item = slot.item {
                MultiViewPlayer(
                    item: item,
                    isActiveAudio: store.activeAudioSlotID == slot.id,
                    isPiPActive: store.isPiPActive && store.activeAudioSlotID == slot.id,
                    instanceID: slot.instanceID
                )
                .onTapGesture(count: 2) {
                    store.send(.toggleFullscreen(slotID: slot.id), animation: .spring(response: 0.3, dampingFraction: 0.7))
                }
                .onTapGesture(count: 1) {
                    store.send(.setAudioActive(slotID: slot.id), animation: .spring(response: 0.3, dampingFraction: 0.7))
                }

                // Overlays
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            store.send(.removeChannelTapped(slotID: slot.id))
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(8)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                    HStack {
                        Text(item.title)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.6).cornerRadius(4))
                            .padding(8)

                        Spacer()

                        Image(systemName: store.activeAudioSlotID == slot.id ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(store.activeAudioSlotID == slot.id ? Color(hex: "#0A84FF") : .white.opacity(0.5))
                            .padding(8)
                    }
                }

            } else {
                // Empty state
                Button(action: {
                    store.send(.selectChannelTapped(slotID: slot.id))
                }) {
                    VStack {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 40))
                            .foregroundStyle(Color.white.opacity(0.4))
                        Text("Kanal Ekle")
                            .font(.caption)
                            .foregroundStyle(Color.white.opacity(0.4))
                            .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "#1F1F23"))
                }
                .buttonStyle(.plain)
            }
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(store.activeAudioSlotID == slot.id ? Color(hex: "#0A84FF") : Color.clear, lineWidth: 2)
                .shadow(color: store.activeAudioSlotID == slot.id ? Color(hex: "#0A84FF").opacity(0.5) : Color.clear, radius: 4)
        )
        .scaleEffect(store.activeAudioSlotID == slot.id && store.focusedSlotID == nil ? 1.01 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.activeAudioSlotID)
        .clipped()
    }
}

// MARK: - Channel Selection Sheet

private struct ChannelSelectionSheet: View {
    let channels: [MediaModels.Item]
    let onSelect: (MediaModels.Item) -> Void

    @State private var searchText = ""

    var filteredChannels: [MediaModels.Item] {
        if searchText.isEmpty {
            return channels
        }
        return channels.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List(filteredChannels) { channel in
                Button(action: { onSelect(channel) }) {
                    HStack {
                        if let url = channel.coverURL {
                            AsyncImage(url: url) { img in
                                img.resizable().aspectRatio(contentMode: .fit).frame(width: 30, height: 30)
                            } placeholder: {
                                Image(systemName: "tv").frame(width: 30, height: 30)
                            }
                        } else {
                            Image(systemName: "tv").frame(width: 30, height: 30)
                        }
                        Text(channel.title)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Kanal Seç")
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .searchable(text: $searchText, prompt: "Kanal ara...")
        }
    }
}

// MARK: - Independent Player View

private struct MultiViewPlayer: View {
    let item: MediaModels.Item
    let isActiveAudio: Bool
    let isPiPActive: Bool
    let instanceID: UUID

    @State private var playerClient: PlayerClient?
    #if os(iOS)
        @State private var pipController: PiPController?
    #endif

    var body: some View {
        Group {
            if let client = playerClient {
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
        .task(id: isActiveAudio) {
            try? await playerClient?.setVolume(isActiveAudio ? 100 : 0)
        }
        .onChange(of: isPiPActive) { _, newValue in
            #if os(iOS)
                if newValue {
                    pipController?.start()
                } else {
                    pipController?.stop()
                }
            #endif
        }
    }

    private func runPlayer() async {
        @Dependency(\.playerFactoryClient) var factory

        while !Task.isCancelled {
            let client = factory.createPlayer()
            playerClient = client

            if let url = item.streamURL {
                try? await client.play(url)
                try? await client.setVolume(isActiveAudio ? 100 : 0)
            }

            var needsRecreate = false
            for await event in await client.events() {
                if Task.isCancelled {
                    break
                }
                switch event {
                case let .stateChanged(state):
                    if state == PlayerState.stopped || state == PlayerState.error {
                        needsRecreate = true
                    }
                case .encounteredError:
                    needsRecreate = true
                default:
                    break
                }
                if needsRecreate {
                    break
                }
            }

            if Task.isCancelled {
                break
            }

            // Clean up old client and retry after delay
            try? await client.stop()
            playerClient = nil
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        try? await playerClient?.stop()
    }
}
