import Foundation

/// Builds small actor-linked shelves by resolving a few recent watch-history
/// titles, then intersecting those actors' combined credits with the active
/// provider catalogue. It never enriches every catalogue item individually.
public enum ActorRecommendationEngine: Sendable {
    public struct MostWatchedActor: Equatable, Identifiable, Sendable {
        public enum Source: Equatable, Sendable { case watchHistory, popularFallback }
        public let id: Int
        public let name: String
        public let profilePath: String?
        public let watchedTitleCount: Int
        public let source: Source

        public nonisolated init(id: Int, name: String, profilePath: String?, watchedTitleCount: Int, source: Source) {
            self.id = id
            self.name = name
            self.profilePath = profilePath
            self.watchedTitleCount = watchedTitleCount
            self.source = source
        }
    }

    public enum MediaKind: String, Codable, Sendable {
        case movie
        case series

        public var title: String {
            switch self {
            case .movie: "Filmler".localized
            case .series: "Diziler".localized
            }
        }
    }

    public struct Collection: Equatable, Identifiable, Sendable {
        public let id: String
        public let actorName: String
        public let sourceTitle: String
        public let kind: MediaKind
        public let items: [MediaModels.Item]

        public nonisolated init(
            actorID: Int,
            actorName: String,
            sourceTitle: String,
            kind: MediaKind,
            items: [MediaModels.Item]
        ) {
            id = "\(kind.rawValue):\(actorID)"
            self.actorName = actorName
            self.sourceTitle = sourceTitle
            self.kind = kind
            self.items = items
        }
    }

    private enum SourceKind: Sendable {
        case movie
        case series
    }

    private struct Seed: Sendable {
        let title: String
        let year: Int?
        let kind: SourceKind
    }

    public nonisolated static func collections(
        history: [WatchHistoryItem],
        playlistID: UUID?,
        movies: [MediaModels.Item],
        series: [MediaModels.Item],
        tmdbClient: TMDBClient
    ) async -> [Collection] {
        guard let playlistID else { return [] }
        let seeds = recentSeeds(from: history, playlistID: playlistID)
        guard !seeds.isEmpty else { return [] }

        var seenActorIDs = Set<Int>()
        var result: [Collection] = []
        for seed in seeds {
            guard !Task.isCancelled else { return [] }
            guard let source = await resolve(seed, using: tmdbClient) else { continue }
            for castMember in (source.credits?.cast ?? []).prefix(2) {
                guard !Task.isCancelled else { return [] }
                guard
                    seenActorIDs.insert(castMember.id).inserted,
                    let actorName = castMember.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                    !actorName.isEmpty
                else { continue }

                let actorCredits: TMDBPersonCreditsDTO
                if let cached = await LookupCache.shared.credits(for: castMember.id) {
                    actorCredits = cached
                } else {
                    guard let fetched = try? await tmdbClient.fetchPersonCombinedCredits(castMember.id) else {
                        continue
                    }
                    await LookupCache.shared.store(fetched, for: castMember.id)
                    actorCredits = fetched
                }
                let movieMatches = matches(
                    actorCredits.cast ?? [],
                    kind: .movie,
                    candidates: movies,
                    excluding: Set(history.filter { $0.playlistID == playlistID }.map(\.id))
                )
                let seriesMatches = matches(
                    actorCredits.cast ?? [],
                    kind: .series,
                    candidates: series,
                    excluding: Set(history.filter { $0.playlistID == playlistID }.compactMap(\.seriesID))
                )

                if movieMatches.count >= 2 {
                    result.append(Collection(
                        actorID: castMember.id,
                        actorName: actorName,
                        sourceTitle: seed.title,
                        kind: .movie,
                        items: movieMatches
                    ))
                }
                if seriesMatches.count >= 2 {
                    result.append(Collection(
                        actorID: castMember.id,
                        actorName: actorName,
                        sourceTitle: seed.title,
                        kind: .series,
                        items: seriesMatches
                    ))
                }
                if result.count >= 4 {
                    return result
                }
            }
        }
        return result
    }

