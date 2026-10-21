import ComposableArchitecture
import Foundation

public struct StreamHealthClient: Sendable {
    public var measureLatencyAndJitter: @Sendable (_ url: URL) async -> (latencyMs: Int, jitterMs: Int)
    public var evaluateHealth: @Sendable (
        _ url: URL,
        _ isPlaying: Bool,
        _ counters: PlayerPlaybackCounters,
        _ previousCounters: PlayerPlaybackCounters?,
        _ elapsedSeconds: Double,
        _ mediaBitrate: Int?
    ) async -> StreamHealthMetrics
}

extension StreamHealthClient: DependencyKey {
    private actor LatencyTracker {
        var lastLatencyMs: Int = 32
        var lastJitterMs: Int = 2
        var session: URLSession

        init() {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 2.5
            config.timeoutIntervalForResource = 3.0
            config.waitsForConnectivity = false
            session = URLSession(configuration: config)
        }

        func ping(url: URL) async -> (latencyMs: Int, jitterMs: Int) {
            // Determine host URL for lightweight ping
            guard let host = url.host,
                  let scheme = url.scheme,
                  let pingURL = URL(string: "\(scheme)://\(host)")
            else {
                return (lastLatencyMs, lastJitterMs)
            }

            var request = URLRequest(url: pingURL)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let start = CFAbsoluteTimeGetCurrent()
            do {
                _ = try await session.data(for: request)
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let currentLatency = max(8, min(999, Int(elapsed * 1000.0)))
                let currentJitter = abs(currentLatency - lastLatencyMs)
                lastLatencyMs = currentLatency
                lastJitterMs = currentJitter
                return (currentLatency, currentJitter)
            } catch {
                // If HEAD fails or host rejects HEAD, simulate light decay or record fallback
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let fallbackLatency = max(15, min(999, Int(elapsed * 1000.0)))
                let jitter = abs(fallbackLatency - lastLatencyMs)
                lastLatencyMs = fallbackLatency
                lastJitterMs = jitter
                return (fallbackLatency, jitter)
            }
        }
    }

    public nonisolated static let liveValue: StreamHealthClient = {
        let tracker = LatencyTracker()

        return StreamHealthClient(
            measureLatencyAndJitter: { url in
                await tracker.ping(url: url)
            },
            evaluateHealth: { url, isPlaying, counters, prevCounters, elapsed, mediaBitrate in
                let (latency, jitter) = await tracker.ping(url: url)

                // 1. Bitrate computation
                var bitrateMbps = 0.0
                if let mb = mediaBitrate, mb > 0 {
                    bitrateMbps = Double(mb) / 1_000_000.0
                } else if let prev = prevCounters, elapsed > 0 {
                    let bytesDiff = counters.sourceReadBytes > prev.sourceReadBytes
                        ? counters.sourceReadBytes - prev.sourceReadBytes
                        : 0
                    let bitsPerSec = (Double(bytesDiff) * 8.0) / elapsed
                    bitrateMbps = max(0.2, min(50.0, bitsPerSec / 1_000_000.0))
                } else {
                    bitrateMbps = 4.5
                }

                // 2. Buffer Seconds & Health Percentage
                var bufferSeconds = 4.8
                var bufferPercentage = 0.96

                if !isPlaying {
                    bufferSeconds = 0.8
                    bufferPercentage = 0.20
                } else if latency > 300 || jitter > 60 {
                    bufferSeconds = max(1.2, 5.0 - (Double(latency) / 100.0))
                    bufferPercentage = max(0.25, bufferSeconds / 5.0)
                } else {
                    let dropPenalty = Double(counters.droppedFrames) * 0.1
                    bufferSeconds = max(2.5, min(5.5, 5.0 - dropPenalty))
                    bufferPercentage = min(1.0, bufferSeconds / 5.0)
                }

                // 3. Health Score & Classification
                var score = 100
                if latency > 60 {
                    score -= min(30, (latency - 60) / 6)
                }
                if jitter > 10 {
                    score -= min(20, (jitter - 10) * 2)
                }
                if counters.droppedFrames > 0 {
                    score -= min(25, Int(counters.droppedFrames) * 3)
                }
                if !isPlaying {
                    score = min(score, 40)
                }
                let finalScore = max(15, min(100, score))

                let grade: HealthGrade = switch finalScore {
                case 88 ... 100: .excellent
                case 70 ..< 88: .good
                case 50 ..< 70: .fair
                default: .critical
                }

                let stability = if jitter <= 5, latency <= 70 {
                    "Ultra Kararlı"
                } else if jitter <= 20, latency <= 160 {
                    "İyi & Dengeli"
                } else if jitter <= 45 {
                    "Hafif Dalgalı"
                } else {
                    "Yüksek Jitter / Risk"
                }

                return StreamHealthMetrics(
                    bufferHealth: bufferPercentage,
                    bufferDurationSeconds: (bufferSeconds * 10).rounded() / 10,
                    networkLatencyMs: latency,
                    networkJitterMs: jitter,
                    droppedFrames: counters.droppedFrames,
                    decodedFrames: counters.decodedFrames,
                    lateFrames: counters.lateFrames,
                    bitrateMbps: (bitrateMbps * 10).rounded() / 10,
                    fps: 50.0,
                    healthScore: finalScore,
                    healthGrade: grade,
                    connectionStability: stability
                )
            }
        )
    }()

    public nonisolated static let testValue = StreamHealthClient(
        measureLatencyAndJitter: { _ in (25, 2) },
        evaluateHealth: { _, _, _, _, _, _ in StreamHealthMetrics() }
    )
}

public extension DependencyValues {
    var streamHealthClient: StreamHealthClient {
        get { self[StreamHealthClient.self] }
        set { self[StreamHealthClient.self] = newValue }
    }
}
