import ComposableArchitecture

@DependencyClient
public struct TMDBAPIKeyClient {
    public var hasStoredAPIKey: @Sendable () async throws -> Bool
    public var saveAPIKey: @Sendable (_ apiKey: String) async throws -> Void
    public var deleteAPIKey: @Sendable () async throws -> Void
}

extension TMDBAPIKeyClient: DependencyKey {
    public static let liveValue: TMDBAPIKeyClient = {
        let store = TMDBAPIKeyStore.shared
        return TMDBAPIKeyClient(
            hasStoredAPIKey: { try await store.hasStoredAPIKey() },
            saveAPIKey: { apiKey in try await store.saveUserAPIKey(apiKey) },
            deleteAPIKey: { try await store.deleteUserAPIKey() }
        )
    }()

    public static let testValue: TMDBAPIKeyClient = {
        var client = TMDBAPIKeyClient()
        client.hasStoredAPIKey = { false }
        client.saveAPIKey = { _ in }
        client.deleteAPIKey = {}
        return client
    }()
}

public extension DependencyValues {
    var tmdbAPIKeyClient: TMDBAPIKeyClient {
        get { self[TMDBAPIKeyClient.self] }
        set { self[TMDBAPIKeyClient.self] = newValue }
    }
}
