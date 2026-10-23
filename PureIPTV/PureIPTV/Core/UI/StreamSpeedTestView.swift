import SwiftUI

public struct StreamSpeedTestView: View {
    @StateObject private var speedTest = StreamSpeedTestManager.shared
    @Environment(\.dismiss) private var dismiss
    public var targetURL: URL?

    public init(targetURL: URL? = nil) {
        self.targetURL = targetURL
    }

    public var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IPTV Sunucu Hız & Ping Testi")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text(targetURL?.host ?? "Aktif Yayın Sunucusu")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Button {
                    speedTest.cancelTest()
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Gauge / Results Display
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.08), lineWidth: 14)
                    .frame(width: 170, height: 170)

                switch speedTest.state {
                case .idle:
                    VStack(spacing: 6) {
                        Image(systemName: "speedometer")
                            .font(.system(size: 38))
                            .foregroundStyle(.cyan)
                        Text("Hazır")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                case .testingPing:
                    VStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("Ping Ölçülüyor...")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }

                case let .testingSpeed(progress, currentMbps):
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            AngularGradient(
                                colors: [.cyan, .blue, .purple],
                                center: .center
                            ),
                            style: StrokeStyle(lineWidth: 14, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 170, height: 170)
                        .animation(.linear(duration: 0.1), value: progress)

                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", currentMbps))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("Mbps")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }

                case let .completed(result):
                    Circle()
                        .stroke(Color.green.opacity(0.8), lineWidth: 14)
                        .frame(width: 170, height: 170)

                    VStack(spacing: 2) {
                        Text(String(format: "%.1f", result.speedMbps))
                            .font(.system(size: 36, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                        Text("Mbps")
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                    }

                case let .failed(msg):
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.red)
                        Text(msg)
                            .font(.caption2)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.vertical, 8)

            // Metrics Row
            if case let .completed(result) = speedTest.state {
                VStack(spacing: 12) {
                    HStack(spacing: 24) {
                        VStack(spacing: 2) {
                            Text("Gecikme (Ping)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(Int(result.pingMs)) ms")
                                .font(.headline.bold())
                                .foregroundStyle(.orange)
                        }

                        Divider()
                            .frame(height: 30)

                        VStack(spacing: 2) {
                            Text("Önerilen Kalite")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(result.recommendedBadge)
                                .font(.headline.bold())
                                .foregroundStyle(.cyan)
                        }
                    }

                    Text(result.qualityRating)
                        .font(.caption.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }
            }

            // Action Button
            Button {
                if speedTest.state == .idle || speedTest.state.isCompleted {
                    speedTest.startTest(targetURL: targetURL)
                } else {
                    speedTest.cancelTest()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: speedTest.state.isActive ? "stop.fill" : "play.fill")
                    Text(speedTest.state.isActive ? "Durdur" : "Testi Başlat")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(speedTest.state.isActive ? Color.red : Color.blue)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(24)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(white: 0.12).opacity(0.96))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .frame(maxWidth: 420)
    }
}

private extension SpeedTestState {
    var isActive: Bool {
        switch self {
        case .testingPing, .testingSpeed: true
        default: false
        }
    }

    var isCompleted: Bool {
        switch self {
        case .completed, .failed: true
        default: false
        }
    }
}
