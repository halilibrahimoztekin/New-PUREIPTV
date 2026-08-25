import ComposableArchitecture
import SwiftUI
import SwiftVLC

public struct PlayerView_iOS: View {
    @Bindable var store: StoreOf<PlayerFeature>
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
                                    store.send(.toggleControls, animation: .easeInOut)
                                }
                            )
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let delta = value.translation.height / geo.size.height
                                    let currentBrightness = UIScreen.main.brightness
                                    let newBrightness = max(0, min(1, currentBrightness - delta * 0.05))
                                    UIScreen.main.brightness = newBrightness
                                    store.send(.setBrightness(newBrightness))
                                    store.send(.showGestureFeedback("☀️ %\(Int(newBrightness * 100))"))
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        store.send(.hideGestureFeedback)
                                    }
                                }
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
                                    store.send(.toggleControls, animation: .easeInOut)
                                }
                            )
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let delta = value.translation.height / geo.size.height
                                    let currentVolume = store.volume
                                    let newVolume = max(0, min(100, currentVolume - Int32(delta * 10)))
                                    store.send(.setVolume(newVolume))
                                    store.send(.showGestureFeedback("🔊 %\(newVolume)"))
                                }
                                .onEnded { _ in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                        store.send(.hideGestureFeedback)
                                    }
                                }
                        )
                }
            }
            if store.isControlsVisible {
                VStack {
                    // Top Bar
                    HStack {
                        Button(action: { store.send(.closeTapped) }) {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(.ultraThinMaterial, in: Circle())
                        }

                        VStack(alignment: .leading) {
                            Text(store.item.title)
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 8)

                        Spacer()

                        // AirPlay Button
                        AirPlayView()
                            .frame(width: 44, height: 44)
                            .background(AnyShapeStyle(.ultraThinMaterial), in: Circle())

                        // Tracks Button
                        Button(action: { store.send(.toggleTracksMenu, animation: .easeInOut) }) {
                            Image(systemName: "captions.bubble")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(store.isTracksMenuVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                        }

                        // Info Button
                        Button(action: { store.send(.toggleInfo, animation: .easeInOut) }) {
                            Image(systemName: "info.circle")
                                .font(.title3)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(store.isInfoVisible ? AnyShapeStyle(Color.white.opacity(0.3)) : AnyShapeStyle(.ultraThinMaterial), in: Circle())
                        }
                    }
                    .padding()

                    // Overlays (Info / Tracks)
                    ZStack(alignment: .topTrailing) {
                        if store.isInfoVisible {
                            HStack {
                                Spacer()
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Media Info")
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
                                        Text("Yükleniyor...")
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
                            HStack {
                                Spacer()
                                ScrollView {
                                    VStack(alignment: .leading, spacing: 16) {
                                        if !store.audioTracks.isEmpty {
                                            VStack(alignment: .leading, spacing: 8) {
                                                Text("Ses İzleri")
                                                    .font(.headline)
                                                    .foregroundColor(.white)

                                                ForEach(store.audioTracks) { track in
                                                    Button(action: { store.send(.selectAudioTrack(track)) }) {
                                                        HStack {
                                                            Text(track.name)
                                                            Spacer()
                                                            if track.isSelected {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                        .foregroundColor(track.isSelected ? .accentColor : .white)
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
                                                Text("Altyazılar")
                                                    .font(.headline)
                                                    .foregroundColor(.white)

                                                Button(action: { store.send(.selectSubtitleTrack(nil)) }) {
                                                    HStack {
                                                        Text("Kapalı")
                                                        Spacer()
                                                        if store.subtitleTracks.allSatisfy({ !$0.isSelected }) {
                                                            Image(systemName: "checkmark")
                                                        }
                                                    }
                                                    .foregroundColor(store.subtitleTracks.allSatisfy { !$0.isSelected } ? .accentColor : .white)
                                                }
                                                .padding(.vertical, 4)

                                                ForEach(store.subtitleTracks) { track in
                                                    Button(action: { store.send(.selectSubtitleTrack(track)) }) {
                                                        HStack {
                                                            Text(track.name)
                                                            Spacer()
                                                            if track.isSelected {
                                                                Image(systemName: "checkmark")
                                                            }
                                                        }
                                                        .foregroundColor(track.isSelected ? .accentColor : .white)
                                                    }
                                                    .padding(.vertical, 4)
                                                }
                                            }
                                        }

                                        if store.audioTracks.isEmpty && store.subtitleTracks.isEmpty {
                                            Text("Seçenek bulunmuyor.")
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

                    Spacer()

                    // Center Controls
                    HStack(spacing: 40) {
                        // Jump Backward
                        Button(action: { store.send(.jumpBackward) }) {
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
                        Button(action: { store.send(.jumpForward) }) {
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
                        if store.totalTime > .zero {
                            HStack(spacing: 12) {
                                // Calculate the display time based on dragging status
                                let currentDisplayPosition = isDraggingSlider ? sliderDragValue : store.position
                                let currentDisplaySeconds = Double(store.totalTime.components.seconds) * currentDisplayPosition
                                let currentDisplayDuration = Duration.seconds(currentDisplaySeconds)

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
                                        isDraggingSlider = editing
                                        if !editing {
                                            store.send(.seek(sliderDragValue))
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
                            store.send(.toggleControls, animation: .easeInOut)
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
                    .animation(.easeInOut, value: store.gestureFeedback)
            }
        }
        .onDisappear {
            store.send(.stop)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background {
                store.send(.stop)
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

private struct AirPlayView: UIViewRepresentable {
    func makeUIView(context _: Context) -> AVRoutePickerView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = .white
        routePickerView.activeTintColor = .systemBlue
        return routePickerView
    }

    func updateUIView(_: AVRoutePickerView, context _: Context) {}
}
