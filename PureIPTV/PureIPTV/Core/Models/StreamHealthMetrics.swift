import Foundation
import SwiftUI

public enum HealthGrade: String, Equatable, Sendable, CaseIterable {
    case excellent = "KUSURSUZ"
    case good = "İYİ"
    case fair = "ORTA"
    case critical = "KRİTİK"

    public var systemIcon: String {
        switch self {
        case .excellent: "checkmark.shield.fill"
        case .good: "shield.fill"
        case .fair: "exclamationmark.shield.fill"
        case .critical: "xmark.shield.fill"
        }
    }

    public var color: Color {
        switch self {
        case .excellent: Color(hex: "#00F5D4")
        case .good: Color(hex: "#0A84FF")
        case .fair: Color(hex: "#FFD60A")
        case .critical: Color(hex: "#FF453A")
        }
    }
}

public struct StreamHealthMetrics: Equatable, Sendable {
    public var networkLatencyMs: Int? // RTT from a successful HEAD response
    public var networkJitterMs: Int? // Difference between successful RTT samples
    public var droppedFrames: UInt64 // e.g. 0
    public var decodedFrames: UInt64 // e.g. 2450
    public var lateFrames: UInt64 // e.g. 1
    /// Measured from source-read byte deltas; nil when the current sample is invalid.
    public var networkThroughputMbps: Double?
    /// Provider/media metadata, distinct from measured network throughput.
    public var streamBitrateMbps: Double?
    /// Presented video frames per second over the same valid sampling window.
    public var fps: Double?
    public var healthScore: Int? // 0 ... 100 when measured latency is available
    public var healthGrade: HealthGrade?
    public var connectionStability: String?

    public nonisolated init(
        networkLatencyMs: Int? = nil,
        networkJitterMs: Int? = nil,
        droppedFrames: UInt64 = 0,
        decodedFrames: UInt64 = 0,
        lateFrames: UInt64 = 0,
        networkThroughputMbps: Double? = nil,
        streamBitrateMbps: Double? = nil,
        fps: Double? = nil,
        healthScore: Int? = nil,
        healthGrade: HealthGrade? = nil,
        connectionStability: String? = nil
    ) {
        self.networkLatencyMs = networkLatencyMs
        self.networkJitterMs = networkJitterMs
        self.droppedFrames = droppedFrames
        self.decodedFrames = decodedFrames
        self.lateFrames = lateFrames
        self.networkThroughputMbps = networkThroughputMbps
        self.streamBitrateMbps = streamBitrateMbps
        self.fps = fps
        self.healthScore = healthScore
        self.healthGrade = healthGrade
        self.connectionStability = connectionStability
    }
}
