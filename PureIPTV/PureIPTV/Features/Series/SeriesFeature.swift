import ComposableArchitecture
import FactoryKit
import Foundation

// MARK: - SeriesFeature

@Reducer
public struct SeriesFeature {
    @ObservableState
    public struct State: Equatable {
        // Data
        public var categories: [MediaModels.Category] = []
        public var seriesByCategory: [String: [MediaModels.Item]] = [:]

        /// Server Info
        public var config: PlaylistConfig?

        // UI state
        public var selectedCategoryID: String?
        public var selectedSeries: MediaModels.Item?
        public var isLoadingCategories = false
        public var isLoadingSeries = false
        public var errorMessage: String?
        public var favoriteIDs: Set<String> = []
        public var lastSortMethod: SortMethod = .defaultOrder

        @Presents public var categoryManagement: CategoryManagementFeature.State?
        @Presents public var parentalLock: ParentalLockFeature.State?

        // Computed: series for the currently selected category
        public var currentSeries: [MediaModels.Item] {
            guard let id = selectedCategoryID else { return [] }
            let items = seriesByCategory[id] ?? []

            switch lastSortMethod {
            case .alphabetical:
                return items.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            case .rating:
                return items.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
            case .dateAdded:
                return items.sorted { ($0.addedDate ?? .distantPast) > ($1.addedDate ?? .distantPast) }
            case .defaultOrder:
                return items
            }
        }

        public init() {}
    }

    public enum Action {
        case onAppear(config: PlaylistConfig)
        case categoriesResponse(Result<[MediaModels.Category], Error>)
        case categorySelected(MediaModels.Category)
        case seriesResponse(categoryID: String, Result<[MediaModels.Item], Error>)
        case seriesSelected(MediaModels.Item)
        case toggleFavorite(MediaModels.Item)
        case favoritesLoaded(Set<String>)
        case dismissError
        case reloadCategories(config: PlaylistConfig)
        case reloadPreferences
        case applySortIfChanged
        case editCategoriesTapped
        case categoryManagement(PresentationAction<CategoryManagementFeature.Action>)
        case parentalLock(PresentationAction<ParentalLockFeature.Action>)
        case delegate(Delegate)

        public enum Delegate: Equatable {
            case didSelectSeries(MediaModels.Item)
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
                state.lastSortMethod = settingsClient.getSeriesSortMethod()
                let loadFavorites: Effect<Action> = .run { send in
                    let favs = await (try? databaseClient.fetchFavoritesByType("series")) ?? []
                    await send(.favoritesLoaded(Set(favs.map(\.id))))
                }

                guard !state.isLoadingCategories else { return loadFavorites }
                guard state.categories.isEmpty else { return loadFavorites }

                return .merge(loadFavorites, .send(.reloadCategories(config: config)))

            case let .reloadCategories(config):
                state.isLoadingCategories = true
                state.config = config
                return .run { send in
                    async let categoriesResult = Result { try await iptvClient.fetchSeriesCategories(config) }
                    async let prefsResult = Result { try await databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.series.rawValue) }

                    let categories = await (try? categoriesResult.get()) ?? []
                    let prefs = await (try? prefsResult.get()) ?? []

                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    // Filter and sort

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    let hideAdult = settingsClient.hideAdultContent()
                    var finalCategories = categories.filter { category in
                        if hideAdult, settingsClient.isAdultContent(category.name) {
                            return false
                        }

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
                    let prefs = await (try? databaseClient.fetchCategoryPreferences(CategoryManagementFeature.State.CategoryType.series.rawValue)) ?? []
                    var dict: [String: CategoryPreferenceDTO] = [:]
                    for pref in prefs {
                        dict[pref.categoryID] = pref
                    }

                    let isKidsMode = UserDefaults.standard.bool(forKey: "currentProfileIsKidsMode")
                    let kidsKeywords = ["kid", "çocuk", "child", "animat", "cartoon", "family", "aile"]

                    let hideAdult = settingsClient.hideAdultContent()
                    var finalCategories = currentCats.filter { category in
                        if hideAdult, settingsClient.isAdultContent(category.name) {
                            return false
                        }

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

            case .applySortIfChanged:
                let currentMethod = settingsClient.getSeriesSortMethod()
                if state.lastSortMethod != currentMethod {
                    state.lastSortMethod = currentMethod
                }
                return .none

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
                if state.seriesByCategory[category.id] != nil {
                    return .run { _ in await hapticClient.selection() }
                }
                guard let config = state.config else { return .none }

                state.isLoadingSeries = true
                let categoryID = category.id

                return .run { send in
                    await hapticClient.selection()
                    await send(.seriesResponse(
                        categoryID: categoryID,
                        Result { try await iptvClient.fetchSeries(config, categoryID) }
                    ))
                }

            case let .seriesResponse(categoryID, .success(series)):
                state.isLoadingSeries = false
                state.seriesByCategory[categoryID] = series
                return .none

            case let .seriesResponse(_, .failure(error)):
                state.isLoadingSeries = false
                state.errorMessage = (error as? NetworkError)?.localizedDescription ?? error.localizedDescription
                return .none

            case let .seriesSelected(series):
                state.selectedSeries = series
                return .merge(
                    .run { _ in await hapticClient.impact(.light) },
                    .send(.delegate(.didSelectSeries(series)))
                )

            case let .favoritesLoaded(favIDs):
                state.favoriteIDs = favIDs
                return .none

            case let .toggleFavorite(item):
                let favItem = FavoriteItem(
                    id: item.id,
                    type: "series",
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
                    state.categoryManagement = CategoryManagementFeature.State(config: config, type: .series)
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
                    if state.seriesByCategory[category.id] != nil {
                        return .none
                    }
                    guard let config = state.config else { return .none }
                    state.isLoadingSeries = true
                    let categoryID = category.id
                    return .run { send in
                        await send(.seriesResponse(
                            categoryID: categoryID,
                            Result { try await iptvClient.fetchSeries(config, categoryID) }
                        ))
                    }
                } else if let item {
                    state.selectedSeries = item
                    return .send(.delegate(.didSelectSeries(item)))
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
