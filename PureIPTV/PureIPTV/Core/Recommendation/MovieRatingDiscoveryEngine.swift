import Foundation

/// Intersects bounded TMDB movie rankings with the active provider catalogue.
/// Provider titles are never sent to TMDB one by one, and TMDB-only titles are
/// never shown as playable recommendations.
public enum MovieRatingDiscoveryEngine: Sendable {
    public struct RankedMovie: Equatable, Identifiable, Sendable {
        public let item: MediaModels.Item
        public let voteAverage: Double
        public let voteCount: Int

        public var id: String {
            item.id
        }

        public init(item: MediaModels.Item, voteAverage: Double, voteCount: Int) {
            self.item = item
            self.voteAverage = voteAverage
            self.voteCount = voteCount
        }
    }

    public struct Shelves: Equatable, Sendable {
        public let mostRated: [RankedMovie]
        public let highestRated: [RankedMovie]

        public init(mostRated: [RankedMovie], highestRated: [RankedMovie]) {
            self.mostRated = mostRated
            self.highestRated = highestRated
        }
    }

    private struct RankedCandidate: Sendable {
        let movie: TMDBMovieDiscoveryDTO
        let item: MediaModels.Item
    }

    public nonisolated static func discover(
        from providerMovies: [MediaModels.Item],
        using client: TMDBClient
    ) async -> Shelves {
        let candidates = providerMovies.filter { $0.type == .vod }
        guard !candidates.isEmpty, !Task.isCancelled else {
            return Shelves(mostRated: [], highestRated: [])
        }

        async let mostRatedPage1 = try? client.discoverMovies("vote_count.desc", 100, 1)
        async let mostRatedPage2 = try? client.discoverMovies("vote_count.desc", 100, 2)
        async let highestRatedPage1 = try? client.discoverMovies("vote_average.desc", 250, 1)
        async let highestRatedPage2 = try? client.discoverMovies("vote_average.desc", 250, 2)

        let (mostPage1, mostPage2, highestPage1, highestPage2) = await (
            mostRatedPage1,
            mostRatedPage2,
            highestRatedPage1,
            highestRatedPage2
        )
        let mostRatedResults = [mostPage1?.results, mostPage2?.results]
            .compactMap(\.self)
            .flatMap(\.self)
        let highestRatedResults = [highestPage1?.results, highestPage2?.results]
            .compactMap(\.self)
            .flatMap(\.self)
        guard !Task.isCancelled else { return Shelves(mostRated: [], highestRated: []) }

        return Shelves(
            mostRated: match(mostRatedResults, in: candidates, minimumVoteCount: 100)
                .sorted {
                    if $0.voteCount != $1.voteCount {
                        return $0.voteCount > $1.voteCount
                    }
                    return $0.item.title.localizedStandardCompare($1.item.title) == .orderedAscending
                },
            highestRated: match(highestRatedResults, in: candidates, minimumVoteCount: 250)
                .sorted {
                    if $0.voteAverage != $1.voteAverage {
                        return $0.voteAverage > $1.voteAverage
                    }
                    if $0.voteCount != $1.voteCount {
                        return $0.voteCount > $1.voteCount
                    }
                    return $0.item.title.localizedStandardCompare($1.item.title) == .orderedAscending
                }
        )
    }

    private nonisolated static func match(
        _ movies: [TMDBMovieDiscoveryDTO],
        in candidates: [MediaModels.Item],
        minimumVoteCount: Int
    ) -> [RankedMovie] {
        var candidateIndex: [String: [MediaModels.Item]] = [:]
        for item in candidates {
            candidateIndex[normalizedTitle(item.title), default: []].append(item)
        }

        var seenIDs = Set<String>()
        var result: [RankedMovie] = []
        for movie in movies {
            guard
                movie.adult != true,
                let voteCount = movie.voteCount,
                voteCount >= minimumVoteCount,
                let voteAverage = movie.voteAverage,
                voteAverage > 0,
                voteAverage <= 10
            else { continue }

            let titles = [movie.title, movie.originalTitle].compactMap(\.self).map(normalizedTitle)
            var titleMatchesByID: [String: MediaModels.Item] = [:]
            for title in titles {
                for item in candidateIndex[title] ?? [] {
                    titleMatchesByID[item.id] = item
                }
            }
            let titleMatches = Array(titleMatchesByID.values)
            let movieYear = year(in: movie.releaseDate)
            let yearMatches = titleMatches.filter { item in
                let itemYear = year(in: item.releaseDate) ?? trailingYear(in: item.title)
                if let movieYear {
                    guard let itemYear else { return false }
                    return movieYear == itemYear
                }
                return titleMatches.count == 1
            }

            guard yearMatches.count == 1, let item = yearMatches.first, seenIDs.insert(item.id).inserted else {
                continue
            }
            result.append(RankedMovie(item: item, voteAverage: voteAverage, voteCount: voteCount))
            if result.count == 10 {
                break
            }
        }
        return result
    }

    private nonisolated static func normalizedTitle(_ value: String) -> String {
        let withoutYear = value.replacingOccurrences(
            of: #"\s*[\(\[]?(?:19|20)\d{2}[\)\]]?\s*$"#,
            with: "",
            options: .regularExpression
        )
        return withoutYear
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "tr_TR"))
            .unicodeScalars
            .filter { CharacterSet.alphanumerics.contains($0) }
            .map(String.init)
            .joined()
    }

    private nonisolated static func year(in value: String?) -> Int? {
        guard let value,
              let match = value.range(of: #"(?:19|20)\d{2}"#, options: .regularExpression)
        else { return nil }
        return Int(value[match])
    }

    private nonisolated static func trailingYear(in title: String) -> Int? {
        guard let match = title.range(
            of: #"[\(\[]((?:19|20)\d{2})[\)\]]\s*$"#,
            options: .regularExpression
        ) else { return nil }
        let yearText = title[match].filter(\.isNumber)
        return Int(yearText)
    }
}
