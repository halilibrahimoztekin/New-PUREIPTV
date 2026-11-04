import ComposableArchitecture
import FactoryKit
import Foundation
import SwiftUI

// MARK: - SearchFeature / GlobalSearchFeature

/// Cancel ID must be fully Sendable and non-isolated to avoid
/// main-actor isolation conflicts with the @Reducer macro.
private let searchCancelID = "SearchFeature.search"
private let searchCatalogLoadCancelID = "SearchFeature.catalogLoad"
private let searchMultiPlaylistLoadCancelID = "SearchFeature.multiPlaylistLoad"
private let searchCatalogPrepareCancelID = "SearchFeature.catalogPrepare"
private let searchMultiPlaylistPrepareCancelID = "SearchFeature.multiPlaylistPrepare"
private let searchEPGCancelID = "SearchFeature.searchEPG"
private let searchPeopleCancelID = "SearchFeature.searchPeople"
private let searchProgramsCancelID = "SearchFeature.searchPrograms"
private let searchOfflineMediaCancelID = "SearchFeature.searchOfflineMedia"
private let searchOfflinePlaybackCancelID = "SearchFeature.searchOfflinePlayback"
private let searchCategoryPreferencesCancelID = "SearchFeature.categoryPreferences"
#if os(tvOS)
    private let searchTypingDebounceDuration = Duration.milliseconds(450)
#else
    private let searchTypingDebounceDuration = Duration.milliseconds(250)
#endif

private nonisolated func searchSourceBadge(for config: PlaylistConfig?) -> PlaylistSourceBadge {
    guard let config else {
        return PlaylistSourceBadge(id: "default", playlistName: "Varsayılan", colorHex: "#0A84FF")
    }
    return UnifiedPlaylistManager.shared.badge(for: config)
}

public typealias SearchPrimaryCatalogData = (
    channels: [MediaModels.Item],
    vods: [MediaModels.Item],
    series: [MediaModels.Item],
    categories: [CategorySearchResultItem]
)
public typealias SearchMultiPlaylistCatalogData = [(
    badge: PlaylistSourceBadge,
    channels: [MediaModels.Item],
    vods: [MediaModels.Item],
    series: [MediaModels.Item],
    categories: [CategorySearchResultItem]
)]

public nonisolated struct PreparedSearchPrimaryCatalog: Sendable {
    let channels: [MediaModels.Item]
    let vods: [MediaModels.Item]
    let series: [MediaModels.Item]
    let categories: [CategorySearchResultItem]
    let indexedChannels: [GlobalSearchResultItem]
    let indexedVODs: [GlobalSearchResultItem]
    let indexedSeries: [GlobalSearchResultItem]
}

public nonisolated struct PreparedSearchMultiPlaylistCatalog: Sendable {
    let channels: [GlobalSearchResultItem]
    let vods: [GlobalSearchResultItem]
    let series: [GlobalSearchResultItem]
    let categories: [CategorySearchResultItem]
}

private nonisolated func prepareSearchPrimaryCatalog(
    _ data: SearchPrimaryCatalogData,
    hiddenChannelIDs: Set<String>,
    blacklistedCategoryIDs: Set<String>,
    hideAdult: Bool,
    isAdultContent: @Sendable (String) -> Bool,
    hiddenMediaEntries: [HiddenMediaEntry],
    fallbackPlaylistID: UUID?,
    badge: PlaylistSourceBadge
) -> PreparedSearchPrimaryCatalog {
    let channels = data.channels.filter { item in
        !hiddenChannelIDs.contains(item.id)
            && !blacklistedCategoryIDs.contains(item.categoryID)
            && (!hideAdult || !isAdultContent(item.title))
    }
    let vods = data.vods.filter { !hideAdult || !isAdultContent($0.title) }
    let series = data.series.filter { !hideAdult || !isAdultContent($0.title) }
    let categories = data.categories.filter { item in
        !blacklistedCategoryIDs.contains(item.category.id)
            && (!hideAdult || (!isAdultContent(item.category.name) && !isAdultContent(item.category.sourceName)))
    }
    let hidden = Set(hiddenMediaEntries.map(\.identity))
    let visibleVODs = vods.filter {
        !hidden.contains(HiddenMediaIdentity(item: $0, fallbackPlaylistID: fallbackPlaylistID))
    }
    let visibleSeries = series.filter {
        !hidden.contains(HiddenMediaIdentity(item: $0, fallbackPlaylistID: fallbackPlaylistID))
    }
    return PreparedSearchPrimaryCatalog(
        channels: channels,
        vods: visibleVODs,
        series: visibleSeries,
        categories: categories,
        indexedChannels: channels.map { GlobalSearchResultItem(item: $0, playlistBadge: badge) },
        indexedVODs: visibleVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: badge) },
        indexedSeries: visibleSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: badge) }
    )
}

private nonisolated func prepareSearchMultiPlaylistCatalog(
    _ list: SearchMultiPlaylistCatalogData,
    hiddenChannelIDs: Set<String>,
    blacklistedCategoryIDs: Set<String>,
    hideAdult: Bool,
    isAdultContent: @Sendable (String) -> Bool,
    hiddenMediaEntries: [HiddenMediaEntry]
) -> PreparedSearchMultiPlaylistCatalog {
    var channels: [GlobalSearchResultItem] = []
    var vods: [GlobalSearchResultItem] = []
    var series: [GlobalSearchResultItem] = []
    var categories: [CategorySearchResultItem] = []
    let hidden = Set(hiddenMediaEntries.map(\.identity))
    for playlist in list {
        let visibleChannels = playlist.channels.filter { item in
            !hiddenChannelIDs.contains(item.id)
                && !blacklistedCategoryIDs.contains(item.categoryID)
                && (!hideAdult || !isAdultContent(item.title))
        }
        let visibleVODs = playlist.vods.filter { item in
            (!hideAdult || !isAdultContent(item.title))
                && !hidden.contains(HiddenMediaIdentity(item: item, fallbackPlaylistID: item.playlistID))
        }
        let visibleSeries = playlist.series.filter { item in
            (!hideAdult || !isAdultContent(item.title))
                && !hidden.contains(HiddenMediaIdentity(item: item, fallbackPlaylistID: item.playlistID))
        }
        let visibleCategories = playlist.categories.filter { item in
            !blacklistedCategoryIDs.contains(item.category.id)
                && (!hideAdult || (!isAdultContent(item.category.name) && !isAdultContent(item.category.sourceName)))
        }
        channels.append(contentsOf: visibleChannels.map { GlobalSearchResultItem(item: $0, playlistBadge: playlist.badge) })
        vods.append(contentsOf: visibleVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: playlist.badge) })
        series.append(contentsOf: visibleSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: playlist.badge) })
        categories.append(contentsOf: visibleCategories)
    }
    return PreparedSearchMultiPlaylistCatalog(channels: channels, vods: vods, series: series, categories: categories)
}

private nonisolated struct SearchCatalogSource: Equatable, Sendable {
    let id: UUID
    let config: PlaylistConfig?
}

private nonisolated func searchCatalogSources(_ playlists: [SavedPlaylist]) -> [SearchCatalogSource] {
    playlists.map { SearchCatalogSource(id: $0.id, config: $0.toPlaylistConfig()) }
}

private nonisolated func lengthPrefixedSearchIdentity(_ components: [String]) -> String {
    components.map { "\($0.utf8.count):\($0)" }.joined()
}

private nonisolated func globalSearchResultIdentity(_ result: GlobalSearchResultItem) -> String {
    "search-result-v1|" + lengthPrefixedSearchIdentity([result.item.type.rawValue, result.playlistBadge.id, result.item.id])
}

private nonisolated func searchCategoryPreferenceIdentity(type: String, playlistID: UUID?, categoryID: String) -> String {
    lengthPrefixedSearchIdentity([type, playlistID?.uuidString ?? "legacy", categoryID])
}

private nonisolated func isIncludedInSearchContentScope(
    _ result: GlobalSearchResultItem,
    scope: SearchFeature.SearchContentScope,
    hiddenCategoryPreferenceIDs: Set<String>,
    curatedPlaylistEntryIDs: Set<String>,
    playlistIDsByBadgeID: [String: UUID],
    fallbackPlaylistID: UUID?
) -> Bool {
    switch scope {
    case .all:
        return true
    case .myCategories:
        guard !result.item.categoryID.isEmpty else { return true }
        let playlistID = result.item.playlistID
            ?? playlistIDsByBadgeID[result.playlistBadge.id]
            ?? fallbackPlaylistID
        return !hiddenCategoryPreferenceIDs.contains(
            searchCategoryPreferenceIdentity(
                type: result.item.type.rawValue,
                playlistID: playlistID,
                categoryID: result.item.categoryID
            )
        )
    case .pinned:
        guard let playlistID = result.item.playlistID
            ?? playlistIDsByBadgeID[result.playlistBadge.id]
            ?? fallbackPlaylistID
        else { return false }
        let entryID = CuratedPlaylistEntry.identity(
            playlistID: playlistID,
            contentType: result.item.type.rawValue,
            itemID: result.item.id
        )
        return curatedPlaylistEntryIDs.contains(entryID)
    }
}

private nonisolated func orderedOfflineSearchEpisodeQueue(
    startingWith current: OfflineMediaSnapshot,
    downloadedItems: [OfflineMediaSnapshot]
) -> [OfflineMediaSnapshot] {
    guard let metadata = current.episodeMetadata,
          metadata.episodeOrdinal != nil,
          let playlistID = metadata.playlistID,
          current.isAvailable,
          current.fileSize > 0
    else { return [] }

    let episodes = downloadedItems.filter { item in
        guard item.isAvailable,
              item.fileSize > 0,
              let candidate = item.episodeMetadata,
              candidate.episodeOrdinal != nil
        else { return false }
        return candidate.seriesID == metadata.seriesID && candidate.playlistID == playlistID
    }.sorted { lhs, rhs in
        guard let left = lhs.episodeMetadata,
              let right = rhs.episodeMetadata,
              let leftOrdinal = left.episodeOrdinal,
              let rightOrdinal = right.episodeOrdinal
        else { return lhs.id < rhs.id }
        if leftOrdinal != rightOrdinal {
            return leftOrdinal < rightOrdinal
        }
        if left.seasonNumber != right.seasonNumber {
            return left.seasonNumber < right.seasonNumber
        }
        return lhs.id < rhs.id
    }

    guard episodes.contains(where: { $0.id == current.id && $0.localFilePath == current.localFilePath }) else { return [] }
    return episodes
}

@Reducer
public struct SearchFeature: Sendable {
    public enum SearchFilter: String, CaseIterable, Equatable, Hashable, Sendable {
        case all = "Tümü"
        case categories = "Kategoriler"
        case live = "Canlı TV"
        case vod = "Filmler"
        case series = "Diziler"
        case uhd4k = "4K / UHD"
        case epgMatches = "EPG Programları"
        case people = "Kişiler"
        case programs = "Programlar"
        case downloads = "İndirilenler"

        public var title: String {
            switch self {
            case .all: AppStrings.Search.all
            case .categories: AppStrings.Search.categories
            case .live: AppStrings.Search.liveTV
            case .vod: AppStrings.Search.movies
            case .series: AppStrings.Search.series
            case .uhd4k: AppStrings.Search.filter4K
            case .epgMatches: AppStrings.Search.filterEPG
            case .people: AppStrings.Search.people
            case .programs: AppStrings.Search.programs
            case .downloads: AppStrings.Downloads.title
            }
        }

        public var icon: String {
            switch self {
            case .all: "square.grid.2x2.fill"
            case .categories: "folder.fill"
            case .live: "tv.fill"
            case .vod: "film.fill"
            case .series: "play.tv.fill"
            case .uhd4k: "sparkles.tv.fill"
            case .epgMatches: "clock.badge.checkmark.fill"
            case .people: "person.crop.rectangle.stack.fill"
            case .programs: "list.bullet.rectangle.fill"
            case .downloads: "arrow.down.circle.fill"
            }
        }

        public var badgeColorHex: String {
            switch self {
            case .all: "#0A84FF" // System Blue
            case .categories: "#00D2FF" // Cyan
            case .live: "#0A84FF" // Electric Blue
            case .vod: "#BF5AF2" // Cinema Violet
            case .series: "#FF9F0A" // Sunset Amber
            case .uhd4k: "#FFD60A" // Radiant Gold
            case .epgMatches: "#30D158" // Stadium Green
            case .people: "#FF375F"
            case .programs: "#64D2FF"
            case .downloads: "#30D158"
            }
        }

        public var badgeColor: Color {
            switch self {
            case .all, .live: AppColors.primary
            case .categories: AppColors.cyan
            case .vod: AppColors.premium
            case .series: AppColors.amber
            case .uhd4k: AppColors.warningGold
            case .epgMatches: AppColors.success
            case .people: AppColors.live
            case .programs: AppColors.cyan
            case .downloads: AppColors.success
            }
        }
    }

    public enum SearchContentScope: String, CaseIterable, Equatable, Hashable, Sendable {
        case all
        case myCategories
        case pinned

        public var title: String {
            switch self {
            case .all: AppStrings.Search.all
            case .myCategories: AppStrings.Search.myCategories
            case .pinned: AppStrings.Search.myCollection
            }
        }

        public var icon: String {
            switch self {
            case .all: "magnifyingglass"
            case .myCategories: "square.grid.2x2.fill"
            case .pinned: "bookmark.fill"
            }
        }
    }

    public enum SearchRecoverySuggestion: Equatable, Sendable {
        case allContentTypes
        case allPlaylists

        public var title: String {
            switch self {
            case .allContentTypes: AppStrings.Search.searchAllTypes
            case .allPlaylists: AppStrings.Search.searchAllPlaylists
            }
        }
    }

    public struct QuickSearchTag: Identifiable, Sendable, Equatable {
        public let id: String
        public let title: String
        public let icon: String
        public let hexColor: String

        public init(id: String, title: String, icon: String, hexColor: String) {
            self.id = id
            self.title = title
            self.icon = icon
            self.hexColor = hexColor
        }

        public var color: Color {
            switch id {
            case "spor": AppColors.amber
            case "sinema": AppColors.live
            case "haber": AppColors.primary
            case "belgesel": AppColors.success
            case "cocuk": AppColors.warningGold
            case "muzik": AppColors.premium
            case "4k": AppColors.cyan
            case "aksiyon": AppColors.live
            case "komedi": AppColors.cyan
            case "dizi": AppColors.purpleAccent
            default: AppColors.primary
            }
        }

