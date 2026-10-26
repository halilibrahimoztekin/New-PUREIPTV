#if os(tvOS)
    import ComposableArchitecture
    import SwiftUI

    // MARK: - tvOS Add Playlist View

    // Focus Engine design:
    // - Each interactive element is individually focusable
    // - Focus order: Type Picker → form fields → Connect button
    // - Focused elements scale (1.04x) and gain Electric Blue outline glow
    // - All typography at 10-foot scale (1.5–2x iOS sizes)

    public struct AddPlaylistView_tvOS: View {
        @Bindable var store: StoreOf<AddPlaylistFeature>

        @FocusState private var focusedField: TVField?
        @State private var isShowingQRTransfer = false

        private enum TVField: Hashable {
            case xtreamPicker, m3uPicker, plexPicker, embyPicker
            case serverURL, username, password
            case m3uURL
            case connect, plexPINLink, qrTransfer
        }

        public init(store: StoreOf<AddPlaylistFeature>) {
            self.store = store
        }

        public var body: some View {
            ZStack {
                // ── OLED base ────────────────────────────────────────────
                Color.black.ignoresSafeArea()

                EllipticalGradient(
                    colors: [
                        Color(hex: "#0A84FF").opacity(0.1),
                        Color(hex: "#BF5AF2").opacity(0.05),
                        Color.clear,
                    ],
                    center: .init(x: 0.5, y: 0.2),
                    startRadiusFraction: 0.1,
                    endRadiusFraction: 0.7
                )
                .ignoresSafeArea()

                // ── Two-column layout ────────────────────────────────────
                HStack(alignment: .center, spacing: 100) {
                    // Left: branding
                    VStack(alignment: .leading, spacing: 24) {
                        Spacer()

                        PureMaterialLogo(size: 120, showGlow: true)

                        Text(AppStrings.Splash.appName)
                            .font(.system(size: 52, weight: .heavy))
                            .foregroundStyle(Color(hex: "#E4E1E7"))
                            .tracking(-1)

                        Text(AppStrings.AddPlaylist.title)
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.7))

                        Text(AppStrings.AddPlaylist.connectWith)
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(Color(hex: "#C0C6D6").opacity(0.5))
                            .lineSpacing(4)

                        Spacer()
                    }
                    .frame(maxWidth: 380)

                    // Right: form
                    VStack(spacing: 24) {
                        // Type picker
                        tvTypePicker

                        // Form fields
                        if store.playlistType == .xtream || store.playlistType == .emby {
                            tvXtreamFields
                        } else if store.playlistType == .plex {
                            tvPlexFields
                        } else {
                            tvM3UField
                        }

                        // Error
                        if let error = store.errorMessage {
                            tvErrorBanner(message: error)
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        // Connect button
                        tvConnectButton

                        Button {
                            isShowingQRTransfer = true
                        } label: {
                            Label("iPhone ile QR üzerinden aktar", systemImage: "qrcode")
                                .font(.system(size: 22, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .frame(height: 64)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                        }
                        .buttonStyle(TVFocusButtonStyle())
                        .focused($focusedField, equals: .qrTransfer)
                    }
                    .frame(maxWidth: 600)
                    .focusSection()
                    .defaultFocus($focusedField, .xtreamPicker, priority: .automatic)
                }
                .padding(.horizontal, 80)
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.playlistType)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: store.errorMessage)
            .sheet(isPresented: $isShowingQRTransfer) {
                TVOnboardingQRView {
                    isShowingQRTransfer = false
                    focusedField = .qrTransfer
                } onPaired: {
                    store.send(.delegate(.didReceiveTransferredPlaylist))
                }
            }
        }

        // MARK: – Type Picker

        private var tvTypePicker: some View {
            HStack(spacing: 16) {
                ForEach(PlaylistType.allCases, id: \.self) { type in
                    Button {
                        guard !store.isLoading else { return }
                        store.send(.playlistTypeChanged(type))
                    } label: {
                        Text(type.displayName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(store.playlistType == type ? Color.white : Color(hex: "#C0C6D6").opacity(0.5))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background {
                                if store.playlistType == type {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color(hex: "#0A84FF"))
                                } else {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(Color.white.opacity(0.06))
                                }
                            }
                    }
                    .buttonStyle(TVFocusButtonStyle())
                    .focused($focusedField, equals: pickerFocus(for: type))
                }
            }
            .padding(6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            )
            .focusSection()
        }

        private func pickerFocus(for type: PlaylistType) -> TVField {
            switch type {
            case .xtream: .xtreamPicker
            case .m3u: .m3uPicker
            case .plex: .plexPicker
            case .emby: .embyPicker
            }
        }

        // MARK: – Xtream Fields

        private var tvXtreamFields: some View {
            VStack(spacing: 16) {
                TVFormField(
                    icon: "server.rack",
                    placeholder: store.playlistType == .emby ? "Emby server URL" : AppStrings.AddPlaylist.serverPlaceholder,
                    text: guardedBinding(\.serverURL)
                )
                .focused($focusedField, equals: .serverURL)

                TVFormField(
                    icon: "person.fill",
                    placeholder: AppStrings.AddPlaylist.usernamePlaceholder,
                    text: guardedBinding(\.username)
                )
                .focused($focusedField, equals: .username)

                TVFormField(
                    icon: "lock.fill",
                    placeholder: AppStrings.AddPlaylist.passwordPlaceholder,
                    text: guardedBinding(\.password),
                    isSecure: !store.isPasswordVisible
                )
                .focused($focusedField, equals: .password)
            }
        }

        // MARK: – M3U Field

        private var tvM3UField: some View {
            TVFormField(
                icon: "link",
                placeholder: AppStrings.AddPlaylist.m3uPlaceholder,
                text: guardedBinding(\.m3uURL)
            )
            .focused($focusedField, equals: .m3uURL)
        }

        private var tvPlexFields: some View {
            VStack(alignment: .leading, spacing: 16) {
                if let pin = store.plexPIN {
                    Text("Open plex.tv/link and enter this code")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color(hex: "#C0C6D6"))
                    Link(pin.code, destination: pin.signInURL)
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                        .tint(Color(hex: "#E5A00D"))
                        .focused($focusedField, equals: .plexPINLink)
                }
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
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(18)
                        .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(TVFocusButtonStyle())
                }
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

        private func tvErrorBanner(message: String) -> some View {
            HStack(spacing: 14) {
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(Color(hex: "#FF453A"))
                    .font(.system(size: 24, weight: .semibold))

                Text(message)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color(hex: "#E4E1E7"))

                Spacer()
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(hex: "#FF453A").opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color(hex: "#FF453A").opacity(0.35), lineWidth: 1)
                    )
            )
        }

        // MARK: – Connect Button

        private var tvConnectButton: some View {
            Button {
                guard store.canConnect, !store.isLoading else { return }
                store.send(.connectTapped)
            } label: {
                ZStack {
                    if store.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                    } else {
                        HStack(spacing: 12) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .bold))
                            Text(AppStrings.AddPlaylist.connect)
                                .font(.system(size: 28, weight: .bold))
                        }
                        .foregroundStyle(.white)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 72)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            store.canConnect && !store.isLoading
                                ? LinearGradient(
                                    colors: [Color(hex: "#0A84FF"), Color(hex: "#0060CC")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                : LinearGradient(
                                    colors: [Color(hex: "#1F1F23"), Color(hex: "#1F1F23")],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                        )
                        .opacity(store.canConnect ? 1 : 0.5)
                )
            }
            .buttonStyle(TVFocusButtonStyle())
            .focused($focusedField, equals: .connect)
        }
    }

    // MARK: - TV Form Field

    private struct TVFormField: View {
        let icon: String
        let placeholder: String
        @Binding var text: String
        var isSecure: Bool = false

        @FocusState private var isFocused: Bool

        var body: some View {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(isFocused ? Color(hex: "#0A84FF") : Color(hex: "#C0C6D6").opacity(0.5))
                    .frame(width: 30)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)

                Group {
                    if isSecure {
                        SecureField(placeholder, text: $text)
                    } else {
                        TextField(placeholder, text: $text)
                    }
                }
                .font(.system(size: 26))
                .foregroundStyle(Color(hex: "#E4E1E7"))
                .tint(Color(hex: "#0A84FF"))
                .focused($isFocused)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isFocused ? Color(hex: "#0A84FF").opacity(0.08) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isFocused ? Color(hex: "#0A84FF").opacity(0.6) : Color.white.opacity(0.08),
                                lineWidth: isFocused ? 2 : 1
                            )
                    )
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
    }

    // MARK: - TV Focus Button Style

    // Applies scale + shadow on focus for tvOS focus engine

    struct TVFocusButtonStyle: ButtonStyle {
        @Environment(\.isFocused) private var isFocused

        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .scaleEffect(isFocused ? 1.04 : 1.0)
                .shadow(
                    color: Color(hex: "#0A84FF").opacity(isFocused ? 0.5 : 0),
                    radius: 16, x: 0, y: 4
                )
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isFocused)
        }
    }

    // MARK: - Preview

    #Preview("tvOS Add Playlist") {
        AddPlaylistView_tvOS(
            store: Store(initialState: AddPlaylistFeature.State()) {
                AddPlaylistFeature()
            }
        )
    }
#endif
