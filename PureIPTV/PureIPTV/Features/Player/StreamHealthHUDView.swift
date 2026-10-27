import ComposableArchitecture
import SwiftUI

// MARK: - Stream Health & Network Jitter HUD (Feature #3)

/// Cinematic Obsidian Stream Health, Buffer Gauge & Real-time Network Jitter HUD.
/// Optimized for both Apple TV 10-foot UI (Siri Remote Focus Engine) and iOS touch devices.
public struct StreamHealthHUDView: View {
    public let store: StoreOf<PlayerFeature>
    public let onClose: () -> Void

    #if os(tvOS)
        @FocusState private var focusedField: FocusField?
        private enum FocusField: Hashable {
            case close
            case toggleNerdStats
        }
    #endif

    public init(store: StoreOf<PlayerFeature>, onClose: @escaping () -> Void) {
        self.store = store
        self.onClose = onClose
    }

    private var metrics: StreamHealthMetrics {
        store.streamHealthMetrics ?? StreamHealthMetrics()
    }

    private var statusTint: Color {
        store.streamHealthMetrics?.healthGrade?.color ?? Color.white.opacity(0.65)
    }

    public var body: some View {
        VStack(spacing: 16) {
            headerBar
            if store.isLiveVideoStallDetected {
                liveVideoStallCard
            }
            if store.streamHealthMetrics == nil {
                waitingForSampleCard
            } else {
                healthScoreCard
                diagnosticsGrid
            }
            footerActions
        }
        #if os(tvOS)
        .padding(32)
        .frame(width: 620)
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.94)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [statusTint.opacity(0.6), Color(hex: "#0A84FF").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 15)
        .shadow(color: statusTint.opacity(0.15), radius: 20, x: 0, y: 8)
        .focusSection()
        .onExitCommand {
            onClose()
        }
        #else
        .padding(20)
        .frame(maxWidth: min(440, UIScreen.main.bounds.width - 32))
        .background(
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Color(hex: "#0C0C10").opacity(0.95)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [statusTint.opacity(0.5), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 12)
        .shadow(color: statusTint.opacity(0.12), radius: 18, x: 0, y: 6)
        #endif
    }

    // MARK: - Header Bar

