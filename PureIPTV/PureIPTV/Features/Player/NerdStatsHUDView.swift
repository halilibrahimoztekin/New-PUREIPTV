import SwiftUI
import SwiftVLC

// MARK: - Nerd Stats HUD View (Madde #33 - Anlık Yayın Teknik İstatistikleri)

/// Real-time stream diagnostics & technical statistics HUD.
/// Optimized for both Apple TV 10-foot UI (Focus Engine, Siri Remote) and iOS touch devices.
public struct NerdStatsHUDView: View {
    public let item: PlayerFeature.PlayableItem
    public let mediaInfo: MediaInfo?
    public let playerState: PlayerState
    public let audioDelay: Int
    public let subtitleDelay: Int
    public let playbackRate: Float
    public let aspectRatioMode: VideoAspectRatioMode
    public let selectedAudioTrack: Track?
    public let selectedSubtitleTrack: Track?
    public let currentAudioRoute: AudioRouteInfo?
    public let playerStats: String
    public let streamHealthMetrics: StreamHealthMetrics?
    public let onClose: () -> Void

    #if os(tvOS)
        @FocusState private var isCloseFocused: Bool
    #endif

    public init(
        item: PlayerFeature.PlayableItem,
        mediaInfo: MediaInfo?,
        playerState: PlayerState,
        audioDelay: Int = 0,
        subtitleDelay: Int = 0,
        playbackRate: Float = 1.0,
        aspectRatioMode: VideoAspectRatioMode = .fit,
        selectedAudioTrack: Track? = nil,
        selectedSubtitleTrack: Track? = nil,
        currentAudioRoute: AudioRouteInfo? = nil,
        playerStats: String = "",
        streamHealthMetrics: StreamHealthMetrics? = nil,
        onClose: @escaping () -> Void
    ) {
        self.item = item
        self.mediaInfo = mediaInfo
        self.playerState = playerState
        self.audioDelay = audioDelay
        self.subtitleDelay = subtitleDelay
        self.playbackRate = playbackRate
        self.aspectRatioMode = aspectRatioMode
        self.selectedAudioTrack = selectedAudioTrack
        self.selectedSubtitleTrack = selectedSubtitleTrack
        self.currentAudioRoute = currentAudioRoute
        self.playerStats = playerStats
        self.streamHealthMetrics = streamHealthMetrics
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // ── Header Bar ───────────────────────────────────────────
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Color(hex: "#00F5D4"))

