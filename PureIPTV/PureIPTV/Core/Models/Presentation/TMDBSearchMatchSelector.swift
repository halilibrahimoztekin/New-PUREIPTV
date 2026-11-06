import Foundation

/// Selects only a high-confidence TMDB result; uncertain searches stay available
/// in the existing manual match picker instead of attaching the wrong artwork.
enum TMDBSearchMatchSelector {
    static func bestMatch(
        in results: [TMDBMovieSearchResultDTO],
        providerTitle: String,
        providerReleaseDate: String?
    ) -> TMDBMovieSearchResultDTO? {
        let providerTitles = normalizedProviderTitles(providerTitle)
        guard !providerTitles.isEmpty else { return nil }

        let providerYear = yearPrefix(providerReleaseDate)
        let ranked = results.compactMap { result -> (TMDBMovieSearchResultDTO, Int)? in
            let primaryTitle = normalize(result.title ?? result.name ?? "")
            let originalTitle = normalize(result.originalTitle ?? result.originalName ?? "")
            let score: Int
            if providerTitles.contains(primaryTitle) {
                score = 100
            } else if providerTitles.contains(originalTitle) {
                score = 90
            } else {
                return nil
            }

            let candidateYear = yearPrefix(result.releaseDate ?? result.firstAirDate)
            let yearScore = if let providerYear, let candidateYear {
                candidateYear == providerYear ? 20 : -5
            } else {
                0
            }
            return (result, score + yearScore)
        }

        guard let highestScore = ranked.map(\.1).max() else { return nil }
        let bestCandidates = ranked.filter { $0.1 == highestScore }
        // TMDB returns results in relevance order. Once candidates have an exact
        // normalized title match and the same title/year score, preserve that order.
        guard let firstBestCandidate = bestCandidates.first else { return nil }
        return firstBestCandidate.0
    }

    private static func normalize(_ value: String) -> String {
        value
            // Turkish dotless i is not removed as a diacritic by Foundation's
            // en_US_POSIX folding, but IPTV feeds commonly transliterate it.
            .replacingOccurrences(of: "ı", with: "i")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .filter { $0.isLetter || $0.isNumber }
    }

    private static func normalizedProviderTitles(_ value: String) -> Set<String> {
        let delimiters = [" - ", " – ", " — ", ": ", " | "]
        var baseTitle = value
        for delimiter in delimiters {
            if let range = baseTitle.range(of: delimiter) {
                baseTitle = String(baseTitle[..<range.lowerBound])
                break
            }
        }

        return [value.cleanedForTMDBSearch(), baseTitle.cleanedForTMDBSearch()]
            .map(normalize)
            .filter { !$0.isEmpty }
            .reduce(into: Set<String>()) { $0.insert($1) }
    }

    private static func yearPrefix(_ value: String?) -> String? {
        guard let value else { return nil }
        let year = String(value.prefix(4))
        return year.count == 4 && year.allSatisfy(\.isNumber) ? year : nil
    }
}
