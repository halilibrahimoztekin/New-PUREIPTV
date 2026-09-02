import FactoryKit
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
        self {
            AppCoordinator()
        }.singleton
    }

    /// IPTV Client
    var iptvClient: Factory<IPTVClient> {
        self { .liveValue }
    }

    /// Player Client (SwiftVLC)
    var playerClient: Factory<PlayerClient> {
        self { .liveValue }.singleton
    }

    /// TMDB Client
    var tmdbClient: Factory<TMDBClient> {
        self { .liveValue }
    }
}
