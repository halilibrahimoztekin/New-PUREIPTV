import ComposableArchitecture
import Foundation

#if os(iOS)
    import ImageIO
    import MediaPlayer
    import UIKit
#endif

public struct NowPlayingMetadata: Equatable, Sendable {
    public let itemID: String
    public let playbackRequestID: UUID
    public let title: String
    public let seriesTitle: String?
    public let artworkURL: URL?
    public let artworkUserAgent: String?
    public let duration: Double?
    public let elapsedTime: Double
    public let playbackRate: Double
    public let isLive: Bool
    public let canSeek: Bool

    public init(
        itemID: String,
        playbackRequestID: UUID,
        title: String,
        seriesTitle: String?,
        artworkURL: URL?,
        artworkUserAgent: String?,
        duration: Double?,
        elapsedTime: Double,
        playbackRate: Double,
        isLive: Bool,
        canSeek: Bool
    ) {
        self.itemID = itemID
        self.playbackRequestID = playbackRequestID
        self.title = title
        self.seriesTitle = seriesTitle
        self.artworkURL = artworkURL
        self.artworkUserAgent = artworkUserAgent
        self.duration = duration
        self.elapsedTime = elapsedTime
        self.playbackRate = playbackRate
        self.isLive = isLive
        self.canSeek = canSeek
    }
}

public enum NowPlayingRemoteCommand: Equatable, Sendable {
    case play(playbackRequestID: UUID)
    case pause(playbackRequestID: UUID)
    case togglePlayback(playbackRequestID: UUID)
    case skipForward(seconds: Int64, playbackRequestID: UUID)
    case skipBackward(seconds: Int64, playbackRequestID: UUID)
    case seek(to: Double, playbackRequestID: UUID)

    public var playbackRequestID: UUID {
        switch self {
        case let .play(id), let .pause(id), let .togglePlayback(id): id
        case let .skipForward(_, id), let .skipBackward(_, id), let .seek(_, id): id
        }
    }
}

public struct NowPlayingClient: Sendable {
    public var activate: @MainActor @Sendable (UInt64) -> AsyncStream<NowPlayingRemoteCommand>
    public var update: @MainActor @Sendable (NowPlayingMetadata, Bool, UInt64) -> Void
    public var clear: @MainActor @Sendable (UInt64) -> Void
    public var deactivate: @MainActor @Sendable (UInt64) -> Void

    public init(
        activate: @escaping @MainActor @Sendable (UInt64) -> AsyncStream<NowPlayingRemoteCommand>,
        update: @escaping @MainActor @Sendable (NowPlayingMetadata, Bool, UInt64) -> Void,
        clear: @escaping @MainActor @Sendable (UInt64) -> Void,
        deactivate: @escaping @MainActor @Sendable (UInt64) -> Void
    ) {
        self.activate = activate
        self.update = update
        self.clear = clear
        self.deactivate = deactivate
    }
}

extension NowPlayingClient: DependencyKey {
    public static let liveValue: NowPlayingClient = {
        #if os(iOS)
            let session = NowPlayingSession()
            return NowPlayingClient(
                activate: { session.activate(generation: $0) },
                update: { session.update($0, force: $1, generation: $2) },
                clear: { session.clear(generation: $0) },
                deactivate: { session.deactivate(generation: $0) }
            )
        #else
            return .noop
        #endif
    }()

    public static let testValue = NowPlayingClient.noop
}

private extension NowPlayingClient {
    static var noop: NowPlayingClient {
        NowPlayingClient(
            activate: { _ in
                let (stream, continuation) = AsyncStream<NowPlayingRemoteCommand>.makeStream()
                continuation.finish()
                return stream
            },
            update: { _, _, _ in },
            clear: { _ in },
            deactivate: { _ in }
        )
    }
}

public extension DependencyValues {
    var nowPlayingClient: NowPlayingClient {
        get { self[NowPlayingClient.self] }
        set { self[NowPlayingClient.self] = newValue }
    }
}

