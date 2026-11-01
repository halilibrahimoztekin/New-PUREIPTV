import ComposableArchitecture
import Foundation

public enum OpenSubtitleContentType: String, Equatable, Sendable {
    case movie
    case episode
}

public struct OpenSubtitleSearchRequest: Equatable, Sendable {
    public let query: String
    public let contentType: OpenSubtitleContentType
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let languageCode: String?

    public init(
        query: String,
        contentType: OpenSubtitleContentType,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        languageCode: String? = nil
    ) {
        self.query = query
        self.contentType = contentType
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.languageCode = languageCode
    }

    public static func isSafeTitleQuery(_ value: String) -> Bool {
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty, query.count <= 120,
              query.rangeOfCharacter(from: .controlCharacters) == nil
        else { return false }

        let blockedPatterns = [
            #"(?i)[a-z][a-z0-9+.-]*://"#,
            #"(?i)\b(?:[a-z0-9-]+\.)+[a-z]{2,}(?::\d+)?(?:[/?#\s]|$)"#,
            #"(?i)\b(?:localhost|(?:\d{1,3}\.){3}\d{1,3})(?::\d+)?(?:[/?#\s]|$)"#,
            #"(?i)(?:^|[?&\s])(?:username|password|token|auth|api[_-]?key)="#,
            #"(?i)\.(?:m3u8?|mp4|mkv|avi|ts)(?:$|[?#\s])"#,
        ]
        let fullRange = NSRange(query.startIndex..., in: query)
        return blockedPatterns.allSatisfy { pattern in
            guard let expression = try? NSRegularExpression(pattern: pattern) else { return false }
            return expression.firstMatch(in: query, range: fullRange) == nil
        }
    }
}

public struct OpenSubtitleFeatureDetails: Equatable, Sendable {
    public let title: String?
    public let movieName: String?
    public let featureType: String?
    public let parentTitle: String?
    public let seasonNumber: Int?
    public let episodeNumber: Int?

    public init(
        title: String? = nil,
        movieName: String? = nil,
        featureType: String? = nil,
        parentTitle: String? = nil,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil
    ) {
        self.title = title
        self.movieName = movieName
        self.featureType = featureType
        self.parentTitle = parentTitle
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
    }

    public var displayTitle: String? {
        [parentTitle, movieName, title]
            .compactMap { value in
                guard let value else { return nil }
                let cleaned = value.trimmingCharacters(in: .whitespacesAndNewlines)
                return cleaned.isEmpty ? nil : cleaned
            }
            .first
    }
}

public struct OpenSubtitleSearchResult: Equatable, Identifiable, Sendable {
    public let id: String
    public let fileID: Int
    public let fileName: String
    public let languageCode: String
    public let release: String
    public let downloadCount: Int
    public let isHearingImpaired: Bool
    public let featureDetails: OpenSubtitleFeatureDetails?

    public init(
        id: String,
        fileID: Int,
        fileName: String,
        languageCode: String,
        release: String,
        downloadCount: Int,
        isHearingImpaired: Bool,
        featureDetails: OpenSubtitleFeatureDetails? = nil
    ) {
        self.id = id
        self.fileID = fileID
        self.fileName = fileName
        self.languageCode = languageCode
        self.release = release
        self.downloadCount = downloadCount
        self.isHearingImpaired = isHearingImpaired
        self.featureDetails = featureDetails
    }

    public var fileFormat: String? {
        let ext = URL(fileURLWithPath: fileName).pathExtension
        guard !ext.isEmpty, ext.count <= 8,
              ext.unicodeScalars.allSatisfy({ CharacterSet.alphanumerics.contains($0) })
        else { return nil }
        return ext.uppercased()
    }
}

public enum OpenSubtitlesClientError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidSearchQuery
    case invalidResponse
    case requestFailed(Int)
    case invalidDownloadURL
    case subtitleFileTooLarge
    case subtitleEncodingFailed

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            AppStrings.Player.openSubtitlesAPIKeyRequired
        case .invalidSearchQuery:
            AppStrings.Player.subtitleSearchTitleOnlyWarning
        case .invalidResponse:
            AppStrings.Player.openSubtitlesInvalidResponse
        case let .requestFailed(statusCode):
            String(format: AppStrings.Player.openSubtitlesRequestFailed, statusCode)
        case .invalidDownloadURL:
            AppStrings.Player.openSubtitlesInvalidDownloadURL
        case .subtitleFileTooLarge:
            AppStrings.Player.subtitleFileTooLarge
        case .subtitleEncodingFailed:
            AppStrings.Player.subtitleEncodingFailed
        }
    }
}

