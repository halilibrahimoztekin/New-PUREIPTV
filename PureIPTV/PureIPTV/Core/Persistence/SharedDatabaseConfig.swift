import Foundation
import SwiftData

public enum SharedDatabaseConfig {
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

    public static let shared: ModelContainer = {
        do {
            return try createModelContainer()
        } catch {
            fatalError("Failed to create shared ModelContainer: \(error)")
        }
    }()

    public static func createModelContainer() throws -> ModelContainer {
        try ModelContainer(for: schema, configurations: createConfigurations())
    }
}
