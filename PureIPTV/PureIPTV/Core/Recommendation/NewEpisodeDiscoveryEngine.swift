import Foundation

/// Finds provider-reported episodes added after the user's most recent viewing
/// activity for a series. Series lookups are capped to keep dashboard refreshes
/// bounded, and unsupported flat playlists naturally produce no results.
public enum NewEpisodeDiscoveryEngine: Sendable {
    public struct SeriesEntry: Equatable, Identifiable, Sendable {
        public let series: MediaModels.Item
        public let newEpisodeCount: Int
        public let unwatchedEpisodeCount: Int
        public let latestSeason: Int
        public let latestEpisodeNumber: Int
        public let latestEpisodeTitle: String

        public var id: String {
            series.id
        }

        public init(
            series: MediaModels.Item,
            newEpisodeCount: Int,
            unwatchedEpisodeCount: Int = 0,
            latestSeason: Int,
            latestEpisodeNumber: Int,
            latestEpisodeTitle: String
        ) {
            self.series = series
            self.newEpisodeCount = newEpisodeCount
            self.unwatchedEpisodeCount = unwatchedEpisodeCount
            self.latestSeason = latestSeason
            self.latestEpisodeNumber = latestEpisodeNumber
            self.latestEpisodeTitle = latestEpisodeTitle
        }
    }

    private struct WatchedSeries: Sendable {
        let id: String
        let lastWatchedAt: Date?
        let watchedEpisodeIDs: Set<String>
    }

    public nonisolated static func discover(
        history: [WatchHistoryItem],
        playlistID: UUID?,
        seriesCatalog: [MediaModels.Item],
        favoriteSeriesIDs: Set<String> = [],
        config: PlaylistConfig,
        iptvClient: IPTVClient
    ) async -> [SeriesEntry] {
        guard config.type == .xtream, let playlistID else { return [] }

        let watchedSeries = Dictionary(grouping: history.filter {
            $0.playlistID == playlistID
                && $0.type.caseInsensitiveCompare("episode") == .orderedSame
                && $0.seriesID != nil
                && $0.duration > 0
                && $0.progress / $0.duration >= 0.90
        }, by: { $0.seriesID ?? "" })
            .compactMap { id, episodes -> WatchedSeries? in
                guard let lastWatchedAt = episodes.map(\.lastWatchedAt).max() else { return nil }
                return WatchedSeries(
                    id: id,
                    lastWatchedAt: lastWatchedAt,
                    watchedEpisodeIDs: Set(episodes.map(\.id))
                )
            }
            .sorted { ($0.lastWatchedAt ?? Date.distantPast) > ($1.lastWatchedAt ?? Date.distantPast) }

        let catalogByID: [String: MediaModels.Item] = Dictionary(
            seriesCatalog.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        var watchedByID: [String: WatchedSeries] = Dictionary(
            watchedSeries.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let favoriteIDs = favoriteSeriesIDs.filter { catalogByID[$0] != nil }
            .sorted {
                let leftDate = watchedByID[$0]?.lastWatchedAt ?? Date.distantPast
                let rightDate = watchedByID[$1]?.lastWatchedAt ?? Date.distantPast
                return leftDate == rightDate ? $0 < $1 : leftDate > rightDate
            }
        for id in favoriteIDs where watchedByID[id] == nil {
            watchedByID[id] = WatchedSeries(id: id, lastWatchedAt: nil, watchedEpisodeIDs: [])
        }
        var requestedIDs: [String] = []
        for id in favoriteIDs + watchedSeries.map(\.id) {
            if !requestedIDs.contains(id), requestedIDs.count < 8 {
                requestedIDs.append(id)
            }
        }
        var result: [SeriesEntry] = []
        for seriesID in requestedIDs {
            guard !Task.isCancelled, let series = catalogByID[seriesID], let watched = watchedByID[seriesID] else { continue }
            guard let response = try? await iptvClient.fetchSeriesInfo(config, seriesID) else { continue }
            guard !Task.isCancelled else { return [] }

            let now = Date()
            let releasedEpisodes = response.episodes.filter { episode in
                guard let availableDate = episode.releaseDate ?? episode.addedDate else { return false }
                return availableDate <= now
            }
            let unwatchedEpisodes = releasedEpisodes.filter { episode in
                !watched.watchedEpisodeIDs.contains(episode.id)
            }
            let newEpisodes = unwatchedEpisodes.filter { episode in
                guard let lastWatchedAt = watched.lastWatchedAt else { return false }
                return (episode.releaseDate ?? episode.addedDate).map { $0 > lastWatchedAt } ?? false
            }
            let latestCandidates: [DetailModels.Episode] = newEpisodes.isEmpty ? unwatchedEpisodes : newEpisodes
            guard let latest = latestCandidates.max(by: { left, right in
                let leftDate = left.releaseDate ?? left.addedDate ?? Date.distantPast
                let rightDate = right.releaseDate ?? right.addedDate ?? Date.distantPast
                return leftDate < rightDate
            }) else { continue }

            result.append(SeriesEntry(
                series: series,
                newEpisodeCount: newEpisodes.count,
                unwatchedEpisodeCount: unwatchedEpisodes.count,
                latestSeason: latest.season,
                latestEpisodeNumber: latest.episodeNum,
                latestEpisodeTitle: latest.title
            ))
        }
        return result.sorted { lhs, rhs in
            let lhsSeries = watchedByID[lhs.series.id]
            let rhsSeries = watchedByID[rhs.series.id]
            return (lhsSeries?.lastWatchedAt ?? Date.distantPast) > (rhsSeries?.lastWatchedAt ?? Date.distantPast)
        }
    }
}
