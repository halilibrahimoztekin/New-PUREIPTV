#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Profile Selection View

    public struct ProfileSelectionView_tvOS: View {
        @Bindable var store: StoreOf<ProfileSelectionFeature>
        @State private var newProfileName = ""
        @State private var newProfileIsKids = false

        public init(store: StoreOf<ProfileSelectionFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── Cinematic Ambient Background ─────────────────────
                Color(hex: "#07070A").ignoresSafeArea()

                RadialGradient(
                    colors: [
                        Color(hex: "#0A84FF").opacity(0.14),
                        Color(hex: "#BF5AF2").opacity(0.06),
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
                            .font(.system(size: 54, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)

                        Text(store.isEditing ? AppStrings.Profile.deleteInstruction : AppStrings.Profile.personalizeDesc)
                            .font(.system(size: 22))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.65))
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
            .onAppear {
                store.send(.onAppear)
            }
            .sheet(isPresented: $store.showingAddProfile) {
                TVAddProfileSheet(
                    name: $newProfileName,
                    isKids: $newProfileIsKids,
                    onCancel: {
                        store.send(.binding(.set(\.showingAddProfile, false)))
                        newProfileName = ""
                        newProfileIsKids = false
                    },
                    onAdd: {
                        store.send(.addProfile(name: newProfileName, isKidsMode: newProfileIsKids))
                        newProfileName = ""
                        newProfileIsKids = false
                    }
                )
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
                    colors: [Color(hex: "#FF9500"), Color(hex: "#FF2D55")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            let palettes: [[Color]] = [
                [Color(hex: "#0A84FF"), Color(hex: "#5E5CE6")],
                [Color(hex: "#BF5AF2"), Color(hex: "#AF52DE")],
                [Color(hex: "#30D158"), Color(hex: "#00C7BE")],
                [Color(hex: "#FF375F"), Color(hex: "#FF9F0A")],
                [Color(hex: "#64D2FF"), Color(hex: "#0A84FF")],
            ]
            let colors = palettes[index % palettes.count]
            return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        private var glowColor: Color {
            profile.isKidsMode ? Color(hex: "#FF9500") : Color(hex: "#0A84FF")
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
            isFocused ? Color.white : Color(hex: "#C0C6D6").opacity(0.75)
        }

        private var nameScale: CGFloat {
            isFocused ? 1.08 : 1.0
        }

        var body: some View {
            VStack(spacing: 18) {
                Button(action: onSelect) {
                    ZStack(alignment: .topTrailing) {
                        // Card Background
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(gradient)
                            .frame(width: 190, height: 190)

                        // Avatar Icon
                        Image(systemName: profile.avatarIcon.isEmpty ? "person.crop.circle.fill" : profile.avatarIcon)
                            .font(.system(size: 78))
                            .foregroundStyle(Color.white)
                            .shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 3)
                            .frame(width: 190, height: 190)

                        // Kids Badge
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

                        // Edit Mode Delete Badge
                        if isEditing {
                            Button(action: onDelete) {
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Color.white)
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(TVCircleButtonStyle(isFavorite: true))
                            .offset(x: 10, y: -10)
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(strokeColor, lineWidth: strokeWidth)
                    )
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: shadowY
                    )
                    .scaleEffect(cardScale)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
                }
                .buttonStyle(.tvGridCard)

                // Profile Name
                Text(profile.name)
                    .font(.system(size: 24, weight: isFocused ? .bold : .medium))
                    .foregroundStyle(nameColor)
                    .scaleEffect(nameScale)
                    .lineLimit(1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
            }
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
            isFocused ? Color(hex: "#0A84FF").opacity(0.6) : Color.clear
        }

        private var shadowRadius: CGFloat {
            isFocused ? 24.0 : 0.0
        }

        private var cardScale: CGFloat {
            isFocused ? 1.15 : 1.0
        }

        private var labelColor: Color {
            isFocused ? Color.white : Color(hex: "#C0C6D6").opacity(0.6)
        }

        private var labelScale: CGFloat {
            isFocused ? 1.08 : 1.0
        }

        var body: some View {
            VStack(spacing: 18) {
                Button(action: action) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(fillColor)
                            .frame(width: 190, height: 190)

                        Image(systemName: "plus")
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(iconColor)
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(strokeColor, style: strokeStyle)
                    )
                    .shadow(
                        color: shadowColor,
                        radius: shadowRadius,
                        x: 0,
                        y: isFocused ? 8 : 0
                    )
                    .scaleEffect(cardScale)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
                }
                .buttonStyle(.tvGridCard)

                Text(AppStrings.Profile.addProfile)
                    .font(.system(size: 24, weight: isFocused ? .bold : .medium))
                    .foregroundStyle(labelColor)
                    .scaleEffect(labelScale)
                    .lineLimit(1)
                    .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isFocused)
            }
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
            }
        }
    }

    // MARK: - TV Add Profile Sheet

    private struct TVAddProfileSheet: View {
        @Binding var name: String
        @Binding var isKids: Bool
        let onCancel: () -> Void
        let onAdd: () -> Void

        var body: some View {
            ZStack {
                Color(hex: "#101016").ignoresSafeArea()

                VStack(spacing: 32) {
                    Text(AppStrings.Profile.createProfile)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.white)

                    VStack(alignment: .leading, spacing: 16) {
                        Text(AppStrings.Profile.profileName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))

                        TextField(AppStrings.Profile.enterProfileName, text: $name)
                            .font(.system(size: 22))
                            .padding()
                            .background(Color.white.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 14))

                        Toggle(AppStrings.Profile.kidsProfileDesc, isOn: $isKids)
                            .font(.system(size: 22))
                            .padding(.vertical, 8)
                    }
                    .frame(maxWidth: 600)

                    HStack(spacing: 24) {
                        Button(AppStrings.Common.cancel, action: onCancel)
                            .font(.system(size: 22, weight: .semibold))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)

                        Button(AppStrings.Common.create, action: onAdd)
                            .font(.system(size: 22, weight: .bold))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.top, 16)
                }
                .padding(48)
            }
        }
    }
#endif