#if os(iOS)
    // CGImage instances are immutable after ImageIO creates them and can safely
    // cross back to the main actor for the lightweight UIImage wrappers.
    private struct PreparedNowPlayingArtwork: @unchecked Sendable {
        let large: CGImage
        let medium: CGImage
        let small: CGImage
    }

    @MainActor
    private final class NowPlayingSession {
        private struct ArtworkKey: Equatable {
            let itemID: String
            let url: URL
            let userAgent: String?
        }

        private let infoCenter = MPNowPlayingInfoCenter.default()
        private let commandCenter = MPRemoteCommandCenter.shared()
        private var sessionID: UUID?
        private var generation: UInt64?
        private var continuation: AsyncStream<NowPlayingRemoteCommand>.Continuation?
        private var commandPlaybackRequestID: UUID?
        private var commandTargets: [(MPRemoteCommand, Any)] = []
        private var metadata: NowPlayingMetadata?
        private var artworkKey: ArtworkKey?
        private var artwork: UIImage?
        private var mediumArtwork: UIImage?
        private var smallArtwork: UIImage?
        private var artworkTask: Task<Void, Never>?
        private var lastPublishedElapsedTime: Double?

        func activate(generation: UInt64) -> AsyncStream<NowPlayingRemoteCommand> {
            guard self.generation.map({ generation >= $0 }) ?? true else {
                let (stream, continuation) = AsyncStream<NowPlayingRemoteCommand>.makeStream()
                continuation.finish()
                return stream
            }

            finishCurrentStream()
            self.generation = generation

            let id = UUID()
            let (stream, continuation) = AsyncStream<NowPlayingRemoteCommand>.makeStream()
            sessionID = id
            self.continuation = continuation
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, sessionID == id else { return }
                    deactivate(generation: generation)
                }
            }

            return stream
        }

        func update(_ metadata: NowPlayingMetadata, force: Bool, generation: UInt64) {
            guard continuation != nil, self.generation == generation else { return }
            if commandPlaybackRequestID != metadata.playbackRequestID, let continuation {
                installCommandTargets(using: continuation, playbackRequestID: metadata.playbackRequestID)
            }

            let nextArtworkKey = metadata.artworkURL.map {
                ArtworkKey(itemID: metadata.itemID, url: $0, userAgent: metadata.artworkUserAgent)
            }
            if nextArtworkKey != artworkKey {
                artworkTask?.cancel()
                artworkTask = nil
                artworkKey = nextArtworkKey
                artwork = nil
                mediumArtwork = nil
                smallArtwork = nil
                if let nextArtworkKey {
                    loadArtwork(for: nextArtworkKey)
                }
            }

            let previousMetadata = self.metadata
            self.metadata = metadata
            let identityChanged = previousMetadata?.itemID != metadata.itemID
                || previousMetadata?.title != metadata.title
                || previousMetadata?.seriesTitle != metadata.seriesTitle
                || previousMetadata?.isLive != metadata.isLive
                || previousMetadata?.canSeek != metadata.canSeek
                || previousMetadata?.playbackRate != metadata.playbackRate
            let elapsedChangedEnough = lastPublishedElapsedTime.map {
                metadata.elapsedTime < $0 || abs(metadata.elapsedTime - $0) >= 10
            } ?? true

            guard force || identityChanged || elapsedChangedEnough else { return }
            publishInfo()
        }

        func clear(generation: UInt64) {
            guard self.generation.map({ generation >= $0 }) ?? true else { return }
            self.generation = generation
            clearMetadata()
        }

        func deactivate(generation: UInt64) {
            guard self.generation.map({ generation >= $0 }) ?? true else { return }
            self.generation = generation
            finishCurrentStream()
        }

        private func finishCurrentStream() {
            let oldContinuation = continuation
            sessionID = nil
            continuation = nil
            clearMetadata()
            oldContinuation?.finish()
        }

        private func clearMetadata() {
            artworkTask?.cancel()
            artworkTask = nil
            artworkKey = nil
            artwork = nil
            mediumArtwork = nil
            smallArtwork = nil
            metadata = nil
            lastPublishedElapsedTime = nil
            infoCenter.nowPlayingInfo = nil
            commandPlaybackRequestID = nil
            removeCommandTargets()
        }

        private func installCommandTargets(
            using continuation: AsyncStream<NowPlayingRemoteCommand>.Continuation,
            playbackRequestID: UUID
        ) {
            removeCommandTargets()

            addTarget(commandCenter.playCommand, using: continuation) { _ in .play(playbackRequestID: playbackRequestID) }
            addTarget(commandCenter.pauseCommand, using: continuation) { _ in .pause(playbackRequestID: playbackRequestID) }
            addTarget(commandCenter.togglePlayPauseCommand, using: continuation) { _ in .togglePlayback(playbackRequestID: playbackRequestID) }
            addTarget(commandCenter.skipForwardCommand, using: continuation) { event in
                guard let event = event as? MPSkipIntervalCommandEvent else { return nil }
                return .skipForward(seconds: Self.skipInterval(event.interval), playbackRequestID: playbackRequestID)
            }
            addTarget(commandCenter.skipBackwardCommand, using: continuation) { event in
                guard let event = event as? MPSkipIntervalCommandEvent else { return nil }
                return .skipBackward(seconds: Self.skipInterval(event.interval), playbackRequestID: playbackRequestID)
            }
            addTarget(commandCenter.changePlaybackPositionCommand, using: continuation) { event in
                guard let event = event as? MPChangePlaybackPositionCommandEvent,
                      event.positionTime.isFinite
                else { return nil }
                return .seek(to: event.positionTime, playbackRequestID: playbackRequestID)
            }

            commandCenter.skipForwardCommand.preferredIntervals = [15]
            commandCenter.skipBackwardCommand.preferredIntervals = [15]
            commandPlaybackRequestID = playbackRequestID
            setCommandAvailability(hasItem: false, canSeek: false)
        }

        private func addTarget(
            _ command: MPRemoteCommand,
            using continuation: AsyncStream<NowPlayingRemoteCommand>.Continuation,
            transform: @escaping @Sendable (MPRemoteCommandEvent) -> NowPlayingRemoteCommand?
        ) {
            let token = command.addTarget { event in
                guard let remoteCommand = transform(event) else { return .commandFailed }
                continuation.yield(remoteCommand)
                return .success
            }
            commandTargets.append((command, token))
        }

        private func removeCommandTargets() {
            for (command, token) in commandTargets {
                command.removeTarget(token)
            }
            commandTargets.removeAll()
            setCommandAvailability(hasItem: false, canSeek: false)
        }

        private func setCommandAvailability(hasItem: Bool, canSeek: Bool) {
            commandCenter.playCommand.isEnabled = hasItem
            commandCenter.pauseCommand.isEnabled = hasItem
            commandCenter.togglePlayPauseCommand.isEnabled = hasItem
            commandCenter.skipForwardCommand.isEnabled = hasItem && canSeek
            commandCenter.skipBackwardCommand.isEnabled = hasItem && canSeek
            commandCenter.changePlaybackPositionCommand.isEnabled = hasItem && canSeek
        }

        private func publishInfo() {
            guard let metadata else {
                infoCenter.nowPlayingInfo = nil
                lastPublishedElapsedTime = nil
                setCommandAvailability(hasItem: false, canSeek: false)
                return
            }

            var info: [String: Any] = [
                MPMediaItemPropertyTitle: metadata.title,
                MPNowPlayingInfoPropertyPlaybackRate: metadata.playbackRate,
            ]
            if let seriesTitle = metadata.seriesTitle, !seriesTitle.isEmpty {
                info[MPMediaItemPropertyAlbumTitle] = seriesTitle
            }
            if metadata.isLive {
                info[MPNowPlayingInfoPropertyIsLiveStream] = true
            } else {
                info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = max(0, metadata.elapsedTime)
                if let duration = metadata.duration, duration.isFinite, duration > 0 {
                    info[MPMediaItemPropertyPlaybackDuration] = duration
                }
            }
            if let artwork {
                let mediumArtwork = self.mediumArtwork ?? artwork
                let smallArtwork = self.smallArtwork ?? mediumArtwork
                info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { requestedSize in
                    let requestedDimension = max(requestedSize.width, requestedSize.height)
                    if requestedDimension <= max(smallArtwork.size.width, smallArtwork.size.height) {
                        return smallArtwork
                    }
                    if requestedDimension <= max(mediumArtwork.size.width, mediumArtwork.size.height) {
                        return mediumArtwork
                    }
                    return artwork
                }
            }

            infoCenter.nowPlayingInfo = info
            lastPublishedElapsedTime = metadata.elapsedTime
            setCommandAvailability(hasItem: true, canSeek: metadata.canSeek && !metadata.isLive)
        }

        private func loadArtwork(for key: ArtworkKey) {
            let sessionID = sessionID
            artworkTask = Task { [weak self] in
                guard let preparedArtwork = await Self.prepareArtwork(url: key.url, userAgent: key.userAgent),
                      !Task.isCancelled,
                      let self,
                      self.sessionID == sessionID,
                      self.artworkKey == key
                else { return }

                self.artwork = UIImage(cgImage: preparedArtwork.large)
                self.mediumArtwork = UIImage(cgImage: preparedArtwork.medium)
                self.smallArtwork = UIImage(cgImage: preparedArtwork.small)
                publishInfo()
            }
        }

        @concurrent
        private static func prepareArtwork(url: URL, userAgent: String?) async -> PreparedNowPlayingArtwork? {
            var request = URLRequest(url: url)
            request.cachePolicy = .returnCacheDataElseLoad
            request.timeoutInterval = 12
            if let userAgent,
               userAgent.utf8.count <= 512,
               !userAgent.contains("\r"),
               !userAgent.contains("\n")
            {
                request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
            }

            let maximumBytes = 10 * 1024 * 1024
            guard let (bytes, response) = try? await URLSession.shared.bytes(for: request),
                  let response = response as? HTTPURLResponse,
                  (200 ..< 300).contains(response.statusCode),
                  response.mimeType?.lowercased().hasPrefix("image/") != false,
                  response.expectedContentLength < 0 || response.expectedContentLength <= Int64(maximumBytes)
            else { return nil }

            var data = Data()
            data.reserveCapacity(response.expectedContentLength > 0
                ? Int(response.expectedContentLength)
                : 512 * 1024)
            do {
                for try await byte in bytes {
                    guard !Task.isCancelled, data.count < maximumBytes else { return nil }
                    data.append(byte)
                }
            } catch {
                return nil
            }

            let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
            guard !Task.isCancelled,
                  let imageSource = CGImageSourceCreateWithData(data as CFData, sourceOptions)
            else { return nil }

            func thumbnail(maximumPixelSize: Int) -> CGImage? {
                let options = [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceThumbnailMaxPixelSize: maximumPixelSize,
                    kCGImageSourceShouldCacheImmediately: true,
                ] as CFDictionary
                return CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options)
            }

            guard let large = thumbnail(maximumPixelSize: 512),
                  let medium = thumbnail(maximumPixelSize: 256),
                  let small = thumbnail(maximumPixelSize: 128),
                  !Task.isCancelled
            else { return nil }

            return PreparedNowPlayingArtwork(large: large, medium: medium, small: small)
        }

        private nonisolated static func skipInterval(_ interval: TimeInterval) -> Int64 {
            guard interval.isFinite else { return 15 }
            return Int64(max(1, min(300, interval.rounded())))
        }
    }
#endif
