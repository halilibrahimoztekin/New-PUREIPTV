import Foundation

/// Finds provider-reported episodes added after the user's most recent viewing
/// activity for a series. Series lookups are capped to keep dashboard refreshes
/// bounded, and unsupported flat playlists naturally produce no results.
public enum NewEpisodeDiscoveryEngine: Sendable {
    public struct SeriesEntry: Equatable, Identifiable, Sendable {
        public let series: MediaModels.Item
        public let newEpisodeCount: Int
        public let latestSeason: Int
        public let latestEpisodeNumber: Int
        public let latestEpisodeTitle: String

        public var id: String {
            series.id
        }

        public init(
            series: MediaModels.Item,
            newEpisodeCount: Int,
            latestSeason: Int,
            latestEpisodeNumber: Int,
            latestEpisodeTitle: String
        ) {
            self.series = series
            self.newEpisodeCount = newEpisodeCount
            self.latestSeason = latestSeason
            self.latestEpisodeNumber = latestEpisodeNumber
            self.latestEpisodeTitle = latestEpisodeTitle
        }
    }

    private struct WatchedSeries: Sendable {
        let id: String
        let lastWatchedAt: Date
        let watchedEpisodeIDs: Set<String>
    }

    public nonisolated static func discover(
        history: [WatchHistoryItem],
        playlistID: UUID?,
        seriesCatalog: [MediaModels.Item],
        config: PlaylistConfig,
        iptvClient: IPTVClient
    ) async -> [SeriesEntry] {
        guard config.type == .xtream, let playlistID else { return [] }

        let watchedSeries = Dictionary(grouping: history.filter {
            $0.playlistID == playlistID
                && $0.type.caseInsensitiveCompare("episode") == .orderedSame
                && $0.seriesID != nil
        }, by: { $0.seriesID ?? "" })
            .compactMap { id, episodes -> WatchedSeries? in
                guard let lastWatchedAt = episodes.map(\.lastWatchedAt).max() else { return nil }
                return WatchedSeries(
                    id: id,
                    lastWatchedAt: lastWatchedAt,
                    watchedEpisodeIDs: Set(episodes.map(\.id))
                )
            }
            .sorted { $0.lastWatchedAt > $1.lastWatchedAt }
            .prefix(8)

        let catalogByID = Dictionary(seriesCatalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var result: [SeriesEntry] = []
        for watched in watchedSeries {
            guard !Task.isCancelled, let series = catalogByID[watched.id] else { continue }
            guard let response = try? await iptvClient.fetchSeriesInfo(config, watched.id) else { continue }
            guard !Task.isCancelled else { return [] }

            let newEpisodes = response.episodes.filter { episode in
                !watched.watchedEpisodeIDs.contains(episode.id)
                    && (episode.addedDate.map { $0 > watched.lastWatchedAt } ?? false)
            }
            guard let latest = newEpisodes.max(by: {
                ($0.addedDate ?? .distantPast) < ($1.addedDate ?? .distantPast)
            }) else { continue }

            result.append(SeriesEntry(
                series: series,
                newEpisodeCount: newEpisodes.count,
                latestSeason: latest.season,
                latestEpisodeNumber: latest.episodeNum,
                latestEpisodeTitle: latest.title
            ))
        }
        return result.sorted { lhs, rhs in
            let lhsSeries = watchedSeries.first(where: { $0.id == lhs.series.id })
            let rhsSeries = watchedSeries.first(where: { $0.id == rhs.series.id })
            return (lhsSeries?.lastWatchedAt ?? .distantPast) > (rhsSeries?.lastWatchedAt ?? .distantPast)
        }
    }
}
