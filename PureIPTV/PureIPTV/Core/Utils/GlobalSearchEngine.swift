import Foundation

// MARK: - Global Search Engine

/// Ultra-fast, thread-safe cross-playlist search engine with instant filter badges and EPG matching.
public nonisolated enum GlobalSearchEngine: Sendable {
    private struct SearchIntent: Sendable {
        var terms: String
        var matchTerms: [String]
        var itemType: MediaModels.ItemType?
        var releaseYear: Int?
        var requires4K = false

        init(query: String) {
            var words = query.split(whereSeparator: \.isWhitespace).map(String.init)
            var detectedType: MediaModels.ItemType?
            var detectedYear: Int?
            var detected4K = false
            let currentYear = Calendar(identifier: .gregorian).component(.year, from: Date())
            words.removeAll { word in
                let token = FuzzySearchEngine.normalize(word).trimmingCharacters(in: .punctuationCharacters)
                if ["movie", "movies", "film", "films", "filmler", "sinema"].contains(token) {
                    detectedType = .vod
                    return true
                }
                if ["series", "serie", "dizi", "diziler", "show", "shows"].contains(token) {
                    detectedType = .series
                    return true
                }
                if ["live", "tv", "canli", "kanal", "kanallar"].contains(token) {
                    detectedType = .live
                    return true
                }
                if ["4k", "uhd"].contains(token) {
                    detected4K = true
                    return true
                }
                if token.count == 4, let year = Int(token), (1900 ... currentYear + 1).contains(year) {
                    detectedYear = year
                    return true
                }
                return false
            }
            terms = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
            matchTerms = words
            itemType = detectedType
            releaseYear = detectedYear
            requires4K = detected4K
        }
    }

    public struct SearchResultOutput: Sendable {
        public let categories: [CategorySearchResultItem]
        public let live: [GlobalSearchResultItem]
        public let vods: [GlobalSearchResultItem]
        public let series: [GlobalSearchResultItem]
        public let counts: [SearchFeature.SearchFilter: Int]

        public init(
            categories: [CategorySearchResultItem] = [],
            live: [GlobalSearchResultItem],
            vods: [GlobalSearchResultItem],
            series: [GlobalSearchResultItem],
            counts: [SearchFeature.SearchFilter: Int]
        ) {
            self.categories = categories
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
        categories: [CategorySearchResultItem] = [],
        limitPerCategory: Int = 100,
        isCancelled: @Sendable () -> Bool = { false }
    ) -> SearchResultOutput {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return SearchResultOutput(categories: [], live: [], vods: [], series: [], counts: [:])
        }

        let intent = SearchIntent(query: trimmed)
        let normalizedQuery = FuzzySearchEngine.normalize(intent.terms)
        let hasTextQuery = !normalizedQuery.isEmpty
        let isLookingFor4K = intent.requires4K

        // 1. Filter by selected playlist if specified
        let selectedSourceID = selectedPlaylistID.map(PlaylistSourceBadge.sourceID(for:))
        let scopedChannels = selectedPlaylistID == nil ? channels : channels.filter {
            $0.playlistBadge.id == selectedSourceID
        }
        let scopedVods = selectedPlaylistID == nil ? vods : vods.filter {
            $0.playlistBadge.id == selectedSourceID
        }
        let scopedSeries = selectedPlaylistID == nil ? series : series.filter {
            $0.playlistBadge.id == selectedSourceID
        }
        let scopedCategories = selectedPlaylistID == nil ? categories : categories.filter {
            $0.playlistBadge.id == selectedSourceID
        }

        // 2. Score and search Channels
        var matchedChannels: [GlobalSearchResultItem] = []
        for (index, ch) in scopedChannels.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(categories: [], live: [], vods: [], series: [], counts: [:])
            }
            guard intent.itemType == nil || intent.itemType == .live else { continue }
            guard !intent.requires4K || ch.is4K else { continue }
            let titleMatch = hasTextQuery ? bestTitleMatch(query: normalizedQuery, item: ch.item) : nil
            var baseScore = titleMatch?.score
            if !hasTextQuery {
                baseScore = 1
            }
            var searchMatch: SearchMatchDescription?
            if let titleMatch {
                searchMatch = SearchMatchDescription(
                    field: .channel,
                    sourceText: titleMatch.title,
                    queryTerms: intent.matchTerms
                )
            }

            // EPG metadata is searchable with a lower field weight than a title match.
            let epgMatchTitle: String? = ch.matchedEPGTitle
            if hasTextQuery, let epgMatchTitle {
                let epgNorm = FuzzySearchEngine.normalize(epgMatchTitle)
                if let epgScore = FuzzySearchEngine.score(query: normalizedQuery, target: epgNorm) {
                    let weightedEPGScore = min(epgScore / 3, 220)
                    if weightedEPGScore > (baseScore ?? 0) {
                        searchMatch = SearchMatchDescription(
                            field: .program,
                            sourceText: epgMatchTitle,
                            queryTerms: intent.matchTerms
                        )
                    }
                    baseScore = max(baseScore ?? 0, weightedEPGScore)
                }
            }
            let channelCategoryScore = hasTextQuery ? categoryScore(query: normalizedQuery, category: ch.item.categoryID) : 0
            if channelCategoryScore > 0 {
                if channelCategoryScore > (baseScore ?? 0) {
                    searchMatch = SearchMatchDescription(
                        field: .category,
                        sourceText: ch.item.categoryID,
                        queryTerms: intent.matchTerms
                    )
                }
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
                        score: finalScore,
                        searchMatch: searchMatch
                    )
                )
            }
        }
        sortByRelevance(&matchedChannels)

        // 3. Score and search VODs
        var matchedVODs: [GlobalSearchResultItem] = []
        for (index, v) in scopedVods.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(categories: [], live: [], vods: [], series: [], counts: [:])
            }
            guard intent.itemType == nil || intent.itemType == .vod else { continue }
            guard !intent.requires4K || v.is4K else { continue }
            guard intent.releaseYear == nil || Int((v.item.releaseDate ?? "").prefix(4)) == intent.releaseYear else { continue }
            let titleMatch = hasTextQuery ? bestTitleMatch(query: normalizedQuery, item: v.item) : nil
            var baseScore = titleMatch?.score
            if !hasTextQuery {
                baseScore = 1
            }
            var searchMatch: SearchMatchDescription?
            if let titleMatch {
                searchMatch = SearchMatchDescription(field: .title, sourceText: titleMatch.title, queryTerms: intent.matchTerms)
            }

            let vodCategoryScore = hasTextQuery ? categoryScore(query: normalizedQuery, category: v.item.categoryID) : 0
            if vodCategoryScore > 0 {
                if vodCategoryScore > (baseScore ?? 0) {
                    searchMatch = SearchMatchDescription(field: .category, sourceText: v.item.categoryID, queryTerms: intent.matchTerms)
                }
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
                        score: finalScore,
                        searchMatch: searchMatch
                    )
                )
            }
        }
        sortByRelevance(&matchedVODs)

        // 4. Score and search Series
        var matchedSeries: [GlobalSearchResultItem] = []
        for (index, s) in scopedSeries.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(categories: [], live: [], vods: [], series: [], counts: [:])
            }
            guard intent.itemType == nil || intent.itemType == .series else { continue }
            guard !intent.requires4K || s.is4K else { continue }
            guard intent.releaseYear == nil || Int((s.item.releaseDate ?? "").prefix(4)) == intent.releaseYear else { continue }
            let titleMatch = hasTextQuery ? bestTitleMatch(query: normalizedQuery, item: s.item) : nil
            var baseScore = titleMatch?.score
            if !hasTextQuery {
                baseScore = 1
            }
            var searchMatch: SearchMatchDescription?
            if let titleMatch {
                searchMatch = SearchMatchDescription(field: .title, sourceText: titleMatch.title, queryTerms: intent.matchTerms)
            }

            let seriesCategoryScore = hasTextQuery ? categoryScore(query: normalizedQuery, category: s.item.categoryID) : 0
            if seriesCategoryScore > 0 {
                if seriesCategoryScore > (baseScore ?? 0) {
                    searchMatch = SearchMatchDescription(field: .category, sourceText: s.item.categoryID, queryTerms: intent.matchTerms)
                }
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
                        score: finalScore,
                        searchMatch: searchMatch
                    )
                )
            }
        }
        sortByRelevance(&matchedSeries)

        // 5. Score and search Categories
        var matchedCategories: [CategorySearchResultItem] = []
        for (index, cat) in scopedCategories.enumerated() {
            if index.isMultiple(of: 64), isCancelled() {
                return SearchResultOutput(categories: [], live: [], vods: [], series: [], counts: [:])
            }
            guard intent.itemType == nil || intent.itemType == cat.type else { continue }
            let catName = cat.category.name
            let normalizedName = FuzzySearchEngine.normalize(catName)
            let baseScore: Int? = if hasTextQuery {
                FuzzySearchEngine.score(query: normalizedQuery, target: normalizedName)
            } else {
                1
            }
            if let score = baseScore {
                matchedCategories.append(
                    CategorySearchResultItem(
                        category: cat.category,
                        type: cat.type,
                        playlistBadge: cat.playlistBadge,
                        playlistID: cat.playlistID,
                        itemCount: cat.itemCount,
                        score: score
                    )
                )
            }
        }
        matchedCategories.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            let nameOrder = lhs.category.name.localizedStandardCompare(rhs.category.name)
            if nameOrder != .orderedSame {
                return nameOrder == .orderedAscending
            }
            if lhs.playlistBadge.id != rhs.playlistBadge.id {
                return lhs.playlistBadge.id < rhs.playlistBadge.id
            }
            return lhs.category.id < rhs.category.id
        }

        // 6. Calculate 4K and EPG totals across all results
        let uhdChannelsCount = matchedChannels.filter(\.is4K).prefix(limitPerCategory).count
        let uhdVodsCount = matchedVODs.filter(\.is4K).prefix(limitPerCategory).count
        let uhdSeriesCount = matchedSeries.filter(\.is4K).prefix(limitPerCategory).count
        let totalUHDCount = uhdChannelsCount + uhdVodsCount + uhdSeriesCount

        let epgChannelsCount = matchedChannels.filter { $0.matchedEPGTitle != nil || $0.item.epgChannelID != nil }.prefix(limitPerCategory).count

        let counts: [SearchFeature.SearchFilter: Int] = [
            .all: min(matchedCategories.count, 20) + min(matchedChannels.count, limitPerCategory) + min(matchedVODs.count, limitPerCategory) + min(matchedSeries.count, limitPerCategory),
            .categories: matchedCategories.count,
            .live: min(matchedChannels.count, limitPerCategory),
            .vod: min(matchedVODs.count, limitPerCategory),
            .series: min(matchedSeries.count, limitPerCategory),
            .uhd4k: totalUHDCount,
            .epgMatches: epgChannelsCount,
            .people: 0,
            .programs: 0,
            .downloads: 0,
        ]

        // 7. Apply Filter Selection
        let finalCategories: [CategorySearchResultItem]
        let finalLive: [GlobalSearchResultItem]
        let finalVODs: [GlobalSearchResultItem]
        let finalSeries: [GlobalSearchResultItem]

        switch filter {
        case .all:
            finalCategories = Array(matchedCategories.prefix(20))
            finalLive = Array(matchedChannels.prefix(limitPerCategory))
            finalVODs = Array(matchedVODs.prefix(limitPerCategory))
            finalSeries = Array(matchedSeries.prefix(limitPerCategory))

        case .categories:
            finalCategories = matchedCategories
            finalLive = []
            finalVODs = []
            finalSeries = []

        case .live:
            finalCategories = []
            finalLive = Array(matchedChannels.prefix(limitPerCategory))
            finalVODs = []
            finalSeries = []

        case .vod:
            finalCategories = []
            finalLive = []
            finalVODs = Array(matchedVODs.prefix(limitPerCategory))
            finalSeries = []

        case .series:
            finalCategories = []
            finalLive = []
            finalVODs = []
            finalSeries = Array(matchedSeries.prefix(limitPerCategory))

        case .uhd4k:
            finalCategories = []
            finalLive = Array(matchedChannels.filter(\.is4K).prefix(limitPerCategory))
            finalVODs = Array(matchedVODs.filter(\.is4K).prefix(limitPerCategory))
            finalSeries = Array(matchedSeries.filter(\.is4K).prefix(limitPerCategory))

        case .epgMatches:
            finalCategories = []
            finalLive = Array(matchedChannels.filter { $0.matchedEPGTitle != nil || $0.item.epgChannelID != nil }.prefix(limitPerCategory))
            finalVODs = []
            finalSeries = []

        case .people, .programs, .downloads:
            finalCategories = []
            finalLive = []
            finalVODs = []
            finalSeries = []
        }

        return SearchResultOutput(
            categories: finalCategories,
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

    private static func bestTitleMatch(
        query: String,
        item: MediaModels.Item
    ) -> (score: Int, title: String)? {
        // Keep the provider title searchable alongside a user-facing title override.
        var bestMatch: (score: Int, title: String)?
        var seenTitles = Set<String>()
        for title in [item.displayTitle, item.title] {
            let normalizedTitle = FuzzySearchEngine.normalize(title)
            guard seenTitles.insert(normalizedTitle).inserted,
                  let score = FuzzySearchEngine.score(query: query, target: normalizedTitle)
            else { continue }
            if score > (bestMatch?.score ?? Int.min) {
                bestMatch = (score, title)
            }
        }
        return bestMatch
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
