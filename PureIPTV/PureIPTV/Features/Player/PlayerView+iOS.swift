#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI
    import SwiftVLC

    public struct PlayerView_iOS: View {
        @Bindable var store: StoreOf<PlayerFeature>
        @Binding var pipController: PiPController?
        @State private var isDraggingSlider: Bool = false
        @State private var sliderDragValue: Double = 0.0
        @Environment(\.scenePhase) private var scenePhase

        public var body: some View {
            ZStack {
                // Gesture Areas
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Left Half - Brightness & Backward Jump
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                ExclusiveGesture(
                                    TapGesture(count: 2).onEnded {
                                        store.send(.jumpBackward)
                                        store.send(.showGestureFeedback("10s ⏪"))
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            store.send(.hideGestureFeedback)
                                        }
                                    },
                                    TapGesture(count: 1).onEnded {
                                        store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                    }
                                )
                            )

                        // Right Half - Volume & Forward Jump
                        Color.clear
                            .contentShape(Rectangle())
                            .gesture(
                                ExclusiveGesture(
                                    TapGesture(count: 2).onEnded {
                                        store.send(.jumpForward)
                                        store.send(.showGestureFeedback("⏩ 10s"))
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                            store.send(.hideGestureFeedback)
                                        }
                                    },
                                    TapGesture(count: 1).onEnded {
                                        store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                    }
                                )
                            )
                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                store.send(.dragGestureChanged(
                                    translation: value.translation,
                                    screenWidth: geo.size.width,
                                    screenHeight: geo.size.height,
                                    startLocation: value.startLocation
                                ))
                            }
                            .onEnded { _ in
                                store.send(.dragGestureEnded)
                            }
                    )
                }
                if store.isControlsVisible {
                    VStack {
                        // Top Bar
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button(action: { HapticManager.shared.trigger(.light); store.send(.closeTapped) }) {
                                    Image(systemName: "xmark")
                                        .font(.title3)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(.ultraThinMaterial, in: Circle())
                                }

                                Spacer()

                                // Action Buttons grouped
                                HStack(spacing: 8) {
                                    // PiP Button
                                    if pipController?.isPossible == true {
                                        Button(action: {
                                            HapticManager.shared.trigger(.light)
                                            if store.isPiPActive {
                                                pipController?.stop()
                                            } else {
                                                _ = pipController?.start()
                                            }
                                        }) {
                                            Image(systemName: store.isPiPActive ? "pip.exit" : "pip.enter")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .padding(10)
                                                .background(store.isPiPActive ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                        }
                                    }

                                    // SharePlay Button
                                    Button(action: { HapticManager.shared.trigger(.light); store.send(.sharePlayTapped, animation: .spring(response: 0.3, dampingFraction: 0.7)) }) {
                                        Image(systemName: "shareplay")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                    }

                                    // AirPlay Button
                                    AirPlayView()
                                        .frame(width: 40, height: 40)
                                        .background(AnyShapeStyle(.ultraThinMaterial), in: Circle())

                                    // Channels Button (Zapping)
                                    if store.playlist != nil {
                                        Button(action: { HapticManager.shared.trigger(.light); store.send(.toggleChannelList, animation: .spring(response: 0.3, dampingFraction: 0.7)) }) {
                                            Image(systemName: "list.dash")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .padding(10)
                                                .background(store.isChannelListVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                        }
                                    }

                                    // EPG Button
                                    if let _ = store.item.epgChannelID, !store.epgListings.isEmpty {
                                        Button(action: { HapticManager.shared.trigger(.light); store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7)) }) {
                                            Image(systemName: "list.bullet.rectangle")
                                                .font(.title3)
                                                .foregroundColor(.white)
                                                .padding(10)
                                                .background(store.isEPGVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                        }
                                    }

                                    // Tracks Button
                                    Button(action: { HapticManager.shared.trigger(.light); store.send(.toggleTracksMenu, animation: .spring(response: 0.3, dampingFraction: 0.7)) }) {
                                        Image(systemName: "captions.bubble")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(store.isTracksMenuVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                    }

                                    // Info Button
                                    Button(action: { HapticManager.shared.trigger(.light); store.send(.toggleInfo, animation: .spring(response: 0.3, dampingFraction: 0.7)) }) {
                                        Image(systemName: "info.circle")
                                            .font(.title3)
                                            .foregroundColor(.white)
                                            .padding(10)
                                            .background(store.isInfoVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                                    }
                                }
                            }

                            Text(store.item.title)
                                .font(.headline)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)
                                .truncationMode(.tail)
                                .padding(.leading, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding()

                        // Overlays (Info / Tracks)
                        ZStack(alignment: .topTrailing) {
                            if store.isInfoVisible {
                                HStack {
                                    Spacer()
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(AppStrings.Player.mediaInfo)
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.bottom, 4)

                                        if let info = store.mediaInfo {
                                            InfoRow(title: "Resolution", value: info.resolution ?? "Unknown")
                                            InfoRow(title: "Video Codec", value: info.videoCodec ?? "Unknown")
                                            InfoRow(title: "Audio Codec", value: info.audioCodec ?? "Unknown")
                                            if let bitrate = info.bitrate, bitrate > 0 {
                                                InfoRow(title: "Bitrate", value: "\(bitrate / 1000) kbps")
                                            }
                                        } else {
                                            Text(AppStrings.Common.loading)
                                                .foregroundColor(.white.opacity(0.7))
                                                .font(.caption)
                                        }
                                    }
                                    .padding()
                                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                                    .padding(.trailing, 16)
                                }
                            }

                            if store.isTracksMenuVisible {
                                tracksMenuOverlay
                            }

                            if store.isEPGVisible {
                                VStack {
                                    Spacer()
                                    PlayerEPGTimelineView(
                                        programs: store.epgListings,
                                        currentPosition: store.position,
                                        onClose: { store.send(.toggleEPG, animation: .spring(response: 0.3, dampingFraction: 0.7)) },
                                        onSelect: { program in store.send(.playArchive(program)) }
                                    )
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 24)
                                }
                            }

                            if store.isChannelListVisible, let playlist = store.playlist {
                                HStack {
                                    Spacer()
                                    ChannelListOverlay(
                                        playlist: playlist,
                                        selectedItemID: store.item.id,
                                        onSelect: { item in
                                            store.send(.selectChannel(item), animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        },
                                        onClose: {
                                            store.send(.toggleChannelList, animation: .spring(response: 0.3, dampingFraction: 0.7))
                                        }
                                    )
                                    .frame(width: 300, height: 350)
                                    .padding(.trailing, 16)
                                }
                            }
                        }

                        Spacer()

                        // Center Controls
                        HStack(spacing: 40) {
                            // Jump Backward
                            Button(action: { HapticManager.shared.trigger(.light); store.send(.jumpBackward) }) {
                                Image(systemName: "gobackward.10")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            // Play/Pause
                            Button(action: {
                                if store.playerState == .playing {
                                    store.send(.pause)
                                } else {
                                    store.send(.play)
                                }
                            }) {
                                Image(systemName: store.playerState == .playing ? "pause.fill" : "play.fill")
                                    .font(.system(size: 44))
                                    .foregroundColor(.white)
                                    .padding(24)
                                    .background(.ultraThinMaterial, in: Circle())
                            }

                            // Jump Forward
                            Button(action: { HapticManager.shared.trigger(.light); store.send(.jumpForward) }) {
                                Image(systemName: "goforward.10")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .padding(16)
                                    .background(.ultraThinMaterial, in: Circle())
                            }
                        }

                        Spacer()

                        // Error message
                        if let error = store.errorMessage {
                            Text(error)
                                .foregroundColor(.red)
                                .padding()
                                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
                        }

                        // Bottom Bar (Timeline & Loading)
                        VStack {
                            if store.playerState == .buffering {
                                HStack {
                                    Spacer()
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    Spacer()
                                }
                            }

                            // Timeline (only show if total time is valid, meaning it's not a live stream)
                            if store.totalTime > .zero || store.item.config == nil {
                                HStack(spacing: 12) {
                                    // Calculate the display time based on dragging status
                                    let currentDisplayPosition = isDraggingSlider ? sliderDragValue : store.position
                                    let currentDisplayDuration = isDraggingSlider
                                        ? Duration.seconds(Double(store.totalTime.components.seconds) * currentDisplayPosition)
                                        : store.currentTime

                                    Text(formatDuration(currentDisplayDuration))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.white)

                                    Slider(
                                        value: Binding(
                                            get: { currentDisplayPosition },
                                            set: { newValue in
                                                sliderDragValue = newValue
                                            }
                                        ),
                                        in: 0 ... 1,
                                        onEditingChanged: { editing in
                                            Task { @MainActor in
                                                isDraggingSlider = editing
                                                if !editing {
                                                    store.send(.seek(sliderDragValue))
                                                }
                                            }
                                        }
                                    )
                                    .tint(.accentColor)

                                    Text(formatDuration(store.totalTime))
                                        .font(.caption.monospacedDigit())
                                        .foregroundColor(.white)
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.bottom, 24)
                        .padding(.top, 8)
                    }
                    .background(
                        Color.black.opacity(0.4)
                            .onTapGesture {
                                store.send(.toggleControls, animation: .spring(response: 0.3, dampingFraction: 0.7))
                            }
                    )
                    .transition(.opacity)
                }

                // Gesture Feedback Overlay
                if let feedback = store.gestureFeedback {
                    Text(feedback)
                        .font(.title2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                        .transition(.scale.combined(with: .opacity))
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.gestureFeedback)
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .background {
                    store.send(.onDisappear)
                }
            }
        }

        private func formatDuration(_ duration: Duration) -> String {
            let totalSeconds = Int(duration.components.seconds)
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let seconds = totalSeconds % 60

            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }

        private var tracksMenuOverlay: some View {
            HStack {
                Spacer()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if !store.audioTracks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppStrings.Player.audioTracks)
                                    .font(.headline)
                                    .foregroundColor(.white)

                                ForEach(store.audioTracks) { track in
                                    let isSelected = store.selectedAudioTrack?.id == track.id
                                    Button(action: { HapticManager.shared.trigger(.light); store.send(.selectAudioTrack(track)) }) {
                                        HStack {
                                            Text(track.name)
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                        .foregroundColor(isSelected ? .accentColor : .white)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        if !store.subtitleTracks.isEmpty {
                            if !store.audioTracks.isEmpty {
                                Divider().background(Color.white.opacity(0.3))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text(AppStrings.Player.subtitles)
                                    .font(.headline)
                                    .foregroundColor(.white)

                                let isSubtitlesOff = store.selectedSubtitleTrack == nil || store.subtitleTracks.isEmpty || (store.selectedSubtitleTrack?.id == "-1")

                                Button(action: { HapticManager.shared.trigger(.light); store.send(.selectSubtitleTrack(nil)) }) {
                                    HStack {
                                        Text(AppStrings.Player.off)
                                        Spacer()
                                        if isSubtitlesOff {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                    .foregroundColor(isSubtitlesOff ? .accentColor : .white)
                                }
                                .padding(.vertical, 4)

                                ForEach(store.subtitleTracks) { track in
                                    let isSelected = store.selectedSubtitleTrack?.id == track.id
                                    Button(action: { HapticManager.shared.trigger(.light); store.send(.selectSubtitleTrack(track)) }) {
                                        HStack {
                                            Text(track.name)
                                            Spacer()
                                            if isSelected {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                        .foregroundColor(isSelected ? .accentColor : .white)
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }

                        if store.audioTracks.isEmpty, store.subtitleTracks.isEmpty {
                            Text(AppStrings.Player.noOptions)
                                .foregroundColor(.white.opacity(0.7))
                                .font(.caption)
                        }
                    }
                    .padding()
                }
                .frame(maxHeight: 250)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.trailing, 16)
            }
        }
    }

    private struct InfoRow: View {
        let title: String
        let value: String

        var body: some View {
            HStack {
                Text("\(title):")
                    .foregroundColor(.white.opacity(0.7))
                    .font(.caption)
                Text(value)
                    .foregroundColor(.white)
                    .font(.caption.bold())
            }
        }
    }

    import AVKit

    struct ChannelListOverlay: View {
        let playlist: [PlayerFeature.PlayableItem]
        let selectedItemID: String
        let onSelect: (PlayerFeature.PlayableItem) -> Void
        let onClose: () -> Void

        var body: some View {
            VStack(spacing: 0) {
                // Header
                HStack {
                    Text(AppStrings.LiveTV.channelsTitle)
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .background(Color.black.opacity(0.6))

                Divider().background(Color.white.opacity(0.2))

                // List
                ScrollView {
                    ScrollViewReader { proxy in
                        LazyVStack(spacing: 8) {
                            ForEach(playlist, id: \.id) { item in
                                ChannelListRow(
                                    item: item,
                                    isSelected: item.id == selectedItemID,
                                    action: { onSelect(item) }
                                )
                                .id(item.id)
                            }
                        }
                        .padding(12)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation {
                                    proxy.scrollTo(selectedItemID, anchor: .center)
                                }
                            }
                        }
                    }
                }
            }
            .background(AnyShapeStyle(.ultraThinMaterial))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        }
    }

    struct ChannelListRow: View {
        let item: PlayerFeature.PlayableItem
        let isSelected: Bool
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 12) {
                    if let cover = item.coverURL {
                        AsyncImage(url: cover) { phase in
                            if let image = phase.image {
                                image.resizable().aspectRatio(contentMode: .fit)
                            } else {
                                Image(systemName: "tv").foregroundColor(.gray)
                            }
                        }
                        .frame(width: 40, height: 40)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    } else {
                        Image(systemName: "tv")
                            .frame(width: 40, height: 40)
                            .background(Color.black.opacity(0.3))
                            .cornerRadius(8)
                            .foregroundColor(.gray)
                    }

                    Text(item.title)
                        .font(.subheadline)
                        .fontWeight(isSelected ? .bold : .regular)
                        .foregroundColor(isSelected ? .accentColor : .white)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()
                }
                .padding(8)
                .background(isSelected ? Color.accentColor.opacity(0.15) : Color.white.opacity(0.05))
                .cornerRadius(10)
            }
            .buttonStyle(.plain)
        }
    }
#endif