        public static let defaults: [QuickSearchTag] = [
            QuickSearchTag(id: "spor", title: "Spor", icon: "sportscourt.fill", hexColor: "#FF9500"),
            QuickSearchTag(id: "sinema", title: "Sinema", icon: "film.fill", hexColor: "#FF3B30"),
            QuickSearchTag(id: "haber", title: "Haber", icon: "newspaper.fill", hexColor: "#0A84FF"),
            QuickSearchTag(id: "belgesel", title: "Belgesel", icon: "globe.europe.africa.fill", hexColor: "#30D158"),
            QuickSearchTag(id: "cocuk", title: "Çocuk", icon: "sparkles.tv.fill", hexColor: "#FFD60A"),
            QuickSearchTag(id: "muzik", title: "Müzik", icon: "music.note", hexColor: "#BF5AF2"),
            QuickSearchTag(id: "4k", title: "4K / UHD", icon: "4k.tv.fill", hexColor: "#64D2FF"),
            QuickSearchTag(id: "aksiyon", title: "Aksiyon", icon: "flame.fill", hexColor: "#FF453A"),
            QuickSearchTag(id: "komedi", title: "Komedi", icon: "face.smiling.fill", hexColor: "#63E6BE"),
            QuickSearchTag(id: "dizi", title: "Dizi", icon: "play.tv.fill", hexColor: "#5E5CE6"),
        ]
    }

    public struct PersonCreditResult: Identifiable, Equatable, Sendable {
        public let personID: Int
        public let personName: String
        public let portraitURL: URL?
        public let result: GlobalSearchResultItem
        public var id: String {
            "person-credit-v1|" + lengthPrefixedSearchIdentity([String(personID), result.id])
        }
    }

    public struct ProgramResult: Identifiable, Equatable, Sendable {
        public let program: EPGProgram
        public let result: GlobalSearchResultItem
        public var id: String {
            "program-result-v1|" + lengthPrefixedSearchIdentity([program.id, result.id])
        }
    }

    @ObservableState
    public struct State: Equatable {
        public struct ResultScope: Hashable, Sendable {
            public let filter: SearchFilter
            public let selectedPlaylistID: UUID?
            public let searchContentScope: SearchContentScope

            public init(filter: SearchFilter, selectedPlaylistID: UUID?, searchContentScope: SearchContentScope) {
                self.filter = filter
                self.selectedPlaylistID = selectedPlaylistID
                self.searchContentScope = searchContentScope
            }
        }

        // Data sources (everything fetched once)
        public var allChannels: [MediaModels.Item] = []
        public var allVODs: [MediaModels.Item] = []
        public var allSeries: [MediaModels.Item] = []
        public var allCategories: [CategorySearchResultItem] = []
        public var hiddenMediaEntries: [HiddenMediaEntry] = []
        public var hiddenMediaScope: ProfileContextSnapshot?
        public var hiddenMediaLoadRequestID: UUID?
        public var isHiddenMediaLoaded = false

        // Multi-Playlist Cross-Indexing
        public var savedPlaylists: [SavedPlaylist] = []
        public var selectedPlaylistID: UUID?
        public var indexedChannels: [GlobalSearchResultItem] = []
        public var indexedVODs: [GlobalSearchResultItem] = []
        public var indexedSeries: [GlobalSearchResultItem] = []
        public var indexedCategories: [CategorySearchResultItem] = []
        public var curatedPlaylistEntries: [CuratedPlaylistEntry] = []
        public var curatedPlaylistResults: [GlobalSearchResultItem] = []
        public var curatedPlaylistRevision: UInt64 = 0
        public var isCuratedPlaylistLoaded = false
        public var curatedEntryIDsHiddenByPrivacy: Set<String> = []
        public var curatedPlaylistScope: ProfileContextSnapshot?
        public var mediaPresentationScope: ProfileContextSnapshot?

        public var hiddenSearchCategoryPreferenceIDs: Set<String> = []
        public var hiddenSearchCategoryProfileScope: ProfileContextSnapshot?
        public var hiddenSearchCategoryPlaylistIDs: Set<UUID> = []
        public var hiddenSearchCategoryLoadRequestID: UUID?
        public var isHiddenSearchCategoryPreferencesLoaded = false

        // Search state
        public var searchQuery: String = ""
        public var focusedResultID: String?
        public var debouncedQuery: String = ""
        public var pendingSearchDebounceRequestID: UUID?
        public var filter: SearchFilter = .all
        public var selectedCategoryTypeFilter: MediaModels.ItemType?
        public var searchContentScope: SearchContentScope = .all
        public var searchContentScopeProfileKey: String?
        public var searchContentScopesByProfile: [String: SearchContentScope] = [:]
        public var focusedResultIDsByScope: [ResultScope: String] = [:]
        public var focusedResultScopeRecency: [ResultScope] = []
        public var pendingFocusRestorationID: String?
        public var recentSearches: [SearchHistoryItem] = []
        public var pinnedSearchQueries: [String] = []
        public var isPinnedSearchLimitAlertPresented = false
        public var quickTags: [QuickSearchTag] = QuickSearchTag.defaults

        public var isCurrentSearchPinned: Bool {
            let query = searchQuery.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !query.isEmpty else { return false }
            return pinnedSearchQueries.contains { $0.localizedCaseInsensitiveCompare(query) == .orderedSame }
        }

        // UI state
        public var isLoading = false
        public var primaryCatalogLoadRequestID: UUID?
        public var multiPlaylistLoadRequestID: UUID?
        public var isSearching = false
        public var isPeopleSearchLoading = false
        public var isProgramsSearchLoading = false
        public var hasLoaded = false
        public var errorMessage: String?
        public var reminderFailureMessage: String?
        public var lastLoadedConfig: PlaylistConfig?
        public var lastAdultHidden: Bool?

        // Stored Results (for backward compatibility)
        public var liveResults: [MediaModels.Item] = []
        public var vodResults: [MediaModels.Item] = []
        public var seriesResults: [MediaModels.Item] = []
        public var categoryResults: [CategorySearchResultItem] = []
        public var favoriteIDs: Set<FavoriteIdentity> = []
        public var scheduledReminderIDs: Set<String> = []
        public var pendingReminderRequestIDs: [String: UUID] = [:]
        public var reminderLoadRequestID: UUID?

        // Enriched Multi-Playlist Results
        public var enrichedLiveResults: [GlobalSearchResultItem] = []
        public var enrichedVODResults: [GlobalSearchResultItem] = []
        public var enrichedSeriesResults: [GlobalSearchResultItem] = []
        public var peopleResults: [PersonCreditResult] = []
        public var programResults: [ProgramResult] = []
        public var downloadedMediaResults: [OfflineMediaSnapshot] = []
        public var activeOfflineSearchRequestID: UUID?
        public var activeOfflinePlaybackRequestID: UUID?
        public var activePeopleSearchRequestID: UUID?
        public var activeProgramsSearchRequestID: UUID?
        public var activeSearchRequestID: UUID?
        public var activeEPGEnrichmentRequestID: UUID?
        public var filterCounts: [SearchFilter: Int] = [:]
        public var baseAllResultsCount = 0

        public var fallbackSourceBadge: PlaylistSourceBadge {
            searchSourceBadge(for: lastLoadedConfig)
        }

        public func isHiddenMedia(_ item: MediaModels.Item, fallbackPlaylistID: UUID? = nil) -> Bool {
            let identity = HiddenMediaIdentity(item: item, fallbackPlaylistID: fallbackPlaylistID)
            return hiddenMediaEntries.contains { $0.identity == identity }
        }

        public func isHiddenMedia(_ result: GlobalSearchResultItem) -> Bool {
            let playlistID = result.item.playlistID
                ?? playlistIDsByBadgeID[result.playlistBadge.id]
                ?? lastLoadedConfig?.playlistID
            return isHiddenMedia(result.item, fallbackPlaylistID: playlistID)
        }

        public mutating func filterHiddenMediaFromCatalogs() {
            let hiddenIdentities = Set(hiddenMediaEntries.map(\.identity))
            let playlistIDsByBadgeID = playlistIDsByBadgeID
            let fallbackPlaylistID = lastLoadedConfig?.playlistID
            allVODs.removeAll {
                hiddenIdentities.contains(HiddenMediaIdentity(item: $0, fallbackPlaylistID: fallbackPlaylistID))
            }
            allSeries.removeAll {
                hiddenIdentities.contains(HiddenMediaIdentity(item: $0, fallbackPlaylistID: fallbackPlaylistID))
            }
            indexedVODs.removeAll { result in
                let playlistID = result.item.playlistID
                    ?? playlistIDsByBadgeID[result.playlistBadge.id]
                    ?? fallbackPlaylistID
                return hiddenIdentities.contains(HiddenMediaIdentity(item: result.item, fallbackPlaylistID: playlistID))
            }
            indexedSeries.removeAll { result in
                let playlistID = result.item.playlistID
                    ?? playlistIDsByBadgeID[result.playlistBadge.id]
                    ?? fallbackPlaylistID
                return hiddenIdentities.contains(HiddenMediaIdentity(item: result.item, fallbackPlaylistID: playlistID))
            }
            refreshCuratedPlaylistResults()
        }

        public var visibleResultIDs: [String] {
            let fallbackBadge = fallbackSourceBadge
            let categoryIDs = categoryResults.map(\.id)
            let liveIDs = enrichedLiveResults.isEmpty
                ? liveResults.map { GlobalSearchResultItem(item: $0, playlistBadge: fallbackBadge).id }
                : enrichedLiveResults.map(\.id)
            let vodIDs = enrichedVODResults.isEmpty
                ? vodResults.map { GlobalSearchResultItem(item: $0, playlistBadge: fallbackBadge).id }
                : enrichedVODResults.map(\.id)
            let seriesIDs = enrichedSeriesResults.isEmpty
                ? seriesResults.map { GlobalSearchResultItem(item: $0, playlistBadge: fallbackBadge).id }
                : enrichedSeriesResults.map(\.id)
            return switch filter {
            case .all: categoryIDs + liveIDs + vodIDs + seriesIDs + peopleResults.map(\.id) + programResults.map(\.id)
            case .categories: categoryIDs
            case .uhd4k: liveIDs + vodIDs + seriesIDs
            case .live, .epgMatches: liveIDs
            case .vod: vodIDs
            case .series: seriesIDs
            case .people: peopleResults.map(\.id)
            case .programs: programResults.map(\.id)
            case .downloads: downloadedMediaResults.map(\.id)
            }
        }

        public var isSearchWorkComplete: Bool {
            !isSearching && !isCurrentScopeSearching
        }

        public var currentResultScope: ResultScope {
            ResultScope(
                filter: filter,
                selectedPlaylistID: selectedPlaylistID,
                searchContentScope: searchContentScope
            )
        }

        public func searchScopedResults(_ results: [GlobalSearchResultItem]) -> [GlobalSearchResultItem] {
            let badgeIDs = playlistIDsByBadgeID
            let fallbackPlaylistID = lastLoadedConfig?.playlistID
            let pinnedEntryIDs = Set(curatedPlaylistEntries.map(\.id))
            return results.filter {
                isIncludedInSearchContentScope(
                    $0,
                    scope: searchContentScope,
                    hiddenCategoryPreferenceIDs: hiddenSearchCategoryPreferenceIDs,
                    curatedPlaylistEntryIDs: pinnedEntryIDs,
                    playlistIDsByBadgeID: badgeIDs,
                    fallbackPlaylistID: fallbackPlaylistID
                )
            }
        }

        public func searchScopedCategories(_ categories: [CategorySearchResultItem]) -> [CategorySearchResultItem] {
            let badgeIDs = playlistIDsByBadgeID
            let fallbackPlaylistID = lastLoadedConfig?.playlistID
            return categories.filter { cat in
                switch searchContentScope {
                case .all, .pinned:
                    return true
                case .myCategories:
                    guard !cat.category.id.isEmpty else { return true }
                    let playlistID = cat.playlistID
                        ?? badgeIDs[cat.playlistBadge.id]
                        ?? fallbackPlaylistID
                    return !hiddenSearchCategoryPreferenceIDs.contains(
                        searchCategoryPreferenceIdentity(
                            type: cat.type.rawValue,
                            playlistID: playlistID,
                            categoryID: cat.category.id
                        )
                    )
                }
            }
        }

        public var filteredCategoryResults: [CategorySearchResultItem] {
            guard let filter = selectedCategoryTypeFilter else { return categoryResults }
            return categoryResults.filter { $0.type == filter }
        }

        public var scopedDiscoveryCategories: [CategorySearchResultItem] {
            let raw = indexedCategories.isEmpty ? allCategories : indexedCategories
            var scoped = searchScopedCategories(raw)
            if let selectedPlaylistID {
                let sourceID = PlaylistSourceBadge.sourceID(for: selectedPlaylistID)
                scoped = scoped.filter { $0.playlistBadge.id == sourceID }
            }
            if let filter = selectedCategoryTypeFilter {
                scoped = scoped.filter { $0.type == filter }
            }
            return scoped
        }

        public mutating func invalidateFocusMemory() {
            focusedResultIDsByScope.removeAll(keepingCapacity: true)
            focusedResultScopeRecency.removeAll(keepingCapacity: true)
            pendingFocusRestorationID = nil
            focusedResultID = nil
        }

        public mutating func prepareFocusRestorationForCurrentScope() {
            pendingFocusRestorationID = focusedResultIDsByScope[currentResultScope]
            focusedResultID = nil
        }

        public mutating func rememberFocusedResult(_ id: String) {
            guard visibleResultIDs.contains(id) else { return }
            pendingFocusRestorationID = nil
            let scope = currentResultScope
            focusedResultIDsByScope[scope] = id
            focusedResultScopeRecency.removeAll { $0 == scope }
            focusedResultScopeRecency.append(scope)
            while focusedResultScopeRecency.count > 64 {
                let oldest = focusedResultScopeRecency.removeFirst()
                focusedResultIDsByScope.removeValue(forKey: oldest)
            }
        }

        public mutating func restoreFocusedResultIfPossible() {
            guard let pendingFocusRestorationID else { return }
            if visibleResultIDs.contains(pendingFocusRestorationID) {
                focusedResultID = pendingFocusRestorationID
                self.pendingFocusRestorationID = nil
            } else if isSearchWorkComplete {
                let scope = currentResultScope
                focusedResultIDsByScope.removeValue(forKey: scope)
                focusedResultScopeRecency.removeAll { $0 == scope }
                self.pendingFocusRestorationID = nil
            }
        }

        public var playlistIDsByBadgeID: [String: UUID] {
            var identifiers: [String: UUID] = [:]
            for (index, playlist) in savedPlaylists.enumerated() {
                guard let config = playlist.toPlaylistConfig() else { continue }
                identifiers[UnifiedPlaylistManager.shared.badge(for: config, index: index).id] = playlist.id
            }
            if let config = lastLoadedConfig, let playlistID = config.playlistID {
                identifiers[UnifiedPlaylistManager.shared.badge(for: config).id] = playlistID
                identifiers[EPGReminderIdentifier.playlistIdentity(for: config)] = playlistID
                identifiers["default"] = playlistID
            }
            return identifiers
        }

