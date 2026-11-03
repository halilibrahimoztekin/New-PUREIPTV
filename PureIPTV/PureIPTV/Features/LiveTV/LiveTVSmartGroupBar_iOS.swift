#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Smart Group Bar (iOS)

    /// Horizontal bar of dynamic smart channel groups with Liquid Glass pills.
    struct LiveTVSmartGroupBar_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>

        var body: some View {
            if !store.smartChannelGroups.isEmpty {
                LiquidGlassContainer(spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(store.smartChannelGroups) { group in
                                LiquidGlassPill(
                                    title: group.name,
                                    isSelected: store.selectedSmartGroupID == group.id,
                                    tint: AppColors.primary
                                ) {
                                    HapticManager.shared.trigger(.light)
                                    store.send(.smartGroupSelected(group.id))
                                }
                                .accessibilityHint(AppStrings.LiveTV.smartGroupPrivacyHint)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
            }
        }
    }
#endif
