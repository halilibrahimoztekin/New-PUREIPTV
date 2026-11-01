import Foundation

enum SeriesEpisodeSortPreference {
    static func load(profileID: UUID?, playlistID: UUID?, seriesID: String) -> SeriesDetailFeature.State.EpisodeSortOrder? {
        guard !seriesID.isEmpty,
              let rawValue = UserDefaults.standard.string(forKey: key(
                  profileID: profileID,
                  playlistID: playlistID,
                  seriesID: seriesID
              ))
        else { return nil }

        return SeriesDetailFeature.State.EpisodeSortOrder(rawValue: rawValue)
    }

    static func save(
        _ order: SeriesDetailFeature.State.EpisodeSortOrder,
        profileID: UUID?,
        playlistID: UUID?,
        seriesID: String
    ) {
        guard !seriesID.isEmpty else { return }
        UserDefaults.standard.set(
            order.rawValue,
            forKey: key(profileID: profileID, playlistID: playlistID, seriesID: seriesID)
        )
    }

    private static func key(profileID: UUID?, playlistID: UUID?, seriesID: String) -> String {
        let profileScope = profileID?.uuidString ?? "legacy"
        let playlistScope = playlistID?.uuidString ?? "default"
        return "com.pureiptv.seriesEpisodeSort.v1.\(profileScope).\(playlistScope).\(seriesID.utf8.count):\(seriesID)"
    }
}
