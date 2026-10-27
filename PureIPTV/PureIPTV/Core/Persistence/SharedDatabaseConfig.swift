import Foundation
import SwiftData

public nonisolated enum SharedDatabaseConfig {
    /// Serializes the first store open and caches only a successfully created container.
    private nonisolated final class ContainerCache: @unchecked Sendable {
        private let lock = NSLock()
        private var container: ModelContainer?

        func load() throws -> ModelContainer {
            lock.lock()
            defer { lock.unlock() }
            if let container {
                return container
            }
            let container = try SharedDatabaseConfig.createModelContainer()
            self.container = container
            return container
        }
    }
    private nonisolated static let cache = ContainerCache()
    public static var cloudModels: [any PersistentModel.Type] {
        [
            FavoriteItem.self,
            WatchHistoryItem.self,
            CategoryPreference.self,
            SearchHistoryItem.self,
            UserProfile.self,
        ]
    }

    public static var localModels: [any PersistentModel.Type] {
        [
            OfflineMedia.self,
        ]
    }

    public static var schema: Schema {
        Schema(cloudModels + localModels)
    }

    public static func createConfigurations() -> [ModelConfiguration] {
        let fileManager = FileManager.default
        let groupURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pureiptv.shared")

        let cloudSchema = Schema(cloudModels)
        let localSchema = Schema(localModels)

        if let groupURL {
            let cloudURL = groupURL.appendingPathComponent("PureIPTV.sqlite")
            let localURL = groupURL.appendingPathComponent("PureIPTV_Local.sqlite")

            let cloudConfig = ModelConfiguration("Cloud", schema: cloudSchema, url: cloudURL, cloudKitDatabase: .automatic)
            let localConfig = ModelConfiguration("Local", schema: localSchema, url: localURL, cloudKitDatabase: .none)
            return [cloudConfig, localConfig]
        } else {
            let cloudConfig = ModelConfiguration("Cloud", schema: cloudSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .automatic)
            let localConfig = ModelConfiguration("Local", schema: localSchema, isStoredInMemoryOnly: false, cloudKitDatabase: .none)
            return [cloudConfig, localConfig]
        }
    }

    public static var shared: ModelContainer {
        get throws {
            try cache.load()
        }
    }

    public static func createModelContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: createConfigurations())
    }
}
