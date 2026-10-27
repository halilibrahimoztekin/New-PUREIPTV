import SwiftUI
#if os(iOS)
    import WebKit

    public struct TrailerPlaybackFailure: Equatable, Sendable {
        public let code: Int

        public var message: String {
            switch code {
            case -2: AppStrings.VODDetail.trailerPlaybackTimedOut
            case -1: AppStrings.VODDetail.trailerPlaybackAutoplayBlocked
            case 2: AppStrings.VODDetail.trailerPlaybackInvalidRequest
            case 5: AppStrings.VODDetail.trailerPlaybackPlayerError
            case 100: AppStrings.VODDetail.trailerPlaybackUnavailable
            case 101, 150: AppStrings.VODDetail.trailerPlaybackEmbeddingDisabled
            case 153: AppStrings.VODDetail.trailerPlaybackClientIdentityRequired
            default: AppStrings.VODDetail.trailerPlaybackUnknown(code)
            }
        }

        fileprivate init(code: Int) {
            self.code = code
        }
    }

    public struct TrailerWebView: UIViewRepresentable {
        public let videoKey: String
        public let isMuted: Bool
        public let showControls: Bool
        public let retryAttempt: Int
        public let onPlaybackFailure: (TrailerPlaybackFailure) -> Void

        public init(
            videoKey: String,
            isMuted: Bool = false,
            showControls: Bool = true,
            retryAttempt: Int = 0,
            onPlaybackFailure: @escaping (TrailerPlaybackFailure) -> Void = { _ in }
        ) {
            self.videoKey = videoKey
            self.isMuted = isMuted
            self.showControls = showControls
            self.retryAttempt = retryAttempt
            self.onPlaybackFailure = onPlaybackFailure
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        public final class Coordinator: NSObject, WKScriptMessageHandler, @unchecked Sendable {
            var currentVideoKey: String?
            var currentMuted: Bool?
            var currentRetryAttempt: Int?
            var onPlaybackFailure: ((TrailerPlaybackFailure) -> Void)?

            public func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
                guard
                    message.name == "trailerPlaybackFailure",
                    let payload = message.body as? [String: Any],
                    let attempt = payload["attempt"] as? Int,
                    attempt == currentRetryAttempt,
                    let code = payload["code"] as? Int
                else { return }

                let failure = TrailerPlaybackFailure(code: code)
                Task { @MainActor [weak self] in
                    self?.onPlaybackFailure?(failure)
                }
            }
        }

        public func makeUIView(context: Context) -> WKWebView {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []
            config.userContentController.add(context.coordinator, name: "trailerPlaybackFailure")

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.backgroundColor = .black
            webView.isOpaque = false
            webView.scrollView.isScrollEnabled = false
            return webView
        }

        public func updateUIView(_ uiView: WKWebView, context: Context) {
            let coordinator = context.coordinator
            coordinator.onPlaybackFailure = onPlaybackFailure

            if coordinator.currentVideoKey != videoKey || coordinator.currentRetryAttempt != retryAttempt {
                coordinator.currentVideoKey = videoKey
                coordinator.currentRetryAttempt = retryAttempt
                coordinator.currentMuted = isMuted

                let muteParam = isMuted ? 1 : 0
                let controlsParam = showControls ? 1 : 0
                var components = URLComponents()
                components.scheme = "https"
                components.host = "www.youtube.com"
                components.path = "/embed/\(videoKey)"
                components.queryItems = [
                    URLQueryItem(name: "autoplay", value: "1"),
                    URLQueryItem(name: "playsinline", value: "1"),
                    URLQueryItem(name: "rel", value: "0"),
                    URLQueryItem(name: "modestbranding", value: "1"),
                    URLQueryItem(name: "enablejsapi", value: "1"),
                    URLQueryItem(name: "origin", value: "https://www.youtube.com"),
                    URLQueryItem(name: "mute", value: "\(muteParam)"),
                    URLQueryItem(name: "controls", value: "\(controlsParam)"),
                ]

                guard let embedURL = components.url?.absoluteString.replacingOccurrences(of: "&", with: "&amp;") else {
                    onPlaybackFailure(TrailerPlaybackFailure(code: 2))
                    return
                }

                let embedHTML = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
                    <style>
                        * { margin: 0; padding: 0; box-sizing: border-box; background-color: #000; }
                        body { overflow: hidden; display: flex; align-items: center; justify-content: center; height: 100vh; }
                        iframe { width: 100%; height: 100%; border: none; }
                    </style>
                </head>
                <body>
                    <iframe id="trailerPlayer"
                            src="\(embedURL)"
                            allow="autoplay; encrypted-media; picture-in-picture" 
                            allowfullscreen>
                    </iframe>
                    <script>
                        let trailerPlaybackStarted = false;
                        let trailerFailureReported = false;
                        const trailerRetryAttempt = \(retryAttempt);
                        const trailerStartupTimer = setTimeout(() => {
                            if (!trailerPlaybackStarted) reportTrailerFailure(-2);
                        }, 20000);

                        function reportTrailerFailure(code) {
                            if (trailerFailureReported) return;
                            trailerFailureReported = true;
                            window.webkit.messageHandlers.trailerPlaybackFailure.postMessage({
                                attempt: trailerRetryAttempt,
                                code: code
                            });
                        }

                        function onYouTubeIframeAPIReady() {
                            new YT.Player('trailerPlayer', {
                                events: {
                                    onError: event => reportTrailerFailure(event.data),
                                    onAutoplayBlocked: () => reportTrailerFailure(-1),
                                    onStateChange: event => {
                                        if (event.data === YT.PlayerState.PLAYING) {
                                            trailerPlaybackStarted = true;
                                            clearTimeout(trailerStartupTimer);
                                        }
                                    }
                                }
                            });
                        }
                    </script>
                    <script src="https://www.youtube.com/iframe_api"></script>
                </body>
                </html>
                """
                uiView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
            } else if coordinator.currentMuted != isMuted {
                coordinator.currentMuted = isMuted
                let funcName = isMuted ? "mute" : "unMute"
                let js = """
                document.getElementById('trailerPlayer')?.contentWindow?.postMessage('{"event":"command","func":"\(funcName)","args":""}', '*');
                """
                uiView.evaluateJavaScript(js, completionHandler: nil)
            }
        }
    }

    public struct TrailerPlaybackView: View {
        public let videoKey: String
        public let isMuted: Bool
        public let showControls: Bool

        @State private var retryAttempt = 0
        @State private var playbackFailure: TrailerPlaybackFailure?

        public init(videoKey: String, isMuted: Bool = false, showControls: Bool = true) {
            self.videoKey = videoKey
            self.isMuted = isMuted
            self.showControls = showControls
        }

        public var body: some View {
            ZStack {
                TrailerWebView(
                    videoKey: videoKey,
                    isMuted: isMuted,
                    showControls: showControls,
                    retryAttempt: retryAttempt,
                    onPlaybackFailure: { playbackFailure = $0 }
                )

                if let playbackFailure {
                    Color.black.opacity(0.82)
                    TrailerPlaybackFailureOverlay(failure: playbackFailure) {
                        self.playbackFailure = nil
                        retryAttempt += 1
                    }
                    .padding(20)
                }
            }
        }
    }

    public struct TrailerPlaybackFailureOverlay: View {
        public let failure: TrailerPlaybackFailure
        public let onRetry: () -> Void

        public init(failure: TrailerPlaybackFailure, onRetry: @escaping () -> Void) {
            self.failure = failure
            self.onRetry = onRetry
        }

        public var body: some View {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .accessibilityHidden(true)

                Text(AppStrings.VODDetail.trailerPlaybackFailed)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(failure.message)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
                    .multilineTextAlignment(.center)

                Button(action: onRetry) {
                    Label(AppStrings.Common.retry, systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            .frame(maxWidth: 360)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .accessibilityElement(children: .contain)
        }
    }
#endif
