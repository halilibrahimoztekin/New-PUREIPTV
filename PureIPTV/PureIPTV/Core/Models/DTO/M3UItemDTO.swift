import Foundation

public struct M3UItemDTO: Equatable, Identifiable, Sendable {
    public let id: String
    public let title: String
    public let streamURL: URL
    public let coverURL: URL?
    public let groupTitle: String
    public let sourceGroupTitle: String?
    public let tvgID: String?
    public let tvgName: String?
    public let originalLanguageCode: String?
    public let originalLanguageSourceValue: String?
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
        sourceGroupTitle: String? = nil,
        tvgID: String? = nil,
        tvgName: String? = nil,
        originalLanguageCode: String? = nil,
        originalLanguageSourceValue: String? = nil,
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
        self.sourceGroupTitle = sourceGroupTitle
        self.tvgID = tvgID
        self.tvgName = tvgName
        self.originalLanguageSourceValue = originalLanguageSourceValue ?? originalLanguageCode
        self.originalLanguageCode = ISO639LanguageCode.normalize(originalLanguageSourceValue ?? originalLanguageCode)
        self.tvgLogo = tvgLogo
        self.tvgType = tvgType
        self.catchup = catchup
        self.catchupDays = catchupDays
    }
}
