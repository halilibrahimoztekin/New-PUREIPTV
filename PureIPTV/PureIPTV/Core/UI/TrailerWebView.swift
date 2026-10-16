import SwiftUI
#if os(iOS)
    import WebKit

    public struct TrailerWebView: UIViewRepresentable {
        public let videoKey: String

        public init(videoKey: String) {
            self.videoKey = videoKey
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

        public func updateUIView(_ uiView: WKWebView, context _: Context) {
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
                <iframe src="https://www.youtube.com/embed/\(videoKey)?autoplay=1&playsinline=1&rel=0&modestbranding=1" 
                        allow="autoplay; encrypted-media; picture-in-picture" 
                        allowfullscreen>
                </iframe>
            </body>
            </html>
            """
            uiView.loadHTMLString(embedHTML, baseURL: URL(string: "https://www.youtube.com"))
        }
    }
#endif