@DependencyClient
public struct OpenSubtitlesClient: Sendable {
    public var savedAPIKey: @Sendable () -> String? = { nil }
    public var saveAPIKey: @Sendable (_ value: String) async throws -> Void
    public var search: @Sendable (_ request: OpenSubtitleSearchRequest, _ apiKey: String) async throws -> [OpenSubtitleSearchResult]
    public var downloadURL: @Sendable (_ fileID: Int, _ apiKey: String) async throws -> URL
    public var downloadData: @Sendable (_ url: URL) async throws -> Data = { _ in
        throw OpenSubtitlesClientError.invalidResponse
    }
}

extension OpenSubtitlesClient: DependencyKey {
    private nonisolated static let apiKeyAccount = "com.pureiptv.opensubtitles.apiKey"
    private nonisolated static let baseURL = URL(string: "https://api.opensubtitles.com/api/v1")!
    private nonisolated static let userAgent = "PureIPTV/1.0"
    private nonisolated static let maximumSubtitleFileBytes = 8 * 1024 * 1024

    private struct SearchResponse: Decodable {
        struct Entry: Decodable {
            struct Attributes: Decodable {
                struct File: Decodable {
                    let fileID: Int?
                    let fileName: String?

                    enum CodingKeys: String, CodingKey {
                        case fileID = "file_id"
                        case fileName = "file_name"
                    }
                }

                struct FeatureDetails: Decodable {
                    let title: String?
                    let movieName: String?
                    let featureType: String?
                    let parentTitle: String?
                    let seasonNumber: Int?
                    let episodeNumber: Int?

                    enum CodingKeys: String, CodingKey {
                        case title
                        case movieName = "movie_name"
                        case featureType = "feature_type"
                        case parentTitle = "parent_title"
                        case seasonNumber = "season_number"
                        case episodeNumber = "episode_number"
                    }
                }

                let language: String?
                let release: String?
                let downloadCount: Int?
                let hearingImpaired: Bool?
                let files: [File]?
                let featureDetails: FeatureDetails?

                enum CodingKeys: String, CodingKey {
                    case language
                    case release
                    case downloadCount = "download_count"
                    case hearingImpaired = "hearing_impaired"
                    case files
                    case featureDetails = "feature_details"
                }
            }

            let id: String
            let attributes: Attributes
        }

        let data: [Entry]
    }

    private struct DownloadRequest: Encodable {
        let fileID: Int
        enum CodingKeys: String, CodingKey { case fileID = "file_id" }
    }

    private struct DownloadResponse: Decodable {
        let link: URL
    }

