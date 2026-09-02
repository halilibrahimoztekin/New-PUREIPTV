import ComposableArchitecture
import FactoryKit
import Foundation

// MARK: - VODFeature

@Reducer
public struct VODFeature {
    @ObservableState
    public struct State: Equatable {
        // Data
        public var categories: [MediaModels.Category] = []
        public var vodsByCategory: [String: [MediaModels.Item]] = [:]

        /// Server Info
        public var config: PlaylistConfig?

        // UI state
        public var selectedCategoryID: String?
        public var selectedVOD: MediaModels.Item?
        public var isLoadingCategories = false
        public var isLoadingVODs = false
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []

        @Presents public var categoryManagement: CategoryManagementFeature.State?
        @Presents public var parentalLock: ParentalLockFeature.State?

        // Computed: vods for the currently selected category
        public var currentVODs: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            return vodsByCategory[id] ?? []
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>)
        case categorySelected(MediaModels.Category)
        case vodsResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case vodSelected(MediaModels.Item)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
        case reloadPreferences
        case editCategoriesTapped
        case categoryManagement(PresentationAction<CategoryManagementFeature.Action>)
        case parentalLock(PresentationAction<ParentalLockFeature.Action>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectVOD(MediaModels.Item)
        }
    }

    @Injected(\.iptvClient) var iptvClient
    @Dependency(\.databaseClient) var databaseClient
    @Dependency(\.settingsClient) var settingsClient
    @Dependency(\.hapticClient) var hapticClient

    public init() {}

    public var body: some Reducer<State, Action> {
        let iptvClient = iptvClient

        Reduce { state, action in
            switch action {
            case let .onAppear(config):
                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("vod")) ?? []
                    await send(.favoritesLoaded(Set(favs.map(\.id))))
                }

                guard !state.isLoadingCategories else { return loadFavorites }
                guard state.categories.isEmpty else { return loadFavorites }

                return .merge(loadFavorites, .send(.reloadCategories(config: config)))

            case let .reloadCategories(config):
                state.isLoadingCategories = true
                state.config = config
                return .run { send in
                    async let categoriesResult = Result { try await iptvClient.fetchVODCategories(config) }
                    async let prefsResult = Result { try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.vod.rawValue) }

                    let categories = await (try? categoriesResult.get()) ?? []
                    let prefs = await (try? prefsResult.get()) ?? []

                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    // Filter and sort

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = categories.filter { category in
                        if dict[category.id]?.isHidden ?? false {
                            return false
                        }

                        if isKidsMode {
                            let nameLower = category.name.lowercased()
                            return kidsKeywords.contains { nameLower.contains($0) }
                        }

                        return true
                    }
                    finalCategories.sort { a, b in
                        let orderA = dict[a.id]?.orderIndex ?? Int.max
                        let orderB = dict[b.id]?.orderIndex ?? Int.max
                        if orderA == orderB {
                            return a.name < b.name
                        }
                        return orderA < orderB
                    }

                    await send(.categoriesResponse(.success(finalCategories)))
                } catch: { error, send in
                    await send(.categoriesResponse(.failure(error)))
                }

            case .reloadPreferences:
                let currentCats = state.categories
                return .run { send in
                    let prefs = await (try? databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.vod.rawValue)) ?? []
                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    var finalCategories = currentCats.filter { category in
                        if dict[category.id]?.isHidden ?? false {
                            return false
                        }

                        if isKidsMode {
                            let nameLower = category.name.lowercased()
                            return kidsKeywords.contains { nameLower.contains($0) }
                        }

                        return true
                    }
                    finalCategories.sort { a, b in
                        let orderA = dict[a.id]?.orderIndex ?? Int.max
                        let orderB = dict[b.id]?.orderIndex ?? Int.max
                        if orderA == orderB {
                            return a.name < b.name
                        }
                        return orderA < orderB
                    }

                    await send(.categoriesResponse(.success(finalCategories)))
                }

            case let .categoriesResponse(.success(categories)):
                state.isLoadingCategories = false
                state.categories = categories
                // Auto-select first category
                if let first = categories.first {
                    state.selectedCategoryID = first.id
                    return .send(.categorySelected(first))
                }
                return .none

            case let .categoriesResponse(.failure(error)):
                state.isLoadingCategories = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .categorySelected(category):
                if settingsClient.isParentalControlEnabled(), settingsClient.isAdultContent(category.name) {
                    state.parentalLock = ParentalLockFeature.State(category: category)
                    return .none
                }

                state.selectedCategoryID = category.id
                if state.vodsByCategory[category.id] != nil {
                    return .run { _ in await hapticClient.selection() }
                }
                guard let config = state.config else { return .none }

                state.isLoadingVODs = true
                let categoryID = category.id

                return .run { send in
                    await hapticClient.selection()
                    await send(.vodsResponse(
                        categoryID: categoryID,
                        Result { try await iptvClient.fetchVODs(config, categoryID) }
                    ))
                }

            case let .vodsResponse(categoryID, .success(vods)):
                state.isLoadingVODs = false
                state.vodsByCategory[categoryID] = vods
                return .none

            case let .vodsResponse(_, .failure(error)):
                state.isLoadingVODs = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .vodSelected(vod):
                state.selectedVOD = vod
                return .merge(
                    .run { _ in await hapticClient.impact(.light) },
                    .send(.delegate(.didSelectVOD(vod)))
                )

            case let .favoritesLoaded(favIDs):
                state.favoriteIDs = favIDs
                return .none

            case let .toggleFavorite(item):
                let favItem = FavoriteItem(
                    id: item.id,
                    type: "vod",
                    title: item.title,
                    coverURL: item.coverURL?.absoluteString,
                    streamURL: item.streamURL?.absoluteString
                )
                let isCurrentlyFav = state.favoriteIDs.contains(item.id)
                if isCurrentlyFav {
                    state.favoriteIDs.remove(item.id)
                } else {
                    state.favoriteIDs.insert(item.id)
                }
                return .run { _ in
                    _ = try? await databaseClient.toggleFavorite(favItem)
                    await hapticClient.notification(.success)
                }

            case .dismissError:
                state.errorMessage = nil
                return .none

            case .editCategoriesTapped:
                if let config = state.config {
                    state.categoryManagement = CategoryManagementFeature.State(config: config, type: .vod)
                }
                return .none

            case .categoryManagement(.presented(.delegate(.categoriesUpdated))):
                return .send(.reloadPreferences)

            case .categoryManagement(.presented(.delegate(.close))):
                state.categoryManagement = nil
                return .none

            case .categoryManagement:
                return .none

            case let .parentalLock(.presented(.delegate(.didUnlock(category, item)))):
                state.parentalLock = nil
                if let category {
                    state.selectedCategoryID = category.id
                    if state.vodsByCategory[category.id] != nil {
                        return .none
                    }
                    guard let config = state.config else { return .none }
                    state.isLoadingVODs = true
                    let categoryID = category.id
                    return .run { send in
                        await send(.vodsResponse(
                            categoryID: categoryID,
                            Result { try await iptvClient.fetchVODs(config, categoryID) }
                        ))
                    }
                } else if let item {
                    state.selectedVOD = item
                    return .send(.delegate(.didSelectVOD(item)))
                }
                return .none

            case .parentalLock(.presented(.delegate(.didCancel))):
                state.parentalLock = nil
                return .none

            case .parentalLock:
                return .none

            case .delegate:
                return .none
            }
        }
        .ifLet(\.$categoryManagement, action: \.categoryManagement) {
            CategoryManagementFeature()
        }
        .ifLet(\.$parentalLock, action: \.parentalLock) {
            ParentalLockFeature()
        }
    }
}
