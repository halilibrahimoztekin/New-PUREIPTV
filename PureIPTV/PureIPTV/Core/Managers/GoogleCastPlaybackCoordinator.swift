#if os(iOS)
    import Foundation
    @preconcurrency import GoogleCast

    @MainActor
    final class GoogleCastPlaybackCoordinator: NSObject, GCKSessionManagerListener, GCKRequestDelegate {
        static let shared = GoogleCastPlaybackCoordinator()

        private struct PendingCast {
            let id: UUID
            let mediaInformation: GCKMediaInformation
            let isLive: Bool
            let startingPosition: TimeInterval
            let onRemotePlaybackStarted: () -> Void
            let onSessionEnded: () -> Void
            var didLoad = false
            var requestSent = false
        }

        private var pendingCast: PendingCast?
        private var activeLoadRequest: GCKRequest?
        private var activeLoadCastID: UUID?
        private var activeSessionEndHandler: (() -> Void)?
        private var castDialogObserver: NSObjectProtocol?
        private var didConfigure = false
        private var isCastDialogVisible = false
        private var isStartingCastSession = false

        override private init() {
            super.init()
        }

        private var receiverApplicationID: String {
            let configuredID = Bundle.main.object(forInfoDictionaryKey: "GoogleCastReceiverApplicationID") as? String
            let trimmedID = configuredID?.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmedID.flatMap { $0.isEmpty ? nil : $0 } ?? kGCKDefaultMediaReceiverApplicationID
        }

        private var usesDefaultReceiver: Bool {
            receiverApplicationID == kGCKDefaultMediaReceiverApplicationID
        }

        var isConfigured: Bool {
            isValidReceiverApplicationID(receiverApplicationID) && !usesDefaultReceiver
        }

        func configureIfNeeded() {
            guard !didConfigure, isConfigured else { return }

            let criteria = GCKDiscoveryCriteria(applicationID: receiverApplicationID)
            let options = GCKCastOptions(discoveryCriteria: criteria)
            GCKCastContext.setSharedInstanceWith(options)

            let context = GCKCastContext.sharedInstance()
            context.useDefaultExpandedMediaControls = true
            context.sessionManager.add(self)
            castDialogObserver = NotificationCenter.default.addObserver(
                forName: .gckuiCastDialogDidHide,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.castDialogDidHide()
                }
            }
            didConfigure = true
        }

        func canCast(item: PlayerFeature.PlayableItem, streamURL: URL) -> Bool {
            guard isConfigured,
                  let scheme = streamURL.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  contentType(for: streamURL) != nil,
                  item.config?.mediaServerCredentials == nil,
                  item.config?.type != .plex,
                  item.config?.type != .emby
            else { return false }

            if let userAgent = item.userAgentOverride {
                let trimmedUserAgent = userAgent.trimmingCharacters(in: .whitespacesAndNewlines)
                guard ["m3u8", "mpd"].contains(streamURL.pathExtension.lowercased()),
                      !trimmedUserAgent.isEmpty,
                      trimmedUserAgent.utf8.count <= 1024,
                      trimmedUserAgent.rangeOfCharacter(from: .controlCharacters) == nil
                else { return false }
            }

            return true
        }

        func cast(
            item: PlayerFeature.PlayableItem,
            streamURL: URL,
            startingPosition: TimeInterval,
            onRemotePlaybackStarted: @escaping () -> Void,
            onSessionEnded: @escaping () -> Void
        ) {
            guard canCast(item: item, streamURL: streamURL) else { return }
            configureIfNeeded()
            cancelActiveLoadRequest()

            let metadata = GCKMediaMetadata(metadataType: .generic)
            metadata.setString(item.title, forKey: kGCKMetadataKeyTitle)
            if let seriesTitle = item.seriesTitle {
                metadata.setString(seriesTitle, forKey: kGCKMetadataKeySubtitle)
            }

            let builder = GCKMediaInformationBuilder(contentURL: streamURL)
            builder.contentID = "pureiptv-\(UUID().uuidString)"
            builder.streamType = item.isLive ? .live : .buffered
            builder.contentType = contentType(for: streamURL) ?? "application/octet-stream"
            builder.metadata = metadata

            if let userAgent = item.userAgentOverride?.trimmingCharacters(in: .whitespacesAndNewlines) {
                builder.customData = ["httpHeaders": ["User-Agent": userAgent]]
            }

            pendingCast = PendingCast(
                id: UUID(),
                mediaInformation: builder.build(),
                isLive: item.isLive,
                startingPosition: max(0, startingPosition),
                onRemotePlaybackStarted: onRemotePlaybackStarted,
                onSessionEnded: onSessionEnded
            )

            isCastDialogVisible = true
            GCKCastContext.sharedInstance().presentCastDialog()
            if let session = GCKCastContext.sharedInstance().sessionManager.currentCastSession {
                loadPendingCast(in: session)
            }
        }

        func sessionManager(_: GCKSessionManager, willStart _: GCKCastSession) {
            isStartingCastSession = true
        }

        func sessionManager(_: GCKSessionManager, didStart session: GCKCastSession) {
            isStartingCastSession = false
            loadPendingCast(in: session)
        }

        func sessionManager(
            _: GCKSessionManager,
            didFailToStart _: GCKCastSession,
            withError _: Error
        ) {
            isStartingCastSession = false
            finishActiveCastSession()
        }

        func sessionManager(
            _: GCKSessionManager,
            didEnd _: GCKCastSession,
            withError _: Error?
        ) {
            cancelActiveLoadRequest()
            if !isCastDialogVisible, !isStartingCastSession {
                finishActiveCastSession()
            }
        }

        func requestDidComplete(_ request: GCKRequest) {
            handleLoadRequest(request, succeeded: true)
        }

        func request(_ request: GCKRequest, didFailWithError _: GCKError) {
            handleLoadRequest(request, succeeded: false)
        }

        func request(_ request: GCKRequest, didAbortWith _: GCKRequestAbortReason) {
            guard request === activeLoadRequest else { return }
            cancelActiveLoadRequest()
            if !isCastDialogVisible {
                if sessionManager.currentCastSession == nil {
                    finishActiveCastSession()
                } else {
                    pendingCast = nil
                }
            }
        }

        private var sessionManager: GCKSessionManager {
            GCKCastContext.sharedInstance().sessionManager
        }

        private func loadPendingCast(in session: GCKCastSession) {
            guard var pendingCast,
                  !pendingCast.requestSent,
                  let remoteMediaClient = session.remoteMediaClient
            else { return }

            let request: GCKRequest = if pendingCast.isLive {
                remoteMediaClient.loadMedia(pendingCast.mediaInformation)
            } else {
                remoteMediaClient.loadMedia(
                    pendingCast.mediaInformation,
                    autoplay: true,
                    playPosition: pendingCast.startingPosition
                )
            }
            pendingCast.requestSent = true
            self.pendingCast = pendingCast
            activeLoadRequest = request
            activeLoadCastID = pendingCast.id
            request.delegate = self
        }

        private func handleLoadRequest(_ request: GCKRequest, succeeded: Bool) {
            guard request === activeLoadRequest,
                  let castID = activeLoadCastID,
                  var pendingCast,
                  pendingCast.id == castID
            else { return }

            activeLoadRequest = nil
            activeLoadCastID = nil
            pendingCast.requestSent = false

            guard succeeded else {
                let shouldResumeLocalPlayback = pendingCast.didLoad
                self.pendingCast = nil
                if shouldResumeLocalPlayback {
                    finishActiveCastSession()
                }
                return
            }

            pendingCast.didLoad = true
            self.pendingCast = pendingCast
            activeSessionEndHandler = pendingCast.onSessionEnded
            pendingCast.onRemotePlaybackStarted()
            GCKCastContext.sharedInstance().presentDefaultExpandedMediaControls()

            if !isCastDialogVisible, sessionManager.currentCastSession != nil {
                self.pendingCast = nil
            }
        }

        private func castDialogDidHide() {
            isCastDialogVisible = false
            guard !isStartingCastSession else { return }

            if sessionManager.currentCastSession == nil {
                finishActiveCastSession()
            } else if pendingCast?.didLoad == true {
                pendingCast = nil
            } else if pendingCast?.requestSent == false {
                pendingCast = nil
            }
        }

        private func finishActiveCastSession() {
            cancelActiveLoadRequest()
            pendingCast = nil
            let onSessionEnded = activeSessionEndHandler
            activeSessionEndHandler = nil
            onSessionEnded?()
        }

        private func cancelActiveLoadRequest() {
            activeLoadRequest?.delegate = nil
            activeLoadRequest?.cancel()
            activeLoadRequest = nil
            activeLoadCastID = nil

            if var pendingCast {
                pendingCast.requestSent = false
                self.pendingCast = pendingCast
            }
        }

        private func isValidReceiverApplicationID(_ value: String) -> Bool {
            value.range(of: "^[A-Za-z0-9]{8}$", options: .regularExpression) != nil
        }

        private func contentType(for url: URL) -> String? {
            switch url.pathExtension.lowercased() {
            case "m3u8":
                "application/x-mpegURL"
            case "mpd":
                "application/dash+xml"
            case "ts":
                "video/mp2t"
            case "mp4", "m4v":
                "video/mp4"
            default:
                nil
            }
        }

    }
#endif
