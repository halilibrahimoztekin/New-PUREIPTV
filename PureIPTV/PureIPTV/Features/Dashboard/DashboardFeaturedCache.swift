import Foundation

/// Stores only the small, already-filtered Dashboard shelves. The full provider
/// catalogue remains transient and is refreshed in the background.
@MainActor
enum DashboardFeaturedCache {
    struct Snapshot: Codable, Sendable {
        let updatedAt: Date?
        let channels: [Item]
        let vods: [Item]
        let series: [Item]
    }

    struct Item: Codable, Sendable {
        let id: String
        let title: String
        let streamURL: URL?
        let coverURL: URL?
        let categoryID: String
        let type: String
        let rating: Double?
        let releaseDate: String?
        let duration: String?
        let addedDate: Date?
        let epgChannelID: String?
        let tvArchive: Int?
        let tvArchiveDuration: Int?

        init(_ item: MediaModels.Item) {
            id = item.id
            title = item.title
            streamURL = item.streamURL
            coverURL = item.coverURL
            categoryID = item.categoryID
            type = item.type.rawValue
            rating = item.rating
            releaseDate = item.releaseDate
            duration = item.duration
            addedDate = item.addedDate
            epgChannelID = item.epgChannelID
            tvArchive = item.tvArchive
            tvArchiveDuration = item.tvArchiveDuration
        }

        var mediaItem: MediaModels.Item? {
            guard let itemType = MediaModels.ItemType(rawValue: type) else { return nil }
            return MediaModels.Item(
                id: id,
                title: title,
                streamURL: streamURL,
                coverURL: coverURL,
                categoryID: categoryID,
                type: itemType,
                rating: rating,
                releaseDate: releaseDate,
                duration: duration,
                addedDate: addedDate,
                epgChannelID: epgChannelID,
                tvArchive: tvArchive,
                tvArchiveDuration: tvArchiveDuration
            )
        }
    }

    static func load(playlistID: UUID?, hideAdult: Bool) -> Snapshot? {
        migrateLegacyRecommendationPayloadsIfNeeded()
        guard let playlistID, let url = fileURL(playlistID: playlistID, hideAdult: hideAdult),
              let data = try? Data(contentsOf: url)
        else { return nil }
        return try? JSONDecoder().decode(Snapshot.self, from: data)
    }

    static func save(
        playlistID: UUID?,
        hideAdult: Bool,
        channels: [MediaModels.Item],
        vods: [MediaModels.Item],
        series: [MediaModels.Item]
    ) {
        guard let playlistID else { return }
        let snapshot = Snapshot(
            updatedAt: Date(),
            channels: channels.map(Item.init),
            vods: vods.map(Item.init),
            series: series.map(Item.init)
        )
        guard let url = fileURL(playlistID: playlistID, hideAdult: hideAdult) else { return }
        do {
            try write(snapshot, to: url)
        } catch {
            // A cache write failure must not affect playback or catalog loading.
        }
    }

    private static func migrateLegacyRecommendationPayloadsIfNeeded() {
        let migrationKey = "com.pureiptv.dashboardFeatured.recommendationCacheMigration.v1"
        guard !UserDefaults.standard.bool(forKey: migrationKey),
              let directoryURL = cacheDirectoryURL(),
              let cacheURLs = try? FileManager.default.contentsOfDirectory(
                  at: directoryURL,
                  includingPropertiesForKeys: nil
              )
        else { return }

        var migrationSucceeded = true
        for url in cacheURLs where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  payload["recommendations"] != nil || payload["recommendationReasons"] != nil,
                  let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data)
            else { continue }

            do {
                try write(snapshot, to: url)
            } catch {
                migrationSucceeded = false
            }
        }

        if migrationSucceeded {
            UserDefaults.standard.set(true, forKey: migrationKey)
        }
    }

    private static func write(_ snapshot: Snapshot, to url: URL) throws {
        let data = try JSONEncoder().encode(snapshot)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: url, options: .atomic)
        try FileManager.default.setAttributes(
            [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
            ofItemAtPath: url.path
        )
    }

    private static func fileURL(playlistID: UUID, hideAdult: Bool) -> URL? {
        cacheDirectoryURL()?
            .appendingPathComponent("\(playlistID.uuidString).adult-\(hideAdult).json")
    }

    private static func cacheDirectoryURL() -> URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("DashboardFeatured", isDirectory: true)
    }
}

enum LocalPersonalizationPreferences {
    nonisolated static let didChangeNotification = Notification.Name("LocalPersonalizationPreferences.didChange")

    static func recommendationsEnabled(for profileID: UUID?) -> Bool {
        guard let value = UserDefaults.standard.object(forKey: recommendationsKey(profileID)) as? Bool
        else { return true }
        return value
    }

    static func setRecommendationsEnabled(_ enabled: Bool, for profileID: UUID?) {
        UserDefaults.standard.set(enabled, forKey: recommendationsKey(profileID))
        notifyChange(profileID: profileID)
    }

    static func watchHistoryCutoff(for profileID: UUID?) -> Date? {
        UserDefaults.standard.object(forKey: watchHistoryCutoffKey(profileID)) as? Date
    }

    static func clearWatchHistorySignal(for profileID: UUID?) {
        UserDefaults.standard.set(Date(), forKey: watchHistoryCutoffKey(profileID))
        notifyChange(profileID: profileID)
    }

    private static func recommendationsKey(_ profileID: UUID?) -> String {
        "com.pureiptv.personalization.recommendationsEnabled.\(scopeKey(profileID))"
    }

    private static func watchHistoryCutoffKey(_ profileID: UUID?) -> String {
        "com.pureiptv.personalization.watchHistoryCutoff.\(scopeKey(profileID))"
    }

    private static func scopeKey(_ profileID: UUID?) -> String {
        profileID?.uuidString ?? "default-profile"
    }

    private static func notifyChange(profileID: UUID?) {
        var userInfo: [AnyHashable: Any] = [:]
        if let profileID {
            userInfo["profileID"] = profileID
        }
        NotificationCenter.default.post(
            name: didChangeNotification,
            object: nil,
            userInfo: userInfo
        )
    }
}
