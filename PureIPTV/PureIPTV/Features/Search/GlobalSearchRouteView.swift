import ComposableArchitecture
import SwiftUI

struct GlobalSearchRouteView: View {
    let routeStore: StoreOf<GlobalSearchRouteFeature>

    var body: some View {
        SearchView(
            store: routeStore.scope(state: \.search, action: \.search),
            config: routeStore.config,
            onClose: { routeStore.send(.closeTapped) }
        )
    }
}
