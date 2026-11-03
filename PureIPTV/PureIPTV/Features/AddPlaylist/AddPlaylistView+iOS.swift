#if os(iOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - iOS & iPad Add Playlist View

    public struct AddPlaylistView_iOS: View {
        @Bindable var store: StoreOf<AddPlaylistFeature>
        @FocusState private var focusedField: Field?

        private enum Field: Hashable {
            case serverURL, username, password, m3uURL
        }

        public init(store: StoreOf<AddPlaylistFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── OLED base + ambient glow ─────────────────────────────
                Color.black.ignoresSafeArea()

                RadialGradient(
                    colors: [
                        AppColors.primary.opacity(0.12),
                        AppColors.premium.opacity(0.06),
                        Color.clear,
                    ],
                    center: .init(x: 0.5, y: 0.25),
                    startRadius: 0,
                    endRadius: 400
                )
                .ignoresSafeArea()

                // ── Scrollable content ───────────────────────────────────
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Header
                        header
                            .padding(.top, 56)
                            .padding(.bottom, 32)

                        // Smart Paste Banner (Madde #77)
                        if store.isShowingClipboardBanner, let detectedURL = store.detectedClipboardURL {
                            SmartPasteBannerView(
                                detectedURL: detectedURL,
                                onApply: { _ in store.send(.applyClipboardURL) },
                                onDismiss: { store.send(.dismissClipboardBanner) }
                            )
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 24)
                            .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Type picker
                        typePicker
                            .padding(.horizontal, horizontalPadding)
                            .padding(.bottom, 32)

                        // Form fields
                        formFields
                            .padding(.horizontal, horizontalPadding)

                        if store.supportsCompatibilityCheck {
                            PlaylistHealthPreflightView(
                                report: store.compatibilityReport,
                                isChecking: store.isCheckingCompatibility,
                                isEnabled: store.canConnect && !store.isLoading,
                                onCheck: { store.send(.checkCompatibilityTapped) }
                            )
                            .padding(.horizontal, horizontalPadding)
                        }

                        // Error banner
                        if let error = store.errorMessage {
                            errorBanner(message: error)
                                .padding(.horizontal, horizontalPadding)
                                .padding(.top, 16)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Connect button
                        connectButton
                            .padding(.horizontal, horizontalPadding)
                            .padding(.top, 32)
                            .padding(.bottom, 16)
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.errorMessage)
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.playlistType)
            .onTapGesture {
                focusedField = nil
            }
            .onAppear {
                store.send(.onAppear)
            }
        }

        // MARK: – Header

        private var header: some View {
            VStack(spacing: 12) {
                // Logo icon
                PureMaterialLogo(size: 72, showGlow: true)

                Text(AppStrings.AddPlaylist.title)
                    .font(AppFonts.displayMedium)
                    .foregroundStyle(AppColors.onSurface)

                Text(AppStrings.AddPlaylist.connectWithIOS)
                    .font(AppFonts.bodyMedium)
                    .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }

        // MARK: – Type Picker

        private var typePicker: some View {
            HStack(spacing: 0) {
                ForEach(PlaylistType.allCases, id: \.self) { type in
                    Button {
                        guard !store.isLoading else { return }
                        store.send(.playlistTypeChanged(type))
                    } label: {
                        Text(type.displayName)
                            .font(AppFonts.bodySmall.weight(.semibold))
                            .foregroundStyle(
                                store.playlistType == type
                                    ? Color.white
                                    : AppColors.onSurfaceVariant.opacity(0.6)
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background {
                                if store.playlistType == type {
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(AppColors.primary)
                                        .matchedGeometryEffect(id: "pill", in: pickerNamespace)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
            )
        }

        @Namespace private var pickerNamespace

        // MARK: – Form Fields

        @ViewBuilder
        private var formFields: some View {
            if store.playlistType == .xtream || store.playlistType == .emby {
                VStack(spacing: 12) {
                    GlassTextField(
                        icon: "server.rack",
                        placeholder: store.playlistType == .emby ? "Emby server URL" : AppStrings.AddPlaylist.serverPlaceholder,
                        text: guardedBinding(\.serverURL),
                        keyboardType: .URL,
                        autocapitalization: .never
                    )
                    .focused($focusedField, equals: .serverURL)

                    HStack(spacing: 12) {
                        GlassTextField(
                            icon: "person.fill",
                            placeholder: AppStrings.AddPlaylist.usernamePlaceholder,
                            text: guardedBinding(\.username),
                            autocapitalization: .never
                        )
                        .focused($focusedField, equals: .username)

                        GlassSecureField(
                            icon: "lock.fill",
                            placeholder: AppStrings.AddPlaylist.passwordPlaceholder,
                            text: guardedBinding(\.password),
                            isVisible: store.isPasswordVisible,
                            onToggle: { store.send(.togglePasswordVisibility) }
                        )
                        .focused($focusedField, equals: .password)
                    }
                }
            } else if store.playlistType == .plex {
                VStack(alignment: .leading, spacing: 12) {
                    if let pin = store.plexPIN {
                        Text("Go to plex.tv/link and enter this code")
                            .font(AppFonts.bodyMedium.weight(.medium))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                        Link(pin.code, destination: pin.signInURL)
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .tint(AppColors.amber)
                    }
                    if !store.discoveredPlexServers.isEmpty {
                        Text("Choose a Plex server")
                            .font(AppFonts.bodyMedium.weight(.semibold))
                            .foregroundStyle(AppColors.onSurfaceVariant)
                        ForEach(store.discoveredPlexServers) { server in
                            Button {
                                guard !store.isLoading else { return }
                                store.send(.selectPlexServer(server.id))
                            } label: {
                                HStack {
                                    Text(server.name)
                                    Spacer()
                                    if store.selectedPlexServerID == server.id {
                                        Image(systemName: "checkmark.circle.fill")
                                    }
                                }
                                .foregroundStyle(AppColors.textPrimary)
                                .padding(12)
                                .background(AppColors.borderSubtle, in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            } else {
                GlassTextField(
                    icon: "link",
                    placeholder: AppStrings.AddPlaylist.m3uPlaceholder,
                    text: guardedBinding(\.m3uURL),
                    keyboardType: .URL,
                    autocapitalization: .never
                )
                .focused($focusedField, equals: .m3uURL)
            }
        }

        private func guardedBinding(_ keyPath: WritableKeyPath<AddPlaylistFeature.State, String>) -> Binding<String> {
            Binding(
                get: { store.withState { $0[keyPath: keyPath] } },
                set: { value in
                    guard !store.isLoading else { return }
                    store.send(.binding(.set(keyPath, value)))
                }
            )
        }

        // MARK: – Error Banner

        private func errorBanner(message: String) -> some View {
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(AppColors.destructive)
                    .font(AppFonts.bodySmall.weight(.semibold))

                Text(message)
                    .font(AppFonts.caption.weight(.medium))
                    .foregroundStyle(AppColors.onSurface)
                    .multilineTextAlignment(.leading)

                Spacer()

                Button {
                    store.send(.dismissError)
                } label: {
                    Image(systemName: "xmark")
                        .font(AppFonts.captionSmall.weight(.bold))
                        .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.6))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(AppColors.destructive.opacity(0.12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.destructive.opacity(0.3), lineWidth: 1)
                    )
            )
        }

        // MARK: – Connect Button

        private var connectButton: some View {
            Button {
                focusedField = nil
                store.send(.connectTapped)
            } label: {
                ZStack {
                    if store.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.85)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "play.fill")
                                .font(AppFonts.caption.weight(.bold))
                            Text(AppStrings.AddPlaylist.connect)
                                .font(AppFonts.bodyLarge.weight(.bold))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(
                    Group {
                        if store.canConnect, !store.isLoading {
                            LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryDark],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        } else {
                            AppColors.surfaceSecondary
                        }
                    }
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(store.canConnect ? 0 : 0.06), lineWidth: 1)
                )
                .opacity(store.canConnect ? 1 : 0.5)
            }
            .disabled(!store.canConnect || store.isLoading || store.isCheckingCompatibility)
            .buttonStyle(.plain)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.canConnect)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: store.isLoading)
        }

        // MARK: – Layout helpers

        private var horizontalPadding: CGFloat {
            UIDevice.current.userInterfaceIdiom == .pad ? 80 : 20
        }
    }

    // MARK: - Glass Text Field

    struct GlassTextField: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        var keyboardType: UIKeyboardType = .default
        var autocapitalization: TextInputAutocapitalization = .sentences

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(AppFonts.bodyMedium.weight(.medium))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 22)

                TextField(placeholder, text: $text)
                    .font(AppFonts.bodyLarge)
                    .foregroundStyle(AppColors.onSurface)
                    .keyboardType(keyboardType)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .tint(AppColors.primary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Glass Secure Field

    struct GlassSecureField: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        let isVisible: Bool
        let onToggle: () -> Void

        var body: some View {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(AppFonts.bodyMedium.weight(.medium))
                    .foregroundStyle(AppColors.primary)
                    .frame(width: 22)

                if isVisible {
                    TextField(placeholder, text: $text)
                        .font(AppFonts.bodyLarge)
                        .foregroundStyle(AppColors.onSurface)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .tint(AppColors.primary)
                } else {
                    SecureField(placeholder, text: $text)
                        .font(AppFonts.bodyLarge)
                        .foregroundStyle(AppColors.onSurface)
                        .tint(AppColors.primary)
                }

                Button(action: onToggle) {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .font(AppFonts.bodySmall.weight(.medium))
                        .foregroundStyle(AppColors.onSurfaceVariant.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(AppColors.borderSubtle, lineWidth: 1)
                    )
            )
        }
    }

    // MARK: - Preview

    #Preview("Add Playlist – iPhone") {
        AddPlaylistView_iOS(
            store: Store(initialState: AddPlaylistFeature.State()) {
                AddPlaylistFeature()
            }
        )
    }

    #Preview("Add Playlist – Error State") {
        AddPlaylistView_iOS(
            store: Store(
                initialState: {
                    var s = AddPlaylistFeature.State()
                    s.errorMessage = AppStrings.Errors.unauthorized
                    s.serverURL = "http://example.com:8080"
                    s.username = "user"
                    s.password = "wrong"
                    return s
                }()
            ) {
                AddPlaylistFeature()
            }
        )
    }
#endif
