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
        store.streamHealthMetrics ?? StreamHealthMetrics(
            bufferHealth: 0.95,
            bufferDurationSeconds: 4.8,
            networkLatencyMs: 32,
            networkJitterMs: 2,
            droppedFrames: 0,
            decodedFrames: 1840,
            lateFrames: 0,
            bitrateMbps: 5.2,
            fps: 50.0,
            healthScore: 98,
            healthGrade: .excellent,
            connectionStability: "Ultra Kararlı"
        )
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header Bar
            headerBar

            // Health Score & Stability Banner
            healthScoreCard

            // Live Buffer Gauge Bar
            bufferGaugeSection

            // Network & Playback Diagnostics Grid
            diagnosticsGrid

            // Footer / Toggle Full Nerd Stats Button
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
                        colors: [metrics.healthGrade.color.opacity(0.6), Color(hex: "#0A84FF").opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: .black.opacity(0.7), radius: 30, x: 0, y: 15)
        .shadow(color: metrics.healthGrade.color.opacity(0.15), radius: 20, x: 0, y: 8)
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
                        colors: [metrics.healthGrade.color.opacity(0.5), Color.white.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: .black.opacity(0.65), radius: 24, x: 0, y: 12)
        .shadow(color: metrics.healthGrade.color.opacity(0.12), radius: 18, x: 0, y: 6)
        #endif
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(metrics.healthGrade.color.opacity(0.18))
                    .frame(width: 36, height: 36)
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(metrics.healthGrade.color)
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
        HStack(spacing: 16) {
            // Big Score
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(metrics.healthScore)")
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

            // Grade Badge & Stability
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: metrics.healthGrade.systemIcon)
                        .font(.system(size: 13, weight: .bold))
                    Text(metrics.healthGrade.rawValue)
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                }
                .foregroundColor(metrics.healthGrade.color)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(metrics.healthGrade.color.opacity(0.16), in: Capsule())

                HStack(spacing: 5) {
                    Circle()
                        .fill(metrics.healthGrade.color)
                        .frame(width: 6, height: 6)
                    Text(metrics.connectionStability)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.white.opacity(0.8))
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

    // MARK: - Live Buffer Gauge Section

    private var bufferGaugeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "gauge.with.needle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: "#0A84FF"))

                    Text(AppStrings.Player.bufferHealth)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                }

                Spacer()

                Text("\(String(format: "%.1f", metrics.bufferDurationSeconds))s Tampon")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundColor(metrics.bufferHealth > 0.4 ? Color(hex: "#00F5D4") : Color(hex: "#FF453A"))
            }

            // Animated Buffer Bar Gauge
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.12))
                        .frame(height: 10)

                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#0A84FF"), metrics.healthGrade.color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geo.size.width * CGFloat(min(1.0, max(0.0, metrics.bufferHealth)))), height: 10)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: metrics.bufferHealth)
                }
            }
            .frame(height: 10)

            HStack {
                Text("0s (Kritik)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("2.5s (Güvenli)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
                Spacer()
                Text("5.0s+ (Maksimum)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(14)
        .background(
            Color.white.opacity(0.04),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    // MARK: - Diagnostics Grid

    private var diagnosticsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            // Ping (Latency)
            metricTile(
                icon: "bolt.horizontal.fill",
                title: AppStrings.Player.networkLatency,
                value: "\(metrics.networkLatencyMs) ms",
                subtitle: metrics.networkLatencyMs < 60 ? "Ultra Hızlı" : (metrics.networkLatencyMs < 150 ? "Normal" : "Yüksek Ping"),
                tintColor: metrics.networkLatencyMs < 60 ? Color(hex: "#00F5D4") : (metrics.networkLatencyMs < 150 ? Color(hex: "#0A84FF") : Color(hex: "#FF453A"))
            )

            // Jitter
            metricTile(
                icon: "arrow.triangle.swap",
                title: AppStrings.Player.networkJitter,
                value: "±\(metrics.networkJitterMs) ms",
                subtitle: metrics.networkJitterMs < 8 ? "Çok Kararlı" : "Dalgalanma Var",
                tintColor: metrics.networkJitterMs < 8 ? Color(hex: "#00F5D4") : Color(hex: "#FFD60A")
            )

            // Bitrate
            metricTile(
                icon: "speedometer",
                title: AppStrings.Player.bitrate,
                value: "\(String(format: "%.1f", metrics.bitrateMbps)) Mbps",
                subtitle: store.mediaInfo?.resolution ?? "Canlı Veri Akışı",
                tintColor: Color(hex: "#64D2FF")
            )

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
