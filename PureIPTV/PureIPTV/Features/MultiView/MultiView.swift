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

                    // Dummy view to center the title
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 28))
                        .opacity(0)
                }
                .padding()

                // Grid
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
                } else {
                    // Mobile Portrait: Just stack them vertically or show only 2?
                    // Let's show 2 vertically to avoid them being too small.
                    VStack(spacing: 4) {
                        slotView(for: store.slots[0])
                        slotView(for: store.slots[1])
                    }
                    .padding(.horizontal, 4)
                    .padding(.bottom, 4)
                }
            }
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
                    instanceID: slot.instanceID
                )
                .onTapGesture {
                    store.send(.setAudioActive(slotID: slot.id))
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
        )
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
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Kanal ara...")
        }
    }
}

// MARK: - Independent Player View

private struct MultiViewPlayer: View {
    let item: MediaModels.Item
    let isActiveAudio: Bool
    let instanceID: UUID

    @State private var playerClient: PlayerClient?

    var body: some View {
        Group {
            if let client = playerClient {
                #if os(iOS)
                    VideoView(client.vlcPlayer())
                #else
                    VideoView(client.vlcPlayer())
                #endif
            } else {
                Color.black
            }
        }
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            Task {
                if let client = playerClient {
                    try? await client.stop()
                }
            }
        }
        .onChange(of: isActiveAudio) { _, newValue in
            Task {
                try? await playerClient?.setVolume(newValue ? 100 : 0)
            }
        }
        .onChange(of: instanceID) { _, _ in
            setupPlayer() // Reboot player if instanceID changes
        }
    }

    private func setupPlayer() {
        @Dependency(\.playerFactoryClient) var factory
        let client = factory.createPlayer()
        playerClient = client

        Task {
            if let url = item.streamURL {
                try? await client.play(url)
                try? await client.setVolume(isActiveAudio ? 100 : 0)
            }

            for await event in await client.events() {
                switch event {
                case let .stateChanged(state):
                    if state == PlayerState.stopped || state == PlayerState.error {
                        // Reconnect after a short delay
                        try? await Task.sleep(nanoseconds: 2_000_000_000)
                        if let url = item.streamURL {
                            try? await client.play(url)
                            try? await client.setVolume(isActiveAudio ? 100 : 0)
                        }
                    }
                case .encounteredError:
                    // Reconnect on error event as well
                    try? await Task.sleep(nanoseconds: 2_000_000_000)
                    if let url = item.streamURL {
                        try? await client.play(url)
                        try? await client.setVolume(isActiveAudio ? 100 : 0)
                    }
                default:
                    break
                }
            }
        }
    }
}
