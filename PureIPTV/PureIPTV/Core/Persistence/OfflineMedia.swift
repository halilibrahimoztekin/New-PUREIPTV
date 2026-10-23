import Foundation
import SwiftData

@Model
public final class OfflineMedia {
    public var id: String = "" // VOD ID or Episode ID
    public var title: String = ""
    public var localFilePath: String = ""
    public var coverURL: String?
    public var downloadedAt: Date = Date()
    public var fileSize: Int64 = 0

    public init(id: String, title: String, localFilePath: String, coverURL: String?, fileSize: Int64) {
        self.id = id
        self.title = title
        self.localFilePath = localFilePath
        self.coverURL = coverURL
        self.fileSize = fileSize
        downloadedAt = Date()
    }
}
