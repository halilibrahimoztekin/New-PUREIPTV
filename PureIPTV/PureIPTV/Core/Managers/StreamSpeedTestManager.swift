import Combine
import Foundation

public struct StreamSpeedResult: Sendable, Equatable {
    public let pingMs: Double
    public let speedMbps: Double
    public let qualityRating: String
    public let recommendedBadge: String

    public init(pingMs: Double, speedMbps: Double) {
        self.pingMs = pingMs
        self.speedMbps = speedMbps

        if speedMbps >= 25.0, pingMs < 80 {
            qualityRating = "Mükemmel (4K HDR & 60 FPS)"
            recommendedBadge = "4K HDR"
        } else if speedMbps >= 12.0, pingMs < 150 {
            qualityRating = "Çok İyi (1080p FHD Kesintisiz)"
            recommendedBadge = "1080p FHD"
        } else if speedMbps >= 5.0 {
            qualityRating = "İyi (720p HD Standart)"
            recommendedBadge = "720p HD"
        } else {
            qualityRating = "Zayıf (Donma & Tamponlama Riski)"
            recommendedBadge = "SD / Donma Riski"
        }
    }
}

public enum SpeedTestState: Equatable, Sendable {
    case idle
    case testingPing
    case testingSpeed(progress: Double, currentMbps: Double)
    case completed(StreamSpeedResult)
    case failed(String)
}

@MainActor
public final class StreamSpeedTestManager: ObservableObject {
    public static let shared = StreamSpeedTestManager()

    @Published public private(set) var state: SpeedTestState = .idle
    private var testTask: Task<Void, Never>?

    private init() {}

    public func startTest(targetURL: URL? = nil) {
        cancelTest()

        // Fallback to a fast public CDN/test segment if targetURL is nil
        let testURL = targetURL ?? URL(string: "https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4")!

        state = .testingPing

        testTask = Task { [weak self] in
            guard let self else { return }

            // 1. Measure Latency (Ping)
            let ping = await measurePing(to: testURL)

            guard !Task.isCancelled else {
                await MainActor.run { self.state = .idle }
                return
            }

            await MainActor.run {
                self.state = .testingSpeed(progress: 0.05, currentMbps: 0.0)
            }

            // 2. Measure Throughput
            let speedMbps = await measureThroughput(from: testURL)

            guard !Task.isCancelled else {
                await MainActor.run { self.state = .idle }
                return
            }

            let result = StreamSpeedResult(pingMs: ping, speedMbps: speedMbps)
            await MainActor.run {
                self.state = .completed(result)
            }
        }
    }

    public func cancelTest() {
        testTask?.cancel()
        testTask = nil
        state = .idle
    }

    private func measurePing(to url: URL) async -> Double {
        var pings: [Double] = []

        for _ in 0 ..< 3 {
            guard !Task.isCancelled else { break }
            let start = CFAbsoluteTimeGetCurrent()
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 3.0

            do {
                _ = try await URLSession.shared.data(for: request)
                let elapsed = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
                pings.append(elapsed)
            } catch {
                // If HEAD fails, record high ping fallback
                pings.append(180.0)
            }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        if pings.isEmpty {
            return 150.0
        }
        let average = pings.reduce(0, +) / Double(pings.count)
        return Double(round(10 * average) / 10)
    }

    private func measureThroughput(from url: URL) async -> Double {
        var request = URLRequest(url: url)
        request.setValue("bytes=0-10485760", forHTTPHeaderField: "Range") // 10MB chunk
        request.timeoutInterval = 8.0

        let start = CFAbsoluteTimeGetCurrent()
        var totalBytes: Int64 = 0

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let expectedLength = response.expectedContentLength > 0 ? response.expectedContentLength : 10_485_760

            for try await _ in bytes {
                totalBytes += 1

                if totalBytes % 131_072 == 0 { // Update UI every 128 KB
                    let elapsed = CFAbsoluteTimeGetCurrent() - start
                    if elapsed > 0.1 {
                        let currentMbps = (Double(totalBytes) * 8.0) / (elapsed * 1_000_000.0)
                        let progress = min(0.95, Double(totalBytes) / Double(expectedLength))

                        await MainActor.run {
                            self.state = .testingSpeed(progress: progress, currentMbps: Double(round(10 * currentMbps) / 10))
                        }
                    }
                }

                if Task.isCancelled || totalBytes >= 10_485_760 {
                    break
                }
            }
        } catch {
            // Fallback or network error
            if totalBytes == 0 {
                return 0.0
            }
        }

        let totalTime = max(0.1, CFAbsoluteTimeGetCurrent() - start)
        let finalMbps = (Double(totalBytes) * 8.0) / (totalTime * 1_000_000.0)
        return Double(round(10 * finalMbps) / 10)
    }
}
