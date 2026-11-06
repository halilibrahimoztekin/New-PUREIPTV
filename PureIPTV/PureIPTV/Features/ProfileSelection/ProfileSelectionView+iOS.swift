#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS Profile Selection View

    public struct ProfileSelectionView_iOS: View {
        @Bindable var store: StoreOf<ProfileSelectionFeature>

        public init(store: StoreOf<ProfileSelectionFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                AppColors.oledBlack.ignoresSafeArea()

                VStack(spacing: 40) {
                    Text(AppStrings.Profile.whoIsWatching)
                        .font(AppFonts.displayLarge)
                        .foregroundStyle(AppColors.textPrimary)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 32) {
                        ForEach(store.profiles) { profile in
                            VStack(spacing: 12) {
                                Button {
                                    if !store.isEditing {
                                        store.send(.selectProfile(profile))
                                    }
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        Image(systemName: profile.avatarIcon.isEmpty ? "person.crop.circle.fill" : profile.avatarIcon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 90, height: 90)
                                            .foregroundStyle(profile.isKidsMode ? AppColors.warning : AppColors.primary)
                                            .background(AppColors.surfaceElevated)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18)
                                                    .stroke(AppColors.borderStrong, lineWidth: 2)
                                            )

                                        if store.isEditing {
                                            Button {
                                                store.send(.deleteProfile(profile))
                                            } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .foregroundStyle(AppColors.destructive)
                                                    .background(AppColors.textPrimary.clipShape(Circle()))
                                                    .font(AppFonts.titleMedium)
                                            }
                                            .offset(x: 10, y: -10)
                                        }
                                    }
                                }
                                .accessibilityLabel(profile.name)
                                .buttonStyle(.plain)

                                Text(profile.name)
                                    .font(AppFonts.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }

                        // Add Profile Button
                        if !store.isEditing, store.profiles.count < 6 {
                            VStack(spacing: 12) {
                                Button {
                                    store.send(.addProfileTapped)
                                } label: {
                                    Image(systemName: "plus")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 36, height: 36)
                                        .frame(width: 90, height: 90)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .background(AppColors.surfaceSecondary)
                                        .clipShape(RoundedRectangle(cornerRadius: 18))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 18)
                                                .stroke(AppColors.borderStrong, lineWidth: 2)
                                        )
                                }
                                .buttonStyle(.plain)

                                Text(AppStrings.Common.add)
                                    .font(AppFonts.headline)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                        }
                    }
                    .padding(.horizontal, 40)

                    Button {
                        store.send(.toggleEditMode)
                    } label: {
                        Text(store.isEditing ? AppStrings.Common.done : AppStrings.Profile.editProfiles)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.textPrimary)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(AppColors.surfaceElevated)
                            .clipShape(Capsule())
                    }
                    .padding(.top, 20)
                }
            }
        }
    }
#endif