    private static func makeRequest(url: URL, apiKey: String, method: String = "GET") -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(apiKey, forHTTPHeaderField: "Api-Key")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    public nonisolated static let liveValue: OpenSubtitlesClient = {
        let session = URLSession.shared
        return OpenSubtitlesClient(
            savedAPIKey: {
                try? KeychainManager.shared.retrieve(for: apiKeyAccount, as: String.self)
            },
            saveAPIKey: { value in
                let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if key.isEmpty {
                    try KeychainManager.shared.delete(for: apiKeyAccount)
                } else {
                    try KeychainManager.shared.save(key, for: apiKeyAccount)
                }
            },
            search: { searchRequest, apiKey in
                let cleanedQuery = searchRequest.query.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanedKey.isEmpty else { throw OpenSubtitlesClientError.missingAPIKey }
                guard OpenSubtitleSearchRequest.isSafeTitleQuery(cleanedQuery) else {
                    throw OpenSubtitlesClientError.invalidSearchQuery
                }
                guard var components = URLComponents(url: baseURL.appending(path: "subtitles"), resolvingAgainstBaseURL: false) else {
                    throw OpenSubtitlesClientError.invalidResponse
                }
                var queryItems = [
                    URLQueryItem(name: "query", value: cleanedQuery.lowercased()),
                    URLQueryItem(name: "type", value: searchRequest.contentType.rawValue),
                ]
                if searchRequest.contentType == .episode {
                    if let seasonNumber = searchRequest.seasonNumber, seasonNumber >= 0 {
                        queryItems.append(URLQueryItem(name: "season_number", value: String(seasonNumber)))
                    }
                    if let episodeNumber = searchRequest.episodeNumber, episodeNumber > 0 {
                        queryItems.append(URLQueryItem(name: "episode_number", value: String(episodeNumber)))
                    }
                }
                if let languageCode = searchRequest.languageCode?.lowercased(),
                   languageCode.range(of: #"^[a-z]{2,3}$"#, options: .regularExpression) != nil
                {
                    queryItems.append(URLQueryItem(name: "languages", value: languageCode))
                }
                components.queryItems = queryItems.sorted { $0.name < $1.name }
                guard let url = components.url else { throw OpenSubtitlesClientError.invalidResponse }
                let (data, response) = try await session.data(for: makeRequest(url: url, apiKey: cleanedKey))
                guard let http = response as? HTTPURLResponse else { throw OpenSubtitlesClientError.invalidResponse }
                guard (200 ..< 300).contains(http.statusCode) else { throw OpenSubtitlesClientError.requestFailed(http.statusCode) }
                let decoded = try JSONDecoder().decode(SearchResponse.self, from: data)
                return decoded.data.flatMap { entry in
                    (entry.attributes.files ?? []).compactMap { file in
                        guard let fileID = file.fileID, let fileName = file.fileName else { return nil }
                        return OpenSubtitleSearchResult(
                            id: "\(entry.id)-\(fileID)",
                            fileID: fileID,
                            fileName: fileName,
                            languageCode: entry.attributes.language ?? "",
                            release: entry.attributes.release ?? "",
                            downloadCount: entry.attributes.downloadCount ?? 0,
                            isHearingImpaired: entry.attributes.hearingImpaired ?? false,
                            featureDetails: entry.attributes.featureDetails.map {
                                OpenSubtitleFeatureDetails(
                                    title: $0.title,
                                    movieName: $0.movieName,
                                    featureType: $0.featureType,
                                    parentTitle: $0.parentTitle,
                                    seasonNumber: $0.seasonNumber,
                                    episodeNumber: $0.episodeNumber
                                )
                            }
                        )
                    }
                }.prefix(60).map(\.self)
            },
            downloadURL: { fileID, apiKey in
                let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanedKey.isEmpty else { throw OpenSubtitlesClientError.missingAPIKey }
                let url = baseURL.appending(path: "download")
                var request = makeRequest(url: url, apiKey: cleanedKey, method: "POST")
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONEncoder().encode(DownloadRequest(fileID: fileID))
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw OpenSubtitlesClientError.invalidResponse }
                guard (200 ..< 300).contains(http.statusCode) else { throw OpenSubtitlesClientError.requestFailed(http.statusCode) }
                let decoded = try JSONDecoder().decode(DownloadResponse.self, from: data)
                guard decoded.link.scheme?.lowercased() == "https",
                      let host = decoded.link.host?.lowercased(),
                      host == "opensubtitles.com" || host.hasSuffix(".opensubtitles.com")
                else { throw OpenSubtitlesClientError.invalidDownloadURL }
                return decoded.link
            },
            downloadData: { url in
                guard url.scheme?.lowercased() == "https",
                      let host = url.host?.lowercased(),
                      host == "opensubtitles.com" || host.hasSuffix(".opensubtitles.com")
                else { throw OpenSubtitlesClientError.invalidDownloadURL }

                let (bytes, response) = try await session.bytes(from: url)
                guard let http = response as? HTTPURLResponse else { throw OpenSubtitlesClientError.invalidResponse }
                guard (200 ..< 300).contains(http.statusCode) else { throw OpenSubtitlesClientError.requestFailed(http.statusCode) }
                guard http.url?.scheme?.lowercased() == "https",
                      let finalHost = http.url?.host?.lowercased(),
                      finalHost == "opensubtitles.com" || finalHost.hasSuffix(".opensubtitles.com")
                else { throw OpenSubtitlesClientError.invalidDownloadURL }
                if http.expectedContentLength > Int64(maximumSubtitleFileBytes) {
                    throw OpenSubtitlesClientError.subtitleFileTooLarge
                }

                var data = Data()
                if http.expectedContentLength > 0 {
                    data.reserveCapacity(min(Int(http.expectedContentLength), maximumSubtitleFileBytes))
                }
                for try await byte in bytes {
                    if data.count >= maximumSubtitleFileBytes {
                        throw OpenSubtitlesClientError.subtitleFileTooLarge
                    }
                    data.append(byte)
                    if data.count.isMultiple(of: 64 * 1024) {
                        try Task.checkCancellation()
                    }
                }
                guard !data.isEmpty else { throw OpenSubtitlesClientError.invalidResponse }
                return data
            }
        )
    }()
}

public extension DependencyValues {
    var openSubtitlesClient: OpenSubtitlesClient {
        get { self[OpenSubtitlesClient.self] }
        set { self[OpenSubtitlesClient.self] = newValue }
    }
}
