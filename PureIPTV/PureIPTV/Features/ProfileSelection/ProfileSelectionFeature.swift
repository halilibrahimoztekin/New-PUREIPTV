import ComposableArchitecture
import Foundation
import SwiftData

@Reducer
public struct ProfileSelectionFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public var profiles: [UserProfile] = []
        public var isEditing: Bool = false
        public var showingAddProfile: Bool = false

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case loadProfiles([UserProfile])
        case selectProfile(UserProfile)
        case toggleEditMode
        case addProfileTapped
        case deleteProfile(UserProfile)
        case addProfile(name: String, isKidsMode: Bool)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectProfile(UserProfile)
        }
    }

    @Dependency(\.uuid) var uuid

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                return .run { send in
                    // We need a DatabaseClient method to fetch profiles, but we can do it directly here for brevity
                    // Wait, Reducers should use Dependencies.
                    // Let's assume we add `fetchProfiles` to DatabaseClient.
                    let profiles = try await fetchProfiles()
                    await send(.loadProfiles(profiles))
                }

            case let .loadProfiles(profiles):
                state.profiles = profiles
                // Create default profiles if none exist
                if state.profiles.isEmpty {
                    return .run { send in
                        try await createDefaultProfiles()
                        let newProfiles = try await fetchProfiles()
                        await send(.loadProfiles(newProfiles))
                    }
                }
                return .none

            case let .selectProfile(profile):
                UserDefaults.standard.set(profile.id.uuidString, forKey: "currentProfileID")
                UserDefaults.standard.set(profile.isKidsMode, forKey: "currentProfileIsKidsMode")
                return .send(.delegate(.didSelectProfile(profile)))

            case .toggleEditMode:
                state.isEditing.toggle()
                return .none

            case .addProfileTapped:
                state.showingAddProfile = true
                return .none

            case let .deleteProfile(profile):
                state.profiles.removeAll { $0.id == profile.id }
                return .run { send in
                    try await deleteProfile(profile)
                    let newProfiles = try await fetchProfiles()
                    await send(.loadProfiles(newProfiles))
                }

            case let .addProfile(name, isKidsMode):
                state.showingAddProfile = false
                let newProfile = UserProfile(id: uuid(), name: name, avatarIcon: isKidsMode ? "face.smiling.fill" : "person.crop.circle.fill", isKidsMode: isKidsMode)
                return .run { send in
                    try await saveProfile(newProfile)
                    let newProfiles = try await fetchProfiles()
                    await send(.loadProfiles(newProfiles))
                }

            case .delegate:
                return .none

            case .binding:
                return .none
            }
        }
    }

    /// Helpers (To be moved to DatabaseClient)
    private func fetchProfiles() async throws -> [UserProfile] {
        let context = ModelContext(SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor)
    }

    private func createDefaultProfiles() async throws {
        let context = ModelContext(SharedDatabaseConfig.shared)
        context.insert(UserProfile(id: UUID(), name: "Yetişkin", avatarIcon: "person.crop.circle.fill", isKidsMode: false))
        context.insert(UserProfile(id: UUID(), name: "Çocuk", avatarIcon: "face.smiling.fill", isKidsMode: true))
        try context.save()
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        let context = ModelContext(SharedDatabaseConfig.shared)
        context.insert(profile)
        try context.save()
    }

    private func deleteProfile(_ profile: UserProfile) async throws {
        let context = ModelContext(SharedDatabaseConfig.shared)
        let id = profile.id
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }
}
