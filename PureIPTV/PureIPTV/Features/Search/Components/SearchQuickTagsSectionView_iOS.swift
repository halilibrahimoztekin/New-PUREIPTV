#if !os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    public struct SearchQuickTagsSectionView_iOS: View {
        let store: StoreOf<SearchFeature>

        public init(store: StoreOf<SearchFeature>) {
            self.store = store
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: 14) {
                Label(AppStrings.Search.quickTags, systemImage: "sparkles")
                    .font(AppFonts.bodyLarge.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 155, maximum: 200), spacing: 12)], spacing: 12) {
                    ForEach(store.quickTags) { tag in
                        Button {
                            HapticManager.shared.trigger(.light)
                            store.send(.tagSelected(tag))
                        } label: {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(tag.color.opacity(0.18))
                                        .frame(width: 36, height: 36)
                                    Image(systemName: tag.icon)
                                        .font(AppFonts.bodyMedium.weight(.semibold))
                                        .foregroundStyle(tag.color)
                                }

                                Text(tag.title)
                                    .font(AppFonts.bodySmall.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(AppFonts.captionSmall.weight(.semibold))
                                    .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.3))
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(AppColors.surfaceContainer)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
#endif
