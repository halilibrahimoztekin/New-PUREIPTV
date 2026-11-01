import ComposableArchitecture
import SwiftUI

public struct OpenSubtitlesSearchView: View {
    @Dependency(\.openSubtitlesClient) private var openSubtitlesClient
    @Dependency(\.settingsClient) private var settingsClient
    public let itemTitle: String
    public let searchTitle: String
    public let contentType: OpenSubtitleContentType
    public let seasonNumber: Int?
    public let episodeNumber: Int?
    public let onSubtitleDownloaded: (URL) -> Void
    public let onClose: () -> Void
    public let isActive: () -> Bool
    public let isInstallingTrack: Bool
    public let installationErrorMessage: String?

    @State private var apiKey = ""
    @State private var query = ""
    @State private var activeSearchTitle = ""
    @State private var selectedLanguage = "all"
    @State private var selectedTextEncoding: ExternalSubtitleTextEncoding = .automatic
    @State private var results: [OpenSubtitleSearchResult] = []
    @State private var isSearching = false
    @State private var downloadingResultID: String?
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var downloadTask: Task<Void, Never>?

    public init(
        itemTitle: String,
        searchTitle: String? = nil,
        contentType: OpenSubtitleContentType = .movie,
        seasonNumber: Int? = nil,
        episodeNumber: Int? = nil,
        onSubtitleDownloaded: @escaping (URL) -> Void,
        onClose: @escaping () -> Void,
        isActive: @escaping () -> Bool,
        isInstallingTrack: Bool,
        installationErrorMessage: String?
    ) {
        self.itemTitle = itemTitle
        self.searchTitle = searchTitle ?? itemTitle
        self.contentType = contentType
        self.seasonNumber = seasonNumber
        self.episodeNumber = episodeNumber
        self.onSubtitleDownloaded = onSubtitleDownloaded
        self.onClose = onClose
        self.isActive = isActive
        self.isInstallingTrack = isInstallingTrack
        self.installationErrorMessage = installationErrorMessage
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField(AppStrings.Player.openSubtitlesAPIKey, text: $apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text(AppStrings.Player.openSubtitlesAPIKeyHint)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Link(AppStrings.Player.getOpenSubtitlesAPIKey, destination: URL(string: "https://www.opensubtitles.com/consumers")!)
                } header: {
                    Text("OpenSubtitles")
                }

                Section {
                    TextField(AppStrings.Player.subtitleSearchQuery, text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker(AppStrings.Player.subtitleSearchLanguage, selection: $selectedLanguage) {
                        Text(AppStrings.Player.subtitleSearchAllLanguages).tag("all")
                        Text("🇹🇷 Türkçe").tag("tr")
                        Text("🇬🇧 English").tag("en")
                        Text("🇩🇪 Deutsch").tag("de")
                        Text("🇫🇷 Français").tag("fr")
                        Text("🇪🇸 Español").tag("es")
                        Text("🇮🇹 Italiano").tag("it")
                        Text("🇷🇺 Русский").tag("ru")
                        Text("🇸🇦 العربية").tag("ar")
                    }
                    Picker(
                        AppStrings.Player.subtitleTextEncoding,
                        selection: Binding(
                            get: { selectedTextEncoding },
                            set: { encoding in
                                selectedTextEncoding = encoding
                                settingsClient.setExternalSubtitleTextEncoding(encoding)
                            }
                        )
                    ) {
                        ForEach(ExternalSubtitleTextEncoding.allCases) { encoding in
                            Text(encoding.title).tag(encoding)
                        }
                    }
                    Text(AppStrings.Player.subtitleTextEncodingDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !isSafeQuery {
                        Text(AppStrings.Player.subtitleSearchTitleOnlyWarning)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Button {
                        search()
                    } label: {
                        HStack {
                            Text(AppStrings.Player.searchSubtitles)
                            if isSearching {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isSearching || !isSafeQuery)
                } header: {
                    Text(itemTitle)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                } else if let installationErrorMessage {
                    Section {
                        Text(installationErrorMessage)
                            .foregroundStyle(.red)
                    }
                }

                if !results.isEmpty {
                    Section(AppStrings.Player.subtitleSearchResults) {
                        if isInstallingTrack {
                            ProgressView()
                        }
                        ForEach(results) { result in
                            Button {
                                add(result)
                            } label: {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(result.fileName)
                                            .font(.subheadline.weight(.semibold))
                                            .lineLimit(2)
                                        let matchSummary = matchSummary(for: result)
                                        Text(matchSummary.text)
                                            .font(.caption.weight(.medium))
                                            .foregroundStyle(matchSummary.tint)
                                            .lineLimit(2)
                                        Text([formatLabel(for: result), result.languageCode.uppercased(), result.release, "↓ \(result.downloadCount)"]
                                            .filter { !$0.isEmpty }
                                            .joined(separator: " · "))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 8)
                                    if downloadingResultID == result.id {
                                        ProgressView()
                                    } else {
                                        Image(systemName: "captions.bubble.fill")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                            .disabled(downloadingResultID != nil || isInstallingTrack)
                        }
                    }
                } else if !isSearching, errorMessage == nil {
                    Section {
                        Text(AppStrings.Player.subtitleSearchEmpty)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle(AppStrings.Player.subtitleOnlineSearch)
            #if !os(tvOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.close, action: onClose)
                    }
                }
                .task {
                    apiKey = openSubtitlesClient.savedAPIKey() ?? ""
                    query = searchTitle
                    let preferredLanguage = settingsClient.playbackDefaults(.vod).preferredSubtitleLanguage.lowercased()
                    selectedLanguage = Self.supportedLanguageCodes.contains(preferredLanguage) ? preferredLanguage : "all"
                    selectedTextEncoding = settingsClient.externalSubtitleTextEncoding()
                }
                .onDisappear {
                    searchTask?.cancel()
                    downloadTask?.cancel()
                }
                .onChange(of: installationErrorMessage) { _, message in
                    if message != nil {
                        downloadingResultID = nil
                    }
                }
        }
    }

    private static let supportedLanguageCodes: Set<String> = ["tr", "en", "de", "fr", "es", "it", "ru", "ar"]

    private var isSafeQuery: Bool {
        OpenSubtitleSearchRequest.isSafeTitleQuery(query)
    }

    private func formatLabel(for result: OpenSubtitleSearchResult) -> String {
        let value = result.fileFormat ?? AppStrings.Player.subtitleSearchUnknownFormat
        return "\(AppStrings.Player.subtitleSearchFormat): \(value)"
    }

    private func matchSummary(for result: OpenSubtitleSearchResult) -> MatchSummary {
        guard let details = result.featureDetails else {
            return MatchSummary(text: unverifiedMatchLabel, tint: .secondary)
        }

        if contentType == .episode {
            let returnedCoordinates: String? = if let season = details.seasonNumber, let episode = details.episodeNumber {
                Self.episodeCoordinates(season: season, episode: episode)
            } else {
                nil
            }
            let parentMatches = details.parentTitle.map { Self.normalizedTitle($0) == Self.normalizedTitle(activeSearchTitle) }
            if let expectedSeason = seasonNumber, let expectedEpisode = episodeNumber,
               let returnedSeason = details.seasonNumber, let returnedEpisode = details.episodeNumber,
               parentMatches == true
            {
                let coordinate = Self.episodeCoordinates(season: returnedSeason, episode: returnedEpisode)
                if expectedSeason == returnedSeason, expectedEpisode == returnedEpisode {
                    return MatchSummary(text: "\(AppStrings.Player.subtitleSearchEpisodeMatch) · \(coordinate)", tint: .green)
                }
                return MatchSummary(text: "\(AppStrings.Player.subtitleSearchDifferentEpisode) · \(coordinate)", tint: .orange)
            }
            let suffix = [details.displayTitle, returnedCoordinates]
                .compactMap(\.self)
                .joined(separator: " · ")
            return MatchSummary(
                text: suffix.isEmpty ? unverifiedMatchLabel : "\(AppStrings.Player.subtitleSearchEpisodeUnverified) · \(suffix)",
                tint: .secondary
            )
        }

        guard let title = details.title ?? details.movieName,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return MatchSummary(text: unverifiedMatchLabel, tint: .secondary)
        }
        if Self.normalizedTitle(title) == Self.normalizedTitle(activeSearchTitle) {
            return MatchSummary(text: "\(AppStrings.Player.subtitleSearchTitleMatch) · \(title)", tint: .green)
        }
        return MatchSummary(text: "\(AppStrings.Player.subtitleSearchTitleUnverified) · \(title)", tint: .secondary)
    }

    private var unverifiedMatchLabel: String {
        contentType == .episode
            ? AppStrings.Player.subtitleSearchEpisodeUnverified
            : AppStrings.Player.subtitleSearchTitleUnverified
    }

    private static func episodeCoordinates(season: Int, episode: Int) -> String {
        "S\(String(format: "%02d", season))E\(String(format: "%02d", episode))"
    }

    private static func normalizedTitle(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map { String($0) }
            .joined()
    }

    private struct MatchSummary {
        let text: String
        let tint: Color
    }

    private func search() {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        activeSearchTitle = searchQuery
        isSearching = true
        errorMessage = nil
        results = []
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await openSubtitlesClient.saveAPIKey(key)
                try Task.checkCancellation()
                guard isActive() else { return }
                let request = OpenSubtitleSearchRequest(
                    query: searchQuery,
                    contentType: contentType,
                    seasonNumber: seasonNumber,
                    episodeNumber: episodeNumber,
                    languageCode: selectedLanguage == "all" ? nil : selectedLanguage
                )
                let searchResults = try await openSubtitlesClient.search(request, key)
                try Task.checkCancellation()
                guard isActive() else { return }
                results = searchResults
            } catch is CancellationError {
                return
            } catch {
                guard isActive() else { return }
                errorMessage = error.localizedDescription
            }
            if isActive() {
                isSearching = false
            }
        }
    }

    private func add(_ result: OpenSubtitleSearchResult) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let textEncoding = selectedTextEncoding
        downloadingResultID = result.id
        errorMessage = nil
        downloadTask?.cancel()
        downloadTask = Task {
            do {
                let url = try await openSubtitlesClient.downloadURL(result.fileID, key)
                try Task.checkCancellation()
                guard isActive() else { return }
                guard textEncoding != .automatic,
                      textEncoding.supportsTextFileFormat(result.fileFormat)
                else {
                    onSubtitleDownloaded(url)
                    return
                }

                let data = try await openSubtitlesClient.downloadData(url)
                try Task.checkCancellation()
                guard let text = textEncoding.decode(data),
                      let fileFormat = result.fileFormat
                else { throw OpenSubtitlesClientError.subtitleEncodingFailed }
                let temporaryURL = try textEncoding.writeUTF8TemporaryFile(text, fileFormat: fileFormat)
                guard !Task.isCancelled, isActive() else {
                    try? FileManager.default.removeItem(at: temporaryURL)
                    return
                }
                onSubtitleDownloaded(temporaryURL)
            } catch is CancellationError {
                return
            } catch {
                guard isActive() else { return }
                errorMessage = error.localizedDescription
                downloadingResultID = nil
            }
        }
    }
}
