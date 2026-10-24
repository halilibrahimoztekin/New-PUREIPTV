import ComposableArchitecture
import Foundation

public struct StreamHealthClient: Sendable {
    public var measureLatencyAndJitter: @Sendable (_ url: URL) async -> (latencyMs: Int, jitterMs: Int?)?
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
        var lastLatencyMs: Int?
        var lastEndpoint: String?
        var session: URLSession

        init() {
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 2.5
            config.timeoutIntervalForResource = 3.0
            config.waitsForConnectivity = false
            session = URLSession(configuration: config)
        }

        func ping(url: URL) async -> (latencyMs: Int, jitterMs: Int?)? {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let scheme = components.scheme,
                  let host = components.host
            else {
                return nil
            }
            components.user = nil
            components.password = nil
            components.path = ""
            components.query = nil
            components.fragment = nil
            guard let pingURL = components.url else { return nil }

            let endpoint = "\(scheme.lowercased())://\(host.lowercased()):\(components.port ?? -1)"
            if endpoint != lastEndpoint {
                lastEndpoint = endpoint
                lastLatencyMs = nil
            }

            var request = URLRequest(url: pingURL)
            request.httpMethod = "HEAD"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let start = CFAbsoluteTimeGetCurrent()
            do {
                let (_, response) = try await session.data(for: request)
                guard let response = response as? HTTPURLResponse,
                      (200 ..< 400).contains(response.statusCode)
                else { return nil }
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                let currentLatency = max(8, min(999, Int(elapsed * 1000.0)))
                let currentJitter = lastLatencyMs.map { abs(currentLatency - $0) }
                lastLatencyMs = currentLatency
                return (currentLatency, currentJitter)
            } catch {
                // A failed probe is unavailable, not a latency measurement. Keep
                // the last successful sample so the next success can measure jitter.
                return nil
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
                let ping = await tracker.ping(url: url)
                let latency = ping?.latencyMs
                let jitter = ping?.jitterMs

                // Counter deltas are valid only for a recent, advancing playback window.
                // A reset, pause, first sample, or stalled source deliberately reports no rate.
                let validWindow = isPlaying && elapsed > 0 && elapsed <= 5
                let networkThroughputMbps: Double?
                let presentedFPS: Double?
                if validWindow, let previous = prevCounters {
                    if counters.sourceReadBytes > previous.sourceReadBytes {
                        let bytesPerSecond = Double(counters.sourceReadBytes - previous.sourceReadBytes) / elapsed
                        networkThroughputMbps = bytesPerSecond.isFinite ? bytesPerSecond * 8 / 1_000_000 : nil
                    } else {
                        networkThroughputMbps = nil
                    }
                    if counters.presentedFrames > previous.presentedFrames {
                        let framesPerSecond = Double(counters.presentedFrames - previous.presentedFrames) / elapsed
                        presentedFPS = framesPerSecond.isFinite ? framesPerSecond : nil
                    } else {
                        presentedFPS = nil
                    }
                } else {
                    networkThroughputMbps = nil
                    presentedFPS = nil
                }
                let streamBitrateMbps = mediaBitrate.flatMap { $0 > 0 ? Double($0) / 1_000_000 : nil }

                // A health score is meaningful only when latency came from a
                // successful probe. No score or grade is emitted otherwise.
                let finalScore: Int? = latency.map { latency in
                    var score = 100
                    if latency > 60 {
                        score -= min(30, (latency - 60) / 6)
                    }
                    if let jitter, jitter > 10 {
                        score -= min(20, (jitter - 10) * 2)
                    }
                    if counters.droppedFrames > 0 {
                        score -= min(25, Int(counters.droppedFrames) * 3)
                    }
                    if !isPlaying {
                        score = min(score, 40)
                    }
                    return max(15, min(100, score))
                }

                let grade: HealthGrade? = finalScore.map { score in
                    switch score {
                    case 88 ... 100: .excellent
                    case 70 ..< 88: .good
                    case 50 ..< 70: .fair
                    default: .critical
                    }
                }

                let stability: String? = if let latency, let jitter {
                    if jitter <= 5, latency <= 70 {
                        "Ultra Kararlı"
                    } else if jitter <= 20, latency <= 160 {
                        "İyi & Dengeli"
                    } else if jitter <= 45 {
                        "Hafif Dalgalı"
                    } else {
                        "Yüksek Jitter / Risk"
                    }
                } else {
                    nil
                }

                return StreamHealthMetrics(
                    networkLatencyMs: latency,
                    networkJitterMs: jitter,
                    droppedFrames: counters.droppedFrames,
                    decodedFrames: counters.decodedFrames,
                    lateFrames: counters.lateFrames,
                    networkThroughputMbps: networkThroughputMbps.map { ($0 * 10).rounded() / 10 },
                    streamBitrateMbps: streamBitrateMbps.map { ($0 * 10).rounded() / 10 },
                    fps: presentedFPS.map { ($0 * 10).rounded() / 10 },
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
