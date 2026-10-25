import Combine
import Foundation

public struct StreamSpeedResult: Sendable, Equatable {
    /// Time to receive a successful HTTP response; this is not ICMP ping.
    public let responseTimeMs: Double?
    public let speedMbps: Double
    public let qualityRating: String
    public let recommendedBadge: String
    public let endpointLabel: String

    public init(responseTimeMs: Double?, speedMbps: Double, endpointLabel: String) {
        self.responseTimeMs = responseTimeMs
        self.speedMbps = speedMbps
        self.endpointLabel = endpointLabel

        if speedMbps >= 25.0 {
            qualityRating = "Yüksek bant genişliği tahmini"
            recommendedBadge = "25 Mbps+"
        } else if speedMbps >= 12.0 {
            qualityRating = "Orta-yüksek bant genişliği tahmini"
            recommendedBadge = "12 Mbps+"
        } else if speedMbps >= 5.0 {
            qualityRating = "Orta bant genişliği tahmini"
            recommendedBadge = "5 Mbps+"
        } else {
            qualityRating = "Düşük bant genişliği tahmini"
            recommendedBadge = "5 Mbps altı"
        }
    }
}

public enum SpeedTestState: Equatable, Sendable {
    case idle
    case testingResponseTime
    case testingSpeed(progress: Double, currentMbps: Double)
    case completed(StreamSpeedResult)
    case failed(String)
}

@MainActor
public final class StreamSpeedTestManager: ObservableObject {
    public static let shared = StreamSpeedTestManager()

    @Published public private(set) var state: SpeedTestState = .idle
    private var testTask: Task<Void, Never>?
    private var throughputTask: Task<Double, Never>?
    private var activeTestID: UUID?

    private init() {}

    public func startTest(targetURL: URL? = nil) {
        cancelTest()
        let testID = UUID()
        activeTestID = testID

        // Settings tests the public endpoint. The UI names it explicitly so
        // results are never mistaken for the user's IPTV provider route.
        let defaultURL = URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")
        guard let testURL = targetURL ?? defaultURL else { return }
        let endpointLabel = targetURL?.host ?? "Google Cloud public sample endpoint"

        state = .testingResponseTime

        testTask = Task { [weak self] in
            guard let self else { return }

            // 1. Measure HTTP response time
            let responseTime = await measureResponseTime(to: testURL)

            guard !Task.isCancelled, activeTestID == testID else { return }

            state = .testingSpeed(progress: 0.05, currentMbps: 0.0)

            // 2. Count bytes off MainActor. Only aggregate progress reaches the UI.
            let manager = self
            throughputTask = Task.detached(priority: .utility) {
                await Self.measureThroughput(from: testURL) { progress, currentMbps in
                    await manager.publishProgress(
                        progress: progress,
                        currentMbps: currentMbps,
                        testID: testID
                    )
                }
            }
            guard let throughputTask else { return }
            let speedMbps = await throughputTask.value

            guard !Task.isCancelled, activeTestID == testID else { return }
            self.throughputTask = nil

            guard speedMbps > 0 else {
                activeTestID = nil
                state = .failed("Bu uç noktadan ölçüm tamamlanamadı. Bağlantıyı veya sunucu yanıtını kontrol edin.")
                return
            }

            let result = StreamSpeedResult(
                responseTimeMs: responseTime,
                speedMbps: speedMbps,
                endpointLabel: endpointLabel
            )
            activeTestID = nil
            state = .completed(result)
        }
    }

    public func cancelTest() {
        activeTestID = nil
        testTask?.cancel()
        testTask = nil
        throughputTask?.cancel()
        throughputTask = nil
        state = .idle
    }

    private func publishProgress(progress: Double, currentMbps: Double, testID: UUID) {
        guard activeTestID == testID else { return }
        state = .testingSpeed(progress: progress, currentMbps: currentMbps)
    }

    private func measureResponseTime(to url: URL) async -> Double? {
        var pings: [Double] = []

        for _ in 0 ..< 3 {
            guard !Task.isCancelled else { break }
            let start = CFAbsoluteTimeGetCurrent()
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 3.0

            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                guard let response = response as? HTTPURLResponse,
                      (200 ..< 400).contains(response.statusCode) else { continue }
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                pings.append(elapsed)
            } catch {
                // Failed HTTP requests are unavailable measurements, not latency samples.
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        guard !pings.isEmpty else { return nil }
        let average = pings.reduce(0, +) / Double(pings.count)
        return Double(round(10 * average) / 10)
    }

    private nonisolated static func measureThroughput(
        from url: URL,
        onProgress: @escaping @Sendable (Double, Double) async -> Void
    ) async -> Double {
        var request = URLRequest(url: url)
        let byteLimit: Int64 = 2_097_152
        request.setValue("bytes=0-\(byteLimit - 1)", forHTTPHeaderField: "Range")
        request.timeoutInterval = 8.0

        let start = CFAbsoluteTimeGetCurrent()
        var totalBytes: Int64 = 0

        do {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = 8
            configuration.timeoutIntervalForResource = 8
            configuration.waitsForConnectivity = false
            let session = URLSession(configuration: configuration)
            defer { session.invalidateAndCancel() }

            let (bytes, response) = try await session.bytes(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 || httpResponse.statusCode == 206 else { return 0 }
            let expectedLength = response.expectedContentLength > 0
                ? min(response.expectedContentLength, byteLimit)
                : byteLimit

            for try await _ in bytes {
                totalBytes += 1

                if totalBytes % 131_072 == 0 { // Update UI every 128 KB
                    let elapsed = CFAbsoluteTimeGetCurrent() - start
                    if elapsed > 0.1 {
                        let currentMbps = (Double(totalBytes) * 8.0) / (elapsed * 1_000_000.0)
                        let progress = min(0.95, Double(totalBytes) / Double(expectedLength))

                        await onProgress(progress, Double(round(10 * currentMbps) / 10))
                    }
                }

                if Task.isCancelled || totalBytes >= byteLimit {
                    break
                }
            }
        } catch {
            // A partial response is not a valid throughput measurement.
            return 0
        }

        let totalTime = max(0.1, CFAbsoluteTimeGetCurrent() - start)
        let finalMbps = (Double(totalBytes) * 8.0) / (totalTime * 1_000_000.0)
        return Double(round(10 * finalMbps) / 10)
    }
}
