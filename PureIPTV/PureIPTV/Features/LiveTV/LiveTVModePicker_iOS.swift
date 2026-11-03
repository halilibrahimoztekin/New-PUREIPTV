#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - Live TV Mode Picker (iOS)

    /// Decomposed mode switcher for Live TV (Kanallar vs. Yayın Akışı)
    /// styled with Liquid Glass and tokenized colors/typography.
    struct LiveTVModePicker_iOS: View {
        @Bindable var store: StoreOf<LiveTVFeature>

        var body: some View {
            LiquidGlassContainer {
                HStack(spacing: 4) {
                    ForEach(LiveTVFeature.State.TabMode.allCases, id: \.self) { mode in
                        let isSelected = store.selectedTabMode == mode
                        Button {
                            HapticManager.shared.trigger(.light)
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                                store.send(.setTabMode(mode))
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode == .channels ? "tv" : "calendar.day.timeline.left")
                                    .font(AppFonts.captionSemibold)
                                Text(mode.rawValue)
                                    .font(isSelected ? AppFonts.bodySmall.weight(.semibold) : AppFonts.caption)
                            }
                            .foregroundColor(isSelected ? AppColors.textPrimary : AppColors.textSecondary.opacity(0.75))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(isSelected ? AppColors.primary : Color.clear)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(mode.rawValue)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(4)
                .liquidGlass(shape: .roundedRectangle(cornerRadius: 14), isInteractive: false, surfaceColor: AppColors.surfaceSecondary)
            }
        }
    }
#endif
