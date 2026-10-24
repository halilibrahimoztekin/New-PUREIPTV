import Foundation

// MARK: - Smart Recommendation Engine (Madde #8 & #42)

/// Production-grade recommendation engine based on user watch history and favorited content.
/// Performs collaborative and content-based scoring:
/// - Category Affinity (weighted by watch completion ratio and recency)
/// - High IMDb Rating weighting
/// - Deduplication against completed movies (watched >= 85%)
/// - Catalog Diversity (prevents single-category saturation)
public enum SmartRecommendationEngine: Sendable {
    public enum Reason: String, Codable, Sendable {
        case watchHistory
        case favorites
        case highlyRated
        case recentlyAdded

        public var title: String {
            switch self {
            case .watchHistory: "İzleme geçmişine göre".localized
            case .favorites: "Favorilerine göre".localized
            case .highlyRated: "Yüksek puanlı".localized
            case .recentlyAdded: "Yeni eklenen".localized
            }
        }
    }

    public struct Recommendation: Equatable, Sendable, Identifiable {
        public let item: MediaModels.Item
        public let reason: Reason?

        public nonisolated var id: String {
            item.id
        }

        public nonisolated init(item: MediaModels.Item, reason: Reason?) {
            self.item = item
            self.reason = reason
        }
    }

    /// Generates a concise explanation alongside each item, based on the scoring signal that actually contributed.
    public nonisolated static func recommendations(
        from candidates: [MediaModels.Item],
        history: [WatchHistoryItem],
        favorites: [FavoriteItem],
        limit: Int = 14
    ) -> [Recommendation] {
        var candidateIDs = Set<String>()
        let uniqueCandidates = candidates.filter { candidateIDs.insert($0.id).inserted }
        guard !uniqueCandidates.isEmpty else { return [] }

        var historyCategoryScores: [String: Double] = [:]
        var favoriteCategoryScores: [String: Double] = [:]
        var watchedIDs = Set<String>()
        var completedIDs = Set<String>()
        let now = Date()
        let candidatesByID = Dictionary(uniqueCandidates.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })

        for (index, item) in history.enumerated() {
            if index.isMultiple(of: 64), Task.isCancelled {
                return []
            }
            watchedIDs.insert(item.id)
            let ratio: Double = if item.duration > 0 {
                min(1.0, max(0.0, item.progress / item.duration))
            } else {
                0.5
            }
            if ratio >= 0.85 {
                completedIDs.insert(item.id)
            }
            let daysSinceWatch = max(1.0, now.timeIntervalSince(item.lastWatchedAt) / 86400.0)
            let recencyWeight = max(0.4, 1.0 / (1.0 + (daysSinceWatch * 0.1)))
            if let matchingCandidate = candidatesByID[item.id] {
                let watchWeight = ratio > 0.5 ? 3.0 : 1.5
                historyCategoryScores[matchingCandidate.categoryID, default: 0.0] += watchWeight * recencyWeight
            }
        }

        for (index, favorite) in favorites.enumerated() where favorite.type.lowercased() == "vod" {
            if index.isMultiple(of: 64), Task.isCancelled {
                return []
            }
            if let matchingCandidate = candidatesByID[favorite.id] {
                favoriteCategoryScores[matchingCandidate.categoryID, default: 0.0] += 2.5
            }
        }

        let availablePool = uniqueCandidates.filter { !completedIDs.contains($0.id) }
        if historyCategoryScores.isEmpty, favoriteCategoryScores.isEmpty {
            return topRatedDiverseRecommendations(from: availablePool, limit: limit)
        }

        struct ScoredItem {
            let recommendation: Recommendation
            let score: Double
        }

