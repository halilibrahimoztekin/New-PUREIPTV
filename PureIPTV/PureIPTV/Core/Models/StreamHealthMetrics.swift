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
    public var bufferHealth: Double // 0.0 ... 1.0 (e.g. 0.85 = 85%)
    public var bufferDurationSeconds: Double // e.g. 4.5 seconds
    public var networkLatencyMs: Int // RTT e.g. 28 ms
    public var networkJitterMs: Int // Variance e.g. 3 ms
    public var droppedFrames: UInt64 // e.g. 0
    public var decodedFrames: UInt64 // e.g. 2450
    public var lateFrames: UInt64 // e.g. 1
    public var bitrateMbps: Double // e.g. 5.8 Mbps
    public var fps: Double // e.g. 60.0 fps
    public var healthScore: Int // 0 ... 100
    public var healthGrade: HealthGrade
    public var connectionStability: String // "Ultra Kararlı", "Hafif Dalgalı", "Dengesiz"

    public nonisolated init(
        bufferHealth: Double = 1.0,
        bufferDurationSeconds: Double = 5.0,
        networkLatencyMs: Int = 30,
        networkJitterMs: Int = 2,
        droppedFrames: UInt64 = 0,
        decodedFrames: UInt64 = 0,
        lateFrames: UInt64 = 0,
        bitrateMbps: Double = 0.0,
        fps: Double = 50.0,
        healthScore: Int = 98,
        healthGrade: HealthGrade = .excellent,
        connectionStability: String = "Ultra Kararlı"
    ) {
        self.bufferHealth = bufferHealth
        self.bufferDurationSeconds = bufferDurationSeconds
        self.networkLatencyMs = networkLatencyMs
        self.networkJitterMs = networkJitterMs
        self.droppedFrames = droppedFrames
        self.decodedFrames = decodedFrames
        self.lateFrames = lateFrames
        self.bitrateMbps = bitrateMbps
        self.fps = fps
        self.healthScore = healthScore
        self.healthGrade = healthGrade
        self.connectionStability = connectionStability
    }
}
