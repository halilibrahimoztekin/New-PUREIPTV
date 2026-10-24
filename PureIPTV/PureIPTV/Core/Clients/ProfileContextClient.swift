import ComposableArchitecture
import Foundation

public struct ProfileContextSnapshot: Equatable, Sendable {
    public let profileID: UUID?
    public let generation: UUID

    public init(profileID: UUID?, generation: UUID) {
        self.profileID = profileID
        self.generation = generation
    }
}

/// Carries the selected, persisted profile identity and a generation token for stale work.
public struct ProfileContextClient: Sendable {
    public var snapshot: @Sendable () -> ProfileContextSnapshot
    public var select: @Sendable (_ profileID: UUID) -> ProfileContextSnapshot

    public init(
        snapshot: @escaping @Sendable () -> ProfileContextSnapshot,
        select: @escaping @Sendable (UUID) -> ProfileContextSnapshot
    ) {
        self.snapshot = snapshot
        self.select = select
    }
}

extension ProfileContextClient: DependencyKey {
    private nonisolated static let profileIDKey = "currentProfileID"
    private nonisolated static let generationKey = "com.pureiptv.profileContextGeneration"

    public static let liveValue: ProfileContextClient = {
        let defaults = UserDefaults.standard
        return ProfileContextClient(
            snapshot: {
                let id = defaults.string(forKey: profileIDKey).flatMap(UUID.init(uuidString:))
                let generation: UUID
                if let stored = defaults.string(forKey: generationKey).flatMap(UUID.init(uuidString:)) {
                    generation = stored
                } else {
                    generation = UUID()
                    defaults.set(generation.uuidString, forKey: generationKey)
                }
                return ProfileContextSnapshot(profileID: id, generation: generation)
            },
            select: { profileID in
                let generation = UUID()
                defaults.set(profileID.uuidString, forKey: profileIDKey)
                defaults.set(generation.uuidString, forKey: generationKey)
                return ProfileContextSnapshot(profileID: profileID, generation: generation)
            }
        )
    }()

    public static let testValue = ProfileContextClient(
        snapshot: { ProfileContextSnapshot(profileID: nil, generation: UUID()) },
        select: { ProfileContextSnapshot(profileID: $0, generation: UUID()) }
    )
}

public extension DependencyValues {
    var profileContextClient: ProfileContextClient {
        get { self[ProfileContextClient.self] }
        set { self[ProfileContextClient.self] = newValue }
    }
}
