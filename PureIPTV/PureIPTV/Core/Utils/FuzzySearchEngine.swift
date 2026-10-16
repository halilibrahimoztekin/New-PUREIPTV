import Foundation

/// Fast, thread-safe fuzzy search and relevance ranking engine.
/// Optimized for large catalogs (10,000 - 50,000+ items) without blocking the MainActor.
public nonisolated enum FuzzySearchEngine: Sendable {
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

        // 6. tvOS Voice Dictation / Levenshtein Distance Match (Madde #62)
        // Helps catch phonetic dictation errors (e.g. "bein" vs "beyin", "spor" vs "spo")
        if query.count >= 3 {
            let maxAllowedDistance = query.count <= 4 ? 1 : 2
            let dist = levenshteinDistance(between: query, and: target)
            if dist <= maxAllowedDistance {
                return 180 - (dist * 40)
            }

            // Word-level Levenshtein check
            for tToken in targetTokens where abs(tToken.count - query.count) <= maxAllowedDistance {
                let tokenDist = levenshteinDistance(between: query, and: tToken)
                if tokenDist <= maxAllowedDistance {
                    return 160 - (tokenDist * 30)
                }
            }
        }

        return nil
    }

    /// Computes Levenshtein Distance for typo and dictation tolerance (Madde #62)
    public static func levenshteinDistance(between s1: String, and s2: String) -> Int {
        let a = Array(s1)
        let b = Array(s2)
        let (m, n) = (a.count, b.count)
        guard m > 0 else { return n }
        guard n > 0 else { return m }

        var prev = Array(0 ... n)
        var curr = [Int](repeating: 0, count: n + 1)

        for i in 1 ... m {
            curr[0] = i
            for j in 1 ... n {
                let cost = a[i - 1] == b[j - 1] ? 0 : 1
                curr[j] = min(
                    prev[j] + 1,
                    curr[j - 1] + 1,
                    prev[j - 1] + cost
                )
            }
            prev = curr
        }
        return prev[n]
    }

    /// Generic fuzzy search on any collection of items with a title keypath, ranking by relevance.
    /// Returns at most `limit` items, preventing SwiftUI rendering stalls.
    public static func search<T: Sendable>(
        _ items: [T],
        titleKeyPath: KeyPath<T, String>,
        query: String,
        limit: Int = 100
    ) -> [T] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let normalizedQuery = normalize(trimmed)
        var scoredResults: [(item: T, score: Int)] = []
        scoredResults.reserveCapacity(min(items.count, limit * 2))

        for item in items {
            let normalizedTitle = normalize(item[keyPath: titleKeyPath])
            if let score = score(query: normalizedQuery, target: normalizedTitle) {
                scoredResults.append((item, score))
            }
        }

        // Sort by score descending, then shorter title length, then alphabetical
        scoredResults.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            let lhsTitle = lhs.item[keyPath: titleKeyPath]
            let rhsTitle = rhs.item[keyPath: titleKeyPath]
            if lhsTitle.count != rhsTitle.count {
                return lhsTitle.count < rhsTitle.count
            }
            return lhsTitle.localizedStandardCompare(rhsTitle) == .orderedAscending
        }

        if scoredResults.count > limit {
            return Array(scoredResults.prefix(limit).map(\.item))
        }
        return scoredResults.map(\.item)
    }

    /// Performs fuzzy search on a collection of MediaModels.Item, ranking by relevance.
    /// Returns at most `limit` items, preventing SwiftUI rendering stalls.
    public static func searchItems(
        _ items: [MediaModels.Item],
        query: String,
        limit: Int = 100
    ) -> [MediaModels.Item] {
        search(items, titleKeyPath: \.title, query: query, limit: limit)
    }
}
