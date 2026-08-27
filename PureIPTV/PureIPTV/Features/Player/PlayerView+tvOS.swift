import ComposableArchitecture
import SwiftUI
import SwiftVLC

public struct PlayerView_tvOS: View {
    @Bindable var store: StoreOf<PlayerFeature>

    public var body: some View {
        ZStack {
            if store.isControlsVisible {
                VStack {
                    // Top Bar
                    HStack {
                        VStack(alignment: .leading) {
                            Text(store.item.title)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 8)

                        Spacer()

                        // EPG Button
                        if let _ = store.item.epgChannelID, !store.epgListings.isEmpty {
                            Button(action: { store.send(.toggleEPG, animation: .easeInOut) }) {
                                Image(systemName: "list.bullet.rectangle")
                                    .font(.title3)
                                    .foregroundColor(.white)
                                    .padding()
                            }
                            .buttonStyle(.plain)
                            .background(store.isEPGVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(Color.white.opacity(0.2)), in: Circle())
                        }
                    }
                    .padding()

                    Spacer()

                    // Center Controls
                    HStack(spacing: 40) {
                        Button(action: { store.send(.closeTapped) }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                        }
                        .buttonStyle(.plain)
                        .padding()
                        .background(Color.white.opacity(0.2), in: Circle())

                        Button(action: {
                            if store.playerState == .playing {
                                store.send(.pause)
                            } else {
                                store.send(.play)
                            }
                        }) {
                            Image(systemName: store.playerState == .playing ? "pause.fill" : "play.fill")
                                .font(.system(size: 44))
                        }
                        .buttonStyle(.plain)
                        .padding(24)
                        .background(Color.white.opacity(0.2), in: Circle())
                    }

                    Spacer()

                    // Loading indicator
                    if store.playerState == .buffering {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                }
                .background(Color.black.opacity(0.4))
                .transition(.opacity)

                // EPG Overlay
                if store.isEPGVisible {
                    HStack {
                        Spacer()
                        EPGListView(
                            programs: store.epgListings,
                            currentPosition: store.position,
                            onClose: { store.send(.toggleEPG, animation: .easeInOut) }
                        )
                        .frame(width: 500)
                        .padding(.trailing, 40)
                    }
                }
            }
        }
    }
}
