import Foundation

/// Uses a small TMDB popularity window and one batched Wikidata query to find
/// award-recognized movies that are actually playable from the active playlist.
public enum AwardDiscoveryEngine: Sendable {
    public struct MovieEntry: Equatable, Identifiable, Sendable {
        public let item: MediaModels.Item
        public let recognitionCount: Int

        public var id: String {
            item.id
        }

        public nonisolated init(item: MediaModels.Item, recognitionCount: Int) {
            self.item = item
            self.recognitionCount = recognitionCount
        }
    }

    public struct Shelves: Equatable, Sendable {
        public let winners: [MovieEntry]
        public let nominees: [MovieEntry]

        public nonisolated init(winners: [MovieEntry], nominees: [MovieEntry]) {
            self.winners = winners
            self.nominees = nominees
        }
    }

    private struct MatchedMovie: Sendable {
        let movie: TMDBMovieDiscoveryDTO
        let item: MediaModels.Item
    }

    public nonisolated static func discover(
        from providerMovies: [MediaModels.Item],
        using tmdbClient: TMDBClient,
        awardClient: WikidataAwardClient
    ) async -> Shelves {
        let candidates = providerMovies.filter { $0.type == .vod }
        guard !candidates.isEmpty, !Task.isCancelled else {
            return Shelves(winners: [], nominees: [])
        }

        async let page1 = try? tmdbClient.discoverMovies("popularity.desc", 0, 1)
        async let page2 = try? tmdbClient.discoverMovies("popularity.desc", 0, 2)
        let (firstPage, secondPage) = await (page1, page2)
        guard !Task.isCancelled else { return Shelves(winners: [], nominees: []) }

        let movies = [firstPage?.results, secondPage?.results]
            .compactMap(\.self)
            .flatMap(\.self)
        let matched = match(Array(movies.prefix(40)), in: candidates)
        guard !matched.isEmpty, !Task.isCancelled else {
            return Shelves(winners: [], nominees: [])
        }

        guard let recognitions = try? await awardClient.fetchRecognitions(matched.map(\.movie.id), .movie) else {
            return Shelves(winners: [], nominees: [])
        }
        guard !Task.isCancelled else { return Shelves(winners: [], nominees: []) }

        let recognitionsByMovie = Dictionary(grouping: recognitions, by: \.tmdbID)
        let winners = entries(for: .winner, matched: matched, recognitions: recognitionsByMovie)
        let nominees = entries(for: .nominee, matched: matched, recognitions: recognitionsByMovie)
        return Shelves(winners: winners, nominees: nominees)
    }

    private nonisolated static func entries(
        for kind: WikidataAwardClient.RecognitionKind,
        matched: [MatchedMovie],
        recognitions: [Int: [WikidataAwardClient.Recognition]]
    ) -> [MovieEntry] {
        matched.compactMap { match in
            let count = (recognitions[match.movie.id] ?? [])
                .filter { $0.kind == kind }
                .reduce(0) { $0 + $1.recognitionCount }
            guard count > 0 else { return nil }
            return MovieEntry(item: match.item, recognitionCount: count)
        }
        .prefix(10)
        .map(\.self)
    }

    private nonisolated static func match(
        _ movies: [TMDBMovieDiscoveryDTO],
        in candidates: [MediaModels.Item]
    ) -> [MatchedMovie] {
        var candidateIndex: [String: [MediaModels.Item]] = [:]
        for item in candidates {
            candidateIndex[normalizedTitle(item.title), default: []].append(item)
        }

        var seenTMDBIDs = Set<Int>()
        var result: [MatchedMovie] = []
        for movie in movies {
            guard movie.adult != true, seenTMDBIDs.insert(movie.id).inserted else { continue }
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
            guard yearMatches.count == 1, let item = yearMatches.first else { continue }
            result.append(MatchedMovie(movie: movie, item: item))
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
        return Int(title[match].filter(\.isNumber))
    }
}
