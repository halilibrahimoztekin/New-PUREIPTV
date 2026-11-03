import ComposableArchitecture
import SwiftUI

struct DetailTrailerRouteContent: View {
    let videoKey: String
    let close: () -> Void

    var body: some View {
        #if os(tvOS)
            Button(AppStrings.Common.close, action: close)
        #else
            iOSContent
        #endif
    }

    #if !os(tvOS)
        private var iOSContent: some View {
            Group {
                if let trailerURL {
                    SafariModalPresenter(url: trailerURL, onDismiss: close)
                        .ignoresSafeArea()
                } else {
                    VStack(spacing: 16) {
                        Text(AppStrings.VODDetail.trailerNotAvailable)
                            .foregroundStyle(AppColors.textPrimary)
                        Button(AppStrings.Common.close, action: close)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppColors.oledBlack.ignoresSafeArea())
        }

        private var trailerURL: URL? {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.youtube.com"
            components.path = "/watch"
            components.queryItems = [URLQueryItem(name: "v", value: videoKey)]
            return components.url
        }
    #endif
}
