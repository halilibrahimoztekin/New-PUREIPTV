#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Profile Selection View

    public struct ProfileSelectionView_tvOS: View {
        @Bindable var store: StoreOf<ProfileSelectionFeature>

        public init(store: StoreOf<ProfileSelectionFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── Cinematic Ambient Background ─────────────────────
                AppColors.background.ignoresSafeArea()

                RadialGradient(
                    colors: [
                        AppColors.primary.opacity(0.14),
                        AppColors.premium.opacity(0.06),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 80,
                    endRadius: 650
                )
                .ignoresSafeArea()

                VStack(spacing: 50) {
                    Spacer().frame(height: 20)

                    // ── Header Title ──────────────────────────────────
                    VStack(spacing: 12) {
                        Text(store.isEditing ? AppStrings.Profile.manageProfiles : AppStrings.Profile.whoIsWatching)
                            .font(AppFonts.displayLarge)
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                        Text(store.isEditing ? AppStrings.Profile.deleteInstruction : AppStrings.Profile.personalizeDesc)
                            .font(AppFonts.titleSmall)
                            .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.65))
                    }

                    // ── Profiles Row ──────────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 48) {
                            ForEach(Array(store.profiles.enumerated()), id: \.element.id) { index, profile in
                                TVProfileCard(
                                    profile: profile,
                                    index: index,
                                    isEditing: store.isEditing,
                                    onSelect: {
                                        if !store.isEditing {
                                            store.send(.selectProfile(profile))
                                        }
                                    },
                                    onDelete: {
                                        store.send(.deleteProfile(profile))
                                    }
                                )
                            }

                            // Add Profile Button (if not at max limit)
                            if !store.isEditing, store.profiles.count < 6 {
                                TVAddProfileCard {
                                    store.send(.addProfileTapped)
                                }
                            }
                        }
                        .padding(.horizontal, 80)
                        .padding(.vertical, 30)
                    }
                    .focusSection()

                    // ── Bottom Action (Manage Profiles) ───────────────
                    Button {
                        store.send(.toggleEditMode)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: store.isEditing ? "checkmark" : "pencil")
                                .font(.system(size: 18, weight: .bold))
                            Text(store.isEditing ? AppStrings.Common.done : AppStrings.Profile.manageProfiles)
                                .font(.system(size: 20, weight: .semibold))
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(TVEditProfileButtonStyle(isEditing: store.isEditing))

                    Spacer().frame(height: 20)
                }
            }
            .onExitCommand {
                if store.isEditing {
                    store.send(.toggleEditMode)
                }
            }
        }
    }

    // MARK: - TV Profile Card

    private struct TVProfileCard: View {
        let profile: UserProfile
        let index: Int
        let isEditing: Bool
        let onSelect: () -> Void
        let onDelete: () -> Void

        @Environment(\.isFocused) private var isFocused

        private var gradient: LinearGradient {
            if profile.isKidsMode {
                return LinearGradient(
                    colors: [AppColors.warning, AppColors.destructive],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            let palettes: [[Color]] = [
                [AppColors.primary, AppColors.primaryDark],
                [AppColors.premium, AppColors.premium.opacity(0.8)],
                [AppColors.success, AppColors.neonTeal],
                [AppColors.destructive, AppColors.warning],
                [AppColors.sky, AppColors.primary],
            ]
            let colors = palettes[index % palettes.count]
            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        private var glowColor: Color {
            profile.isKidsMode ? AppColors.warning : AppColors.primary
        }

        private var strokeColor: Color {
            isFocused ? Color.white : Color.white.opacity(0.12)
        }

        private var strokeWidth: CGFloat {
            isFocused ? 4.0 : 1.5
        }

        private var shadowColor: Color {
            isFocused ? glowColor.opacity(0.7) : Color.black.opacity(0.4)
        }

        private var shadowRadius: CGFloat {
            isFocused ? 26.0 : 10.0
        }

        private var shadowY: CGFloat {
            isFocused ? 8.0 : 4.0
        }

        private var cardScale: CGFloat {
            isFocused ? 1.15 : 1.0
        }

        private var nameColor: Color {
            isFocused ? Color.white : AppColors.onSurfaceVariant.opacity(0.75)
        }

        private var nameScale: CGFloat {
            isFocused ? 1.08 : 1.0
        }

        var body: some View {
            if isEditing {
                VStack(spacing: 18) {
                    profileArtwork

                    HStack(spacing: 8) {
                        Text(profile.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundStyle(Color.white)
                            .lineLimit(1)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundStyle(Color.white)
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(TVCircleButtonStyle(isFavorite: true))
                        .accessibilityLabel("\(AppStrings.Common.delete): \(profile.name)")
                        .accessibilityHint(AppStrings.Profile.deleteInstruction)
                    }
                    .frame(width: 190)
                }
            } else {
                Button(action: onSelect) {
                    VStack(spacing: 18) {
                        profileArtwork

                        Text(profile.name)
                            .font(AppFonts.headline)
                            .foregroundStyle(AppColors.onSurface)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                            .frame(width: 190, alignment: .center)
                    }
                }
                .buttonStyle(TVGridCardButtonStyle(cornerRadius: 26))
                .accessibilityLabel(profile.name)
            }
        }

        private var profileArtwork: some View {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(gradient)
                    .frame(width: 190, height: 190)

                Image(systemName: profile.avatarIcon.isEmpty ? "person.crop.circle.fill" : profile.avatarIcon)
                    .font(.system(size: 78))
                    .foregroundStyle(Color.white)
                    .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                    .frame(width: 190, height: 190)

                if profile.isKidsMode {
                    Text(AppStrings.Profile.kidsBadge)
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(Color.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.black.opacity(0.45))
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .stroke(strokeColor, lineWidth: strokeWidth)
            )
            .shadow(color: shadowColor, radius: shadowRadius, x: 0, y: shadowY)
            .scaleEffect(cardScale)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
        }
    }

    // MARK: - TV Add Profile Card

    private struct TVAddProfileCard: View {
        let action: () -> Void

        @Environment(\.isFocused) private var isFocused

        private var fillColor: Color {
            isFocused ? Color.white.opacity(0.18) : Color.white.opacity(0.06)
        }

        private var strokeColor: Color {
            isFocused ? Color.white : Color.white.opacity(0.2)
        }

        private var strokeStyle: StrokeStyle {
            StrokeStyle(lineWidth: isFocused ? 4.0 : 2.0, dash: isFocused ? [] : [8, 6])
        }

        private var iconColor: Color {
            isFocused ? Color.white : Color.white.opacity(0.5)
        }

        private var shadowColor: Color {
            isFocused ? AppColors.primary.opacity(0.6) : Color.clear
        }

        private var shadowRadius: CGFloat {
            isFocused ? 24.0 : 0.0
        }

        private var cardScale: CGFloat {
            isFocused ? 1.15 : 1.0
        }

        private var labelColor: Color {
            isFocused ? Color.white : AppColors.onSurfaceVariant.opacity(0.6)
        }

        private var labelScale: CGFloat {
            isFocused ? 1.08 : 1.0
        }

        var body: some View {
            Button(action: action) {
                VStack(spacing: 18) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 190, height: 190)

                        Image(systemName: "plus")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.2), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    )

                    Text(AppStrings.Profile.addProfile)
                        .font(AppFonts.headline)
                        .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.7))
                        .lineLimit(1)
                        .frame(width: 190, alignment: .center)
                }
            }
            .buttonStyle(TVGridCardButtonStyle(cornerRadius: 26))
        }
    }

    // MARK: - TV Edit Profile Button Style

    private struct TVEditProfileButtonStyle: ButtonStyle {
        let isEditing: Bool

        func makeBody(configuration: Configuration) -> some View {
            TVEditProfileButtonBody(configuration: configuration, isEditing: isEditing)
        }

        private struct TVEditProfileButtonBody: View {
            let configuration: Configuration
            let isEditing: Bool
            @Environment(\.isFocused) private var isFocused

            private var fillColor: Color {
                if isFocused {
                    Color.white
                } else if isEditing {
                    Color.red.opacity(0.25)
                } else {
                    Color.white.opacity(0.08)
                }
            }

            private var strokeColor: Color {
                if isFocused {
                    Color.clear
                } else if isEditing {
                    Color.red.opacity(0.8)
                } else {
                    Color.white.opacity(0.2)
                }
            }

            private var foregroundColor: Color {
                if isFocused {
                    Color.black
                } else if isEditing {
                    Color.red
                } else {
                    Color.white.opacity(0.85)
                }
            }

            private var buttonScale: CGFloat {
                if isFocused {
                    1.08
                } else if configuration.isPressed {
                    0.96
                } else {
                    1.0
                }
            }

            private var shadowColor: Color {
                isFocused ? Color.white.opacity(0.35) : Color.clear
            }

            var body: some View {
                configuration.label
                    .background(
                        Capsule()
                            .fill(fillColor)
                    )
                    .overlay(
                        Capsule()
                            .stroke(strokeColor, lineWidth: 1.5)
                    )
                    .foregroundStyle(foregroundColor)
                    .scaleEffect(buttonScale)
                    .shadow(color: shadowColor, radius: 12, x: 0, y: 0)
                    .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isFocused)
                    .tvHighContrastFocusOutline(isFocused: isFocused, shape: .capsule)
            }
        }
    }

#endif