                Text(AppStrings.Player.nerdStats)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)

                Spacer()

                // State indicator pulse
                stateBadge

                // Close Button
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.white.opacity(0.85))
                }
                .buttonStyle(.plain)
                #if os(tvOS)
                    .focused($isCloseFocused)
                    .scaleEffect(isCloseFocused ? 1.25 : 1.0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isCloseFocused)
                #endif
            }
            .padding(.bottom, 4)

            Divider()
                .overlay(Color.white.opacity(0.15))

            // ── Metrics Grid ─────────────────────────────────────────
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                // Video Resolution
                StatCard(
                    icon: "tv.fill",
                    title: AppStrings.Player.resolution,
                    value: resolutionString,
                    accentColor: Color.cyan
                )

                // Video Codec
                StatCard(
                    icon: "video.fill",
                    title: AppStrings.Player.videoCodec,
                    value: videoCodecString,
                    accentColor: Color(hex: "#00F5D4")
                )

                // Audio Codec & Route
                StatCard(
                    icon: "waveform",
                    title: AppStrings.Player.audioCodec,
                    value: audioCodecString,
                    accentColor: Color(hex: "#BF5AF2")
                )

                // Measured network throughput
                StatCard(
                    icon: "arrow.down.circle.fill",
                    title: AppStrings.Player.networkThroughput,
                    value: streamHealthMetrics?.networkThroughputMbps.map { "\(String(format: "%.1f", $0)) Mbps" }
                        ?? AppStrings.Player.sampleUnavailable,
                    accentColor: Color.yellow
                )

                StatCard(
                    icon: "speedometer",
                    title: AppStrings.Player.streamBitrate,
                    value: streamHealthMetrics?.streamBitrateMbps.map { "\(String(format: "%.1f", $0)) Mbps" } ?? bitrateString,
                    accentColor: Color.orange
                )

                StatCard(
                    icon: "film",
                    title: AppStrings.Player.renderedFPS,
                    value: streamHealthMetrics?.fps.map { "\(String(format: "%.1f", $0)) FPS" }
                        ?? AppStrings.Player.sampleUnavailable,
                    accentColor: Color(hex: "#00F5D4")
                )

                if let metrics = streamHealthMetrics {
                    // Network Latency & Jitter
                    StatCard(
                        icon: "bolt.horizontal.fill",
                        title: AppStrings.Player.networkLatency,
                        value: metrics.networkLatencyMs.map { latency in
                            let jitter = metrics.networkJitterMs.map { " (±\($0)ms)" } ?? ""
                            return "\(latency) ms\(jitter)"
                        } ?? AppStrings.Player.sampleUnavailable,
                        accentColor: metrics.networkLatencyMs.map { $0 < 80 ? Color(hex: "#00F5D4") : Color.orange }
                            ?? Color.white.opacity(0.55)
                    )

                    // Frame Drops
                    StatCard(
                        icon: metrics.droppedFrames == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                        title: AppStrings.Player.droppedFramesTitle,
                        value: "\(metrics.droppedFrames) Drop (\(metrics.decodedFrames)f)",
                        accentColor: metrics.droppedFrames == 0 ? Color.green : Color.red
                    )
                }

                // Aspect Ratio & Scale
                StatCard(
                    icon: aspectRatioMode.systemIcon,
                    title: "En-Boy / Hız",
                    value: "\(aspectRatioMode.title) • \(String(format: "%.2gx", playbackRate))",
                    accentColor: Color.green
                )

                // Audio Delay Sync
                StatCard(
                    icon: "clock.arrow.circlepath",
                    title: AppStrings.Player.audioSync,
                    value: audioDelay == 0 ? "Senkronize (0 ms)" : "\(audioDelay > 0 ? "+" : "")\(audioDelay) ms",
                    accentColor: audioDelay == 0 ? Color.white.opacity(0.8) : Color.orange
                )

                // Audio Output Route
                StatCard(
                    icon: currentAudioRoute?.iconName ?? "speaker.wave.2.fill",
                    title: AppStrings.Player.audioRoute,
                    value: currentAudioRoute?.name ?? AppStrings.Player.speaker,
                    accentColor: Color(hex: "#0A84FF")
                )

                // Stream Format / Protocol
                StatCard(
                    icon: "network",
                    title: AppStrings.Player.streamProtocol,
                    value: streamFormatString,
                    accentColor: Color(hex: "#64D2FF")
                )

                // VPN Status (Madde #93)
                StatCard(
                    icon: VPNMonitor.shared.isConnected ? "lock.shield.fill" : "shield",
                    title: "Ağ & VPN",
                    value: VPNMonitor.shared.isConnected ? "VPN Tüneli Aktif" : "Doğrudan ISP",
                    accentColor: VPNMonitor.shared.isConnected ? Color.green : Color.white.opacity(0.7)
                )

                // Stream Type / Live Mode
                StatCard(
                    icon: item.isLive ? "antenna.radiowaves.left.and.right" : "film.fill",
                    title: "Yayın Tipi",
                    value: item.isLive ? "Canlı TV (Live)" : "İsteğe Bağlı (VOD)",
                    accentColor: Color(hex: "#FFD60A")
                )
            }

            // ── Raw Stats Output (if present from native engine) ──────
            if !playerStats.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("NATIVE BUFFER METRICS")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.6))

                    Text(playerStats)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.85))
                        .lineLimit(3)
                }
                .padding(8)
                .background(Color.black.opacity(0.4), in: RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(20)
        #if os(tvOS)
            .frame(width: 580)
        #else
            .frame(maxWidth: 380)
        #endif
            .background(
                ZStack {
                    Color.black.opacity(0.82)
                    Rectangle()
                        .fill(.ultraThinMaterial)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(
                        LinearGradient(
                            colors: [Color(hex: "#00F5D4").opacity(0.6), Color(hex: "#0A84FF").opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.7), radius: 24, x: 0, y: 12)
            .shadow(color: Color(hex: "#00F5D4").opacity(0.18), radius: 18, x: 0, y: 6)
        #if os(tvOS)
            .onExitCommand {
                onClose()
            }
        #endif
    }

    // MARK: - State Badge

    private var stateBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(stateColor)
                .frame(width: 8, height: 8)

            Text(stateText)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .foregroundStyle(stateColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(stateColor.opacity(0.18), in: Capsule())
    }

    private var stateColor: Color {
        switch playerState {
        case .playing: Color.green
        case .buffering, .opening: Color.orange
        case .error: Color.red
        default: Color.white.opacity(0.7)
        }
    }

    private var stateText: String {
        switch playerState {
        case .playing: "CANLI / OYNUYOR"
        case .buffering: "TAMPONLANIYOR"
        case .opening: "AÇILIYOR"
        case .paused: "DURAKLATILDI"
        case .stopped: "DURDURULDU"
        case .error: "HATA"
        case .idle: "BEKLEMEDE"
        case .stopping: "DURDURULUYOR"
        @unknown default: "BİLİNMİYOR"
        }
    }

    // MARK: - Computed Metric Strings

    private var resolutionString: String {
        if let res = mediaInfo?.resolution, !res.isEmpty {
            return res.contains("3840") ? "\(res) (4K UHD)" : (res.contains("1920") ? "\(res) (FHD)" : res)
        }
        let lower = item.title.lowercased()
        if lower.contains("4k") || lower.contains("uhd") {
            return "3840x2160 (4K UHD)"
        } else if lower.contains("fhd") || lower.contains("1080") {
            return "1920x1080 (1080p FHD)"
        } else if lower.contains("hd") || lower.contains("720") {
            return "1280x720 (720p HD)"
        }
        return "Otomatik / HLS Stream"
    }

    private var videoCodecString: String {
        if let codec = mediaInfo?.videoCodec, !codec.isEmpty {
            return codec.uppercased()
        }
        let lower = item.title.lowercased()
        if lower.contains("hevc") || lower.contains("h.265") || lower.contains("x265") {
            return "HEVC (H.265 Main 10)"
        }
        return "H.264 (AVC High)"
    }

    private var audioCodecString: String {
        if let codec = mediaInfo?.audioCodec, !codec.isEmpty {
            return codec.uppercased()
        }
        if let track = selectedAudioTrack {
            return "\(track.name) (AAC-LC)"
        }
        return "AAC-LC Stereo"
    }

    private var bitrateString: String {
        if let bitrate = mediaInfo?.bitrate, bitrate > 0 {
            if bitrate >= 1_000_000 {
                return String(format: "%.1f Mbps", Double(bitrate) / 1_000_000.0)
            } else {
                return "\(bitrate / 1000) kbps"
            }
        }
        return AppStrings.Player.sampleUnavailable
    }

    private var streamFormatString: String {
        let url = item.streamURL
        let ext = url.pathExtension.lowercased()
        if ext == "m3u8" {
            return "Apple HLS (.m3u8)"
        } else if ext == "ts" {
            return "MPEG-2 Transport Stream (.ts)"
        } else if ext == "mp4" {
            return "MP4 / AAC Container"
        } else if ext == "mkv" {
            return "Matroska Video (.mkv)"
        }
        return "\(url.scheme?.uppercased() ?? "HTTP") Stream"
    }
}

// MARK: - Stat Card Subview

private struct StatCard: View {
    let icon: String
    let title: String
    let value: String
    let accentColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accentColor)

                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color.white.opacity(0.65))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
