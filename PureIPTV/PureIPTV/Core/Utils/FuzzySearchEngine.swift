import Foundation

/// Fast, thread-safe fuzzy search and relevance ranking engine.
/// Optimized for large catalogs (10,000 - 50,000+ items) without blocking the MainActor.
public nonisolated enum FuzzySearchEngine: Sendable {
    /// Normalizes case, diacritics, punctuation, and whitespace for consistent title matching.
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

        let folded = str
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US"))
        var normalized = String.UnicodeScalarView()
        var pendingSpace = false
        for scalar in folded.unicodeScalars {
            if CharacterSet.alphanumerics.contains(scalar) {
                if pendingSpace, !normalized.isEmpty {
                    normalized.append(" ")
                }
                normalized.append(scalar)
                pendingSpace = false
            } else {
                pendingSpace = true
            }
        }
        return String(normalized)
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

        let compactQuery = query.filter { !$0.isWhitespace }
        let compactTarget = target.filter { !$0.isWhitespace }
        if !compactQuery.isEmpty, compactTarget == compactQuery {
            return 950
        }
        if !compactQuery.isEmpty, compactTarget.hasPrefix(compactQuery) {
            return 760 - min(compactTarget.count - compactQuery.count, 200)
        }

        // 3. Tokenize both query and target (words separated by spaces, punctuation, brackets)
        let queryTokens = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        guard !queryTokens.isEmpty else { return nil }

        let targetTokens = target.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        // If query is a single short token (< 3 chars), require either target prefix or word prefix
        if queryTokens.count == 1, query.count < 3 {
            let single = queryTokens[0]
            if let wordIndex = targetTokens.firstIndex(where: { $0.hasPrefix(single) }) {
                return 600 - (wordIndex * 20)
            }
            return nil
        }

        // Match each query term to a distinct target term. Prefer constrained
        // terms first so a broad prefix cannot consume the only exact match for
        // another query term.
        var candidatesByQuery: [[(targetIndex: Int, score: Int)]] = []
        candidatesByQuery.reserveCapacity(queryTokens.count)
        for qToken in queryTokens {
            var candidates: [(targetIndex: Int, score: Int)] = []
            for (index, tToken) in targetTokens.enumerated() {
                if tToken == qToken {
                    candidates.append((index, 150 - min(index * 10, 50)))
                } else if tToken.hasPrefix(qToken) {
                    candidates.append((index, 120 - min(index * 10, 50)))
                } else if tToken.contains(qToken) {
                    candidates.append((index, 60 - min(index * 5, 30)))
                }
            }
            candidates.sort {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.targetIndex < $1.targetIndex
            }
            candidatesByQuery.append(candidates)
        }

        let queryOrder = queryTokens.indices.sorted {
            if candidatesByQuery[$0].count != candidatesByQuery[$1].count {
                return candidatesByQuery[$0].count < candidatesByQuery[$1].count
            }
            if queryTokens[$0].count != queryTokens[$1].count {
                return queryTokens[$0].count > queryTokens[$1].count
            }
            if queryTokens[$0] != queryTokens[$1] {
                return queryTokens[$0] < queryTokens[$1]
            }
            return $0 < $1
        }
        var assignedTargets = Set<Int>()
        var matchedIndexes = [Int?](repeating: nil, count: queryTokens.count)
        var matchedScores = [Int](repeating: 0, count: queryTokens.count)
        for queryIndex in queryOrder {
            guard let candidate = candidatesByQuery[queryIndex].first(where: { !assignedTargets.contains($0.targetIndex) }) else {
                continue
            }
            assignedTargets.insert(candidate.targetIndex)
            matchedIndexes[queryIndex] = candidate.targetIndex
            matchedScores[queryIndex] = candidate.score
        }

        let unmatchedQueryIndexes = queryTokens.indices.filter { matchedIndexes[$0] == nil }
        if unmatchedQueryIndexes.count == 1 {
            let queryIndex = unmatchedQueryIndexes[0]
            let token = queryTokens[queryIndex]
            if (3 ... 32).contains(token.count) {
                let maximumDistance = token.count <= 4 ? 1 : 2
                var bestFuzzyMatch: (targetIndex: Int, distance: Int)?
                for (targetIndex, targetToken) in targetTokens.enumerated() where !assignedTargets.contains(targetIndex) {
                    guard abs(targetToken.count - token.count) <= maximumDistance,
                          let distance = boundedLevenshteinDistance(
                              between: token,
                              and: targetToken,
                              maximumDistance: maximumDistance
                          )
                    else { continue }
                    let shouldReplace: Bool = if let currentBest = bestFuzzyMatch {
                        distance < currentBest.distance
                            || (distance == currentBest.distance && targetIndex < currentBest.targetIndex)
                    } else {
                        true
                    }
                    if shouldReplace {
                        bestFuzzyMatch = (targetIndex, distance)
                    }
                }
                if let bestFuzzyMatch {
                    matchedIndexes[queryIndex] = bestFuzzyMatch.targetIndex
                    matchedScores[queryIndex] = 90 - bestFuzzyMatch.distance * 25
                    assignedTargets.insert(bestFuzzyMatch.targetIndex)
                }
            }
        }

        guard matchedIndexes.allSatisfy({ $0 != nil }) else {
            // Keep the legacy whole-query substring fallback for unusual input
            // that tokenization cannot otherwise represent.
            return target.contains(query) ? 200 : nil
        }

        var totalScore = 300 + matchedScores.reduce(0, +)
        if target.contains(query) {
            totalScore += 200
        }
        let positions = matchedIndexes.compactMap(\.self)
        if zip(positions, positions.dropFirst()).allSatisfy({ pair in pair.0 < pair.1 }) {
            totalScore += 40
        }
        if let first = positions.min(), let last = positions.max() {
            let extraGap = max(0, last - first + 1 - queryTokens.count)
            totalScore += max(0, 60 - extraGap * 15)
        }
        return totalScore
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
