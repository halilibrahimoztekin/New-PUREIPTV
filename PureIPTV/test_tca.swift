import ComposableArchitecture

@Reducer
struct Child {
    struct State {}
    enum Action {}
    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

@Reducer
struct Parent {
    struct State {
        @Presents var child: Child.State?
    }

    enum Action {
        case child(PresentationAction<Child.Action>)
    }

    var body: some ReducerOf<Self> {
        EmptyReducer()
    }
}

func test(store: StoreOf<Parent>) {
    // How to get StoreOf<Child>?
    if let childStore = store.scope(state: \.child, action: \.child) {
        let _: StoreOf<Child> = childStore // Does this compile?
    }
}
