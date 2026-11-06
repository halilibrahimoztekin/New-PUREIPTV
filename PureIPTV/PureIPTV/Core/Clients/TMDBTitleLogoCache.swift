import Combine
import Foundation

/// Shares title-logo paths learned on detail screens with visible catalog cards.
/// It keeps a bounded in-memory view cache and persists only a small path index.
@MainActor
final class TMDBTitleLogoCache: ObservableObject {
    static let shared = TMDBTitleLogoCache()

    private(set) var logos: [String: TMDBTitleLogo] = [:]
    private var insertionOrder: [String] = []
    private let capacity = 300

    private init() {
        Task { [weak self] in
            async let storedLogoPaths = TMDBTitleLogoPersistence.shared.loadLogos()
            async let storedBackdropPaths = TMDBTitleLogoPersistence.shared.loadBackdrops()
            let (logoPaths, backdropPaths) = await (storedLogoPaths, storedBackdropPaths)
            guard let self else { return }
            for (key, path) in logoPaths {
                let logo = logo(for: key)
                if logo.path == nil {
                    logo.path = path
                }
            }
            for (key, path) in backdropPaths {
                let logo = logo(for: key)
                if logo.backdropPath == nil {
                    logo.backdropPath = path
                }
            }
        }
    }

    func logo(for key: String?) -> TMDBTitleLogo {
        guard let key else { return .empty }
        if let existing = logos[key] {
            touch(key)
            return existing
        }

        let logo = TMDBTitleLogo()
        logos[key] = logo
        touch(key)
        return logo
    }

    func insert(_ path: String?, for key: String?) {
        guard let path, !path.isEmpty, let key else { return }

        let logo = logo(for: key)
        logo.path = path
        Task {
            await TMDBTitleLogoPersistence.shared.store(path, for: key)
        }
    }

    func insertBackdrop(_ path: String?, for key: String?) {
        guard let path, !path.isEmpty, let key else { return }

        let artwork = logo(for: key)
        artwork.backdropPath = path
        Task {
            await TMDBTitleLogoPersistence.shared.storeBackdrop(path, for: key)
        }
    }

    func markTitleAssetsResolved(for key: String?) {
        guard let key else { return }
        logo(for: key).didResolveTitleAssets = true
    }

    private func touch(_ key: String) {
        insertionOrder.removeAll { $0 == key }
        insertionOrder.append(key)

        while insertionOrder.count > capacity {
            logos.removeValue(forKey: insertionOrder.removeFirst())
        }
    }

    nonisolated static func key(for item: MediaModels.Item, mediaType: String) -> String {
        "\(item.playlistID?.uuidString ?? "shared")|\(mediaType)|\(item.id)"
    }
}

@MainActor
final class TMDBTitleLogo: ObservableObject {
    static let empty = TMDBTitleLogo()

    @Published var path: String?
    @Published var backdropPath: String?
    @Published var didResolveTitleAssets = false
}

private actor TMDBTitleLogoPersistence {
    static let shared = TMDBTitleLogoPersistence()

    private let logoStorageKey = "com.pureiptv.tmdb.title-logo-paths.v2"
    private let backdropStorageKey = "com.pureiptv.tmdb.title-backdrop-paths.v2"
    private let capacity = 300
    private var didLoad = false
    private var paths: [String: String] = [:]
    private var insertionOrder: [String] = []
    private var didLoadBackdrops = false
    private var backdropPaths: [String: String] = [:]
    private var backdropInsertionOrder: [String] = []

    func loadLogos() -> [String: String] {
        loadLogosIfNeeded()
        return paths
    }

    func loadBackdrops() -> [String: String] {
        loadBackdropsIfNeeded()
        return backdropPaths
    }

    func store(_ path: String, for key: String) {
        loadLogosIfNeeded()
        paths[key] = path
        insertionOrder.removeAll { $0 == key }
        insertionOrder.append(key)

        while insertionOrder.count > capacity {
            paths.removeValue(forKey: insertionOrder.removeFirst())
        }

        UserDefaults.standard.set(paths, forKey: logoStorageKey)
        UserDefaults.standard.set(insertionOrder, forKey: "\(logoStorageKey).order")
    }

    func storeBackdrop(_ path: String, for key: String) {
        loadBackdropsIfNeeded()
        backdropPaths[key] = path
        backdropInsertionOrder.removeAll { $0 == key }
        backdropInsertionOrder.append(key)

        while backdropInsertionOrder.count > capacity {
            backdropPaths.removeValue(forKey: backdropInsertionOrder.removeFirst())
        }

        UserDefaults.standard.set(backdropPaths, forKey: backdropStorageKey)
        UserDefaults.standard.set(backdropInsertionOrder, forKey: "\(backdropStorageKey).order")
    }

    private func loadLogosIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        paths = UserDefaults.standard.dictionary(forKey: logoStorageKey) as? [String: String] ?? [:]
        insertionOrder = UserDefaults.standard.stringArray(forKey: "\(logoStorageKey).order") ?? Array(paths.keys)
        insertionOrder = insertionOrder.filter { paths[$0] != nil }

        while insertionOrder.count > capacity {
            paths.removeValue(forKey: insertionOrder.removeFirst())
        }
    }

    private func loadBackdropsIfNeeded() {
        guard !didLoadBackdrops else { return }
        didLoadBackdrops = true
        backdropPaths = UserDefaults.standard.dictionary(forKey: backdropStorageKey) as? [String: String] ?? [:]
        backdropInsertionOrder = UserDefaults.standard.stringArray(forKey: "\(backdropStorageKey).order") ?? Array(backdropPaths.keys)
        backdropInsertionOrder = backdropInsertionOrder.filter { backdropPaths[$0] != nil }

        while backdropInsertionOrder.count > capacity {
            backdropPaths.removeValue(forKey: backdropInsertionOrder.removeFirst())
        }
    }
}
