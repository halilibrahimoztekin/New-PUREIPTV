import ComposableArchitecture
import SwiftUI

public struct ProfileSelectionView: View {
    @Bindable var store: StoreOf<ProfileSelectionFeature>
    @FocusState private var retryButtonFocused: Bool

    public init(store: StoreOf<ProfileSelectionFeature>) {
        self.store = store
    }

    private var isBlockingContent: Bool {
        store.isLoadingProfiles || store.isPerformingProfileOperation || store.errorMessage != nil
    }

    public var body: some View {
        ZStack {
            Group {
                #if os(tvOS)
                    ProfileSelectionView_tvOS(store: store)
                #else
                    ProfileSelectionView_iOS(store: store)
                #endif
            }
            .allowsHitTesting(!isBlockingContent)
            .disabled(isBlockingContent)
            .accessibilityHidden(isBlockingContent)

            if isBlockingContent {
                Color.black.opacity(0.82)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                VStack(spacing: 20) {
                    if let errorMessage = store.errorMessage {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                            .accessibilityHidden(true)
                        Text(AppStrings.Startup.profilesUnavailableTitle)
                            .font(.title2.weight(.semibold))
                            .multilineTextAlignment(.center)
                        Text(AppStrings.Startup.profilesUnavailableMessage)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                        if !errorMessage.isEmpty {
                            Text(AppStrings.Startup.supportCode(errorMessage))
                                .font(.callout)
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.tertiary)
                        }

                        Button(AppStrings.Common.retry) {
                            store.send(.retry)
                        }
                        .buttonStyle(.borderedProminent)
                        .focused($retryButtonFocused)

                        if store.hasLoadedProfiles {
                            Button(AppStrings.Common.close) {
                                store.send(.dismissError)
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        ProgressView(AppStrings.Common.loading)
                            .controlSize(.large)
                            .accessibilityLabel(AppStrings.Common.loading)
                    }
                }
                .padding(32)
                .frame(maxWidth: 900)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                .padding(32)
                .zIndex(1)
                #if os(tvOS)
                    .focusSection()
                #endif
            }
        }
        .task {
            await Task.yield()
            guard !Task.isCancelled else { return }
            await store.send(.onAppear).finish()
        }
        .onDisappear {
            store.send(.onDisappear)
        }
        .onChange(of: store.errorMessage) { _, message in
            if message != nil {
                retryButtonFocused = true
            }
        }
    }
}

struct ProfileAddProfileRouteForm: View {
    let isPerformingProfileOperation: Bool
    let errorMessage: String?
    let onClose: () -> Void
    let onRetry: () -> Void
    let onAdd: (String, Bool, String) -> Void

    @State private var name = ""
    @State private var isKids = false
    @State private var avatarIcon = ProfileAvatarCatalog.adultDefault

    var body: some View {
        #if os(tvOS)
            tvOSBody
        #else
            iOSBody
        #endif
    }

