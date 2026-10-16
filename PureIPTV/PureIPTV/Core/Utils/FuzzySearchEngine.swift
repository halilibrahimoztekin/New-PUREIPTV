import Foundation

/// Fast, thread-safe fuzzy search and relevance ranking engine.
/// Optimized for large catalogs (10,000 - 50,000+ items) without blocking the MainActor.
public enum FuzzySearchEngine: Sendable {
    /// Normalizes a string for fast case-insensitive, diacritic-insensitive matching across all locales.
    public static func normalize(_ text: String) -> String {
        var str = text.lowercased()
        if str.contains("ı") {
            str = str.replacingOccurrences(of: "ı", with: "i")
        }
        if str.contains("ş") {
            str = str.replacingOccurrences(of: "ş", with: "s")
        }
        if str.contains("ğ") {
            str = str.replacingOccurrences(of: "ğ", with: "g")
        }
        if str.contains("ü") {
            str = str.replacingOccurrences(of: "ü", with: "u")
        }
        if str.contains("ö") {
            str = str.replacingOccurrences(of: "ö", with: "o")
        }
        if str.contains("ç") {
            str = str.replacingOccurrences(of: "ç", with: "c")
        }

        return str
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Evaluates match score between normalized query and normalized target.
    /// Higher scores represent higher relevance. Returns `nil` if not matching.
    public static func score(query: String, target: String) -> Int? {
        guard !query.isEmpty, !target.isEmpty else { return nil }

        // 1. Exact match (highest priority)
        if target == query {
            return 1000
        }

        // 2. Exact prefix match
        if target.hasPrefix(query) {
            let lengthPenalty = min(target.count - query.count, 200)
            return 800 - lengthPenalty
        }

        // 3. Tokenize both query and target (words separated by spaces, punctuation, brackets)
        let queryTokens = query.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        guard !queryTokens.isEmpty else { return nil }

        let targetTokens = target.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }

        // If query is a single short token (< 3 chars), require either target prefix or word prefix
        if queryTokens.count == 1, query.count < 3 {
            let single = queryTokens[0]
            if let wordIndex = targetTokens.firstIndex(where: { $0.hasPrefix(single) }) {
                return 600 - (wordIndex * 20)
            }
            if target.contains(single) {
                return 250
            }
            return nil
        }

        // 4. Multi-token scoring (e.g. "bein 1" matches "beIN SPORTS 1 HD")
        var totalScore = 0
        var matchedTokensCount = 0

        for qToken in queryTokens {
            var bestTokenScore = 0
            for (index, tToken) in targetTokens.enumerated() {
                if tToken == qToken {
                    // Exact word match
                    bestTokenScore = max(bestTokenScore, 150 - min(index * 10, 50))
                } else if tToken.hasPrefix(qToken) {
                    // Word prefix match
                    bestTokenScore = max(bestTokenScore, 120 - min(index * 10, 50))
                } else if tToken.contains(qToken) {
                    // Substring in word
                    bestTokenScore = max(bestTokenScore, 60 - min(index * 5, 30))
                }
            }

            if bestTokenScore > 0 {
                totalScore += bestTokenScore
                matchedTokensCount += 1
            }
        }

        // If all query tokens matched, award a strong multi-match bonus
        if matchedTokensCount == queryTokens.count {
            // Contiguous substring sequence bonus
            if target.contains(query) {
                totalScore += 200
            }
            return 300 + totalScore
        }

        // 5. Fallback substring match if query isn't broken up
        if target.contains(query) {
            return 200
        }

        return nil
    }

    /// Performs fuzzy search on a collection of MediaModels.Item, ranking by relevance.
    /// Returns at most `limit` items, preventing SwiftUI rendering stalls.
    public static func searchItems(
        _ items: [MediaModels.Item],
        query: String,
        limit: Int = 100
    ) -> [MediaModels.Item] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalizedQuery = normalize(trimmed)
        var scoredResults: [(item: MediaModels.Item, score: Int)] = []
        scoredResults.reserveCapacity(min(items.count, limit * 2))

        for item in items {
            let normalizedTitle = normalize(item.title)
            if let score = score(query: normalizedQuery, target: normalizedTitle) {
                scoredResults.append((item, score))
            }
        }

        // Sort by score descending, then shorter title length, then alphabetical
        scoredResults.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            if lhs.item.title.count != rhs.item.title.count {
                return lhs.item.title.count < rhs.item.title.count
            }
            return lhs.item.title.localizedStandardCompare(rhs.item.title) == .orderedAscending
        }

        if scoredResults.count > limit {
            return Array(scoredResults.prefix(limit).map(\.item))
        }
        return scoredResults.map(\.item)
    }
}
