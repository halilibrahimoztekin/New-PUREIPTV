import ComposableArchitecture
import SwiftUI

public struct OpenSubtitlesSearchView: View {
    @Dependency(\.openSubtitlesClient) private var openSubtitlesClient
    @Dependency(\.playerClient) private var playerClient
    @Environment(\.dismiss) private var dismiss

    public let itemTitle: String
    public let onTrackAdded: () -> Void

    @State private var apiKey = ""
    @State private var query = ""
    @State private var results: [OpenSubtitleSearchResult] = []
    @State private var isSearching = false
    @State private var downloadingResultID: String?
    @State private var errorMessage: String?

    public init(itemTitle: String, onTrackAdded: @escaping () -> Void) {
        self.itemTitle = itemTitle
        self.onTrackAdded = onTrackAdded
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
                }

                if !results.isEmpty {
                    Section(AppStrings.Player.subtitleSearchResults) {
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
                            .disabled(downloadingResultID != nil)
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
                        Button(AppStrings.Common.close) { dismiss() }
                    }
                }
                .task {
                    apiKey = openSubtitlesClient.savedAPIKey() ?? ""
                    query = itemTitle
                }
        }
    }

    private func search() {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        isSearching = true
        errorMessage = nil
        results = []
        Task {
            do {
                try await openSubtitlesClient.saveAPIKey(key)
                results = try await openSubtitlesClient.search(searchQuery, key)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSearching = false
        }
    }

    private func add(_ result: OpenSubtitleSearchResult) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        downloadingResultID = result.id
        errorMessage = nil
        Task {
            do {
                let url = try await openSubtitlesClient.downloadURL(result.fileID, key)
                guard await playerClient.addExternalSubtitleTrack(url) else {
                    errorMessage = AppStrings.Player.externalSubtitleAddFailed
                    downloadingResultID = nil
                    return
                }
                onTrackAdded()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                downloadingResultID = nil
            }
        }
    }
}
