import ComposableArchitecture
import Foundation

public enum PlaybackSkipMarkerKind: String, Codable, CaseIterable, Equatable, Sendable {
    case intro
    case credits
}

public struct PlaybackSkipMarker: Codable, Equatable, Sendable {
    public var startSeconds: Double?
    public var endSeconds: Double?

    public init(startSeconds: Double? = nil, endSeconds: Double? = nil) {
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
    }

    public func isValid(duration: Double) -> Bool {
        guard let startSeconds, let endSeconds else { return false }
        return startSeconds.isFinite
            && endSeconds.isFinite
            && startSeconds >= 0
            && endSeconds > startSeconds
            && endSeconds <= duration
    }

    public func contains(_ seconds: Double) -> Bool {
        guard let startSeconds, let endSeconds else { return false }
        return seconds >= startSeconds && seconds < endSeconds
    }
}

public struct PlaybackSkipMarkers: Codable, Equatable, Sendable {
    public var intro = PlaybackSkipMarker()
    public var credits = PlaybackSkipMarker()

    public init(intro: PlaybackSkipMarker = .init(), credits: PlaybackSkipMarker = .init()) {
        self.intro = intro
        self.credits = credits
    }

    public subscript(_ kind: PlaybackSkipMarkerKind) -> PlaybackSkipMarker {
        get {
            switch kind {
            case .intro: intro
            case .credits: credits
            }
        }
        set {
            switch kind {
            case .intro: intro = newValue
            case .credits: credits = newValue
            }
        }
    }
}

private actor PlaybackSkipMarkerStore {
    static let shared = PlaybackSkipMarkerStore()
    private static let processID = UUID()
    private let defaults = UserDefaults.standard

    private struct StoredMarkers: Codable {
        let processID: UUID
        let revision: UInt64
        let markers: PlaybackSkipMarkers
    }

    func load(
        profileID: UUID,
        playlistID: UUID,
        mediaKind: String,
        mediaID: String,
        seriesID: String?
    ) -> PlaybackSkipMarkers {
        guard let data = defaults.data(forKey: key(
            profileID: profileID,
            playlistID: playlistID,
            mediaKind: mediaKind,
            mediaID: mediaID,
            seriesID: seriesID
        )) else { return .init() }
        if let stored = try? JSONDecoder().decode(StoredMarkers.self, from: data) {
            return stored.markers
        }
        return (try? JSONDecoder().decode(PlaybackSkipMarkers.self, from: data)) ?? .init()
    }

    func save(
        _ markers: PlaybackSkipMarkers,
        revision: UInt64,
        profileID: UUID,
        playlistID: UUID,
        mediaKind: String,
        mediaID: String,
        seriesID: String?
    ) {
        let storageKey = key(
            profileID: profileID,
            playlistID: playlistID,
            mediaKind: mediaKind,
            mediaID: mediaID,
            seriesID: seriesID
        )
        if let data = defaults.data(forKey: storageKey),
           let existing = try? JSONDecoder().decode(StoredMarkers.self, from: data),
           existing.processID == Self.processID,
           existing.revision > revision
        {
            return
        }
        let record = StoredMarkers(processID: Self.processID, revision: revision, markers: markers)
        if let data = try? JSONEncoder().encode(record) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func key(
        profileID: UUID,
        playlistID: UUID,
        mediaKind: String,
        mediaID: String,
        seriesID: String?
    ) -> String {
        let components = [
            profileID.uuidString,
            playlistID.uuidString,
            mediaKind,
            mediaID,
            seriesID ?? "",
        ]
        let encoded = components.map {
            Data($0.utf8).base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "com.pureiptv.playbackSkipMarkers.v1." + encoded.joined(separator: ".")
    }
}

@DependencyClient
public struct PlaybackSkipMarkerClient: Sendable {
    public var load: @Sendable (
        _ profileID: UUID,
        _ playlistID: UUID,
        _ mediaKind: String,
        _ mediaID: String,
        _ seriesID: String?
    ) async -> PlaybackSkipMarkers = { _, _, _, _, _ in .init() }
    public var save: @Sendable (
        _ markers: PlaybackSkipMarkers,
        _ revision: UInt64,
        _ profileID: UUID,
        _ playlistID: UUID,
        _ mediaKind: String,
        _ mediaID: String,
        _ seriesID: String?
    ) async -> Void
}

extension PlaybackSkipMarkerClient: DependencyKey {
    public static let liveValue = Self(
        load: { profileID, playlistID, mediaKind, mediaID, seriesID in
            await PlaybackSkipMarkerStore.shared.load(
                profileID: profileID,
                playlistID: playlistID,
                mediaKind: mediaKind,
                mediaID: mediaID,
                seriesID: seriesID
            )
        },
        save: { markers, revision, profileID, playlistID, mediaKind, mediaID, seriesID in
            await PlaybackSkipMarkerStore.shared.save(
                markers,
                revision: revision,
                profileID: profileID,
                playlistID: playlistID,
                mediaKind: mediaKind,
                mediaID: mediaID,
                seriesID: seriesID
            )
        }
    )

    public static let testValue = Self()
}

public extension DependencyValues {
    var playbackSkipMarkerClient: PlaybackSkipMarkerClient {
        get { self[PlaybackSkipMarkerClient.self] }
        set { self[PlaybackSkipMarkerClient.self] = newValue }
    }
}