        public mutating func refreshCuratedPlaylistResults() {
            guard !curatedPlaylistEntries.isEmpty else {
                curatedPlaylistResults = []
                return
            }
            let hiddenIdentities = Set(hiddenMediaEntries.map(\.identity))
            let visibleEntries = curatedPlaylistEntries.filter { entry in
                let identity = HiddenMediaIdentity(
                    type: entry.contentType,
                    playlistID: entry.playlistID,
                    mediaID: entry.itemID
                )
                return !curatedEntryIDsHiddenByPrivacy.contains(entry.id)
                    && !hiddenIdentities.contains(identity)
            }
            let entryIDs = Set(visibleEntries.map(\.id))
            let indexedResults = indexedChannels + indexedVODs + indexedSeries
            var resultsByEntryID: [String: GlobalSearchResultItem] = [:]
            for result in indexedResults {
                guard let playlistID = playlistIDsByBadgeID[result.playlistBadge.id] else { continue }
                let entryID = CuratedPlaylistEntry.identity(
                    playlistID: playlistID,
                    contentType: result.item.type.rawValue,
                    itemID: result.item.id
                )
                if entryIDs.contains(entryID), !curatedEntryIDsHiddenByPrivacy.contains(entryID) {
                    resultsByEntryID[entryID] = result
                }
            }
            curatedPlaylistResults = visibleEntries.compactMap { resultsByEntryID[$0.id] }
        }

        public var unavailableCuratedPlaylistEntries: [CuratedPlaylistEntry] {
            guard hasLoaded, primaryCatalogLoadRequestID == nil, multiPlaylistLoadRequestID == nil else { return [] }
            let resolvedIDs = Set(curatedPlaylistResults.map(\.id))
            return curatedPlaylistEntries.filter {
                let identity = HiddenMediaIdentity(type: $0.contentType, playlistID: $0.playlistID, mediaID: $0.itemID)
                return !resolvedIDs.contains($0.id)
                    && !curatedEntryIDsHiddenByPrivacy.contains($0.id)
                    && !hiddenMediaEntries.contains { $0.identity == identity }
            }
        }

        public var hasVisibleCuratedPlaylistItems: Bool {
            !curatedPlaylistResults.isEmpty || !unavailableCuratedPlaylistEntries.isEmpty
        }

        public func curatedPlaylistID(for result: GlobalSearchResultItem) -> UUID? {
            guard let playlistID = playlistIDsByBadgeID[result.playlistBadge.id],
                  let playlist = savedPlaylists.first(where: { $0.id == playlistID }),
                  playlist.type == .m3u || playlist.type == .xtream
            else { return nil }
            return playlistID
        }

        public func isInCuratedPlaylist(_ result: GlobalSearchResultItem) -> Bool {
            guard let playlistID = curatedPlaylistID(for: result) else { return false }
            let entryID = CuratedPlaylistEntry.identity(
                playlistID: playlistID,
                contentType: result.item.type.rawValue,
                itemID: result.item.id
            )
            return curatedPlaylistEntries.contains { $0.id == entryID }
        }

        public func canToggleCuratedPlaylist(_ result: GlobalSearchResultItem) -> Bool {
            guard result.item.id.utf8.count <= CuratedPlaylistEntry.maximumItemIDByteCount,
                  curatedPlaylistID(for: result) != nil
            else { return false }
            return isInCuratedPlaylist(result) || curatedPlaylistEntries.count < CuratedPlaylistEntry.maximumEntryCount
        }

        public var playlistIdentitiesByBadgeID: [String: String] {
            var identities: [String: String] = [:]
            for (index, playlist) in savedPlaylists.enumerated() {
                guard let config = playlist.toPlaylistConfig() else { continue }
                let badge = UnifiedPlaylistManager.shared.badge(for: config, index: index)
                identities[badge.id] = EPGReminderIdentifier.playlistIdentity(for: config)
            }
            if let config = lastLoadedConfig {
                identities[UnifiedPlaylistManager.shared.badge(for: config).id] = EPGReminderIdentifier.playlistIdentity(for: config)
            }
            return identities
        }

        public mutating func updateAllResultsCount() {
            filterCounts[.all] = baseAllResultsCount + categoryResults.count + peopleResults.count + programResults.count
            filterCounts[.categories] = categoryResults.count
        }

        public mutating func clearSearchResults() {
            focusedResultID = nil
            liveResults = []
            vodResults = []
            seriesResults = []
            categoryResults = []
            enrichedLiveResults = []
            enrichedVODResults = []
            enrichedSeriesResults = []
            peopleResults = []
            programResults = []
            downloadedMediaResults = []
            activeOfflineSearchRequestID = nil
            activeOfflinePlaybackRequestID = nil
            filterCounts = [:]
            baseAllResultsCount = 0
        }

        public var totalResultsCount: Int {
            switch filter {
            case .categories:
                return categoryResults.count
            case .people:
                return peopleResults.count
            case .programs:
                return programResults.count
            case .downloads:
                return downloadedMediaResults.count
            case .all:
                let liveCount = enrichedLiveResults.isEmpty ? liveResults.count : enrichedLiveResults.count
                let vodCount = enrichedVODResults.isEmpty ? vodResults.count : enrichedVODResults.count
                let seriesCount = enrichedSeriesResults.isEmpty ? seriesResults.count : enrichedSeriesResults.count
                return categoryResults.count + liveCount + vodCount + seriesCount + peopleResults.count + programResults.count
            default:
                if !enrichedLiveResults.isEmpty || !enrichedVODResults.isEmpty || !enrichedSeriesResults.isEmpty {
                    return enrichedLiveResults.count + enrichedVODResults.count + enrichedSeriesResults.count
                }
                return liveResults.count + vodResults.count + seriesResults.count
            }
        }

        public var isCurrentScopeSearching: Bool {
            switch filter {
            case .all: isPeopleSearchLoading || isProgramsSearchLoading
            case .people: isPeopleSearchLoading
            case .programs: isProgramsSearchLoading
            default: false
            }
        }

        public var searchRecoverySuggestion: SearchRecoverySuggestion? {
            guard !searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !isLoading,
                  !isSearching,
                  !isCurrentScopeSearching,
                  totalResultsCount == 0,
                  filter != .downloads
            else { return nil }

            if filter != .all {
                return .allContentTypes
            }
            if selectedPlaylistID != nil {
                return .allPlaylists
            }
            return nil
        }

