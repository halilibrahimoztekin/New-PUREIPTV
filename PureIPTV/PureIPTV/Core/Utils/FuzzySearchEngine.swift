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
            return nil
        }

        // 4. Multi-token scoring (e.g. "bein 1" matches "beIN SPORTS 1 HD")
        var totalScore = 0
        var matchedTokenIndexes: Set<Int> = []

        for qToken in queryTokens {
            var bestTokenScore = 0
            var bestTokenIndex: Int?
            for (index, tToken) in targetTokens.enumerated() {
                guard !matchedTokenIndexes.contains(index) else { continue }
                if tToken == qToken {
                    // Exact word match
                    let candidateScore = 150 - min(index * 10, 50)
                    if candidateScore > bestTokenScore {
                        bestTokenScore = candidateScore
                        bestTokenIndex = index
                    }
                } else if tToken.hasPrefix(qToken) {
                    // Word prefix match
                    let candidateScore = 120 - min(index * 10, 50)
                    if candidateScore > bestTokenScore {
                        bestTokenScore = candidateScore
                        bestTokenIndex = index
                    }
                } else if tToken.contains(qToken) {
                    // Substring in word
                    let candidateScore = 60 - min(index * 5, 30)
                    if candidateScore > bestTokenScore {
                        bestTokenScore = candidateScore
                        bestTokenIndex = index
                    }
                }
            }

            if let bestTokenIndex, bestTokenScore > 0 {
                totalScore += bestTokenScore
                matchedTokenIndexes.insert(bestTokenIndex)
            }
        }

        // If all query tokens matched, award a strong multi-match bonus
        if matchedTokenIndexes.count == queryTokens.count {
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
        if (3 ... 32).contains(query.count) {
            let maxAllowedDistance = query.count <= 4 ? 1 : 2
            // Compare bounded query-sized tokens only. Running full edit distance
            // against an entire channel title needlessly scales with title length.
            for tToken in targetTokens where abs(tToken.count - query.count) <= maxAllowedDistance {
                if let tokenDist = boundedLevenshteinDistance(
                    between: query,
                    and: tToken,
                    maximumDistance: maxAllowedDistance
                ) {
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

    private static func boundedLevenshteinDistance(
        between s1: String,
        and s2: String,
        maximumDistance: Int
    ) -> Int? {
        let a = Array(s1)
        let b = Array(s2)
        let (m, n) = (a.count, b.count)
        guard abs(m - n) <= maximumDistance else { return nil }
        guard m > 0 else { return n <= maximumDistance ? n : nil }
        guard n > 0 else { return m <= maximumDistance ? m : nil }

        let sentinel = maximumDistance + 1
        var previous = [Int](repeating: sentinel, count: n + 1)
        for column in 0 ... min(n, maximumDistance) {
            previous[column] = column
        }

        for row in 1 ... m {
            var current = [Int](repeating: sentinel, count: n + 1)
            if row <= maximumDistance {
                current[0] = row
            }
            let firstColumn = max(1, row - maximumDistance)
            let lastColumn = min(n, row + maximumDistance)
            guard firstColumn <= lastColumn else { return nil }

            for column in firstColumn ... lastColumn {
                let substitutionCost = a[row - 1] == b[column - 1] ? 0 : 1
                current[column] = min(
                    previous[column] + 1,
                    current[column - 1] + 1,
                    previous[column - 1] + substitutionCost
                )
            }
            if current[firstColumn ... lastColumn].min() ?? sentinel > maximumDistance {
                return nil
            }
            previous = current
        }

        return previous[n] <= maximumDistance ? previous[n] : nil
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
        var scoredResults: [(item: T, score: Int, title: String, offset: Int)] = []
        scoredResults.reserveCapacity(min(items.count, limit * 2))

        for (offset, item) in items.enumerated() {
            let title = item[keyPath: titleKeyPath]
            let normalizedTitle = normalize(title)
            if let score = score(query: normalizedQuery, target: normalizedTitle) {
                scoredResults.append((item, score, title, offset))
            }
        }

        // Sort by score descending, then shorter title length, then alphabetical
        scoredResults.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            if lhs.title.count != rhs.title.count {
                return lhs.title.count < rhs.title.count
            }
            let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
            if titleOrder != .orderedSame {
                return titleOrder == .orderedAscending
            }
            return lhs.offset < rhs.offset
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
