import ComposableArchitecture
import SwiftUI

public struct OpenSubtitlesSearchView: View {
    @Dependency(\.openSubtitlesClient) private var openSubtitlesClient
    public let itemTitle: String
    public let onSubtitleDownloaded: (URL) -> Void
    public let onClose: () -> Void
    public let isActive: () -> Bool
    public let isInstallingTrack: Bool
    public let installationErrorMessage: String?

    @State private var apiKey = ""
    @State private var query = ""
    @State private var results: [OpenSubtitleSearchResult] = []
    @State private var isSearching = false
    @State private var downloadingResultID: String?
    @State private var errorMessage: String?
    @State private var searchTask: Task<Void, Never>?
    @State private var downloadTask: Task<Void, Never>?

    public init(
        itemTitle: String,
        onSubtitleDownloaded: @escaping (URL) -> Void,
        onClose: @escaping () -> Void,
        isActive: @escaping () -> Bool,
        isInstallingTrack: Bool,
        installationErrorMessage: String?
    ) {
        self.itemTitle = itemTitle
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
                    .disabled(isSearching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
                                        Text([result.languageCode.uppercased(), result.release, "↓ \(result.downloadCount)"]
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
                    query = itemTitle
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

    private func search() {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        errorMessage = nil
        results = []
        searchTask?.cancel()
        searchTask = Task {
            do {
                try await openSubtitlesClient.saveAPIKey(key)
                try Task.checkCancellation()
                guard isActive() else { return }
                let searchResults = try await openSubtitlesClient.search(searchQuery, key)
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
        downloadingResultID = result.id
        errorMessage = nil
        downloadTask?.cancel()
        downloadTask = Task {
            do {
                let url = try await openSubtitlesClient.downloadURL(result.fileID, key)
                try Task.checkCancellation()
                guard isActive() else { return }
                onSubtitleDownloaded(url)
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