    public nonisolated static func mostWatchedActors(
        history: [WatchHistoryItem],
        playlistID: UUID?,
        movies: [MediaModels.Item],
        series: [MediaModels.Item],
        tmdbClient: TMDBClient
    ) async -> [MostWatchedActor] {
        var appearances: [Int: (name: String, profilePath: String?, count: Int)] = [:]
        if let playlistID {
            for seed in recentSeeds(from: history, playlistID: playlistID) {
                guard !Task.isCancelled else { return [] }
                guard let source = await resolve(seed, using: tmdbClient) else { continue }
                var seenInSource = Set<Int>()
                for actor in source.credits?.cast ?? [] {
                    guard
                        seenInSource.insert(actor.id).inserted,
                        let name = actor.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                        !name.isEmpty
                    else { continue }
                    let existing = appearances[actor.id]
                    appearances[actor.id] = (
                        name,
                        actor.profilePath ?? existing?.profilePath,
                        (existing?.count ?? 0) + 1
                    )
                }
            }
        }

        let ranked = appearances.map { id, value in
            MostWatchedActor(
                id: id,
                name: value.name,
                profilePath: value.profilePath,
                watchedTitleCount: value.count,
                source: .watchHistory
            )
        }
        .sorted {
            if $0.watchedTitleCount != $1.watchedTitleCount {
                return $0.watchedTitleCount > $1.watchedTitleCount
            }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        if !ranked.isEmpty {
            return await catalogMatchingActors(Array(ranked.prefix(16)), movies: movies, series: series, tmdbClient: tmdbClient)
        }

        if let cached = await LookupCache.shared.popularActors() {
            return await catalogMatchingActors(cached, movies: movies, series: series, tmdbClient: tmdbClient)
        }
        guard !Task.isCancelled else { return [] }
        let response: TMDBPopularPeopleResponseDTO
        do {
            response = try await tmdbClient.fetchPopularPeople()
        } catch {
            return []
        }
        var seen = Set<Int>()
        let people: [TMDBPopularPersonDTO] = response.results ?? []
        let actors: [MostWatchedActor] = Array(people.compactMap { person -> MostWatchedActor? in
            guard
                seen.insert(person.id).inserted,
                person.knownForDepartment?.caseInsensitiveCompare("Acting") == .orderedSame,
                let name = person.name?.trimmingCharacters(in: .whitespacesAndNewlines),
                !name.isEmpty
            else { return nil }
            return MostWatchedActor(
                id: person.id,
                name: name,
                profilePath: person.profilePath,
                watchedTitleCount: 0,
                source: .popularFallback
            )
        }.prefix(16))
        guard !Task.isCancelled else { return [] }
        await LookupCache.shared.storePopularActors(actors)
        return await catalogMatchingActors(actors, movies: movies, series: series, tmdbClient: tmdbClient)
    }

    private nonisolated static func catalogMatchingActors(
        _ actors: [MostWatchedActor],
        movies: [MediaModels.Item],
        series: [MediaModels.Item],
        tmdbClient: TMDBClient
    ) async -> [MostWatchedActor] {
        var result: [MostWatchedActor] = []
        for actor in actors {
            guard !Task.isCancelled else { return [] }
            let credits: TMDBPersonCreditsDTO
            if let cached = await LookupCache.shared.credits(for: actor.id) {
                credits = cached
            } else {
                guard let fetched = try? await tmdbClient.fetchPersonCombinedCredits(actor.id) else { continue }
                await LookupCache.shared.store(fetched, for: actor.id)
                credits = fetched
            }
            guard !Task.isCancelled else { return [] }
            if !matches(credits.cast ?? [], kind: .movie, candidates: movies, excluding: [], limit: 1).isEmpty
                || !matches(credits.cast ?? [], kind: .series, candidates: series, excluding: [], limit: 1).isEmpty
            {
                result.append(actor)
                if result.count == 8 {
                    break
                }
            }
        }
        return result
    }

    public nonisolated static func filmography(
        actorID: Int,
        actorName: String,
        movies: [MediaModels.Item],
        series: [MediaModels.Item],
        tmdbClient: TMDBClient
    ) async -> [Collection] {
        guard !Task.isCancelled else { return [] }
        let credits: TMDBPersonCreditsDTO
        if let cached = await LookupCache.shared.credits(for: actorID) {
            credits = cached
        } else {
            guard let fetched = try? await tmdbClient.fetchPersonCombinedCredits(actorID) else { return [] }
            await LookupCache.shared.store(fetched, for: actorID)
            credits = fetched
        }
        guard !Task.isCancelled else { return [] }
        let movieMatches = matches(credits.cast ?? [], kind: .movie, candidates: movies, excluding: [], limit: 80)
        let seriesMatches = matches(credits.cast ?? [], kind: .series, candidates: series, excluding: [], limit: 80)
        var result: [Collection] = []
        if !movieMatches.isEmpty {
            result.append(Collection(
                actorID: actorID,
                actorName: actorName,
                sourceTitle: "Filmografi",
                kind: .movie,
                items: movieMatches
            ))
        }
        if !seriesMatches.isEmpty {
            result.append(Collection(
                actorID: actorID,
                actorName: actorName,
                sourceTitle: "Filmografi",
                kind: .series,
                items: seriesMatches
            ))
        }
        return result
    }

    private nonisolated static func recentSeeds(from history: [WatchHistoryItem], playlistID: UUID) -> [Seed] {
        var seenIDs = Set<String>()
        var seenSeriesIDs = Set<String>()
        var result: [Seed] = []
        for item in history
            .filter({ $0.playlistID == playlistID })
            .sorted(by: { $0.lastWatchedAt > $1.lastWatchedAt })
        {
            guard result.count < 3 else { break }
            let sourceKind: SourceKind
            let sourceTitle: String
            if item.type.caseInsensitiveCompare("episode") == .orderedSame,
               let seriesTitle = item.seriesTitle?.trimmingCharacters(in: .whitespacesAndNewlines),
               !seriesTitle.isEmpty
            {
                sourceKind = .series
                sourceTitle = seriesTitle
                if let seriesID = item.seriesID, !seenSeriesIDs.insert(seriesID).inserted {
                    continue
                }
            } else if item.type.caseInsensitiveCompare("vod") == .orderedSame {
                sourceKind = .movie
                sourceTitle = item.title
            } else {
                continue
            }
            let key = "\(sourceKind)\u{0}\(normalizedTitle(sourceTitle))"
            guard seenIDs.insert(key).inserted else { continue }
            result.append(Seed(title: sourceTitle, year: year(in: sourceTitle), kind: sourceKind))
        }
        return result
    }

    private struct ResolvedSource {
        let title: String
        let credits: TMDBCreditsDTO?
    }

    /// Session-memory-only cache: provider titles and viewing-derived actor
    /// links are not persisted to disk. Entries expire after one day.
    private actor LookupCache {
        static let shared = LookupCache()
        private let lifetime: TimeInterval = 24 * 60 * 60
        private var sources: [String: (expiresAt: Date, value: ResolvedSource)] = [:]
        private var creditsByActorID: [Int: (expiresAt: Date, value: TMDBPersonCreditsDTO)] = [:]
        private var popularActorsEntry: (expiresAt: Date, value: [MostWatchedActor])?

        func popularActors() -> [MostWatchedActor]? {
            guard let entry = popularActorsEntry else { return nil }
            guard entry.expiresAt > Date() else {
                popularActorsEntry = nil
                return nil
            }
            return entry.value
        }

        func storePopularActors(_ actors: [MostWatchedActor]) {
            popularActorsEntry = (Date().addingTimeInterval(lifetime), actors)
        }

        func source(for key: String) -> ResolvedSource? {
            guard let entry = sources[key] else { return nil }
            guard entry.expiresAt > Date() else {
                sources.removeValue(forKey: key)
                return nil
            }
            return entry.value
        }

        func store(_ source: ResolvedSource, for key: String) {
            pruneExpiredEntries()
            sources[key] = (Date().addingTimeInterval(lifetime), source)
            if sources.count > 200, let oldestKey = sources.keys.first {
                sources.removeValue(forKey: oldestKey)
            }
        }

        func credits(for actorID: Int) -> TMDBPersonCreditsDTO? {
            guard let entry = creditsByActorID[actorID] else { return nil }
            guard entry.expiresAt > Date() else {
                creditsByActorID.removeValue(forKey: actorID)
                return nil
            }
            return entry.value
        }

        func store(_ credits: TMDBPersonCreditsDTO, for actorID: Int) {
            pruneExpiredEntries()
            creditsByActorID[actorID] = (Date().addingTimeInterval(lifetime), credits)
            if creditsByActorID.count > 200, let oldestID = creditsByActorID.keys.first {
                creditsByActorID.removeValue(forKey: oldestID)
            }
        }

        private func pruneExpiredEntries() {
            let now = Date()
            sources = sources.filter { $0.value.expiresAt > now }
            creditsByActorID = creditsByActorID.filter { $0.value.expiresAt > now }
        }
    }

    private nonisolated static func resolve(_ seed: Seed, using client: TMDBClient) async -> ResolvedSource? {
        let cacheKey = "\(seed.kind)|\(normalizedTitle(seed.title))|\(seed.year.map(String.init) ?? "-")"
        if let cached = await LookupCache.shared.source(for: cacheKey) {
            return cached
        }
        do {
            let search: TMDBSearchResponseDTO = switch seed.kind {
            case .movie:
                try await client.searchMovie(seed.title)
            case .series:
                try await client.searchTV(seed.title)
            }
            guard !Task.isCancelled else { return nil }
            let matches = (search.results ?? []).filter { result in
                let titles = [result.title, result.name, result.originalTitle, result.originalName]
                    .compactMap(\.self)
                guard titles.contains(where: { normalizedTitle($0) == normalizedTitle(seed.title) }) else {
                    return false
                }
                guard let seedYear = seed.year else { return true }
                let resultYear = year(in: result.releaseDate ?? result.firstAirDate)
                return resultYear == seedYear
            }
            let uniqueMatches = Dictionary(matches.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            guard uniqueMatches.count == 1, let match = uniqueMatches.values.first else { return nil }
            let details: TMDBCreditsDTO?
            let resolvedTitle: String?
            switch seed.kind {
            case .movie:
                let value = try await client.fetchMovieDetails(match.id)
                guard seed.year == nil || year(in: value.releaseDate) == seed.year else { return nil }
                details = value.credits
                resolvedTitle = value.title ?? match.title ?? match.originalTitle
            case .series:
                let value = try await client.fetchTVDetails(match.id)
                guard seed.year == nil || year(in: value.firstAirDate) == seed.year else { return nil }
                details = value.credits
                resolvedTitle = value.name ?? match.name ?? match.originalName
            }
            guard let resolvedTitle else { return nil }
            let resolved = ResolvedSource(title: resolvedTitle, credits: details)
            await LookupCache.shared.store(resolved, for: cacheKey)
            return resolved
        } catch is CancellationError {
            return nil
        } catch {
            return nil
        }
    }

    private nonisolated static func matches(
        _ credits: [TMDBPersonCreditDTO],
        kind: MediaKind,
        candidates: [MediaModels.Item],
        excluding watchedIDs: Set<String>,
        limit: Int = 8
    ) -> [MediaModels.Item] {
        var candidateIndex: [String: [MediaModels.Item]] = [:]
        for item in candidates where !watchedIDs.contains(item.id) {
            candidateIndex[normalizedTitle(item.title), default: []].append(item)
        }

        var seenIDs = Set<String>()
        var result: [MediaModels.Item] = []
        for credit in credits {
            guard credit.mediaType == (kind == .movie ? "movie" : "tv") else { continue }
            let creditTitles = [credit.title, credit.name, credit.originalTitle, credit.originalName]
                .compactMap(\.self)
                .map(normalizedTitle)
            guard let key = creditTitles.first(where: { candidateIndex[$0] != nil }) else { continue }
            guard let titleMatches = candidateIndex[key] else { continue }
            let creditYear = year(in: credit.releaseDate ?? credit.firstAirDate)
            let yearMatches = titleMatches.filter { item in
                let candidateYear = year(in: item.releaseDate) ?? year(in: item.title)
                if let creditYear, let candidateYear {
                    return creditYear == candidateYear
                }
                return titleMatches.count == 1
            }
            for item in yearMatches where seenIDs.insert(item.id).inserted {
                result.append(item)
            }
            if result.count >= limit {
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
}
