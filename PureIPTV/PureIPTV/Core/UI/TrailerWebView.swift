import SwiftUI
#if os(iOS)
    import WebKit

    public struct TrailerWebView: UIViewRepresentable {
        public let videoKey: String
        public let isMuted: Bool
        public let showControls: Bool

        public init(videoKey: String, isMuted: Bool = false, showControls: Bool = true) {
            self.videoKey = videoKey
            self.isMuted = isMuted
            self.showControls = showControls
        }

        public func makeCoordinator() -> Coordinator {
            Coordinator()
        }

        public final class Coordinator: NSObject, @unchecked Sendable {
            var currentVideoKey: String?
            var currentMuted: Bool?
        }

        public func makeUIView(context _: Context) -> WKWebView {
            let config = WKWebViewConfiguration()
            config.allowsInlineMediaPlayback = true
            config.mediaTypesRequiringUserActionForPlayback = []

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.backgroundColor = .black
            webView.isOpaque = false
            webView.scrollView.isScrollEnabled = false
            return webView
        }

        public func updateUIView(_ uiView: WKWebView, context: Context) {
            let coordinator = context.coordinator

            if coordinator.currentVideoKey != videoKey {
                coordinator.currentVideoKey = videoKey
                coordinator.currentMuted = isMuted

                let muteParam = isMuted ? 1 : 0
                let controlsParam = showControls ? 1 : 0

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
                            src="https://www.youtube.com/embed/\(videoKey)?autoplay=1&playsinline=1&rel=0&modestbranding=1&enablejsapi=1&mute=\(muteParam)&controls=\(controlsParam)" 
                            allow="autoplay; encrypted-media; picture-in-picture" 
                            allowfullscreen>
                    </iframe>
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
#endif