        var scoredItems: [ScoredItem] = []
        for (index, candidate) in availablePool.enumerated() {
            if index.isMultiple(of: 64), Task.isCancelled {
                return []
            }
            let historyAffinity = historyCategoryScores[candidate.categoryID] ?? 0
            let favoriteAffinity = favoriteCategoryScores[candidate.categoryID] ?? 0
            let categoryAffinity = historyAffinity + favoriteAffinity
            let rating = candidate.rating.flatMap { $0 > 0 ? $0 : nil }
            let ratingContribution = rating.map { $0 * 1.5 + ($0 >= 7.5 ? 3.0 : 0) } ?? 4.5
            let historyContribution = historyAffinity * 4
            let favoriteContribution = favoriteAffinity * 4
            let nowFreshnessContribution: Double
            if let added = candidate.addedDate {
                let daysOld = now.timeIntervalSince(added) / 86400.0
                if daysOld < 30 {
                    nowFreshnessContribution = 3.0
                } else if daysOld < 90 {
                    nowFreshnessContribution = 1.5
                } else {
                    nowFreshnessContribution = 0
                }
            } else {
                nowFreshnessContribution = 0
            }
            let reason: Reason? = if historyContribution > 0,
                                     historyContribution >= favoriteContribution,
                                     historyContribution >= ratingContribution,
                                     historyContribution >= nowFreshnessContribution
            {
                .watchHistory
            } else if favoriteContribution > 0,
                      favoriteContribution >= ratingContribution,
                      favoriteContribution >= nowFreshnessContribution
            {
                .favorites
            } else if (rating ?? 0) >= 7.5, ratingContribution >= nowFreshnessContribution {
                .highlyRated
            } else if nowFreshnessContribution > 0 {
                .recentlyAdded
            } else {
                nil
            }
            var score = categoryAffinity * 4 + ratingContribution + nowFreshnessContribution
            if watchedIDs.contains(candidate.id) {
                score *= 0.5
            }
            scoredItems.append(ScoredItem(
                recommendation: Recommendation(item: candidate, reason: reason),
                score: score
            ))
        }

        let sorted = scoredItems.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.recommendation.id.localizedStandardCompare($1.recommendation.id) == .orderedAscending
        }
        var result: [Recommendation] = []
        var categoryUsage: [String: Int] = [:]
        for scored in sorted {
            let category = scored.recommendation.item.categoryID
            guard categoryUsage[category, default: 0] < 3 else { continue }
            result.append(scored.recommendation)
            categoryUsage[category, default: 0] += 1
            if result.count >= limit {
                break
            }
        }
        if result.count < limit {
            for scored in sorted where !result.contains(where: { $0.id == scored.recommendation.id }) {
                result.append(scored.recommendation)
                if result.count >= limit {
                    break
                }
            }
        }
        return result
    }

    /// Generates tailored VOD recommendations.
    public nonisolated static func recommendVODs(
        from candidates: [MediaModels.Item],
        history: [WatchHistoryItem],
        favorites: [FavoriteItem],
        limit: Int = 14
    ) -> [MediaModels.Item] {
        recommendations(from: candidates, history: history, favorites: favorites, limit: limit).map(\.item)
    }

    /// Fallback ranking for new users: high ratings and diversity.
    private nonisolated static func topRatedDiverseRecommendations(from candidates: [MediaModels.Item], limit: Int) -> [Recommendation] {
        let sorted = candidates.sorted {
            let r0 = $0.rating ?? 0.0
            let r1 = $1.rating ?? 0.0
            if r0 != r1 {
                return r0 > r1
            }
            let d0 = $0.addedDate ?? Date.distantPast
            let d1 = $1.addedDate ?? Date.distantPast
            return d0 > d1
        }

        var result: [Recommendation] = []
        var categoryUsage: [String: Int] = [:]

        for (index, item) in sorted.enumerated() {
            if index.isMultiple(of: 64), Task.isCancelled {
                return []
            }
            let cat = item.categoryID
            let count = categoryUsage[cat, default: 0]
            if count < 3 {
                let daysOld = item.addedDate.map { Date().timeIntervalSince($0) / 86400 } ?? .infinity
                let reason: Reason? = if (item.rating ?? 0) >= 7.5 {
                    .highlyRated
                } else if daysOld < 90 {
                    .recentlyAdded
                } else {
                    nil
                }
                result.append(Recommendation(item: item, reason: reason))
                categoryUsage[cat] = count + 1
            }
            if result.count >= limit {
                break
            }
        }

        return result
    }
}
