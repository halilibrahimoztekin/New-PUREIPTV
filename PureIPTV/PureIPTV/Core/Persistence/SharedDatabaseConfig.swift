import Foundation
import SwiftData

public nonisolated enum SharedDatabaseConfig {
    /// Serializes the first store open and caches only a successfully created container.
    private final nonisolated class ContainerCache: @unchecked Sendable {
        private let lock = NSLock()
        private var container: ModelContainer?

        func load() throws -> ModelContainer {
            lock.lock()
            defer { lock.unlock() }
            if let container {
                return container
            }
            let container: ModelContainer
            do {
                container = try SharedDatabaseConfig.createModelContainer()
            } catch {
                // Never make the whole app unusable because the primary store could not
                // migrate or open. Keep it untouched and open a separate recovery store.
                // The original database can then be diagnosed or migrated in a later release.
                do {
                    container = try SharedDatabaseConfig.createRecoveryModelContainer()
                } catch {
                    // Last resort: still let users reach the app. This store is session-only
                    // and does not overwrite either persistent database.
                    container = try SharedDatabaseConfig.createInMemoryModelContainer()
                }
            }
            self.container = container
            return container
        }
    }

    private nonisolated static let cache = ContainerCache()
    public static var cloudModels: [any PersistentModel.Type] {
        [
            FavoriteItem.self,
            WatchHistoryItem.self,
            HiddenMediaRecord.self,
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

    private static func createRecoveryModelContainer() throws -> ModelContainer {
        let fileManager = FileManager.default
        let baseURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: "group.com.pureiptv.shared")
            ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let cloudConfig = ModelConfiguration(
            "RecoveryCloud",
            schema: Schema(cloudModels),
            url: baseURL.appendingPathComponent("PureIPTV_Recovery.sqlite"),
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "RecoveryLocal",
            schema: Schema(localModels),
            url: baseURL.appendingPathComponent("PureIPTV_Local_Recovery.sqlite"),
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [cloudConfig, localConfig])
    }

    private static func createInMemoryModelContainer() throws -> ModelContainer {
        let cloudConfig = ModelConfiguration(
            "SessionCloud",
            schema: Schema(cloudModels),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        let localConfig = ModelConfiguration(
            "SessionLocal",
            schema: Schema(localModels),
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [cloudConfig, localConfig])
    }
}
