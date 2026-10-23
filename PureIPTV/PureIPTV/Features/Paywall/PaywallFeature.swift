import ComposableArchitecture
import Foundation
import RevenueCat

@Reducer
public struct PaywallFeature {
    @ObservableState
    public struct State: Equatable {
        public var packages: [RevenueCat.Package] = []
        public var isLoading: Bool = false
        public var errorMessage: String?

        public init() {}
    }

    public enum Action {
        case onAppear
        case offeringsResponse(TaskResult<Offerings>)
        case purchasePackage(Package)
        case purchaseResponse(TaskResult<CustomerInfo>)
        case restorePurchases
        case restoreResponse(TaskResult<CustomerInfo>)
        case closeButtonTapped
        case dismiss
    }

    @Dependency(\.purchases) var purchases

    public init() {}

    public var body: some Reducer<State, Action> {
        Reduce { state, action in
            switch action {
            case .onAppear:
                state.isLoading = true
                state.errorMessage = nil
                return .run { send in
                    await send(.offeringsResponse(TaskResult {
                        try await purchases.fetchOfferings()
                    }))
                }

            case let .offeringsResponse(.success(offerings)):
                state.isLoading = false
                if let current = offerings.current {
                    state.packages = current.availablePackages
                }
                return .none

            case let .offeringsResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case let .purchasePackage(package):
                state.isLoading = true
                return .run { send in
                    await send(.purchaseResponse(TaskResult {
                        try await purchases.purchasePackage(package)
                    }))
                }

            case let .purchaseResponse(.success(info)):
                state.isLoading = false
                if !info.entitlements.active.isEmpty {
                    return .send(.dismiss)
                }
                return .none

            case let .purchaseResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .restorePurchases:
                state.isLoading = true
                return .run { send in
                    await send(.restoreResponse(TaskResult {
                        try await purchases.restorePurchases()
                    }))
                }

            case let .restoreResponse(.success(info)):
                state.isLoading = false
                if !info.entitlements.active.isEmpty {
                    return .send(.dismiss)
                }
                return .none

            case let .restoreResponse(.failure(error)):
                state.isLoading = false
                state.errorMessage = error.localizedDescription
                return .none

            case .closeButtonTapped:
                return .send(.dismiss)

            case .dismiss:
                return .none
            }
        }
    }
}
