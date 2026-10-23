import Foundation

/// Stores only the small, already-filtered Dashboard shelves. The full provider
/// catalogue remains transient and is refreshed in the background.
@MainActor
enum DashboardFeaturedCache {
    struct Snapshot: Codable, Sendable {
        let channels: [Item]
        let vods: [Item]
        let series: [Item]
        let recommendations: [Item]
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
        series: [MediaModels.Item],
        recommendations: [MediaModels.Item]
    ) {
        guard let playlistID else { return }
        let snapshot = Snapshot(
            channels: channels.map(Item.init),
            vods: vods.map(Item.init),
            series: series.map(Item.init),
            recommendations: recommendations.map(Item.init)
        )
        guard let data = try? JSONEncoder().encode(snapshot),
              let url = fileURL(playlistID: playlistID, hideAdult: hideAdult)
        else { return }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            try FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication],
                ofItemAtPath: url.path
            )
        } catch {
            // A cache write failure must not affect playback or catalog loading.
        }
    }

    private static func fileURL(playlistID: UUID, hideAdult: Bool) -> URL? {
        guard let cacheDirectory = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return cacheDirectory
            .appendingPathComponent("DashboardFeatured", isDirectory: true)
            .appendingPathComponent("\(playlistID.uuidString).adult-\(hideAdult).json")
    }
}
