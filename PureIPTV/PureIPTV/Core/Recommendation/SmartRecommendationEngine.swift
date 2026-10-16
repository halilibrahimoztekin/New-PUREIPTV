import Foundation

// MARK: - Smart Recommendation Engine (Madde #8 & #42)

/// Production-grade recommendation engine based on user watch history and favorited content.
/// Performs collaborative and content-based scoring:
/// - Category Affinity (weighted by watch completion ratio and recency)
/// - High IMDb Rating weighting
/// - Deduplication against completed movies (watched >= 85%)
/// - Catalog Diversity (prevents single-category saturation)
public enum SmartRecommendationEngine: Sendable {
    /// Generates tailored VOD recommendations.
    public static func recommendVODs(
        from candidates: [MediaModels.Item],
        history: [WatchHistoryItem],
        favorites: [FavoriteItem],
        limit: Int = 14
    ) -> [MediaModels.Item] {
        guard !candidates.isEmpty else { return [] }

        // 1. Calculate Category Affinity Scores
        var categoryScores: [String: Double] = [:]
        var watchedIDs = Set<String>()
        var completedIDs = Set<String>()

        let now = Date()

        for item in history {
            watchedIDs.insert(item.id)

            // Calculate watch completion ratio
            let ratio: Double = if item.duration > 0 {
                min(1.0, max(0.0, item.progress / item.duration))
            } else {
                0.5
            }

            // If watched >= 85%, mark as completed to avoid recommending the same movie again
            if ratio >= 0.85 {
                completedIDs.insert(item.id)
            }

            // Recency decay: items watched in the last 7 days have higher affinity weight
            let daysSinceWatch = max(1.0, now.timeIntervalSince(item.lastWatchedAt) / 86400.0)
            let recencyWeight = max(0.4, 1.0 / (1.0 + (daysSinceWatch * 0.1)))

            // Find matching VOD category if present
            if let matchingCandidate = candidates.first(where: { $0.id == item.id }) {
                let catID = matchingCandidate.categoryID
                let watchWeight = ratio > 0.5 ? 3.0 : 1.5
                categoryScores[catID, default: 0.0] += (watchWeight * recencyWeight)
            }
        }

        // Add Favorite affinities
        for fav in favorites where fav.type.lowercased() == "vod" {
            if let matchingCandidate = candidates.first(where: { $0.id == fav.id }) {
                let catID = matchingCandidate.categoryID
                categoryScores[catID, default: 0.0] += 2.5
            }
        }

        // 2. Filter out already completed movies
        let availablePool = candidates.filter { !completedIDs.contains($0.id) }

        // If user has zero history and zero favorites, recommend top-rated & newest items with diversity
        if categoryScores.isEmpty {
            return topRatedDiverseVODs(from: availablePool, limit: limit)
        }

        // 3. Score candidates based on Category Affinity, Rating, and Freshness
        struct ScoredItem {
            let item: MediaModels.Item
            let score: Double
        }

        var scoredItems: [ScoredItem] = []

        for candidate in availablePool {
            var itemScore = 0.0

            // Category match bonus
            let catScore = categoryScores[candidate.categoryID] ?? 0.0
            itemScore += (catScore * 4.0)

            // Rating score (0.0 ... 10.0 scale)
            if let rating = candidate.rating, rating > 0 {
                itemScore += (rating * 1.5)
                if rating >= 7.5 {
                    itemScore += 3.0 // High quality critically acclaimed bonus
                }
            } else {
                itemScore += 4.5 // Baseline for unrated
            }

            // Freshness / Recency score
            if let added = candidate.addedDate {
                let daysOld = now.timeIntervalSince(added) / 86400.0
                if daysOld < 30 {
                    itemScore += 3.0
                } else if daysOld < 90 {
                    itemScore += 1.5
                }
            }

            // Down-rank if already watched recently (partially watched)
            if watchedIDs.contains(candidate.id) {
                itemScore *= 0.5
            }

            scoredItems.append(ScoredItem(item: candidate, score: itemScore))
        }

        // Sort descending by score
        let sortedCandidates = scoredItems.sorted { $0.score > $1.score }

        // 4. Ensure diversity: max 3 items from the exact same category
        var result: [MediaModels.Item] = []
        var categoryUsage: [String: Int] = [:]

        for scored in sortedCandidates {
            let cat = scored.item.categoryID
            let currentCount = categoryUsage[cat, default: 0]
            if currentCount < 3 {
                result.append(scored.item)
                categoryUsage[cat] = currentCount + 1
            }
            if result.count >= limit {
                break
            }
        }

        // Fallback fill if strict diversity didn't reach limit
        if result.count < limit {
            for scored in sortedCandidates {
                if !result.contains(where: { $0.id == scored.item.id }) {
                    result.append(scored.item)
                }
                if result.count >= limit {
                    break
                }
            }
        }

        return result
    }

    /// Fallback ranking for new users: high ratings and diversity.
    private static func topRatedDiverseVODs(from candidates: [MediaModels.Item], limit: Int) -> [MediaModels.Item] {
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

        var result: [MediaModels.Item] = []
        var categoryUsage: [String: Int] = [:]

        for item in sorted {
            let cat = item.categoryID
            let count = categoryUsage[cat, default: 0]
            if count < 3 {
                result.append(item)
                categoryUsage[cat] = count + 1
            }
            if result.count >= limit {
                break
            }
        }

        return result
    }
}