    #if !os(tvOS)
        private var iOSBody: some View {
            NavigationStack {
                Form {
                    Section(header: Text(AppStrings.Profile.profileInfo)) {
                        TextField(AppStrings.Profile.profileName, text: $name)
                        Toggle(AppStrings.Profile.kidsProfileInfo, isOn: $isKids)
                            .onChange(of: isKids) { _, newValue in
                                resetDefaultAvatar(forKidsMode: newValue)
                            }
                    }

                    Section(header: Text(AppStrings.Profile.profileAvatar)) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 14) {
                            ForEach(ProfileAvatarCatalog.options) { option in
                                Button {
                                    avatarIcon = option.symbolName
                                } label: {
                                    Image(systemName: option.symbolName)
                                        .font(.system(size: 24, weight: .semibold))
                                        .foregroundStyle(avatarIcon == option.symbolName ? .white : .primary)
                                        .frame(maxWidth: .infinity, minHeight: 52)
                                        .background(
                                            avatarIcon == option.symbolName
                                                ? Color.accentColor
                                                : Color.secondary.opacity(0.12),
                                            in: RoundedRectangle(cornerRadius: 12)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 12)
                                                .strokeBorder(
                                                    avatarIcon == option.symbolName ? Color.accentColor : .clear,
                                                    lineWidth: 2
                                                )
                                        }
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(option.name)
                                .accessibilityAddTraits(avatarIcon == option.symbolName ? .isSelected : [])
                            }
                        }
                    }

                    if let errorMessage {
                        Section {
                            Text(AppStrings.Startup.supportCode(errorMessage))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button(AppStrings.Common.retry, action: onRetry)
                        }
                    }

                    if isPerformingProfileOperation {
                        Section {
                            ProgressView(AppStrings.Common.loading)
                        }
                    }
                }
                .navigationTitle(AppStrings.Profile.newProfile)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(AppStrings.Common.cancel, action: onClose)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button(AppStrings.Common.add) {
                            onAdd(name, isKids, avatarIcon)
                        }
                        .disabled(name.isEmpty || isPerformingProfileOperation || errorMessage != nil)
                    }
                }
            }
            .presentationDetents([.medium])
        }
    #endif

    #if os(tvOS)
        private var tvOSBody: some View {
            ZStack {
                Color(hex: "#101016").ignoresSafeArea()

                VStack(spacing: 28) {
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
                            .onChange(of: isKids) { _, newValue in
                                resetDefaultAvatar(forKidsMode: newValue)
                            }

                        Text(AppStrings.Profile.profileAvatar)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.7))

                        ScrollView(.horizontal, showsIndicators: false) {
                            LazyHStack(spacing: 14) {
                                ForEach(ProfileAvatarCatalog.options) { option in
                                    Button {
                                        avatarIcon = option.symbolName
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: option.symbolName)
                                                .font(.system(size: 30, weight: .semibold))
                                            Text(option.name)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(1)
                                        }
                                        .foregroundStyle(.white)
                                        .frame(width: 96, height: 92)
                                        .background(
                                            avatarIcon == option.symbolName
                                                ? Color(hex: "#0A84FF").opacity(0.85)
                                                : Color.white.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 16)
                                        )
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 16)
                                                .strokeBorder(
                                                    avatarIcon == option.symbolName ? Color.white : Color.white.opacity(0.12),
                                                    lineWidth: avatarIcon == option.symbolName ? 2.5 : 1
                                                )
                                        }
                                    }
                                    .buttonStyle(.tvGridCard)
                                    .accessibilityLabel(option.name)
                                    .accessibilityAddTraits(avatarIcon == option.symbolName ? .isSelected : [])
                                }
                            }
                            .padding(.vertical, 10)
                        }
                        .focusSection()
                    }
                    .frame(maxWidth: 600)

                    if let errorMessage {
                        VStack(spacing: 12) {
                            Text(AppStrings.Startup.supportCode(errorMessage))
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                            Button(AppStrings.Common.retry, action: onRetry)
                        }
                    }

                    if isPerformingProfileOperation {
                        ProgressView(AppStrings.Common.loading)
                    }

                    HStack(spacing: 24) {
                        Button(AppStrings.Common.cancel, action: onClose)
                            .font(.system(size: 22, weight: .semibold))
                            .padding(.horizontal, 32)
                            .padding(.vertical, 14)

                        Button(AppStrings.Common.create) {
                            onAdd(name, isKids, avatarIcon)
                        }
                        .font(.system(size: 22, weight: .bold))
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .disabled(
                            name.trimmingCharacters(in: .whitespaces).isEmpty
                                || isPerformingProfileOperation
                                || errorMessage != nil
                        )
                    }
                    .padding(.top, 8)
                }
                .padding(48)
            }
            .onExitCommand(perform: onClose)
        }
    #endif

    private func resetDefaultAvatar(forKidsMode isKidsMode: Bool) {
        guard avatarIcon == ProfileAvatarCatalog.adultDefault || avatarIcon == ProfileAvatarCatalog.kidsDefault else {
            return
        }
        avatarIcon = ProfileAvatarCatalog.defaultAvatar(isKidsMode: isKidsMode)
    }
}
