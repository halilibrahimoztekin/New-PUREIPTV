#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct VODDetailView_iOS: View {
        let store: StoreOf<VODDetailFeature>
        let onPresentSynopsis: (String) -> Void

        public init(
            store: StoreOf<VODDetailFeature>,
            onPresentSynopsis: @escaping (String) -> Void = { _ in }
        ) {
            self.store = store
            self.onPresentSynopsis = onPresentSynopsis
        }

        public var body: some View {
            ZStack(alignment: .top) {
                AppColors.surfaceDark.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        VODDetailHeroHeaderView_iOS(store: store)
                        VODDetailCastSection_iOS(store: store, onPresentSynopsis: onPresentSynopsis)
                    }
                }
            }
            .onAppear {
                store.send(.onAppear)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        HapticManager.shared.trigger(.light)
                        store.send(.closeTapped)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(8)
                            .liquidGlass(shape: .circle, isInteractive: true)
                    }
                }
            }
        }
    }
#endif
