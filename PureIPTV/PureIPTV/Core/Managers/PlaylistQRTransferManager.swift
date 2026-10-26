import Foundation

/// Transfers a playlist selection between the user's devices without putting credentials in the QR code.
public final class PlaylistQRTransferManager: @unchecked Sendable {
    public nonisolated static let shared = PlaylistQRTransferManager()

    public nonisolated struct Pairing: Equatable, Sendable {
        public let sessionID: UUID
        public let secret: UUID

        public var url: URL? {
            var components = URLComponents()
            components.scheme = "pureiptv"
            components.host = "setup"
            components.queryItems = [
                URLQueryItem(name: "session", value: sessionID.uuidString),
                URLQueryItem(name: "secret", value: secret.uuidString),
            ]
            return components.url
        }
    }

    private nonisolated struct Session: Codable {
        let id: UUID
        let secret: UUID
        let expiresAt: Date
    }

    private nonisolated struct Request: Codable {
        let sessionID: UUID
        let secret: UUID
        let playlistID: UUID
        let expiresAt: Date
    }

    private nonisolated let keychain = KeychainManager.shared
    private nonisolated let repository = PlaylistRepository()
    private nonisolated let lifetime: TimeInterval = 5 * 60
    private nonisolated let mutationLock = NSLock()

    private init() {}

    public nonisolated func beginSession() throws -> Pairing {
        let session = Session(id: UUID(), secret: UUID(), expiresAt: Date().addingTimeInterval(lifetime))
        try keychain.save(session, for: sessionKey(session.id))
        return Pairing(sessionID: session.id, secret: session.secret)
    }

    public nonisolated func availablePlaylists(for pairing: Pairing) -> [SavedPlaylist]? {
        guard let session = readSession(pairing.sessionID),
              session.expiresAt > Date(), session.secret == pairing.secret
        else { return nil }
        return repository.getPlaylists()
    }

    public nonisolated func submit(playlistID: UUID, for pairing: Pairing) throws {
        mutationLock.lock()
        defer { mutationLock.unlock() }

        guard let session = readSession(pairing.sessionID),
              session.expiresAt > Date(), session.secret == pairing.secret,
              repository.getPlaylists().contains(where: { $0.id == playlistID })
        else { throw KeychainError.itemNotFound }

        let request = Request(
            sessionID: pairing.sessionID,
            secret: pairing.secret,
            playlistID: playlistID,
            expiresAt: session.expiresAt
        )
        try keychain.save(request, for: requestKey(pairing.sessionID))
    }

    /// Returns nil while iCloud Keychain is still syncing; expired or malformed requests are discarded.
    public nonisolated func consumeRequest(for pairing: Pairing) -> SavedPlaylist? {
        guard let session = readSession(pairing.sessionID),
              session.expiresAt > Date(), session.secret == pairing.secret,
              let request = try? keychain.retrieve(for: requestKey(pairing.sessionID), as: Request.self),
              request.sessionID == pairing.sessionID,
              request.secret == pairing.secret,
              request.expiresAt > Date()
        else {
            if readSession(pairing.sessionID)?.expiresAt ?? .distantPast <= Date() {
                endSession(pairing.sessionID)
            }
            return nil
        }

        guard let playlist = repository.getPlaylists().first(where: { $0.id == request.playlistID }) else {
            return nil
        }
        repository.setActivePlaylistID(playlist.id)
        endSession(pairing.sessionID)
        return playlist
    }

    public nonisolated func endSession(_ id: UUID) {
        mutationLock.lock()
        defer { mutationLock.unlock() }
        try? keychain.delete(for: requestKey(id))
        try? keychain.delete(for: sessionKey(id))
    }

    private nonisolated func readSession(_ id: UUID) -> Session? {
        try? keychain.retrieve(for: sessionKey(id), as: Session.self)
    }

    private nonisolated func sessionKey(_ id: UUID) -> String {
        "com.pureiptv.qrTransfer.session.\(id.uuidString)"
    }

    private nonisolated func requestKey(_ id: UUID) -> String {
        "com.pureiptv.qrTransfer.request.\(id.uuidString)"
    }
}
