import Foundation

public struct DownloadProgressItem: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let coverURL: String?
    public var progress: Double // 0.0 ... 1.0
    public var isCompleted: Bool

    public init(id: String, title: String, coverURL: String?, progress: Double = 0.0, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.coverURL = coverURL
        self.progress = progress
        self.isCompleted = isCompleted
    }
}
