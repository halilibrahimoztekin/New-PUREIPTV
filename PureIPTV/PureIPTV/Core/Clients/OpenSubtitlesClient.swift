import ComposableArchitecture
import Foundation

public struct OpenSubtitleSearchResult: Equatable, Identifiable, Sendable {
    public let id: String
    public let fileID: Int
    public let fileName: String
    public let languageCode: String
    public let release: String
    public let downloadCount: Int
    public let isHearingImpaired: Bool

    public init(
        id: String,
        fileID: Int,
        fileName: String,
        languageCode: String,
        release: String,
        downloadCount: Int,
        isHearingImpaired: Bool
    ) {
        self.id = id
        self.fileID = fileID
        self.fileName = fileName
        self.languageCode = languageCode
        self.release = release
        self.downloadCount = downloadCount
        self.isHearingImpaired = isHearingImpaired
    }
}

public enum OpenSubtitlesClientError: LocalizedError, Sendable {
    case missingAPIKey
    case invalidResponse
    case requestFailed(Int)
    case invalidDownloadURL

    public var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            "OpenSubtitles API key is required."
        case .invalidResponse:
            "OpenSubtitles returned an invalid response."
        case let .requestFailed(statusCode):
            "OpenSubtitles request failed (HTTP \(statusCode))."
        case .invalidDownloadURL:
            "OpenSubtitles returned an unsafe subtitle URL."
        }
    }
}

@DependencyClient
public struct OpenSubtitlesClient: Sendable {
    public var savedAPIKey: @Sendable () -> String? = { nil }
    public var saveAPIKey: @Sendable (_ value: String) async throws -> Void
    public var search: @Sendable (_ query: String, _ apiKey: String) async throws -> [OpenSubtitleSearchResult]
    public var downloadURL: @Sendable (_ fileID: Int, _ apiKey: String) async throws -> URL
}

extension OpenSubtitlesClient: DependencyKey {
    private nonisolated static let apiKeyAccount = "com.pureiptv.opensubtitles.apiKey"
    private nonisolated static let baseURL = URL(string: "https://api.opensubtitles.com/api/v1")!
    private nonisolated static let userAgent = "PureIPTV/1.0"

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

                let language: String?
                let release: String?
                let downloadCount: Int?
                let hearingImpaired: Bool?
                let files: [File]?

                enum CodingKeys: String, CodingKey {
                    case language
                    case release
                    case downloadCount = "download_count"
                    case hearingImpaired = "hearing_impaired"
                    case files
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
            search: { query, apiKey in
                let cleanedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
                let cleanedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !cleanedKey.isEmpty else { throw OpenSubtitlesClientError.missingAPIKey }
                guard !cleanedQuery.isEmpty else { return [] }
                guard var components = URLComponents(url: baseURL.appending(path: "subtitles"), resolvingAgainstBaseURL: false) else {
                    throw OpenSubtitlesClientError.invalidResponse
                }
                components.queryItems = [
                    URLQueryItem(name: "query", value: cleanedQuery.lowercased()),
                    URLQueryItem(name: "machine_translated", value: "exclude"),
                    URLQueryItem(name: "page", value: "1"),
                ]
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
                            isHearingImpaired: entry.attributes.hearingImpaired ?? false
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