        public mutating func updateResults() {
            let query = debouncedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !query.isEmpty else {
                clearSearchResults()
                return
            }

            let defaultBadge = searchSourceBadge(for: lastLoadedConfig)

            let chSource = !indexedChannels.isEmpty ? indexedChannels : allChannels.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }
            let hiddenIdentities = Set(hiddenMediaEntries.map(\.identity))
            let voSource = (!indexedVODs.isEmpty ? indexedVODs : allVODs.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }).filter { result in
                let playlistID = result.item.playlistID
                    ?? playlistIDsByBadgeID[result.playlistBadge.id]
                    ?? lastLoadedConfig?.playlistID
                return !hiddenIdentities.contains(HiddenMediaIdentity(item: result.item, fallbackPlaylistID: playlistID))
            }
            let seSource = (!indexedSeries.isEmpty ? indexedSeries : allSeries.map {
                GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge)
            }).filter { result in
                let playlistID = result.item.playlistID
                    ?? playlistIDsByBadgeID[result.playlistBadge.id]
                    ?? lastLoadedConfig?.playlistID
                return !hiddenIdentities.contains(HiddenMediaIdentity(item: result.item, fallbackPlaylistID: playlistID))
            }

            let catSource = !indexedCategories.isEmpty ? indexedCategories : allCategories
            let output = GlobalSearchEngine.search(
                query: query,
                filter: filter,
                selectedPlaylistID: selectedPlaylistID,
                channels: chSource,
                vods: voSource,
                series: seSource,
                categories: catSource,
                limitPerCategory: 100
            )

            categoryResults = output.categories
            enrichedLiveResults = output.live
            enrichedVODResults = output.vods
            enrichedSeriesResults = output.series
            filterCounts = output.counts
            baseAllResultsCount = output.counts[.all, default: 0]
            updateAllResultsCount()

            liveResults = output.live.map(\.item)
            vodResults = output.vods.map(\.item)
            seriesResults = output.series.map(\.item)
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case loadSavedPlaylistsResponse([SavedPlaylist])
        case loadRecentSearchesResponse([SearchHistoryItem])
        case curatedPlaylistLoaded(CuratedPlaylistSnapshot, ProfileContextSnapshot)
        case curatedPlaylistUpdated(CuratedPlaylistSnapshot, ProfileContextSnapshot)
        case hiddenMediaLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, Result<[HiddenMediaEntry], Error>)
        case primaryCatalogPrepared(
            requestID: UUID,
            config: PlaylistConfig,
            hiddenMediaRequestID: UUID?,
            sourceData: SearchPrimaryCatalogData,
            prepared: PreparedSearchPrimaryCatalog
        )
        case multiPlaylistCatalogPrepared(
            requestID: UUID,
            config: PlaylistConfig,
            hiddenMediaRequestID: UUID?,
            sourceData: SearchMultiPlaylistCatalogData,
            prepared: PreparedSearchMultiPlaylistCatalog
        )
        case reloadSearchCategoryPreferences
        case searchCategoryPreferencesLoaded(requestID: UUID, profileScope: ProfileContextSnapshot, hiddenCategoryIDs: Set<String>, errorMessage: String?)
        case loadAllDataResponse(
            requestID: UUID,
            config: PlaylistConfig,
            result: Result<SearchPrimaryCatalogData, Error>
        )
        case loadPlaylistsDataResponse(
            requestID: UUID,
            config: PlaylistConfig,
            list: SearchMultiPlaylistCatalogData
        )
        case queryChanged(String)
        case debouncedSearchFired(query: String, requestID: UUID)
        case performSearch(String, debounceRequestID: UUID?)
        case searchCompleted(query: String, filter: SearchFilter, live: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item])
        case searchEnrichedCompleted(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, output: GlobalSearchEngine.SearchResultOutput)
        case liveEPGEnriched(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, results: [GlobalSearchResultItem])
        case peopleSearchCompleted(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, results: [PersonCreditResult])
        case programsSearchCompleted(requestID: UUID, query: String, filter: SearchFilter, playlistID: UUID?, results: [ProgramResult])
        case downloadedSearchCompleted(requestID: UUID, query: String, results: [OfflineMediaSnapshot])
        case filterChanged(SearchFilter)
        case searchContentScopeChanged(SearchContentScope)
        case selectPlaylistFilter(UUID?)
        case resetCache
        case channelSelected(MediaModels.Item)
        case vodSelected(MediaModels.Item)
        case seriesSelected(MediaModels.Item)
        case categorySelected(CategorySearchResultItem)
        case categoryTypeFilterSelected(MediaModels.ItemType?)
        case toggleCuratedPlaylistItem(GlobalSearchResultItem)
        case removeCuratedPlaylistItem(String)
        case focusedResultChanged(String)
        case personCreditSelected(PersonCreditResult)
        case programSelected(ProgramResult)
        case offlineMediaSelected(OfflineMediaSnapshot)
        case offlinePlaybackValidated(requestID: UUID, query: String, current: OfflineMediaSnapshot?, downloadedItems: [OfflineMediaSnapshot])
        case clearHistoryTapped
        case recentSearchTapped(String)
        case togglePinnedSearch(String)
        case pinnedSearchLimitAlertDismissed
        case tagSelected(QuickSearchTag)
        case loadFavoritesResponse([FavoriteItem], ProfileContextSnapshot)
        case loadReminders
        case remindersLoaded(requestID: UUID, Set<String>)
        case toggleReminder(EPGProgram, MediaModels.Item, reminderID: String, playlistIdentity: String)
        case reminderToggleResponse(programID: String, legacyProgramID: String, requestID: UUID, isScheduled: Bool)
        case reminderSchedulingFailed
        case clearReminderFailure
        case toggleFavorite(item: MediaModels.Item, type: String, playlistID: UUID?)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectChannel(MediaModels.Item, playlist: [MediaModels.Item]?)
            case didSelectVOD(MediaModels.Item)
            case didSelectSeries(MediaModels.Item)
            case didSelectCategory(category: MediaModels.Category, type: MediaModels.ItemType, playlistID: UUID?)
            case playOfflineMedia(OfflineMediaSnapshot, episodeQueue: [OfflineMediaSnapshot])
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Injected(\.playlistRepository) var playlistRepository
    @Dependency(\.continuousClock) var clock
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.profileContextClient) var profileContextClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.parentalControlClient) var parentalControlClient
    @Dependency(\.reminderClient) var reminderClient
    @Dependency(\.tmdbClient) var tmdbClient
    @Dependency(\.customEPGMappingClient) var customEPGMappingClient
    @Dependency(\.curatedPlaylistClient) var curatedPlaylistClient
    @Dependency(\.mediaPresentationOverrideClient) var mediaPresentationOverrideClient
    @Dependency(\.downloadClient) var downloadClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient
        let playlistRepository = playlistRepository
        let settingsClient = settingsClient
        let parentalControlClient = parentalControlClient
        let reminderClient = reminderClient
        let tmdbClient = tmdbClient
        let customEPGMappingClient = customEPGMappingClient
        let curatedPlaylistClient = curatedPlaylistClient
        let mediaPresentationOverrideClient = mediaPresentationOverrideClient
        let downloadClient = downloadClient

        let profileContextClient = profileContextClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let playlists = playlistRepository.getPlaylists()
                let oldCatalog = searchCatalogSources(state.savedPlaylists)
                let newCatalog = searchCatalogSources(playlists)
                let sourceCatalogChanged = oldCatalog != newCatalog
                let validPlaylistIDs = Set(newCatalog.compactMap { $0.config == nil ? nil : $0.id })
                if let selectedPlaylistID = state.selectedPlaylistID,
                   !validPlaylistIDs.contains(selectedPlaylistID)
                {
                    state.selectedPlaylistID = nil
                }
                if sourceCatalogChanged {
                    state.invalidateFocusMemory()
                    state.activeEPGEnrichmentRequestID = nil
                }
                state.savedPlaylists = playlists

                let profileScope = profileContextClient.snapshot()
                let profileKey = profileScope.profileID?.uuidString ?? "default"
                if let previousProfileKey = state.searchContentScopeProfileKey,
                   previousProfileKey != profileKey
                {
                    state.searchContentScopesByProfile[previousProfileKey] = state.searchContentScope
                }
                if state.searchContentScopeProfileKey != profileKey {
                    state.searchContentScopeProfileKey = profileKey
                    state.searchContentScope = state.searchContentScopesByProfile[profileKey] ?? .all
                }
                let categoryPreferencePlaylistIDs = Set(playlists.map(\.id) + [config.playlistID].compactMap(\.self))
                if state.hiddenSearchCategoryProfileScope != profileScope
                    || state.hiddenSearchCategoryPlaylistIDs != categoryPreferencePlaylistIDs
                {
                    state.hiddenSearchCategoryPreferenceIDs = []
                    state.hiddenSearchCategoryProfileScope = profileScope
                    state.hiddenSearchCategoryPlaylistIDs = categoryPreferencePlaylistIDs
                    state.hiddenSearchCategoryLoadRequestID = nil
                    state.isHiddenSearchCategoryPreferencesLoaded = false
                }
                let loadSearchCategoryPreferences: Effect<Action> = state.searchContentScope == .myCategories
                    ? .send(.reloadSearchCategoryPreferences)
                    : .none

                let savedPinnedSearches = settingsClient.pinnedSearchQueries()
                let normalizedPinnedSearches = Self.normalizedPinnedSearchQueries(savedPinnedSearches)
                state.pinnedSearchQueries = normalizedPinnedSearches
                if normalizedPinnedSearches != savedPinnedSearches {
                    settingsClient.setPinnedSearchQueries(normalizedPinnedSearches)
                }

                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                let historyCutoff = Date().addingTimeInterval(-historyRetention.duration)
                if !historySavingEnabled {
                    state.recentSearches = []
                } else {
                    state.recentSearches.removeAll { $0.timestamp < historyCutoff }
                }
                let loadHistory: Effect<Action> = .run { send in
                    let history: [SearchHistoryItem]
                    if historySavingEnabled {
                        history = await (try? databaseClient.fetchSearchHistory(historyCutoff)) ?? []
                    } else {
                        _ = try? await databaseClient.clearSearchHistory()
                        history = []
                    }
                    await send(.loadRecentSearchesResponse(history))
                }

                let presentationScopeChanged = state.mediaPresentationScope != profileScope
                state.mediaPresentationScope = profileScope
                if state.hiddenMediaScope != profileScope {
                    state.hiddenMediaEntries = []
                    state.hiddenMediaScope = profileScope
                }
                let hiddenMediaRequestID = UUID()
                state.hiddenMediaLoadRequestID = hiddenMediaRequestID
                state.isHiddenMediaLoaded = false
                let loadHiddenMedia: Effect<Action> = .run { send in
                    do {
                        let items = try await databaseClient.fetchHiddenMediaItems(nil, profileScope)
                        await send(.hiddenMediaLoaded(requestID: hiddenMediaRequestID, profileScope: profileScope, .success(items)))
                    } catch {
                        await send(.hiddenMediaLoaded(requestID: hiddenMediaRequestID, profileScope: profileScope, .failure(error)))
                    }
                }
                if state.curatedPlaylistScope != profileScope {
                    state.curatedPlaylistScope = profileScope
                    state.curatedPlaylistEntries = []
                    state.curatedPlaylistResults = []
                    state.curatedPlaylistRevision = 0
                    state.isCuratedPlaylistLoaded = false
                    state.curatedEntryIDsHiddenByPrivacy = []
                }
                let loadFavs: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavorites(profileScope)) ?? []
                    await send(.loadFavoritesResponse(favs, profileScope))
                }
                let loadCuratedPlaylist: Effect<Action> = .run { send in
                    let snapshot = await curatedPlaylistClient.load(profileScope.profileID)
                    await send(.curatedPlaylistLoaded(snapshot, profileScope))
                }

                let currentAdultHidden = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let privacyHiddenCuratedEntryIDs = Self.curatedEntriesHiddenByPrivacy(
                    state.curatedPlaylistEntries,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs(),
                    hideAdultContent: currentAdultHidden,
                    isAdultContent: settingsClient.isAdultContent
                )
                if privacyHiddenCuratedEntryIDs != state.curatedEntryIDsHiddenByPrivacy {
                    state.curatedEntryIDsHiddenByPrivacy = privacyHiddenCuratedEntryIDs
                    state.refreshCuratedPlaylistResults()
                }
                let configurationChanged = state.lastLoadedConfig != config
                let adultVisibilityChanged = state.lastAdultHidden != currentAdultHidden
                let privacyReset = configurationChanged || adultVisibilityChanged || presentationScopeChanged
                if privacyReset || sourceCatalogChanged {
                    state.invalidateFocusMemory()
                    state.activeEPGEnrichmentRequestID = nil
                    state.hasLoaded = false
                    state.isLoading = false
                    state.primaryCatalogLoadRequestID = nil
                    state.multiPlaylistLoadRequestID = nil
                    state.allChannels = []
                    state.allVODs = []
                    state.allSeries = []
                    state.allCategories = []
                    state.indexedChannels = []
                    state.indexedVODs = []
                    state.indexedSeries = []
                    state.indexedCategories = []
                    state.curatedPlaylistResults = []
                    state.liveResults = []
                    state.vodResults = []
                    state.seriesResults = []
                    state.categoryResults = []
                    state.enrichedLiveResults = []
                    state.enrichedVODResults = []
                    state.enrichedSeriesResults = []
                    state.peopleResults = []
                    state.programResults = []
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeSearchRequestID = nil
                    state.filterCounts = [:]
                    state.baseAllResultsCount = 0
                    if privacyReset {
                        state.searchQuery = ""
                        state.debouncedQuery = ""
                        state.pendingSearchDebounceRequestID = nil
                        state.isSearching = false
                        state.isPeopleSearchLoading = false
                        state.isProgramsSearchLoading = false
                    } else {
                        let query = state.searchQuery
                        state.debouncedQuery = query
                        let hasQuery = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        state.isSearching = hasQuery
                        state.isPeopleSearchLoading = hasQuery && query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
                        state.isProgramsSearchLoading = hasQuery
                    }
                    state.lastLoadedConfig = config
                    state.lastAdultHidden = currentAdultHidden
                }

                let offlineSearchRefresh: Effect<Action> = state.filter == .downloads
                    ? .send(.performSearch(state.searchQuery, debounceRequestID: nil))
                    : .none

                if state.filter == .downloads {
                    state.isLoading = false
                    state.primaryCatalogLoadRequestID = nil
                    state.multiPlaylistLoadRequestID = nil
                    state.errorMessage = nil
                    state.lastLoadedConfig = config
                    state.lastAdultHidden = currentAdultHidden
                    return .merge(
                        .cancel(id: searchCatalogLoadCancelID),
                        .cancel(id: searchMultiPlaylistLoadCancelID),
                        .cancel(id: searchCatalogPrepareCancelID),
                        .cancel(id: searchMultiPlaylistPrepareCancelID),
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID),
                        loadHistory,
                        loadFavs,
                        loadCuratedPlaylist,
                        loadHiddenMedia,
                        loadSearchCategoryPreferences,
                        .send(.loadReminders),
                        offlineSearchRefresh
                    )
                }

                guard !state.hasLoaded, !state.isLoading else {
                    let query = state.searchQuery
                    let hasCachedQuery = state.hasLoaded
                        && !state.isLoading
                        && state.filter != .downloads
                        && !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    let refreshCachedQuery: Effect<Action> = hasCachedQuery
                        ? .send(.performSearch(query, debounceRequestID: nil))
                        : .none
                    return .merge(
                        loadHistory,
                        loadFavs,
                        loadCuratedPlaylist,
                        loadHiddenMedia,
                        loadSearchCategoryPreferences,
                        .send(.loadReminders),
                        offlineSearchRefresh,
                        refreshCachedQuery,
                        sourceCatalogChanged ? .cancel(id: searchEPGCancelID) : .none
                    )
                }
                state.isLoading = true
                state.errorMessage = nil
                let primaryRequestID = UUID()
                let multiPlaylistRequestID = playlists.count > 1 ? UUID() : nil
                state.primaryCatalogLoadRequestID = primaryRequestID
                state.multiPlaylistLoadRequestID = multiPlaylistRequestID

                // Concurrently fetch active playlist plus other playlists if multiple exist
                let primaryFetch: Effect<Action> = .run { send in
                    async let channelsReq = try? iptvClient.fetchLiveChannels(config, nil)
                    let vods: [MediaModels.Item]?
                    let series: [MediaModels.Item]?
                    let liveCats: [MediaModels.Category]?
                    let vodCats: [MediaModels.Category]?
                    let seriesCats: [MediaModels.Category]?
                    if config.type == .plex || config.type == .emby {
                        // Authenticated media servers are searched on demand instead of loading
                        // their entire libraries into the global search index.
                        vods = []
                        series = []
                        liveCats = []
                        vodCats = []
                        seriesCats = []
                    } else {
                        async let vodsReq = try? iptvClient.fetchVODs(config, nil)
                        async let seriesReq = try? iptvClient.fetchSeries(config, nil)
                        async let liveCatsReq = try? iptvClient.fetchLiveCategories(config)
                        async let vodCatsReq = try? iptvClient.fetchVODCategories(config)
                        async let seriesCatsReq = try? iptvClient.fetchSeriesCategories(config)
                        (vods, series, liveCats, vodCats, seriesCats) = await (vodsReq, seriesReq, liveCatsReq, vodCatsReq, seriesCatsReq)
                    }
                    let channels = await channelsReq
                    var resolvedVODs = vods ?? []
                    var resolvedSeries = series ?? []
                    if let playlistID = config.playlistID {
                        let vodOverrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                        let seriesOverrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .series)
                        resolvedVODs = resolvedVODs.map { $0.replacingPresentationOverride(vodOverrides[$0.id]) }
                        resolvedSeries = resolvedSeries.map { $0.replacingPresentationOverride(seriesOverrides[$0.id]) }
                    }
                    guard profileContextClient.snapshot() == profileScope else { return }

                    let defaultBadge = searchSourceBadge(for: config)
                    let chCounts = Dictionary(grouping: channels ?? [], by: \.categoryID).mapValues(\.count)
                    let voCounts = Dictionary(grouping: resolvedVODs, by: \.categoryID).mapValues(\.count)
                    let seCounts = Dictionary(grouping: resolvedSeries, by: \.categoryID).mapValues(\.count)

                    var categoryItems: [CategorySearchResultItem] = []
                    for cat in liveCats ?? [] {
                        categoryItems.append(CategorySearchResultItem(
                            category: cat,
                            type: .live,
                            playlistBadge: defaultBadge,
                            playlistID: config.playlistID,
                            itemCount: chCounts[cat.id] ?? 0
                        ))
                    }
                    for cat in vodCats ?? [] {
                        categoryItems.append(CategorySearchResultItem(
                            category: cat,
                            type: .vod,
                            playlistBadge: defaultBadge,
                            playlistID: config.playlistID,
                            itemCount: voCounts[cat.id] ?? 0
                        ))
                    }
                    for cat in seriesCats ?? [] {
                        categoryItems.append(CategorySearchResultItem(
                            category: cat,
                            type: .series,
                            playlistBadge: defaultBadge,
                            playlistID: config.playlistID,
                            itemCount: seCounts[cat.id] ?? 0
                        ))
                    }

                    if channels == nil, vods == nil, series == nil {
                        await send(.loadAllDataResponse(
                            requestID: primaryRequestID,
                            config: config,
                            result: .failure(NetworkError.invalidResponse)
                        ))
                    } else {
                        await send(.loadAllDataResponse(
                            requestID: primaryRequestID,
                            config: config,
                            result: .success((
                                channels: channels ?? [],
                                vods: resolvedVODs,
                                series: resolvedSeries,
                                categories: categoryItems
                            ))
                        ))
                    }
                }

                let multiPlaylistFetch: Effect<Action> = if let multiPlaylistRequestID {
                    .run { send in
                        var list: [(badge: PlaylistSourceBadge, channels: [MediaModels.Item], vods: [MediaModels.Item], series: [MediaModels.Item], categories: [CategorySearchResultItem])] = []
                        for (index, p) in playlists.enumerated() {
                            guard let pConfig = p.toPlaylistConfig() else { continue }
                            let badge = UnifiedPlaylistManager.shared.badge(for: pConfig, index: index)
                            async let channelsReq = try? iptvClient.fetchLiveChannels(pConfig, nil)
                            let vods: [MediaModels.Item]?
                            let series: [MediaModels.Item]?
                            let liveCats: [MediaModels.Category]?
                            let vodCats: [MediaModels.Category]?
                            let seriesCats: [MediaModels.Category]?
                            if pConfig.type == .plex || pConfig.type == .emby {
                                vods = []
                                series = []
                                liveCats = []
                                vodCats = []
                                seriesCats = []
                            } else {
                                async let vodsReq = try? iptvClient.fetchVODs(pConfig, nil)
                                async let seriesReq = try? iptvClient.fetchSeries(pConfig, nil)
                                async let liveCatsReq = try? iptvClient.fetchLiveCategories(pConfig)
                                async let vodCatsReq = try? iptvClient.fetchVODCategories(pConfig)
                                async let seriesCatsReq = try? iptvClient.fetchSeriesCategories(pConfig)
                                (vods, series, liveCats, vodCats, seriesCats) = await (vodsReq, seriesReq, liveCatsReq, vodCatsReq, seriesCatsReq)
                            }
                            let channels = await channelsReq
                            var resolvedVODs = vods ?? []
                            var resolvedSeries = series ?? []
                            if let playlistID = pConfig.playlistID {
                                let vodOverrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                                let seriesOverrides = await mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .series)
                                resolvedVODs = resolvedVODs.map { $0.replacingPresentationOverride(vodOverrides[$0.id]) }
                                resolvedSeries = resolvedSeries.map { $0.replacingPresentationOverride(seriesOverrides[$0.id]) }
                            }
                            let chCounts = Dictionary(grouping: channels ?? [], by: \.categoryID).mapValues(\.count)
                            let voCounts = Dictionary(grouping: resolvedVODs, by: \.categoryID).mapValues(\.count)
                            let seCounts = Dictionary(grouping: resolvedSeries, by: \.categoryID).mapValues(\.count)

                            var pCategories: [CategorySearchResultItem] = []
                            for cat in liveCats ?? [] {
                                pCategories.append(CategorySearchResultItem(
                                    category: cat,
                                    type: .live,
                                    playlistBadge: badge,
                                    playlistID: pConfig.playlistID,
                                    itemCount: chCounts[cat.id] ?? 0
                                ))
                            }
                            for cat in vodCats ?? [] {
                                pCategories.append(CategorySearchResultItem(
                                    category: cat,
                                    type: .vod,
                                    playlistBadge: badge,
                                    playlistID: pConfig.playlistID,
                                    itemCount: voCounts[cat.id] ?? 0
                                ))
                            }
                            for cat in seriesCats ?? [] {
                                pCategories.append(CategorySearchResultItem(
                                    category: cat,
                                    type: .series,
                                    playlistBadge: badge,
                                    playlistID: pConfig.playlistID,
                                    itemCount: seCounts[cat.id] ?? 0
                                ))
                            }
                            list.append((badge: badge, channels: channels ?? [], vods: resolvedVODs, series: resolvedSeries, categories: pCategories))
                        }
                        guard profileContextClient.snapshot() == profileScope else { return }
                        await send(.loadPlaylistsDataResponse(
                            requestID: multiPlaylistRequestID,
                            config: config,
                            list: list
                        ))
                    }
                } else {
                    .none
                }

                return .concatenate(
                    .cancel(id: searchCatalogLoadCancelID),
                    .cancel(id: searchMultiPlaylistLoadCancelID),
                    .cancel(id: searchCatalogPrepareCancelID),
                    .cancel(id: searchMultiPlaylistPrepareCancelID),
                    .cancel(id: searchCancelID),
                    .cancel(id: searchEPGCancelID),
                    .cancel(id: searchPeopleCancelID),
                    .cancel(id: searchProgramsCancelID),
                    .merge(
                        loadHistory,
                        loadFavs,
                        loadCuratedPlaylist,
                        loadHiddenMedia,
                        loadSearchCategoryPreferences,
                        primaryFetch.cancellable(id: searchCatalogLoadCancelID, cancelInFlight: true),
                        multiPlaylistFetch.cancellable(id: searchMultiPlaylistLoadCancelID, cancelInFlight: true),
                        .send(.loadReminders),
                        offlineSearchRefresh
                    )
                )

            case let .loadSavedPlaylistsResponse(playlists):
                let catalogChanged = searchCatalogSources(state.savedPlaylists) != searchCatalogSources(playlists)
                if catalogChanged {
                    guard let config = state.lastLoadedConfig else {
                        state.invalidateFocusMemory()
                        state.activeEPGEnrichmentRequestID = nil
                        state.savedPlaylists = playlists
                        state.curatedPlaylistResults = []
                        return .merge(
                            .cancel(id: searchEPGCancelID),
                            .cancel(id: searchCancelID),
                            .cancel(id: searchPeopleCancelID),
                            .cancel(id: searchProgramsCancelID)
                        )
                    }
                    // Keep the previous catalog in state until onAppear compares
                    // and rebuilds the indexes from the repository's current set.
                    return .send(.onAppear(config: config))
                }
                state.savedPlaylists = playlists
                return .none

            case let .loadRecentSearchesResponse(history):
                state.recentSearches = history
                return .none

            case let .hiddenMediaLoaded(requestID, scope, result):
                guard state.hiddenMediaLoadRequestID == requestID,
                      profileContextClient.snapshot() == scope
                else { return .none }
                state.hiddenMediaLoadRequestID = nil
                state.isHiddenMediaLoaded = true
                if case let .success(items) = result {
                    state.hiddenMediaEntries = items
                }
                state.filterHiddenMediaFromCatalogs()
                state.clearSearchResults()
                guard !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return .none }
                guard state.pendingSearchDebounceRequestID == nil else { return .none }
                return .send(.performSearch(state.searchQuery, debounceRequestID: nil))

            case let .primaryCatalogPrepared(requestID, responseConfig, hiddenMediaRequestID, sourceData, prepared):
                guard state.primaryCatalogLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                guard state.hiddenMediaLoadRequestID == hiddenMediaRequestID else {
                    return .send(.loadAllDataResponse(requestID: requestID, config: responseConfig, result: .success(sourceData)))
                }
                state.allChannels = prepared.channels
                state.allVODs = prepared.vods
                state.allSeries = prepared.series
                state.allCategories = prepared.categories
                if state.indexedChannels.isEmpty {
                    state.indexedChannels = prepared.indexedChannels
                    state.indexedVODs = prepared.indexedVODs
                    state.indexedSeries = prepared.indexedSeries
                    state.indexedCategories = prepared.categories
                }
                state.primaryCatalogLoadRequestID = nil
                state.isLoading = false
                state.hasLoaded = true
                state.refreshCuratedPlaylistResults()
                if !state.debouncedQuery.isEmpty {
                    guard state.multiPlaylistLoadRequestID == nil else { return .none }
                    return .send(.performSearch(state.debouncedQuery, debounceRequestID: nil))
                }
                return .none

            case let .multiPlaylistCatalogPrepared(requestID, responseConfig, hiddenMediaRequestID, sourceData, prepared):
                guard state.multiPlaylistLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                guard state.hiddenMediaLoadRequestID == hiddenMediaRequestID else {
                    return .send(.loadPlaylistsDataResponse(requestID: requestID, config: responseConfig, list: sourceData))
                }
                state.indexedChannels = prepared.channels
                state.indexedVODs = prepared.vods
                state.indexedSeries = prepared.series
                state.indexedCategories = prepared.categories
                state.multiPlaylistLoadRequestID = nil
                state.refreshCuratedPlaylistResults()
                if state.primaryCatalogLoadRequestID == nil, !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery, debounceRequestID: nil))
                }
                return .none

            case .reloadSearchCategoryPreferences:
                let profileScope = profileContextClient.snapshot()
                let requestID = UUID()
                let playlistIDs = Set(
                    state.savedPlaylists.map(\.id)
                        + [state.lastLoadedConfig?.playlistID].compactMap(\.self)
                )
                let categoryPreferencePlaylistScopes = Array(playlistIDs.map(Optional.some)) + [nil]
                state.hiddenSearchCategoryProfileScope = profileScope
                state.hiddenSearchCategoryPlaylistIDs = playlistIDs
                state.hiddenSearchCategoryLoadRequestID = requestID
                state.hiddenSearchCategoryPreferenceIDs = []
                state.isHiddenSearchCategoryPreferencesLoaded = false
                state.errorMessage = nil
                if state.searchContentScope == .myCategories,
                   !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                {
                    state.isSearching = true
                    state.clearSearchResults()
                }

                return .run { send in
                    var hiddenCategoryIDs = Set<String>()
                    var errorMessage: String?
                    for playlistID in categoryPreferencePlaylistScopes {
                        for type in ["live", "vod", "series"] {
                            let preferences: [CategoryPreferenceDTO]
                            do {
                                preferences = try await databaseClient.fetchCategoryPreferences(
                                    type,
                                    CategoryPreferenceScope(profileID: profileScope.profileID, playlistID: playlistID)
                                )
                            } catch {
                                errorMessage = error.localizedDescription
                                break
                            }
                            for preference in preferences where preference.isHidden {
                                hiddenCategoryIDs.insert(
                                    searchCategoryPreferenceIdentity(
                                        type: type,
                                        playlistID: playlistID,
                                        categoryID: preference.categoryID
                                    )
                                )
                            }
                        }
                        guard !Task.isCancelled else { return }
                        if errorMessage != nil {
                            break
                        }
                    }
                    guard profileContextClient.snapshot() == profileScope else { return }
                    await send(.searchCategoryPreferencesLoaded(
                        requestID: requestID,
                        profileScope: profileScope,
                        hiddenCategoryIDs: hiddenCategoryIDs,
                        errorMessage: errorMessage
                    ))
                }
                .cancellable(id: searchCategoryPreferencesCancelID, cancelInFlight: true)

            case let .searchCategoryPreferencesLoaded(requestID, profileScope, hiddenCategoryIDs, errorMessage):
                guard state.hiddenSearchCategoryLoadRequestID == requestID,
                      state.hiddenSearchCategoryProfileScope == profileScope,
                      profileContextClient.snapshot() == profileScope
                else { return .none }
                state.hiddenSearchCategoryLoadRequestID = nil
                if let errorMessage {
                    guard state.searchContentScope == .myCategories else { return .none }
                    state.isHiddenSearchCategoryPreferencesLoaded = false
                    state.isSearching = false
                    state.errorMessage = AppStrings.Errors.searchFailed(desc: errorMessage)
                    state.clearSearchResults()
                    return .none
                }
                state.hiddenSearchCategoryPreferenceIDs = hiddenCategoryIDs
                state.isHiddenSearchCategoryPreferencesLoaded = true
                guard state.searchContentScope == .myCategories,
                      !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      state.pendingSearchDebounceRequestID == nil
                else { return .none }
                return .send(.performSearch(state.searchQuery, debounceRequestID: nil))

            case let .loadAllDataResponse(requestID, responseConfig, .success(data)):
                guard state.primaryCatalogLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                let hiddenIDs = parentalControlClient.hiddenChannelIDs()
                let blacklistedCats = parentalControlClient.blacklistedCategoryIDs()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let hiddenMediaRequestID = state.hiddenMediaLoadRequestID
                let hiddenMediaEntries = state.hiddenMediaEntries
                let fallbackPlaylistID = responseConfig.playlistID
                let badge = searchSourceBadge(for: responseConfig)
                return .run { send in
                    let prepared = await Task.detached(priority: .userInitiated) {
                        prepareSearchPrimaryCatalog(
                            data,
                            hiddenChannelIDs: hiddenIDs,
                            blacklistedCategoryIDs: blacklistedCats,
                            hideAdult: hideAdult,
                            isAdultContent: isAdult,
                            hiddenMediaEntries: hiddenMediaEntries,
                            fallbackPlaylistID: fallbackPlaylistID,
                            badge: badge
                        )
                    }.value
                    await send(.primaryCatalogPrepared(
                        requestID: requestID,
                        config: responseConfig,
                        hiddenMediaRequestID: hiddenMediaRequestID,
                        sourceData: data,
                        prepared: prepared
                    ))
                }
                .cancellable(id: searchCatalogPrepareCancelID, cancelInFlight: true)

            case let .loadAllDataResponse(requestID, responseConfig, .failure(error)):
                guard state.primaryCatalogLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                state.primaryCatalogLoadRequestID = nil
                state.isLoading = false
                state.errorMessage = AppStrings.Errors.searchFailed(desc: error.localizedDescription)
                if state.multiPlaylistLoadRequestID == nil, !state.debouncedQuery.isEmpty {
                    return .send(.performSearch(state.debouncedQuery, debounceRequestID: nil))
                }
                return .none

            case let .loadPlaylistsDataResponse(requestID, responseConfig, list):
                guard state.multiPlaylistLoadRequestID == requestID,
                      state.lastLoadedConfig == responseConfig
                else { return .none }
                let hiddenIDs = parentalControlClient.hiddenChannelIDs()
                let blacklistedCats = parentalControlClient.blacklistedCategoryIDs()
                let hideAdult = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdult = settingsClient.isAdultContent
                let hiddenMediaRequestID = state.hiddenMediaLoadRequestID
                let hiddenMediaEntries = state.hiddenMediaEntries
                return .run { send in
                    let prepared = await Task.detached(priority: .userInitiated) {
                        prepareSearchMultiPlaylistCatalog(
                            list,
                            hiddenChannelIDs: hiddenIDs,
                            blacklistedCategoryIDs: blacklistedCats,
                            hideAdult: hideAdult,
                            isAdultContent: isAdult,
                            hiddenMediaEntries: hiddenMediaEntries
                        )
                    }.value
                    await send(.multiPlaylistCatalogPrepared(
                        requestID: requestID,
                        config: responseConfig,
                        hiddenMediaRequestID: hiddenMediaRequestID,
                        sourceData: list,
                        prepared: prepared
                    ))
                }
                .cancellable(id: searchMultiPlaylistPrepareCancelID, cancelInFlight: true)

            case let .queryChanged(query):
                if state.searchQuery != query {
                    state.invalidateFocusMemory()
                }
                state.searchQuery = query
                state.activePeopleSearchRequestID = nil
                state.activeProgramsSearchRequestID = nil
                state.activeSearchRequestID = nil
                state.activeEPGEnrichmentRequestID = nil
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmed.isEmpty {
                    state.pendingSearchDebounceRequestID = nil
                    state.debouncedQuery = ""
                    state.isSearching = false
                    state.isPeopleSearchLoading = false
                    state.isProgramsSearchLoading = false
                    state.clearSearchResults()
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeSearchRequestID = nil
                    state.activeEPGEnrichmentRequestID = nil
                    if state.filter == .downloads {
                        state.isSearching = true
                        return .merge(
                            .cancel(id: searchCancelID),
                            .cancel(id: searchEPGCancelID),
                            .cancel(id: searchPeopleCancelID),
                            .cancel(id: searchProgramsCancelID),
                            .cancel(id: searchOfflineMediaCancelID),
                            .cancel(id: searchOfflinePlaybackCancelID),
                            .send(.performSearch(query, debounceRequestID: nil))
                        )
                    }
                    return .merge(
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID),
                        .cancel(id: searchOfflineMediaCancelID),
                        .cancel(id: searchOfflinePlaybackCancelID)
                    )
                }

                state.isSearching = true
                state.isPeopleSearchLoading = trimmed.count >= 2 && (state.filter == .all || state.filter == .people)
                state.isProgramsSearchLoading = true
                state.clearSearchResults()
                let requestID = UUID()
                state.pendingSearchDebounceRequestID = requestID
                let debounceEffect: Effect<Action> = .run { send in
                    try await clock.sleep(for: searchTypingDebounceDuration)
                    await send(.debouncedSearchFired(query: query, requestID: requestID))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)
                return .merge(
                    .cancel(id: searchEPGCancelID),
                    .cancel(id: searchPeopleCancelID),
                    .cancel(id: searchProgramsCancelID),
                    .cancel(id: searchOfflineMediaCancelID),
                    .cancel(id: searchOfflinePlaybackCancelID),
                    debounceEffect
                )

            case let .debouncedSearchFired(query, requestID):
                guard state.pendingSearchDebounceRequestID == requestID,
                      state.searchQuery == query
                else { return .none }
                return .send(.performSearch(query, debounceRequestID: requestID))

            case let .performSearch(query, debounceRequestID):
                guard state.searchQuery == query else { return .none }
                if let debounceRequestID {
                    guard state.pendingSearchDebounceRequestID == debounceRequestID else { return .none }
                }
                state.pendingSearchDebounceRequestID = nil
                state.debouncedQuery = query
                let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if state.filter == .downloads {
                    state.isSearching = true
                    state.isPeopleSearchLoading = false
                    state.isProgramsSearchLoading = false
                    state.clearSearchResults()
                    let requestID = UUID()
                    state.activeOfflineSearchRequestID = requestID
                    let normalizedQuery = trimmed
                    return .merge(
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID),
                        .run { send in
                            let downloadedItems = await (try? downloadClient.getDownloadedMedia()) ?? []
                            let matchingItems = downloadedItems.filter { item in
                                guard item.isAvailable, item.fileSize > 0 else { return false }
                                guard !normalizedQuery.isEmpty else { return true }
                                return item.title.localizedCaseInsensitiveContains(normalizedQuery)
                                    || item.episodeMetadata?.seriesTitle.localizedCaseInsensitiveContains(normalizedQuery) == true
                            }
                            await send(.downloadedSearchCompleted(requestID: requestID, query: query, results: matchingItems))
                        }
                        .cancellable(id: searchOfflineMediaCancelID, cancelInFlight: true)
                    )
                }
                if trimmed.isEmpty {
                    state.isSearching = false
                    state.isPeopleSearchLoading = false
                    state.isProgramsSearchLoading = false
                    state.clearSearchResults()
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeSearchRequestID = nil
                    state.activeEPGEnrichmentRequestID = nil
                    return .merge(
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID)
                    )
                }

                if (state.searchContentScope == .myCategories && !state.isHiddenSearchCategoryPreferencesLoaded)
                    || (state.searchContentScope == .pinned && !state.isCuratedPlaylistLoaded)
                {
                    state.isSearching = true
                    state.isPeopleSearchLoading = trimmed.count >= 2 && (state.filter == .all || state.filter == .people)
                    state.isProgramsSearchLoading = state.filter == .all || state.filter == .programs || state.filter == .epgMatches
                    state.clearSearchResults()
                    return .none
                }

                guard state.isHiddenMediaLoaded else {
                    state.isSearching = true
                    state.isPeopleSearchLoading = trimmed.count >= 2 && (state.filter == .all || state.filter == .people)
                    state.isProgramsSearchLoading = true
                    state.clearSearchResults()
                    return .none
                }

                guard state.primaryCatalogLoadRequestID == nil,
                      state.multiPlaylistLoadRequestID == nil
                else {
                    state.isSearching = true
                    state.isPeopleSearchLoading = trimmed.count >= 2 && (state.filter == .all || state.filter == .people)
                    state.isProgramsSearchLoading = true
                    state.activeSearchRequestID = nil
                    state.activePeopleSearchRequestID = nil
                    state.activeProgramsSearchRequestID = nil
                    state.activeEPGEnrichmentRequestID = nil
                    state.clearSearchResults()
                    return .merge(
                        .cancel(id: searchCancelID),
                        .cancel(id: searchEPGCancelID),
                        .cancel(id: searchPeopleCancelID),
                        .cancel(id: searchProgramsCancelID)
                    )
                }

                state.isSearching = true
                let filter = state.filter
                let selectedPID = state.selectedPlaylistID
                let selectedSourceID = selectedPID.map(PlaylistSourceBadge.sourceID(for:))
                let searchRequestID = UUID()
                let peopleRequestID = UUID()
                let programsRequestID = UUID()
                let shouldSearchPeople = filter == .all || filter == .people
                state.activeSearchRequestID = searchRequestID
                state.activeEPGEnrichmentRequestID = nil
                state.pendingFocusRestorationID = state.focusedResultIDsByScope[state.currentResultScope]
                state.activePeopleSearchRequestID = shouldSearchPeople ? peopleRequestID : nil
                state.activeProgramsSearchRequestID = programsRequestID
                state.isPeopleSearchLoading = shouldSearchPeople && trimmed.count >= 2
                state.isProgramsSearchLoading = true
                state.clearSearchResults()

                let channels: [GlobalSearchResultItem]
                let vods: [GlobalSearchResultItem]
                let series: [GlobalSearchResultItem]
                let categories: [CategorySearchResultItem]

                if !state.indexedChannels.isEmpty || !state.indexedVODs.isEmpty || !state.indexedSeries.isEmpty || !state.indexedCategories.isEmpty {
                    channels = state.indexedChannels
                    vods = state.indexedVODs
                    series = state.indexedSeries
                    categories = state.indexedCategories
                } else {
                    let defaultBadge = searchSourceBadge(for: state.lastLoadedConfig)
                    channels = state.allChannels.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    vods = state.allVODs.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    series = state.allSeries.map { GlobalSearchResultItem(item: $0, playlistBadge: defaultBadge) }
                    categories = state.allCategories
                }

                let searchChannels = state.searchScopedResults(channels)
                let searchVODs = state.searchScopedResults(vods)
                let searchSeries = state.searchScopedResults(series)
                let searchCategories = state.searchScopedCategories(categories)
                let searchContentScope = state.searchContentScope
                let hiddenSearchCategoryPreferenceIDs = state.hiddenSearchCategoryPreferenceIDs
                let curatedPlaylistEntryIDs = Set(state.curatedPlaylistEntries.map(\.id))
                let playlistIDsByBadgeID = state.playlistIDsByBadgeID
                let fallbackPlaylistID = state.lastLoadedConfig?.playlistID

                var configsByBadgeID: [String: (config: PlaylistConfig, badge: PlaylistSourceBadge)] = [:]
                let primaryBadge = searchSourceBadge(for: state.lastLoadedConfig)
                if let primaryConfig = state.lastLoadedConfig {
                    configsByBadgeID[primaryBadge.id] = (primaryConfig, primaryBadge)
                }
                for (index, playlist) in state.savedPlaylists.enumerated() {
                    guard let config = playlist.toPlaylistConfig() else { continue }
                    let badge = UnifiedPlaylistManager.shared.badge(for: config, index: index)
                    configsByBadgeID[badge.id] = (config, badge)
                }
                let scopedConfigs = Array(configsByBadgeID.values
                    .filter { selectedPID == nil || $0.badge.id == selectedSourceID }
                    .sorted { $0.badge.id < $1.badge.id })
                let adultFilteringEnabled = settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled()
                let isAdultContent = settingsClient.isAdultContent
                let blacklistedCategoryIDs = parentalControlClient.blacklistedCategoryIDs()
                let profileScope = profileContextClient.snapshot()

                let searchEffect: Effect<Action> = .run { send in
                    guard !Task.isCancelled else { return }
                    var remoteVODs: [GlobalSearchResultItem] = []
                    var remoteSeries: [GlobalSearchResultItem] = []
                    if filter == .all || filter == .vod || filter == .series || filter == .uhd4k {
                        for source in scopedConfigs where source.config.type == .plex || source.config.type == .emby {
                            guard !Task.isCancelled else { return }
                            guard let results = try? await iptvClient.searchMediaServer(source.config, trimmed) else { continue }
                            let vodOverrides: [String: MediaPresentationOverride]
                            let seriesOverrides: [String: MediaPresentationOverride]
                            if let playlistID = source.config.playlistID {
                                async let vodValues = mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .movie)
                                async let seriesValues = mediaPresentationOverrideClient.load(profileScope.profileID, playlistID, .series)
                                (vodOverrides, seriesOverrides) = await (vodValues, seriesValues)
                            } else {
                                vodOverrides = [:]
                                seriesOverrides = [:]
                            }
                            for item in results.vods where !item.categoryID.isEmpty
                                && !blacklistedCategoryIDs.contains(item.categoryID)
                                && (!adultFilteringEnabled || !isAdultContent(item.title))
                            {
                                let result = GlobalSearchResultItem(
                                    item: item.replacingPresentationOverride(vodOverrides[item.id]),
                                    playlistBadge: source.badge
                                )
                                if isIncludedInSearchContentScope(
                                    result,
                                    scope: searchContentScope,
                                    hiddenCategoryPreferenceIDs: hiddenSearchCategoryPreferenceIDs,
                                    curatedPlaylistEntryIDs: curatedPlaylistEntryIDs,
                                    playlistIDsByBadgeID: playlistIDsByBadgeID,
                                    fallbackPlaylistID: fallbackPlaylistID
                                ) {
                                    remoteVODs.append(result)
                                }
                            }
                            for item in results.series where !item.categoryID.isEmpty
                                && !blacklistedCategoryIDs.contains(item.categoryID)
                                && (!adultFilteringEnabled || !isAdultContent(item.title))
                            {
                                let result = GlobalSearchResultItem(
                                    item: item.replacingPresentationOverride(seriesOverrides[item.id]),
                                    playlistBadge: source.badge
                                )
                                if isIncludedInSearchContentScope(
                                    result,
                                    scope: searchContentScope,
                                    hiddenCategoryPreferenceIDs: hiddenSearchCategoryPreferenceIDs,
                                    curatedPlaylistEntryIDs: curatedPlaylistEntryIDs,
                                    playlistIDsByBadgeID: playlistIDsByBadgeID,
                                    fallbackPlaylistID: fallbackPlaylistID
                                ) {
                                    remoteSeries.append(result)
                                }
                            }
                        }
                    }
                    let knownVODIDs = Set(searchVODs.map(\.id))
                    let knownSeriesIDs = Set(searchSeries.map(\.id))
                    remoteVODs.removeAll { knownVODIDs.contains($0.id) }
                    remoteSeries.removeAll { knownSeriesIDs.contains($0.id) }
                    guard !Task.isCancelled else { return }
                    let output = GlobalSearchEngine.search(
                        query: trimmed,
                        filter: filter,
                        selectedPlaylistID: selectedPID,
                        channels: searchChannels,
                        vods: searchVODs + remoteVODs,
                        series: searchSeries + remoteSeries,
                        categories: searchCategories,
                        limitPerCategory: 100,
                        isCancelled: { Task.isCancelled }
                    )
                    guard !Task.isCancelled else { return }
                    await send(.searchEnrichedCompleted(requestID: searchRequestID, query: query, filter: filter, playlistID: selectedPID, output: output))
                }
                .cancellable(id: searchCancelID, cancelInFlight: true)
                let catalog = (searchVODs + searchSeries).filter {
                    selectedPID == nil || $0.playlistBadge.id == selectedSourceID
                }
                let personSearchEffect: Effect<Action> = if shouldSearchPeople {
                    .run { send in
                        guard trimmed.count >= 2, !Task.isCancelled else {
                            await send(.peopleSearchCompleted(requestID: peopleRequestID, query: query, filter: filter, playlistID: selectedPID, results: []))
                            return
                        }
                        guard let response = try? await tmdbClient.searchPeople(trimmed) else {
                            guard !Task.isCancelled else { return }
                            await send(.peopleSearchCompleted(requestID: peopleRequestID, query: query, filter: filter, playlistID: selectedPID, results: []))
                            return
                        }
                        guard !Task.isCancelled else { return }
                        let people = Array(response.results ?? [])
                        let catalogByNormalizedTitle = Dictionary(grouping: catalog, by: { FuzzySearchEngine.normalize($0.item.title) })
                        // Enrich only the highest-ranked people for bounded per-query TMDB traffic; cache hits are shared with actor recommendations.
                        let personIDsForFullCredits = Array(people.prefix(8).map(\.id))
                        var combinedCreditsByPersonID: [Int: [TMDBPersonCreditDTO]] = [:]
                        var nextPersonIndex = 0
                        await withTaskGroup(of: (Int, [TMDBPersonCreditDTO]).self) { group in
                            let concurrentLimit = min(3, personIDsForFullCredits.count)
                            for personID in personIDsForFullCredits.prefix(concurrentLimit) {
                                group.addTask {
                                    guard !Task.isCancelled else { return (personID, []) }
                                    let response = await ActorRecommendationEngine.combinedCredits(for: personID, using: tmdbClient)
                                    return (personID, response?.cast ?? [])
                                }
                            }
                            nextPersonIndex = concurrentLimit
                            while let (personID, credits) = await group.next() {
                                guard !Task.isCancelled else {
                                    group.cancelAll()
                                    break
                                }
                                combinedCreditsByPersonID[personID] = credits
                                guard nextPersonIndex < personIDsForFullCredits.count else { continue }
                                let nextPersonID = personIDsForFullCredits[nextPersonIndex]
                                nextPersonIndex += 1
                                group.addTask {
                                    guard !Task.isCancelled else { return (nextPersonID, []) }
                                    let response = await ActorRecommendationEngine.combinedCredits(for: nextPersonID, using: tmdbClient)
                                    return (nextPersonID, response?.cast ?? [])
                                }
                            }
                        }
                        guard !Task.isCancelled else { return }
                        var seen = Set<String>()
                        var matches: [PersonCreditResult] = []
                        for person in people.prefix(30) {
                            guard !Task.isCancelled, let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { continue }
                            let portraitURL = person.profilePath.flatMap { URL(string: "https://image.tmdb.org/t/p/w185/\($0.trimmingCharacters(in: CharacterSet(charactersIn: "/")))") }
                            let searchableCredits: [(mediaType: String?, titles: [String?], releaseDate: String?)] = if let combinedCredits = combinedCreditsByPersonID[person.id], !combinedCredits.isEmpty {
                                combinedCredits.map {
                                    ($0.mediaType, [$0.title, $0.originalTitle, $0.name, $0.originalName], $0.releaseDate ?? $0.firstAirDate)
                                }
                            } else {
                                (person.knownFor ?? []).map {
                                    ($0.mediaType, [$0.title, $0.originalTitle, $0.name, $0.originalName], $0.releaseDate ?? $0.firstAirDate)
                                }
                            }
                            for credit in searchableCredits {
                                let creditTitles = credit.titles
                                    .compactMap(\.self)
                                    .map(FuzzySearchEngine.normalize)
                                    .filter { !$0.isEmpty }
                                var playable: [GlobalSearchResultItem] = []
                                var unknownYearPlayable: [GlobalSearchResultItem] = []
                                var seenCandidates = Set<String>()
                                let expectedType: MediaModels.ItemType? = switch credit.mediaType?.lowercased() {
                                case "movie": .vod
                                case "tv": .series
                                default: nil
                                }
                                let creditYear = credit.releaseDate.flatMap { Int($0.prefix(4)) }
                                for title in creditTitles {
                                    for result in catalogByNormalizedTitle[title] ?? [] {
                                        let resultIdentity = globalSearchResultIdentity(result)
                                        guard seenCandidates.insert(resultIdentity).inserted else { continue }
                                        if let expectedType {
                                            guard result.item.type == expectedType else { continue }
                                        }
                                        let itemYear = result.item.releaseDate.flatMap { Int($0.prefix(4)) }
                                        if let creditYear, let itemYear {
                                            guard itemYear == creditYear else { continue }
                                        } else if creditYear != nil {
                                            unknownYearPlayable.append(result)
                                            continue
                                        }
                                        playable.append(result)
                                    }
                                }
                                if creditYear != nil, playable.isEmpty {
                                    playable = unknownYearPlayable
                                }
                                if expectedType == nil || creditYear == nil {
                                    let distinctTitles = Set(playable.map {
                                        "\($0.item.type.rawValue)|\(FuzzySearchEngine.normalize($0.item.title))|\(($0.item.releaseDate ?? "").prefix(4))"
                                    })
                                    guard distinctTitles.count == 1 else { continue }
                                }
                                for result in playable {
                                    let resultIdentity = globalSearchResultIdentity(result)
                                    let personCreditIdentity = lengthPrefixedSearchIdentity([String(person.id), resultIdentity])
                                    guard seen.insert(personCreditIdentity).inserted else { continue }
                                    matches.append(PersonCreditResult(personID: person.id, personName: name, portraitURL: portraitURL, result: result))
                                    if matches.count >= 80 {
                                        break
                                    }
                                }
                                if matches.count >= 80 {
                                    break
                                }
                            }
                            if matches.count >= 80 {
                                break
                            }
                        }
                        guard !Task.isCancelled else { return }
                        await send(.peopleSearchCompleted(requestID: peopleRequestID, query: query, filter: filter, playlistID: selectedPID, results: matches))
                    }
                    .cancellable(id: searchPeopleCancelID, cancelInFlight: true)
                } else {
                    .cancel(id: searchPeopleCancelID)
                }

                let channelsByBadgeID = Dictionary(grouping: searchChannels, by: { $0.playlistBadge.id })
                let programsEffect: Effect<Action> = .run { send in
                    var matches: [ProgramResult] = []
                    var seen = Set<String>()
                    for source in scopedConfigs {
                        guard !Task.isCancelled else { return }
                        let sourceChannels = channelsByBadgeID[source.badge.id]?.map(\.item)
                            ?? (source.badge.id == primaryBadge.id ? searchChannels.map(\.item) : [])
                        let found: [CachedEPGProgramMatch] = if source.config.type == .m3u {
                            await iptvClient.searchCachedEPGPrograms(source.config, trimmed, sourceChannels, 100 - matches.count)
                        } else {
                            await customEPGMappingClient.searchCachedPrograms(trimmed, sourceChannels, 100 - matches.count)
                        }
                        for match in found {
                            let result = GlobalSearchResultItem(item: match.channel, playlistBadge: source.badge, matchedEPGTitle: match.program.title, matchedEPGProgram: match.program)
                            let programResult = ProgramResult(program: match.program, result: result)
                            if seen.insert(programResult.id).inserted {
                                matches.append(programResult)
                            }
                            if matches.count >= 100 {
                                break
                            }
                        }
                        if matches.count >= 100 {
                            break
                        }
                    }
                    guard !Task.isCancelled else { return }
                    await send(.programsSearchCompleted(requestID: programsRequestID, query: query, filter: filter, playlistID: selectedPID, results: matches))
                }
                .cancellable(id: searchProgramsCancelID, cancelInFlight: true)
                return .merge(.cancel(id: searchEPGCancelID), searchEffect, personSearchEffect, programsEffect)

            case let .searchCompleted(query, filter, live, vods, series):
                guard state.debouncedQuery == query, state.searchQuery == query, state.filter == filter else { return .none }
                state.isSearching = false
                state.liveResults = live
                state.vodResults = vods.filter { !state.isHiddenMedia($0, fallbackPlaylistID: state.lastLoadedConfig?.playlistID) }
                state.seriesResults = series.filter { !state.isHiddenMedia($0, fallbackPlaylistID: state.lastLoadedConfig?.playlistID) }
                state.restoreFocusedResultIfPossible()
                return .none

            case let .downloadedSearchCompleted(requestID, query, results):
                guard state.activeOfflineSearchRequestID == requestID,
                      state.filter == .downloads,
                      state.searchQuery == query,
                      state.debouncedQuery == query
                else { return .none }
                state.activeOfflineSearchRequestID = nil
                state.isSearching = false
                state.downloadedMediaResults = results
                state.filterCounts[.downloads] = results.count
                state.restoreFocusedResultIfPossible()
                return .none

            case let .searchEnrichedCompleted(requestID, query, filter, playlistID, output):
                guard state.activeSearchRequestID == requestID, state.debouncedQuery == query, state.searchQuery == query, state.filter == filter, state.selectedPlaylistID == playlistID else { return .none }
                let hiddenIdentities = Set(state.hiddenMediaEntries.map(\.identity))
                let playlistIDsByBadgeID = state.playlistIDsByBadgeID
                let fallbackPlaylistID = state.lastLoadedConfig?.playlistID
                let isHiddenMediaResult: (GlobalSearchResultItem) -> Bool = { result in
                    let playlistID = result.item.playlistID
                        ?? playlistIDsByBadgeID[result.playlistBadge.id]
                        ?? fallbackPlaylistID
                    return hiddenIdentities.contains(HiddenMediaIdentity(item: result.item, fallbackPlaylistID: playlistID))
                }
                state.activeSearchRequestID = nil
                state.isSearching = false
                state.categoryResults = output.categories
                state.enrichedLiveResults = output.live
                state.enrichedVODResults = output.vods.filter { !isHiddenMediaResult($0) }
                state.enrichedSeriesResults = output.series.filter { !isHiddenMediaResult($0) }
                state.peopleResults.removeAll { isHiddenMediaResult($0.result) }
                state.filterCounts = output.counts
                let removedVODCount = output.vods.count - state.enrichedVODResults.count
                let removedSeriesCount = output.series.count - state.enrichedSeriesResults.count
                state.filterCounts[.categories] = output.categories.count
                state.filterCounts[.vod] = state.enrichedVODResults.count
                state.filterCounts[.series] = state.enrichedSeriesResults.count
                let uhdOutput = GlobalSearchEngine.search(
                    query: query,
                    filter: .uhd4k,
                    selectedPlaylistID: playlistID,
                    channels: output.live,
                    vods: state.enrichedVODResults,
                    series: state.enrichedSeriesResults,
                    categories: [],
                    limitPerCategory: 100
                )
                state.filterCounts[.uhd4k] = uhdOutput.counts[.uhd4k, default: 0]
                state.baseAllResultsCount = max(0, output.counts[.all, default: 0] - removedVODCount - removedSeriesCount)

                // Maintain backward compatibility
                state.liveResults = output.live.map(\.item)
                state.vodResults = state.enrichedVODResults.map(\.item)
                state.seriesResults = state.enrichedSeriesResults.map(\.item)
                state.filterCounts[.people] = state.peopleResults.count
                state.filterCounts[.programs] = state.programResults.count
                state.updateAllResultsCount()
                state.restoreFocusedResultIfPossible()
                state.activeEPGEnrichmentRequestID = nil
                guard let primaryConfig = state.lastLoadedConfig, !output.live.isEmpty else { return .none }
                var playlistConfigs: [String: PlaylistConfig] = [:]
                let primaryBadgeID = UnifiedPlaylistManager.shared.badge(for: primaryConfig).id
                playlistConfigs[primaryBadgeID] = primaryConfig
                for (index, playlist) in state.savedPlaylists.enumerated() {
                    guard let config = playlist.toPlaylistConfig() else { continue }
                    let badge = UnifiedPlaylistManager.shared.badge(for: config, index: index)
                    playlistConfigs[badge.id] = config
                }
                let channelResults = Array(output.live.prefix(6))
                let selectedPlaylistID = state.selectedPlaylistID
                let epgRequestID = UUID()
                state.activeEPGEnrichmentRequestID = epgRequestID
                return .run { send in
                    var programByResultID: [String: EPGProgram] = [:]
                    let resultsByPlaylist = Dictionary(grouping: channelResults, by: \.playlistBadge.id)
                    for (playlistBadgeID, results) in resultsByPlaylist {
                        guard !Task.isCancelled else { return }
                        guard let config = playlistConfigs[playlistBadgeID] else { continue }
                        let epgIDs = results.map { result in
                            config.type == .m3u ? (result.item.epgChannelID ?? result.item.id) : result.item.id
                        }
                        let cachedPrograms = await iptvClient.cachedEPGPrograms(config, epgIDs, 4)
                        // Keep cache misses serial: one M3U feed should not be downloaded
                        // and parsed concurrently once for each result card.
                        for result in results {
                            guard !Task.isCancelled else { return }
                            let epgID = config.type == .m3u
                                ? (result.item.epgChannelID ?? result.item.id)
                                : result.item.id
                            let programs: [EPGProgram] = if let snapshot = cachedPrograms[epgID] {
                                snapshot.programs
                            } else {
                                await (try? iptvClient.fetchShortEPG(
                                    config,
                                    result.item.id,
                                    result.item.epgChannelID,
                                    4
                                )) ?? []
                            }
                            let now = Date()
                            let selectedProgram = programs
                                .filter { $0.startTime > now }
                                .sorted { $0.startTime < $1.startTime }
                                .first
                                ?? programs.first(where: \.isPlayingNow)
                                ?? programs.first(where: { $0.endTime > now })
                            if let selectedProgram {
                                programByResultID[result.id] = selectedProgram
                            }
                        }
                    }
                    guard !Task.isCancelled else { return }
                    let results = output.live.map { result -> GlobalSearchResultItem in
                        guard let program = programByResultID[result.id] else { return result }
                        return GlobalSearchResultItem(
                            item: result.item,
                            playlistBadge: result.playlistBadge,
                            is4K: result.is4K,
                            matchedEPGTitle: program.title,
                            matchedEPGProgram: program,
                            score: result.score,
                            searchMatch: result.searchMatch
                        )
                    }
                    await send(.liveEPGEnriched(
                        requestID: epgRequestID,
                        query: query,
                        filter: filter,
                        playlistID: selectedPlaylistID,
                        results: results
                    ))
                }
                .cancellable(id: searchEPGCancelID, cancelInFlight: true)

            case let .liveEPGEnriched(requestID, query, filter, playlistID, results):
                guard
                    state.activeEPGEnrichmentRequestID == requestID,
                    state.debouncedQuery == query,
                    state.searchQuery == query,
                    state.filter == filter,
                    state.selectedPlaylistID == playlistID
                else { return .none }
                state.activeEPGEnrichmentRequestID = nil
                state.enrichedLiveResults = results
                state.restoreFocusedResultIfPossible()
                return .none

            case let .peopleSearchCompleted(requestID, query, filter, playlistID, results):
                guard state.activePeopleSearchRequestID == requestID, state.debouncedQuery == query, state.searchQuery == query, state.filter == filter, state.selectedPlaylistID == playlistID else { return .none }
                state.activePeopleSearchRequestID = nil
                state.isPeopleSearchLoading = false
                state.peopleResults = results.filter { !state.isHiddenMedia($0.result) }
                state.filterCounts[.people] = state.peopleResults.count
                state.updateAllResultsCount()
                state.restoreFocusedResultIfPossible()
                return .none

            case let .programsSearchCompleted(requestID, query, filter, playlistID, results):
                guard state.activeProgramsSearchRequestID == requestID, state.debouncedQuery == query, state.searchQuery == query, state.filter == filter, state.selectedPlaylistID == playlistID else { return .none }
                state.activeProgramsSearchRequestID = nil
                state.isProgramsSearchLoading = false
                state.programResults = results
                state.filterCounts[.programs] = results.count
                state.updateAllResultsCount()
                state.restoreFocusedResultIfPossible()
                return .none

            case .loadReminders:
                let requestID = UUID()
                state.reminderLoadRequestID = requestID
                return .run { send in
                    let ids = await reminderClient.getScheduledReminderIDs()
                    await send(.remindersLoaded(requestID: requestID, ids))
                }

            case let .remindersLoaded(requestID, ids):
                guard state.reminderLoadRequestID == requestID else { return .none }
                state.reminderLoadRequestID = nil
                var reconciledIDs = ids
                for programID in state.pendingReminderRequestIDs.keys {
                    if state.scheduledReminderIDs.contains(programID) {
                        reconciledIDs.insert(programID)
                    } else {
                        reconciledIDs.remove(programID)
                    }
                }
                state.scheduledReminderIDs = reconciledIDs
                return .none

            case let .toggleReminder(program, channel, reminderID, playlistIdentity):
                guard state.pendingReminderRequestIDs[reminderID] == nil else { return .none }
                state.reminderFailureMessage = nil
                state.reminderLoadRequestID = nil
                let requestID = UUID()
                state.pendingReminderRequestIDs[reminderID] = requestID
                if state.scheduledReminderIDs.contains(reminderID)
                    || state.scheduledReminderIDs.contains(program.id)
                {
                    state.scheduledReminderIDs.remove(reminderID)
                    state.scheduledReminderIDs.remove(program.id)
                    return .run { send in
                        await reminderClient.removeReminder(reminderID)
                        if program.id != reminderID {
                            await reminderClient.removeReminder(program.id)
                        }
                        await send(.reminderToggleResponse(
                            programID: reminderID,
                            legacyProgramID: program.id,
                            requestID: requestID,
                            isScheduled: false
                        ))
                    }
                }
                let namespacedProgram = EPGProgram(
                    id: reminderID,
                    title: program.title,
                    description: program.description,
                    startTime: program.startTime,
                    endTime: program.endTime,
                    isPlayingNow: program.isPlayingNow
                )
                return .run { send in
                    do {
                        guard try await reminderClient.requestAuthorization() else {
                            await send(.reminderToggleResponse(programID: reminderID, legacyProgramID: program.id, requestID: requestID, isScheduled: false))
                            await send(.reminderSchedulingFailed)
                            return
                        }
                        try await reminderClient.scheduleReminder(namespacedProgram, channel, 5, playlistIdentity)
                        let ids = await reminderClient.getScheduledReminderIDs()
                        await send(.reminderToggleResponse(
                            programID: reminderID,
                            legacyProgramID: program.id,
                            requestID: requestID,
                            isScheduled: ids.contains(reminderID)
                        ))
                    } catch {
                        await send(.reminderToggleResponse(programID: reminderID, legacyProgramID: program.id, requestID: requestID, isScheduled: false))
                        await send(.reminderSchedulingFailed)
                    }
                }

            case let .reminderToggleResponse(programID, legacyProgramID, requestID, isScheduled):
                guard state.pendingReminderRequestIDs[programID] == requestID else { return .none }
                state.pendingReminderRequestIDs.removeValue(forKey: programID)
                if isScheduled {
                    state.scheduledReminderIDs.insert(programID)
                } else {
                    state.scheduledReminderIDs.remove(programID)
                    state.scheduledReminderIDs.remove(legacyProgramID)
                }
                return .none

            case .reminderSchedulingFailed:
                state.reminderFailureMessage = AppStrings.Player.reminderSchedulingFailed
                return .run { send in
                    try? await Task.sleep(for: .seconds(4))
                    await send(.clearReminderFailure)
                }

            case .clearReminderFailure:
                state.reminderFailureMessage = nil
                return .none

            case let .filterChanged(filter):
                guard state.filter != filter else { return .none }
                let wasSearchingDownloads = state.filter == .downloads
                state.filter = filter
                if filter != .categories {
                    state.selectedCategoryTypeFilter = nil
                }
                state.prepareFocusRestorationForCurrentScope()
                state.activeEPGEnrichmentRequestID = nil
                let query = state.searchQuery
                if filter == .downloads {
                    state.isLoading = false
                    state.primaryCatalogLoadRequestID = nil
                    state.multiPlaylistLoadRequestID = nil
                    state.pendingSearchDebounceRequestID = nil
                    state.isSearching = true
                    state.clearSearchResults()
                    return .merge(
                        .cancel(id: searchCatalogLoadCancelID),
                        .cancel(id: searchMultiPlaylistLoadCancelID),
                        .cancel(id: searchCatalogPrepareCancelID),
                        .cancel(id: searchMultiPlaylistPrepareCancelID),
                        .cancel(id: searchOfflineMediaCancelID),
                        .cancel(id: searchOfflinePlaybackCancelID),
                        .send(.performSearch(query, debounceRequestID: nil))
                    )
                }
                if wasSearchingDownloads, !state.hasLoaded, let config = state.lastLoadedConfig {
                    state.clearSearchResults()
                    state.pendingSearchDebounceRequestID = nil
                    return .merge(
                        .cancel(id: searchOfflineMediaCancelID),
                        .cancel(id: searchOfflinePlaybackCancelID),
                        .send(.onAppear(config: config))
                    )
                }
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.pendingSearchDebounceRequestID = nil
                    state.isSearching = true
                    state.clearSearchResults()
                    return .merge(
                        .cancel(id: searchOfflineMediaCancelID),
                        .cancel(id: searchOfflinePlaybackCancelID),
                        .send(.performSearch(query, debounceRequestID: nil))
                    )
                }
                state.clearSearchResults()
                state.restoreFocusedResultIfPossible()
                return .merge(
                    .cancel(id: searchEPGCancelID),
                    .cancel(id: searchOfflineMediaCancelID),
                    .cancel(id: searchOfflinePlaybackCancelID)
                )

            case let .searchContentScopeChanged(contentScope):
                guard state.filter != .downloads,
                      state.searchContentScope != contentScope
                else { return .none }
                state.searchContentScope = contentScope
                state.errorMessage = nil
                if let profileKey = state.searchContentScopeProfileKey {
                    state.searchContentScopesByProfile[profileKey] = contentScope
                }
                state.prepareFocusRestorationForCurrentScope()
                state.activeEPGEnrichmentRequestID = nil
                let query = state.searchQuery
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.pendingSearchDebounceRequestID = nil
                    state.isSearching = true
                    state.clearSearchResults()
                    if contentScope == .myCategories, !state.isHiddenSearchCategoryPreferencesLoaded {
                        return .send(.reloadSearchCategoryPreferences)
                    }
                    return .merge(
                        .cancel(id: searchOfflineMediaCancelID),
                        .cancel(id: searchOfflinePlaybackCancelID),
                        .send(.performSearch(query, debounceRequestID: nil))
                    )
                }
                state.clearSearchResults()
                state.restoreFocusedResultIfPossible()
                return .cancel(id: searchEPGCancelID)

            case let .selectPlaylistFilter(playlistID):
                guard state.selectedPlaylistID != playlistID else { return .none }
                state.selectedPlaylistID = playlistID
                state.prepareFocusRestorationForCurrentScope()
                state.activeEPGEnrichmentRequestID = nil
                let query = state.searchQuery
                if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    state.pendingSearchDebounceRequestID = nil
                    state.isSearching = true
                    state.clearSearchResults()
                    return .send(.performSearch(query, debounceRequestID: nil))
                }
                state.restoreFocusedResultIfPossible()
                return .cancel(id: searchEPGCancelID)

            case .resetCache:
                state.invalidateFocusMemory()
                state.activeEPGEnrichmentRequestID = nil
                state.pendingSearchDebounceRequestID = nil
                state.hasLoaded = false
                state.isLoading = false
                state.primaryCatalogLoadRequestID = nil
                state.multiPlaylistLoadRequestID = nil
                state.isSearching = false
                state.allChannels = []
                state.allVODs = []
                state.allSeries = []
                state.indexedChannels = []
                state.indexedVODs = []
                state.indexedSeries = []
                state.curatedPlaylistResults = []
                state.liveResults = []
                state.vodResults = []
                state.seriesResults = []
                state.enrichedLiveResults = []
                state.enrichedVODResults = []
                state.enrichedSeriesResults = []
                state.peopleResults = []
                state.programResults = []
                state.downloadedMediaResults = []
                state.activeOfflineSearchRequestID = nil
                state.activeOfflinePlaybackRequestID = nil
                state.filterCounts[.people] = 0
                state.filterCounts[.programs] = 0
                state.filterCounts = [:]
                state.baseAllResultsCount = 0
                state.searchQuery = ""
                state.debouncedQuery = ""
                state.pendingSearchDebounceRequestID = nil
                state.filter = .all
                state.selectedCategoryTypeFilter = nil
                state.focusedResultID = nil
                state.lastLoadedConfig = nil
                state.selectedPlaylistID = nil
                return .merge(
                    .cancel(id: searchCatalogLoadCancelID),
                    .cancel(id: searchMultiPlaylistLoadCancelID),
                    .cancel(id: searchCatalogPrepareCancelID),
                    .cancel(id: searchMultiPlaylistPrepareCancelID),
                    .cancel(id: searchCancelID),
                    .cancel(id: searchEPGCancelID),
                    .cancel(id: searchPeopleCancelID),
                    .cancel(id: searchProgramsCancelID),
                    .cancel(id: searchOfflineMediaCancelID),
                    .cancel(id: searchOfflinePlaybackCancelID)
                )

            case let .channelSelected(channel):
                let query = state.debouncedQuery
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    await send(.delegate(.didSelectChannel(channel, playlist: nil)))
                }

            case let .focusedResultChanged(id):
                guard state.visibleResultIDs.contains(id) else { return .none }
                state.focusedResultID = id
                state.rememberFocusedResult(id)
                return .none

            case let .vodSelected(vod):
                let query = state.debouncedQuery
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    await send(.delegate(.didSelectVOD(vod)))
                }

            case let .seriesSelected(series):
                let query = state.debouncedQuery
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    await send(.delegate(.didSelectSeries(series)))
                }

            case let .categorySelected(categoryResult):
                let playlistID = categoryResult.playlistID
                    ?? state.playlistIDsByBadgeID[categoryResult.playlistBadge.id]
                    ?? state.lastLoadedConfig?.playlistID
                let query = state.debouncedQuery
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    await send(.delegate(.didSelectCategory(
                        category: categoryResult.category,
                        type: categoryResult.type,
                        playlistID: playlistID
                    )))
                }

            case let .categoryTypeFilterSelected(type):
                state.selectedCategoryTypeFilter = type
                return .none

            case let .personCreditSelected(personCredit):
                let item = personCredit.result.item.replacingPlaylistID(
                    state.playlistIDsByBadgeID[personCredit.result.playlistBadge.id]
                        ?? personCredit.result.item.playlistID
                )
                let query = state.debouncedQuery
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    if item.type == .series {
                        await send(.delegate(.didSelectSeries(item)))
                    } else {
                        await send(.delegate(.didSelectVOD(item)))
                    }
                }

            case let .programSelected(programResult):
                let result = programResult.result
                let channelPlaylist = state.indexedChannels
                    .filter { $0.playlistBadge.id == result.playlistBadge.id }
                    .map(\.item)
                let fallback = state.allChannels
                let playlist = channelPlaylist.isEmpty ? (fallback.isEmpty ? [result.item] : fallback) : channelPlaylist
                let query = state.debouncedQuery
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    await send(.delegate(.didSelectChannel(result.item, playlist: playlist)))
                }

            case let .offlineMediaSelected(item):
                guard state.filter == .downloads,
                      state.downloadedMediaResults.contains(where: {
                          $0.id == item.id && $0.localFilePath == item.localFilePath && $0.isAvailable && $0.fileSize > 0
                      })
                else { return .none }
                let requestID = UUID()
                let query = state.searchQuery
                state.activeOfflinePlaybackRequestID = requestID
                return .run { send in
                    let downloadedItems = await (try? downloadClient.getDownloadedMedia()) ?? []
                    let current = downloadedItems.first(where: {
                        $0.id == item.id &&
                            $0.localFilePath == item.localFilePath &&
                            $0.isAvailable &&
                            $0.fileSize > 0
                    })
                    await send(.offlinePlaybackValidated(
                        requestID: requestID,
                        query: query,
                        current: current,
                        downloadedItems: downloadedItems
                    ))
                }
                .cancellable(id: searchOfflinePlaybackCancelID, cancelInFlight: true)

            case let .offlinePlaybackValidated(requestID, query, current, downloadedItems):
                guard state.activeOfflinePlaybackRequestID == requestID,
                      state.filter == .downloads,
                      state.searchQuery == query
                else { return .none }
                state.activeOfflinePlaybackRequestID = nil
                guard let current else {
                    return .send(.performSearch(query, debounceRequestID: nil))
                }
                let episodeQueue = orderedOfflineSearchEpisodeQueue(
                    startingWith: current,
                    downloadedItems: downloadedItems
                )
                let historySavingEnabled = settingsClient.isSearchHistorySavingEnabled()
                let historyRetention = settingsClient.searchHistoryRetention()
                return .run { send in
                    await Self.recordSearchHistoryIfEnabled(
                        query,
                        enabled: historySavingEnabled,
                        retention: historyRetention,
                        databaseClient: databaseClient
                    )
                    await send(.delegate(.playOfflineMedia(current, episodeQueue: episodeQueue)))
                }

            case .clearHistoryTapped:
                state.recentSearches = []
                return .run { _ in
                    _ = try? await databaseClient.clearSearchHistory()
                }

            case let .togglePinnedSearch(query):
                guard let normalizedQuery = Self.normalizedPinnedSearchQueries([query]).first else { return .none }
                if let existingIndex = state.pinnedSearchQueries.firstIndex(where: {
                    $0.localizedCaseInsensitiveCompare(normalizedQuery) == .orderedSame
                }) {
                    state.pinnedSearchQueries.remove(at: existingIndex)
                } else {
                    guard state.pinnedSearchQueries.count < Self.pinnedSearchQueryLimit else {
                        state.isPinnedSearchLimitAlertPresented = true
                        return .none
                    }
                    state.pinnedSearchQueries.insert(normalizedQuery, at: 0)
                }
                settingsClient.setPinnedSearchQueries(state.pinnedSearchQueries)
                return .none

            case .pinnedSearchLimitAlertDismissed:
                state.isPinnedSearchLimitAlertPresented = false
                return .none

            case let .recentSearchTapped(query):
                if state.searchQuery != query {
                    state.invalidateFocusMemory()
                }
                state.pendingSearchDebounceRequestID = nil
                state.searchQuery = query
                state.debouncedQuery = query
                return .send(.performSearch(query, debounceRequestID: nil))

            case let .tagSelected(tag):
                if state.searchQuery != tag.title {
                    state.invalidateFocusMemory()
                }
                state.pendingSearchDebounceRequestID = nil
                state.searchQuery = tag.title
                state.debouncedQuery = tag.title
                return .send(.performSearch(tag.title, debounceRequestID: nil))

            case let .loadFavoritesResponse(favs, scope):
                guard profileContextClient.snapshot() == scope else { return .none }
                state.favoriteIDs = Set(favs.map(FavoriteIdentity.init))
                return .none

            case let .curatedPlaylistLoaded(snapshot, scope):
                guard profileContextClient.snapshot() == scope, state.curatedPlaylistScope == scope else { return .none }
                Self.applyCuratedPlaylistSnapshot(
                    snapshot,
                    to: &state,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs(),
                    hideAdultContent: settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled(),
                    isAdultContent: settingsClient.isAdultContent
                )
                state.isCuratedPlaylistLoaded = true
                guard state.searchContentScope == .pinned,
                      !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      state.pendingSearchDebounceRequestID == nil
                else { return .none }
                return .send(.performSearch(state.searchQuery, debounceRequestID: nil))

            case let .curatedPlaylistUpdated(snapshot, scope):
                guard profileContextClient.snapshot() == scope,
                      state.curatedPlaylistScope == scope,
                      snapshot.revision >= state.curatedPlaylistRevision
                else { return .none }
                Self.applyCuratedPlaylistSnapshot(
                    snapshot,
                    to: &state,
                    hiddenChannelIDs: parentalControlClient.hiddenChannelIDs(),
                    blacklistedCategoryIDs: parentalControlClient.blacklistedCategoryIDs(),
                    hideAdultContent: settingsClient.hideAdultContent() || settingsClient.isParentalControlEnabled(),
                    isAdultContent: settingsClient.isAdultContent
                )
                state.isCuratedPlaylistLoaded = true
                guard state.searchContentScope == .pinned,
                      !state.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      state.pendingSearchDebounceRequestID == nil
                else { return .none }
                return .send(.performSearch(state.searchQuery, debounceRequestID: nil))

            case let .toggleCuratedPlaylistItem(result):
                guard let playlistID = state.curatedPlaylistID(for: result),
                      let playlist = state.savedPlaylists.first(where: { $0.id == playlistID })
                else { return .none }
                let entry = CuratedPlaylistEntry(
                    playlistID: playlistID,
                    contentType: result.item.type.rawValue,
                    itemID: result.item.id,
                    categoryID: result.item.categoryID,
                    titleSnapshot: result.item.displayTitle,
                    playlistNameSnapshot: playlist.name
                )
                let profileScope = profileContextClient.snapshot()
                return .run { send in
                    let snapshot = await curatedPlaylistClient.toggle(entry, profileScope.profileID)
                    guard !Task.isCancelled else { return }
                    await send(.curatedPlaylistUpdated(snapshot, profileScope))
                }

            case let .removeCuratedPlaylistItem(entryID):
                let profileScope = profileContextClient.snapshot()
                return .run { send in
                    let snapshot = await curatedPlaylistClient.remove(entryID, profileScope.profileID)
                    guard !Task.isCancelled else { return }
                    await send(.curatedPlaylistUpdated(snapshot, profileScope))
                }

            case let .toggleFavorite(item, type, playlistID):
                let profileScope = profileContextClient.snapshot()
                let favItem = FavoriteItem(
                    id: item.id,
                    type: type,
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString,
                    playlistID: playlistID
                )
                let identity = FavoriteIdentity(favItem)
                if state.favoriteIDs.contains(identity) {
                    state.favoriteIDs.remove(identity)
                } else {
                    state.favoriteIDs.insert(identity)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem, profileScope)
                }

            case .delegate:
                return .none
            }
        }
    }

    private static let pinnedSearchQueryLimit = 10

    private static func normalizedPinnedSearchQueries(_ queries: [String]) -> [String] {
        var normalized: [String] = []
        for query in queries {
            let compactQuery = query.split(whereSeparator: \.isWhitespace).joined(separator: " ")
            guard !compactQuery.isEmpty,
                  !normalized.contains(where: { $0.localizedCaseInsensitiveCompare(compactQuery) == .orderedSame })
            else { continue }
            normalized.append(compactQuery)
            if normalized.count == pinnedSearchQueryLimit {
                break
            }
        }
        return normalized
    }

    private static func recordSearchHistoryIfEnabled(
        _ query: String,
        enabled: Bool,
        retention: SearchHistoryRetention,
        databaseClient: DatabaseClient
    ) async {
        guard enabled, !query.isEmpty else { return }
        let cutoff = Date().addingTimeInterval(-retention.duration)
        _ = try? await databaseClient.saveSearchHistory(query, cutoff)
    }

    private static func applyCuratedPlaylistSnapshot(
        _ snapshot: CuratedPlaylistSnapshot,
        to state: inout State,
        hiddenChannelIDs: Set<String>,
        blacklistedCategoryIDs: Set<String>,
        hideAdultContent: Bool,
        isAdultContent: (String) -> Bool
    ) {
        guard snapshot.revision >= state.curatedPlaylistRevision else { return }
        state.curatedPlaylistEntries = snapshot.entries
        state.curatedPlaylistRevision = snapshot.revision
        state.curatedEntryIDsHiddenByPrivacy = curatedEntriesHiddenByPrivacy(
            snapshot.entries,
            hiddenChannelIDs: hiddenChannelIDs,
            blacklistedCategoryIDs: blacklistedCategoryIDs,
            hideAdultContent: hideAdultContent,
            isAdultContent: isAdultContent
        )
        state.refreshCuratedPlaylistResults()
    }

    private static func curatedEntriesHiddenByPrivacy(
        _ entries: [CuratedPlaylistEntry],
        hiddenChannelIDs: Set<String>,
        blacklistedCategoryIDs: Set<String>,
        hideAdultContent: Bool,
        isAdultContent: (String) -> Bool
    ) -> Set<String> {
        Set(entries.compactMap { entry in
            let type = MediaModels.ItemType(rawValue: entry.contentType)
            let hiddenChannel = type == .live && (
                hiddenChannelIDs.contains(entry.itemID) || blacklistedCategoryIDs.contains(entry.categoryID)
            )
            let hiddenAdult = hideAdultContent && isAdultContent(entry.titleSnapshot)
            return hiddenChannel || hiddenAdult ? entry.id : nil
        })
    }
}

// MARK: - GlobalSearchFeature Alias

public typealias GlobalSearchFeature = SearchFeature
