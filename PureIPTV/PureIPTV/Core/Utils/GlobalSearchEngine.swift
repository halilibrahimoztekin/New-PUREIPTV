import Foundation

// MARK: - Global Search Engine

/// Ultra-fast, thread-safe cross-playlist search engine with instant filter badges and EPG matching.
public nonisolated enum GlobalSearchEngine: Sendable {
    public struct SearchResultOutput: Sendable {
        public let live: [GlobalSearchResultItem]
        public let vods: [GlobalSearchResultItem]
        public let series: [GlobalSearchResultItem]
        public let counts: [SearchFeature.SearchFilter: Int]

        public init(
            live: [GlobalSearchResultItem],
            vods: [GlobalSearchResultItem],
            series: [GlobalSearchResultItem],
            counts: [SearchFeature.SearchFilter: Int]
        ) {
            self.live = live
            self.vods = vods
            self.series = series
            self.counts = counts
        }
    }

    /// Performs global multi-playlist search with debounce and multi-filter segmentation.
    public static func search(
        query: String,
        filter: SearchFeature.SearchFilter,
        selectedPlaylistID: UUID?,
        channels: [GlobalSearchResultItem],
        vods: [GlobalSearchResultItem],
        series: [GlobalSearchResultItem],
        limitPerCategory: Int = 100,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> SearchResultOutput {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchResultOutput(live: [], vods: [], series: [], counts: [:])
        }

        let normalizedQuery = FuzzySearchEngine.normalize(trimmed)
        let isLookingFor4K = normalizedQuery.contains("4k") || normalizedQuery.contains("uhd")

        // 1. Filter by selected playlist if specified
        let scopedChannels = selectedPlaylistID == nil ? channels : channels.filter {
            $0.playlistBadge.id == selectedPlaylistID?.uuidString
        }
        let scopedVods = selectedPlaylistID == nil ? vods : vods.filter {
            $0.playlistBadge.id == selectedPlaylistID?.uuidString
        }
        let scopedSeries = selectedPlaylistID == nil ? series : series.filter {
            $0.playlistBadge.id == selectedPlaylistID?.uuidString
        }

        // 2. Score and search Channels
        var matchedChannels: [GlobalSearchResultItem] = []
        for (index, ch) in scopedChannels.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(live: [], vods: [], series: [], counts: [:])
            }
            let normalizedTitle = FuzzySearchEngine.normalize(ch.item.title)
            var baseScore = FuzzySearchEngine.score(query: normalizedQuery, target: normalizedTitle)

            // EPG metadata is searchable with a lower field weight than a title match.
            let epgMatchTitle: String? = ch.matchedEPGTitle
            if let epgMatchTitle {
                let epgNorm = FuzzySearchEngine.normalize(epgMatchTitle)
                if let epgScore = FuzzySearchEngine.score(query: normalizedQuery, target: epgNorm) {
                    baseScore = max(baseScore ?? 0, min(epgScore / 3, 220))
                }
            }
            let channelCategoryScore = categoryScore(query: normalizedQuery, category: ch.item.categoryID)
            if channelCategoryScore > 0 {
                baseScore = max(baseScore ?? 0, channelCategoryScore)
            }

            if let score = baseScore {
                let finalScore = score + (ch.is4K && isLookingFor4K ? 150 : 0)
                matchedChannels.append(
                    GlobalSearchResultItem(
                        item: ch.item,
                        playlistBadge: ch.playlistBadge,
                        is4K: ch.is4K,
                        matchedEPGTitle: epgMatchTitle,
                        matchedEPGProgram: ch.matchedEPGProgram,
                        score: finalScore
                    )
                )
            }
        }
        sortByRelevance(&matchedChannels)

        // 3. Score and search VODs
        var matchedVODs: [GlobalSearchResultItem] = []
        for (index, v) in scopedVods.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(live: [], vods: [], series: [], counts: [:])
            }
            let normalizedTitle = FuzzySearchEngine.normalize(v.item.title)
            var baseScore = FuzzySearchEngine.score(query: normalizedQuery, target: normalizedTitle)

            let vodCategoryScore = categoryScore(query: normalizedQuery, category: v.item.categoryID)
            if vodCategoryScore > 0 {
                baseScore = max(baseScore ?? 0, vodCategoryScore)
            }

            if let score = baseScore {
                let finalScore = score + (v.is4K && isLookingFor4K ? 150 : 0)
                matchedVODs.append(
                    GlobalSearchResultItem(
                        item: v.item,
                        playlistBadge: v.playlistBadge,
                        is4K: v.is4K,
                        matchedEPGTitle: nil,
                        score: finalScore
                    )
                )
            }
        }
        sortByRelevance(&matchedVODs)

        // 4. Score and search Series
        var matchedSeries: [GlobalSearchResultItem] = []
        for (index, s) in scopedSeries.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(live: [], vods: [], series: [], counts: [:])
            }
            let normalizedTitle = FuzzySearchEngine.normalize(s.item.title)
            var baseScore = FuzzySearchEngine.score(query: normalizedQuery, target: normalizedTitle)

            let seriesCategoryScore = categoryScore(query: normalizedQuery, category: s.item.categoryID)
            if seriesCategoryScore > 0 {
                baseScore = max(baseScore ?? 0, seriesCategoryScore)
            }

            if let score = baseScore {
                let finalScore = score + (s.is4K && isLookingFor4K ? 150 : 0)
                matchedSeries.append(
                    GlobalSearchResultItem(
                        item: s.item,
                        playlistBadge: s.playlistBadge,
                        is4K: s.is4K,
                        matchedEPGTitle: nil,
                        score: finalScore
                    )
                )
            }
        }
        sortByRelevance(&matchedSeries)

        // 5. Calculate 4K and EPG totals across all results
        let uhdChannelsCount = matchedChannels.filter(\.is4K).count
        let uhdVodsCount = matchedVODs.filter(\.is4K).count
        let uhdSeriesCount = matchedSeries.filter(\.is4K).count
        let totalUHDCount = uhdChannelsCount + uhdVodsCount + uhdSeriesCount

        let epgChannelsCount = matchedChannels.filter { $0.matchedEPGTitle != nil || $0.item.epgChannelID != nil }.count

        let counts: [SearchFeature.SearchFilter: Int] = [
            .all: matchedChannels.count + matchedVODs.count + matchedSeries.count,
            .live: matchedChannels.count,
            .vod: matchedVODs.count,
            .series: matchedSeries.count,
            .uhd4k: totalUHDCount,
            .epgMatches: epgChannelsCount,
        ]

        // 6. Apply Filter Selection
        let finalLive: [GlobalSearchResultItem]
        let finalVODs: [GlobalSearchResultItem]
        let finalSeries: [GlobalSearchResultItem]

        switch filter {
        case .all:
            finalLive = Array(matchedChannels.prefix(limitPerCategory))
            finalVODs = Array(matchedVODs.prefix(limitPerCategory))
            finalSeries = Array(matchedSeries.prefix(limitPerCategory))

        case .live:
            finalLive = Array(matchedChannels.prefix(limitPerCategory))
            finalVODs = []
            finalSeries = []

        case .vod:
            finalLive = []
            finalVODs = Array(matchedVODs.prefix(limitPerCategory))
            finalSeries = []

        case .series:
            finalLive = []
            finalVODs = []
            finalSeries = Array(matchedSeries.prefix(limitPerCategory))

        case .uhd4k:
            finalLive = Array(matchedChannels.filter(\.is4K).prefix(limitPerCategory))
            finalVODs = Array(matchedVODs.filter(\.is4K).prefix(limitPerCategory))
            finalSeries = Array(matchedSeries.filter(\.is4K).prefix(limitPerCategory))

        case .epgMatches:
            finalLive = Array(matchedChannels.filter { $0.matchedEPGTitle != nil || $0.item.epgChannelID != nil }.prefix(limitPerCategory))
            finalVODs = []
            finalSeries = []
        }

        return SearchResultOutput(
            live: finalLive,
            vods: finalVODs,
            series: finalSeries,
            counts: counts
        )
    }

    private static func categoryScore(query: String, category: String?) -> Int {
        guard
            let category,
            let score = FuzzySearchEngine.score(query: query, target: FuzzySearchEngine.normalize(category))
        else { return 0 }
        return min(score / 4, 100)
    }

    private static func sortByRelevance(_ results: inout [GlobalSearchResultItem]) {
        results.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            let titleOrder = lhs.item.title.localizedStandardCompare(rhs.item.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            if lhs.playlistBadge.id != rhs.playlistBadge.id {
                return lhs.playlistBadge.id < rhs.playlistBadge.id
            }
            return lhs.item.id < rhs.item.id
        }
    }
}
