import ComposableArchitecture
import SwiftUI

// MARK: - Platform Router

// This view is the single entry point for the Splash feature.
// It delegates rendering to the platform-specific view at compile time
// using conditional compilation — no runtime overhead.

public struct SplashView: View {
    let store: StoreOf<SplashFeature>

    public init(store: StoreOf<SplashFeature>) {
        self.store = store
    }

    public var body: some View {
        #if os(tvOS)
            SplashView_tvOS(store: store)
        #else
            // iOS, iPadOS — same layout, iPad benefits from extra breathing room
            // via adaptive padding/font sizes in SplashView_iOS
            SplashView_iOS(store: store)
        #endif
    }
}
