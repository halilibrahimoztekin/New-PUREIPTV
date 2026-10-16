import Foundation

public struct DownloadProgressItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let coverURL: String?
    public var progress: Double // 0.0 ... 1.0
    public var isCompleted: Bool
    public var bytesWritten: Int64
    public var totalBytesExpected: Int64
    public var speedBytesPerSecond: Double

    public init(
        id: String,
        title: String,
        coverURL: String?,
        progress: Double = 0.0,
        isCompleted: Bool = false,
        bytesWritten: Int64 = 0,
        totalBytesExpected: Int64 = 0,
        speedBytesPerSecond: Double = 0
    ) {
        self.id = id
        self.title = title
        self.coverURL = coverURL
        self.progress = progress
        self.isCompleted = isCompleted
        self.bytesWritten = bytesWritten
        self.totalBytesExpected = totalBytesExpected
        self.speedBytesPerSecond = speedBytesPerSecond
    }

    public var formattedProgress: String {
        "%\(Int(progress * 100))"
    }

    public var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        let written = formatter.string(fromByteCount: bytesWritten)
        if totalBytesExpected > 0 {
            let total = formatter.string(fromByteCount: totalBytesExpected)
            return "\(written) / \(total)"
        } else {
            return written
        }
    }

    public var formattedSpeed: String {
        guard speedBytesPerSecond > 0 else { return "" }
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return "\(formatter.string(fromByteCount: Int64(speedBytesPerSecond)))/s"
    }
}
