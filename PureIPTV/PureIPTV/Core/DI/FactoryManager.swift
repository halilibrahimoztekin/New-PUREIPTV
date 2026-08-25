import Factory
import Foundation
import UIKit

// MARK: - Factory Manager

public final class FactoryManager {
    public static let shared = FactoryManager()
    private init() {}
}

public extension Container {
    /// App Coordinator
    var appCoordinator: Factory<AppCoordinator> {
        self { @MainActor in
            AppCoordinator()
        }.singleton
    }

    /// IPTV Client
    var iptvClient: Factory<IPTVClient> {
        self { IPTVClient.liveValue }
    }

    /// Player Client (SwiftVLC)
    var playerClient: Factory<PlayerClient> {
        self { PlayerClient.liveValue }.singleton
    }

    /// TMDB Client
    var tmdbClient: Factory<TMDBClient> {
        self { TMDBClient.liveValue }
    }
}
