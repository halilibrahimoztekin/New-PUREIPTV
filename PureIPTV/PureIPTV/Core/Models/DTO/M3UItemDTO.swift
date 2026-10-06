import Foundation

public struct M3UItemDTO: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let streamURL: URL
    public let coverURL: URL?
    public let groupTitle: String
    public let tvgID: String?
    public let tvgName: String?
    public let tvgLogo: String?
    public let tvgType: String?
    public let catchup: String?
    public let catchupDays: Int?

    public init(
        id: String = UUID().uuidString,
        title: String,
        streamURL: URL,
        coverURL: URL? = nil,
        groupTitle: String,
        tvgID: String? = nil,
        tvgName: String? = nil,
        tvgLogo: String? = nil,
        tvgType: String? = nil,
        catchup: String? = nil,
        catchupDays: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.streamURL = streamURL
        self.coverURL = coverURL
        self.groupTitle = groupTitle
        self.tvgID = tvgID
        self.tvgName = tvgName
        self.tvgLogo = tvgLogo
        self.tvgType = tvgType
        self.catchup = catchup
        self.catchupDays = catchupDays
    }
}