    private var liveVideoStallCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: "#FFD60A"))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                Text(AppStrings.Player.liveVideoStallTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                Text(AppStrings.Player.liveVideoStallMessage)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: "#FFD60A").opacity(0.1), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color(hex: "#FFD60A").opacity(0.22), lineWidth: 1)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(AppStrings.Player.liveVideoStallTitle)
        .accessibilityValue(AppStrings.Player.liveVideoStallMessage)
        .accessibilityAddTraits(.isStaticText)
    }

    private var waitingForSampleCard: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.white.opacity(0.8))
            Text(AppStrings.Player.sampleUnavailable)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white.opacity(0.75))
            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(AppStrings.Player.sampleUnavailable)
    }

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(statusTint.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(statusTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(AppStrings.Player.streamHealthTitle)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(store.item.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer()

            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($focusedField, equals: .close)
            #endif
        }
    }

    // MARK: - Health Score Card

    private var healthScoreCard: some View {
        Group {
            if let score = metrics.healthScore, let grade = metrics.healthGrade {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(score)")
                                .font(.system(size: 38, weight: .heavy, design: .rounded))
                                .foregroundColor(.white)
                            Text("/100")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(.white.opacity(0.5))
                        }
                        Text("Genel Sağlık Skoru")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.55))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: grade.systemIcon)
                                .font(.system(size: 13, weight: .bold))
                            Text(grade.rawValue)
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        }
                        .foregroundColor(grade.color)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(grade.color.opacity(0.16), in: Capsule())
                        HStack(spacing: 5) {
                            Circle()
                                .fill(grade.color)
                                .frame(width: 6, height: 6)
                            Text(metrics.connectionStability ?? AppStrings.Player.sampleUnavailable)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .foregroundColor(.white.opacity(0.6))
                    Text(AppStrings.Player.sampleUnavailable)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            Color.white.opacity(0.06),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    // MARK: - Diagnostics Grid

    private var diagnosticsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            // Ping (Latency)
            metricTile(
                icon: "bolt.horizontal.fill",
                title: AppStrings.Player.networkLatency,
                value: metrics.networkLatencyMs.map { "\($0) ms" } ?? AppStrings.Player.sampleUnavailable,
                subtitle: metrics.networkLatencyMs.map {
                    $0 < 60 ? "Ultra Hızlı" : ($0 < 150 ? "Normal" : "Yüksek Ping")
                } ?? AppStrings.Player.sampleUnavailable,
                tintColor: metrics.networkLatencyMs.map {
                    $0 < 60 ? Color(hex: "#00F5D4") : ($0 < 150 ? Color(hex: "#0A84FF") : Color(hex: "#FF453A"))
                } ?? Color.white.opacity(0.55)
            )

            // Jitter
            metricTile(
                icon: "arrow.triangle.swap",
                title: AppStrings.Player.networkJitter,
                value: metrics.networkJitterMs.map { "±\($0) ms" } ?? AppStrings.Player.sampleUnavailable,
                subtitle: metrics.networkJitterMs.map { $0 < 8 ? "Çok Kararlı" : "Dalgalanma Var" }
                    ?? AppStrings.Player.sampleUnavailable,
                tintColor: metrics.networkJitterMs.map { $0 < 8 ? Color(hex: "#00F5D4") : Color(hex: "#FFD60A") }
                    ?? Color.white.opacity(0.55)
            )

            // Measured network throughput
            metricTile(
                icon: "arrow.down.circle.fill",
                title: AppStrings.Player.networkThroughput,
                value: metrics.networkThroughputMbps.map { "\(String(format: "%.1f", $0)) Mbps" }
                    ?? AppStrings.Player.sampleUnavailable,
                subtitle: AppStrings.Player.networkThroughput,
                tintColor: Color(hex: "#64D2FF")
            )

            metricTile(
                icon: "film",
                title: AppStrings.Player.renderedFPS,
                value: metrics.fps.map { "\(String(format: "%.1f", $0)) FPS" }
                    ?? AppStrings.Player.sampleUnavailable,
                subtitle: AppStrings.Player.renderedFPS,
                tintColor: Color(hex: "#00F5D4")
            )

            if let streamBitrateMbps = metrics.streamBitrateMbps {
                metricTile(
                    icon: "speedometer",
                    title: AppStrings.Player.streamBitrate,
                    value: "\(String(format: "%.1f", streamBitrateMbps)) Mbps",
                    subtitle: store.mediaInfo?.resolution ?? AppStrings.Player.videoCodec,
                    tintColor: Color(hex: "#FFD60A")
                )
            }

            // Frame Drops
            metricTile(
                icon: metrics.droppedFrames == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                title: AppStrings.Player.droppedFramesTitle,
                value: "\(metrics.droppedFrames) Drop",
                subtitle: "\(metrics.decodedFrames) kare çözüldü",
                tintColor: metrics.droppedFrames == 0 ? Color(hex: "#00F5D4") : Color(hex: "#FF453A")
            )
        }
    }

    private func metricTile(
        icon: String,
        title: String,
        value: String,
        subtitle: String,
        tintColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(tintColor)

                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Text(value)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(subtitle)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.45))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            Color.white.opacity(0.05),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    // MARK: - Footer Actions

    private var footerActions: some View {
        HStack(spacing: 10) {
            Button {
                #if !os(tvOS)
                    HapticManager.shared.trigger(.light)
                #endif
                onClose()
                store.send(.toggleStats)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "terminal.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text(AppStrings.Player.nerdStatsShort)
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white.opacity(0.9))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            #if os(tvOS)
                .focused($focusedField, equals: .toggleNerdStats)
            #endif
        }
    }
}
