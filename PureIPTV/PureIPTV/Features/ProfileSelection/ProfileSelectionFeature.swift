import ComposableArchitecture
import Foundation
import SwiftData

private nonisolated enum ProfileSelectionCancelID: Hashable, Sendable {
    case request
}

@Reducer
public struct ProfileSelectionFeature: Sendable {
    @ObservableState
    public struct State: Equatable {
        public enum PendingOperation: Equatable {
            case add(UserProfile)
            case delete(UserProfile)
        }

        public var profiles: [UserProfile] = []
        public var isEditing: Bool = false
        public var showingAddProfile: Bool = false
        public var hasLoadedProfiles = false
        public var isLoadingProfiles = false
        public var isPerformingProfileOperation = false
        public var requestID: UUID?
        public var pendingOperation: PendingOperation?
        public var errorMessage: String?

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case onDisappear
        case retry
        case dismissError
        case profilesLoaded(requestID: UUID, [UserProfile])
        case requestFailed(requestID: UUID, message: String)
        case operationCommitted(requestID: UUID, State.PendingOperation)
        case operationSucceeded(requestID: UUID, [UserProfile])
        case selectProfile(UserProfile)
        case toggleEditMode
        case addProfileTapped
        case deleteProfile(UserProfile)
        case addProfile(name: String, isKidsMode: Bool, avatarIcon: String)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectProfile(UserProfile)
        }
    }

    @Dependency(\.uuid) var uuid
    @Dependency(\.profileContextClient) var profileContextClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .onAppear:
                guard !state.isLoadingProfiles, !state.isPerformingProfileOperation else { return .none }
                if let operation = state.pendingOperation {
                    return beginOperation(operation, state: &state)
                }
                guard !state.hasLoadedProfiles else { return .none }
                return beginLoading(state: &state)

            case .onDisappear:
                let hadRequest = state.requestID != nil
                state.requestID = nil
                state.isLoadingProfiles = false
                state.isPerformingProfileOperation = false
                if state.pendingOperation == nil { state.errorMessage = nil }
                return hadRequest ? .cancel(id: ProfileSelectionCancelID.request) : .none

            case .retry:
                guard !state.isLoadingProfiles, !state.isPerformingProfileOperation else { return .none }
                if let operation = state.pendingOperation {
                    return beginOperation(operation, state: &state)
                }
                state.errorMessage = nil
                return beginLoading(state: &state)

            case .dismissError:
                guard state.hasLoadedProfiles else { return .none }
                state.errorMessage = nil
                if let operation = state.pendingOperation, case .add = operation {
                    state.pendingOperation = nil
                    state.showingAddProfile = true
                } else {
                    state.pendingOperation = nil
                }
                return .none

            case let .profilesLoaded(requestID, profiles):
                guard state.requestID == requestID else { return .none }
                state.requestID = nil
                state.isLoadingProfiles = false
                state.profiles = profiles
                state.hasLoadedProfiles = true
                state.errorMessage = nil
                return .none

            case let .requestFailed(requestID, message):
                guard state.requestID == requestID else { return .none }
                state.requestID = nil
                state.isLoadingProfiles = false
                state.isPerformingProfileOperation = false
                state.errorMessage = message
                if let operation = state.pendingOperation, case .add = operation {
                    state.showingAddProfile = false
                }
                return .none

            case let .operationCommitted(requestID, operation):
                guard state.requestID == requestID, state.pendingOperation == operation else { return .none }
                state.pendingOperation = nil
                switch operation {
                case let .add(profile):
                    if !state.profiles.contains(where: { $0.id == profile.id }) {
                        state.profiles.append(profile)
                        state.profiles.sort { $0.createdAt < $1.createdAt }
                    }
                    state.showingAddProfile = false
                case let .delete(profile):
                    state.profiles.removeAll { $0.id == profile.id }
                }
                return .none

            case let .operationSucceeded(requestID, profiles):
                guard state.requestID == requestID else { return .none }
                state.requestID = nil
                state.isPerformingProfileOperation = false
                state.profiles = profiles
                state.hasLoadedProfiles = true
                state.pendingOperation = nil
                state.errorMessage = nil
                state.showingAddProfile = false
                return .none

            case let .selectProfile(profile):
                _ = profileContextClient.select(profile.id)
                UserDefaults.standard.set(profile.isKidsMode, forKey: "currentProfileIsKidsMode")
                return .send(.delegate(.didSelectProfile(profile)))

            case .toggleEditMode:
                state.isEditing.toggle()
                return .none

            case .addProfileTapped:
                state.showingAddProfile = true
                return .none

            case let .deleteProfile(profile):
                guard !state.isPerformingProfileOperation else { return .none }
                let operation = State.PendingOperation.delete(profile)
                state.pendingOperation = operation
                state.errorMessage = nil
                return beginOperation(operation, state: &state)

            case let .addProfile(name, isKidsMode, avatarIcon):
                guard !state.isPerformingProfileOperation else { return .none }
                let profile = UserProfile(
                    id: uuid(),
                    name: name,
                    avatarIcon: ProfileAvatarCatalog.validated(avatarIcon, isKidsMode: isKidsMode),
                    isKidsMode: isKidsMode
                )
                let operation = State.PendingOperation.add(profile)
                state.pendingOperation = operation
                state.errorMessage = nil
                return beginOperation(operation, state: &state)

            case .delegate, .binding:
                return .none
            }
        }
    }

    private func beginLoading(state: inout State) -> Effect<Action> {
        let requestID = uuid()
        state.requestID = requestID
        state.isLoadingProfiles = true
        state.errorMessage = nil
        return .run { send in
            do {
                try Task.checkCancellation()
                let profiles = try await loadProfilesOrCreateDefaults()
                await send(.profilesLoaded(requestID: requestID, profiles))
            } catch is CancellationError {
                return
            } catch {
                await send(.requestFailed(requestID: requestID, message: "\((error as NSError).domain) (\((error as NSError).code))"))
            }
        }
        .cancellable(id: ProfileSelectionCancelID.request, cancelInFlight: true)
    }

    private func beginOperation(_ operation: State.PendingOperation, state: inout State) -> Effect<Action> {
        let requestID = uuid()
        state.requestID = requestID
        state.isPerformingProfileOperation = true
        state.errorMessage = nil
        return .run { send in
            do {
                switch operation {
                case let .add(profile):
                    try await saveProfile(profile)
                case let .delete(profile):
                    try await deleteProfile(profile)
                }
                await send(.operationCommitted(requestID: requestID, operation))
                let profiles = try await fetchProfiles()
                await send(.operationSucceeded(requestID: requestID, profiles))
            } catch is CancellationError {
                return
            } catch {
                await send(.requestFailed(requestID: requestID, message: "\((error as NSError).domain) (\((error as NSError).code))"))
            }
        }
        .cancellable(id: ProfileSelectionCancelID.request, cancelInFlight: true)
    }

    /// Helpers (to be moved to DatabaseClient).
    @MainActor
    private func loadProfilesOrCreateDefaults() throws -> [UserProfile] {
        try Task.checkCancellation()
        let context = ModelContext(try SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        var profiles = try context.fetch(descriptor)
        if profiles.isEmpty {
            try Task.checkCancellation()
            context.insert(UserProfile(id: UUID(), name: AppStrings.Profile.defaultAdultProfile, avatarIcon: "person.crop.circle.fill", isKidsMode: false))
            context.insert(UserProfile(id: UUID(), name: AppStrings.Profile.defaultKidsProfile, avatarIcon: "face.smiling.fill", isKidsMode: true))
            try Task.checkCancellation()
            try context.save()
            profiles = try context.fetch(descriptor)
        }
        return profiles
    }

    private func fetchProfiles() async throws -> [UserProfile] {
        let context = ModelContext(try SharedDatabaseConfig.shared)
        let descriptor = FetchDescriptor<UserProfile>(sortBy: [SortDescriptor(\.createdAt)])
        return try context.fetch(descriptor)
    }

    private func saveProfile(_ profile: UserProfile) async throws {
        let context = ModelContext(try SharedDatabaseConfig.shared)
        let id = profile.id
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == id })
        guard try context.fetch(descriptor).isEmpty else { return }
        context.insert(profile)
        try context.save()
    }

    private func deleteProfile(_ profile: UserProfile) async throws {
        let context = ModelContext(try SharedDatabaseConfig.shared)
        let id = profile.id
        let descriptor = FetchDescriptor<UserProfile>(predicate: #Predicate { $0.id == id })
        if let existing = try context.fetch(descriptor).first {
            context.delete(existing)
            try context.save()
        }
    }
}
