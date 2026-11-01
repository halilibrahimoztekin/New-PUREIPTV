import ComposableArchitecture
import Foundation

public enum PlaylistContentArea: String, CaseIterable, Codable, Equatable, Hashable, Sendable {
    case liveTV
    case movies
    case series
}

public struct PlaylistContentSourceSelection: Codable, Equatable, Sendable {
    public var liveTVPlaylistID: UUID?
    public var moviesPlaylistID: UUID?
    public var seriesPlaylistID: UUID?

    public init(
        liveTVPlaylistID: UUID? = nil,
        moviesPlaylistID: UUID? = nil,
        seriesPlaylistID: UUID? = nil
    ) {
        self.liveTVPlaylistID = liveTVPlaylistID
        self.moviesPlaylistID = moviesPlaylistID
        self.seriesPlaylistID = seriesPlaylistID
    }

    public var isEmpty: Bool {
        liveTVPlaylistID == nil && moviesPlaylistID == nil && seriesPlaylistID == nil
    }

    public func playlistID(for area: PlaylistContentArea) -> UUID? {
        switch area {
        case .liveTV: liveTVPlaylistID
        case .movies: moviesPlaylistID
        case .series: seriesPlaylistID
        }
    }

    public mutating func setPlaylistID(_ playlistID: UUID?, for area: PlaylistContentArea) {
        switch area {
        case .liveTV: liveTVPlaylistID = playlistID
        case .movies: moviesPlaylistID = playlistID
        case .series: seriesPlaylistID = playlistID
        }
    }

    public mutating func removePlaylist(_ playlistID: UUID) {
        for area in PlaylistContentArea.allCases where self.playlistID(for: area) == playlistID {
            setPlaylistID(nil, for: area)
        }
    }
}

public struct PlaylistContentSourceConfigs: Sendable {
    public let liveTV: PlaylistConfig
    public let movies: PlaylistConfig
    public let series: PlaylistConfig

    public init(liveTV: PlaylistConfig, movies: PlaylistConfig, series: PlaylistConfig) {
        self.liveTV = liveTV
        self.movies = movies
        self.series = series
    }
}

public struct PlaylistContentSourceClient: Sendable {
    public var load: @Sendable (_ profileID: UUID?) -> PlaylistContentSourceSelection
    public var save: @Sendable (_ selection: PlaylistContentSourceSelection, _ profileID: UUID?) -> Void
    public var removePlaylistReferences: @Sendable (_ playlistID: UUID) -> Void

    public init(
        load: @escaping @Sendable (UUID?) -> PlaylistContentSourceSelection,
        save: @escaping @Sendable (PlaylistContentSourceSelection, UUID?) -> Void,
        removePlaylistReferences: @escaping @Sendable (UUID) -> Void
    ) {
        self.load = load
        self.save = save
        self.removePlaylistReferences = removePlaylistReferences
    }
}

private enum PlaylistContentSourceStore {
    private static let storageKey = "com.pureiptv.playlistContentSources.v1"

    static func load(profileID: UUID?) -> PlaylistContentSourceSelection {
        storedSelections()[profileKey(profileID)] ?? PlaylistContentSourceSelection()
    }

    static func save(_ selection: PlaylistContentSourceSelection, profileID: UUID?) {
        var selections = storedSelections()
        let key = profileKey(profileID)
        if selection.isEmpty {
            selections.removeValue(forKey: key)
        } else {
            selections[key] = selection
        }
        persist(selections)
    }

    static func removePlaylistReferences(_ playlistID: UUID) {
        var selections = storedSelections()
        for key in Array(selections.keys) {
            guard var selection = selections[key] else { continue }
            let previous = selection
            selection.removePlaylist(playlistID)
            if selection != previous {
                if selection.isEmpty {
                    selections.removeValue(forKey: key)
                } else {
                    selections[key] = selection
                }
            }
        }
        persist(selections)
    }

    private static func storedSelections() -> [String: PlaylistContentSourceSelection] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let selections = try? JSONDecoder().decode([String: PlaylistContentSourceSelection].self, from: data)
        else { return [:] }
        return selections
    }

    private static func persist(_ selections: [String: PlaylistContentSourceSelection]) {
        guard !selections.isEmpty else {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(selections) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    private static func profileKey(_ profileID: UUID?) -> String {
        profileID?.uuidString.lowercased() ?? "default"
    }
}

extension PlaylistContentSourceClient: DependencyKey {
    public static let liveValue = PlaylistContentSourceClient(
        load: { PlaylistContentSourceStore.load(profileID: $0) },
        save: { PlaylistContentSourceStore.save($0, profileID: $1) },
        removePlaylistReferences: { PlaylistContentSourceStore.removePlaylistReferences($0) }
    )

    public static let testValue = PlaylistContentSourceClient(
        load: { _ in PlaylistContentSourceSelection() },
        save: { _, _ in },
        removePlaylistReferences: { _ in }
    )
}

public extension DependencyValues {
    var playlistContentSourceClient: PlaylistContentSourceClient {
        get { self[PlaylistContentSourceClient.self] }
        set { self[PlaylistContentSourceClient.self] = newValue }
    }
}
